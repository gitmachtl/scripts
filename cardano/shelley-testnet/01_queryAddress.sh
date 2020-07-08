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

#What type of Address is it? Base&Enterprise or Stake
if [[ ${typeOfAddr} == ${addrTypePayment} ]]; then  #Enterprise and Base UTXO adresses

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

	#rewardsAmount=$(${cardanocli} shelley query stake-address-info --address ${checkAddr} ${magicparam} | jq -r .\"${checkAddr}\".rewardAccountBalance)
        rewardsAmount=$(${cardanocli} shelley query stake-address-info --address ${checkAddr} ${magicparam} | jq -r "flatten | .[0].rewardAccountBalance")
	delegationPoolID=$(${cardanocli} shelley query stake-address-info --address ${checkAddr} ${magicparam} | jq -r "flatten | .[0].delegation")

	#Checking about rewards on the stake address
	if [[ ${rewardsAmount} == 0 ]]; then echo -e "\e[35mNo rewards found on the stake Addr !\e[0m\n";
        elif [[ ${rewardsAmount} == null ]]; then echo -e "\e[35mStaking Address is not on the chain, register it first !\e[0m\n";
	else echo -e "Current Rewards: \e[33m${rewardsAmount} lovelaces\e[0m\n"
	fi

        #If delegated to a pool, show the current pool ID
        if [[ ! ${delegationPoolID} == null ]]; then echo -e "Account is delegated to a Pool with ID: \e[32m${delegationPoolID}\e[0m\n"; fi

else #unsupported address type

	echo -e "\e[35mAddress type unknown!\e[0m";
fi

