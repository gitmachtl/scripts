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
if [[ $# -eq 1 && ! $1 == "" ]]; then addrName="$(dirname $1)/$(basename $1 .addr)"; addrName=${addrName/#.\//}; else echo "ERROR - Usage: $0 <AdressName or HASH>"; exit 2; fi

#Check if Address file doesn not exists, make a dummy one in the temp directory and fill in the given parameter as the hash address
if [ ! -f "${addrName}.addr" ]; then echo "${addrName}" > ${tempDir}/tempAddr.addr; addrName="${tempDir}/tempAddr"; fi

checkAddr=$(cat ${addrName}.addr)

typeOfAddr=$(get_addressType "${checkAddr}"); checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi;

#What type of Address is it? Base&Enterprise or Stake
if [[ ${typeOfAddr} == ${addrTypePayment} ]]; then  #Enterprise and Base UTXO adresses

	echo -e "\e[0mChecking UTXOs of Address-File\e[32m ${addrName}.addr\e[0m: ${checkAddr}"
	echo

	echo -e "\e[0mAddress-Type / Era:\e[32m $(get_addressType "${checkAddr}")\e[0m / \e[32m$(get_addressEra "${checkAddr}")\e[0m"
	echo

	#Get UTX0 Data for the address. When in online mode of course from the node and the chain, in offlinemode from the transferFile
	#${nodeEraParam} not needed anymore
	if ${onlineMode}; then
				utxo=$(${cardanocli} query utxo --address ${checkAddr} ${magicparam} ); checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi;
				utxoJSON=$(generate_UTXO "${utxo}" "${checkAddr}")
			  else
                                readOfflineFile;        #Reads the offlinefile into the offlineJSON variable
                                utxoJSON=$(jq -r ".address.\"${checkAddr}\".utxoJSON" <<< ${offlineJSON})
                                if [[ "${utxoJSON}" == null ]]; then echo -e "\e[35mAddress not included in the offline transferFile, please include it first online!\e[0m\n"; exit 1; fi
	fi

        utxoEntryCnt=$(jq length <<< ${utxoJSON})
        if [[ ${utxoEntryCnt} == 0 ]]; then echo -e "\e[35mNo funds on the Address!\e[0m\n"; exit 1; else echo -e "\e[32m${utxoEntryCnt} UTXOs\e[0m found on the Address!"; fi
        echo

	totalLovelaces=0;	#Init for the Sum
	totalAssetsJSON="{}"; #Building a total JSON with the different assetstypes "policyIdHash.name", amount and name
	totalPolicyIDsJSON="{}"; #Holds the different PolicyIDs as values "policyIDHash", length is the amount of different policyIDs

	#For each utxo entry, check the utxo#index and check if there are also any assets in that utxo#index
	#LEVEL 1 - different UTXOs
	for (( tmpCnt=0; tmpCnt<${utxoEntryCnt}; tmpCnt++ ))
	do
	utxoHashIndex=$(jq -r "keys_unsorted[${tmpCnt}]" <<< ${utxoJSON})
	utxoAmount=$(jq -r ".\"${utxoHashIndex}\".value.lovelace" <<< ${utxoJSON})   #Lovelaces
        totalLovelaces=$(bc <<< "${totalLovelaces} + ${utxoAmount}" )
	echo -e "Hash#Index: ${utxoHashIndex}\tAmount: ${utxoAmount}"; utxoDataEntry=$(jq -r ".\"${utxoHashIndex}\".data" <<< ${utxoJSON}); if [[ ! "${utxoDataEntry}" == null ]]; then echo -e "  DataHash: ${utxoDataEntry}"; fi
	assetsJSON=$(jq -r ".\"${utxoHashIndex}\".value | del (.lovelace)" <<< ${utxoJSON}) #All values without the lovelaces entry
	assetsEntryCnt=$(jq length <<< ${assetsJSON})

	if [[ ${assetsEntryCnt} -gt 0 ]]; then
			#LEVEL 2 - different policyIDs
			for (( tmpCnt2=0; tmpCnt2<${assetsEntryCnt}; tmpCnt2++ ))
		        do
		        assetHash=$(jq -r "keys_unsorted[${tmpCnt2}]" <<< ${assetsJSON})  #assetHash = policyID
			assetsNameCnt=$(jq ".\"${assetHash}\" | length" <<< ${assetsJSON})
			totalPolicyIDsJSON=$( jq ". += {\"${assetHash}\": 1}" <<< ${totalPolicyIDsJSON})

				#LEVEL 3 - different names under the same policyID
				for (( tmpCnt3=0; tmpCnt3<${assetsNameCnt}; tmpCnt3++ ))
	                        do
                        	assetName=$(jq -r ".\"${assetHash}\" | keys_unsorted[${tmpCnt3}]" <<< ${assetsJSON})
				assetAmount=$(jq -r ".\"${assetHash}\".\"${assetName}\"" <<< ${assetsJSON})
				assetBech=$(convert_tokenName2BECH "${assetHash}${assetName}" "")
				if [[ "${assetName}" == "" ]]; then point=""; else point="."; fi
				oldValue=$(jq -r ".\"${assetHash}${point}${assetName}\".amount" <<< ${totalAssetsJSON})
				newValue=$(bc <<< "${oldValue}+${assetAmount}")
				assetTmpName=$(convert_assetNameHEX2ASCII_ifpossible "${assetName}") #if it starts with a . -> ASCII showable name, otherwise the HEX-String
				totalAssetsJSON=$( jq ". += {\"${assetHash}${point}${assetName}\":{amount: \"${newValue}\", name: \"${assetTmpName}\", bech: \"${assetBech}\"}}" <<< ${totalAssetsJSON})
				if [[ "${assetTmpName:0:1}" == "." ]]; then assetTmpName=${assetTmpName:1}; else assetTmpName="{${assetTmpName}}"; fi
        	                echo -e "\e[90m                           Asset: ${assetBech}  Amount: ${assetAmount} ${assetTmpName}\e[0m"
				done
			done

	fi
	done
	echo -e "\e[0m-----------------------------------------------------------------------------------------------------"
	echo -e "Total ADA on the Address:\e[32m $(convertToADA ${totalLovelaces}) ADA / ${totalLovelaces} lovelaces \e[0m\n"

	totalPolicyIDsCnt=$(jq length <<< ${totalPolicyIDsJSON});

        #Get a sorted list of the AssetHashes into a separate Array
        #totalAssetsHASHsorted=$(jq "keys | sort_by( split(\".\")[1]|length) | sort_by( split(\".\")[0])" 2> /dev/null <<< ${totalAssetsJSON})

	totalAssetsCnt=$(jq length <<< ${totalAssetsJSON});
	if [[ ${totalAssetsCnt} -gt 0 ]]; then
			echo -e "\e[32m${totalAssetsCnt} Asset-Type(s) / ${totalPolicyIDsCnt} different PolicyIDs\e[0m found on the Address!\n"
			printf "\e[0m%-56s%11s    %16s %-44s  %7s  %s\n" "PolicyID:" "Asset-Name:" "Total-Amount:" "Bech-Format:" "Ticker:" "Meta-Name:"
                        for (( tmpCnt=0; tmpCnt<${totalAssetsCnt}; tmpCnt++ ))
                        do
			assetHashName=$(jq -r "keys[${tmpCnt}]" <<< ${totalAssetsJSON})
			#assetHashName=$(jq -r ".[${tmpCnt}]" <<< ${totalAssetsHASHsorted})
                        assetAmount=$(jq -r ".\"${assetHashName}\".amount" <<< ${totalAssetsJSON})
			assetName=$(jq -r ".\"${assetHashName}\".name" <<< ${totalAssetsJSON})
			assetBech=$(jq -r ".\"${assetHashName}\".bech" <<< ${totalAssetsJSON})
			#assetHashHex="${assetHashName:0:56}$(convert_assetNameASCII2HEX ${assetName})"
			assetHashHex="${assetHashName//./}" #remove a . if present, we need a clean subject here for the registry request

			if $queryTokenRegistry; then if $onlineMode; then metaResponse=$(curl -sL -m 20 "${tokenMetaServer}${assetHashHex}"); else metaResponse=$(jq -r ".tokenMetaServer.\"${assetHashHex}\"" <<< ${offlineJSON}); fi
				metaAssetName=$(jq -r ".name.value | select (.!=null)" 2> /dev/null <<< ${metaResponse}); if [[ ! "${metaAssetName}" == "" ]]; then metaAssetName="${metaAssetName} "; fi
				metaAssetTicker=$(jq -r ".ticker.value | select (.!=null)" 2> /dev/null <<< ${metaResponse})
			fi

			if [[ "${assetName}" == "." ]]; then assetName=""; fi

			printf "\e[90m%-70s \e[32m%16s %44s  \e[90m%-7s  \e[36m%s\e[0m\n" "${assetHashName:0:56}${assetName}" "${assetAmount}" "${assetBech}" "${metaAssetTicker}" "${metaAssetName}"
			done
        fi
	echo

#jq . <<< ${totalAssetsJSON}


elif [[ ${typeOfAddr} == ${addrTypeStake} ]]; then  #Staking Address

	echo -e "\e[0mChecking Rewards on Stake-Address-File\e[32m ${addrName}.addr\e[0m: ${checkAddr}"
	echo

        echo -e "\e[0mAddress-Type / Era:\e[32m $(get_addressType "${checkAddr}")\e[0m / \e[32m$(get_addressEra "${checkAddr}")\e[0m"
        echo

        #Get rewards state data for the address. When in online mode of course from the node and the chain, in offlinemode from the transferFile
        if ${onlineMode}; then
				rewardsJSON=$(${cardanocli} query stake-address-info --address ${checkAddr} ${magicparam} | jq -rc .)
                          else
                                rewardsJSON=$(cat ${offlineFile} | jq -r ".address.\"${checkAddr}\".rewardsJSON" 2> /dev/null)
                                if [[ "${rewardsJSON}" == null ]]; then echo -e "\e[35mAddress not included in the offline transferFile, please include it first online!\e[0m\n"; exit; fi
        fi
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

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

