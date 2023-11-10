#!/bin/bash

# Script is brought to you by ATADA Stakepool, Telegram @atada_stakepool

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

                                #check if its an root adahandle (without a @ char)
                                elif checkAdaRootHandleFormat "${addrName}"; then
                                        if ${offlineMode}; then echo -e "\n\e[35mERROR - Adahandles are only supported in online & light mode.\n\e[0m"; exit 1; fi
                                        adahandleName=${addrName,,}
                                        assetNameHex=$(convert_assetNameASCII2HEX ${adahandleName:1})
                                        #query classic cip-25 adahandle asset holding address via koios
                                        showProcessAnimation "Query Adahandle(CIP-25) into holding address: " &
                                        response=$(curl -sL -m 10 -X GET "${koiosAPI}/asset_address_list?_asset_policy=${adahandlePolicyID}&_asset_name=${assetNameHex}" -H "Accept: application/json" 2> /dev/null)
                                        stopProcessAnimation;
                                        #check if the received json only contains one entry in the array (will also not be 1 if not a valid json)
                                        if [[ $(jq ". | length" 2> /dev/null <<< ${response}) -ne 1 ]]; then
	                                        #query classic cip-68 adahandle asset holding address via koios
	                                        showProcessAnimation "Query Adahandle(CIP-68) into holding address: " &
	                                        response=$(curl -sL -m 10 -X GET "${koiosAPI}/asset_address_list?_asset_policy=${adahandlePolicyID}&_asset_name=000de140${assetNameHex}" -H "Accept: application/json" 2> /dev/null)
	                                        stopProcessAnimation;
	                                        #check if the received json only contains one entry in the array (will also not be 1 if not a valid json)
	                                        if [[ $(jq ". | length" 2> /dev/null <<< ${response}) -ne 1 ]]; then echo -e "\n\e[33mCould not resolve Adahandle to an address.\n\e[0m"; exit 1; fi
						assetNameHex="000de140${assetNameHex}"
					fi
                                        addrName=$(jq -r ".[0].payment_address" <<< ${response} 2> /dev/null)
                                        typeOfAddr=$(get_addressType "${addrName}");
                                        if [[ ${typeOfAddr} != ${addrTypePayment} ]]; then echo -e "\n\e[35mERROR - Resolved address '${addrName}' is not a valid payment address.\n\e[0m"; exit 1; fi;
					#check that the node is fully synced, otherwise the query would mabye return a false state
					if [[ ${fullMode} == true && $(get_currentSync) != "synced" ]]; then echo -e "\e[35mError - Node not fully synced or not running, please let your node sync to 100% first !\e[0m\n"; exit 1; fi

                                        showProcessAnimation "Verify Adahandle is on resolved address: " &
					case ${workMode} in
						"online")	utxo=$(${cardanocli} ${cliEra} query utxo --address ${addrName} ); stopProcessAnimation; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi;;
						"light")	utxo=$(queryLight_UTXO "${addrName}"); if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${utxo}\e[0m\n"; exit $?; else stopProcessAnimation; fi;;
					esac

                                        if [[ $(grep "${adahandlePolicyID}.${assetNameHex} " <<< ${utxo} | wc -l) -ne 1 ]]; then
                                                 echo -e "\n\e[35mERROR - Resolved address '${addrName}' does not hold the \$adahandle '${adahandleName}' !\n\e[0m"; exit 1; fi;
                                        echo -e "\e[0mFound \$adahandle '${adahandleName}' on Address:\e[32m ${addrName}\e[0m\n"
                                        echo "${addrName}" > ${tempDir}/adahandle-resolve.addr; addrName="${tempDir}/adahandle-resolve";

                                elif checkAdaSubHandleFormat "${addrName}"; then
                                        if ${offlineMode}; then echo -e "\n\e[35mERROR - Adahandles are only supported in online & light mode.\n\e[0m"; exit 1; fi

#					addrName='$test'

                                        adahandleName=${addrName,,}; #convert given handle to lower case

					#query virtual subHandle via adahandleAPI
					if [[ "${adahandleAPI}" == "" ]]; then echo -e "\n\e[33mERROR - There is no Adahandle-API available for this network.\n\e[0m"; exit 1; fi
                                        showProcessAnimation "Query virtual Adahandle via the Adahandle-API (${adahandleAPI}): " &
					response=$(curl -sL -m 10 -X GET -H "Accept: application/json" -w "---spo-scripts---%{http_code}" "${adahandleAPI}/handles/${adahandleName:1}" 2> /dev/null)
					if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\n\e[35mERROR - Query via Adahandle-API (${adahandleAPI}) failed.\n\e[0m"; exit 1; else stopProcessAnimation; fi;
					responseCode=${response#*---spo-scripts---}
					responseJSON=${response%---spo-scripts---*}
					#Check the responseCode
					case ${responseCode} in
						"200" ) ;; #all good, continue
						"202" )	echo -e "\n\e[33mAdahandle was found, but the API sync is not on tip with the network status. Please try again later.\n\e[0m"; exit 1;;
						"404" )	echo -e "\n\e[33mAdahandle '${adahandleName}' was not found, cannot resolve it to an address.\n\e[0m"; exit 1;;
						* )	echo -e "\n\e[33m$(jq -r .message <<< ${responseJSON})\nAdahandle-API response code: ${responseCode}";
							echo -e "\nIf you think this is an issue, please report this via the SPO-Scripts Github-Repository https://github.com/gitmachtl/scripts\n\e[0m"; exit 1;;
					esac;
					#query was successful, get the address
                                        addrName=$(jq -r ".\"resolved_addresses\".ada" <<< ${responseJSON} 2> /dev/null)
					if [ $? -ne 0 ]; then echo -e "\n\e[35mERROR - The received data from the Adahandle-API is not a valid JSON.\n\e[0m"; exit 1; fi;
                                        typeOfAddr=$(get_addressType "${addrName}");
                                        if [[ ${typeOfAddr} != ${addrTypePayment} ]]; then echo -e "\n\e[35mERROR - Resolved address '${addrName}' is not a valid payment address.\n\e[0m"; exit 1; fi;
                                        echo -e "\e[0mFound \$adahandle '${adahandleName}' on Address:\e[32m ${addrName}\n\n\e[33mThis is a virtual \$adahandle, the scripts cannot verify it on an UTXO.\e[0m\n"
                                        echo "${addrName}" > ${tempDir}/adahandle-resolve.addr; addrName="${tempDir}/adahandle-resolve";




                                #otherwise post an error message
                                else echo -e "\n\e[35mERROR - Destination Address can't be resolved. Maybe filename wrong, or not a payment-address.\n\e[0m"; exit 1;

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

        delegationPoolID=$(jq -r ".[${tmpCnt}].delegation" <<< ${rewardsJSON})

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

		if ${onlineMode}; then
	                #query poolinfo via poolid on koios
	                showProcessAnimation "Query Pool-Info via Koios: " &
	                response=$(curl -s -m 10 -X POST "${koiosAPI}/pool_info" -H "Accept: application/json" -H "Content-Type: application/json" -d "{\"_pool_bech32_ids\":[\"${delegationPoolID}\"]}" 2> /dev/null)
	                stopProcessAnimation;
	                #check if the received json only contains one entry in the array (will also not be 1 if not a valid json)
	                if [[ $(jq ". | length" 2> /dev/null <<< ${response}) -eq 1 ]]; then
	                        poolName=$(jq -r ".[0].meta_json.name | select (.!=null)" 2> /dev/null <<< ${response})
	                        poolTicker=$(jq -r ".[0].meta_json.ticker | select (.!=null)" 2> /dev/null <<< ${response})
	                        poolStatus=$(jq -r ".[0].pool_status | select (.!=null)" 2> /dev/null <<< ${response})
	                        echo -e "   \t\e[0mInformation about the Pool: \e[32m${poolName} (${poolTicker})\e[0m"
	                        echo -e "   \t\e[0m                    Status: \e[32m${poolStatus}\e[0m"
	                        echo
	                fi
		fi

		else

		echo -e "   \tAccount is not delegated to a Pool !";

	fi

        echo

        done

        if [[ ${rewardsEntryCnt} -gt 1 ]]; then echo -e "   \t-----------------------------------------\n"; echo -e "   \tTotal Rewards: \e[33m${rewardsSumInADA} ADA / ${rewardsSum} lovelaces\e[0m\n"; fi

else #unsupported address type

	echo -e "\e[35mAddress type unknown!\e[0m";
fi

