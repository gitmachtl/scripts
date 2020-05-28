#!/bin/bash

#load variables from common.sh
#       socket          Path to the node.socket (also exports socket to CARDANO_NODE_SOCKET_PATH)
#       genesisfile     Path to the genesis.json
#       magicparam      TestnetMagic paramter
. "$(dirname "$0")"/00_common.sh

if [[ ! $1 == "" ]]; then addrName=$1; else echo "ERROR - Usage: $0 <name>"; exit 2; fi
#addrName="addr1"

echo
echo -e "\e[0mCreating Node Offline Keys\e[32m ${addrName}.node.vkey/skey\e[0m and Issue.Counter File\e[32m ${addrName}.node.counter"
echo

${cardanocli} shelley node key-gen --verification-key-file ${addrName}.node.vkey --signing-key-file ${addrName}.node.skey --operational-certificate-issue-counter ${addrName}.node.counter

echo
echo -e "\e[0mOperator-Verification-Key:\e[32m ${addrName}.node.vkey \e[90m"
cat ${addrName}.node.vkey
echo
echo -e "\e[0mOperator-Signing-Key:\e[32m ${addrName}.node.skey \e[90m"
cat ${addrName}.node.skey
echo
echo -e "\e[0mResetting Operational Certificate Issue Counter:\e[32m ${addrName}.node.counter \e[90m"
cat ${addrName}.node.counter
echo
