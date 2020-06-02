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
  2 ) poolName="$1";
      delegName="$2";;
  * ) cat >&2 <<EOF
Usage:  $(basename $0) <PoolNodeName> <DelegatorStakeAddressName>
EOF
  exit 1;; esac


#case $# in
#  2 ) stakeAddr="$1";
#      fromAddr="$2";;
#  * ) cat >&2 <<EOF
#Usage:  $(basename $0) <StakeAddressName> <Base/PaymentAddressName (paying for the registration fees)>
#Example: $(basename $0) atada.staking atada.payment
#EOF
#  exit 1;; esac

echo
echo -e "\e[0mRegister Delegation Certificate\e[32m ${delegName}.deleg.cert\e[0m with funds from Address\e[32m ${delegName}.payment.addr\e[0m:"
echo

#get values to register the staking address on the blockchain
currentTip=$(${cardanocli} shelley query tip ${magicparam} | awk 'match($0,/unSlotNo = [0-9]+/) {print substr($0, RSTART+11,RLENGTH-11)}')
ttl=$(( ${currentTip} + 10000 ))  #just add 10000 slots to the current one

echo -e "Current Slot-Height:\e[32m ${currentTip}\e[0m (setting TTL to ${ttl})"

rxcnt="1"               #transmit to one destination addr. all utxos will be sent back to the fromAddr

sendFromAddr=$(cat ${delegName}.payment.addr)
sendToAddr=$(cat ${delegName}.payment.addr)

echo
echo -e "Pay fees from Address\e[32m ${delegName}.payment.addr\e[0m: ${sendFromAddr}"
echo


#Get UTX0 Data for the sendFromAddr
utx0=$(${cardanocli} shelley query utxo --address ${sendFromAddr} ${magicparam})
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


#cardano-cli shelley transaction calculate-min-fee \
#    --tx-in-count 1 \
#    --tx-out-count 1 \
#    --ttl 430000 \
#    --testnet-magic 42 \
#    --signing-key-file pay.skey \
#    --signing-key-file stake.skey \
#    --certificate deleg.cert \
#    --protocol-params-file params.json

fee=$(${cardanocli} shelley transaction calculate-min-fee --protocol-params-file protocol-parameters.json --tx-in-count ${txcnt} --tx-out-count ${rxcnt} --ttl ${ttl} ${magicparam} --signing-key-file ${delegName}.payment.skey --signing-key-file ${delegName}.staking.skey --certificate ${delegName}.deleg.cert | awk '{ print $2 }')
echo -e "\e[0mMinimum transfer Fee for ${txcnt}x TxIn & ${rxcnt}x TxOut & 1x Certificate: \e[32m ${fee} lovelaces \e[90m"
minRegistrationFund=$(( ${fee} ))

echo
echo -e "\e[0mMinimum funds required for registration (Sum of fees): \e[32m ${minRegistrationFund} lovelaces \e[90m"
echo

#calculate new balance for destination address
lovelacesToSend=$(( ${totalLovelaces}-${minRegistrationFund} ))

#Checking about minimum funds in the UTX0
if [[ ${lovelacesToSend} -lt 0 ]]; then echo -e "\e[35mNot enough funds on the payment Addr!\e[0m"; exit; fi

echo -e "\e[0mLovelaces that will be returned to payment Address (UTXO-Sum minus fees): \e[32m ${lovelacesToSend} lovelaces \e[90m"
echo

echo
echo -e "\e[0mBuilding the unsigned transaction body with Delegation Certificate\e[32m ${delegName}.deleg.cert\e[0m certificates: \e[32m tx_${delegName}.txbody \e[90m"
echo

#Building unsigned transaction body
${cardanocli} shelley transaction build-raw ${txInString} --tx-out ${sendToAddr}+${lovelacesToSend} --ttl ${ttl} --fee ${fee} --tx-body-file tx_${delegName}.txbody --certificate ${delegName}.deleg.cert

cat tx_${delegName}.txbody
echo

echo -e "\e[0mSign the unsigned transaction body with the \e[32m${delegName}.payment.skey\e[0m & \e[32m${delegName}.staking.skey\e[0m: \e[32m tx_${delegName}.tx \e[90m"
echo

#Sign the unsigned transaction body with the SecureKey
${cardanocli} shelley transaction sign --tx-body-file tx_${delegName}.txbody --signing-key-file ${delegName}.payment.skey --signing-key-file ${delegName}.staking.skey --tx-file tx_${delegName}.tx ${magicparam}

cat tx_${delegName}.tx
echo

if ask "\e[33mDoes this look good for you ?" N; then
        echo
        echo -ne "\e[0mSubmitting the transaction via the node..."
        ${cardanocli} shelley transaction submit --tx-file tx_${delegName}.tx ${magicparam}
        echo -e "\e[32mDONE\n"
fi

echo -e "\e[0m\n"
