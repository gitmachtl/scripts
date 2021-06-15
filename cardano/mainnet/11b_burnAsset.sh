#!/bin/bash

# Script is brought to you by ATADA_Stakepool, Telegram @atada_stakepool

#load variables from common.sh
#       socket          Path to the node.socket (also exports socket to CARDANO_NODE_SOCKET_PATH)
#       genesisfile     Path to the genesis.json
#       magicparam      TestnetMagic parameter
#       cardanocli      Path to the cardano-cli executable
#       cardanonode     Path to the cardano-node executable
. "$(dirname "$0")"/00_common.sh

if [ $# -ge 3 ]; then
      fromAddr="$(dirname $3)/$(basename $3 .addr)"; fromAddr=${fromAddr/#.\//};
      toAddr=${fromAddr};
      policyName="$(echo $1 | cut -d. -f 1)";
      assetBurnName="$(echo $1 | cut -d. -f 2-)"; assetBurnName=$(basename "${assetBurnName}" .asset); #assetBurnName=${assetBurnName//./};
      assetBurnAmount="$2";
      else
      cat >&2 <<EOF
Usage:  $(basename $0) <PolicyName.AssetName> <AssetAmount> <PaymentAddressName>
        [Opt: Transaction-Metadata.json - this is not the TokenRegistryServer Metadata!]
        [Opt: Message comment, starting with "msg: ...", | is the separator]


Optional parameters:

- If you wanna attach a Transaction-Message like a short comment, invoice-number, etc with the transaction:
   You can just add one or more Messages in quotes starting with "msg: ..." as a parameter. Max. 64chars / Message
   "msg: This is a short comment for the transaction" ... that would be a one-liner comment
   "msg: This is a the first comment line|and that is the second one" ... that would be a two-liner comment, | is the separator !

- You can attach a transaction-metadata.json by adding the filename of the json file to the parameters (minting information)

- You can attach a transaction-metadata.cbor by adding the filename of the json file to the parameters (minting information)

Note: If you wanna register your NativeAsset/Token on the TokenRegistry, use the scripts 12a/12b!

EOF
  exit 1; fi


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
if [ ! -f "${fromAddr}.skey" ]; then echo -e "\n\e[35mERROR - \"${fromAddr}.skey\" does not exist! Please create it first with script 03a or 02. It's not possible to mint on a hw-wallet for now!\e[0m"; exit 1; fi
#if ! [[ -f "${fromAddr}.skey" || -f "${fromAddr}.hwsfile" ]]; then echo -e "\n\e[35mERROR - \"${fromAddr}.skey/hwsfile\" does not exist! Please create it first with script 03a or 02.\e[0m"; exit 1; fi

#Check all optional parameters about there types and set the corresponding variables
#Starting with the 4th parameter (index3) up to the last parameter
metafileParameter=""; metafile=""; filterForUTXO=""; transactionMessage="{}"; #Setting defaults

paramCnt=$#;
allParameters=( "$@" )
for (( tmpCnt=3; tmpCnt<${paramCnt}; tmpCnt++ ))
 do
        paramValue=${allParameters[$tmpCnt]}
        #echo -n "${tmpCnt}: ${paramValue} -> "

        #Check if an additional metadata.json/.cbor was set as parameter (not a message, not an UTXO#IDX, not empty, not beeing a number)
        if [[ ! "${paramValue,,}" =~ ^msg:(.*)$ ]] && [[ ! "${paramValue}" =~ ^([[:xdigit:]]+#[[:digit:]]+(\|?)){1,}$ ]] && [[ ! ${paramValue} == "" ]] && [ -z "${paramValue##*[!0-9]*}" ]; then

             metafile="$(dirname ${paramValue})/$(basename $(basename ${paramValue} .json) .cbor)"; metafile=${metafile//.\//}
             if [ -f "${metafile}.json" ]; then metafile="${metafile}.json"
                #Do a simple basic check if the metadatum is in the 0..65535 range
                metadatum=$(jq -r "keys_unsorted[0]" ${metafile} 2> /dev/null)
                if [[ $? -ne 0 ]]; then echo "ERROR - '${metafile}' is not a valid JSON file"; exit 1; fi
                #Check if it is null, a number, lower then zero, higher then 65535, otherwise exit with an error
                if [ "${metadatum}" == null ] || [ -z "${metadatum##*[!0-9]*}" ] || [ "${metadatum}" -lt 0 ] || [ "${metadatum}" -gt 65535 ]; then
                                                                                                                        echo "ERROR - MetaDatum Value '${metadatum}' in '${metafile}' must be in the range of 0..65535!"; exit 1; fi
                metafileParameter="${metafileParameter}--metadata-json-file ${metafile} "; metafileList="${metafileList}${metafile} "
             elif [ -f "${metafile}.cbor" ]; then metafile="${metafile}.cbor"
                metafileParameter="${metafileParameter}--metadata-cbor-file ${metafile} "; metafileList="${metafileList}${metafile} "
             else echo -e "The specified Metadata JSON/CBOR-File '${metafile}' does not exist. Fileextension must be '.json' or '.cbor' Please try again."; exit 1;
             fi

        #Check if an additional UTXO#IDX filter was set as parameter "hex#num(|)" at least 1 time, but can be more often}
        elif [[ "${paramValue}" =~ ^([[:xdigit:]]+#[[:digit:]]+(\|?)){1,}$ ]]; then filterForUTXO="${paramValue}";

        #Check it its a MessageComment. Adding it to the JSON array if the length is <= 64 chars
        elif [[ "${paramValue,,}" =~ ^msg:(.*)$ ]]; then #if the parameter starts with "msg:" then add it
                msgString=$(trimString "${paramValue:4}");

                #Split the messages within the parameter at the "|" char
                IFS='|' read -ra allMessages <<< "${msgString}"

                #Add each message to the transactionMessage JSON
                for (( tmpCnt2=0; tmpCnt2<${#allMessages[@]}; tmpCnt2++ ))
                do
                        tmpMessage=${allMessages[tmpCnt2]}
                        if [[ $(byteLength "${tmpMessage}") -le 64 ]]; then
                                                transactionMessage=$( jq ".\"674\".msg += [ \"${tmpMessage}\" ]" <<< ${transactionMessage} 2> /dev/null);
                                                if [ $? -ne 0 ]; then echo -e "\n\e[35mMessage-Adding-ERROR: \"${tmpMessage}\" contain invalid chars for a JSON!\n\e[0m"; exit 1; fi
                        else echo -e "\n\e[35mMessage-Adding-ERROR: \"${tmpMessage}\" is too long, max. 64 bytes allowed, yours is $(byteLength "${tmpMessage}") bytes long!\n\e[0m"; exit 1;
                        fi
                done

        fi #end of different parameters check

 done

#Check if there are transactionMessages, if so, save the messages to a xxx.transactionMessage.json temp-file and add it to the list
if [[ ! "${transactionMessage}" == "{}" ]]; then
        transactionMessageMetadataFile="${tempDir}/$(basename ${fromAddr}).transactionMessage.json";
        tmp=$( jq . <<< ${transactionMessage} 2> /dev/null)
        if [ $? -eq 0 ]; then echo "${tmp}" > ${transactionMessageMetadataFile}; metafileParameter="${metafileParameter}--metadata-json-file ${transactionMessageMetadataFile} "; #add it to the list of metadata.jsons to attach
                         else echo -e "\n\e[35mERROR - Additional Transaction Message-Metafile is not valid:\n\n$${transactionMessage}\n\nPlease check your added Message-Paramters.\n\e[0m"; exit 1; fi
fi

#Sending ALL lovelaces, so only 1 receiver addresses
rxcnt="1"

assetBurnBech=$(convert_tokenName2BECH ${policyID} ${assetBurnName})
assetBurnSubject="${policyID}$(convert_assetNameASCII2HEX ${assetBurnName})"

echo -e "\e[0mBurning Asset \e[32m${assetBurnAmount} '${assetBurnName}'\e[0m with Policy \e[32m'${policyName}'\e[0m: ${assetBurnBech}"

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

if [[ ! "${metafile}" == "" ]]; then echo -e "\e[0mInclude Metadata-File:\e[32m ${metafile}\e[0m\n"; fi

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
                                if [[ "${utxoJSON}" == null ]]; then echo -e "\e[35mPayment-Address not included in the offline transferFile, please include it first online!\e[0m\n"; exit; fi
        fi

        #Only use UTXOs specied in the extra parameter if present
        if [[ ! "${filterForUTXO}" == "" ]]; then echo -e "\e[0mUTXO-Mode: \e[32mOnly using the UTXO with Hash ${filterForUTXO}\e[0m\n"; utxoJSON=$(filterFor_UTXO "${utxoJSON}" "${filterForUTXO}"); fi

        txcnt=$(jq length <<< ${utxoJSON}) #Get number of UTXO entries (Hash#Idx), this is also the number of --tx-in for the transaction
        if [[ ${txcnt} == 0 ]]; then echo -e "\e[35mNo funds on the Source Address!\e[0m\n"; exit; else echo -e "\e[32m${txcnt} UTXOs\e[0m found on the Source Address!\n"; fi

        #Calculating the total amount of lovelaces in all utxos on this address
        totalLovelaces=0

        #totalAssetsJSON="{}"; #Building a total JSON with the different assetstypes "policyIdHash.name", amount and name
	#Preload the new Asset to burn in the totalAssetsJSON with the negative number of assets to burn, will sum up later
	if [[ "${assetBurnName}" == "" ]]; then point=""; else point="."; fi
        assetBech=$(convert_tokenName2BECH ${policyID} ${assetBurnName})
	totalAssetsJSON=$( jq ". += {\"${policyID}${point}${assetBurnName}\":{amount: \"-${assetBurnAmount}\", name: \"${assetBurnName}\", bech: \"${assetBech}\"}}" <<< "{}")
        totalPolicyIDsJSON="{}"; #Holds the different PolicyIDs as values "policyIDHash", length is the amount of different policyIDs

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
                        echo -e "\e[32m${totalAssetsCnt} Asset-Type(s) / ${totalPolicyIDsCnt} different PolicyIDs - \e[91m PREVIEW after burning!\e[0m\n"
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


#There are metadata files attached, list them:
if [[ ! "${metafileList}" == "" ]]; then echo -e "\e[0mInclude Metadata-File(s):\e[32m ${metafileList}\e[0m\n"; fi

#There are transactionMessages attached, show the metadatafile:
if [[ ! "${transactionMessage}" == "{}" ]]; then echo -e "\e[0mInclude Transaction-Message-Metadata-File:\e[32m ${transactionMessageMetadataFile}\n\e[90m"; cat ${transactionMessageMetadataFile}; echo -e "\e[0m"; fi


#Read ProtocolParameters
if ${onlineMode}; then
                        protocolParametersJSON=$(${cardanocli} query protocol-parameters ${magicparam} ); #onlinemode
                  else
                        protocolParametersJSON=$(jq ".protocol.parameters" <<< ${offlineJSON}); #offlinemode
                  fi
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
minOutUTXO=$(calc_minOutUTXO "${protocolParametersJSON}" "${sendToAddr}+0${assetsOutString}")

if [[ "${assetBurnName}" == "" ]]; then point=""; else point="."; fi

#Check amount of assets after the burn
assetAmountAfterBurn=$(jq -r ".\"${policyID}${point}${assetBurnName}\".amount" <<< ${totalAssetsJSON})
if [[ $(bc <<< "${assetAmountAfterBurn}<0") -eq 1 ]]; then echo -e "\n\e[35mYou can't burn ${assetBurnAmount} ${assetBurnName} Assets with that policy, you can only burn $(bc <<< "${assetBurnAmount}+${assetAmountAfterBurn}") Assets!\e[0m"; exit; fi

#Generate Dummy-TxBody file for fee calculation
txBodyFile="${tempDir}/dummy.txbody"
rm ${txBodyFile} 2> /dev/null
${cardanocli} transaction build-raw ${nodeEraParam} ${txInString} --tx-out "${sendToAddr}+0${assetsOutString}" --mint "-${assetBurnAmount} ${policyID}${point}${assetBurnName}" --minting-script-file ${policyName}.policy.script --invalid-hereafter ${ttl} --fee 0 ${metafileParameter} --out-file ${txBodyFile}
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
fee=$(${cardanocli} transaction calculate-min-fee --tx-body-file ${txBodyFile} --protocol-params-file <(echo ${protocolParametersJSON}) --tx-in-count ${txcnt} --tx-out-count ${rxcnt} ${magicparam} --witness-count 2 --byron-witness-count 0 | awk '{ print $1 }')
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
echo -e "\e[0mMinimum Transaction Fee for ${txcnt}x TxIn & ${rxcnt}x TxOut: \e[32m $(convertToADA ${fee}) ADA / ${fee} lovelaces \e[90m"

lovelacesToSend=$(( ${totalLovelaces} - ${fee} ))

echo -e "\e[0mLovelaces to return to source ${toAddr}.addr: \e[33m $(convertToADA ${lovelacesToSend}) ADA / ${lovelacesToSend} lovelaces \e[90m"

#Checking about minimum funds in the UTX0
if [[ ${lovelacesToSend} -lt ${minOutUTXO} ]]; then echo -e "\e[35mNot enough funds on the source Addr! Minimum UTXO value is ${minOutUTXO} lovelaces.\e[0m"; exit; fi

#if [[ ! "${metafile}" == "" ]]; then echo -e "\n\e[0mAdding Metadata-File: \e[32m${metafile} \e[90m\n"; cat ${metafile}; fi

txBodyFile="${tempDir}/$(basename ${fromAddr}).txbody"
txFile="${tempDir}/$(basename ${fromAddr}).tx"

echo
echo -e "\e[0mBuilding the unsigned transaction body: \e[32m ${txBodyFile} \e[90m"
echo

#Building unsigned transaction body
rm ${txBodyFile} 2> /dev/null
${cardanocli} transaction build-raw ${nodeEraParam} ${txInString} --tx-out "${sendToAddr}+${lovelacesToSend}${assetsOutString}" --mint "-${assetBurnAmount} ${policyID}${point}${assetBurnName}" --minting-script-file ${policyName}.policy.script --invalid-hereafter ${ttl} --fee ${fee} ${metafileParameter} --out-file ${txBodyFile}
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

cat ${txBodyFile}
echo

echo -e "\e[0mSign the unsigned transaction body with the \e[32m${fromAddr}.skey\e[0m and \e[32m${policyName}.policy.skey\e[0m: \e[32m ${txFile} \e[90m"
echo

#Sign the unsigned transaction body with the SecureKey
rm ${txFile} 2> /dev/null
${cardanocli} transaction sign --tx-body-file ${txBodyFile} --signing-key-file ${fromAddr}.skey --signing-key-file ${policyName}.policy.skey ${magicparam} --out-file ${txFile}
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

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
                                if [[ ${magicparam^^} =~ (MAINNET|1097911063) ]]; then echo -e "\e[0mTracking: \e[32m${transactionExplorer}${txID}\n\e[0m"; fi


                                #Updating the ${policyName}.${assetBurnName}.asset json
                                assetFileName="${policyName}.${assetBurnName}.asset"

                                #Make assetFileSkeleton
                                assetFileSkeletonJSON=$(jq ". += {metaName: \"${assetBurnName}\",
                                                                  metaDescription: \"\",
                                                                  \"---\": \"--- Optional additional info ---\",
                                                                  metaTicker: \"\",
                                                                  metaUrl: \"\",
                                                                  metaDecimals: \"0\",
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
                                newValue=$(bc <<< "${oldValue} - ${assetBurnAmount}")
                                assetFileJSON=$( jq ". += {minted: \"${newValue}\",
                                                           name: \"${assetBurnName}\",
                                                           bechName: \"${assetBurnBech}\",
                                                           policyID: \"${policyID}\",
                                                           policyValidBeforeSlot: \"${ttlFromScript}\",
                                                           subject: \"${assetBurnSubject}\",
                                                           lastUpdate: \"$(date -R)\",
                                                           lastAction: \"burn ${assetBurnAmount}\"}" <<< ${assetFileJSON})


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


			                                #Make assetFileSkeleton
			                                assetFileSkeletonJSON=$(jq ". += {metaName: \"${assetBurnName}\",
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
			                                newValue=$(bc <<< "${oldValue} - ${assetBurnAmount}")
			                                assetFileJSON=$( jq ". += {minted: \"${newValue}\",
			                                                           name: \"${assetBurnName}\",
			                                                           bechName: \"${assetBurnBech}\",
			                                                           policyID: \"${policyID}\",
			                                                           policyValidBeforeSlot: \"${ttlFromScript}\",
			                                                           subject: \"${assetBurnSubject}\",
			                                                           lastUpdate: \"$(date -R)\",
			                                                           lastAction: \"burn ${assetBurnAmount} (only Offline proof)\"}" <<< ${assetFileJSON})

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

