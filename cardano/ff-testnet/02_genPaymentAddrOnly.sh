#!/bin/bash

#load variables from common.sh
#       socket          Path to the node.socket (also exports socket to CARDANO_NODE_SOCKET_PATH)
#       genesisfile     Path to the genesis.json
#       magicparam      TestnetMagic paramter
. "$(dirname "$0")"/00_common.sh

if [[ ! $1 == "" ]]; then addrName=$1; else echo "ERROR - Usage: $0 <addressname>.addr"; exit 2; fi


${cardanocli} shelley address key-gen --verification-key-file ${addrName}.vkey --signing-key-file ${addrName}.skey

echo -e "\e[0mPaymentOnly(Enterprise)-Verification-Key: \e[32m ${addrName}.vkey \e[90m"
cat ${addrName}.vkey
echo
echo -e "\e[0mPaymentOnly(Enterprise)-Signing-Key: \e[32m ${addrName}.skey \e[90m"
cat ${addrName}.skey
echo

#Building a Payment Address
${cardanocli} shelley address build --payment-verification-key-file ${addrName}.vkey > ${addrName}.addr

echo -e "\e[0mPaymentOnly(Enterprise)-Address built: \e[32m ${addrName}.addr \e[90m"
cat ${addrName}.addr
echo

