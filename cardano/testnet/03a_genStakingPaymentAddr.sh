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
if [ $# -lt 2 ] || [[ ! ${2^^} =~ ^(CLI|HW|HYBRID)$ ]]; then
cat >&2 <<EOF
ERROR - Usage: $(basename $0) <AddressName> <KeyType: cli | hw | hybrid> [Account# 0-1000 for HW-Wallet-Path, Default=0]

Examples:
$(basename $0) owner cli		... generates Payment & Staking keys via cli (was default method before)
$(basename $0) owner hw		... generates Payment & Staking keys using Ledger/Trezor HW-Keys
$(basename $0) owner hybrid	... generates Payment keys using Ledger/Trezor HW-Keys, Staking keys via cli (comfort mode for multiowner pools)

Optional with Hardware-Account-Numbers:
$(basename $0) owner hw 1       ... generates Payment & Staking keys using Ledger/Trezor HW-Keys and SubAccount #1 (Default=0)
$(basename $0) owner hybrid 5   ... generates Payment keys using Ledger/Trezor HW-Keys with SubAccount #5, Staking keys via cli (comfort mode for multiowner pools)

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
if [ -f "${addrName}.payment.vkey" ]; then echo -e "\e[35mWARNING - ${addrName}.payment.vkey already present, delete it or use another name !\e[0m"; exit 2; fi
if [[ -f "${addrName}.payment.skey" ||  -f "${addrName}.payment.hwsfile" ]]; then echo -e "\e[35mWARNING - ${addrName}.payment.skey/hwsfile already present, delete it or use another name. Only one instance allowed !\e[0m"; exit 2; fi
if [ -f "${addrName}.payment.addr" ]; then echo -e "\e[35mWARNING - ${addrName}.payment.addr already present, delete it or use another name !\e[0m"; exit 2; fi
if [ -f "${addrName}.staking.vkey" ]; then echo -e "\e[35mWARNING - ${addrName}.staking.vkey already present, delete it or use another name !\e[0m"; exit 2; fi
if [[ -f "${addrName}.staking.skey" ||  -f "${addrName}.staking.hwsfile" ]]; then echo -e "\e[35mWARNING - ${addrName}.staking.skey/hwsfile already present, delete it or use another name. Only one instance allowed !\e[0m"; exit 2; fi
if [ -f "${addrName}.staking.addr" ]; then echo -e "\e[35mWARNING - ${addrName}.staking.addr already present, delete it or use another name !\e[0m"; exit 2; fi
if [ -f "${addrName}.staking.cert" ]; then echo -e "\e[35mWARNING - ${addrName}.staking.cert already present, delete it or use another name !\e[0m"; exit 2; fi


if [[ ${keyType^^} == "CLI" ]]; then

	#We need a normal payment(base) keypair with vkey and skey, so let's create that one
	${cardanocli} ${subCommand} address key-gen --verification-key-file ${addrName}.payment.vkey --signing-key-file ${addrName}.payment.skey
	checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
	file_lock ${addrName}.payment.vkey
	file_lock ${addrName}.payment.skey
	echo -e "\e[0mPayment(Base)-Verification-Key: \e[32m ${addrName}.payment.vkey \e[90m"
	cat ${addrName}.payment.vkey
	echo
	echo -e "\e[0mPayment(Base)-Signing-Key: \e[32m ${addrName}.payment.skey \e[90m"
	cat ${addrName}.payment.skey
	echo

				else

	#We need a payment(base) keypair with vkey and hwsfile from a Hardware-Key, sol lets' create them
        start_HwWallet; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
  	tmp=$(${cardanohwcli} address key-gen --path 1852H/1815H/${accountNo}H/0/0 --verification-key-file ${addrName}.payment.vkey --hw-signing-file ${addrName}.payment.hwsfile 2> /dev/stdout)
        if [[ "${tmp^^}" == *"ERROR"* ]]; then echo -e "\e[35m${tmp}\e[0m\n"; exit 1; else echo -e "\e[32mDONE\e[0m\n"; fi
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

	#Edit the description in the vkey file to mark this as a hardware verification key
	vkeyJSON=$(cat ${addrName}.payment.vkey | jq ".description = \"Payment Hardware Verification Key\" ")
	echo "${vkeyJSON}" > ${addrName}.payment.vkey

        file_lock ${addrName}.payment.vkey
        file_lock ${addrName}.payment.hwsfile
        echo -e "\e[0mPayment(Base)-Verification-Key (Account# ${accountNo}): \e[32m ${addrName}.payment.vkey \e[90m"
        cat ${addrName}.payment.vkey
        echo
        echo -e "\e[0mPayment(Base)-HardwareSigning-File (Account# ${accountNo}): \e[32m ${addrName}.payment.hwsfile \e[90m"
        cat ${addrName}.payment.hwsfile
        echo

fi

echo

if [[ ${keyType^^} == "CLI" || ${keyType^^} == "HYBRID" ]]; then

	#Building the StakeAddress Keys from CLI for the normal CLI type or when HWPAYONLY was choosen
	${cardanocli} ${subCommand} stake-address key-gen --verification-key-file ${addrName}.staking.vkey --signing-key-file ${addrName}.staking.skey
	checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
	file_lock ${addrName}.staking.vkey
	file_lock ${addrName}.staking.skey

	echo -e "\e[0mVerification(Rewards)-Staking-Key: \e[32m ${addrName}.staking.vkey \e[90m"
	cat ${addrName}.staking.vkey
	echo
	echo -e "\e[0mSigning(Rewards)-Staking-Key: \e[32m ${addrName}.staking.skey \e[90m"
	cat ${addrName}.staking.skey
	echo

	else

        #We need the staking keypair with vkey and hwsfile from a Hardware-Key, sol lets' create them
        start_HwWallet; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
        tmp=$(${cardanohwcli} address key-gen --path 1852H/1815H/${accountNo}H/2/0 --verification-key-file ${addrName}.staking.vkey --hw-signing-file ${addrName}.staking.hwsfile 2> /dev/stdout)
        if [[ "${tmp^^}" == *"ERROR"* ]]; then echo -e "\e[35m${tmp}\e[0m\n"; exit 1; else echo -e "\e[32mDONE\e[0m\n"; fi
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

        #Edit the description in the vkey file to mark this as a hardware verification key
        vkeyJSON=$(cat ${addrName}.staking.vkey | jq ".description = \"Stake Hardware Verification Key\" ")
        echo "${vkeyJSON}" > ${addrName}.staking.vkey

        file_lock ${addrName}.staking.vkey
        file_lock ${addrName}.staking.hwsfile

        echo -e "\e[0mVerification(Rewards)-Staking-Key (Account# ${accountNo}): \e[32m ${addrName}.staking.vkey \e[90m"
        cat ${addrName}.staking.vkey
        echo
        echo -e "\e[0mSigning(Rewards)-HardwareSigning-File (Account# ${accountNo}): \e[32m ${addrName}.staking.hwsfile \e[90m"
        cat ${addrName}.staking.hwsfile
        echo

fi

#Building a Payment Address
${cardanocli} ${subCommand} address build --payment-verification-key-file ${addrName}.payment.vkey --staking-verification-key-file ${addrName}.staking.vkey ${addrformat} > ${addrName}.payment.addr
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
file_lock ${addrName}.payment.addr

echo -e "\e[0mPayment(Base)-Address built: \e[32m ${addrName}.payment.addr \e[90m"
cat ${addrName}.payment.addr
echo

#Building a Staking Address
${cardanocli} ${subCommand} stake-address build --staking-verification-key-file ${addrName}.staking.vkey ${addrformat} > ${addrName}.staking.addr
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
file_lock ${addrName}.staking.addr

echo -e "\e[0mStaking(Rewards)-Address built: \e[32m ${addrName}.staking.addr \e[90m"
cat ${addrName}.staking.addr
echo

#create an address registration certificate
${cardanocli} ${subCommand} stake-address registration-certificate --staking-verification-key-file ${addrName}.staking.vkey --out-file ${addrName}.staking.cert
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
file_lock ${addrName}.staking.cert

echo -e "\e[0mStaking-Address-Registration-Certificate built: \e[32m ${addrName}.staking.cert \e[90m"
cat ${addrName}.staking.cert
echo
echo
echo -e "\e[35mIf you wanna register the Staking-Address, please now run the script 03b_regStakingAddrCert.sh !\e[0m"
echo


