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
  2 ) stakeAddr="$1";
      fromAddr="$2";;
  * ) cat >&2 <<EOF
Usage:  $(basename $0) <StakeAddressName> <Base/PaymentAddressName (paying for the transaction fees)>
Example: $(basename $0) atada.staking atada.payment
EOF
  exit 1;; esac

echo
echo -e "\e[0mDe-Register (retire) the Staking Address\e[32m ${stakeAddr}.addr\e[0m with funds from Address\e[32m ${fromAddr}.addr\e[0m"
echo

#get values to deregister the staking address on the blockchain
#get live values
currentTip=$(get_currentTip)
ttl=$(get_currentTTL)
currentEPOCH=$(get_currentEpoch)

echo -e "Current Slot-Height:\e[32m ${currentTip}\e[0m (setting TTL to ${ttl})"

rxcnt="1"               #transmit to one destination addr. all utxos will be sent back to the fromAddr

sendFromAddr=$(cat ${fromAddr}.addr); check_address "${sendFromAddr}";
sendToAddr=$(cat ${fromAddr}.addr); check_address "${sendToAddr}";

echo
echo -e "Pay fees from Address\e[32m ${fromAddr}.addr\e[0m: ${sendFromAddr}"
echo


#Get UTX0 Data for the sendFromAddr
utx0=$(${cardanocli} shelley query utxo --address ${sendFromAddr} ${magicparam}); checkError "$?";
utx0linecnt=$(echo "${utx0}" | wc -l)
txcnt=$((${utx0linecnt}-2))

if [[ ${txcnt} -lt 1 ]]; then echo -e "\e[35mNo funds on the payment Addr!\e[0m"; exit; else echo "${txcnt} UTXOs found on the payment Addr!"; fi

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

#Getting protocol parameters from the blockchain, calculating fees
${cardanocli} shelley query protocol-parameters ${magicparam} > protocol-parameters.json

#Generate Dummy-TxBody file for fee calculation
        txBodyFile="${tempDir}/dummy.txbody"
        rm ${txBodyFile} 2> /dev/null
        ${cardanocli} shelley transaction build-raw ${txInString} --tx-out ${sendToAddr}+0 --ttl ${ttl} --fee 0 --certificate ${stakeAddr}.dereg-cert --out-file ${txBodyFile}
        checkError "$?"

fee=$(${cardanocli} shelley transaction calculate-min-fee --tx-body-file ${txBodyFile} --protocol-params-file protocol-parameters.json --tx-in-count ${txcnt} --tx-out-count ${rxcnt} ${magicparam} --witness-count 2 --byron-witness-count 0 | awk '{ print $1 }')
checkError "$?"

echo -e "\e[0mMimimum transfer Fee for ${txcnt}x TxIn & ${rxcnt}x TxOut & 1x Certificate: \e[32m ${fee} lovelaces \e[90m"
keyDepositFee=$(cat protocol-parameters.json | jq -r .keyDeposit)
echo -e "\e[0mKey Deposit Fee that will be refunded: \e[32m ${keyDepositFee} lovelaces \e[90m"

minDeregistrationFund=$(( ${fee} ))

echo
echo -e "\e[0mMimimum funds required for de-registration: \e[32m 0 lovelaces \e[90mbecause the KeyDepositFee refund will pay for it"
echo

#calculate new balance for destination address
lovelacesToSend=$(( ${totalLovelaces}-${minDeregistrationFund}+${keyDepositFee} ))

#Checking about minimum funds in the UTX0
if [[ ${lovelacesToSend} -lt 0 ]]; then echo -e "\e[35mNot enough funds on the payment Addr!\e[0m"; exit; fi

echo -e "\e[0mLovelaces that will be return to payment Address (UTXO-Sum minus fees): \e[32m ${lovelacesToSend} lovelaces \e[90m"
echo

txBodyFile="${tempDir}/$(basename ${fromAddr}).txbody"
txFile="${tempDir}/$(basename ${fromAddr}).tx"

echo
echo -e "\e[0mBuilding the unsigned transaction body with the\e[32m ${stakeAddr}.dereg-cert\e[0m certificate: \e[32m ${txBodyFile} \e[90m"
echo

#Building unsigned transaction body
rm ${txBodyFile} 2> /dev/null
${cardanocli} shelley transaction build-raw ${txInString} --tx-out ${sendToAddr}+${lovelacesToSend} --ttl ${ttl} --fee ${fee} --certificate ${stakeAddr}.dereg-cert --out-file ${txBodyFile}
checkError "$?"
cat ${txBodyFile}
echo
echo
echo -e "\e[0mSign the unsigned transaction body with the \e[32m${fromAddr}.skey\e[0m: \e[32m ${txFile} \e[90m"
echo

#Sign the unsigned transaction body with the SecureKey
rm ${txFile} 2> /dev/null
${cardanocli} shelley transaction sign --tx-body-file ${txBodyFile} --signing-key-file ${fromAddr}.skey --signing-key-file ${stakeAddr}.skey ${magicparam} --out-file ${txFile}
checkError "$?"
cat ${txFile}
echo


if ask "\e[33mDoes this look good for you, continue ?" N; then
        echo
        echo -ne "\e[0mSubmitting the transaction via the node..."
        ${cardanocli} shelley transaction submit --tx-file ${txFile} ${magicparam}
	checkError "$?"
        echo -e "\e[32mDONE\n"
fi

echo -e "\e[0m\n"
