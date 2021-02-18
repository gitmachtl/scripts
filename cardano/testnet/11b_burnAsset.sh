#!/bin/bash

# Script is brought to you by ATADA_Stakepool, Telegram @atada_stakepool

#load variables from common.sh
#       socket          Path to the node.socket (also exports socket to CARDANO_NODE_SOCKET_PATH)
#       genesisfile     Path to the genesis.json
#       magicparam      TestnetMagic parameter
#       cardanocli      Path to the cardano-cli executable
#       cardanonode     Path to the cardano-node executable
. "$(dirname "$0")"/00_common.sh

case $# in

  3|4 ) fromAddr="$(dirname $3)/$(basename $3 .addr)"; fromAddr=${fromAddr/#.\//};
      toAddr=${fromAddr};
      policyName="$(echo $1 | cut -d. -f 1)";
      assetBurnName="$(echo $1 | cut -d. -f 2-)"; assetBurnName=$(basename "${assetBurnName}" .asset); #assetBurnName=${assetBurnName//./};
      assetBurnAmount="$2";;

  * ) cat >&2 <<EOF
Usage:  $(basename $0) <PolicyName.AssetName> <AssetAmount> <PaymentAddressName> [optional Metadata.json to send along]
EOF
  exit 1;; esac


#Check assetBurnName for alphanummeric only, 32 chars max
if [[ "${assetBurnName}" == ".asset" ]]; then assetBurnName="";
elif [[ ! "${assetBurnName}" == "${assetBurnName//[^[:alnum:]]/}" ]]; then echo -e "\e[35mError - Your given AssetName '${assetBurnName}' should only contain alphanummeric chars!\e[0m"; exit 1; fi
if [[ ${#assetBurnName} -gt 32 ]]; then echo -e "\e[35mError - Your given AssetName is too long, maximum of 32 chars allowed!\e[0m"; exit 1; fi
if [[ ${assetBurnAmount} -lt 1 ]]; then echo -e "\e[35mError - The Amount of Assets to burn must be a positive number!\e[0m"; exit 1; fi

# Check for needed input files
if [ ! -f "${policyName}.policy.id" ]; then echo -e "\n\e[35mERROR - \"${policyName}.policy.id\" id-file does not exist! Please create it first with script 10.\e[0m"; exit 1; fi
if [ ! -f "${policyName}.policy.script" ]; then echo -e "\n\e[35mERROR - \"${policyName}.policy.script\" scriptfile does not exist! Please create it first with script 10.\e[0m"; exit 1; fi
if [ ! -f "${policyName}.policy.skey" ]; then echo -e "\n\e[35mERROR - \"${policyName}.policy.skey\" signing key does not exist! Please create it first with script 10.\e[0m"; exit 1; fi
policyID=$(cat ${policyName}.policy.id)

if [ ! -f "${fromAddr}.addr" ]; then echo -e "\n\e[35mERROR - \"${fromAddr}.addr\" does not exist! Please create it first with script 03a or 02.\e[0m"; exit 1; fi
if [ ! -f "${fromAddr}.skey" ]; then echo -e "\n\e[35mERROR - \"${fromAddr}.skey\" does not exist! Please create it first with script 03a or 02.\e[0m"; exit 1; fi

#Check if there is also an optional metadata file present
metafileParameter=""
if [[ $# -eq 4 ]]; then
                        metafile="$(dirname $4)/$(basename $4 .json).json"; metafile=${metafile//.\//}
                        if [ ! -f "${metafile}" ]; then echo -e "The specified Metadata JSON-File '${metafile}' does not exist. Please try again."; exit 1; fi
                        #Do a simple basic check if the metadatum is in the 0..65535 range
                        metadatum=$(jq -r "keys_unsorted[0]" ${metafile} 2> /dev/null)
                        if [[ $? -ne 0 ]]; then echo "ERROR - '${metafile}' is not a valid JSON file"; exit 1; fi
                        #Check if it is null, a number, lower then zero, higher then 65535
			if [ "${metadatum}" == null ] || [ -z "${metadatum##*[!0-9]*}" ] || [ "${metadatum}" -lt 0 ] || [ "${metadatum}" -gt 65535 ]; then echo "ERROR - MetaDatum Value '${metadatum}' in '${metafile}' must be in the range of 0..65535!"; exit 1; fi
                        metafileParameter="--metadata-json-file ${metafile}"
fi


#Sending ALL lovelaces, so only 1 receiver addresses
rxcnt="1"

echo -e "\e[0mBurning Asset \e[32m${assetBurnAmount} '${assetBurnName}'\e[0m with Policy \e[32m'${policyName}'\e[0m:"

#get live values
currentTip=$(get_currentTip)

#set timetolife (inherent hereafter) to the currentTTL or to the value set in the policy.script for the "before" slot (limited policy lifespan)
ttlFromScript=$(cat ${policyName}.policy.script | jq -r ".scripts[] | select(.type == \"before\") | .slot" 2> /dev/null || echo "unlimited")
if [[ ! ${ttlFromScript} == "unlimited" ]]; then ttl=${ttlFromScript}; else ttl=$(get_currentTTL); fi
echo
echo -e "\e[0mPolicy valid before Slot-Height:\e[33m ${ttlFromScript}\e[0m"
echo
echo -e "\e[0mCurrent Slot-Height:\e[32m ${currentTip} \e[0m(setting TTL[invalid_hereafter] to ${ttl})"
echo
if [[ ${ttl} -le ${currentTip} ]]; then echo -e "\e[35mError - Your given Policy has expired, you cannot use it anymore!\e[0m\n"; exit 2; fi


sendFromAddr=$(cat ${fromAddr}.addr)
sendToAddr=${sendFromAddr}

check_address "${sendFromAddr}"; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi;

echo -e "\e[0mPayment Address and Asset-Destination-Address ${fromAddr}.addr:\e[32m ${sendFromAddr} \e[90m"
echo

#
# Checking UTXO Data of the source address and gathering data about total lovelaces and total assets
#
        #Get UTX0 Data for the address. When in online mode of course from the node and the chain, in offlinemode from the transferFile
        if ${onlineMode}; then
                                utxo=$(${cardanocli} ${subCommand} query utxo --address ${sendFromAddr} --cardano-mode ${magicparam} ${nodeEraParam}); checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi;
				utxoJSON=$(generate_UTXO "${utxo}" "${sendFromAddr}")
                          else
                                readOfflineFile;        #Reads the offlinefile into the offlineJSON variable
                                utxoJSON=$(jq -r ".address.\"${sendFromAddr}\".utxoJSON" <<< ${offlineJSON})
                                if [[ "${utxoJSON}" == null ]]; then echo -e "\e[35mPayment-Address not included in the offline transferFile, please include it first online!\e[0m\n"; exit; fi
        fi

        txcnt=$(jq length <<< ${utxoJSON}) #Get number of UTXO entries (Hash#Idx), this is also the number of --tx-in for the transaction
        if [[ ${txcnt} == 0 ]]; then echo -e "\e[35mNo funds on the Source Address!\e[0m\n"; exit; else echo -e "\e[32m${txcnt} UTXOs\e[0m found on the Source Address!\n"; fi

        #Calculating the total amount of lovelaces in all utxos on this address
        totalLovelaces=0

        #totalAssetsJSON="{}"; #Building a total JSON with the different assetstypes "policyIdHash.name", amount and name
	#Preload the new Asset to burn in the totalAssetsJSON with the negative number of assets to burn, will sum up later
	if [[ "${assetBurnName}" == "" ]]; then point=""; else point="."; fi
	totalAssetsJSON=$( jq ". += {\"${policyID}${point}${assetBurnName}\":{amount: \"-${assetBurnAmount}\", name: \"${assetBurnName}\"}}" <<< "{}")
        totalPolicyIDsJSON="{}"; #Holds the different PolicyIDs as values "policyIDHash", length is the amount of different policyIDs

        #For each utxo entry, check the utxo#index and check if there are also any assets in that utxo#index
	#LEVEL 1 - different UTXOs
        for (( tmpCnt=0; tmpCnt<${txcnt}; tmpCnt++ ))
        do
        utxoHashIndex=$(jq -r "keys_unsorted[${tmpCnt}]" <<< ${utxoJSON})
        utxoAmount=$(jq -r ".\"${utxoHashIndex}\".amount[0]" <<< ${utxoJSON})   #Lovelaces
	totalLovelaces=$(( ${totalLovelaces} + ${utxoAmount} ))
        echo -e "Hash#Index: ${utxoHashIndex}\tAmount: ${utxoAmount}"
        assetsJSON=$(jq -r ".\"${utxoHashIndex}\".amount[1]" <<< ${utxoJSON})
        assetsEntryCnt=$(jq length <<< ${assetsJSON})
        if [[ ${assetsEntryCnt} -gt 0 ]]; then
			#LEVEL 2 - different policyID/assetHASH
                        for (( tmpCnt2=0; tmpCnt2<${assetsEntryCnt}; tmpCnt2++ ))
                        do
                        assetHash=$(jq -r ".[${tmpCnt2}][0]" <<< ${assetsJSON})  #assetHash = policyID
                        assetsNameCnt=$(jq ".[${tmpCnt2}][1] | length" <<< ${assetsJSON})
                        totalPolicyIDsJSON=$( jq ". += {\"${assetHash}\": 1}" <<< ${totalPolicyIDsJSON})

                                #LEVEL 3 - different names under the same policyID
                                for (( tmpCnt3=0; tmpCnt3<${assetsNameCnt}; tmpCnt3++ ))
                                do
                                assetName=$(jq -r ".[${tmpCnt2}][1][${tmpCnt3}][0]" <<< ${assetsJSON})
                                assetAmount=$(jq -r ".[${tmpCnt2}][1][${tmpCnt3}][1]" <<< ${assetsJSON})
				if [[ "${assetName}" == "" ]]; then point=""; else point="."; fi
                                oldValue=$(jq -r ".\"${assetHash}${point}${assetName}\".amount" <<< ${totalAssetsJSON})
                                newValue=$((${oldValue}+${assetAmount}))
                                totalAssetsJSON=$( jq ". += {\"${assetHash}${point}${assetName}\":{amount: \"${newValue}\", name: \"${assetName}\"}}" <<< ${totalAssetsJSON})
                                echo -e "\e[90m            PolID: ${assetHash}\tAmount: ${assetAmount} ${assetName}\e[0m"
                                done
                         done
        fi
	txInString="${txInString} --tx-in ${utxoHashIndex}"
        done
        echo -e "\e[0m-----------------------------------------------------------------------------------------------------"
        echo -e "Total ADA on the Address:\e[32m  $(convertToADA ${totalLovelaces}) ADA / ${totalLovelaces} lovelaces \e[0m\n"
        totalPolicyIDsCnt=$(jq length <<< ${totalPolicyIDsJSON});
        totalAssetsCnt=$(jq length <<< ${totalAssetsJSON})
        if [[ ${totalAssetsCnt} -gt 0 ]]; then
                        echo -e "\e[32m${totalAssetsCnt} Asset-Type(s)\e[0m - PREVIEW after the burn\n"
                        printf "\e[0m%-70s %16s %s\n" "PolicyID.Name:" "Total-Amount:" "Name:"
                        for (( tmpCnt=0; tmpCnt<${totalAssetsCnt}; tmpCnt++ ))
                        do
                        assetHashName=$(jq -r "keys[${tmpCnt}]" <<< ${totalAssetsJSON})
                        assetAmount=$(jq -r ".\"${assetHashName}\".amount" <<< ${totalAssetsJSON})
                        assetName=$(jq -r ".\"${assetHashName}\".name" <<< ${totalAssetsJSON})
			if [[ ${assetAmount} -ge 0 ]]; then
                        	printf "\e[90m%-70s \e[32m%16s %s\e[0m\n" "${assetHashName}" "${assetAmount}" "${assetName}"
				assetsOutString+="+${assetAmount} ${assetHashName}"; #only include in the sendout if more than zero
			fi
                        done
        fi

echo

#Read ProtocolParameters
if ${onlineMode}; then
                        protocolParametersJSON=$(${cardanocli} ${subCommand} query protocol-parameters --cardano-mode ${magicparam} ${nodeEraParam}); #onlinemode
                  else
                        protocolParametersJSON=$(jq ".protocol.parameters" <<< ${offlineJSON}); #offlinemode
                  fi
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
minOutUTXO=$(get_minOutUTXO "${protocolParametersJSON}" "${totalAssetsCnt}" "${totalPolicyIDsCnt}")

if [[ "${assetBurnName}" == "" ]]; then point=""; else point="."; fi

#Check amount of assets after the burn
assetAmountAfterBurn=$(jq -r ".\"${policyID}.${assetBurnName}\".amount" <<< ${totalAssetsJSON})
if [[ ${assetAmountAfterBurn} -lt 0 ]]; then echo -e "\n\e[35mYou can't burn ${assetBurnAmount} ${assetBurnName} Assets with that policy, you can only burn $((${assetBurnAmount}+${assetAmountAfterBurn})) Assets!\e[0m"; exit; fi

#Generate Dummy-TxBody file for fee calculation
txBodyFile="${tempDir}/dummy.txbody"
rm ${txBodyFile} 2> /dev/null
${cardanocli} ${subCommand} transaction build-raw ${nodeEraParam} ${txInString} --tx-out "${dummyShelleyAddr}+0${assetsOutString}" --mint "-${assetBurnAmount} ${policyID}${point}${assetBurnName}" --invalid-hereafter ${ttl} --fee 0 ${metafileParameter} --out-file ${txBodyFile}
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
fee=$(${cardanocli} ${subCommand} transaction calculate-min-fee --tx-body-file ${txBodyFile} --protocol-params-file <(echo ${protocolParametersJSON}) --tx-in-count ${txcnt} --tx-out-count ${rxcnt} ${magicparam} --witness-count 2 --byron-witness-count 0 | awk '{ print $1 }')
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
echo -e "\e[0mMinimum Transaction Fee for ${txcnt}x TxIn & ${rxcnt}x TxOut: \e[32m $(convertToADA ${fee}) ADA / ${fee} lovelaces \e[90m"

lovelacesToSend=$(( ${totalLovelaces} - ${fee} ))

echo -e "\e[0mLovelaces to return to source ${toAddr}.addr: \e[33m $(convertToADA ${lovelacesToSend}) ADA / ${lovelacesToSend} lovelaces \e[90m"

#Checking about minimum funds in the UTX0
if [[ ${lovelacesToSend} -lt ${minOutUTXO} ]]; then echo -e "\e[35mNot enough funds on the source Addr! Minimum UTXO value is ${minOutUTXO} lovelaces.\e[0m"; exit; fi

if [[ ! "${metafile}" == "" ]]; then echo -e "\n\e[0mAdding Metadata-File: \e[32m${metafile} \e[90m\n"; cat ${metafile}; fi

txBodyFile="${tempDir}/$(basename ${fromAddr}).txbody"
txFile="${tempDir}/$(basename ${fromAddr}).tx"

echo
echo -e "\e[0mBuilding the unsigned transaction body: \e[32m ${txBodyFile} \e[90m"
echo

#Building unsigned transaction body
rm ${txBodyFile} 2> /dev/null
${cardanocli} ${subCommand} transaction build-raw ${nodeEraParam} ${txInString} --tx-out "${sendToAddr}+${lovelacesToSend}${assetsOutString}" --mint "-${assetBurnAmount} ${policyID}${point}${assetBurnName}" --invalid-hereafter ${ttl} --fee ${fee} ${metafileParameter} --out-file ${txBodyFile}
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
#echo "${cardanocli} ${subCommand} transaction build-raw ${nodeEraParam} ${txInString} --tx-out \"${sendToAddr}+${lovelacesToSend}${assetsOutString}\" --mint \"${assetBurnAmount} ${policyID}.${assetBurnName}\" --invalid-hereafter ${ttl}  --out-file ${txBodyFile}"

cat ${txBodyFile}
echo

echo -e "\e[0mSign the unsigned transaction body with the \e[32m${fromAddr}.skey\e[0m and \e[32m${policyName}.policy.skey\e[0m: \e[32m ${txFile} \e[90m"
echo

#Sign the unsigned transaction body with the SecureKey
rm ${txFile} 2> /dev/null
${cardanocli} ${subCommand} transaction sign --tx-body-file ${txBodyFile} --signing-key-file ${fromAddr}.skey --signing-key-file ${policyName}.policy.skey --script-file ${policyName}.policy.script ${magicparam} --out-file ${txFile}
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
#echo "${cardanocli} ${subCommand} transaction sign --tx-body-file ${txBodyFile} --signing-key-file ${fromAddr}.skey --signing-key-file ${policyName}.policy.skey --script-file ${policyName}.policy.script ${magicparam} --out-file ${txFile}"

cat ${txFile}
echo

if ask "\e[33mDoes this look good for you, continue ?" N; then
        echo
        if ${onlineMode}; then  #onlinesubmit
                                echo -ne "\e[0mSubmitting the transaction via the node..."
                                ${cardanocli} ${subCommand} transaction submit --tx-file ${txFile} --cardano-mode ${magicparam}
                                checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
                                echo -e "\e[32mDONE\n"

                                #Show the TxID
                                txID=$(${cardanocli} ${subCommand} transaction txid --tx-file ${txFile}); echo -e "\e[0mTxID is: \e[32m${txID}\e[0m"
                                if [[ ${magicparam} == "--mainnet" ]]; then echo -e "\e[0mTracking: \e[32mhttps://cardanoscan.io/transaction/${txID}\n"; fi

			        #Updating the ${policyName}.${assetBurnName}.asset json
			        assetFileName="${policyName}.${assetBurnName}.asset"
			        if [ ! -f "${assetFileName}" ]; then echo "{}" > ${assetFileName}; fi #generate an empty json if no file present
			        oldValue=$(jq -r ".minted" ${assetFileName})
			        newValue=$(( ${oldValue} - ${assetBurnAmount} ))
			        assetFileJSON=$( jq ". += {minted: \"${newValue}\", name: \"${assetBurnName}\", policyID: \"${policyID}\", lastUpdate: \"$(date -R)\", lastAction: \"burn ${assetBurnAmount}\"}" < ${assetFileName})

			        file_unlock ${assetFileName}
			        echo -e "${assetFileJSON}" > ${assetFileName}
			        file_lock ${assetFileName}

			        echo -e "\e[0mAsset-File: \e[32m ${assetFileName} \e[90m\n"
			        cat ${assetFileName}
			        echo

                          else  #offlinestore
                                txFileJSON=$(cat ${txFile} | jq .)
                                offlineJSON=$( jq ".transactions += [ { date: \"$(date -R)\",
                                                                        type: \"Asset-Burning\",
                                                                        era: \"$(jq -r .protocol.era <<< ${offlineJSON})\",
                                                                        fromAddr: \"${fromAddr}\",
                                                                        sendFromAddr: \"${sendFromAddr}\",
                                                                        toAddr: \"${toAddr}\",
                                                                        sendToAddr: \"${sendToAddr}\",
                                                                        txJSON: ${txFileJSON} } ]" <<< ${offlineJSON})
                                #Write the new offileFile content
                                offlineJSON=$( jq ".history += [ { date: \"$(date -R)\", action: \"burned ${assetBurnAmount} '${assetBurnName}' on '${fromAddr}'\" } ]" <<< ${offlineJSON})
                                offlineJSON=$( jq ".general += {offlineCLI: \"${versionCLI}\" }" <<< ${offlineJSON})
                                offlineJSON=$( jq ".general += {offlineNODE: \"${versionNODE}\" }" <<< ${offlineJSON})
                                echo "${offlineJSON}" > ${offlineFile}
                                #Readback the tx content and compare it to the current one
                                readback=$(cat ${offlineFile} | jq -r ".transactions[-1].txJSON")
                                if [[ "${txFileJSON}" == "${readback}" ]]; then
						        #Updating the ${policyName}.${assetBurnName}.asset json
						        assetFileName="${policyName}.${assetBurnName}.asset"
						        if [ ! -f "${assetFileName}" ]; then echo "{}" > ${assetFileName}; fi #generate an empty json if no file present
						        oldValue=$(jq -r ".minted" ${assetFileName})
						        newValue=$(( ${oldValue} - ${assetBurnAmount} ))
						        assetFileJSON=$( jq ". += {minted: \"${newValue}\", name: \"${assetBurnName}\", policyID: \"${policyID}\", lastUpdate: \"$(date -R)\", lastAction: \"burn ${assetBurnAmount}\"}" < ${assetFileName})

						        file_unlock ${assetFileName}
						        echo -e "${assetFileJSON}" > ${assetFileName}
						        file_lock ${assetFileName}

						        echo -e "\e[0mAsset-File: \e[32m ${assetFileName} \e[90m\n"
						        cat ${assetFileName}
						        echo

                                                        showOfflineFileInfo;
                                                        echo -e "\e[33mTransaction txJSON has been stored in the '$(basename ${offlineFile})'.\nYou can now transfer it to your online machine for execution.\e[0m\n";

                                                 else
                                                        echo -e "\e[35mERROR - Could not verify the written data in the '$(basename ${offlineFile})'. Retry again or generate a new '$(basename ${offlineFile})'.\e[0m\n";
                                fi

        fi
fi

echo -e "\e[0m\n"

