#!/bin/bash

# Script is brought to you by ATADA_Stakepool, Telegram @atada_stakepool

#load variables from common.sh
#       socket          Path to the node.socket (also exports socket to CARDANO_NODE_SOCKET_PATH)
#       genesisfile     Path to the genesis.json
#       magicparam      TestnetMagic parameter
#       cardanocli      Path to the cardano-cli executable
#       cardanonode     Path to the cardano-node executable
. "$(dirname "$0")"/00_common.sh

if [[ $# -eq 1 && ! $1 == "" ]]; then addrName=$1; else echo "ERROR - Usage: $0 <AddressName>"; exit 2; fi

#warnings
if [ -f "${addrName}.payment.vkey" ]; then echo -e "\e[35mWARNING - ${addrName}.payment.vkey already present, delete it or use another name !\e[0m"; exit 2; fi
if [ -f "${addrName}.payment.skey" ]; then echo -e "\e[35mWARNING - ${addrName}.payment.skey already present, delete it or use another name !\e[0m"; exit 2; fi
if [ -f "${addrName}.payment.addr" ]; then echo -e "\e[35mWARNING - ${addrName}.payment.addr already present, delete it or use another name !\e[0m"; exit 2; fi
if [ -f "${addrName}.staking.vkey" ]; then echo -e "\e[35mWARNING - ${addrName}.staking.vkey already present, delete it or use another name !\e[0m"; exit 2; fi
if [ -f "${addrName}.staking.skey" ]; then echo -e "\e[35mWARNING - ${addrName}.staking.skey already present, delete it or use another name !\e[0m"; exit 2; fi
if [ -f "${addrName}.staking.addr" ]; then echo -e "\e[35mWARNING - ${addrName}.staking.addr already present, delete it or use another name !\e[0m"; exit 2; fi
if [ -f "${addrName}.staking.cert" ]; then echo -e "\e[35mWARNING - ${addrName}.staking.cert already present, delete it or use another name !\e[0m"; exit 2; fi


#We need a normal payment(base) keypair with vkey and skey, so let's create that one
${cardanocli} shelley address key-gen --verification-key-file ${addrName}.payment.vkey --signing-key-file ${addrName}.payment.skey
file_lock ${addrName}.payment.vkey
file_lock ${addrName}.payment.skey

echo -e "\e[0mPayment(Base)-Verification-Key: \e[32m ${addrName}.payment.vkey \e[90m"
cat ${addrName}.payment.vkey
echo
echo -e "\e[0mPayment(Base)-Signing-Key: \e[32m ${addrName}.payment.skey \e[90m"
cat ${addrName}.payment.skey
echo

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
${cardanocli} shelley address build --payment-verification-key-file ${addrName}.payment.vkey --staking-verification-key-file ${addrName}.staking.vkey ${magicparam} > ${addrName}.payment.addr
file_lock ${addrName}.payment.addr

echo -e "\e[0mPayment(Base)-Address built: \e[32m ${addrName}.payment.addr \e[90m"
cat ${addrName}.payment.addr
echo

#Building a Staking Address
${cardanocli} shelley stake-address build --staking-verification-key-file ${addrName}.staking.vkey ${magicparam} > ${addrName}.staking.addr
file_lock ${addrName}.staking.addr

echo -e "\e[0mStaking(Rewards)-Address built: \e[32m ${addrName}.staking.addr \e[90m"
cat ${addrName}.staking.addr
echo

#Building a Enterprise Address
#${cardanocli} shelley address build --payment-verification-key-file ${addrName}.payment.vkey ${magicparam} > ${addrName}.enterprise.addr
#
#echo -e "\e[0mEnterprise-Address built: \e[32m ${addrName}.enterprise.addr \e[90m"
#cat ${addrName}.enterprise.addr
#echo

#create an address registration certificate
${cardanocli} shelley stake-address registration-certificate --staking-verification-key-file ${addrName}.staking.vkey --out-file ${addrName}.staking.cert
file_lock ${addrName}.staking.cert

echo -e "\e[0mStaking-Address-Registration-Certificate built: \e[32m ${addrName}.staking.cert \e[90m"
cat ${addrName}.staking.cert
echo

#get values to calculate fees for the staking address registration on the blockchain
#get live values
#currentTip=$(get_currentTip)
#ttl=$(get_currentTTL)
#currentEPOCH=$(get_currentEpoch)

#calculating minimum fee
#Usage: cardano-cli.1.15 shelley transaction calculate-min-fee --tx-body-file FILE
#                                                              [--mainnet |
#                                                                --testnet-magic NATURAL]
#                                                              --protocol-params-file FILE
#                                                              --tx-in-count NATURAL
#                                                              --tx-out-count NATURAL
#                                                              --witness-count NATURAL
#                                                              --byron-witness-count NATURAL

#${cardanocli} shelley query protocol-parameters ${magicparam} > protocol-parameters.json

#Building a dummy txbodyfile
#txBodyFile="${tempDir}/dummy.txbody"
#${cardanocli} shelley transaction build-raw --tx-in 5417f0851212a26887f1db37f767eb53e3b704c4a8710f806cae125723f5b819#0 --tx-out $(cat ${addrName}.payment.addr)+1000  --ttl ${ttl} --fee 0 --certificate-file ${addrName}.staking.cert --out-file ${txBodyFile}
#fee=$(${cardanocli} shelley transaction calculate-min-fee --tx-body-file ${txBodyFile} --protocol-params-file protocol-parameters.json --tx-in-count 1 --tx-out-count 1 ${magicparam} --witness-count 3 --byron-./witness-count 0 | awk '{ print $2 }')
#echo -e "\e[0mMimimum Registration Transfer Fee: \e[32m ${fee} lovelaces \e[90m"
#keyDepositFee=$(cat protocol-parameters.json | jq -r .keyDeposit)
#echo -e "\e[0mKey Deposit Fee: \e[32m ${keyDepositFee} lovelaces \e[90m"

#minRegistrationFund=$((${keyDepositFee}+${fee}))

echo
echo -e "\e[35mIf you wanna register the Staking-Address, please now run the script 03b_regStakingAddrCert.sh !\e[0m"
echo

#--network-magic not needed on mainnet later

