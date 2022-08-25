#!/bin/bash

# Script is brought to you by ATADA Stakepool, Telegram @atada_stakepool

#load variables and functions from common.sh
. "$(dirname "$0")"/00_common.sh


#Check command line parameter
if [ $# -lt 2 ] || [[ ! ${2^^} =~ ^(CLI|HW|HYBRID|ENC|HYBRIDENC)$ ]]; then
cat >&2 <<EOF
ERROR - Usage: $(basename $0) <AddressName> <KeyType: cli | enc | hw | hybrid | hybridenc> [Account# 0-1000 for HW-Wallet-Path, Default=0]

Examples:
$(basename $0) owner cli        ... generates Payment & Staking keys via cli (was default method before)
$(basename $0) owner enc        ... generates Payment & Staking keys via cli and encrypted via a Password
$(basename $0) owner hw         ... generates Payment & Staking keys using Ledger/Trezor HW-Keys
$(basename $0) owner hybrid     ... generates Payment keys using Ledger/Trezor HW-Keys, Staking keys via cli (comfort mode for multiowner pools)
$(basename $0) owner hybridenc  ... generates Payment keys using Ledger/Trezor HW-Keys, Staking keys via cli and encrypted via a Password


Optional with Hardware-Account-Numbers:
$(basename $0) owner hw 1        ... generates Payment & Staking keys using Ledger/Trezor HW-Keys and SubAccount #1 (Default=0)
$(basename $0) owner hybrid 5    ... generates Payment keys using Ledger/Trezor HW-Keys with SubAccount #5, Staking keys via cli (comfort mode for multiowner pools)
$(basename $0) owner hybridenc 7 ... generates Payment keys using Ledger/Trezor HW-Keys with SubAccount #7, Staking keys via cli and encrypted via a Password


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
	file_unlock "${addrName}.payment.vkey"
	rm -f "${addrName}.payment.vkey" 2> /dev/null
	file_unlock "${addrName}.payment.skey"
	rm -f "${addrName}.payment.vkey" 2> /dev/null
	file_unlock "${addrName}.staking.vkey"
	rm -f "${addrName}.staking.vkey" 2> /dev/null
	file_unlock "${addrName}.staking.skey"
	rm -f "${addrName}.staking.skey" 2> /dev/null
        exit 1
}


#warnings
if [ -f "${addrName}.payment.vkey" ]; then echo -e "\e[35mWARNING - ${addrName}.payment.vkey already present, delete it or use another name !\e[0m"; exit 2; fi
if [[ -f "${addrName}.payment.skey" ||  -f "${addrName}.payment.hwsfile" ]]; then echo -e "\e[35mWARNING - ${addrName}.payment.skey/hwsfile already present, delete it or use another name. Only one instance allowed !\e[0m"; exit 2; fi
if [ -f "${addrName}.payment.addr" ]; then echo -e "\e[35mWARNING - ${addrName}.payment.addr already present, delete it or use another name !\e[0m"; exit 2; fi
if [ -f "${addrName}.staking.vkey" ]; then echo -e "\e[35mWARNING - ${addrName}.staking.vkey already present, delete it or use another name !\e[0m"; exit 2; fi
if [[ -f "${addrName}.staking.skey" ||  -f "${addrName}.staking.hwsfile" ]]; then echo -e "\e[35mWARNING - ${addrName}.staking.skey/hwsfile already present, delete it or use another name. Only one instance allowed !\e[0m"; exit 2; fi
if [ -f "${addrName}.staking.addr" ]; then echo -e "\e[35mWARNING - ${addrName}.staking.addr already present, delete it or use another name !\e[0m"; exit 2; fi
if [ -f "${addrName}.staking.cert" ]; then echo -e "\e[35mWARNING - ${addrName}.staking.cert already present, delete it or use another name !\e[0m"; exit 2; fi


##############################
#### Building the Payment Keys
##############################

if [[ "${keyType^^}" == "CLI" ]]; then #Payment Keys via CLI (unencrypted)

	#We need a normal payment(base) keypair with vkey and skey, so let's create that one
	${cardanocli} address key-gen --verification-key-file "${addrName}.payment.vkey" --signing-key-file "${addrName}.payment.skey"
	checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
	file_lock ${addrName}.payment.vkey
	file_lock ${addrName}.payment.skey
	echo -e "\e[0mPayment(Base)-Verification-Key: \e[32m ${addrName}.payment.vkey \e[90m"
	cat ${addrName}.payment.vkey
	echo
	echo -e "\e[0mPayment(Base)-Signing-Key: \e[32m ${addrName}.payment.skey \e[90m"
	cat ${addrName}.payment.skey
	echo


elif [[ "${keyType^^}" == "ENC" ]]; then #Payment Keys via CLI (encrypted)

	#We need a normal payment(base) keypair with vkey and skey, so let's create that one
        skeyJSON=$(${cardanocli} address key-gen --verification-key-file "${addrName}.payment.vkey" --signing-key-file /dev/stdout 2> /dev/null)
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
        file_lock ${addrName}.payment.vkey

        echo -e "\e[0mPayment(Base)-Verification-Key: \e[32m ${addrName}.payment.vkey \e[90m"
        cat ${addrName}.payment.vkey
        echo

	trap terminate SIGINT INT

        #Loop until we have two matching passwords
        pass_1="x"; pass_2="y"; #start with unmatched passwords
        while [[ "${pass_1}" != "${pass_2}" ]]; do

                        #Read in the password
                        echo -e "\e[0mPlease provide a strong password (min. 10 chars, uppercase, lowercase, specialchars) for the encryption ...\n";
                        pass_1=$(ask_pass "\e[33mEnter a strong Password for the Payment-SKEY (empty to abort)")
                        if [[ ${pass_1} == "" ]]; then echo -e "\n\e[35mAborted\e[0m\n\n"; file_unlock "${addrName}.payment.vkey"; rm -f "${addrName}.payment.vkey"; exit 1; fi #abort and remove the vkey file
                        while [[ $(is_strong_password "${pass_1}") != "true" ]]; do
                                echo -e "\n\e[35mThis is not a strong password, lets try it again...\e[0m\n"
                                pass_1=$(ask_pass "\e[33mEnter a strong Password for the Payment-SKEY (empty to abort)")
                                if [[ ${pass_1} == "" ]]; then echo -e "\n\e[35mAborted\e[0m\n\n"; file_unlock "${addrName}.payment.vkey"; rm -f "${addrName}.payment.vkey"; exit 1; fi #abort and remove the vkey file
                        done
                        echo -e "\e[0m";

                        #Confirm the password
                        pass_2=$(ask_pass "\e[33mConfirm the strong Password (empty to abort)")
                        if [[ ${pass_2} == "" ]]; then echo -e "\n\e[35mAborted\e[0m\n\n"; file_unlock "${addrName}.payment.vkey"; rm -f "${addrName}.payment.vkey"; exit 1; fi #abort and remove the vkey file
                        while [[ $(is_strong_password "${pass_2}") != "true" ]]; do
                                echo -e "\n\e[35mThis is not a strong password, lets try it again...\e[0m\n"
                                pass_2=$(ask_pass "\e[33mConfirm the strong Password (empty to abort)")
	                        if [[ ${pass_2} == "" ]]; then echo -e "\n\e[35mAborted\e[0m\n\n"; file_unlock "${addrName}.payment.vkey"; rm -f "${addrName}.payment.vkey"; exit 1; fi #abort and remove the vkey file
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

        echo -ne "\e[0mWriting the file '\e[32m${addrName}.payment.skey\e[0m' to disc ... "
        file_unlock "${addrName}.payment.skey"
        echo "${encrJSON}" > "${addrName}.payment.skey"
        if [ $? -ne 0 ]; then echo -e "\n\n\e[35mERROR, could not write to file!\n\n\e[0m"; exit 1; fi
        file_lock "${addrName}.payment.skey"
        echo -e "\e[32mOK\e[0m\n"

	trap - SIGINT INT

	echo -e "\e[0mPayment(Base)-Signing-Key: \e[32m ${addrName}.payment.skey \e[90m"
	cat ${addrName}.payment.skey
	echo

else  #Payment Keys via HW-Wallet, also for HYBRID and HYBRIDENC

	#We need a payment(base) keypair with vkey and hwsfile from a Hardware-Key, sol lets' create them
        start_HwWallet; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
  	tmp=$(${cardanohwcli} address key-gen --path 1852H/1815H/${accountNo}H/0/0 --verification-key-file ${addrName}.payment.vkey --hw-signing-file ${addrName}.payment.hwsfile 2> /dev/stdout)
        if [[ "${tmp^^}" =~ (ERROR|DISCONNECT) ]]; then echo -e "\e[35m${tmp}\e[0m\n"; exit 1; else echo -e "\e[32mDONE\e[0m\n"; fi
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

##############################
#### Building the Staking Keys
##############################

if [[ "${keyType^^}" == "CLI" || "${keyType^^}" == "HYBRID" ]]; then #Staking Keys via CLI (unencrypted)

	#Building the StakeAddress Keys from CLI for the normal CLI type or when HYBRID was choosen
	${cardanocli} stake-address key-gen --verification-key-file "${addrName}.staking.vkey" --signing-key-file "${addrName}.staking.skey"
	checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
	file_lock ${addrName}.staking.vkey
	file_lock ${addrName}.staking.skey

	echo -e "\e[0mVerification(Rewards)-Staking-Key: \e[32m ${addrName}.staking.vkey \e[90m"
	cat ${addrName}.staking.vkey
	echo
	echo -e "\e[0mSigning(Rewards)-Staking-Key: \e[32m ${addrName}.staking.skey \e[90m"
	cat ${addrName}.staking.skey
	echo


elif [[ "${keyType^^}" == "ENC" || "${keyType^^}" == "HYBRIDENC" ]]; then #Staking Keys via CLI (encrypted)

	#Building the StakeAddress Keys from CLI for the normal CLI type or when HYBRID was choosen
	skeyJSON=$(${cardanocli} stake-address key-gen --verification-key-file "${addrName}.staking.vkey" --signing-key-file /dev/stdout 2> /dev/null)
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
        file_lock "${addrName}.staking.vkey"

	echo -e "\e[0mVerification(Rewards)-Staking-Key: \e[32m ${addrName}.staking.vkey \e[90m"
	cat "${addrName}.staking.vkey"
	echo

	trap terminate SIGINT INT

        #Loop until we have two matching passwords
        pass_1="x"; pass_2="y"; #start with unmatched passwords
        while [[ "${pass_1}" != "${pass_2}" ]]; do

                        #Read in the password
                        echo -e "\e[0mPlease provide a strong password (min. 10 chars, uppercase, lowercase, specialchars) for the encryption ...\n";
                        pass_1=$(ask_pass "\e[33mEnter a strong Password for the Staking-SKEY (empty to abort)")
                        if [[ ${pass_1} == "" ]]; then echo -e "\n\e[35mAborted\e[0m\n\n"; file_unlock "${addrName}.staking.vkey"; rm -f "${addrName}.staking.vkey"; exit 1; fi #abort and remove the vkey file
                        while [[ $(is_strong_password "${pass_1}") != "true" ]]; do
                                echo -e "\n\e[35mThis is not a strong password, lets try it again...\e[0m\n"
                                pass_1=$(ask_pass "\e[33mEnter a strong Password for the Staking-SKEY (empty to abort)")
                                if [[ ${pass_1} == "" ]]; then echo -e "\n\e[35mAborted\e[0m\n\n"; file_unlock "${addrName}.staking.vkey"; rm -f "${addrName}.staking.vkey"; exit 1; fi #abort and remove the vkey file
                        done
                        echo -e "\e[0m";

                        #Confirm the password
                        pass_2=$(ask_pass "\e[33mConfirm the strong Password (empty to abort)")
                        if [[ ${pass_2} == "" ]]; then echo -e "\n\e[35mAborted\e[0m\n\n"; file_unlock "${addrName}.staking.vkey"; rm -f "${addrName}.staking.vkey"; exit 1; fi #abort and remove the vkey file
                        while [[ $(is_strong_password "${pass_2}") != "true" ]]; do
                                echo -e "\n\e[35mThis is not a strong password, lets try it again...\e[0m\n"
                                pass_2=$(ask_pass "\e[33mConfirm the strong Password (empty to abort)")
	                        if [[ ${pass_2} == "" ]]; then echo -e "\n\e[35mAborted\e[0m\n\n"; file_unlock "${addrName}.staking.vkey"; rm -f "${addrName}.staking.vkey"; exit 1; fi #abort and remove the vkey file
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

        echo -ne "\e[0mWriting the file '\e[32m${addrName}.staking.skey\e[0m' to disc ... "
        file_unlock "${addrName}.staking.skey"
        echo "${encrJSON}" > "${addrName}.staking.skey"
        if [ $? -ne 0 ]; then echo -e "\n\n\e[35mERROR, could not write to file!\n\n\e[0m"; exit 1; fi
        file_lock "${addrName}.staking.skey"
        echo -e "\e[32mOK\e[0m\n"

	trap - SIGINT INT

	echo -e "\e[0mSigning(Rewards)-Staking-Key: \e[32m ${addrName}.staking.skey \e[90m"
	cat ${addrName}.staking.skey
	echo


else  #Staking Keys via HW-Wallet

        #We need the staking keypair with vkey and hwsfile from a Hardware-Key, sol lets' create them
        start_HwWallet; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
        tmp=$(${cardanohwcli} address key-gen --path 1852H/1815H/${accountNo}H/2/0 --verification-key-file ${addrName}.staking.vkey --hw-signing-file ${addrName}.staking.hwsfile 2> /dev/stdout)
        if [[ "${tmp^^}" =~ (ERROR|DISCONNECT) ]]; then echo -e "\e[35m${tmp}\e[0m\n"; exit 1; else echo -e "\e[32mDONE\e[0m\n"; fi
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
${cardanocli} address build --payment-verification-key-file "${addrName}.payment.vkey" --staking-verification-key-file "${addrName}.staking.vkey" ${addrformat} > "${addrName}.payment.addr"
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
file_lock "${addrName}.payment.addr"

echo -e "\e[0mPayment(Base)-Address built: \e[32m ${addrName}.payment.addr \e[90m"
cat "${addrName}.payment.addr"
echo
echo

#Building a Staking Address
${cardanocli} stake-address build --staking-verification-key-file "${addrName}.staking.vkey" ${addrformat} > "${addrName}.staking.addr"
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
file_lock "${addrName}.staking.addr"

echo -e "\e[0mStaking(Rewards)-Address built: \e[32m ${addrName}.staking.addr \e[90m"
cat "${addrName}.staking.addr"
echo

#create an address registration certificate
${cardanocli} stake-address registration-certificate --staking-verification-key-file "${addrName}.staking.vkey" --out-file "${addrName}.staking.cert"
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
file_lock "${addrName}.staking.cert"

echo -e "\e[0mStaking-Address-Registration-Certificate built: \e[32m ${addrName}.staking.cert \e[90m"
cat "${addrName}.staking.cert"
echo
echo
echo -e "\e[35mIf you wanna register the Staking-Address, please now run the script 03b_regStakingAddrCert.sh !\e[0m"
echo


