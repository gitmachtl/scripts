#!/bin/bash

############################################################
#    _____ ____  ____     _____           _       __
#   / ___// __ \/ __ \   / ___/__________(_)___  / /______
#   \__ \/ /_/ / / / /   \__ \/ ___/ ___/ / __ \/ __/ ___/
#  ___/ / ____/ /_/ /   ___/ / /__/ /  / / /_/ / /_(__  )
# /____/_/    \____/   /____/\___/_/  /_/ .___/\__/____/
#                                    /_/
#
# Scripts are brought to you by Martin L. (ATADA Stakepool)
# Telegram: @atada_stakepool   Github: github.com/gitmachtl
#
############################################################

#load variables and functions from common.sh
. "$(dirname "$0")"/00_common.sh

#Check the commandline parameter
if [[ $# -eq 1 && ! $1 == "" ]]; then addrName="$(dirname $1)/$(basename $1 .addr)"; addrName=${addrName/#.\//}; else echo "ERROR - Usage: $0 <AdressName or HASH or '\$adahandle'>"; exit 2; fi


#Check if addrName file does not exists, make a dummy one in the temp directory and fill in the given parameter as the hash address
if [ ! -f "${addrName}.addr" ]; then
                                addrName=$(trimString "${addrName}") #trim it if spaces present

                                #check if its a regular cardano payment address
                                typeOfAddr=$(get_addressType "${addrName}");
                                if [[ ${typeOfAddr} == ${addrTypePayment} || ${typeOfAddr} == ${addrTypeStake} ]]; then echo "$(basename ${addrName})" > ${tempDir}/tempAddr.addr; addrName="${tempDir}/tempAddr";

                                #check if its an adahandle (root/sub/virtual)
                                elif checkAdaHandleFormat "${addrName}"; then

                                        adahandleName=${addrName,,}

					#resolve given adahandle into address
					resolveAdahandle "${adahandleName}" "addrName" #if successful, it resolves the adahandle and writes it out into the variable 'addrName'. also sets the variable 'utxo' if possible

					#resolveAdahandle did not exit with an error, so we resolved it
                                        echo "${addrName}" > ${tempDir}/adahandle-resolve.addr; addrName="${tempDir}/adahandle-resolve";

                                #otherwise post an error message
                                else echo -e "\n\e[35mERROR - Destination Address can't be resolved. Maybe filename wrong, or not a payment- or stake-address.\n\e[0m"; exit 1;
                                fi
fi

showToAddr=${adahandleName:-"${addrName}.addr"} #shows the adahandle instead of the destination address file if available

checkAddr=$(cat ${addrName}.addr)

typeOfAddr=$(get_addressType "${checkAddr}"); checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi;

#What type of Address is it? Base&Enterprise or Stake
if [[ ${typeOfAddr} == ${addrTypePayment} ]]; then  #Enterprise and Base UTXO adresses

	echo -e "\e[0mChecking UTXOs of Payment-Address\e[32m ${showToAddr}\e[0m: ${checkAddr}"
	echo

	echo -e "\e[0mAddress-Type / Era:\e[32m $(get_addressType "${checkAddr}")\e[0m / \e[32m$(get_addressEra "${checkAddr}")\e[0m"
	echo

	#Get UTX0 Data for the address. When in online mode of course from the node and the chain, in lightmode via API requests, in offlinemode from the transferFile
	case ${workMode} in
		"online")	if [[ "${utxo}" == "" ]]; then #only query it again if not already queried via an adahandle check before
					#check that the node is fully synced, otherwise the query would mabye return a false state
					if [[ $(get_currentSync) != "synced" ]]; then echo -e "\e[35mError - Node not fully synced or not running, please let your node sync to 100% first !\e[0m\n"; exit 1; fi
					showProcessAnimation "Query-UTXO: " &
					utxo=$(${cardanocli} ${cliEra} query utxo --address ${checkAddr} 2> /dev/stdout);
					if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${utxo}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
				fi
				showProcessAnimation "Convert-UTXO: " &
				utxoJSON=$(generate_UTXO "${utxo}" "${checkAddr}"); stopProcessAnimation;
				;;

		"light")	if [[ "${utxo}" == "" ]]; then #only query it again if not already queried via an adahandle check before
					showProcessAnimation "Query-UTXO-LightMode: " &
					utxo=$(queryLight_UTXO "${checkAddr}");
					if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${utxo}\e[0m\n"; exit $?; else stopProcessAnimation;	fi;
				fi
				showProcessAnimation "Convert-UTXO: " &
				utxoJSON=$(generate_UTXO "${utxo}" "${checkAddr}"); stopProcessAnimation;
				;;


		"offline")      readOfflineFile;        #Reads the offlinefile into the offlineJSON variable
                                utxoJSON=$(jq -r ".address.\"${checkAddr}\".utxoJSON" <<< ${offlineJSON} 2> /dev/null)
                                if [[ "${utxoJSON}" == null ]]; then echo -e "\e[35mAddress not included in the offline transferFile, please include it first online!\e[0m\n"; exit 1; fi
				;;
	esac

        utxoEntryCnt=$(jq length <<< ${utxoJSON})
        if [[ ${utxoEntryCnt} == 0 ]]; then echo -e "\e[35mNo funds on the Address!\e[0m\n"; exit 1; else echo -e "\e[32m${utxoEntryCnt} UTXOs\e[0m found on the Address!"; fi
        echo

	totalLovelaces=0;	#Init for the Sum
	totalAssetsJSON="{}"; #Building a total JSON with the different assetstypes "policyIdHash.name", amount and name
	totalPolicyIDsLIST=""; #Buffer for the policyIDs, will be sorted/uniq/linecount at the end of the query

	#For each utxo entry, check the utxo#index and check if there are also any assets in that utxo#index
	#LEVEL 1 - different UTXOs

	readarray -t utxoHashIndexArray <<< $(jq -r "keys_unsorted[]" <<< ${utxoJSON})
	readarray -t utxoLovelaceArray <<< $(jq -r "flatten | .[].value.lovelace" <<< ${utxoJSON})
	readarray -t assetsEntryCntArray <<< $(jq -r "flatten | .[].value | del (.lovelace) | length" <<< ${utxoJSON})
	readarray -t assetsEntryJsonArray <<< $(jq -c "flatten | .[].value | del (.lovelace)" <<< ${utxoJSON})
	readarray -t utxoDatumHashArray <<< $(jq -r "flatten | .[].datumhash" <<< ${utxoJSON})


	for (( tmpCnt=0; tmpCnt<${utxoEntryCnt}; tmpCnt++ ))
	do
	utxoHashIndex=${utxoHashIndexArray[${tmpCnt}]}
	utxoAmount=${utxoLovelaceArray[${tmpCnt}]} #Lovelaces
        totalLovelaces=$(bc <<< "${totalLovelaces} + ${utxoAmount}" )
#	echo -e "Hash#Index: ${utxoHashIndex}\tAmount: ${utxoAmount}";
        echo -e "Hash#Index: ${utxoHashIndex}\tADA: $(convertToADA ${utxoAmount}) \e[90m(${utxoAmount} lovelaces)\e[0m";
	if [[ ! "${utxoDatumHashArray[${tmpCnt}]}" == null ]]; then echo -e " DatumHash: ${utxoDatumHashArray[${tmpCnt}]}"; fi
	assetsEntryCnt=${assetsEntryCntArray[${tmpCnt}]}

	if [[ ${assetsEntryCnt} -gt 0 ]]; then

			assetsJSON=${assetsEntryJsonArray[${tmpCnt}]}
			assetHashIndexArray=(); readarray -t assetHashIndexArray <<< $(jq -r "keys_unsorted[]" <<< ${assetsJSON})
			assetNameCntArray=(); readarray -t assetNameCntArray <<< $(jq -r "flatten | .[] | length" <<< ${assetsJSON})

			#LEVEL 2 - different policyIDs
			for (( tmpCnt2=0; tmpCnt2<${assetsEntryCnt}; tmpCnt2++ ))
		        do
		        assetHash=${assetHashIndexArray[${tmpCnt2}]} #assetHash = policyID
			totalPolicyIDsLIST+="${assetHash}\n"

			assetsNameCnt=${assetNameCntArray[${tmpCnt2}]}
			assetNameArray=(); readarray -t assetNameArray <<< $(jq -r ".\"${assetHash}\" | keys_unsorted[]" <<< ${assetsJSON})
			assetAmountArray=(); readarray -t assetAmountArray <<< $(jq -r ".\"${assetHash}\" | flatten | .[]" <<< ${assetsJSON})

				#LEVEL 3 - different names under the same policyID
				for (( tmpCnt3=0; tmpCnt3<${assetsNameCnt}; tmpCnt3++ ))
	                        do
                        	assetName=${assetNameArray[${tmpCnt3}]}
				assetAmount=${assetAmountArray[${tmpCnt3}]}
				assetBech=$(convert_tokenName2BECH "${assetHash}${assetName}" "")
				if [[ "${assetName}" == "" ]]; then point=""; else point="."; fi
				oldValue=$(jq -r ".\"${assetHash}${point}${assetName}\".amount" <<< ${totalAssetsJSON})
				newValue=$(bc <<< "${oldValue}+${assetAmount}")
				assetTmpName=$(convert_assetNameHEX2ASCII_ifpossible "${assetName}") #if it starts with a . -> ASCII showable name, otherwise the HEX-String
				totalAssetsJSON=$( jq ". += {\"${assetHash}${point}${assetName}\":{amount: \"${newValue}\", name: \"${assetTmpName}\", bech: \"${assetBech}\"}}" <<< ${totalAssetsJSON})
				if [[ "${assetTmpName:0:1}" == "." ]]; then assetTmpName=${assetTmpName:1}; else assetTmpName="{${assetTmpName}}"; fi

				case "${assetHash}${assetTmpName:1:8}" in
					"${adahandlePolicyID}000de140" )	#$adahandle cip-68
						assetName=${assetName:8};
						echo -e "\e[90m                           Asset: ${assetBech}  \e[33mADA Handle(Own): \$$(convert_assetNameHEX2ASCII ${assetName}) ${assetTmpName}\e[0m"
						;;
					"${adahandlePolicyID}00000000" )	#$adahandle virtual
						assetName=${assetName:8};
						echo -e "\e[90m                           Asset: ${assetBech}  \e[33mADA Handle(Vir): \$$(convert_assetNameHEX2ASCII ${assetName}) ${assetTmpName}\e[0m"
						;;
					"${adahandlePolicyID}000643b0" )	#$adahandle reference
						assetName=${assetName:8};
						echo -e "\e[90m                           Asset: ${assetBech}  \e[33mADA Handle(Ref): \$$(convert_assetNameHEX2ASCII ${assetName}) ${assetTmpName}\e[0m"
						;;
					"${adahandlePolicyID}"* )		#$adahandle cip-25
						echo -e "\e[90m                           Asset: ${assetBech}  \e[33mADA Handle: \$$(convert_assetNameHEX2ASCII ${assetName}) ${assetTmpName}\e[0m"
						;;
					* ) #default
		        	                echo -e "\e[90m                           Asset: ${assetBech}  Amount: ${assetAmount} ${assetTmpName}\e[0m"
						;;
				esac

				done
			done
	fi
	done
	echo -e "\e[0m-----------------------------------------------------------------------------------------------------"
	echo -e "Total ADA on the Address:\e[32m $(convertToADA ${totalLovelaces}) ADA / ${totalLovelaces} lovelaces \e[0m\n"

	totalPolicyIDsCnt=$(echo -ne "${totalPolicyIDsLIST}" | sort | uniq | wc -l)

	totalAssetsCnt=$(jq length <<< ${totalAssetsJSON});
	if [[ ${totalAssetsCnt} -gt 0 ]]; then
			echo -e "\e[32m${totalAssetsCnt} Asset-Type(s) / ${totalPolicyIDsCnt} different PolicyIDs\e[0m found on the Address!\n"
			printf "\e[0m%-56s%11s    %16s %-44s  %7s  %s\n" "PolicyID:" "Asset-Name:" "Total-Amount:" "Bech-Format:" "Ticker:" "Meta-Name:"

			totalAssetsJSON=$(jq --sort-keys . <<< ${totalAssetsJSON}) #sort the json by the hashname
			assetHashNameArray=(); readarray -t assetHashNameArray <<< $(jq -r "keys_unsorted[]" <<< ${totalAssetsJSON})
			assetAmountArray=(); readarray -t assetAmountArray <<< $(jq -r "flatten | .[].amount" <<< ${totalAssetsJSON})
			assetNameArray=(); readarray -t assetNameArray <<< $(jq -r "flatten | .[].name" <<< ${totalAssetsJSON})
			assetBechArray=(); readarray -t assetBechArray <<< $(jq -r "flatten | .[].bech" <<< ${totalAssetsJSON})

                        for (( tmpCnt=0; tmpCnt<${totalAssetsCnt}; tmpCnt++ ))
                        do
			assetHashName=${assetHashNameArray[${tmpCnt}]}
                        assetAmount=${assetAmountArray[${tmpCnt}]}
			assetName=${assetNameArray[${tmpCnt}]}
			assetBech=${assetBechArray[${tmpCnt}]}
			assetHashHex="${assetHashName//./}" #remove a . if present, we need a clean subject here for the registry request

			if $queryTokenRegistry; then if $onlineMode; then metaResponse=$(curl -sL -m 20 "${tokenMetaServer}/${assetHashHex}"); else metaResponse=$(jq -r ".tokenMetaServer.\"${assetHashHex}\"" <<< ${offlineJSON}); fi
				metaAssetName=$(jq -r ".name.value | select (.!=null)" 2> /dev/null <<< ${metaResponse}); if [[ ! "${metaAssetName}" == "" ]]; then metaAssetName="${metaAssetName} "; fi
				metaAssetTicker=$(jq -r ".ticker.value | select (.!=null)" 2> /dev/null <<< ${metaResponse})
			fi

			if [[ "${assetName}" == "." ]]; then assetName=""; fi

			printf "\e[90m%-70s \e[32m%16s %44s  \e[90m%-7s  \e[36m%s\e[0m\n" "${assetHashName:0:56}${assetName}" "${assetAmount}" "${assetBech}" "${metaAssetTicker}" "${metaAssetName}"
			done
        fi
	echo




elif [[ ${typeOfAddr} == ${addrTypeStake} ]]; then  #Staking Address

	echo -e "\e[0mChecking Rewards on Stake-Address\e[32m ${showToAddr}\e[0m: ${checkAddr}"
	echo

        echo -e "\e[0mAddress-Type / Era:\e[32m $(get_addressType "${checkAddr}")\e[0m / \e[32m$(get_addressEra "${checkAddr}")\e[0m"
        echo

        #Get rewards state data for the address. When in online mode of course from the node and the chain, in light mode via koios, in offlinemode from the transferFile
	case ${workMode} in

		"online")	showProcessAnimation "Query-StakeAddress-Info: " &
				rewardsJSON=$(${cardanocli} ${cliEra} query stake-address-info --address ${checkAddr} 2> /dev/null )
				if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${rewardsJSON}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
				rewardsJSON=$(jq -rc . <<< "${rewardsJSON}")
				;;

		"light")	showProcessAnimation "Query-StakeAddress-Info-LightMode: " &
				rewardsJSON=$(queryLight_stakeAddressInfo "${checkAddr}")
				if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${rewardsJSON}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
				;;

		"offline")      readOfflineFile;        #Reads the offlinefile into the offlineJSON variable
				rewardsJSON=$(jq -r ".address.\"${checkAddr}\".rewardsJSON" <<< ${offlineJSON} 2> /dev/null)
                                if [[ "${rewardsJSON}" == null ]]; then echo -e "\e[35mAddress not included in the offline transferFile, please include it first online!\e[0m\n"; exit; fi
				;;

        esac

        rewardsEntryCnt=$(jq -r 'length' <<< ${rewardsJSON})

        if [[ ${rewardsEntryCnt} == 0 ]]; then echo -e "\e[35mStaking Address is not on the chain, register it first !\e[0m\n"; exit 1;
        else echo -e "\e[0mFound:\e[32m ${rewardsEntryCnt}\e[0m entries\n";
        fi

        rewardsSum=0

        for (( tmpCnt=0; tmpCnt<${rewardsEntryCnt}; tmpCnt++ ))
        do
        rewardsAmount=$(jq -r ".[${tmpCnt}].rewardAccountBalance" <<< ${rewardsJSON})
	rewardsAmountInADA=$(bc <<< "scale=6; ${rewardsAmount} / 1000000")

        delegationPoolID=$(jq -r ".[${tmpCnt}].delegation // .[${tmpCnt}].stakeDelegation" <<< ${rewardsJSON})

        drepDelegationHASH=$(jq -r ".[${tmpCnt}].voteDelegation // \"notSet\"" <<< ${rewardsJSON})

        rewardsSum=$((${rewardsSum}+${rewardsAmount}))
	rewardsSumInADA=$(bc <<< "scale=6; ${rewardsSum} / 1000000")

        echo -ne "[$((${tmpCnt}+1))]\t"

        #Checking about rewards on the stake address
        if [[ ${rewardsAmount} == 0 ]]; then echo -e "\e[35mNo rewards found on the stake Addr !\e[0m";
        else echo -e "Entry Rewards: \e[33m${rewardsAmountInADA} ADA / ${rewardsAmount} lovelaces\e[0m"
        fi

        #If delegated to a pool, show the current pool ID
        if [[ ! ${delegationPoolID} == null ]]; then
		echo -e "   \tAccount is delegated to a Pool with ID: \e[32m${delegationPoolID}\e[0m";

                if [[ ${onlineMode} == true && ${koiosAPI} != "" ]]; then

                        #query poolinfo via poolid on koios
                        errorcnt=0; error=-1;
                        showProcessAnimation "Query Pool-Info via Koios: " &
                        while [[ ${errorcnt} -lt 5 && ${error} -ne 0 ]]; do #try a maximum of 5 times to request the information
                                error=0
			        response=$(curl -sL -m 30 -X POST -w "---spo-scripts---%{http_code}" "${koiosAPI}/pool_info" -H "${koiosAuthorizationHeader}" -H "Accept: application/json" -H "Content-Type: application/json" -d "{\"_pool_bech32_ids\":[\"${delegationPoolID}\"]}" 2> /dev/null)
                                if [[ $? -ne 0 ]]; then error=1; sleep 1; fi; #if there is an error, wait for a second and repeat
                                errorcnt=$(( ${errorcnt} + 1 ))
                        done
                        stopProcessAnimation;

                        #if no error occured, split the response string into JSON content and the HTTP-ResponseCode
                        if [[ ${error} -eq 0 && "${response}" =~ (.*)---spo-scripts---([0-9]*)* ]]; then

                                responseJSON="${BASH_REMATCH[1]}"
                                responseCode="${BASH_REMATCH[2]}"

                                #if the responseCode is 200 (OK) and the received json only contains one entry in the array (will also not be 1 if not a valid json)
                                if [[ ${responseCode} -eq 200 && $(jq ". | length" 2> /dev/null <<< ${responseJSON}) -eq 1 ]]; then
		                        { read poolNameInfo; read poolTickerInfo; read poolStatusInfo; } <<< $(jq -r ".[0].meta_json.name // \"-\", .[0].meta_json.ticker // \"-\", .[0].pool_status // \"-\"" 2> /dev/null <<< ${responseJSON})
                                        echo -e "   \t\e[0mInformation about the Pool: \e[32m${poolNameInfo} (${poolTickerInfo})\e[0m"
                                        echo -e "   \t\e[0m                    Status: \e[32m${poolStatusInfo}\e[0m"
                                        echo
					unset poolNameInfo poolTickerInfo poolStatusInfo
                                fi #responseCode & jsoncheck

                        fi #error & response
                        unset errorcnt error

                fi #onlineMode & koiosAPI

		else

		echo -e "   \tAccount is not delegated to a Pool !";

	fi

	#Show the current status of the voteDelegation
	case ${drepDelegationHASH} in
		"alwaysNoConfidence")
			#always-no-confidence
			echo -e "   \t\e[0mVoting-Power of Staking Address is currently set to: \e[94mALWAYS NO CONFIDENCE\e[0m\n";
			;;

		"alwaysAbstain")
			#always-abstain
			echo -e "   \t\e[0mVoting-Power of Staking Address is currently set to: \e[94mALWAYS ABSTAIN\e[0m\n";
			;;

		"notSet")
			#no votingpower delegated
			echo -e "   \t\e[0mVoting-Power of Staking Address is not delegated to a DRep !\e[0m\n";
			;;

		*)
			#normal drep-id or drep-script-id
			case "${drepDelegationHASH%%-*}" in
				"keyHash")	drepDelegationID=$(${bech32_bin} "drep" <<< "${drepDelegationHASH##*-}" 2> /dev/null)
						echo -e "   \t\e[0mVoting-Power of Staking Address is delegated to DRepID(HASH): \e[32m${drepDelegationID}\e[0m (\e[94m${drepDelegationHASH##*-}\e[0m)\n";
						;;
				"scriptHash")   drepDelegationID=$(${bech32_bin} "drep_script" <<< "${drepDelegationHASH##*-}" 2> /dev/null)
						echo -e "   \t\e[0mVoting-Power of Staking Address is delegated to DRep-Script-ID(HASH): \e[32m${drepDelegationID}\e[0m (\e[94m${drepDelegationHASH##*-}\e[0m)\n";
						;;
				"null")		#not delegated
						echo -e "   \t\e[0mVoting-Power of Staking Address is not delegated to a DRep !\e[0m\n";
						;;
				*)		#unknown type
						echo -e "   \t\e[0mVoting-Power of Staking Address is delegated to DRep-HASH: \e[32m${drepDelegationHASH}\e[0m\n";
						;;
			esac
			;;

	esac

        echo

        done

        if [[ ${rewardsEntryCnt} -gt 1 ]]; then echo -e "   \t-----------------------------------------\n"; echo -e "   \tTotal Rewards: \e[33m${rewardsSumInADA} ADA / ${rewardsSum} lovelaces\e[0m\n"; fi

else #unsupported address type

	echo -e "\e[35mAddress type unknown!\e[0m";
fi

