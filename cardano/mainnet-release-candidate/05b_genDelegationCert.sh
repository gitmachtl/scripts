#!/bin/bash

# Script is brought to you by ATADA_Stakepool, Telegram @atada_stakepool

#load variables from common.sh
#       socket          Path to the node.socket (also exports socket to CARDANO_NODE_SOCKET_PATH)
#       genesisfile     Path to the genesis.json
#       magicparam      TestnetMagic parameter
#       cardanocli      Path to the cardano-cli executable
#       cardanonode     Path to the cardano-node executable
. "$(dirname "$0")"/00_common.sh

case $# in
  2 ) delegateStakeAddr="$2";
      toPoolNodeName="$1";;
  * ) cat >&2 <<EOF
Usage:  $(basename $0) <PoolNodeName> <DelegatorStakeAddressName>
EOF
  exit 1;; esac

echo
echo -e "\e[0mCreate a delegation registration certificate for Delegator\e[32m ${delegateStakeAddr}.staking.vkey\e[0m to the PoolNode\e[32m ${toPoolNodeName}.node.vkey\e[90m:"

file_unlock ${delegateStakeAddr}.deleg.cert

${cardanocli} shelley stake-address delegation-certificate --stake-verification-key-file ${delegateStakeAddr}.staking.vkey --cold-verification-key-file ${toPoolNodeName}.node.vkey --out-file ${delegateStakeAddr}.deleg.cert
checkError "$?"

file_lock ${delegateStakeAddr}.deleg.cert

echo
echo -e "\e[0mDelegation registration certificate:\e[32m ${delegateStakeAddr}.deleg.cert \e[90m"
cat ${delegateStakeAddr}.deleg.cert 
echo
echo -e "\e[0mCreated a delegation certificate which delegates funds from all stake addresses\nassociated with key \e[32m${delegateStakeAddr}.staking.vkey\e[0m to the pool associated with \e[32m${toPoolNodeName}.node.vkey\e[0m"
echo

echo -e "\e[0m\n"
