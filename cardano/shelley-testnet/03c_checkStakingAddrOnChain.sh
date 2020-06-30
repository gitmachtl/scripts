#!/bin/bash

# Script is brought to you by ATADA_Stakepool, Telegram @atada_stakepool

#load variables from common.sh
#       socket          Path to the node.socket (also exports socket to CARDANO_NODE_SOCKET_PATH)
#       genesisfile     Path to the genesis.json
#       magicparam      TestnetMagic parameter
#       cardanocli      Path to the cardano-cli executable
#       cardanonode     Path to the cardano-node executable
. "$(dirname "$0")"/00_common.sh

if [[ $# -eq 1 && ! $1 == "" ]]; then addrName=$1; else echo "ERROR - Usage: $(basename $0) <StakeAddressName> (pointing to the StakeAddressName.staking.addr file)"; exit 1; fi

#Check if addr file exists
if [ ! -f "${addrName}.staking.addr" ]; then echo -e "\n\e[33mERROR - \"${addrName}.staking.addr\" does not exist.\e[0m"; exit 1; fi

checkAddr=$(cat ${addrName}.staking.addr | cut -c 7-)

echo
echo -e "\e[0mChecking the ledger-state about the \e[32m ${addrName}.staking.addr\e[0m: ${checkAddr}"
echo

#check ledger-state
#stakeAddrInLedgerCnt=$(${cardanocli} shelley query ledger-state ${magicparam} | jq ._delegationState._dstate._stkCreds | grep "${checkAddr}" | wc -l)
stakeAddrInLedgerCnt=$(${cardanocli} shelley query ledger-state ${magicparam} | grep "\"${checkAddr}\"" | wc -l)



if [[ ${stakeAddrInLedgerCnt} -gt 0 ]]; then
					echo -e "\e[32mStake-Address is registered on the chain!\e[0m";
				    else
					echo -e "\e[35mStake-Address is NOT registered on the chain!\e[0m";
fi
echo
