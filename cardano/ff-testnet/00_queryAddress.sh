#!/bin/bash

#load variables from common.sh
#	socket 		Path to the node.socket (also exports socket to CARDANO_NODE_SOCKET_PATH)
#	genesisfile	Path to the genesis.json
#	magicparam	TestnetMagic paramter
source "$(dirname "$0")"/00_common.sh

if [[ ! $1 == "" ]]; then addrName=$1; else echo "ERROR - Usage: $0 <addressname>.addr"; exit 2; fi

#addrName="addr1"

echo -e "UTX0 query for address name '${addrName}.addr' - $(cat ${addrName}.addr):"
${cardanocli} shelley query utxo --address $(cat ${addrName}.addr) ${magicparam}

