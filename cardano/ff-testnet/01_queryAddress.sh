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
if [[ $# -eq 1 && ! $1 == "" ]]; then addrName=$1; else echo "ERROR - Usage: $0 <AdressName>"; exit 2; fi

checkAddr=$(cat ${addrName}.addr)

typeOfAddr=${checkAddr:0:2}

#What type of address is it? Base&Enterprise or Stake
if [[ ${typeOfAddr} == ${addrTypeEnterprise} || ${typeOfAddr} == ${addrTypeBase} ]]; then  #Enterprise and Base UTXO adresses

	echo
	echo -e "\e[0mChecking UTXO of Address-File\e[32m ${addrName}.addr\e[0m: ${checkAddr}"
	echo

	#Get UTX0 Data for the address
	utx0=$(${cardanocli} shelley query utxo --address ${checkAddr} ${magicparam})
	utx0linecnt=$(echo "${utx0}" | wc -l)
	txcnt=$((${utx0linecnt}-2))

	if [[ ${txcnt} -lt 1 ]]; then echo -e "\e[35mNo funds on the Address!\e[0m"; exit; else echo -e "\e[32m${txcnt} UTXOs\e[0m found on the Address!"; fi
	echo

	#Calculating the total amount of lovelaces in all utxos on this address
	totalLovelaces=0

	while IFS= read -r utx0entry
	do
	fromHASH=$(echo ${utx0entry} | awk '{print $1}')
	fromINDEX=$(echo ${utx0entry} | awk '{print $2}')
	sourceLovelaces=$(echo ${utx0entry} | awk '{print $3}')
	echo -e "HASH: ${fromHASH}\tIdx: ${fromINDEX}\tAmount: ${sourceLovelaces}"
	totalLovelaces=$((${totalLovelaces}+${sourceLovelaces}))
	done < <(printf "${utx0}\n" | tail -n ${txcnt})

	echo -e "\e[0m-----------------------------------------------------------------------------------------------------"
	echo -e "Total lovelaces in UTX0:\e[32m  ${totalLovelaces} lovelaces \e[0m"
	echo

elif [[ ${typeOfAddr} == ${addrTypeStake} ]]; then  #Staking Address

	echo
	echo -e "\e[0mChecking Rewards on Stake-Address-File\e[32m ${addrName}.addr\e[0m: ${checkAddr}"
	echo

	rewardsAmount=$(${cardanocli} shelley query stake-address-info --address ${checkAddr} --testnet-magic 42 | jq -r .\"${checkAddr}\".rewardAccountBalance)

	#Checking about rewards on the stake address
	if [[ ${rewardsAmount} == 0 ]]; then echo -e "\e[35mNo rewards found on the stake Addr!\e[0m\n"; exit; fi

	echo -e "Current Rewards: \e[33m${rewardsAmount} lovelaces\e[0m\n"

else #unsupported address type

	echo -e "\e[35mAddress type unknown!\e[0m";

fi

