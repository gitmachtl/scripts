#!/bin/bash

# Script is brought to you by ATADA Stakepool, Telegram @atada_stakepool

#load variables and functions from common.sh
. "$(dirname "$0")"/00_common.sh

#Check the commandline parameter
if [[ $# -eq 1 && ! $1 == "" && "${1//[![:xdigit:]]}" == "${1}" && ${#1} -eq 64 ]]; then txHash="${1,,}"; else echo -e "Usage: $0 <QuestionTxHash>\n\nPlease specify a 64char hex tx-hash as the input parameter.\n\nExample: $0 d8c1b1d871a27d74fbddfa16d28ce38288411a75c5d3561bb74066bcd54689e2\n\n"; exit 2; fi

#Get the Question Metadata via koios
if ${offlineMode}; then echo -e "\n\e[35mERROR - SPO-Poll is only supported in Online mode.\n\e[0m"; exit 1; fi

echo -e "\e[0mSPO-Poll question via metadata from txHash: \e[32m${txHash}\e[0m"
echo

showProcessAnimation "Query Question-Metadata via koios: " &
response=$(curl -s -m 10 -X POST "${koiosAPI}/tx_metadata" -H "accept: application/json" -H "content-type: application/json" -d "{\"_tx_hashes\":[\"${txHash}\"]}" 2> /dev/null)
stopProcessAnimation;


#Check if the response is valid and if the label is 94
#check if the received json only contains one entry in the array (will also not be 1 if not a valid json)
if [[ $(jq ". | length" 2> /dev/null <<< ${response}) -ne 1 ]]; then
	echo -e "\n\e[35mERROR - No data found via koios for the txHash ${txHash}\n\e[0m"; exit 1;
fi


#Data found, now check about the metadata label 94
txMeta94=$(jq -r ".[0].metadata.\"94\"" <<< ${response} 2> /dev/null)
if [[ ${txMeta94} == "null" ]]; then
	echo -e "\n\e[35mERROR - No CIP0094 metadatum label 94 found\n\e[0m"; exit 1;
fi

#Variables for the Question and the Options
questionString=""   #string that holds the question
optionString=()     #array of options

#Question found now convert it to cbor
cborStr="" #setup a clear new cbor string variable
cborStr+=$(to_cbor "map" 1) #map 1
cborStr+=$(to_cbor "unsigned" 94) #unsigned 94
cborStr+=$(to_cbor "map" 2) #map 2
cborStr+=$(to_cbor "unsigned" 0) #unsigned 0

#Add QuestionStrings
questionStrLength=$(jq -r ".\"0\" | length" <<< ${txMeta94} 2> /dev/null)
if [[ ${questionStrLength} -eq 0 ]]; then
	echo -e "\n\e[35mERROR - No question string included\n\e[0m"; exit 1;
fi
cborStr+=$(to_cbor "array" ${questionStrLength}) #array with the number of entries
for (( tmpCnt=0; tmpCnt<${questionStrLength}; tmpCnt++ ))
do
	strEntry=$(jq -r ".\"0\"[${tmpCnt}]" <<< ${txMeta94} 2> /dev/null)
	cborStr+=$(to_cbor "string" "${strEntry}") #string
	questionString+="${strEntry}"
done

cborStr+=$(to_cbor "unsigned" 1) #unsigned 1

#Add OptionsStrings
optionsStrLength=$(jq -r ".\"1\" | length" <<< ${txMeta94} 2> /dev/null)
if [[ ${optionsStrLength} -eq 0 ]]; then
	echo -e "\n\e[35mERROR - No option strings included\n\e[0m"; exit 1;
fi
cborStr+=$(to_cbor "array" ${optionsStrLength}) #array with the number of options

for (( tmpCnt=0; tmpCnt<${optionsStrLength}; tmpCnt++ ))
do

	optionEntryStrLength=$(jq -r ".\"1\"[${tmpCnt}] | length" <<< ${txMeta94} 2> /dev/null)
	cborStr+=$(to_cbor "array" ${optionEntryStrLength}) #array with the number of entries
	for (( tmpCnt2=0; tmpCnt2<${optionEntryStrLength}; tmpCnt2++ ))
	do
		strEntry=$(jq -r ".\"1\"[${tmpCnt}][${tmpCnt2}]" <<< ${txMeta94} 2> /dev/null)
		cborStr+=$(to_cbor "string" "${strEntry}") #string
		optionString[${tmpCnt}]+="${strEntry}"
	done

done


#Show the question and the available answer options
echo
echo -e "\e[32mQuestion\e[0m: ${questionString}"
echo
echo -e "There are ${optionsStrLength} answer option(s) available:"
for (( tmpCnt=0; tmpCnt<${optionsStrLength}; tmpCnt++ ))
do
 echo -e "[\e[33m${tmpCnt}\e[0m] ${optionString[${tmpCnt}]}"
done
echo

#Read in the answer, loop until a valid answer index is given
answer="-1"
while [ -z "${answer##*[!0-9]*}" ] || [[ ${answer} -lt 0 ]] || [[ ${answer} -ge ${optionsStrLength} ]];
do
	read -e -p $'\e[33mPlease indicate an answer (by index): \e[0m' answer
	if [[ ${answer} == "" ]]; then echo -e "\nExited without an answer\n"; exit 1; fi
done

echo
echo -e "Your answer is '${optionString[${answer}]}'."
echo

if ! ask "\e[33mIs this correct ?\e[0m" Y; then	echo -e "\nExited without an answer\n"; exit 1; fi

#Generating the answer cbor
questionHash=$(echo -n "${cborStr}" | xxd -r -ps | b2sum -l 256 -b | cut -d' ' -f 1)

#Make a new cborStr with the answer
cborStr="" #setup a clear new cbor string variable
cborStr+=$(to_cbor "map" 1) #map 1
cborStr+=$(to_cbor "unsigned" 94) #unsigned 94
cborStr+=$(to_cbor "map" 2) #map 2
cborStr+=$(to_cbor "unsigned" 2) #unsigned 2
cborStr+=$(to_cbor "bytes" "${questionHash}") #bytearray of the blake2b-256 hash of the question cbor
cborStr+=$(to_cbor "unsigned" 3) #unsigned 3
cborStr+=$(to_cbor "unsigned" ${answer}) #unsigned - answer index


#CBOR Answer is ready, write it out to disc
echo
echo -e "\e[0mCBOR-Answer generated: \e[32m${cborStr}\e[0m"
echo

cborFile="spopoll_${questionHash}.cbor"
echo -ne "\e[0mWriting the file '\e[32m${cborFile}\e[0m' to disc ... "
xxd -r -ps <<< ${cborStr} 2> /dev/null > ${cborFile}
if [ $? -ne 0 ]; then echo -e "\n\n\e[35mERROR, could not write to file!\n\n\e[0m"; exit 1; fi
echo -e "\e[32mOK\e[0m\n"

echo -e "\e[0mYou can now submit the CBOR file on the chain by using the\nscript 13b_sendSpoPoll.sh to also sign it with your pool cold key.\nExample:\e[33m 13b_sendSpoPoll.sh mywallet mywallet min mypool \"${cborFile}\"\n\e[0m";
