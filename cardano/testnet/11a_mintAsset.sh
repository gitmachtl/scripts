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
      assetMintName="$(echo $1 | cut -d. -f 2-)"; assetMintName=$(basename "${assetMintName}" .asset); assetMintInputName=${assetMintName}; #assetMintName=${assetMintName//./};
      assetMintAmount="$2";
      else
      cat >&2 <<EOF
Usage:  $(basename $0) <PolicyName.AssetName> <AssetAmount> <PaymentAddressName>
        [Opt: Transaction-Metadata.json - this is not the TokenRegistryServer Metadata!]
        [Opt: Message comment, starting with "msg: ...", | is the separator]


Examples: $(basename $0) mypolicy.mytoken 100 myfunds.addr ... to mint 100 mytoken on the payment address myfunds
          $(basename $0) mypolicy.{00010203} 500 myotherfunds.addr ... to mint 500 tokens with hexname 0x00010203 on the payment address myotherfunds

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

#Check assetMintName for alphanummeric only, 32 chars max
if [[ "${assetMintName}" == ".asset" ]]; then assetMintName="";
elif [[ "${assetMintName,,}" =~ ^\{([[:xdigit:]][[:xdigit:]]){1,}\}$ ]]; then assetMintName=${assetMintName,,}; assetMintName=${assetMintName:1:-1}; assetHexMintName=${assetMintName}
elif [[ ! "${assetMintName}" == "${assetMintName//[^[:alnum:]]/}" ]]; then echo -e "\e[35mError - Your given AssetName '${assetMintName}' should only contain alphanummeric chars!
Otherwise you can use the binary hexformat like \"{8ac33ed560000eacce}\" as the assetName! Make sure to use full hex-pairs.\e[0m"; exit 1;
else assetMintName=$(convert_assetNameASCII2HEX ${assetMintName})
fi

#assetMintName is in HEX-Format after this point, the given assetMintName is stored in assetMintInputName for filehandling, etc.

if [[ ${#assetMintName} -gt 64 ]]; then echo -e "\e[35mError - Your given AssetName is too long, maximum of 32 bytes allowed!\e[0m"; exit 1; fi  #checking for a length of 64 because a byte is two hexchars
if [[ ${assetMintAmount} -lt 1 ]]; then echo -e "\e[35mError - The Amount of Assets to mint must be a positive number!\e[0m"; exit 1; fi

# Check for needed input files - missing - work to do :-)
if [ ! -f "${policyName}.policy.id" ]; then echo -e "\n\e[35mERROR - \"${policyName}.policy.id\" id-file does not exist! Please create it first with script 10.\e[0m"; exit 1; fi
if [ ! -f "${policyName}.policy.script" ]; then echo -e "\n\e[35mERROR - \"${policyName}.policy.script\" scriptfile does not exist! Please create it first with script 10.\e[0m"; exit 1; fi
if ! [[ -f "${policyName}.policy.skey" || -f "${policyName}.policy.hwsfile" ]]; then echo -e "\n\e[35mERROR - \"${policyName}.policy.skey/hwsfile\" does not exist! Please create it first with script 10.\e[0m"; exit 2; fi
policyID=$(cat ${policyName}.policy.id)

if [ ! -f "${fromAddr}.addr" ]; then echo -e "\n\e[35mERROR - \"${fromAddr}.addr\" does not exist! Please create it first with script 03a or 02.\e[0m"; exit 1; fi
#if [ ! -f "${fromAddr}.skey" ]; then echo -e "\n\e[35mERROR - \"${fromAddr}.skey\" does not exist! Please create it first with script 03a or 02. It's not possible to mint on a hw-wallet for now!\e[0m"; exit 1; fi
if ! [[ -f "${fromAddr}.skey" || -f "${fromAddr}.hwsfile" ]]; then echo -e "\n\e[35mERROR - \"${fromAddr}.skey/hwsfile\" does not exist! Please create it first with script 03a or 02.\e[0m"; exit 1; fi

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

assetMintBech=$(convert_tokenName2BECH "${policyID}${assetMintName}" ""); #assetMintName already in HEX-Format
assetMintSubject="${policyID}${assetMintName}" #assetMintName already in HEX-Format

echo -e "\e[0mMinting Asset \e[32m${assetMintAmount} '${assetMintInputName}' -> '$(convert_assetNameHEX2ASCII_ifpossible ${assetMintName})'\e[0m with Policy \e[32m'${policyName}'\e[0m: ${assetMintBech}"

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
                                showProcessAnimation "Query-UTXO: " &
                                utxo=$(${cardanocli} query utxo --address ${sendFromAddr} ${magicparam} ); stopProcessAnimation; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi;
                                showProcessAnimation "Convert-UTXO: " &
                                utxoJSON=$(generate_UTXO "${utxo}" "${sendFromAddr}"); stopProcessAnimation;
                                #utxoJSON=$(${cardanocli} query utxo --address ${sendFromAddr} ${magicparam} --out-file /dev/stdout); checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi;
                          else
                                readOfflineFile;        #Reads the offlinefile into the offlineJSON variable
                                utxoJSON=$(jq -r ".address.\"${sendFromAddr}\".utxoJSON" <<< ${offlineJSON})
                                if [[ "${utxoJSON}" == null ]]; then echo -e "\e[35mPayment-Address not included in the offline transferFile, please include it first online!\e[0m\n"; exit 1; fi
        fi

        #Only use UTXOs specified in the extra parameter if present
        if [[ ! "${filterForUTXO}" == "" ]]; then echo -e "\e[0mUTXO-Mode: \e[32mOnly using the UTXO with Hash ${filterForUTXO}\e[0m\n"; utxoJSON=$(filterFor_UTXO "${utxoJSON}" "${filterForUTXO}"); fi

        txcnt=$(jq length <<< ${utxoJSON}) #Get number of UTXO entries (Hash#Idx), this is also the number of --tx-in for the transaction
        if [[ ${txcnt} == 0 ]]; then echo -e "\e[35mNo funds on the Source Address!\e[0m\n"; exit 1; else echo -e "\e[32m${txcnt} UTXOs\e[0m found on the Source Address!\n"; fi

        #Calculating the total amount of lovelaces in all utxos on this address
        totalLovelaces=0

        #totalAssetsJSON="{}"; #Building a total JSON with the different assetstypes "policyIdHash.name", amount and name
	#Preload the new Asset to mint in the totalAssetsJSON

	if [[ "${assetMintName}" == "" ]]; then point=""; else point="."; fi

	assetBech=$(convert_tokenName2BECH "${policyID}${assetMintName}" "")
	assetTmpName=$(convert_assetNameHEX2ASCII_ifpossible "${assetMintName}") #if it starts with a . -> ASCII showable name, otherwise the HEX-String

	totalAssetsJSON=$( jq ". += {\"${policyID}${point}${assetMintName}\":{amount: \"${assetMintAmount}\", name: \"${assetTmpName}\", bech: \"${assetBech}\"}}" <<< "{}")
        totalPolicyIDsJSON="{}"; #Holds the different PolicyIDs as values "policyIDHash", length is the amount of different policyIDs
	totalPolicyIDsJSON=$( jq ". += {\"${policyID}\": 1}" <<< ${totalPolicyIDsJSON})

        #For each utxo entry, check the utxo#index and check if there are also any assets in that utxo#index
        #LEVEL 1 - different UTXOs


        readarray -t utxoHashIndexArray <<< $(jq -r "keys_unsorted[]" <<< ${utxoJSON})
        readarray -t utxoLovelaceArray <<< $(jq -r "flatten | .[].value.lovelace" <<< ${utxoJSON})
        readarray -t assetsEntryCntArray <<< $(jq -r "flatten | .[].value | del (.lovelace) | length" <<< ${utxoJSON})
        readarray -t assetsEntryJsonArray <<< $(jq -c "flatten | .[].value | del (.lovelace)" <<< ${utxoJSON})
        readarray -t utxoDatumHashArray <<< $(jq -r "flatten | .[].datumhash" <<< ${utxoJSON})

        for (( tmpCnt=0; tmpCnt<${txcnt}; tmpCnt++ ))
        do
        utxoHashIndex=${utxoHashIndexArray[${tmpCnt}]}
        utxoAmount=${utxoLovelaceArray[${tmpCnt}]} #Lovelaces
        totalLovelaces=$(bc <<< "${totalLovelaces} + ${utxoAmount}" )
        echo -e "Hash#Index: ${utxoHashIndex}\tAmount: ${utxoAmount}"; if [[ ! "${utxoDatumHashArray[${tmpCnt}]}" == null ]]; then echo -e " DatumHash: ${utxoDatumHashArray[${tmpCnt}]}"; fi
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

                                case ${assetHash} in
                                        f0ff48bbb7bbe9d59a40f1ce90e9e9d0ff5002ec48f232b49ca0fb9a )      #$adahandle
                                                echo -e "\e[90m                           Asset: ${assetBech}  ADA Handle: \$$(convert_assetNameHEX2ASCII ${assetName}) ${assetTmpName}\e[0m"
                                                ;;
                                        * ) #default
                                                echo -e "\e[90m                           Asset: ${assetBech}  Amount: ${assetAmount} ${assetTmpName}\e[0m"
                                                ;;
                                esac

                                done
                        done
        fi
        txInString="${txInString} --tx-in ${utxoHashIndex}"
        done
        echo -e "\e[0m-----------------------------------------------------------------------------------------------------"
        echo -e "Total ADA on the Address:\e[32m  $(convertToADA ${totalLovelaces}) ADA / ${totalLovelaces} lovelaces \e[0m\n"

        totalPolicyIDsCnt=$(jq length <<< ${totalPolicyIDsJSON});
        totalAssetsCnt=$(jq length <<< ${totalAssetsJSON})

        #Get a sorted list of the AssetHashes into a separate Array
        #totalAssetsHASHsorted=$(jq "keys | sort_by( split(\".\")[1]|length) | sort_by( split(\".\")[0])" 2> /dev/null <<< ${totalAssetsJSON})

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

                        if $queryTokenRegistry; then if $onlineMode; then metaResponse=$(curl -sL -m 20 "${tokenMetaServer}${assetHashHex}"); else metaResponse=$(jq -r ".tokenMetaServer.\"${assetHashHex}\"" <<< ${offlineJSON}); fi
                                metaAssetName=$(jq -r ".name.value | select (.!=null)" 2> /dev/null <<< ${metaResponse}); if [[ ! "${metaAssetName}" == "" ]]; then metaAssetName="${metaAssetName} "; fi
                                metaAssetTicker=$(jq -r ".ticker.value | select (.!=null)" 2> /dev/null <<< ${metaResponse})
                        fi

                        if [[ "${assetName}" == "." ]]; then assetName=""; fi

                        printf "\e[90m%-70s \e[32m%16s %44s  \e[90m%-7s  \e[36m%s\e[0m\n" "${assetHashName:0:56}${assetName}" "${assetAmount}" "${assetBech}" "${metaAssetTicker}" "${metaAssetName}"
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

if [[ "${assetMintName}" == "" ]]; then point=""; else point="."; fi

#Generate Dummy-TxBody file for fee calculation
txBodyFile="${tempDir}/dummy.txbody"
rm ${txBodyFile} 2> /dev/null
${cardanocli} transaction build-raw --cddl-format ${nodeEraParam} ${txInString} --tx-out "${sendToAddr}+0${assetsOutString}" --mint "${assetMintAmount} ${policyID}${point}${assetMintName}" --minting-script-file ${policyName}.policy.script --invalid-hereafter ${ttl} --fee 0 ${metafileParameter} --out-file ${txBodyFile}
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

txWitnessPolicyFile="${tempDir}/$(basename ${policyName}).witness"
rm ${txWitnessPolicyFile} 2> /dev/null

txWitnessPaymentFile="${tempDir}/$(basename ${fromAddr}).witness"
rm ${txWitnessPaymentFile} 2> /dev/null


echo
echo -e "\e[0mBuilding the unsigned transaction body: \e[32m ${txBodyFile} \e[90m"
echo

#Building unsigned transaction body
rm ${txBodyFile} 2> /dev/null
${cardanocli} transaction build-raw --cddl-format ${nodeEraParam} ${txInString} --tx-out "${sendToAddr}+${lovelacesToSend}${assetsOutString}" --mint "${assetMintAmount} ${policyID}${point}${assetMintName}" --minting-script-file ${policyName}.policy.script --invalid-hereafter ${ttl} --fee ${fee} ${metafileParameter} --out-file ${txBodyFile}
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

dispFile=$(cat ${txBodyFile}); if ${cropTxOutput} && [[ ${#dispFile} -gt 4000 ]]; then echo "${dispFile:0:4000} ... (cropped)"; else echo "${dispFile}"; fi
echo

#do the TxBody autocorrection if actions are for a hw-wallet   (same if conditions as below)
if [ -f "${policyName}.policy.hwsfile" ] || [ -f "${fromAddr}.hwsfile" ]; then
	echo -ne "\e[0mAutocorrect the TxBody for canonical order: "
	tmp=$(autocorrect_TxBodyFile "${txBodyFile}"); if [ $? -ne 0 ]; then echo -e "\e[35m${tmp}\e[0m\n\n"; exit 1; fi
	echo -e "\e[32m${tmp}\e[0m\n"
fi

echo -e "\e[0mSign the Tx-Body with the \e[32m${fromAddr}.skey|hwsfile\e[0m and \e[32m${policyName}.policy.skey|hwsfile\e[0m: \e[32m ${txFile} \e[90m"
echo

#If policy is a hw-based one, collect the witness via the cardano-hw-cli for the signing
if [[ -f "${policyName}.policy.hwsfile" ]]; then

        if ! ask "\e[0mAdding the Policy-Witness signing from a local Hardware-Wallet key '\e[33m${policyName}\e[0m', continue?" Y; then echo; echo -e "\e[35mABORT - Witness Signing aborted...\e[0m"; echo; exit 2; fi
        start_HwWallet; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
        tmp=$(${cardanohwcli} transaction witness --tx-file ${txBodyFile} --hw-signing-file ${policyName}.policy.hwsfile --out-file ${txWitnessPolicyFile} ${magicparam} 2> /dev/stdout)
        if [[ "${tmp^^}" =~ (ERROR|DISCONNECT) ]]; then echo -e "\e[35m${tmp}\e[0m\n"; exit 1; else echo -e "\e[32mDONE\e[0m\n"; fi
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

else #generate the policy witness via the cli

	${cardanocli} transaction witness --tx-body-file ${txBodyFile} --signing-key-file ${policyName}.policy.skey ${magicparam} --out-file ${txWitnessPolicyFile}
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

fi

#Generate the witness for the payment key

#If the payment address is a hw-based one, collect the witness via the cardano-hw-cli for the signing
if [[ -f "${fromAddr}.hwsfile" ]]; then

        if ! ask "\e[0mAdding the Payment-Witness signing from a local Hardware-Wallet key '\e[33m${fromAddr}.hwsfile\e[0m', continue?" Y; then echo; echo -e "\e[35mABORT - Witness Signing aborted...\e[0m"; echo; exit 2; fi
        start_HwWallet; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
        tmp=$(${cardanohwcli} transaction witness --tx-file ${txBodyFile} --hw-signing-file ${fromAddr}.hwsfile --change-output-key-file ${fromAddr}.hwsfile ${magicparam} --out-file ${txWitnessPaymentFile} 2> /dev/stdout)
        if [[ "${tmp^^}" =~ (ERROR|DISCONNECT) ]]; then echo -e "\e[35m${tmp}\e[0m\n"; exit 1; else echo -e "\e[32mDONE\e[0m\n"; fi
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

else #generate the payment witness via the cli

	${cardanocli} transaction witness --tx-body-file ${txBodyFile} --signing-key-file ${fromAddr}.skey ${magicparam} --out-file ${txWitnessPaymentFile}
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

fi


#Assemble all witnesses into the final TxBody
rm ${txFile} 2> /dev/null
${cardanocli} transaction assemble --tx-body-file ${txBodyFile} --witness-file ${txWitnessPolicyFile} --witness-file ${txWitnessPaymentFile} --out-file ${txFile}
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

echo -ne "\e[90m"
dispFile=$(cat ${txFile}); if ${cropTxOutput} && [[ ${#dispFile} -gt 4000 ]]; then echo "${dispFile:0:4000} ... (cropped)"; else echo "${dispFile}"; fi
echo

#Do a txSize Check to not exceed the max. txSize value
cborHex=$(jq -r .cborHex < ${txFile})
txSize=$(( ${#cborHex} / 2 ))
maxTxSize=$(jq -r .maxTxSize <<< ${protocolParametersJSON})
if [[ ${txSize} -le ${maxTxSize} ]]; then echo -e "\e[0mTransaction-Size: ${txSize} bytes (max. ${maxTxSize})\n"
                                     else echo -e "\n\e[35mError - ${txSize} bytes Transaction-Size is too big! The maximum is currently ${maxTxSize} bytes.\e[0m\n"; exit 1; fi

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

				assetTmpName=$(convert_assetNameHEX2ASCII_ifpossible ${assetMintName}); if [[ "${assetTmpName:0:1}" == "." ]]; then assetTmpName=${assetTmpName:1}; fi

			        #Updating the ${policyName}.${assetMintInputName}.asset json
			        assetFileName="${policyName}.${assetMintInputName}.asset"

				#Make assetFileSkeleton
                                assetFileSkeletonJSON=$(jq ". += {metaName: \"${assetTmpName:0:50}\",
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


#Currently disabled by IOHK
#                                                                                         metaSubUnitDecimals: 0,
#                                                                                         metaSubUnitName: \"\",


			        oldValue=$(jq -r ".minted" <<< ${assetFileJSON}); if [[ "${oldValue}" == "" ]]; then oldValue=0; fi
			        newValue=$(bc <<< "${oldValue} + ${assetMintAmount}")
			        assetFileJSON=$( jq ". += {minted: \"${newValue}\",
                                                           name: \"${assetTmpName}\",
							   hexname: \"${assetHexMintName}\",
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
                                offlineJSON=$( jq ".history += [ { date: \"$(date -R)\", action: \"minted ${assetMintAmount} '${assetMintInputName}' on '${fromAddr}'\" } ]" <<< ${offlineJSON})
                                offlineJSON=$( jq ".general += {offlineCLI: \"${versionCLI}\" }" <<< ${offlineJSON})
                                offlineJSON=$( jq ".general += {offlineNODE: \"${versionNODE}\" }" <<< ${offlineJSON})
                                echo "${offlineJSON}" > ${offlineFile}
                                #Readback the tx content and compare it to the current one
                                readback=$(cat ${offlineFile} | jq -r ".transactions[-1].txJSON")
                                if [[ "${txFileJSON}" == "${readback}" ]]; then

			                                #Updating the ${policyName}.${assetMintInputName}.asset json
			                                assetFileName="${policyName}.${assetMintInputName}.asset"

							assetTmpName=$(convert_assetNameHEX2ASCII_ifpossible ${assetMintName}); if [[ "${assetTmpName:0:1}" == "." ]]; then assetTmpName=${assetTmpName:1}; fi

			                                #Make assetFileSkeleton
			                                assetFileSkeletonJSON=$(jq ". += {metaName: \"${assetTmpName}\",
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
			                                                           name: \"${assetTmpName}\",
										   hexname: \"${assetHexMintName}\",
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



