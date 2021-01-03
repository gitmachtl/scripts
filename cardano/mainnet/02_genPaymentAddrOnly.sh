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
if [ $# -ne 2 ] || [[ ! ${2^^} =~ ^(CLI|HW)$ ]]; then
cat >&2 <<EOF
ERROR - Usage: $(basename $0) <AddressName> <KeyType: cli | hw>

Examples:
$(basename $0) owner cli    ... generates a PaymentOnly Address via cli (was default method before)
$(basename $0) owner hw     ... generates a PaymentOnly Address by using a Ledger/Trezor HW-Wallet

EOF
exit 1;
else
addrName="$(dirname $1)/$(basename $1 .addr)"; addrName=${addrName/#.\//};
keyType=$2;
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
        tmp=$(${cardanohwcli} shelley address key-gen --path 1852H/1815H/0H/0/0 --verification-key-file ${addrName}.vkey --hw-signing-file ${addrName}.hwsfile 2> /dev/stdout)
        if [[ "${tmp^^}" == *"ERROR"* ]]; then echo -e "\e[35m${tmp}\e[0m\n"; exit 1; else echo -e "\e[32mDONE\e[0m\n"; fi
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

        #Edit the description in the vkey file to mark this as a hardware verification key
        vkeyJSON=$(cat ${addrName}.vkey | jq ".description = \"Payment Hardware Verification Key\" ")
        echo "${vkeyJSON}" > ${addrName}.vkey
        file_lock ${addrName}.vkey
        file_lock ${addrName}.hwsfile

	echo -e "\e[0mPaymentOnly(Enterprise)-Verification-Key: \e[32m ${addrName}.vkey \e[90m"
        cat ${addrName}.vkey
        echo
        echo -e "\e[0mPaymentOnly(Enterprise)-HardwareSigning-File: \e[32m ${addrName}.hwsfile \e[90m"
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



