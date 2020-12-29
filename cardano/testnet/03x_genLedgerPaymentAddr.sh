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
#${cardanocli} ${subCommand} address key-gen --verification-key-file ${addrName}.payment.vkey --signing-key-file ${addrName}.payment.skey
./cardano-hw-cli shelley address key-gen --path 1852H/1815H/0H/0/0 --verification-key-file ${addrName}.payment.vkey --hw-signing-file ${addrName}.payment.skey
checkError "$?"
file_lock ${addrName}.payment.vkey
file_lock ${addrName}.payment.skey

echo -e "\e[0mPayment(Base)-Verification-Key: \e[32m ${addrName}.payment.vkey \e[90m"
cat ${addrName}.payment.vkey
echo
echo -e "\e[0mPayment(Base)-Signing-Key: \e[32m ${addrName}.payment.skey \e[90m"
cat ${addrName}.payment.skey
echo

#Building a Payment Address
${cardanocli} ${subCommand} address build --payment-verification-key-file ${addrName}.payment.vkey ${addrformat} > ${addrName}.addr
checkError "$?"
file_lock ${addrName}.addr

echo -e "\e[0mPaymentOnly(Enterprise)-Address built: \e[32m ${addrName}.addr \e[90m"
cat ${addrName}.addr
echo

./cardano-hw-cli shelley address key-gen --path 1852H/1815H/0H/2/0 --verification-key-file ${addrName}.staking.vkey --hw-signing-file ${addrName}.staking.skey
#${cardanocli} ${subCommand} stake-address key-gen --verification-key-file ${addrName}.staking.vkey --signing-key-file ${addrName}.staking.skey
checkError "$?"
file_lock ${addrName}.staking.vkey
file_lock ${addrName}.staking.skey

echo -e "\e[0mVerification(Rewards)-Staking-Key: \e[32m ${addrName}.staking.vkey \e[90m"
cat ${addrName}.staking.vkey
echo
echo -e "\e[0mSigning(Rewards)-Staking-Key: \e[32m ${addrName}.staking.skey \e[90m"
cat ${addrName}.staking.skey
echo

#Building a Payment Address
${cardanocli} ${subCommand} address build --payment-verification-key-file ${addrName}.payment.vkey --staking-verification-key-file ${addrName}.staking.vkey ${addrformat} > ${addrName}.payment.addr
checkError "$?"
file_lock ${addrName}.payment.addr

echo -e "\e[0mPayment(Base)-Address built: \e[32m ${addrName}.payment.addr \e[90m"
cat ${addrName}.payment.addr
echo

#Building a Staking Address
${cardanocli} ${subCommand} stake-address build --staking-verification-key-file ${addrName}.staking.vkey ${addrformat} > ${addrName}.staking.addr
checkError "$?"
file_lock ${addrName}.staking.addr

echo -e "\e[0mStaking(Rewards)-Address built: \e[32m ${addrName}.staking.addr \e[90m"
cat ${addrName}.staking.addr
echo

#create an address registration certificate
${cardanocli} ${subCommand} stake-address registration-certificate --staking-verification-key-file ${addrName}.staking.vkey --out-file ${addrName}.staking.cert
checkError "$?"
file_lock ${addrName}.staking.cert

echo -e "\e[0mStaking-Address-Registration-Certificate built: \e[32m ${addrName}.staking.cert \e[90m"
cat ${addrName}.staking.cert
echo
echo
echo -e "\e[35mIf you wanna register the Staking-Address, please now run the script 03b_regStakingAddrCert.sh !\e[0m"
echo


