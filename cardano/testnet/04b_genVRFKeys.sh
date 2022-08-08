#!/bin/bash

# Script is brought to you by ATADA Stakepool, Telegram @atada_stakepool

#load variables and functions from common.sh
. "$(dirname "$0")"/00_common.sh

#Check command line parameter
if [ $# -lt 2 ] || [[ ! ${2^^} =~ ^(CLI|ENC)$ ]]; then
cat >&2 <<EOF
ERROR - Usage: $(basename $0) <NodePoolName> <KeyType: cli | enc>

Examples:
$(basename $0) mypool cli   ... generates the node VRF keys from standard CLI commands (was default before)
$(basename $0) mypool enc   ... generates the node VRF keys from standard CLI commands but encrypted via a Password

EOF
exit 1;
fi

nodeName="${1}"
keyType="${2}"

#trap to delete the produced files if aborted via CTRL+C(INT) or SIGINT
terminate(){
        echo -e "... doing cleanup ... \e[0m"
	file_unlock "${nodeName}.vrf.vkey"
	rm -f "${nodeName}.vrf.vkey"
	exit 1
}

#check if files already present
if [ -f "${nodeName}.vrf.vkey" ]; then echo -e "\e[35mWARNING - ${nodeName}.vrf.vkey already present, delete it or use another name !\e[0m\n"; exit 2; fi
if [ -f "${nodeName}.vrf.skey" ]; then echo -e "\e[35mWARNING - ${nodeName}.vrf.skey already present, delete it or use another name !\e[0m\n"; exit 2; fi

echo -e "\e[0mCreating VRF operational Keypairs"
echo


if [[ "${keyType^^}" == "CLI" ]]; then #Building it from the cli (unencrypted)

	${cardanocli} node key-gen-VRF --verification-key-file "${nodeName}.vrf.vkey" --signing-key-file "${nodeName}.vrf.skey"
	checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
	file_lock ${nodeName}.vrf.vkey
	file_lock ${nodeName}.vrf.skey

	echo -e "\e[0mNode operational VRF-Verification-Key:\e[32m ${nodeName}.vrf.vkey \e[90m"
	cat "${nodeName}.vrf.vkey"
	echo
	echo -e "\e[0mNode operational VRF-Signing-Key:\e[32m ${nodeName}.vrf.skey \e[90m"
	cat "${nodeName}.vrf.skey"
	echo

elif [[ "${keyType^^}" == "ENC" ]]; then #Building it from the cli (encrypted)

        ${cardanocli} node key-gen-VRF --verification-key-file "${nodeName}.vrf.vkey" --signing-key-file "${nodeName}.vrf.skey" #workaround because the key-gen-VRF command cannot output to /dev/stdout
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
	skeyJSON=$(cat "${nodeName}.vrf.skey"); rm -f "${nodeName}.vrf.skey" #workaround because the key-gen-VRF command cannot output to /dev/stdout
	file_lock ${nodeName}.vrf.vkey

	echo -e "\e[0mNode operational VRF-Verification-Key:\e[32m ${nodeName}.vrf.vkey \e[90m"
	cat "${nodeName}.vrf.vkey"
	echo

	trap terminate SIGINT INT

        #Loop until we have two matching passwords
        pass_1="x"; pass_2="y"; #start with unmatched passwords
        while [[ "${pass_1}" != "${pass_2}" ]]; do

                        #Read in the password
                        echo -e "\e[0mPlease provide a strong password (min. 10 chars, uppercase, lowercase, specialchars) for the encryption ...\n";
                        pass_1=$(ask_pass "\e[33mEnter a strong Password for the VRF-SKEY (empty to abort)")
                        if [[ ${pass_1} == "" ]]; then echo -e "\n\e[35mAborted\e[0m\n\n"; file_unlock "${nodeName}.vrf.vkey"; rm -f "${nodeName}.vrf.vkey"; exit 1; fi #abort and remove the vkey/counter files
                        while [[ $(is_strong_password "${pass_1}") != "true" ]]; do
                                echo -e "\n\e[35mThis is not a strong password, lets try it again...\e[0m\n"
                                pass_1=$(ask_pass "\e[33mEnter a strong Password for the VRF-SKEY (empty to abort)")
	                        if [[ ${pass_1} == "" ]]; then echo -e "\n\e[35mAborted\e[0m\n\n"; file_unlock "${nodeName}.vrf.vkey"; rm -f "${nodeName}.vrf.vkey"; exit 1; fi #abort and remove the vkey/counter files
                        done
                        echo -e "\e[0m";

                        #Confirm the password
                        pass_2=$(ask_pass "\e[33mConfirm the strong Password (empty to abort)")
                        if [[ ${pass_2} == "" ]]; then echo -e "\n\e[35mAborted\e[0m\n\n"; file_unlock "${nodeName}.vrf.vkey"; rm -f "${nodeName}.vrf.vkey"; exit 1; fi #abort and remove the vkey/counter files
                        while [[ $(is_strong_password "${pass_2}") != "true" ]]; do
                                echo -e "\n\e[35mThis is not a strong password, lets try it again...\e[0m\n"
                                pass_2=$(ask_pass "\e[33mConfirm the strong Password (empty to abort)")
	                        if [[ ${pass_2} == "" ]]; then echo -e "\n\e[35mAborted\e[0m\n\n"; file_unlock "${nodeName}.vrf.vkey"; rm -f "${nodeName}.vrf.vkey"; exit 1; fi #abort and remove the vkey/counter files
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

        echo -ne "\e[0mWriting the file '\e[32m${nodeName}.vrf.skey\e[0m' to disc ... "
        file_unlock "${nodeName}.vrf.skey"
        echo "${encrJSON}" > "${nodeName}.vrf.skey"
        if [ $? -ne 0 ]; then echo -e "\n\n\e[35mERROR, could not write to file!\n\n\e[0m"; exit 1; fi
	file_lock "${nodeName}.vrf.skey"
        echo -e "\e[32mOK\e[0m\n"

	trap - SIGINT INT

	echo -e "\e[0mNode operational VRF-Signing-Key:\e[32m ${nodeName}.vrf.skey \e[90m"
	cat "${nodeName}.vrf.skey"
	echo

fi




echo -e "\e[0m\n"
