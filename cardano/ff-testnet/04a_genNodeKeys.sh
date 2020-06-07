#!/bin/bash

# Script is brought to you by ATADA_Stakepool, Telegram @atada_stakepool

#load variables from common.sh
#       socket          Path to the node.socket (also exports socket to CARDANO_NODE_SOCKET_PATH)
#       genesisfile     Path to the genesis.json
#       magicparam      TestnetMagic parameter
#       cardanocli      Path to the cardano-cli executable
#       cardanonode     Path to the cardano-node executable
. "$(dirname "$0")"/00_common.sh

if [[ $# -eq 1 && ! $1 == "" ]]; then nodeName=$1; else echo "ERROR - Usage: $0 <NodePoolName>"; exit 2; fi

echo
echo -e "\e[0mCreating Node Offline Keys\e[32m ${nodeName}.node.vkey/skey\e[0m and Issue.Counter File\e[32m ${nodeName}.node.counter"
echo

${cardanocli} shelley node key-gen --verification-key-file ${nodeName}.node.vkey --signing-key-file ${nodeName}.node.skey --operational-certificate-issue-counter ${nodeName}.node.counter

file_lock ${nodeName}.node.vkey
file_lock ${nodeName}.node.skey
file_lock ${nodeName}.node.counter

echo
echo -e "\e[0mOperator-Verification-Key:\e[32m ${nodeName}.node.vkey \e[90m"
cat ${nodeName}.node.vkey
echo
echo -e "\e[0mOperator-Signing-Key:\e[32m ${nodeName}.node.skey \e[90m"
cat ${nodeName}.node.skey
echo
echo -e "\e[0mResetting Operational Certificate Issue Counter:\e[32m ${nodeName}.node.counter \e[90m"
cat ${nodeName}.node.counter
echo

echo -e "\e[0m\n"
