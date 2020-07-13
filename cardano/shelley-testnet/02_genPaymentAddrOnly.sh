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
if [ -f "${addrName}.vkey" ]; then echo -e "\e[35mWARNING - ${addrName}.vkey already present, delete it or use another name !\e[0m"; exit 2; fi
if [ -f "${addrName}.skey" ]; then echo -e "\e[35mWARNING - ${addrName}.skey already present, delete it or use another name !\e[0m"; exit 2; fi
if [ -f "${addrName}.addr" ]; then echo -e "\e[35mWARNING - ${addrName}.addr already present, delete it or use another name !\e[0m"; exit 2; fi



${cardanocli} shelley address key-gen --verification-key-file ${addrName}.vkey --signing-key-file ${addrName}.skey
checkError "$?"
file_lock ${addrName}.vkey
file_lock ${addrName}.skey


echo -e "\e[0mPaymentOnly(Enterprise)-Verification-Key: \e[32m ${addrName}.vkey \e[90m"
cat ${addrName}.vkey
echo
echo -e "\e[0mPaymentOnly(Enterprise)-Signing-Key: \e[32m ${addrName}.skey \e[90m"
cat ${addrName}.skey
echo

#Building a Payment Address
${cardanocli} shelley address build --payment-verification-key-file ${addrName}.vkey ${magicparam} > ${addrName}.addr
checkError "$?"
file_lock ${addrName}.addr

echo -e "\e[0mPaymentOnly(Enterprise)-Address built: \e[32m ${addrName}.addr \e[90m"
cat ${addrName}.addr
echo

echo -e "\e[0m\n"

