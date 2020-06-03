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
if [ ! -f "${poolFile}.pool.json" ]; then echo -e "\n\e[33mERROR - \"${poolFile}.pool.json\" does not exist.\e[0m"; exit 1; fi

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
poolID=$(readJSONparam "poolID"); if [[ ! $? == 0 ]]; then exit 2; fi

echo
echo -e "\e[0mChecking \e[32m ${poolFile}.pool.json\e[0m about the Pool-ID: ${poolID}"
echo

#check ledger-state
poolInLedgerCnt=$(${cardanocli} shelley query ledger-state ${magicparam} | grep "poolPubKey" | grep  "${poolID}" | wc -l)

if [[ ${poolInLedgerCnt} -gt 0 ]]; then 
					echo -e "\e[32mPool-ID is on the chain!\e[0m";
				    else
					echo -e "\e[35mPool-ID is NOT on the chain!\e[0m";
fi
echo
