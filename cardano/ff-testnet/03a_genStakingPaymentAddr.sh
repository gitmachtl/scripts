#!/bin/bash

# Script is brought to you by ATADA_Stakepool, Telegram @atada_stakepool

#load variables from common.sh
#       socket          Path to the node.socket (also exports socket to CARDANO_NODE_SOCKET_PATH)
#       genesisfile     Path to the genesis.json
#       magicparam      TestnetMagic parameter
#       cardanocli      Path to the cardano-cli executable
#       cardanonode     Path to the cardano-node executable
. "$(dirname "$0")"/00_common.sh

if [[ ! $1 == "" ]]; then addrName=$1; else echo "ERROR - Usage: $0 <AddressName>"; exit 2; fi

#We need a normal payment(base) keypair with vkey and skey, so let's create that one

file_unlock ${addrName}.payment.vkey
file_unlock ${addrName}.payment.skey

${cardanocli} shelley address key-gen --verification-key-file ${addrName}.payment.vkey --signing-key-file ${addrName}.payment.skey

file_lock ${addrName}.payment.vkey
file_lock ${addrName}.payment.skey

echo -e "\e[0mPayment(Base)-Verification-Key: \e[32m ${addrName}.payment.vkey \e[90m"
cat ${addrName}.payment.vkey
echo
echo -e "\e[0mPayment(Base)-Signing-Key: \e[32m ${addrName}.payment.skey \e[90m"
cat ${addrName}.payment.skey
echo

file_unlock ${addrName}.staking.vkey
file_unlock ${addrName}.staking.skey

${cardanocli} shelley stake-address key-gen --verification-key-file ${addrName}.staking.vkey --signing-key-file ${addrName}.staking.skey 

file_lock ${addrName}.staking.vkey
file_lock ${addrName}.staking.skey

echo
echo -e "\e[0mVerification(Rewards)-Staking-Key: \e[32m ${addrName}.staking.vkey \e[90m"
cat ${addrName}.staking.vkey
echo
echo -e "\e[0mSigning(Rewards)-Staking-Key: \e[32m ${addrName}.staking.skey \e[90m"
cat ${addrName}.staking.skey
echo

#Building a Payment Address
file_unlock ${addrName}.payment.addr
${cardanocli} shelley address build --payment-verification-key-file ${addrName}.payment.vkey --staking-verification-key-file ${addrName}.staking.vkey > ${addrName}.payment.addr
file_lock ${addrName}.payment.addr

echo -e "\e[0mPayment(Base)-Address built: \e[32m ${addrName}.payment.addr \e[90m"
cat ${addrName}.payment.addr
echo

#Building a Staking Address
file_unlock ${addrName}.staking.addr
${cardanocli} shelley stake-address build --staking-verification-key-file ${addrName}.staking.vkey > ${addrName}.staking.addr
file_lock ${addrName}.staking.addr

echo -e "\e[0mStaking(Rewards)-Address built: \e[32m ${addrName}.staking.addr \e[90m"
cat ${addrName}.staking.addr
echo

#Building a Enterprise Address
#${cardanocli} shelley address build --payment-verification-key-file ${addrName}.payment.vkey > ${addrName}.enterprise.addr
#
#echo -e "\e[0mEnterprise-Address built: \e[32m ${addrName}.enterprise.addr \e[90m"
#cat ${addrName}.enterprise.addr
#echo

#create an address registration certificate
file_unlock ${addrName}.staking.cert
${cardanocli} shelley stake-address registration-certificate --staking-verification-key-file ${addrName}.staking.vkey --out-file ${addrName}.staking.cert
file_lock ${addrName}.staking.cert

echo -e "\e[0mStaking-Address-Registration-Certificate built: \e[32m ${addrName}.staking.cert \e[90m"
cat ${addrName}.staking.cert
echo

#get values to register the staking address on the blockchain

currentTip=$(${cardanocli} shelley query tip ${magicparam} | awk 'match($0,/unSlotNo = [0-9]+/) {print substr($0, RSTART+11,RLENGTH-11)}')
ttl=$(( ${currentTip} + 10000 ))  #just add 10000 slots to the current one

#calculating minimum fee
#cardano-cli shelley transaction calculate-min-fee \
#     --tx-in-count 1 \
#     --tx-out-count 1 \
#     --ttl 200000 \
#     --testnet-magic 42 \
#     --signing-key-file payment.skey \
#     --signing-key-file staking.skey \
#     --certificate staking.cert \
#     --protocol-params-file protocol.json
${cardanocli} shelley query protocol-parameters ${magicparam} > protocol-parameters.json
fee=$(${cardanocli} shelley transaction calculate-min-fee --protocol-params-file protocol-parameters.json --tx-in-count 1 --tx-out-count 1 --ttl ${ttl} ${magicparam} --signing-key-file ${addrName}.payment.skey --signing-key-file ${addrName}.staking.skey --certificate ${addrName}.staking.cert | awk '{ print $2 }')
echo -e "\e[0mMimimum Registration Transfer Fee: \e[32m ${fee} lovelaces \e[90m"
keyDepositFee=$(cat protocol-parameters.json | jq -r .keyDeposit)
echo -e "\e[0mKey Deposit Fee: \e[32m ${keyDepositFee} lovelaces \e[90m"

minRegistrationFund=$((${keyDepositFee}+${fee}))

echo
echo -e "\e[35mIf you wanna register the Staking-Address:\n\nPlease transfer now at least ${minRegistrationFund} lovelaces to your ${addrName}.payment.addr!\nIt will be used to pay for the registration fee of your Staking Address ${addrName}.staking.addr.\nSo the blockchain knows about the payment/staking address relationship !\e[0m"



#--network-magic not needed on mainnet later

