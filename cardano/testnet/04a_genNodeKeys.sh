#!/bin/bash

# Script is brought to you by ATADA Stakepool, Telegram @atada_stakepool

#load variables and functions from common.sh
. "$(dirname "$0")"/00_common.sh



#Check command line parameter
if [ $# -lt 2 ] || [[ ! ${2^^} =~ ^(CLI|HW|ENC)$ ]]; then
cat >&2 <<EOF
ERROR - Usage: $(basename $0) <NodePoolName> <KeyType: cli | enc | hw>

Examples:
$(basename $0) mypool cli   ... generates the node cold keys from standard CLI commands (was default before hw option)
$(basename $0) mypool enc   ... generates the node cold keys from standard CLI commands but encrypted via a Password
$(basename $0) mypool hw    ... generates the node cold keys by using a Ledger/Trezor HW-Wallet

EOF
exit 1;
fi

nodeName="${1}"
keyType="${2}"
keyIndex=0

if [ $# -ge 3 ]; then
  keyIndex="${3}"
fi

#trap to delete the produced files if aborted via CTRL+C(INT) or SIGINT
terminate(){
        echo -e "... doing cleanup ... \e[0m"
	file_unlock "${nodeName}.node.vkey"
	file_unlock "${nodeName}.node.counter"
	rm -f "${nodeName}.node.vkey"
	rm -f "${nodeName}.node.counter"
	exit 1
}


#Check if there are already node cold files
if [ -f "${nodeName}.node.vkey" ]; then echo -e "\e[35mWARNING - ${nodeName}.node.vkey already present, delete it or use another name !\e[0m"; exit 2; fi
if [ -f "${nodeName}.node.skey" ]; then echo -e "\e[35mWARNING - ${nodeName}.node.skey already present, delete it or use another name !\e[0m"; exit 2; fi
if [ -f "${nodeName}.node.hwsfile" ]; then echo -e "\e[35mWARNING - ${nodeName}.node.hwsfile already present, delete it or use another name !\e[0m"; exit 2; fi
if [ -f "${nodeName}.node.counter" ]; then echo -e "\e[35mWARNING - ${nodeName}.node.counter already present, delete it or use another name !\e[0m"; exit 2; fi


if [[ "${keyType^^}" == "CLI" ]]; then #Building it from the cli (unencrypted)

	echo -e "\e[0mCreating Node Cold/Offline Keys (CLI)\e[32m ${nodeName}.node.vkey/skey\e[0m and Issue.Counter File\e[32m ${nodeName}.node.counter"
	echo

	${cardanocli} node key-gen --verification-key-file "${nodeName}.node.vkey" --signing-key-file "${nodeName}.node.skey" --operational-certificate-issue-counter "${nodeName}.node.counter"
	checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
	file_lock ${nodeName}.node.vkey
	file_lock ${nodeName}.node.skey
	file_lock ${nodeName}.node.counter

	echo -e "\e[0mNode Cold Verification-Key:\e[32m ${nodeName}.node.vkey \e[90m"
	cat ${nodeName}.node.vkey
	echo
	echo -e "\e[0mNode Cold Signing-Key:\e[32m ${nodeName}.node.skey \e[90m"
	cat ${nodeName}.node.skey
	echo
	echo -e "\e[0mNode Operational-Certificate-Issue-Counter:\e[32m ${nodeName}.node.counter \e[90m"
	cat ${nodeName}.node.counter
	echo

elif [[ "${keyType^^}" == "ENC" ]]; then #Building it from the cli (encrypted)

        skeyJSON=$(${cardanocli} node key-gen --verification-key-file "${nodeName}.node.vkey" --signing-key-file /dev/stdout --operational-certificate-issue-counter "${nodeName}.node.counter" 2> /dev/null)
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
	file_lock "${nodeName}.node.vkey"
	file_lock "${nodeName}.node.counter"

	echo -e "\e[0mNode Cold Verification-Key:\e[32m ${nodeName}.node.vkey \e[90m"
	cat "${nodeName}.node.vkey"
	echo

	trap terminate SIGINT INT

        #Loop until we have two matching passwords
        pass_1="x"; pass_2="y"; #start with unmatched passwords
        while [[ "${pass_1}" != "${pass_2}" ]]; do

                        #Read in the password
                        echo -e "\e[0mPlease provide a strong password (min. 10 chars, uppercase, lowercase, specialchars) for the encryption ...\n";
                        pass_1=$(ask_pass "\e[33mEnter a strong Password for the NODE-SKEY (empty to abort)")
                        if [[ ${pass_1} == "" ]]; then echo -e "\n\e[35mAborted\e[0m\n\n"; file_unlock "${nodeName}.node.vkey"; file_unlock "${nodeName}.node.counter";  rm -f "${nodeName}.node.vkey"; rm -f "${nodeName}.node.counter"; exit 1; fi #abort and remove the vkey/counter files
                        while [[ $(is_strong_password "${pass_1}") != "true" ]]; do
                                echo -e "\n\e[35mThis is not a strong password, lets try it again...\e[0m\n"
                                pass_1=$(ask_pass "\e[33mEnter a strong Password for the NODE-SKEY (empty to abort)")
	                        if [[ ${pass_1} == "" ]]; then echo -e "\n\e[35mAborted\e[0m\n\n"; file_unlock "${nodeName}.node.vkey"; file_unlock "${nodeName}.node.counter";  rm -f "${nodeName}.node.vkey"; rm -f "${nodeName}.node.counter"; exit 1; fi #abort and remove the vkey/counter files
                        done
                        echo -e "\e[0m";

                        #Confirm the password
                        pass_2=$(ask_pass "\e[33mConfirm the strong Password (empty to abort)")
                        if [[ ${pass_2} == "" ]]; then echo -e "\n\e[35mAborted\e[0m\n\n"; file_unlock "${nodeName}.node.vkey"; file_unlock "${nodeName}.node.counter";  rm -f "${nodeName}.node.vkey"; rm -f "${nodeName}.node.counter"; exit 1; fi #abort and remove the vkey/counter files
                        while [[ $(is_strong_password "${pass_2}") != "true" ]]; do
                                echo -e "\n\e[35mThis is not a strong password, lets try it again...\e[0m\n"
                                pass_2=$(ask_pass "\e[33mConfirm the strong Password (empty to abort)")
	                        if [[ ${pass_2} == "" ]]; then echo -e "\n\e[35mAborted\e[0m\n\n"; file_unlock "${nodeName}.node.vkey"; file_unlock "${nodeName}.node.counter";  rm -f "${nodeName}.node.vkey"; rm -f "${nodeName}.node.counter"; exit 1; fi #abort and remove the vkey/counter files
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

        echo -ne "\e[0mWriting the file '\e[32m${nodeName}.node.skey\e[0m' to disc ... "
        file_unlock "${nodeName}.node.skey"
        echo "${encrJSON}" > "${nodeName}.node.skey"
        if [ $? -ne 0 ]; then echo -e "\n\n\e[35mERROR, could not write to file!\n\n\e[0m"; exit 1; fi
        file_lock "${nodeName}.node.skey"
        echo -e "\e[32mOK\e[0m\n"

	trap - SIGINT INT

	echo -e "\e[0mNode Cold Signing-Key:\e[32m ${nodeName}.node.skey \e[90m"
	cat ${nodeName}.node.skey
	echo
	echo -e "\e[0mNode Operational-Certificate-Issue-Counter:\e[32m ${nodeName}.node.counter \e[90m"
	cat ${nodeName}.node.counter
	echo


else #Building it from HW-Keys

        echo -e "\e[0mCreating Node Cold/Offline Keys (HW)\e[32m ${nodeName}.node.vkey/hwsfile\e[0m and Issue.Counter File\e[32m ${nodeName}.node.counter"
        echo

	#This function is currently limited to Ledger HW-Wallets only, so call the start_HwWallet function with a restriction to Ledger only
        start_HwWallet "Ledger"; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
        tmp=$(${cardanohwcli} node key-gen --path 1853H/1815H/0H/${keyIndex}H --cold-verification-key-file ${nodeName}.node.vkey --hw-signing-file ${nodeName}.node.hwsfile --operational-certificate-issue-counter-file ${nodeName}.node.counter 2> /dev/stdout)
        if [[ "${tmp^^}" =~ (ERROR|DISCONNECT) ]]; then echo -e "\e[35m${tmp}\e[0m\n"; exit 1; else echo -e "\e[32mDONE\e[0m\n"; fi
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
        file_lock ${nodeName}.node.vkey
        file_lock ${nodeName}.node.hwsfile
        file_lock ${nodeName}.node.counter

        echo -e "\e[0mNode Cold Verification-Key:\e[32m ${nodeName}.node.vkey \e[90m"
        cat ${nodeName}.node.vkey
        echo
	echo
        echo -e "\e[0mNode Cold HardwareSigning-File:\e[32m ${nodeName}.node.hwsfile \e[90m"
        cat ${nodeName}.node.hwsfile
        echo
	echo
        echo -e "\e[0mNode Operational-Certificate-Issue-Counter:\e[32m ${nodeName}.node.counter \e[90m"
        cat ${nodeName}.node.counter
        echo

fi

echo -e "\e[0m\n"
