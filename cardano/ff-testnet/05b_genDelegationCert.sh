#!/bin/bash

#load variables from common.sh
#       socket          Path to the node.socket (also exports socket to CARDANO_NODE_SOCKET_PATH)
#       genesisfile     Path to the genesis.json
#       magicparam      TestnetMagic paramter
. "$(dirname "$0")"/00_common.sh

case $# in
  2 ) delegateStakeAddr="$1";
      toPoolNodeName="$2";;
  * ) cat >&2 <<EOF
Usage:  $(basename $0) <Delegate from StakeAddressName> <To PoolNodeName>
EOF
  exit 1;; esac

echo
echo -e "\e[0mCreate a delegation registration certificate for Delegator\e[32m ${delegateStakeAddr}.staking.vkey\e[0m to the PoolNode\e[32m ${toPoolNodeName}.node.vkey\e[90m:"

${cardanocli} shelley stake-address delegation-certificate --staking-verification-key-file ${delegateStakeAddr}.staking.vkey --stake-pool-verification-key-file ${toPoolNodeName}.node.vkey --out-file ${delegateStakeAddr}.deleg.cert

echo
echo -e "\e[0mDelegation registration certificate:\e[32m ${delegateStakeAddr}.deleg.cert \e[90m"
cat ${delegateStakeAddr}.deleg.cert 
echo
echo -e "\e[0mCreated a delegation certificate which delegates funds from all stake addresses\nassociated with key \e[32m${delegateStakeAddr}.staking.vkey\e[0m to the pool associated with \e[32m${toPoolNodeName}.node.vkey\e[0m"
echo

