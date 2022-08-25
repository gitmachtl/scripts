#!/bin/bash

# Script is brought to you by ATADA Stakepool, Telegram @atada_stakepool

#load variables and functions from common.sh
. "$(dirname "$0")"/00_common.sh


#Check command line parameter
if [ $# -lt 2 ] || [[ ! ${2^^} =~ ^(CLI|HW|ENC)$ ]]; then
cat >&2 <<EOF
ERROR - Usage: $(basename $0) <AddressName> <KeyType: cli | enc | hw> [Account# 0-1000 for HW-Wallet-Path, Default=0]

Examples:
$(basename $0) owner cli              ... generates a PaymentOnly Address via cli (was default method before)
$(basename $0) owner enc              ... generates a PaymentOnly Address via cli and encrypt it with a Password
$(basename $0) owner hw               ... generates a PaymentOnly Address by using a Ledger/Trezor HW-Wallet

Optional with Hardware-Account-Numbers:
$(basename $0) owner hw 1   ... generates a PaymentOnly Address  by using a Leder/Trezor HW-Wallet and SubAccount #1 (Default=0)
$(basename $0) owner hw 5   ... generates a PaymentOnly Address  by using a Leder/Trezor HW-Wallet and SubAccount #5 (Default=0)

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

#trap to delete the produced files if aborted via CTRL+C(INT) or SIGINT
terminate(){
        echo -e "... doing cleanup ... \e[0m"
	file_unlock "${addrName}.vkey"
	rm -f "${addrName}.vkey" 2> /dev/null
	file_unlock "${addrName}.skey"
	rm -f "${addrName}.skey" 2> /dev/null
        exit 1
}


#warnings
if [ -f "${addrName}.vkey" ]; then echo -e "\e[35mWARNING - ${addrName}.vkey already present, delete it or use another name !\e[0m"; exit 2; fi
if [[ -f "${addrName}.skey" ||  -f "${addrName}.hwsfile" ]]; then echo -e "\e[35mWARNING - ${addrName}.skey/hwsfile already present, delete it or use another name !\e[0m"; exit 2; fi
if [ -f "${addrName}.addr" ]; then echo -e "\e[35mWARNING - ${addrName}.addr already present, delete it or use another name !\e[0m"; exit 2; fi

if [[ "${keyType^^}" == "CLI" ]]; then #Building it from the cli

	${cardanocli} address key-gen --verification-key-file ${addrName}.vkey --signing-key-file ${addrName}.skey
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
	${cardanocli} address build --payment-verification-key-file ${addrName}.vkey ${addrformat} > ${addrName}.addr
	checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
	file_lock ${addrName}.addr

	echo -e "\e[0mPaymentOnly(Enterprise)-Address built: \e[32m ${addrName}.addr \e[90m"
	cat ${addrName}.addr
	echo

	echo -e "\e[0m\n"

elif [[ "${keyType^^}" == "ENC" ]]; then #Building it from the cli and encrypt the skey file. The skey file never touches the hdd unencrypted

	skeyJSON=$(${cardanocli} address key-gen --verification-key-file "${addrName}.vkey" --signing-key-file /dev/stdout 2> /dev/null)
	checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
	file_lock ${addrName}.vkey

	echo -e "\e[0mPaymentOnly(Enterprise)-Verification-Key: \e[32m ${addrName}.vkey \e[90m"
	cat ${addrName}.vkey
	echo

	trap terminate SIGINT INT

	#Loop until we have two matching passwords
	pass_1="x"; pass_2="y"; #start with unmatched passwords
	while [[ "${pass_1}" != "${pass_2}" ]]; do

			#Read in the password
			echo -e "\e[0mPlease provide a strong password (min. 10 chars, uppercase, lowercase, specialchars) for the encryption ...\n";
			pass_1=$(ask_pass "\e[33mEnter a strong Password (empty to abort)")
			if [[ ${pass_1} == "" ]]; then echo -e "\n\e[35mAborted\e[0m\n\n"; file_unlock "${addrName}.vkey"; rm -f "${addrName}.vkey"; exit 1; fi #abort and remove the vkey file
			while [[ $(is_strong_password "${pass_1}") != "true" ]]; do
				echo -e "\n\e[35mThis is not a strong password, lets try it again...\e[0m\n"
				pass_1=$(ask_pass "\e[33mEnter a strong Password (empty to abort)")
				if [[ ${pass_1} == "" ]]; then echo -e "\n\e[35mAborted\e[0m\n\n"; file_unlock "${addrName}.vkey"; rm -f "${addrName}.vkey"; exit 1; fi #abort and remove the vkey file
			done
			echo -e "\e[0m";

			#Confirm the password
			pass_2=$(ask_pass "\e[33mConfirm the strong Password (empty to abort)")
			if [[ ${pass_2} == "" ]]; then echo -e "\n\e[35mAborted\e[0m\n\n"; file_unlock "${addrName}.vkey"; rm -f "${addrName}.vkey"; exit 1; fi #abort and remove the vkey file
			while [[ $(is_strong_password "${pass_2}") != "true" ]]; do
				echo -e "\n\e[35mThis is not a strong password, lets try it again...\e[0m\n"
				pass_2=$(ask_pass "\e[33mConfirm the strong Password (empty to abort)")
				if [[ ${pass_2} == "" ]]; then echo -e "\n\e[35mAborted\e[0m\n\n"; file_unlock "${addrName}.vkey"; rm -f "${addrName}.vkey"; exit 1; fi #abort and remove the vkey file
			done

			#If passwords don't match, show a message and let the while loop repeat
			if [[ "${pass_1}" != "${pass_2}" ]]; then echo -e "\n\e[35mThe second password does not match the first one, lets start over again...\e[0m\n"; fi

	done

	echo -e "\e[32m\nPasswords match\e[0m\n";
	password=${pass_1}
	unset pass_1
	unset pass_2

	#Entered passwords are a match, ask if it should be shown on screen for 5 seconds
	if ask "\e[33mDo you want to show the password for 5 seconds on screen to check it?" N; then echo -ne "\n\e[0mChoosen password is '\e[32m${password}\e[0m' "; sleep 1; echo -n "."; sleep 1; echo -n "."; sleep 1; echo -n "."; sleep 1; echo -n "."; sleep 1; echo -ne "\r\033[K"; fi
	echo -e "\e[0m";

        #Encrypt the data
        showProcessAnimation "Encrypting the cborHex: " &
        encrJSON=$(encrypt_skeyJSON "${skeyJSON}" "${password}"); if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\n\e[35mERROR - ${encrJSON}\e[0m\n"; exit 1; fi;
        stopProcessAnimation
        unset password
	unset skeyJSON

        echo -ne "\e[0mWriting the file '\e[32m${addrName}.skey\e[0m' to disc ... "
        file_unlock "${addrName}.skey"
        echo "${encrJSON}" > "${addrName}.skey"
        if [ $? -ne 0 ]; then echo -e "\n\n\e[35mERROR, could not write to file!\n\n\e[0m"; exit 1; fi
        file_lock "${addrName}.skey"
	echo -e "\e[32mOK\e[0m\n"

	trap - SIGINT INT

	echo -e "\e[0mPaymentOnly(Enterprise)-Signing-Key: \e[32m ${addrName}.skey \e[90m"
	cat ${addrName}.skey
	echo

	#Building a Payment Address
	${cardanocli} address build --payment-verification-key-file ${addrName}.vkey ${addrformat} > ${addrName}.addr
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
        if [[ "${tmp^^}" =~ (ERROR|DISCONNECT) ]]; then echo -e "\e[35m${tmp}\e[0m\n"; exit 1; else echo -e "\e[32mDONE\e[0m\n"; fi
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
        ${cardanocli} address build --payment-verification-key-file ${addrName}.vkey ${addrformat} > ${addrName}.addr
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
        file_lock ${addrName}.addr

        echo -e "\e[0mPaymentOnly(Enterprise)-Address built: \e[32m ${addrName}.addr \e[90m"
        cat ${addrName}.addr
        echo

        echo -e "\e[0m\n"

fi



