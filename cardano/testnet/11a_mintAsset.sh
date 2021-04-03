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
      assetMintName="$(echo $1 | cut -d. -f 2-)"; assetMintName=$(basename "${assetMintName}" .asset); #assetMintName=${assetMintName//./};
      assetMintAmount="$2";;

  * ) cat >&2 <<EOF
Usage:  $(basename $0) <PolicyName.AssetName> <AssetAmount> <PaymentAddressName> [Opt: Transaction-Metadata.json - this is not the TokenRegistryServer Metadata!]

Note: If you wanna register your NativeAsset/Token on the TokenRegitry, use the scripts 12!

EOF
  exit 1;; esac

#Check assetMintName for alphanummeric only, 32 chars max
if [[ "${assetMintName}" == ".asset" ]]; then assetMintName="";
elif [[ ! "${assetMintName}" == "${assetMintName//[^[:alnum:]]/}" ]]; then echo -e "\e[35mError - Your given AssetName '${assetMintName}' should only contain alphanummeric chars!\e[0m"; exit 1; fi
if [[ ${#assetMintName} -gt 32 ]]; then echo -e "\e[35mError - Your given AssetName is too long, maximum of 32 chars allowed!\e[0m"; exit 1; fi
if [[ ${assetMintAmount} -lt 1 ]]; then echo -e "\e[35mError - The Amount of Assets to mint must be a positive number!\e[0m"; exit 1; fi

# Check for needed input files - missing - work to do :-)
if [ ! -f "${policyName}.policy.id" ]; then echo -e "\n\e[35mERROR - \"${policyName}.policy.id\" id-file does not exist! Please create it first with script 10.\e[0m"; exit 1; fi
if [ ! -f "${policyName}.policy.script" ]; then echo -e "\n\e[35mERROR - \"${policyName}.policy.script\" scriptfile does not exist! Please create it first with script 10.\e[0m"; exit 1; fi
if [ ! -f "${policyName}.policy.skey" ]; then echo -e "\n\e[35mERROR - \"${policyName}.policy.skey\" signing key does not exist! Please create it first with script 10.\e[0m"; exit 1; fi
policyID=$(cat ${policyName}.policy.id)

if [ ! -f "${fromAddr}.addr" ]; then echo -e "\n\e[35mERROR - \"${fromAddr}.addr\" does not exist! Please create it first with script 03a or 02.\e[0m"; exit 1; fi
if [ ! -f "${fromAddr}.skey" ]; then echo -e "\n\e[35mERROR - \"${fromAddr}.skey\" does not exist! Please create it first with script 03a or 02. It's not possible to mint on a hw-wallet for now!\e[0m"; exit 1; fi
#if ! [[ -f "${fromAddr}.skey" || -f "${fromAddr}.hwsfile" ]]; then echo -e "\n\e[35mERROR - \"${fromAddr}.skey/hwsfile\" does not exist! Please create it first with script 03a or 02.\e[0m"; exit 1; fi

#Check if there is also an optional trasaction metadata file present
metafileParameter=""; metafile="";
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

assetMintBech=$(convert_tokenName2BECH ${policyID} ${assetMintName})
assetMintSubject="${policyID}$(convert_assetNameASCII2HEX ${assetMintName})"

echo -e "\e[0mMinting Asset \e[32m${assetMintAmount} '${assetMintName}'\e[0m with Policy \e[32m'${policyName}'\e[0m: ${assetMintBech}"

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
                                utxo=$(${cardanocli} query utxo --address ${sendFromAddr} ${magicparam} ); checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi;
                                utxoJSON=$(generate_UTXO "${utxo}" "${sendFromAddr}")
                          else
                                readOfflineFile;        #Reads the offlinefile into the offlineJSON variable
                                utxoJSON=$(jq -r ".address.\"${sendFromAddr}\".utxoJSON" <<< ${offlineJSON})
                                if [[ "${utxoJSON}" == null ]]; then echo -e "\e[35mPayment-Address not included in the offline transferFile, please include it first online!\e[0m\n"; exit 1; fi
        fi

        txcnt=$(jq length <<< ${utxoJSON}) #Get number of UTXO entries (Hash#Idx), this is also the number of --tx-in for the transaction
        if [[ ${txcnt} == 0 ]]; then echo -e "\e[35mNo funds on the Source Address!\e[0m\n"; exit 1; else echo -e "\e[32m${txcnt} UTXOs\e[0m found on the Source Address!\n"; fi

        #Calculating the total amount of lovelaces in all utxos on this address
        totalLovelaces=0

        #totalAssetsJSON="{}"; #Building a total JSON with the different assetstypes "policyIdHash.name", amount and name
	#Preload the new Asset to mint in the totalAssetsJSON

	if [[ "${assetMintName}" == "" ]]; then point=""; else point="."; fi

	assetBech=$(convert_tokenName2BECH ${policyID} ${assetMintName})
	totalAssetsJSON=$( jq ". += {\"${policyID}${point}${assetMintName}\":{amount: \"${assetMintAmount}\", name: \"${assetMintName}\", bech: \"${assetBech}\"}}" <<< "{}")
        totalPolicyIDsJSON="{}"; #Holds the different PolicyIDs as values "policyIDHash", length is the amount of different policyIDs
	totalPolicyIDsJSON=$( jq ". += {\"${policyID}\": 1}" <<< ${totalPolicyIDsJSON})

        #For each utxo entry, check the utxo#index and check if there are also any assets in that utxo#index
        #LEVEL 1 - different UTXOs
        for (( tmpCnt=0; tmpCnt<${txcnt}; tmpCnt++ ))
        do
        utxoHashIndex=$(jq -r "keys_unsorted[${tmpCnt}]" <<< ${utxoJSON})
        utxoAmount=$(jq -r ".\"${utxoHashIndex}\".value.lovelace" <<< ${utxoJSON})   #Lovelaces
        totalLovelaces=$(bc <<< "${totalLovelaces} + ${utxoAmount}" )
        echo -e "Hash#Index: ${utxoHashIndex}\tAmount: ${utxoAmount}"
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
                                assetBech=$(convert_tokenName2BECH ${assetHash} ${assetName})
                                if [[ "${assetName}" == "" ]]; then point=""; else point="."; fi
                                oldValue=$(jq -r ".\"${assetHash}${point}${assetName}\".amount" <<< ${totalAssetsJSON})
                                newValue=$(bc <<< "${oldValue}+${assetAmount}")
                                totalAssetsJSON=$( jq ". += {\"${assetHash}${point}${assetName}\":{amount: \"${newValue}\", name: \"${assetName}\", bech: \"${assetBech}\"}}" <<< ${totalAssetsJSON})
                                echo -e "\e[90m                           Asset: ${assetBech}  Amount: ${assetAmount} ${assetName}\e[0m"
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
                        echo -e "\e[32m${totalAssetsCnt} Asset-Type(s) / ${totalPolicyIDsCnt} different PolicyIDs - \e[91m PREVIEW after minting!\e[0m\n"
                        printf "\e[0m%-56s%11s    %16s %-44s  %7s  %s\n" "PolicyID:" "ASCII-Name:" "Total-Amount:" "Bech-Format:" "Ticker:" "Meta-Name:"
                        for (( tmpCnt=0; tmpCnt<${totalAssetsCnt}; tmpCnt++ ))
                        do
                        assetHashName=$(jq -r "keys[${tmpCnt}]" <<< ${totalAssetsJSON})
                        assetAmount=$(jq -r ".\"${assetHashName}\".amount" <<< ${totalAssetsJSON})
                        assetName=$(jq -r ".\"${assetHashName}\".name" <<< ${totalAssetsJSON})
                        assetBech=$(jq -r ".\"${assetHashName}\".bech" <<< ${totalAssetsJSON})
                        assetHashHex="${assetHashName:0:56}$(convert_assetNameASCII2HEX ${assetName})"

                        if $queryTokenRegistry; then if $onlineMode; then metaResponse=$(curl -sL -m 20 "${tokenMetaServer}${assetHashHex}"); else metaResponse=$(jq -r ".tokenMetaServer.\"${assetHashHex}\"" <<< ${offlineJSON}); fi
                                metaAssetName=$(jq -r ".name.value | select (.!=null)" 2> /dev/null <<< ${metaResponse}); if [[ ! "${metaAssetName}" == "" ]]; then metaAssetName="${metaAssetName} "; fi
                                metaAssetTicker=$(jq -r ".ticker.value | select (.!=null)" 2> /dev/null <<< ${metaResponse})
                        fi

                        printf "\e[90m%-70s \e[32m%16s %44s  \e[90m%-7s  \e[36m%s\e[0m\n" "${assetHashName}" "${assetAmount}" "${assetBech}" "${metaAssetTicker}" "${metaAssetName}"
                        if [[ $(bc <<< "${assetAmount}>0") -eq 1 ]]; then assetsOutString+="+${assetAmount} ${assetHashName}"; fi #only include in the sendout if more than zero
                        done
        fi

echo

if [[ ! "${metafile}" == "" ]]; then echo -e "\e[0mInclude Metadata-File:\e[32m ${metafile}\e[0m\n"; fi

#Read ProtocolParameters
if ${onlineMode}; then
                        protocolParametersJSON=$(${cardanocli} query protocol-parameters ${magicparam} ); #onlinemode
                  else
                        protocolParametersJSON=$(jq ".protocol.parameters" <<< ${offlineJSON}); #offlinemode
                  fi
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
minOutUTXO=$(get_minOutUTXO "${protocolParametersJSON}" "${totalAssetsCnt}" "${totalPolicyIDsCnt}")

if [[ "${assetMintName}" == "" ]]; then point=""; else point="."; fi

#Generate Dummy-TxBody file for fee calculation
txBodyFile="${tempDir}/dummy.txbody"
rm ${txBodyFile} 2> /dev/null
${cardanocli} transaction build-raw ${nodeEraParam} ${txInString} --tx-out "${sendToAddr}+0${assetsOutString}" --mint "${assetMintAmount} ${policyID}${point}${assetMintName}" --invalid-hereafter ${ttl} --fee 0 ${metafileParameter} --out-file ${txBodyFile}
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
fee=$(${cardanocli} transaction calculate-min-fee --tx-body-file ${txBodyFile} --protocol-params-file <(echo ${protocolParametersJSON}) --tx-in-count ${txcnt} --tx-out-count ${rxcnt} ${magicparam} --witness-count 2 --byron-witness-count 0 | awk '{ print $1 }')
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
${cardanocli} transaction build-raw ${nodeEraParam} ${txInString} --tx-out "${sendToAddr}+${lovelacesToSend}${assetsOutString}" --mint "${assetMintAmount} ${policyID}${point}${assetMintName}" --invalid-hereafter ${ttl} --fee ${fee} ${metafileParameter} --out-file ${txBodyFile}
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
#echo "${cardanocli} transaction build-raw ${nodeEraParam} ${txInString} --tx-out \"${sendToAddr}+${lovelacesToSend}${assetsOutString}\" --mint \"${assetMintAmount} ${policyID}.${assetMintName}\" --invalid-hereafter ${ttl}  --out-file ${txBodyFile}"

cat ${txBodyFile}
echo

echo -e "\e[0mSign the unsigned transaction body with the \e[32m${fromAddr}.skey\e[0m and \e[32m${policyName}.policy.skey\e[0m: \e[32m ${txFile} \e[90m"
echo

#Sign the unsigned transaction body with the SecureKey
rm ${txFile} 2> /dev/null
${cardanocli} transaction sign --tx-body-file ${txBodyFile} --signing-key-file ${fromAddr}.skey --signing-key-file ${policyName}.policy.skey --script-file ${policyName}.policy.script ${magicparam} --out-file ${txFile}
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
#echo "${cardanocli} transaction sign --tx-body-file ${txBodyFile} --signing-key-file ${fromAddr}.skey --signing-key-file ${policyName}.policy.skey --script-file ${policyName}.policy.script ${magicparam} --out-file ${txFile}"

cat ${txFile}
echo

if ask "\e[33mDoes this look good for you, continue ?" N; then
        echo
        if ${onlineMode}; then  #onlinesubmit
                                echo -ne "\e[0mSubmitting the transaction via the node... "
                                ${cardanocli} transaction submit --tx-file ${txFile} ${magicparam}
                                checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
                                echo -e "\e[32mDONE\n"

                                #Show the TxID
                                txID=$(${cardanocli} transaction txid --tx-file ${txFile}); echo -e "\e[0m TxID is: \e[32m${txID}\e[0m"
                                checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi;
                                if [[ ${magicparam} == "--mainnet" ]]; then echo -e "\e[0mTracking: \e[32mhttps://cardanoscan.io/transaction/${txID}\n\e[0m";
                                elif [[ ${magicparam} == *"1097911063"* ]]; then echo -e "\e[0mTracking: \e[32mhttps://explorer.cardano-testnet.iohkdev.io/en/transaction?id=${txID}\n\e[0m";
                                fi

			        #Updating the ${policyName}.${assetMintName}.asset json
			        assetFileName="${policyName}.${assetMintName}.asset"

				#Make assetFileSkeleton
                                assetFileSkeletonJSON=$(jq ". += {metaName: \"${assetMintName}\",
                                                                  metaDescription: \"\",
                                                                  \"---\": \"--- Optional additional info ---\",
                                                                  metaTicker: \"\",
                                                                  metaUrl: \"\",
                                                                  metaLogoPNG: \"\",
                                                                  \"===\": \"--- DO NOT EDIT BELOW THIS LINE !!! ---\",
                                                                  minted: \"0\"}" <<< "{}")


				#If there is no assetFileName file, create one
			        if [ ! -f "${assetFileName}" ]; then echo "{}" > ${assetFileName}; fi

				#Read in the current file
				assetFileJSON=$(cat ${assetFileName})

				#Combine the Skeleton with the real one
				assetFileJSON=$(echo "${assetFileSkeletonJSON} ${assetFileJSON}" | jq -rs 'reduce .[] as $item ({}; . * $item)')


#Currently disabled by IOHK
#                                                                                         metaSubUnitDecimals: 0,
#                                                                                         metaSubUnitName: \"\",


			        oldValue=$(jq -r ".minted" <<< ${assetFileJSON}); if [[ "${oldValue}" == "" ]]; then oldValue=0; fi
			        newValue=$(bc <<< "${oldValue} + ${assetMintAmount}")
			        assetFileJSON=$( jq ". += {minted: \"${newValue}\",
                                                           name: \"${assetMintName}\",
                                                           bechName: \"${assetMintBech}\",
                                                           policyID: \"${policyID}\",
                                                           policyValidBeforeSlot: \"${ttlFromScript}\",
                                                           subject: \"${assetMintSubject}\",
                                                           lastUpdate: \"$(date -R)\",
                                                           lastAction: \"mint ${assetMintAmount}\"}" <<< ${assetFileJSON})

			        file_unlock ${assetFileName}
			        echo -e "${assetFileJSON}" > ${assetFileName}
			        file_lock ${assetFileName}

			        echo -e "\e[0mAsset-File: \e[32m ${assetFileName} \e[90m\n"
			        cat ${assetFileName}
			        echo

                          else  #offlinestore
                                txFileJSON=$(cat ${txFile} | jq .)
                                offlineJSON=$( jq ".transactions += [ { date: \"$(date -R)\",
                                                                        type: \"Asset-Minting\",
                                                                        era: \"$(jq -r .protocol.era <<< ${offlineJSON})\",
                                                                        fromAddr: \"${fromAddr}\",
                                                                        sendFromAddr: \"${sendFromAddr}\",
                                                                        toAddr: \"${toAddr}\",
                                                                        sendToAddr: \"${sendToAddr}\",
                                                                        txJSON: ${txFileJSON} } ]" <<< ${offlineJSON})
                                #Write the new offileFile content
                                offlineJSON=$( jq ".history += [ { date: \"$(date -R)\", action: \"minted ${assetMintAmount} '${assetMintName}' on '${fromAddr}'\" } ]" <<< ${offlineJSON})
                                offlineJSON=$( jq ".general += {offlineCLI: \"${versionCLI}\" }" <<< ${offlineJSON})
                                offlineJSON=$( jq ".general += {offlineNODE: \"${versionNODE}\" }" <<< ${offlineJSON})
                                echo "${offlineJSON}" > ${offlineFile}
                                #Readback the tx content and compare it to the current one
                                readback=$(cat ${offlineFile} | jq -r ".transactions[-1].txJSON")
                                if [[ "${txFileJSON}" == "${readback}" ]]; then

			                                #Updating the ${policyName}.${assetMintName}.asset json
			                                assetFileName="${policyName}.${assetMintName}.asset"

			                                #Make assetFileSkeleton
			                                assetFileSkeletonJSON=$(jq ". += {metaName: \"${assetMintName}\",
			                                                                  metaDescription: \"\",
			                                                                  \"---\": \"--- Optional additional info ---\",
			                                                                  metaTicker: \"\",
			                                                                  metaUrl: \"\",
			                                                                  metaLogoPNG: \"\",
			                                                                  \"===\": \"--- DO NOT EDIT BELOW THIS LINE !!! ---\",
			                                                                  minted: \"0\"}" <<< "{}")

			                                #If there is no assetFileName file, create one
			                                if [ ! -f "${assetFileName}" ]; then echo "{}" > ${assetFileName}; fi

			                                #Read in the current file
			                                assetFileJSON=$(cat ${assetFileName})

			                                #Combine the Skeleton with the real one
			                                assetFileJSON=$(echo "${assetFileSkeletonJSON} ${assetFileJSON}" | jq -rs 'reduce .[] as $item ({}; . * $item)')

			                                oldValue=$(jq -r ".minted" <<< ${assetFileJSON}); if [[ "${oldValue}" == "" ]]; then oldValue=0; fi
			                                newValue=$(bc <<< "${oldValue} + ${assetMintAmount}")
			                                assetFileJSON=$( jq ". += {minted: \"${newValue}\",
			                                                           name: \"${assetMintName}\",
			                                                           bechName: \"${assetMintBech}\",
			                                                           policyID: \"${policyID}\",
			                                                           policyValidBeforeSlot: \"${ttlFromScript}\",
			                                                           subject: \"${assetMintSubject}\",
			                                                           lastUpdate: \"$(date -R)\",
			                                                           lastAction: \"mint ${assetMintAmount} (only Offline proof)\"}" <<< ${assetFileJSON})

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



