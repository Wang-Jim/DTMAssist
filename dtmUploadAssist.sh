#!/bin/sh
# parameter 1 : the path to file   
# parameter 2 : the string copy from DTM upload URL
#           the format of paramete 2 : https://support.microsoft.com/files?workspace={a long string}&wid={looks like an ID}
# the overview of the file upload to DTM process:
    # step0: the information are required :  workspace  , wid .   wc can get them from the DTM shared link, it does not need to login,  we could upload file anonymous
    # step1: use workspace information to get access token 
    # step2: use access token and HTTP PUT method to allocated/define a file in the DTM, include some information : chunk Size , file size , file name , number of chunks
    # step3: use HTTP PATCH method to upload the file, the real content, to DTM separately
#  
#  This script is for users to know the DTM upload link, and in the linux environment, it is convenient to upload files directly from the VM to the DTM. 
#  
#  this script also write logs to /tmp/dtmUploadAssist_logFile , if you can't not execute/upload the file properly , please check the logs
#                                

PathToFile=$1;
DFMURI=$2;
logFile="/tmp/dtmUploadAssist_logFile"

echo -e "\n\n========== to start execute DTM upload assist script on `hostname` at `date` ========== " >> "${logFile}" 2>&1
echo "check / list if the 1st parameter is a file and the basic info "  >> "${logFile}" 2>&1

ls -l $PathToFile  >> "${logFile}" 2>&1

echo "log the input parameter 2 :  the URI copied from DTM link:"  >> "${logFile}" 2>&1
echo -e "$DFMURI \n"  >> "${logFile}" 2>&1





# the overview of the file upload to DTM process:
    # step0: the information are required :  workspace  , wid .   wc can get them from the DTM shared link, it does not need to login,  we could upload file anonymous
workspace=$(echo $DFMURI  | awk -F'[?=&]' '{print $3}' )
wid=$(echo $DFMURI  | awk -F'[?=&]' '{print $5}' )

printf "Step0 log : the workspace value is: %s  \nThe wid value is : %s \n\n" $workspace $wid  >> "${logFile}" 2>&1

    # step1: use workspace information to get access token 
    echo "to get access token for the DTM workspace" 
respStr=$(curl -s 'https://support.microsoft.com/supportformsapi/workspace/AccessTokens' -H 'Content-Type: application/json' --data-raw '{"workspaceToken":"'$workspace'","email":null}')
printf "step1 log : the access token response str is :%s \n\n" $respStr  >> "${logFile}" 2>&1
accessToken=$(echo $respStr | awk -F '"' '{print $4}')
printf "step1 log : retrieve the accessToken value as : %s \n\n" $accessToken  >> "${logFile}" 2>&1

    # step2: use access token and Http PUT method to allocated/define a file in the DTM, include some information : chunk Size , file size , file name , number of chunks
fileSize=$( wc -c < $PathToFile)
fileName=$(basename $PathToFile)
#chunkSize=134217728   # set chunk Size as 128MB as the default value , you could use other size of bytes
chunkSize=134217728
numberOfChunks=$(( (fileSize+chunkSize-1)/chunkSize ))

printf "step2 log :  fileSize: %s , fileName: %s , chunkSize: %s , number of chunks: %s \n\n" $fileSize $fileName $chunkSize $numberOfChunks  >> "${logFile}" 2>&1

printf "step2 log: ready to PUT file metadata to DTM\n"  >> "${logFile}" 2>&1
curl -s "https://api.dtmnebula.microsoft.com/api/v1/workspaces/$wid/folders/external/files/metadata?filename=$fileName" -X 'PUT' -H "authorization: Bearer $accessToken" -H 'content-type: application/json' --data-raw '{"chunkSize":'$chunkSize',"contentType":"application/octet-stream","fileSize":'$fileSize',"numberOfChunks":'$numberOfChunks'}'  >> "${logFile}" 2>&1


    # step3: use Http PATCH method to upload the file, the real content, to DTM separately
split -b $chunkSize -d   $PathToFile  uploadFileTemp_   #  to split the file into many files by the chunkSize.  the temp file name is like uploadFileTemp_00 , uploadFileTemp_01 ....
echo "step3 log: the current working directory is `pwd` , the splited temp files are:"  >> "${logFile}" 2>&1
ls -l uploadFileTemp_*  >> "${logFile}" 2>&1

echo "split file $PathToFile into $numberOfChunks chunk(s) to upload, chunk size is 128MB"
for i in $(seq 0 $((numberOfChunks-1))); do 
    tempIndex=$(printf "%02d" $i); 
    printf "to upload chunked file $i with temp file name: uploadFileTemp_$tempIndex \n"; 
    curl  "https://api.dtmnebula.microsoft.com/api/v1/workspaces/$wid/folders/external/files?fileName=$fileName" -X 'PATCH' -H "chunkindex: $i" -H "authorization: Bearer $accessToken" -H 'content-type: application/octet-stream' -T  "uploadFileTemp_$tempIndex"  --progress-bar | tee -a "${logFile}" 
done

rm -f uploadFileTemp_*   # to remove the temp file after script 

echo "\n========== end of execute DTM upload assist script on `hostname` at `date` ========== " >> "${logFile}" 2>&1



