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
  4|5 ) fromAddr="$(dirname $1)/$(basename $1 .addr)"; fromAddr=${fromAddr/#.\//}
      toAddr="$(dirname $2)/$(basename $2 .addr)"; toAddr=${toAddr/#.\//}
      assetToSend="$3";
      amountToSend="$4";;
  * ) cat >&2 <<EOF
Usage:  $(basename $0) <From AddressName> <To AddressName or HASH> <PolicyID.Name of the asset OR <PATHtoNAME>.asset of the asset file> <Amount of assets to send OR keyword ALL> [Optional Amount of lovelaces to attach, normally zero]
EOF
  exit 1;; esac

if [[ $# -eq 5 ]]; then lovelacesToSend="$5"; else lovelacesToSend=0; fi

if [ ! -f "${fromAddr}.addr" ]; then echo -e "\n\e[35mERROR - \"${fromAddr}.addr\" does not exist! Please create it first with script 03a or 02.\e[0m"; exit 1; fi
if [ ! -f "${fromAddr}.skey" ]; then echo -e "\n\e[35mERROR - \"${fromAddr}.skey\" does not exist! Please create it first with script 03a or 02.\e[0m"; exit 1; fi

#Check if toAddr file doesn not exists, make a dummy one in the temp directory and fill in the given parameter as the hash address
if [ ! -f "${toAddr}.addr" ]; then echo "$(basename ${toAddr})" > ${tempDir}/tempTo.addr; toAddr="${tempDir}/tempTo"; fi

#Check if the assetToSend is a file xxx.asset then read out the data from the file instead
if [ -f "${assetToSend}.asset" ]; then assetToSend="$(jq -r .policyID < ${assetToSend}.asset).$(jq -r .name < ${assetToSend}.asset)"; fi

echo -e "\e[0mSending assets from Address\e[32m ${fromAddr}.addr\e[0m to Address\e[32m ${toAddr}.addr\e[0m:"
echo

#get live values
currentTip=$(get_currentTip)
ttl=$(get_currentTTL)
currentEPOCH=$(get_currentEpoch)

echo -e "\e[0mCurrent Slot-Height:\e[32m ${currentTip} \e[0m(setting TTL[invalid_hereafter] to ${ttl})"
echo

sendFromAddr=$(cat ${fromAddr}.addr)
sendToAddr=$(cat ${toAddr}.addr)

check_address "${sendFromAddr}"
check_address "${sendToAddr}"

echo -e "\e[0mSource Address ${fromAddr}.addr:\e[32m ${sendFromAddr} \e[90m"
echo -e "\e[0mDestination Address ${toAddr}.addr:\e[32m ${sendToAddr} \e[90m"
echo

#
# Checking UTXO Data of the source address and gathering data about total lovelaces and total assets
#
        #Get UTX0 Data for the address. When in online mode of course from the node and the chain, in offlinemode from the transferFile
        if ${onlineMode}; then
                                utxoJSON=$(${cardanocli} ${subCommand} query utxo --address ${sendFromAddr} --cardano-mode ${magicparam} ${nodeEraParam} --out-file /dev/stdout); checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi;
                          else
                                readOfflineFile;        #Reads the offlinefile into the offlineJSON variable
                                utxoJSON=$(jq -r ".address.\"${sendFromAddr}\".utxoJSON" <<< ${offlineJSON})
                                if [[ "${utxoJSON}" == null ]]; then echo -e "\e[35mPayment-Address not included in the offline transferFile, please include it first online!\e[0m\n"; exit; fi
        fi

	txcnt=$(jq length <<< ${utxoJSON}) #Get number of UTXO entries (Hash#Idx), this is also the number of --tx-in for the transaction
	if [[ ${txcnt} == 0 ]]; then echo -e "\e[35mNo funds on the Source Address!\e[0m\n"; exit; else echo -e "\e[32m${txcnt} UTXOs\e[0m found on the Source Address!\n"; fi

	#Calculating the total amount of lovelaces in all utxos on this address
        totalLovelaces=$(jq '[.[].amount[0]] | add' <<< ${utxoJSON})

        totalAssetsJSON="{}"; 	#Building a total JSON with the different assetstypes "policyIdHash.name", amount and name
        totalPolicyIDsJSON="{}"; #Holds the different PolicyIDs as values "policyIDHash", length is the amount of different policyIDs

	assetsReturnString="";	#This will hold the String to append on the --tx-out if assets present or it will be empty

        #For each utxo entry, check the utxo#index and check if there are also any assets in that utxo#index
        #LEVEL 1 - different UTXOs
        for (( tmpCnt=0; tmpCnt<${txcnt}; tmpCnt++ ))
        do
        utxoHashIndex=$(jq -r "keys_unsorted[${tmpCnt}]" <<< ${utxoJSON})
        utxoAmount=$(jq -r ".\"${utxoHashIndex}\".amount[0]" <<< ${utxoJSON})   #Lovelaces
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
                                oldValue=$(jq -r ".\"${assetHash}.${assetName}\".amount" <<< ${totalAssetsJSON})
                                newValue=$((${oldValue}+${assetAmount}))
                                totalAssetsJSON=$( jq ". += {\"${assetHash}.${assetName}\":{amount: ${newValue}, name: \"${assetName}\"}}" <<< ${totalAssetsJSON})
                                echo -e "\e[90m            PolID: ${assetHash}\tAmount: ${assetAmount} ${assetName}\e[0m"
                                done
                         done
        fi
        txInString="${txInString} --tx-in ${utxoHashIndex}"
        done
        echo -e "\e[0m-----------------------------------------------------------------------------------------------------"
        echo -e "Total ADA on the Address:\e[32m  $(convertToADA ${totalLovelaces}) ADA / ${totalLovelaces} lovelaces \e[0m\n"

	totalPolicyIDsCnt=$(jq length <<< ${totalPolicyIDsJSON});

	#Calculating the amount of the asset to send out, using the given amount of using all of the assets amount
	echo -e "\e[0mAsset-Type to send to ${toAddr}.addr:\e[33m ${assetToSend} \e[0m"
	echo

	#Currently on the source address
	assetAmount=$(jq -r ".\"${assetToSend}\".amount" <<< ${totalAssetsJSON})
        assetName=$(jq -r ".\"${assetToSend}\".name" <<< ${totalAssetsJSON})
	#If there is no asset of that type, exit with an error
	if [[ ${assetAmount} -gt 0 ]]; then
			        echo -e "\e[0mAsset-Amount currenty on ${fromAddr}.addr:\e[32m ${assetAmount} ${assetName} \e[0m"
        				else
				echo -e "\n\e[35mError - This asset is not available on the source address!\e[0m\n"; exit 2;
	fi

	#If keyword ALL was used, set the amountToSend to the available amount on the source address
	if [[ "${amountToSend^^}" == "ALL" ]]; then amountToSend=${assetAmount}; fi

        echo -e "\e[0mAsset-Amount to send to ${toAddr}.addr:\e[33m ${amountToSend} ${assetName} \e[0m"

        if [[ ${amountToSend} -lt 1 ]]; then  echo -e "\n\e[35mError - Please input a positive sending amount (integer)!\e[0m\n"; exit 2; fi

	amountToReturn=$(( ${assetAmount} - ${amountToSend} ));	#the rest amount of the asset that stays on the source address

        if [[ ${amountToReturn} -ge 0 ]]; then
                                echo -e "\e[0mAsset-Amount that stays on the source Address:\e[32m ${amountToReturn} ${assetName} \e[0m"
                                        else
                                echo -e "\n\e[35mError - You can't send out more amounts of this assets than it is available on the source address!\e[0m\n"; exit 2;
        fi

	#Update the new value in the totalAssetsJSON
	totalAssetsJSON=$( jq ". += {\"${assetToSend}\":{amount: ${amountToReturn}, name: \"${assetName}\"}}" <<< ${totalAssetsJSON})

	echo

        totalAssetsCnt=$(jq length <<< ${totalAssetsJSON})
        if [[ ${totalAssetsCnt} -gt 0 ]]; then
                        echo -e "\e[32m${totalAssetsCnt} Asset-Type(s) / ${totalPolicyIDsCnt} Policy-IDs \e[0m - Remaining assets on the source address\n"
                        printf "\e[0m%-70s %16s %s\n" "PolicyID.Name:" "Total-Amount:" "Name:"
                         for (( tmpCnt=0; tmpCnt<${totalAssetsCnt}; tmpCnt++ ))
                        do
                        assetHashName=$(jq -r "keys[${tmpCnt}]" <<< ${totalAssetsJSON})
                        assetAmount=$(jq -r ".\"${assetHashName}\".amount" <<< ${totalAssetsJSON})
                        assetName=$(jq -r ".\"${assetHashName}\".name" <<< ${totalAssetsJSON})
                        printf "\e[90m%-70s \e[32m%16s %s\e[0m\n" "${assetHashName}" "${assetAmount}" "${assetName}"
                        if [[ ${assetAmount} -gt 0 ]]; then assetsReturnString+="+${assetAmount} ${assetHashName}"; fi #only include in the sendout if more than zero
                        done
        fi

	assetsSendString="+${amountToSend} ${assetToSend}"

echo

#
# Set the right rxcnt, in this case its always 2. One external destination address, one return address (sourceAddress)
#

rxcnt=2

#Read ProtocolParameters
if ${onlineMode}; then
                        protocolParametersJSON=$(${cardanocli} ${subCommand} query protocol-parameters --cardano-mode ${magicparam} ${nodeEraParam}); #onlinemode
                  else
                        protocolParametersJSON=$(jq ".protocol.parameters" <<< ${offlineJSON}); #offlinemode
                  fi
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
minOutUTXO=$(get_minOutUTXO "${protocolParametersJSON}" "1" "1")  #one asset will be sent out, so total assetcount=1 and policyidcount=1
if [[ ${amountToReturn} -gt 0 ]]; then
 					minReturnUTXO=$(get_minOutUTXO "${protocolParametersJSON}" "${totalAssetsCnt}" "${totalPolicyIDsCnt}") #restamount of the sending asset still on the source so full number of assets to return
                                        else
					minReturnUTXO=$(get_minOutUTXO "${protocolParametersJSON}" "$(( ${totalAssetsCnt} - 1 ))" "${totalPolicyIDsCnt}") #the choosen asset is transfered completly, so total number - 1
fi


#Generate Dummy-TxBody file for fee calculation
txBodyFile="${tempDir}/dummy.txbody"
rm ${txBodyFile} 2> /dev/null
${cardanocli} ${subCommand} transaction build-raw ${nodeEraParam} ${txInString} --tx-out "${dummyShelleyAddr}+0${assetsSendString}" --tx-out "${dummyShelleyAddr}+0${assetsReturnString}" --invalid-hereafter ${ttl} --fee 0 --out-file ${txBodyFile}
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
fee=$(${cardanocli} ${subCommand} transaction calculate-min-fee --tx-body-file ${txBodyFile} --protocol-params-file <(echo ${protocolParametersJSON}) --tx-in-count ${txcnt} --tx-out-count ${rxcnt} ${magicparam} --witness-count 1 --byron-witness-count 0 | awk '{ print $1 }')
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

echo -e "\e[0mMinimum Transaction Fee for ${txcnt}x TxIn & ${rxcnt}x TxOut: \e[32m $(convertToADA ${fee}) ADA / ${fee} lovelaces \e[90m"

#
# Set the right amount of lovelacesToSend, lovelacesToReturn and also check about sendinglimits like minUTxOValue for returning assets if available
#

echo -e "\e[0mMinimum UTXO value for sending the asset: \e[32m ${minOutUTXO} lovelaces \e[90m"
echo
if [[ ${lovelacesToSend} -lt ${minOutUTXO} ]]; then lovelacesToSend=${minOutUTXO}; fi
echo -e "\e[0mLovelaces to send to ${toAddr}.addr: \e[33m $(convertToADA ${lovelacesToSend}) ADA / ${lovelacesToSend} lovelaces \e[90m"

lovelacesToReturn=$(( ${totalLovelaces} - ${fee} - ${lovelacesToSend} ))
echo -e "\e[0mLovelaces to return to ${fromAddr}.addr: \e[32m $(convertToADA ${lovelacesToReturn}) ADA / ${lovelacesToReturn} lovelaces \e[90m"
if [[ ${lovelacesToReturn} -lt ${minReturnUTXO} ]]; then echo -e "\e[35mError - Not enough funds on the source Addr! Minimum UTXO value to return is ${minReturnUTXO} lovelaces.\e[0m"; exit; fi

txBodyFile="${tempDir}/$(basename ${fromAddr}).txbody"
txFile="${tempDir}/$(basename ${fromAddr}).tx"

echo
echo -e "\e[0mBuilding the unsigned transaction body: \e[32m ${txBodyFile} \e[90m"
echo

#Building unsigned transaction body
rm ${txBodyFile} 2> /dev/null
${cardanocli} ${subCommand} transaction build-raw ${nodeEraParam} ${txInString} --tx-out "${sendToAddr}+${lovelacesToSend}${assetsSendString}" --tx-out "${sendFromAddr}+${lovelacesToReturn}${assetsReturnString}" --invalid-hereafter ${ttl} --fee ${fee} --out-file ${txBodyFile}
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

cat ${txBodyFile}
echo

echo -e "\e[0mSign the unsigned transaction body with the \e[32m${fromAddr}.skey\e[0m: \e[32m ${txFile} \e[90m"
echo

#Sign the unsigned transaction body with the SecureKey
rm ${txFile} 2> /dev/null
${cardanocli} ${subCommand} transaction sign --tx-body-file ${txBodyFile} --signing-key-file ${fromAddr}.skey ${magicparam} --out-file ${txFile} 
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

cat ${txFile}
echo

if ask "\e[33mDoes this look good for you, continue ?" N; then
	echo
        if ${onlineMode}; then  #onlinesubmit
                                echo -ne "\e[0mSubmitting the transaction via the node..."
                                ${cardanocli} ${subCommand} transaction submit --tx-file ${txFile} --cardano-mode ${magicparam}
                                checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
                                echo -e "\e[32mDONE\n"
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
                                offlineJSON=$( jq ".history += [ { date: \"$(date -R)\", action: \"generated and signed utxo-token-transaction from '${fromAddr}' to '${toAddr}'\" } ]" <<< ${offlineJSON})
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



