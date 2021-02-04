#!/bin/bash

# Script is brought to you by ATADA_Stakepool, Telegram @atada_stakepool

#load variables from common.sh
#       socket          Path to the node.socket (also exports socket to CARDANO_NODE_SOCKET_PATH)
#       genesisfile     Path to the genesis.json
#       magicparam      TestnetMagic parameter
#       cardanocli      Path to the cardano-cli executable
#       cardanonode     Path to the cardano-node executable
. "$(dirname "$0")"/00_common.sh

#Check command line parameter
case $# in
  2 ) deregPayName="$(dirname $2)/$(basename $2 .addr)"; deregPayName=${deregPayName/#.\//};
      poolFile="$(dirname $1)/$(basename $(basename $1 .json) .pool)"; poolFile=${poolFile/#.\//};;
  * ) cat >&2 <<EOF
ERROR - Usage: $(basename $0) <PoolNodeName> <PaymentAddrForDeRegistration>
EOF
  exit 1;; esac

#Check if referenced JSON file exists
if [ ! -f "${poolFile}.pool.json" ]; then echo -e "\n\e[34mERROR - ${poolFile}.pool.json does not exist! Please create a minimal first with script 07a.\e[0m"; exit 2; fi

#Small subroutine to read the value of the JSON and output an error if parameter is empty/missing
function readJSONparam() {
param=$(jq -r .$1 ${poolFile}.pool.json 2> /dev/null)
if [[ $? -ne 0 ]]; then echo "ERROR - ${poolFile}.pool.json is not a valid JSON file" >&2; exit 1;
elif [[ "${param}" == null ]]; then echo "ERROR - Parameter \"$1\" in ${poolFile}.pool.json does not exist" >&2; exit 1;
elif [[ "${param}" == "" ]]; then echo "ERROR - Parameter \"$1\" in ${poolFile}.pool.json is empty" >&2; exit 1;
fi
echo "${param}"
}

#Read the pool JSON file and extract the parameters -> report an error is something is missing or wrong/empty and exit
poolName=$(readJSONparam "poolName"); if [[ ! $? == 0 ]]; then exit 1; fi
deregCertFile=$(readJSONparam "deregCertFile"); if [[ ! $? == 0 ]]; then exit 1; fi
poolMetaTicker=$(readJSONparam "poolMetaTicker"); if [[ ! $? == 0 ]]; then exit 1; fi #only used to write out an description of this action in offline mode

#Checks for needed files
if [ ! -f "${deregCertFile}" ]; then echo -e "\n\e[34mERROR - \"${deregCertFile}\" does not exist! Please create it first with script 05d.\e[0m"; exit 2; fi
if [ ! -f "${poolName}.node.skey" ]; then echo -e "\n\e[34mERROR - \"${poolName}.node.skey\" does not exist! Please create it first with script 04a.\e[0m"; exit 2; fi
if [ ! -f "${deregPayName}.addr" ]; then echo -e "\n\e[35mERROR - \"${deregPayName}.addr\" does not exist! Please create it first with script 03a.\e[0m"; exit 1; fi
if [ ! -f "${deregPayName}.skey" ]; then echo -e "\n\e[35mERROR - \"${deregPayName}.skey\" does not exist! Please create it first with script 03a.\e[0m"; exit 1; fi

#-------------------------------------------------------------------------

echo -e "\e[0mDe-Register (retire) StakePool Certificate\e[32m ${deregCertFile}\e[0m with funds from Address\e[32m ${deregPayName}.addr\e[0m:"
echo

#get live values
currentTip=$(get_currentTip)
ttl=$(get_currentTTL)
currentEPOCH=$(get_currentEpoch)

echo -e "Current Slot-Height:\e[32m ${currentTip}\e[0m (setting TTL[invalid_hereafter] to ${ttl})"

rxcnt="1"               #transmit to one destination addr. all utxos will be sent back to the fromAddr

sendFromAddr=$(cat ${deregPayName}.addr); check_address "${sendFromAddr}";
sendToAddr=$(cat ${deregPayName}.addr); check_address "${sendToAddr}";

echo
echo -e "Pay fees from Address\e[32m ${deregPayName}.addr\e[0m: ${sendFromAddr}"
echo

#----------------------------------------------------------

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

        #Convert UTXO into mary style if UTXO is shelley/allegra style
        if [[ ! "$(jq -r '[.[]][0].amount | type' <<< ${utxoJSON})" == "array" ]]; then utxoJSON=$(convert_UTXO "${utxoJSON}"); fi

	#Calculating the total amount of lovelaces in all utxos on this address
        totalLovelaces=$(jq '[.[].amount[0]] | add' <<< ${utxoJSON})

        totalAssetsJSON="{}"; 	#Building a total JSON with the different assetstypes "policyIdHash.name", amount and name
        totalPolicyIDsJSON="{}"; #Holds the different PolicyIDs as values "policyIDHash", length is the amount of different policyIDs

	assetsOutString="";	#This will hold the String to append on the --tx-out if assets present or it will be empty

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
				if [[ "${assetName}" == "" ]]; then point=""; else point="."; fi
                                oldValue=$(jq -r ".\"${assetHash}${point}${assetName}\".amount" <<< ${totalAssetsJSON})
                                newValue=$((${oldValue}+${assetAmount}))
                                totalAssetsJSON=$( jq ". += {\"${assetHash}${point}${assetName}\":{amount: ${newValue}, name: \"${assetName}\"}}" <<< ${totalAssetsJSON})
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
                        echo -e "\e[32m${totalAssetsCnt} Asset-Type(s) / ${totalPolicyIDsCnt} different PolicyIDs\e[0m found on the Address!\n"
                        printf "\e[0m%-70s %16s %s\n" "PolicyID.Name:" "Total-Amount:" "Name:"
                        for (( tmpCnt=0; tmpCnt<${totalAssetsCnt}; tmpCnt++ ))
                        do
                        assetHashName=$(jq -r "keys[${tmpCnt}]" <<< ${totalAssetsJSON})
                        assetAmount=$(jq -r ".\"${assetHashName}\".amount" <<< ${totalAssetsJSON})
                        assetName=$(jq -r ".\"${assetHashName}\".name" <<< ${totalAssetsJSON})
                        printf "\e[90m%-70s \e[32m%16s %s\e[0m\n" "${assetHashName}" "${assetAmount}" "${assetName}"
                        if [[ ${assetAmount} -gt 0 ]]; then assetsOutString+="+${assetAmount} ${assetHashName}"; fi #only include in the sendout if more than zero
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

#----------------------------------------------------------------

#Make a variable for all signing keys
signingKeys="--signing-key-file ${deregPayName}.skey --signing-key-file ${poolName}.node.skey"

#Generate Dummy-TxBody file for fee calculation
txBodyFile="${tempDir}/dummy.txbody"
rm ${txBodyFile} 2> /dev/null
${cardanocli} ${subCommand} transaction build-raw ${nodeEraParam} ${txInString} --tx-out "${sendToAddr}+0${assetsOutString}" --invalid-hereafter ${ttl} --fee 0 --certificate ${deregCertFile} --out-file ${txBodyFile}
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

fee=$(${cardanocli} ${subCommand} transaction calculate-min-fee --tx-body-file ${txBodyFile} --protocol-params-file <(echo ${protocolParametersJSON}) --tx-in-count ${txcnt} --tx-out-count ${rxcnt} ${magicparam} --witness-count 2 --byron-witness-count 0 | awk '{ print $1 }')
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

echo -e "\e[0mMinimum transfer Fee for ${txcnt}x TxIn & ${rxcnt}x TxOut & 1x Certificate: \e[32m $(convertToADA ${fee}) ADA / ${fee} lovelaces \e[90m"

minDeRegistrationFees=${fee}
echo
echo -e "\e[0mMinimum funds required for de-registration (Sum of fees): \e[32m $(convertToADA ${minDeRegistrationFees}) ADA / ${minDeRegistrationFees} lovelaces \e[90m"
echo

#calculate new balance for destination address
lovelacesToSend=$(( ${totalLovelaces}-${minDeRegistrationFees} ))

echo -e "\e[0mLovelaces that will be returned to payment Address (UTXO-Sum minus fees): \e[32m $(convertToADA ${lovelacesToSend}) ADA / ${lovelacesToSend} lovelaces \e[90m (min. required ${minOutUTXO} lovelaces)"
echo

#Checking about minimum funds in the UTX0
if [[ ${lovelacesToSend} -lt ${minOutUTXO} ]]; then echo -e "\e[35mNot enough funds on the source Addr! Minimum UTXO value is ${minOutUTXO} lovelaces.\e[0m"; exit; fi

txBodyFile="${tempDir}/$(basename ${poolName}).txbody"
txFile="${tempDir}/$(basename ${poolName}).tx"

echo
echo -e "\e[0mBuilding the unsigned transaction body with\e[32m ${deregCertFile}\e[0m certificate: \e[32m ${txBodyFile} \e[90m"
echo

#Building unsigned transaction body
rm ${txBodyFile} 2> /dev/null
${cardanocli} ${subCommand} transaction build-raw ${nodeEraParam} ${txInString} --tx-out "${sendToAddr}+${lovelacesToSend}${assetsOutString}" --invalid-hereafter ${ttl} --fee ${fee} --certificate ${deregCertFile} --out-file ${txBodyFile}
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
cat ${txBodyFile}
echo
echo
echo -e "\e[0mSign the unsigned transaction body with the payment \e[32m${deregPayName}.skey\e[0m & node \e[32m${poolName}.node.skey\e[0m: \e[32m ${txFile} \e[90m"
echo

#Sign the unsigned transaction body with the SecureKey
rm ${txFile} 2> /dev/null
${cardanocli} ${subCommand} transaction sign --tx-body-file ${txBodyFile} ${signingKeys} ${magicparam} --out-file ${txFile}
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
cat ${txFile}
echo


if ask "\e[33mDoes this look good for you? Continue ?" N; then
        echo
        if ${onlineMode}; then  #onlinesubmit
                                echo -ne "\e[0mSubmitting the transaction via the node..."
                                ${cardanocli} ${subCommand} transaction submit --tx-file ${txFile} --cardano-mode ${magicparam}
                                #No error, so lets update the pool JSON file with the date and file the certFile was registered on the blockchain
                                if [[ $? -eq 0 ]]; then
                                file_unlock ${poolFile}.pool.json
                                newJSON=$(cat ${poolFile}.pool.json | jq ". += {deregSubmitted: \"$(date -R)\"}")
                                echo "${newJSON}" > ${poolFile}.pool.json
                                file_lock ${poolFile}.pool.json
                                echo -e "\e[32mDONE\n"
                                else
                                echo -e "\n\n\e[35mERROR (Code $?) !\e[0m"; exit 1;
                                fi
                                echo
                                echo -e "\e[0mStakepool Info JSON:\e[32m ${poolFile}.pool.json \e[90m"
                                cat ${poolFile}.pool.json
                                echo
				echo -e "\e[33mDon't de-register/delete your rewards staking account/address yet! You will receive the pool deposit fees on it!\n"
				echo -e "\e[0m\n"

                          else  #offlinestore
                                txFileJSON=$(cat ${txFile} | jq .)
                                offlineJSON=$( jq ".transactions += [ { date: \"$(date -R)\",
                                                                        type: \"PoolRetirement\",
                                                                        era: \"$(jq -r .protocol.era <<< ${offlineJSON})\",
                                                                        fromAddr: \"${deregPayName}\",
                                                                        sendFromAddr: \"${sendFromAddr}\",
                                                                        toAddr: \"${deregPayName}\",
                                                                        sendToAddr: \"${sendToAddr}\",
                                                                        poolMetaTicker: \"${poolMetaTicker}\",
                                                                        txJSON: ${txFileJSON} } ]" <<< ${offlineJSON})
                                #Write the new offileFile content
                                offlineJSON=$( jq ".history += [ { date: \"$(date -R)\", action: \"signed pool retirement transaction for '${poolMetaTicker}', payment via '${deregPayName}'\" } ]" <<< ${offlineJSON})
                                offlineJSON=$( jq ".general += {offlineCLI: \"${versionCLI}\" }" <<< ${offlineJSON})
                                echo "${offlineJSON}" > ${offlineFile}
                                #Readback the tx content and compare it to the current one
                                readback=$(cat ${offlineFile} | jq -r ".transactions[-1].txJSON")
                                if [[ "${txFileJSON}" == "${readback}" ]]; then
                                                        file_unlock ${poolFile}.pool.json
                                                        newJSON=$(cat ${poolFile}.pool.json | jq ". += {deregSubmitted: \"$(date -R) (only offline, no proof)\"}")
                                                        echo "${newJSON}" > ${poolFile}.pool.json
                                                        file_lock ${poolFile}.pool.json
                                                        echo
                                                        echo -e "\e[0mStakepool Info JSON:\e[32m ${poolFile}.pool.json \e[90m"
                                                        cat ${poolFile}.pool.json
                                                        echo
                                                        showOfflineFileInfo;
                                                        echo -e "\e[33mTransaction txJSON has been stored in the '$(basename ${offlineFile})'.\nYou can now transfer it to your online machine for execution.\e[0m\n";
                                                 else
                                                        echo -e "\e[35mERROR - Could not verify the written data in the '$(basename ${offlineFile})'. Retry again or generate a new '$(basename ${offlineFile})'.\e[0m\n";
                                fi

        fi

fi

