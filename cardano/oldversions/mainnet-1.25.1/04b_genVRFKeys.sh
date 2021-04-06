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

if [ -f "${nodeName}.vrf.vkey" ]; then echo -e "\e[35mWARNING - ${nodeName}.vrf.vkey already present, delete it or use another name !\e[0m"; exit 2; fi
if [ -f "${nodeName}.vrf.skey" ]; then echo -e "\e[35mWARNING - ${nodeName}.vrf.skey already present, delete it or use another name !\e[0m"; exit 2; fi

echo -e "\e[0mCreating VRF operational Keypairs"
echo

${cardanocli} ${subCommand} node key-gen-VRF --verification-key-file ${nodeName}.vrf.vkey --signing-key-file ${nodeName}.vrf.skey
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
file_lock ${nodeName}.vrf.vkey
file_lock ${nodeName}.vrf.skey

echo -e "\e[0mNode operational VRF-Verification-Key:\e[32m ${nodeName}.vrf.vkey \e[90m"
cat ${nodeName}.vrf.vkey
echo
echo -e "\e[0mNode operational VRF-Signing-Key:\e[32m ${nodeName}.vrf.skey \e[90m"
cat ${nodeName}.vrf.skey
echo

echo -e "\e[0m\n"
