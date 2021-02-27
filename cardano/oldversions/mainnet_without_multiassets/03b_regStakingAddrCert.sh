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
  2 ) stakeAddr="$(dirname $1)/$(basename $1 .staking).staking"; stakeAddr=${stakeAddr/#.\//};
      fromAddr="$(dirname $2)/$(basename $2 .addr)"; fromAddr=${fromAddr/#.\//};;
  * ) cat >&2 <<EOF
Usage:  $(basename $0) <StakeAddressName> <Base/PaymentAddressName (paying for the registration fees)>
Example: $(basename $0) atada.staking atada.payment
EOF
  exit 1;; esac

#Check about required files: Registration Certificate, Signing Key and Address of the payment Account
#For StakeKeyRegistration
if [ ! -f "${stakeAddr}.cert" ]; then echo -e "\n\e[35mERROR - \"${stakeAddr}.cert\" Registration Certificate does not exist! Please create it first with script 03a.\e[0m"; exit 2; fi
if ! [[ -f "${stakeAddr}.skey" || -f "${stakeAddr}.hwsfile" ]]; then echo -e "\n\e[35mERROR - \"${stakeAddr}.skey/hwsfile\" Staking Signing Key or HardwareFile does not exist! Please create it first with script 03a.\e[0m"; exit 2; fi

#For payment
if [ ! -f "${fromAddr}.addr" ]; then echo -e "\n\e[35mERROR - \"${fromAddr}.addr\" does not exist! Please create it first with script 03a or 02.\e[0m"; exit 1; fi
if ! [[ -f "${fromAddr}.skey" || -f "${fromAddr}.hwsfile" ]]; then echo -e "\n\e[35mERROR - \"${fromAddr}.skey/hwsfile\" does not exist! Please create it first with script 03a or 02.\e[0m"; exit 1; fi

echo
echo -e "\e[0mRegister Staking Address\e[32m ${stakeAddr}.addr\e[0m with funds from Address\e[32m ${fromAddr}.addr\e[0m"
echo

#get values to register the staking address on the blockchain
#get live values
currentTip=$(get_currentTip)
ttl=$(get_currentTTL)
currentEPOCH=$(get_currentEpoch)

echo -e "Current Slot-Height:\e[32m ${currentTip}\e[0m (setting TTL[invalid_hereafter] to ${ttl})"

#adaToSend + fees will be taken out of the sendFromUTXO and sent back to the same Address

rxcnt="1"               #transmit to one destination addr. all utxos will be sent back to the fromAddr

sendFromAddr=$(cat ${fromAddr}.addr); check_address "${sendFromAddr}";
sendToAddr=$(cat ${fromAddr}.addr); check_address "${sendToAddr}";

echo
echo -e "Pay fees from Address\e[32m ${fromAddr}.addr\e[0m: ${sendFromAddr}"
echo

#------------------------------------------------
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

#----------------------------------------------------

#Generate Dummy-TxBody file for fee calculation
txBodyFile="${tempDir}/dummy.txbody"
rm ${txBodyFile} 2> /dev/null
#echo -e "${cardanocli} ${subCommand} transaction build-raw ${nodeEraParam} ${txInString} --tx-out "${sendToAddr}+0${assetsOutString}" --invalid-hereafter ${ttl} --fee 100 --certificate ${stakeAddr}.cert --out-file ${txBodyFile}"
${cardanocli} ${subCommand} transaction build-raw ${nodeEraParam} ${txInString} --tx-out "${sendToAddr}+0${assetsOutString}" --invalid-hereafter ${ttl} --fee 100 --certificate ${stakeAddr}.cert --out-file ${txBodyFile}
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

fee=$(${cardanocli} ${subCommand} transaction calculate-min-fee --tx-body-file ${txBodyFile} --protocol-params-file <(echo ${protocolParametersJSON}) --tx-in-count ${txcnt} --tx-out-count ${rxcnt} ${magicparam} --witness-count 2 --byron-witness-count 0 | awk '{ print $1 }')
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

echo -e "\e[0mMimimum transfer Fee for ${txcnt}x TxIn & ${rxcnt}x TxOut & 1x Certificate: \e[32m $(convertToADA ${fee}) ADA / ${fee} lovelaces \e[90m"
keyDepositFee=$(jq -r .keyDeposit <<< ${protocolParametersJSON})
echo -e "\e[0mKey Deposit Fee: \e[32m ${keyDepositFee} lovelaces \e[90m"
minRegistrationFund=$(( ${keyDepositFee}+${fee} ))

echo
echo -e "\e[0mMimimum funds required for registration (Sum of fees): \e[32m ${minRegistrationFund} lovelaces \e[90m"
echo

#calculate new balance for destination address
lovelacesToSend=$(( ${totalLovelaces}-${minRegistrationFund} ))

echo -e "\e[0mLovelaces that will be returned to payment Address (UTXO-Sum minus fees): \e[32m $(convertToADA ${lovelacesToSend}) ADA / ${lovelacesToSend} lovelaces \e[90m (min. required ${minOutUTXO} lovelaces)"
echo

#Checking about minimum funds in the UTX0
if [[ ${lovelacesToSend} -lt ${minOutUTXO} ]]; then echo -e "\e[35mNot enough funds on the source Addr! Minimum UTXO value is ${minOutUTXO} lovelaces.\e[0m"; exit; fi

txBodyFile="${tempDir}/$(basename ${fromAddr}).txbody"
txFile="${tempDir}/$(basename ${fromAddr}).tx"

echo -e "\e[0mBuilding the unsigned transaction body with the\e[32m ${stakeAddr}.cert\e[0m certificate: \e[32m ${txBodyFile} \e[90m"
echo

#Building unsigned transaction body
rm ${txBodyFile} 2> /dev/null
${cardanocli} ${subCommand} transaction build-raw ${nodeEraParam} ${txInString} --tx-out "${sendToAddr}+${lovelacesToSend}${assetsOutString}" --invalid-hereafter ${ttl} --fee ${fee} --certificate ${stakeAddr}.cert --out-file ${txBodyFile}
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

cat ${txBodyFile}
echo

echo -e "\e[0mSign the unsigned transaction body with the \e[32m${fromAddr}.skey/hwsfile\e[0m: \e[32m ${txFile} \e[0m"
echo

#Sign the unsigned transaction body with the SigningKey
rm ${txFile} 2> /dev/null

#If stakeaddress and payment address are from the same hardware files
paymentName=$(basename ${fromAddr} .payment) #contains the name before the .payment.addr extension
stakingName=$(basename ${stakeAddr} .staking) #contains the name before the .staking.addr extension
if [[ -f "${fromAddr}.hwsfile" && -f "${stakeAddr}.hwsfile" && "${paymentName}" == "${stakingName}" ]]; then
        start_HwWallet; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
        tmp=$(${cardanohwcli} transaction sign --tx-body-file ${txBodyFile} --hw-signing-file ${fromAddr}.hwsfile --hw-signing-file ${stakeAddr}.hwsfile  --change-output-key-file ${fromAddr}.hwsfile  --change-output-key-file ${stakeAddr}.hwsfile ${magicparam} --out-file ${txFile} 2> /dev/stdout)
        if [[ "${tmp^^}" == *"ERROR"* ]]; then echo -e "\e[35m${tmp}\e[0m\n"; exit 1; else echo -e "\e[32mDONE\e[0m\n"; fi
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

elif [[ -f "${stakeAddr}.skey" && -f "${fromAddr}.skey" ]]; then #with the normal cli skey
	${cardanocli} ${subCommand} transaction sign --tx-body-file ${txBodyFile} --signing-key-file ${fromAddr}.skey --signing-key-file ${stakeAddr}.skey ${magicparam} --out-file ${txFile}
else
echo -e "\e[35mThis combination is not allowed! A Hardware-Wallet can only be used to register its own staking key on the chain.\e[0m\n"; exit 1;
fi
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
echo -ne "\e[90m"
cat ${txFile}
echo

if ask "\n\e[33mDoes this look good for you, continue ?" N; then
        echo
        if ${onlineMode}; then  #onlinesubmit
                                echo -ne "\e[0mSubmitting the transaction via the node..."
                                ${cardanocli} ${subCommand} transaction submit --tx-file ${txFile} --cardano-mode ${magicparam}
                                checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
                                echo -e "\e[32mDONE\n"
                          else  #offlinestore
                                txFileJSON=$(cat ${txFile} | jq .)
                                offlineJSON=$( jq ".transactions += [ { date: \"$(date -R)\",
                                                                        type: \"StakeKeyRegistration\",
                                                                        era: \"$(jq -r .protocol.era <<< ${offlineJSON})\",
                                                                        stakeAddr: \"${stakeAddr}\",
                                                                        fromAddr: \"${fromAddr}\",
                                                                        sendFromAddr: \"${sendFromAddr}\",
                                                                        toAddr: \"${fromAddr}\",
                                                                        sendToAddr: \"${sendToAddr}\",
                                                                        txJSON: ${txFileJSON} } ]" <<< ${offlineJSON})
                                #Write the new offileFile content
                                offlineJSON=$( jq ".history += [ { date: \"$(date -R)\", action: \"signed staking key registration transaction for '${stakeAddr}', payment via '${fromAddr}'\" } ]" <<< ${offlineJSON})
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
