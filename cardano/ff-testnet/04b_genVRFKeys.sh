#!/bin/bash

#load variables from common.sh
#       socket          Path to the node.socket (also exports socket to CARDANO_NODE_SOCKET_PATH)
#       genesisfile     Path to the genesis.json
#       magicparam      TestnetMagic paramter
. "$(dirname "$0")"/00_common.sh

if [[ ! $1 == "" ]]; then addrName=$1; else echo "ERROR - Usage: $0 <name>"; exit 2; fi

echo
echo -e "\e[0mCreating VRF operational Keypairs"
echo

${cardanocli} shelley node key-gen-VRF --verification-key-file ${addrName}.vrf.vkey --signing-key-file ${addrName}.vrf.skey

echo
echo -e "\e[0mNode operational VRF-Verification-Key:\e[32m ${addrName}.vrf.vkey \e[90m"
cat ${addrName}.vrf.vkey
echo
echo -e "\e[0mNode operational VRF-Signing-Key:\e[32m ${addrName}.vrf.skey \e[90m"
cat ${addrName}.vrf.skey
echo
