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
echo -e "\e[0mCreating KES operational Keypairs"
echo

#grab the next issue number from the counter file
nextKESnumber=$(cat ${nodeName}.node.counter | awk 'match($0,/Next certificate issue number: [0-9]+/) {print substr($0, RSTART+31,RLENGTH-31)}')
nextKESnumber=$(printf "%03d" ${nextKESnumber})  #to get a nice 3 digit output

${cardanocli} ${subCommand} node key-gen-KES --verification-key-file ${nodeName}.kes-${nextKESnumber}.vkey --signing-key-file ${nodeName}.kes-${nextKESnumber}.skey
checkError "$?"

file_lock ${nodeName}.kes-${nextKESnumber}.vkey
file_lock ${nodeName}.kes-${nextKESnumber}.skey

echo
echo -e "\e[0mNode operational KES-Verification-Key:\e[32m ${nodeName}.kes-${nextKESnumber}.vkey \e[90m"
cat ${nodeName}.kes-${nextKESnumber}.vkey
echo

echo -e "\e[0mNode operational KES-Signing-Key:\e[32m ${nodeName}.kes-${nextKESnumber}.skey \e[90m"
cat ${nodeName}.kes-${nextKESnumber}.skey
echo

file_unlock ${nodeName}.kes.counter
echo ${nextKESnumber} > ${nodeName}.kes.counter
file_lock ${nodeName}.kes.counter 
echo -e "\e[0mUpdated KES-Counter:\e[32m ${nodeName}.kes.counter \e[90m"
cat ${nodeName}.kes.counter
echo

echo -e "\e[0m\n"
