#!/bin/bash

#load variables from common.sh
#       socket          Path to the node.socket (also exports socket to CARDANO_NODE_SOCKET_PATH)
#       genesisfile     Path to the genesis.json
#       magicparam      TestnetMagic paramter
. "$(dirname "$0")"/00_common.sh

if [[ ! $1 == "" ]]; then addrName=$1; else echo "ERROR - Usage: $0 <name>"; exit 2; fi

echo
echo -e "\e[0mCreating KES operational Keypairs"
echo

#grab the next issue number from the counter file
nextKESnumber=$(cat ${addrName}.node.counter | awk 'match($0,/Next certificate issue number: [0-9]+/) {print substr($0, RSTART+31,RLENGTH-31)}')
nextKESnumber=$(printf "%03d" ${nextKESnumber})  #to get a nice 3 digit output

${cardanocli} shelley node key-gen-KES --verification-key-file ${addrName}.kes-${nextKESnumber}.vkey --signing-key-file ${addrName}.kes-${nextKESnumber}.skey

echo
echo -e "\e[0mNode operational KES-Verification-Key:\e[32m ${addrName}.kes-${nextKESnumber}.vkey \e[90m"
cat ${addrName}.kes-${nextKESnumber}.vkey
echo

echo -e "\e[0mNode operational KES-Signing-Key:\e[32m ${addrName}.kes-${nextKESnumber}.skey \e[90m"
cat ${addrName}.kes-${nextKESnumber}.skey
echo

echo ${nextKESnumber} > ${addrName}.kes.counter
echo -e "\e[0mUpdated KES-Counter:\e[32m ${addrName}.kes.counter \e[90m"
cat ${addrName}.kes.counter
echo
