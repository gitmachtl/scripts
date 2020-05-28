#!/bin/bash

#load variables from common.sh
#       socket          Path to the node.socket (also exports socket to CARDANO_NODE_SOCKET_PATH)
#       genesisfile     Path to the genesis.json
#       magicparam      TestnetMagic paramter
. "$(dirname "$0")"/00_common.sh

case $# in
  5 ) poolName="$1";
      ownerName="$2";
      poolPledge="$3";
      poolCost="$4";
      poolMargin="$5";;
  * ) cat >&2 <<EOF
Usage:  $(basename $0) <PoolNodeName> <OwnerStakeAddressName> <pledgeInLovelaces> <poolCostInLovelaces> <poolMargin 0.01-1.00>
EOF
  exit 1;; esac

#poolPledge="100000000000"	#100k ADA
#poolCost="10000000000"		#10k ADA
#poolMargin="0.01"		#1%

echo
echo -e "\e[0mCreate a Stakepool registration certificate for PoolNode with \e[32m ${poolName}.node.vkey, ${poolName}.vrf.vkey\e[0m & OwnerStake\e[32m ${ownerName}.staking.vkey\e[0m:"
echo
echo -e "\e[0mPledge:\e[32m ${poolPledge} \e[90mlovelaces"
echo -e "\e[0m  Cost:\e[32m ${poolCost} \e[90mlovelaces"
echo -e "\e[0mMargin:\e[32m ${poolMargin} \e[0m"

#Usage: cardano-cli shelley stake-pool registration-certificate --cold-verification-key-file FILE
#                                                               --vrf-verification-key-file FILE
#                                                               --pool-pledge LOVELACE
#                                                               --pool-cost LOVELACE
#                                                               --pool-margin DOUBLE
#                                                               --pool-reward-account-verification-key-file FILE
#                                                               --pool-owner-stake-verification-key-file FILE
#                                                               --out-file FILE
#  Create a stake pool registration certificate



${cardanocli} shelley stake-pool registration-certificate --cold-verification-key-file ${poolName}.node.vkey --vrf-verification-key-file ${poolName}.vrf.vkey --pool-pledge ${poolPledge} --pool-cost ${poolCost} --pool-margin ${poolMargin} --pool-reward-account-verification-key-file ${ownerName}.staking.vkey --pool-owner-stake-verification-key-file ${ownerName}.staking.vkey --out-file ${poolName}.pool.cert

echo
echo -e "\e[0mStakepool registration certificate:\e[32m ${poolName}.pool.cert \e[90m"
cat ${poolName}.pool.cert 
echo
echo -e "\e[0m"


