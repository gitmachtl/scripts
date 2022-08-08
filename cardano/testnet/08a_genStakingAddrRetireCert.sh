#!/bin/bash

# Script is brought to you by ATADA Stakepool, Telegram @atada_stakepool

#load variables and functions from common.sh
. "$(dirname "$0")"/00_common.sh


if [[ $# -eq 1 && ! $1 == "" ]]; then addrName="$(dirname $1)/$(basename $(basename $1 .addr) .staking)"; addrName=${addrName/#.\//}; else echo "ERROR - Usage: $0 <AddressName>"; exit 2; fi

#Checks for needed files
if [ ! -f "${addrName}.staking.vkey" ]; then echo -e "\n\e[35mERROR - \"${addrName}.staking.vkey\" does not exist! Maybe a typo?\n\e[0m"; exit 1; fi

#create a stake-address de-registration certificate
file_unlock ${addrName}.staking.dereg-cert
${cardanocli} stake-address deregistration-certificate --stake-verification-key-file ${addrName}.staking.vkey --out-file ${addrName}.staking.dereg-cert
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
file_lock ${addrName}.staking.dereg-cert

echo -e "\e[0mStaking-Address-DeRegistration-Certificate built: \e[32m ${addrName}.staking.dereg-cert \e[90m"
cat ${addrName}.staking.dereg-cert
echo
echo
echo -e "\e[35mIf you wanna de-register the Staking-Address, please use script 08b now!\e[0m"
echo
echo -e "\e[0m\n"


