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
  4 ) fromAddr="$4";
      toAddr="$4";
      policyName="$3";
      assetBurnAmount="$2";
      assetBurnName="$1";;
  * ) cat >&2 <<EOF
Usage:  $(basename $0) <AssetName> <AssetAmount> <PolicyName> <PaymentAddressName>
EOF
  exit 1;; esac


#Check assetBurnName for alphanummeric only, 32 chars max
if [[ ! "${assetBurnName}" == "${assetBurnName//[^[:alnum:]]/}" ]]; then echo -e "\e[35mError - Your given AssetName should only contain alphanummeric chars!\e[0m"; exit; fi
if [[ ${#assetBurnName} -gt 32 ]]; then echo -e "\e[35mError - Your given AssetName is too long, maximum of 32 chars allowed!\e[0m"; exit; fi
if [[ ${assetBurnAmount} -lt 1 ]]; then echo -e "\e[35mError - The Amount of Assets to burn must be a positive number!\e[0m"; exit; fi

# Check for needed input files
if [ ! -f "${policyName}.policy.id" ]; then echo -e "\n\e[35mERROR - \"${policyName}.policy.id\" id-file does not exist! Please create it first with script 10.\e[0m"; exit 1; fi
if [ ! -f "${policyName}.policy.script" ]; then echo -e "\n\e[35mERROR - \"${policyName}.policy.script\" scriptfile does not exist! Please create it first with script 10.\e[0m"; exit 1; fi
if [ ! -f "${policyName}.policy.skey" ]; then echo -e "\n\e[35mERROR - \"${policyName}.policy.skey\" signing key does not exist! Please create it first with script 10.\e[0m"; exit 1; fi
if [ ! -f "${fromAddr}.skey" ]; then echo -e "\n\e[35mERROR - \"${fromAddr}.skey\" signing key does not exist! Please create it first with script 03a or 02.\e[0m"; exit 1; fi



policyID=$(cat ${policyName}.policy.id)

#Sending ALL lovelaces, so only 1 receiver addresses
rxcnt="1"

echo -e "\e[0mBurning Asset \e[32m${assetBurnAmount} '${assetBurnName}'\e[0m with Policy \e[32m'${policyName}'\e[0m:"
echo

#get live values
currentTip=$(get_currentTip)
ttl=$(get_currentTTL)
currentEPOCH=$(get_currentEpoch)

echo -e "\e[0mCurrent Slot-Height:\e[32m ${currentTip} \e[0m(setting TTL[invalid_hereafter] to ${ttl})"
echo

sendFromAddr=$(cat ${fromAddr}.addr)
sendToAddr=${sendFromAddr}

check_address "${sendFromAddr}"

echo -e "\e[0mPayment Address and Asset-Destination-Address ${fromAddr}.addr:\e[32m ${sendFromAddr} \e[90m"
echo

#Get UTX0 Data for the address
utxoJSON=$(${cardanocli} ${subCommand} query utxo --address ${sendFromAddr} --cardano-mode ${magicparam} ${nodeEraParam} --out-file /dev/stdout); checkError "$?";
txcnt=$(jq length <<< ${utxoJSON}) #Get number of UTXO entries (Hash#Idx)
if [[ ${txcnt} == 0 ]]; then echo -e "\e[35mNo funds on the Source Address!\e[0m\n"; exit; else echo -e "\e[32m${txcnt} UTXOs\e[0m found on the Source Address!\n"; fi

        #Calculating the total amount of lovelaces in all utxos on this address
        totalLovelaces=$(jq '[.[].amount[0]] | add' <<< ${utxoJSON})

        #totalAssetsJSON="{}"; #Building a total JSON with the different assetstypes "policyIdHash.name", amount and name
	#Preload the new Asset to burn in the totalAssetsJSON with the negative number of assets to burn, will sum up later
	totalAssetsJSON=$( jq ". += {\"${policyID}.${assetBurnName}\":{amount: -${assetBurnAmount}, name: \"${assetBurnName}\"}}" <<< "{}")

        #For each utxo entry, check the utxo#index and check if there are also any assets in that utxo#index
	#LEVEL 1 - different UTXOs
        for (( tmpCnt=0; tmpCnt<${txcnt}; tmpCnt++ ))
        do
        utxoHashIndex=$(jq -r "keys[${tmpCnt}]" <<< ${utxoJSON})
        #utxoAmount=$(jq -r "[.[].amount] | .[${tmpCnt}]" <<< ${utxoJSON}) #Alternative
        #utxoAmount=$(jq -r "[.[]][${tmpCnt}].amount" <<< ${utxoJSON}) #Alternative
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
        totalInADA=$(bc <<< "scale=6; ${totalLovelaces} / 1000000")
        echo -e "Total ADA on the Address:\e[32m  ${totalInADA} ADA / ${totalLovelaces} lovelaces \e[0m\n"

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

#Check amount of assets after the burn
assetAmountAfterBurn=$(jq -r ".\"${policyID}.${assetBurnName}\".amount" <<< ${totalAssetsJSON})
if [[ ${assetAmountAfterBurn} -lt 0 ]]; then echo -e "\n\e[35mYou can't burn ${assetBurnAmount} ${assetBurnName} Assets with that policy, you can only burn $((${assetBurnAmount}+${assetAmountAfterBurn})) Assets!\e[0m"; exit; fi


#Getting protocol parameters from the blockchain, calculating fees
${cardanocli} ${subCommand} query protocol-parameters --cardano-mode ${magicparam} ${nodeEraParam} > protocol-parameters.json
checkError "$?"

minUTXOvalue=$(cat protocol-parameters.json | jq -r .minUTxOValue)      #This value is the minimum value you have to send out in each --tx-out

#Generate Dummy-TxBody file for fee calculation
txBodyFile="${tempDir}/dummy.txbody"
rm ${txBodyFile} 2> /dev/null
${cardanocli} ${subCommand} transaction build-raw ${nodeEraParam} ${txInString} --tx-out "${dummyShelleyAddr}+0${assetsOutString}" --mint "-${assetBurnAmount} ${policyID}.${assetBurnName}" --invalid-hereafter ${ttl} --fee 0 --out-file ${txBodyFile}
fee=$(${cardanocli} ${subCommand} transaction calculate-min-fee --tx-body-file ${txBodyFile} --protocol-params-file protocol-parameters.json --tx-in-count ${txcnt} --tx-out-count ${rxcnt} ${magicparam} --witness-count 2 --byron-witness-count 0 | awk '{ print $1 }')
checkError "$?"
echo -e "\e[0mMinimum Transaction Fee for ${txcnt}x TxIn & ${rxcnt}x TxOut: \e[32m ${fee} lovelaces \e[90m"

lovelacesToSend=$(( ${totalLovelaces} - ${fee} ))

#lovelacesToReturn=0

#Checking about minimum funds in the UTX0
if [[ ${lovelacesToSend} -lt ${minUTXOvalue} ]]; then echo -e "\e[35mNot enough funds on the source Addr! Minimum UTXO value is ${minUTXOvalue} lovelaces.\e[0m"; exit; fi

echo -e "\e[0mLovelaces to return to source ${toAddr}.addr: \e[33m ${lovelacesToSend} lovelaces \e[90m"
#echo -e "\e[0mLovelaces to return to ${fromAddr}.addr: \e[32m ${lovelacesToReturn} lovelaces \e[90m"

echo

txBodyFile="${tempDir}/$(basename ${fromAddr}).txbody"
txFile="${tempDir}/$(basename ${fromAddr}).tx"

echo
echo -e "\e[0mBuilding the unsigned transaction body: \e[32m ${txBodyFile} \e[90m"
echo

#Building unsigned transaction body
rm ${txBodyFile} 2> /dev/null
${cardanocli} ${subCommand} transaction build-raw ${nodeEraParam} ${txInString} --tx-out "${sendToAddr}+${lovelacesToSend}${assetsOutString}" --mint "-${assetBurnAmount} ${policyID}.${assetBurnName}" --invalid-hereafter ${ttl} --fee ${fee} --out-file ${txBodyFile}
checkError "$?"
#echo "${cardanocli} ${subCommand} transaction build-raw ${nodeEraParam} ${txInString} --tx-out \"${sendToAddr}+${lovelacesToSend}${assetsOutString}\" --mint \"${assetBurnAmount} ${policyID}.${assetBurnName}\" --invalid-hereafter ${ttl}  --out-file ${txBodyFile}"

cat ${txBodyFile}
echo

echo -e "\e[0mSign the unsigned transaction body with the \e[32m${fromAddr}.skey\e[0m and \e[32m${policyName}.policy.skey\e[0m: \e[32m ${txFile} \e[90m"
echo

#Sign the unsigned transaction body with the SecureKey
rm ${txFile} 2> /dev/null
${cardanocli} ${subCommand} transaction sign --tx-body-file ${txBodyFile} --signing-key-file ${fromAddr}.skey --signing-key-file ${policyName}.policy.skey --script-file ${policyName}.policy.script ${magicparam} --out-file ${txFile}
checkError "$?"
#echo "${cardanocli} ${subCommand} transaction sign --tx-body-file ${txBodyFile} --signing-key-file ${fromAddr}.skey --signing-key-file ${policyName}.policy.skey --script-file ${policyName}.policy.script ${magicparam} --out-file ${txFile}"

cat ${txFile}
echo

if ask "\e[33mDoes this look good for you, continue ?" N; then
	echo
	echo -ne "\e[0mSubmitting the transaction via the node..."
	${cardanocli} ${subCommand} transaction submit --tx-file ${txFile} --cardano-mode ${magicparam}
	checkError "$?"
	echo -e "\e[32mDONE\n"

        #Updating the ${policyName}.${assetBurnName}.asset json
        assetFileName="${policyName}.${assetBurnName}.asset"
        if [ ! -f "${assetFileName}" ]; then echo "{}" > ${assetFileName}; fi #generate an empty json if no file present
        oldValue=$(jq -r ".minted" ${assetFileName})
        newValue=$(( ${oldValue} - ${assetBurnAmount} ))
        assetFileJSON=$( jq ". += {minted: ${newValue}, name: \"${assetBurnName}\", policyID: \"${policyID}\", lastUpdate: \"$(date)\", lastAction: \"burn ${assetBurnAmount}\"}" < ${assetFileName})

        file_unlock ${assetFileName}
        echo -e "${assetFileJSON}" > ${assetFileName}
        file_lock ${assetFileName}

        echo -e "\e[0mAsset-File: \e[32m ${assetFileName} \e[90m\n"
        cat ${assetFileName}
        echo


fi


echo -e "\e[0m\n"



