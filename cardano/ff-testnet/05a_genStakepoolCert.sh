#!/bin/bash

# Script is brought to you by ATADA_Stakepool, Telegram @atada_stakepool

#load variables from common.sh
#       socket          Path to the node.socket (also exports socket to CARDANO_NODE_SOCKET_PATH)
#       genesisfile     Path to the genesis.json
#       magicparam      TestnetMagic parameter
#       cardanocli      Path to the cardano-cli executable
#       cardanonode     Path to the cardano-node executable
. "$(dirname "$0")"/00_common.sh

if [[ $# -eq 1 && ! $1 == "" ]]; then poolFile=$1; else echo "ERROR - Usage: $(basename $0) <PoolNodeName> (pointing to the PoolNodeName.pool.json file)"; exit 1; fi

#Check if json file exists
if [ ! -f "${poolFile}.pool.json" ]; then echo -e "\n\e[33mERROR - \"${poolFile}.pool.json\" does not exist, a dummy one was created, please edit it and retry.\e[0m";
#Generate Dummy JSON File
echo "
{
	\"poolName\":   \"${poolFile}\",
	\"poolOwner\":  \"owner\",
        \"poolRewards\":  \"owner\",
	\"poolPledge\": \"100000000000\",
	\"poolCost\":   \"10000000000\",
	\"poolMargin\": \"0.10\"
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
ownerName=$(readJSONparam "poolOwner"); if [[ ! $? == 0 ]]; then exit 2; fi
rewardsName=$(readJSONparam "poolRewards"); if [[ ! $? == 0 ]]; then exit 2; fi
poolPledge=$(readJSONparam "poolPledge"); if [[ ! $? == 0 ]]; then exit 2; fi
poolCost=$(readJSONparam "poolCost"); if [[ ! $? == 0 ]]; then exit 2; fi
poolMargin=$(readJSONparam "poolMargin"); if [[ ! $? == 0 ]]; then exit 2; fi

#case $# in
#  5 ) poolName="$1";
#      ownerName="$2";
#      poolPledge="$3";
#      poolCost="$4";
#      poolMargin="$5";;
#  * ) cat >&2 <<EOF
#Usage:  $(basename $0) <PoolNodeName> <OwnerStakeAddressName> <pledgeInLovelaces> <poolCostInLovelaces> <poolMargin 0.01-1.00>
#EOF
#  exit 1;; esac

#Check needed inputfiles
if [ ! -f "${poolName}.node.vkey" ]; then echo -e "\e[0mERROR - ${poolName}.node.vkey is missing, please generate it with script 04a !\e[0m"; exit 2; fi
if [ ! -f "${poolName}.vrf.vkey" ]; then echo -e "\e[0mERROR - ${poolName}.vrf.vkey is missing, please generate it with script 04b !\e[0m"; exit 2; fi
if [ ! -f "${ownerName}.staking.vkey" ]; then echo -e "\e[0mERROR - ${ownerName}.staking.vkey is missing, please generate it with script 03a !\e[0m"; exit 2; fi
if [ ! -f "${rewardsName}.staking.vkey" ]; then echo -e "\e[0mERROR - ${rewardsName}.staking.vkey is missing, please generate it with script 03a !\e[0m"; exit 2; fi



echo
echo -e "\e[0mCreate a Stakepool registration certificate for PoolNode with \e[32m ${poolName}.node.vkey, ${poolName}.vrf.vkey\e[0m:"
echo
echo -e "\e[0m  Owner Stake:\e[32m ${ownerName}.staking.vkey \e[0m"
echo -e "\e[0mRewards Stake:\e[32m ${rewardsName}.staking.vkey \e[0m"
echo -e "\e[0m       Pledge:\e[32m ${poolPledge} \e[90mlovelaces"
echo -e "\e[0m         Cost:\e[32m ${poolCost} \e[90mlovelaces"
echo -e "\e[0m       Margin:\e[32m ${poolMargin} \e[0m"

#Usage: cardano-cli shelley stake-pool registration-certificate --cold-verification-key-file FILE
#                                                               --vrf-verification-key-file FILE
#                                                               --pool-pledge LOVELACE
#                                                               --pool-cost LOVELACE
#                                                               --pool-margin DOUBLE
#                                                               --pool-reward-account-verification-key-file FILE
#                                                               --pool-owner-stake-verification-key-file FILE
#                                                               --out-file FILE
#  Create a stake pool registration certificate

file_unlock ${poolName}.pool.cert
${cardanocli} shelley stake-pool registration-certificate --cold-verification-key-file ${poolName}.node.vkey --vrf-verification-key-file ${poolName}.vrf.vkey --pool-pledge ${poolPledge} --pool-cost ${poolCost} --pool-margin ${poolMargin} --pool-reward-account-verification-key-file ${rewardsName}.staking.vkey --pool-owner-stake-verification-key-file ${ownerName}.staking.vkey --out-file ${poolName}.pool.cert
#No error, so lets update the pool JSON file with the date and file the certFile was created
if [[ $? -eq 0 ]]; then
	file_unlock ${poolFile}.pool.json
	newJSON=$(cat ${poolFile}.pool.json | jq ". += {regCertCreated: \"$(date)\"}" | jq ". += {regCertFile: \"${poolName}.pool.cert\"}")
	echo "${newJSON}" > ${poolFile}.pool.json
        file_lock ${poolFile}.pool.json
fi

file_lock ${poolName}.pool.cert

echo
echo -e "\e[0mStakepool registration certificate:\e[32m ${poolName}.pool.cert \e[90m"
cat ${poolName}.pool.cert 
echo

echo
echo -e "\e[0mStakepool Info JSON:\e[32m ${poolFile}.pool.json \e[90m"
cat ${poolFile}.pool.json
echo

echo -e "\e[0m"


