#!/bin/bash

# Script is brought to you by ATADA_Stakepool, Telegram @atada_stakepool

#load variables from common.sh
#       socket          Path to the node.socket (also exports socket to CARDANO_NODE_SOCKET_PATH)
#       genesisfile     Path to the genesis.json
#       magicparam      TestnetMagic parameter
#       cardanocli      Path to the cardano-cli executable
#       cardanonode     Path to the cardano-node executable
. "$(dirname "$0")"/00_common.sh

if [[ $# -gt 0 && ! $1 == "" ]]; then poolFile=$1; else echo "ERROR - Usage: $(basename $0) <PoolNodeName> [optional retirement EPOCH value]"; exit 1; fi

if [[ $# -eq 2 ]]; then retireEPOCH=$2; fi

#Check if json file exists
if [ ! -f "${poolFile}.pool.json" ]; then echo -e "\n\e[33mERROR - \"${poolFile}.pool.json\" does not exist, a dummy one with minimum parameters for deRegistration was created, please retry.\e[0m";
#Generate Dummy JSON File
echo "
{
        \"poolName\":   \"${poolFile}\",
        \"poolOwner\": [
                {
                \"ownerName\": \"set_your_owner_name_here\"
                }
        ]
}
" > ${poolFile}.pool.json
echo
echo -e "\e[0mStakepool Info JSON:\e[32m ${poolFile}.pool.json \e[90m"
cat ${poolFile}.pool.json
echo
exit 1; fi

#Small subroutine to read the value of the JSON and output an error is parameter is empty/missing
function readJSONparam() {
param=$(jq -r .$1 ${poolFile}.pool.json 2> /dev/null)
if [[ $? -ne 0 ]]; then echo "ERROR - ${poolFile}.pool.json is not a valid JSON file" >&2; exit 2;
elif [[ "${param}" == null ]]; then echo "ERROR - Parameter \"$1\" in ${poolFile}.pool.json does not exist" >&2; exit 2;
elif [[ "${param}" == "" ]]; then echo "ERROR - Parameter \"$1\" in ${poolFile}.pool.json is empty" >&2; exit 2;
fi
echo "${param}"
}

#Read the pool JSON file and extract the parameters -> report an error is something is missing or wrong/empty
poolName=$(readJSONparam "poolName"); if [[ ! $? == 0 ]]; then exit 2; fi

#Check needed inputfiles
if [ ! -f "${poolName}.node.vkey" ]; then echo -e "\e[0mERROR - ${poolName}.node.vkey is missing !\e[0m"; exit 2; fi

echo
echo -e "\e[0mCreate a Stakepool de-Registration (retire) certificate for PoolNode with \e[32m ${poolName}.node.vkey\e[0m:"
echo

#Getting protocol parameters from the blockchain, checking epochMax (eMax)
${cardanocli} shelley query protocol-parameters ${magicparam} > protocol-parameters.json
eMax=$(cat protocol-parameters.json | jq -r .eMax)

currentEPOCH=$(get_currentEpoch)
minRetireEpoch=$(( ${currentEPOCH} + 1 ))	#earliest one
maxRetireEpoch=$(( ${currentEPOCH} + ${eMax} ))	#latest one

if [[ "${retireEPOCH}" == "" ]]; then retireEPOCH=${minRetireEpoch}; #use the earliest retirement epoch
elif [[ ${retireEPOCH} -lt ${minRetireEpoch} ]]; then retireEPOCH=${minRetireEpoch}; #set it to the earliest possible retirement epoch
elif [[ ${retireEPOCH} -gt ${maxRetireEpoch} ]]; then retireEPOCH=${maxRetireEpoch}; fi #set it to the latest possible retirement epoch

echo -e "      Current EPOCH:\e[32m ${currentEPOCH}\e[0m"
echo -e "   Min Retire EPOCH:\e[32m ${minRetireEpoch}\e[0m (current + 1)"
echo -e "   Max Retire EPOCH:\e[32m ${maxRetireEpoch}\e[0m (current + ${eMax})"
echo
echo -e "Retire EPOCH set to:\e[32m ${retireEPOCH}\e[0m"


#Usage: cardano-cli shelley stake-pool deregistration-certificate --cold-verification-key-file FILE
#                                                                 --epoch NATURAL
#                                                                 --out-file FILE
#  Create a stake pool deregistration certificate

file_unlock ${poolName}.pool.dereg-cert

${cardanocli} shelley stake-pool deregistration-certificate --cold-verification-key-file ${poolName}.node.vkey --epoch ${retireEPOCH} --out-file ${poolName}.pool.dereg-cert
checkError "$?"

#No error, so lets update the pool JSON file with the date and file the certFile was created
if [[ $? -eq 0 ]]; then
	file_unlock ${poolFile}.pool.json
	newJSON=$(cat ${poolFile}.pool.json | jq ". += {deregCertCreated: \"$(date -R)\"}" | jq ". += {deregCertFile: \"${poolName}.pool.dereg-cert\"}" | jq ". += {deregEpoch: \"${retireEPOCH}\"}" )
	echo "${newJSON}" > ${poolFile}.pool.json
        file_lock ${poolFile}.pool.json
fi

file_lock ${poolName}.pool.dereg-cert

echo
echo -e "\e[0mStakepool de-registration certificate:\e[32m ${poolName}.pool.dereg-cert \e[90m"
cat ${poolName}.pool.dereg-cert
echo

echo
echo -e "\e[0mStakepool Info JSON:\e[32m ${poolFile}.pool.json \e[90m"
cat ${poolFile}.pool.json
echo

echo -e "\e[0m"


