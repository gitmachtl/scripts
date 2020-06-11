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
if [[ $# -eq 1 && ! $1 == "" ]]; then addrName=$1; else echo "ERROR - Usage: $0 <StakeAdressName>"; exit 2; fi

#Checks for needed files
if [ ! -f "${addrName}.addr" ]; then echo -e "\n\e[35mERROR - \"${addrName}.addr\" does not exist!\e[0m"; exit 1; fi

stakingAddr=$(cat ${addrName}.addr)

echo
echo -e "\e[0mChecking Rewards on Stake-Address-File\e[32m ${addrName}.addr\e[0m: ${stakingAddr}"
echo

rewardsAmount=$(${cardanocli} shelley query stake-address-info --address ${stakingAddr} --testnet-magic 42 | jq 'flatten | .[0].rewardAccountBalance')

echo -e "Current Rewards: \e[33m${rewardsAmount} lovelaces\e[0m"

#Checking about rewards on the stake address
if [[ ${rewardsAmount} == 0 ]]; then echo -e "\e[35mNo rewards on the stake Addr!\e[0m\n"; exit; fi

