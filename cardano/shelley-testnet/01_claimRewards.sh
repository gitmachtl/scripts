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


echo
echo -e "\e[0mClaim Staking Rewards from Address\e[32m ${stakeAddr}.addr\e[0m with funds from Address\e[32m ${fromAddr}.addr\e[0m"
echo
echo

#get live values
currentTip=$(get_currentTip)
ttl=$(get_currentTTL)
currentEPOCH=$(get_currentEpoch)

echo -e "Current Slot-Height:\e[32m ${currentTip}\e[0m (setting TTL to ${ttl})"

sendFromAddr=$(cat ${fromAddr}.addr)
sendToAddr=$(cat ${toAddr}.addr)
stakingAddr=$(cat ${stakeAddr}.addr)

rewardsAmount=$(${cardanocli} shelley query stake-address-info --address ${stakingAddr} ${magicparam} | jq -r "flatten | .[0].rewardAccountBalance")

echo
echo -e "Claim all rewards from Address ${stakeAddr}.addr: \e[33m${rewardsAmount} lovelaces\e[0m"
echo
echo -e "Send the rewards to Address ${toAddr}.addr: \e[32m${sendToAddr}\e[0m"
echo -e "Pay fees from Address ${fromAddr}.addr: \e[32m${sendFromAddr}\e[0m"
echo

#Checking about rewards on the stake address
if [[ ${rewardsAmount} == 0 ]]; then echo -e "\e[35mNo rewards on the stake Addr!\e[0m\n"; exit; fi


#Get UTX0 Data for the sendFromAddr
utx0=$(${cardanocli} shelley query utxo --address ${sendFromAddr} ${magicparam})
utx0linecnt=$(echo "${utx0}" | wc -l)
txcnt=$((${utx0linecnt}-2))

if [[ ${txcnt} -lt 1 ]]; then echo -e "\e[35mNo funds on the payment Addr!\e[0m"; exit; else echo -e "\e[32m${txcnt} UTXOs\e[0m found on the payment Addr!"; fi

echo

#Calculating the total amount of lovelaces in all utxos on this address

totalLovelaces=0
txInString=""

while IFS= read -r utx0entry
do
fromHASH=$(echo ${utx0entry} | awk '{print $1}')
fromINDEX=$(echo ${utx0entry} | awk '{print $2}')
sourceLovelaces=$(echo ${utx0entry} | awk '{print $3}')
echo -e "HASH: ${fromHASH}\t INDEX: ${fromINDEX}\t LOVELACES: ${sourceLovelaces}"

totalLovelaces=$((${totalLovelaces}+${sourceLovelaces}))
txInString=$(echo -e "${txInString} --tx-in ${fromHASH}#${fromINDEX}")

done < <(printf "${utx0}\n" | tail -n ${txcnt})


echo -e "Total lovelaces in UTX0:\e[32m  ${totalLovelaces} lovelaces \e[90m"
echo

#withdrawal string
withdrawal="${stakingAddr}+${rewardsAmount}"

#Getting protocol parameters from the blockchain, calculating fees
${cardanocli} shelley query protocol-parameters ${magicparam} > protocol-parameters.json
checkError "$?"


#Generate Dummy-TxBody file for fee calculation
txBodyFile="${tempDir}/dummy.txbody"
rm ${txBodyFile} 2> /dev/null
if [[ ${rxcnt} == 1 ]]; then
                        ${cardanocli} shelley transaction build-raw ${txInString} --tx-out ${sendToAddr}+0 --ttl ${ttl} --fee 0 --withdrawal ${withdrawal} --out-file ${txBodyFile}
			checkError "$?"
                        else
                        ${cardanocli} shelley transaction build-raw ${txInString} --tx-out ${sendFromAddr}+0 --tx-out ${sendToAddr}+0 --ttl ${ttl} --fee 0 --withdrawal ${withdrawal} --out-file ${txBodyFile}
			checkError "$?"
fi
fee=$(${cardanocli} shelley transaction calculate-min-fee --tx-body-file ${txBodyFile} --protocol-params-file protocol-parameters.json --tx-in-count ${txcnt} --tx-out-count ${rxcnt} ${magicparam} --witness-count 2 --byron-witness-count 0 | awk '{ print $1 }')

echo -e "\e[0mMimimum transfer Fee for ${txcnt}x TxIn & ${rxcnt}x TxOut & Withdrawal: \e[32m ${fee} lovelaces \e[90m"

#If only one address (paying for the fees and also receiving the rewards)
#If two different addresse (fromAddr is paying for the fees, toAddr is getting the rewards)
if [[ ${rxcnt} == 1 ]]; then

			#calculate the lovelaces to return to the payment address
			lovelacesToReturn=$(( ${totalLovelaces}-${fee}+${rewardsAmount} ))
			#Checking about minimum funds in the UTX0
			if [[ ${lovelacesToReturn} -lt 0 ]]; then echo -e "\e[35mNot enough funds on the payment address!\e[0m"; exit; fi
			echo -e "\e[0mLovelaces that will be returned to destination Address (UTXO-Sum - fees + rewards): \e[33m ${lovelacesToReturn} lovelaces \e[90m"
			echo

			else

                        #calculate the lovelaces to return to the fee payment address
                        lovelacesToReturn=$(( ${totalLovelaces}-${fee} ))
                        #Checking about minimum funds in the UTX0
                        if [[ ${lovelacesToReturn} -lt 0 ]]; then echo -e "\e[35mNot enough funds on the fee payment address!\e[0m"; exit; fi
                        echo -e "\e[0mLovelaces that will be sent to the destination Address (rewards): \e[33m ${rewardsAmount} lovelaces \e[90m"
                        echo -e "\e[0mLovelaces that will be returned to the fee payment Address (UTXO-Sum - fees): \e[32m ${lovelacesToReturn} lovelaces \e[90m"
                        echo

fi

txBodyFile="${tempDir}/$(basename ${fromAddr}).txbody"
txFile="${tempDir}/$(basename ${fromAddr}).tx"

echo
echo -e "\e[0mBuilding the unsigned transaction body: \e[32m ${txBodyFile} \e[90m"
echo

#Building unsigned transaction body

if [[ ${rxcnt} == 1 ]]; then
			${cardanocli} shelley transaction build-raw ${txInString} --tx-out ${sendToAddr}+${lovelacesToReturn} --ttl ${ttl} --fee ${fee} --withdrawal ${withdrawal} --out-file ${txBodyFile}
			else
                        ${cardanocli} shelley transaction build-raw ${txInString} --tx-out ${sendFromAddr}+${lovelacesToReturn} --tx-out ${sendToAddr}+${rewardsAmount} --ttl ${ttl} --fee ${fee} --withdrawal ${withdrawal} --out-file ${txBodyFile}
fi


cat ${txBodyFile}
echo

echo -e "\e[0mSign the unsigned transaction body with the \e[32m${fromAddr}.skey\e[0m & \e[32m${stakeAddr}.skey\e[0m: \e[32m ${txFile} \e[90m"
echo

#Sign the unsigned transaction body with the SecureKey
${cardanocli} shelley transaction sign --tx-body-file ${txBodyFile} --signing-key-file ${fromAddr}.skey --signing-key-file ${stakeAddr}.skey  ${magicparam} --out-file ${txFile}
cat ${txFile}
echo


if ask "\e[33mDoes this look good for you, continue ?" N; then
        echo
        echo -ne "\e[0mSubmitting the transaction via the node..."
        ${cardanocli} shelley transaction submit --tx-file ${txFile} ${magicparam}
        echo -e "\e[32mDONE\n"
fi

echo -e "\e[0m\n"
