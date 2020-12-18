#!/bin/bash

# Script is brought to you by ATADA_Stakepool, Telegram @atada_stakepool

#load variables from common.sh
#       socket          Path to the node.socket (also exports socket to CARDANO_NODE_SOCKET_PATH)
#       genesisfile     Path to the genesis.json
#       magicparam      TestnetMagic parameter
#       cardanocli      Path to the cardano-cli executable
. "$(dirname "$0")"/00_common.sh

case $# in
  2|3 ) stakeAddr="$1";
      toAddr="$2";;
  * ) cat >&2 <<EOF
Usage:  $(basename $0) <StakeAddressName> <To AddressName> [optional <FeePaymentAddressName>]
Ex.: $(basename $0) atada.staking atada.payment        (claims the rewards from atada.staking.addr and sends them to atada.payment.addr, atada.payment.addr pays the fees)
Ex.: $(basename $0) atada.staking atada.payment funds  (claims the rewards from atada.staking.addr and sends them to atada.payment.addr, funds.addr pays the fees)
EOF
  exit 1;; esac

#Check if an optional fee payment address is given and different to the receiver address
fromAddr=${toAddr}
if [[ $# -eq 3 ]]; then fromAddr=$3; fi
if [[ "${fromAddr}" == "${toAddr}" ]]; then rxcnt="1"; else rxcnt="2"; fi


#Checks for needed files
if [ ! -f "${stakeAddr}.addr" ]; then echo -e "\n\e[35mERROR - \"${stakeAddr}.addr\" does not exist!\e[0m"; exit 1; fi
if [ ! -f "${stakeAddr}.skey" ]; then echo -e "\n\e[35mERROR - \"${stakeAddr}.skey\" does not exist!\e[0m"; exit 1; fi
if [ ! -f "${fromAddr}.addr" ]; then echo -e "\n\e[35mERROR - \"${fromAddr}.addr\" does not exist!\e[0m"; exit 1; fi
if [ ! -f "${fromAddr}.skey" ]; then echo -e "\n\e[35mERROR - \"${fromAddr}.skey\" does not exist!\e[0m"; exit 1; fi
if [ ! -f "${toAddr}.addr" ]; then echo -e "\n\e[35mERROR - \"${toAddr}.addr\" does not exist!\e[0m"; exit 1; fi


echo -e "\e[0mClaim Staking Rewards from Address\e[32m ${stakeAddr}.addr\e[0m with funds from Address\e[32m ${fromAddr}.addr\e[0m"
echo
echo

#get live values
currentTip=$(get_currentTip)
ttl=$(get_currentTTL)
currentEPOCH=$(get_currentEpoch)

echo -e "Current Slot-Height:\e[32m ${currentTip}\e[0m (setting TTL[invalid_hereafter] to ${ttl})"

sendFromAddr=$(cat ${fromAddr}.addr); check_address "${sendFromAddr}"
sendToAddr=$(cat ${toAddr}.addr); check_address "${sendToAddr}"
stakingAddr=$(cat ${stakeAddr}.addr); check_address "${stakingAddr}"

echo
echo -e "Claim all rewards from Address ${stakeAddr}.addr: \e[32m${stakingAddr}\e[0m"
echo
echo -e "Send the rewards to Address ${toAddr}.addr: \e[32m${sendToAddr}\e[0m"
echo -e "Pay fees from Address ${fromAddr}.addr: \e[32m${sendFromAddr}\e[0m"
echo

	rewardsJSON=$(${cardanocli} ${subCommand} query stake-address-info --address ${stakingAddr} --cardano-mode ${magicparam} ${nodeEraParam} | jq -rc .)
        checkError "$?"

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
        if [[ ! ${delegationPoolID} == null ]]; then echo -e "   \tAccount is delegated to a Pool with ID: \e[32m${delegationPoolID}\e[0m"; fi

        echo

        done

	if [[ ${rewardsSum} -eq 0 ]]; then exit 1; fi;

        if [[ ${rewardsEntryCnt} -gt 1 ]]; then echo -e "   \t-----------------------------------------\n"; echo -e "   \tTotal Rewards: \e[33m${rewardsSumInADA} ADA / ${rewardsSum} lovelaces\e[0m\n"; fi


#-------------------------------------

#
# Checking UTXO Data of the source address and gathering data about total lovelaces and total assets
#
	utxoJSON=$(${cardanocli} ${subCommand} query utxo --address ${sendFromAddr} --cardano-mode ${magicparam} ${nodeEraParam} --out-file /dev/stdout); checkError "$?";
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
        utxoHashIndex=$(jq -r "keys[${tmpCnt}]" <<< ${utxoJSON})
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
        totalInADA=$(bc <<< "scale=6; ${totalLovelaces} / 1000000")
        echo -e "Total ADA on the Address:\e[32m  ${totalInADA} ADA / ${totalLovelaces} lovelaces \e[0m\n"
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

#Getting protocol parameters from the chain
protocolParametersJSON=$(${cardanocli} ${subCommand} query protocol-parameters --cardano-mode ${magicparam} ${nodeEraParam})
checkError "$?"
minOutUTXO=$(get_minOutUTXO "${protocolParametersJSON}" "${totalAssetsCnt}" "${totalPolicyIDsCnt}")

#-------------------------------------

#withdrawal string
withdrawal="${stakingAddr}+${rewardsSum}"

#Generate Dummy-TxBody file for fee calculation
txBodyFile="${tempDir}/dummy.txbody"
rm ${txBodyFile} 2> /dev/null
if [[ ${rxcnt} == 1 ]]; then
                        ${cardanocli} ${subCommand} transaction build-raw ${nodeEraParam} ${txInString} --tx-out "${sendToAddr}+0${assetsOutString}" --invalid-hereafter ${ttl} --fee 0 --withdrawal ${withdrawal} --out-file ${txBodyFile}
			checkError "$?"
                        else
                        ${cardanocli} ${subCommand} transaction build-raw ${nodeEraParam} ${txInString} --tx-out "${sendFromAddr}+0${assetsOutString}" --tx-out ${sendToAddr}+0 --invalid-hereafter ${ttl} --fee 0 --withdrawal ${withdrawal} --out-file ${txBodyFile}
			checkError "$?"
fi
fee=$(${cardanocli} ${subCommand} transaction calculate-min-fee --tx-body-file ${txBodyFile} --protocol-params-file <(echo ${protocolParametersJSON}) --tx-in-count ${txcnt} --tx-out-count ${rxcnt} ${magicparam} --witness-count 2 --byron-witness-count 0 | awk '{ print $1 }')

echo -e "\e[0mMimimum transfer Fee for ${txcnt}x TxIn & ${rxcnt}x TxOut & Withdrawal: \e[32m ${fee} lovelaces \e[90m"

#If only one address (paying for the fees and also receiving the rewards)
#If two different addresse (fromAddr is paying for the fees, toAddr is getting the rewards)
if [[ ${rxcnt} == 1 ]]; then

			#calculate the lovelaces to return to the payment address
			lovelacesToReturn=$(( ${totalLovelaces}-${fee}+${rewardsSum} ))
			#Checking about minimum funds in the UTX0
                        echo -e "\e[0mLovelaces that will be returned to destination Address (UTXO-Sum - fees + rewards): \e[33m ${lovelacesToReturn} lovelaces \e[90m"
			if [[ ${lovelacesToReturn} -lt ${minOutUTXO} ]]; then echo -e "\e[35mNot enough funds on the source Addr! Minimum UTXO value is ${minOutUTXO} lovelaces.\e[0m"; exit; fi

			echo

			else

                        #calculate the lovelaces to return to the fee payment address
                        lovelacesToReturn=$(( ${totalLovelaces}-${fee} ))
                        #Checking about minimum funds in the UTX0
                        echo -e "\e[0mLovelaces that will be sent to the destination Address (rewards): \e[33m ${rewardsSum} lovelaces \e[90m"
                        echo -e "\e[0mLovelaces that will be returned to the fee payment Address (UTXO-Sum - fees): \e[32m ${lovelacesToReturn} lovelaces \e[90m"
                        if [[ ${lovelacesToReturn} -lt ${minOutUTXO} ]]; then echo -e "\e[35mNot enough funds on the source Addr! Minimum UTXO value is ${minOutUTXO} lovelaces.\e[0m"; exit; fi
                        echo

fi

txBodyFile="${tempDir}/$(basename ${fromAddr}).txbody"
txFile="${tempDir}/$(basename ${fromAddr}).tx"

echo
echo -e "\e[0mBuilding the unsigned transaction body: \e[32m ${txBodyFile} \e[90m"
echo

#Building unsigned transaction body

if [[ ${rxcnt} == 1 ]]; then
			${cardanocli} ${subCommand} transaction build-raw ${nodeEraParam} ${txInString} --tx-out "${sendToAddr}+${lovelacesToReturn}${assetsOutString}" --invalid-hereafter ${ttl} --fee ${fee} --withdrawal ${withdrawal} --out-file ${txBodyFile}
			else
                        ${cardanocli} ${subCommand} transaction build-raw ${nodeEraParam} ${txInString} --tx-out "${sendFromAddr}+${lovelacesToReturn}${assetsOutString}" --tx-out ${sendToAddr}+${rewardsSum} --invalid-hereafter ${ttl} --fee ${fee} --withdrawal ${withdrawal} --out-file ${txBodyFile}
fi

cat ${txBodyFile}
echo

echo -e "\e[0mSign the unsigned transaction body with the \e[32m${fromAddr}.skey\e[0m & \e[32m${stakeAddr}.skey\e[0m: \e[32m ${txFile} \e[90m"
echo

#Sign the unsigned transaction body with the SecureKey
${cardanocli} ${subCommand} transaction sign --tx-body-file ${txBodyFile} --signing-key-file ${fromAddr}.skey --signing-key-file ${stakeAddr}.skey  ${magicparam} --out-file ${txFile}
cat ${txFile}
echo


if ask "\e[33mDoes this look good for you, continue ?" N; then
        echo
        echo -ne "\e[0mSubmitting the transaction via the node..."
        ${cardanocli} ${subCommand} transaction submit --cardano-mode --tx-file ${txFile} ${magicparam}
	checkError "$?"
        echo -e "\e[32mDONE\n"
fi

echo -e "\e[0m\n"
