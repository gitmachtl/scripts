#!/bin/bash

# Script is brought to you by ATADA_Stakepool, Telegram @atada_stakepool

#load variables from common.sh
#       socket          Path to the node.socket (also exports socket to CARDANO_NODE_SOCKET_PATH)
#       genesisfile     Path to the genesis.json
#       magicparam      TestnetMagic parameter
#       cardanocli      Path to the cardano-cli executable
#       cardanonode     Path to the cardano-node executable
. "$(dirname "$0")"/00_common.sh

#Check the commandline parameter
if [[ $# -eq 1 && ! $1 == "" ]]; then addrName=$1; else echo "ERROR - Usage: $0 <AdressName or HASH>"; exit 2; fi

#Check if Address file doesn not exists, make a dummy one in the temp directory and fill in the given parameter as the hash address
if [ ! -f "$1.addr" ]; then echo "$1" > ${tempDir}/tempAddr.addr; addrName="${tempDir}/tempAddr"; fi

checkAddr=$(cat ${addrName}.addr)

typeOfAddr=$(get_addressType "${checkAddr}")

#What type of Address is it? Stake?
if [[ ${typeOfAddr} == ${addrTypeStake} ]]; then  #Staking Address

	echo
	echo -e "\e[0mChecking ChainStatus of Stake-Address-File\e[32m ${addrName}.addr\e[0m: ${checkAddr}"
	echo

        rewardsAmount=$(${cardanocli} shelley query stake-address-info --address ${checkAddr} ${magicparam} | jq -r "flatten | .[0].rewardAccountBalance")

	#Checking about the content
        if [[ ${rewardsAmount} == null ]]; then echo -e "\e[35mStaking Address is NOT on the chain, register it first !\e[0m\n";
	else echo -e "\e[32mStaking Address is on the chain !\e[0m\n"
	fi

else #unsupported address type

	echo -e "\e[35mAddress type unknown!\e[0m";
fi

