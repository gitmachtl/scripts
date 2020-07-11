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

#create a stake-address de-registration certificate
file_unlock ${addrName}.staking.dereg-cert
${cardanocli} shelley stake-address deregistration-certificate --staking-verification-key-file ${addrName}.staking.vkey --out-file ${addrName}.staking.dereg-cert
checkError "$?"
file_lock ${addrName}.staking.dereg-cert

echo
echo -e "\e[0mStaking-Address-DeRegistration-Certificate built: \e[32m ${addrName}.staking.dereg-cert \e[90m"
cat ${addrName}.staking.cert
echo
echo
echo -e "\e[35mIf you wanna de-register the Staking-Address, please use script 08b now!\e[0m"
echo
echo -e "\e[0m\n"

#--network-magic not needed on mainnet later

