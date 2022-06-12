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
if [[ $# -eq 1 && ! $1 == "" ]]; then addrName="$(dirname $1)/$(basename $(basename $1 .addr) .staking)"; addrName=${addrName/#.\//}; else echo "ERROR - Usage: $0 <AdressName or HASH>"; exit 2; fi

#Check can only be done in online mode
if ${offlineMode}; then echo -e "\e[35mYou have to be in ONLINE MODE to do this!\e[0m\n"; exit 1; fi

#Check if Address file doesn not exists, make a dummy one in the temp directory and fill in the given parameter as the hash address
if [ ! -f "${addrName}.staking.addr" ]; then echo "$(basename ${addrName})" > ${tempDir}/tempAddr.staking.addr; addrName="${tempDir}/tempAddr"; fi

checkAddr=$(cat ${addrName}.staking.addr)

typeOfAddr=$(get_addressType "${checkAddr}")

#What type of Address is it? Stake?
if [[ ${typeOfAddr} == ${addrTypeStake} ]]; then  #Staking Address

	echo -e "\e[0mChecking ChainStatus of Stake-Address-File\e[32m ${addrName}.staking.addr\e[0m: ${checkAddr}"
	echo

        rewardsAmount=$(${cardanocli} query stake-address-info --address ${checkAddr} ${magicparam} | jq -r "flatten | .[0].rewardAccountBalance")
	checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
	delegationPoolID=$(${cardanocli} query stake-address-info --address ${checkAddr} ${magicparam} | jq -r "flatten | .[0].delegation")
	checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

	#Checking about the content
        if [[ ${rewardsAmount} == null ]]; then echo -e "\e[35mStaking Address is NOT on the chain, register it first !\e[0m\n";
	else echo -e "\e[32mStaking Address is on the chain !\e[0m\n"
	fi

	#If delegated to a pool, show the current pool ID
        if [[ ! ${delegationPoolID} == null ]]; then
		echo -e "Account is delegated to a Pool with ID: \e[32m${delegationPoolID}\e[0m\n";

		#query poolinfo via poolid on koios
		showProcessAnimation "Query Pool-Info via Koios: " &
		response=$(curl -s -m 10 -X POST "${koiosAPI}/pool_info" -H "Accept: application/json" -H "Content-Type: application/json" -d "{\"_pool_bech32_ids\":[\"${delegationPoolID}\"]}" 2> /dev/null)
		stopProcessAnimation;
		#check if the received json only contains one entry in the array (will also not be 1 if not a valid json)
		if [[ $(jq ". | length" 2> /dev/null <<< ${response}) -eq 1 ]]; then
			poolName=$(jq -r ".[0].meta_json.name | select (.!=null)" 2> /dev/null <<< ${response})
			poolTicker=$(jq -r ".[0].meta_json.ticker | select (.!=null)" 2> /dev/null <<< ${response})
			echo -e "\e[0mInformation about the Pool: \e[32m${poolName} (${poolTicker})\e[0m"
			echo
		fi

	fi

else #unsupported address type

	echo -e "\e[35mAddress type unknown!\e[0m";
fi

