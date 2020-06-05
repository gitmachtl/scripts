#!/bin/bash

# Script is brought to you by ATADA_Stakepool, Telegram @atada_stakepool

#load variables from common.sh
#       socket          Path to the node.socket (also exports socket to CARDANO_NODE_SOCKET_PATH)
#       genesisfile     Path to the genesis.json
#       magicparam      TestnetMagic parameter
#       cardanocli      Path to the cardano-cli executable
#       cardanonode     Path to the cardano-node executable
. "$(dirname "$0")"/00_common.sh

if [[ $# -eq 1 && ! $1 == "" ]]; then poolName=$1; else echo "ERROR - Usage: $(basename $0) <PoolNodeName> (pointing to the PoolNodeName.node.vkey file)"; exit 1; fi

#Check if file exists
if [ ! -f "${poolName}.node.vkey" ]; then echo -e "\n\e[33mERROR - \"${poolName}.node.vkey\" does not exist.\e[0m"; exit 1; fi

#Get the poolID
poolID=$(${cardanocli} shelley stake-pool id --verification-key-file ${poolName}.node.vkey)     #New method since 1.13.0

echo
echo -e "\e[0mChecking\e[32m ${poolName}.node.vkey\e[0m about the Pool-ID: ${poolID}"
echo
