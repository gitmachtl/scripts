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
	echo -e "\e[0mChecking UTXOs of Address-File\e[32m ${addrName}.addr\e[0m: ${checkAddr}"
	echo

	#Get UTX0 Data for the address
	utxoJSON=$(${cardanocli} ${subCommand} query utxo --address ${checkAddr} --cardano-mode ${magicparam} ${nodeEraParam} --out-file /dev/stdout); checkError "$?";
	utxoEntryCnt=$(jq length <<< ${utxoJSON})
	if [[ ${utxoEntryCnt} == 0 ]]; then echo -e "\e[35mNo funds on the Address!\e[0m\n"; exit; else echo -e "\e[32m${utxoEntryCnt} UTXOs\e[0m found on the Address!"; fi
	echo

	#Calculating the total amount of lovelaces in all utxos on this address
	totalLovelaces=$(jq '[.[].amount] | add' <<< ${utxoJSON})

	for (( tmpCnt=0; tmpCnt<${utxoEntryCnt}; tmpCnt++ ))
	do
	utxoHashIndex=$(jq -r "keys[${tmpCnt}]" <<< ${utxoJSON})
	#utxoAmount=$(jq -r "[.[].amount] | .[${tmpCnt}]" <<< ${utxoJSON}) #Alternative
	#utxoAmount=$(jq -r "[.[]][${tmpCnt}].amount" <<< ${utxoJSON}) #Alternative
	utxoAmount=$(jq -r ".\"${utxoHashIndex}\".amount" <<< ${utxoJSON})
	echo -e "Hash#Index: ${utxoHashIndex}\tAmount: ${utxoAmount}"
	done
	echo -e "\e[0m-----------------------------------------------------------------------------------------------------"
	totalInADA=$(bc <<< "scale=6; ${totalLovelaces} / 1000000")
	echo -e "Total balance on the Address:\e[32m  ${totalInADA} ADA / ${totalLovelaces} lovelaces \e[0m"
	echo

elif [[ ${typeOfAddr} == ${addrTypeStake} ]]; then  #Staking Address

	echo
	echo -e "\e[0mChecking Rewards on Stake-Address-File\e[32m ${addrName}.addr\e[0m: ${checkAddr}"
	echo

        rewardsJSON=$(${cardanocli} ${subCommand} query stake-address-info --address ${checkAddr} --cardano-mode ${magicparam} ${nodeEraParam} | jq -rc .)
        checkError "$?"

        rewardsEntryCnt=$(jq -r 'length' <<< ${rewardsJSON})

        if [[ ${rewardsEntryCnt} == 0 ]]; then echo -e "\e[35mStaking Address is not on the chain, register it first !\e[0m\n"; exit 1;
        else echo -e "\e[0mFound:\e[32m ${rewardsEntryCnt}\e[0m entries\n";
        fi

        rewardsSum=0

        for (( tmpCnt=0; tmpCnt<${rewardsEntryCnt}; tmpCnt++ ))
        do
        rewardsAmount=$(jq -r ".[${tmpCnt}].rewardAccountBalance" <<< ${rewardsJSON})
	rewardsAmountInADA=$(bc <<< "scale=6; ${rewardsAmount} / 1000000")

        delegationPoolID=$(jq -r ".[${tmpCnt}].delegation" <<< ${rewardsJSON})

        rewardsSum=$((${rewardsSum}+${rewardsAmount}))
	rewardsSumInADA=$(bc <<< "scale=6; ${rewardsSum} / 1000000") 

        echo -ne "[$((${tmpCnt}+1))]\t"

        #Checking about rewards on the stake address
        if [[ ${rewardsAmount} == 0 ]]; then echo -e "\e[35mNo rewards found on the stake Addr !\e[0m";
        else echo -e "Entry Rewards: \e[33m${rewardsAmountInADA} ADA / ${rewardsAmount} lovelaces\e[0m"
        fi

        #If delegated to a pool, show the current pool ID
        if [[ ! ${delegationPoolID} == null ]]; then echo -e "   \tAccount is delegated to a Pool with ID: \e[32m${delegationPoolID}\e[0m"; fi

        echo

        done

        if [[ ${rewardsEntryCnt} -gt 1 ]]; then echo -e "   \t-----------------------------------------\n"; echo -e "   \tTotal Rewards: \e[33m${rewardsSumInADA} ADA / ${rewardsSum} lovelaces\e[0m\n"; fi

else #unsupported address type

	echo -e "\e[35mAddress type unknown!\e[0m";
fi

