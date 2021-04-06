#!/bin/bash

# Script is brought to you by ATADA_Stakepool, Telegram @atada_stakepool

#load variables from common.sh
#       socket          Path to the node.socket (also exports socket to CARDANO_NODE_SOCKET_PATH)
#       genesisfile     Path to the genesis.json
#       magicparam      TestnetMagic parameter
#       cardanocli      Path to the cardano-cli executable
#       cardanonode     Path to the cardano-node executable
. "$(dirname "$0")"/00_common.sh

#Check command line parameter
#Check command line parameter
if [ $# -lt 2 ] || [[ ! ${2^^} =~ ^(CLI|HW)$ ]]; then
cat >&2 <<EOF
ERROR - Usage: $(basename $0) <AddressName> <KeyType: cli | hw> [Account# 0-1000 for HW-Wallet-Path, Default=0]

Examples:
$(basename $0) owner cli    ... generates a PaymentOnly Address via cli (was default method before)
$(basename $0) owner hw     ... generates a PaymentOnly Address by using a Ledger/Trezor HW-Wallet

Optional with Hardware-Account-Numbers:
$(basename $0) owner hw 1   ... generates a PaymentOnly Address  by using a Leder/Trezor HW-Wallet and SubAccount #1 (Default=0)
$(basename $0) owner hw 5   ... generates a PaymentOnly Address  by using a Leder/Trezor HW-Wallet and SubAccount #51 (Default=0)

EOF
exit 1;
else
addrName="$(dirname $1)/$(basename $1 .addr)"; addrName=${addrName/#.\//};
keyType=$2;
        accountNo=0;
        if [ $# -eq 3 ]; then
        accountNo=$3;
        #Check if the given accountNo is a number and in the range. limit it to 1000 and below. actually the limit is 2^31-1, but thats ridiculous
	if [ "${accountNo}" == null ] || [ -z "${accountNo##*[!0-9]*}" ] || [ "${accountNo}" -lt 0 ] || [ "${accountNo}" -gt 1000 ]; then echo -e "\e[35mERROR - Account# for the HardwarePath is out of range (0-1000, warnings above 100)!\e[0m"; exit 2; fi
        fi


fi

#warnings
if [ -f "${addrName}.vkey" ]; then echo -e "\e[35mWARNING - ${addrName}.vkey already present, delete it or use another name !\e[0m"; exit 2; fi
if [[ -f "${addrName}.skey" ||  -f "${addrName}.hwsfile" ]]; then echo -e "\e[35mWARNING - ${addrName}.skey/hwsfile already present, delete it or use another name !\e[0m"; exit 2; fi
if [ -f "${addrName}.addr" ]; then echo -e "\e[35mWARNING - ${addrName}.addr already present, delete it or use another name !\e[0m"; exit 2; fi

if [[ ${keyType^^} == "CLI" ]]; then #Building it from the cli

	${cardanocli} ${subCommand} address key-gen --verification-key-file ${addrName}.vkey --signing-key-file ${addrName}.skey
	checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
	file_lock ${addrName}.vkey
	file_lock ${addrName}.skey

	echo -e "\e[0mPaymentOnly(Enterprise)-Verification-Key: \e[32m ${addrName}.vkey \e[90m"
	cat ${addrName}.vkey
	echo
	echo -e "\e[0mPaymentOnly(Enterprise)-Signing-Key: \e[32m ${addrName}.skey \e[90m"
	cat ${addrName}.skey
	echo

	#Building a Payment Address
	${cardanocli} ${subCommand} address build --payment-verification-key-file ${addrName}.vkey ${addrformat} > ${addrName}.addr
	checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
	file_lock ${addrName}.addr

	echo -e "\e[0mPaymentOnly(Enterprise)-Address built: \e[32m ${addrName}.addr \e[90m"
	cat ${addrName}.addr
	echo

	echo -e "\e[0m\n"


	else #Building it from HW-Keys


        #We need a enterprise paymentonly keypair with vkey and hwsfile from a Hardware-Key, so lets' create them
        start_HwWallet; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
        tmp=$(${cardanohwcli} address key-gen --path 1852H/1815H/${accountNo}H/0/0 --verification-key-file ${addrName}.vkey --hw-signing-file ${addrName}.hwsfile 2> /dev/stdout)
        if [[ "${tmp^^}" == *"ERROR"* ]]; then echo -e "\e[35m${tmp}\e[0m\n"; exit 1; else echo -e "\e[32mDONE\e[0m\n"; fi
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

        #Edit the description in the vkey file to mark this as a hardware verification key
        vkeyJSON=$(cat ${addrName}.vkey | jq ".description = \"Payment Hardware Verification Key\" ")
        echo "${vkeyJSON}" > ${addrName}.vkey
        file_lock ${addrName}.vkey
        file_lock ${addrName}.hwsfile

	echo -e "\e[0mPaymentOnly(Enterprise)-Verification-Key (Account# ${accountNo}): \e[32m ${addrName}.vkey \e[90m"
        cat ${addrName}.vkey
        echo
        echo -e "\e[0mPaymentOnly(Enterprise)-HardwareSigning-File (Account# ${accountNo}): \e[32m ${addrName}.hwsfile \e[90m"
        cat ${addrName}.hwsfile
        echo

        #Building a Payment Address
        ${cardanocli} ${subCommand} address build --payment-verification-key-file ${addrName}.vkey ${addrformat} > ${addrName}.addr
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
        file_lock ${addrName}.addr

        echo -e "\e[0mPaymentOnly(Enterprise)-Address built: \e[32m ${addrName}.addr \e[90m"
        cat ${addrName}.addr
        echo

        echo -e "\e[0m\n"

fi



