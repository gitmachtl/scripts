#!/bin/bash

# Script is brought to you by ATADA_Stakepool, Telegram @atada_stakepool in
# cooperation with @TheRealAdamDean (BUFFY & SPIKE)

#load variables from common.sh
#       socket          Path to the node.socket (also exports socket to CARDANO_NODE_SOCKET_PATH)
#       genesisfile     Path to the genesis.json
#       magicparam      TestnetMagic parameter
#       cardanocli      Path to the cardano-cli executable
. "$(dirname "$0")"/00_common.sh

case $# in
  2 ) fromAddr="$(dirname $1)/$(basename $1 .addr)"; fromAddr=${fromAddr//.\//}
      metafile="$(dirname $2)/$(basename $2 .json).json"; metafile=${metafile//.\//};;
  * ) cat >&2 <<EOF
Usage:  $(basename $0) <From AddressName> <MetadataFileName>.json
EOF
  exit 1;; esac

#Check about the needed files
if [ ! -f "${fromAddr}.addr" ]; then echo -e "\n\e[35mERROR - \"${fromAddr}.addr\" does not exist! Please create it first with script 03a or 02.\e[0m"; exit 1; fi
if ! [[ -f "${fromAddr}.skey" || -f "${fromAddr}.hwsfile" ]]; then echo -e "\n\e[35mERROR - \"${fromAddr}.skey/hwsfile\" does not exist! Please create it first with script 03a or 02.\e[0m"; exit 1; fi

#This is a simplified Version of the sendLovelaces.sh script so, it will always be a SendALLLovelaces transaction + Metafile
toAddr=${fromAddr}
lovelacesToSend="ALL"

#Throw an error if the metadata.json file does not exist
if [ ! -f "${metafile}" ]; then
  echo -e "The specified '${metafile}' file does not exist. Please try again."
  exit 1
fi

sendFromAddr=$(cat ${fromAddr}.addr)
sendToAddr=$(cat ${toAddr}.addr)
check_address "${sendFromAddr}"; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
check_address "${sendToAddr}"; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

rxcnt="1"

echo
echo -e "\e[0mUsing lovelaces from Address\e[32m ${fromAddr}.addr\e[0m to send the metafile\e[32m ${metafile}\e[0m:"
echo

#get live values
currentTip=$(get_currentTip)
ttl=$(get_currentTTL)
currentEPOCH=$(get_currentEpoch)

echo -e "\e[0mCurrent Slot-Height:\e[32m ${currentTip} \e[0m(setting TTL[invalid_hereafter] to ${ttl})"
echo
echo -e "\e[0mSource/Destination Address ${fromAddr}.addr:\e[32m ${sendFromAddr} \e[90m"
echo -e "\e[0mAttached Metafile:\e[32m ${metafile} \e[90m"
echo

#-------------------------------------
#
# Checking UTXO Data of the source address and gathering data about total lovelaces and total assets
#
        #Get UTX0 Data for the address. When in online mode of course from the node and the chain, in offlinemode from the transferFile
        if ${onlineMode}; then
                                utxo=$(${cardanocli} ${subCommand} query utxo --address ${sendFromAddr} --cardano-mode ${magicparam} ${nodeEraParam}); checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi;
                                utxoJSON=$(generate_UTXO "${utxo}" "${sendFromAddr}")
                                #utxoJSON=$(${cardanocli} ${subCommand} query utxo --address ${sendFromAddr} --cardano-mode ${magicparam} ${nodeEraParam} --out-file /dev/stdout); checkError "$?";
                          else
                                readOfflineFile;        #Reads the offlinefile into the offlineJSON variable
                                utxoJSON=$(jq -r ".address.\"${sendFromAddr}\".utxoJSON" <<< ${offlineJSON})
                                if [[ "${utxoJSON}" == null ]]; then echo -e "\e[35mPayment-Address not included in the offline transferFile, please include it first online!\e[0m\n"; exit 1; fi
        fi

	txcnt=$(jq length <<< ${utxoJSON}) #Get number of UTXO entries (Hash#Idx), this is also the number of --tx-in for the transaction
	if [[ ${txcnt} == 0 ]]; then echo -e "\e[35mNo funds on the Source Address!\e[0m\n"; exit 1; else echo -e "\e[32m${txcnt} UTXOs\e[0m found on the Source Address!\n"; fi

        #Convert UTXO into mary style if UTXO is shelley/allegra style
        if [[ ! "$(jq -r '[.[]][0].amount | type' <<< ${utxoJSON})" == "array" ]]; then utxoJSON=$(convert_UTXO "${utxoJSON}"); fi

	#Calculating the total amount of lovelaces in all utxos on this address
        #totalLovelaces=$(jq '[.[].amount[0]] | add' <<< ${utxoJSON})
        totalLovelaces=0
        totalAssetsJSON="{}"; 	#Building a total JSON with the different assetstypes "policyIdHash.name", amount and name
        totalPolicyIDsJSON="{}"; #Holds the different PolicyIDs as values "policyIDHash", length is the amount of different policyIDs

	assetsOutString="";	#This will hold the String to append on the --tx-out if assets present or it will be empty

        #For each utxo entry, check the utxo#index and check if there are also any assets in that utxo#index
        #LEVEL 1 - different UTXOs
        for (( tmpCnt=0; tmpCnt<${txcnt}; tmpCnt++ ))
        do
        utxoHashIndex=$(jq -r "keys_unsorted[${tmpCnt}]" <<< ${utxoJSON})
        utxoAmount=$(jq -r ".\"${utxoHashIndex}\".amount[0]" <<< ${utxoJSON})   #Lovelaces
        totalLovelaces=$(bc <<< "${totalLovelaces} + ${utxoAmount}")
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
                                newValue=$(bc <<< "${oldValue}+${assetAmount}")
                                totalAssetsJSON=$( jq ". += {\"${assetHash}${point}${assetName}\":{amount: \"${newValue\"}, name: \"${assetName}\"}}" <<< ${totalAssetsJSON})
                                echo -e "\e[90m            PolID: ${assetHash}\tAmount: ${assetAmount} ${assetName}\e[0m"
                                done
                         done
        fi
        txInString="${txInString} --tx-in ${utxoHashIndex}"
        done
        echo -e "\e[0m-----------------------------------------------------------------------------------------------------"
        echo -e "Total ADA on the Address:\e[32m $(convertToADA ${totalLovelaces}) ADA / ${totalLovelaces} lovelaces \e[0m\n"

        totalPolicyIDsCnt=$(jq length <<< ${totalPolicyIDsJSON});
        totalAssetsCnt=$(jq length <<< ${totalAssetsJSON})
        if [[ ${totalAssetsCnt} -gt 0 ]]; then
                        echo -e "\e[32m${totalAssetsCnt} Asset-Type(s) / ${totalPolicyIDsCnt} different PolicyIDs\e[0m found on the Address!\n"
                        printf "\e[0m%-70s %16s %s\n" "PolicyID.Name:" "Total-Amount:" "Name:"
                        for (( tmpCnt=0; tmpCnt<${totalAssetsCnt}; tmpCnt++ ))
                        do
                        assetHashName=$(jq -r "keys[${tmpCnt}]" <<< ${totalAssetsJSON})
                        assetAmount=$(jq -r ".\"${assetHashName}\".amount" <<< ${totalAssetsJSON})
                        assetName=$(jq -r ".\"${assetHashName}\".name" <<< ${totalAssetsJSON})
                        printf "\e[90m%-70s \e[32m%16s %s\e[0m\n" "${assetHashName}" "${assetAmount}" "${assetName}"
                        if [[ $(bc <<< "${assetAmount}>0") -eq 1 ]]; then assetsOutString+="+${assetAmount} ${assetHashName}"; fi #only include in the sendout if more than zero
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

#-------------------------------------


#Generate Dummy-TxBody file for fee calculation
txBodyFile="${tempDir}/dummy.txbody"
rm ${txBodyFile} 2> /dev/null
${cardanocli} ${subCommand} transaction build-raw ${nodeEraParam} ${txInString} --tx-out "${dummyShelleyAddr}+0${assetsOutString}" --invalid-hereafter ${ttl} --fee 0 --metadata-json-file ${metafile} --out-file ${txBodyFile}
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
fee=$(${cardanocli} ${subCommand} transaction calculate-min-fee --tx-body-file ${txBodyFile} --protocol-params-file <(echo ${protocolParametersJSON}) --tx-in-count ${txcnt} --tx-out-count ${rxcnt} ${magicparam} --witness-count 1 --byron-witness-count 0 | awk '{ print $1 }')
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
echo -e "\e[0mMinimum Transaction Fee for ${txcnt}x TxIn & ${rxcnt}x TxOut: \e[32m $(convertToADA ${fee}) ADA / ${fee} lovelaces \e[90m"

lovelacesToSend=$(( ${totalLovelaces} - ${fee} ))

echo -e "\e[0mLovelaces that will be returned to payment Address (UTXO-Sum minus fees): \e[32m $(convertToADA ${lovelacesToSend}) ADA / ${lovelacesToSend} lovelaces \e[90m (min. required ${minOutUTXO} lovelaces)"
echo

#Checking about minimum funds in the UTX0
if [[ ${lovelacesToSend} -lt ${minOutUTXO} ]]; then echo -e "\e[35mNot enough funds on the source Addr! Minimum UTXO value is ${minOutUTXO} lovelaces.\e[0m"; exit 1; fi


txBodyFile="${tempDir}/$(basename ${fromAddr}).txbody"
txFile="${tempDir}/$(basename ${fromAddr}).tx"

echo
echo -e "\e[0mBuilding the unsigned transaction body: \e[32m ${txBodyFile} \e[90m"
echo

#Building unsigned transaction body
rm ${txBodyFile} 2> /dev/null
${cardanocli} ${subCommand} transaction build-raw ${nodeEraParam} ${txInString} --tx-out "${sendToAddr}+${lovelacesToSend}${assetsOutString}" --invalid-hereafter ${ttl} --fee ${fee} --metadata-json-file ${metafile} --out-file ${txBodyFile}
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

cat ${txBodyFile}
echo

echo -e "\e[0mSign the unsigned transaction body with the \e[32m${fromAddr}.skey/hwsfile\e[0m: \e[32m ${txFile} \e[90m"
echo

#If payment address is a hardware wallet, use the cardano-hw-cli for the signing
if [[ -f "${fromAddr}.hwsfile" ]]; then
        start_HwWallet; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
        tmp=$(${cardanohwcli} transaction sign --tx-body-file ${txBodyFile} --hw-signing-file ${fromAddr}.hwsfile ${magicparam} --out-file ${txFile} 2> /dev/stdout)
        if [[ "${tmp^^}" == *"ERROR"* ]]; then echo -e "\e[35m${tmp}\e[0m\n"; exit 1; else echo -e "\e[32mDONE\e[0m\n"; fi
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
else
        ${cardanocli} ${subCommand} transaction sign --tx-body-file ${txBodyFile} --signing-key-file ${fromAddr}.skey ${magicparam} --out-file ${txFile}
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
fi

cat ${txFile}
echo

if [ "${ENV_SKIP_PROMPT^^}" == "YES" ] || ask "\e[33mDoes this look good for you, continue ?" N; then
	echo
        if ${onlineMode}; then  #onlinesubmit
                                echo -ne "\e[0mSubmitting the transaction via the node..."
                                ${cardanocli} ${subCommand} transaction submit --tx-file ${txFile} --cardano-mode ${magicparam}
                                checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
                                echo -e "\e[32mDONE\n"

                                #Show the TxID
                                txID=$(${cardanocli} ${subCommand} transaction txid --tx-file ${txFile}); echo -e "\e[0mTxID is: \e[32m${txID}\e[0m"
                                checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi;
                                if [[ ${magicparam} == "--mainnet" ]]; then echo -e "\e[0mTracking: \e[32mhttps://cardanoscan.io/transaction/${txID}\n"; fi

                          else  #offlinestore
                                txFileJSON=$(cat ${txFile} | jq .)
                                offlineJSON=$( jq ".transactions += [ { date: \"$(date -R)\",
                                                                        type: \"Transaction\",
                                                                        era: \"$(jq -r .protocol.era <<< ${offlineJSON})\",
                                                                        fromAddr: \"${fromAddr}\",
                                                                        sendFromAddr: \"${sendFromAddr}\",
                                                                        toAddr: \"${toAddr}\",
                                                                        sendToAddr: \"${sendToAddr}\",
                                                                        txJSON: ${txFileJSON} } ]" <<< ${offlineJSON})
                                #Write the new offileFile content
                                offlineJSON=$( jq ".history += [ { date: \"$(date -R)\", action: \"signed utxo-transaction from '${fromAddr}' to '${toAddr}' - votingMeta\" } ]" <<< ${offlineJSON})
                                offlineJSON=$( jq ".general += {offlineCLI: \"${versionCLI}\" }" <<< ${offlineJSON})
                                offlineJSON=$( jq ".general += {offlineNODE: \"${versionNODE}\" }" <<< ${offlineJSON})
                                echo "${offlineJSON}" > ${offlineFile}
                                #Readback the tx content and compare it to the current one
                                readback=$(cat ${offlineFile} | jq -r ".transactions[-1].txJSON")
                                if [[ "${txFileJSON}" == "${readback}" ]]; then
                                                        showOfflineFileInfo;
                                                        echo -e "\e[33mTransaction txJSON has been stored in the '$(basename ${offlineFile})'.\nYou can now transfer it to your online machine for execution.\e[0m\n";
                                                 else
                                                        echo -e "\e[35mERROR - Could not verify the written data in the '$(basename ${offlineFile})'. Retry again or generate a new '$(basename ${offlineFile})'.\e[0m\n";
                                fi

        fi

fi


echo -e "\e[0m\n"
