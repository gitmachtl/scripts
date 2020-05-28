#!/bin/bash

#load variables from common.sh
#       socket          Path to the node.socket (also exports socket to CARDANO_NODE_SOCKET_PATH)
#       genesisfile     Path to the genesis.json
#       magicparam      TestnetMagic paramter
source "$(dirname "$0")"/00_common.sh

if [[ ! $1 == "" ]]; then addrName=$1; else echo "ERROR - Usage: $0 <addressname>"; exit 2; fi

#addrName="addr1"	#used for the securekey signing <name>.skey

txcnt="1"		#transmit from how many addresses
rxcnt="2"		#transmit to how many addresses
adaToSend="2000000"   	#in lovelaces
ttl="500000"		#TimeToLive 3600 slots from the submition, so it doesn't float around forever


echo
echo -e "Minimum Fee for ${txcnt} addresses to ${rxcnt} addresse in lovelaces:"
echo


#Getting protocol parameters from the blockchain
${cardanocli} shelley query protocol-parameters ${magicparam} > protocol-parameters.json

#Calculating the minimum Transaction fee
${cardanocli} shelley transaction calculate-min-fee --protocol-params-file protocol-parameters.json --tx-in-count ${txcnt} --tx-out-count ${rxcnt} --ttl ${ttl} ${magicparam} --signing-key-file ${addrName}.skey | awk '{ print $2 }'


