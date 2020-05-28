#!/bin/bash

#load variables from common.sh
#       socket          Path to the node.socket (also exports socket to CARDANO_NODE_SOCKET_PATH)
#       genesisfile     Path to the genesis.json
#       magicparam      TestnetMagic paramter
. "$(dirname "$0")"/00_common.sh

if [[ ! $1 == "" ]]; then poolName=$1; else echo "ERROR - Usage: $0 <PoolName>"; exit 2; fi

poolID=$(cat ${poolName}.pool.id)

echo
echo -e "\e[0mChecking about Pool-ID \e[32m ${poolName}.pool.id\e[0m: ${poolID}"
echo

#check ledger-state
poolInLedgerCnt=$(${cardanocli} shelley query ledger-state ${magicparam} | grep "poolPubKey" | grep  "${poolID}" | wc -l)

if [[ ${poolInLedgerCnt} -gt 0 ]]; then 
					echo -e "\e[32mPool-ID is on the chain!\e[0m";
				    else
					echo -e "\e[35mPool-ID is NOT on the chain!\e[0m";
fi
echo
