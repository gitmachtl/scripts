#!/bin/bash

############################################################
#    _____ ____  ____     _____           _       __
#   / ___// __ \/ __ \   / ___/__________(_)___  / /______
#   \__ \/ /_/ / / / /   \__ \/ ___/ ___/ / __ \/ __/ ___/
#  ___/ / ____/ /_/ /   ___/ / /__/ /  / / /_/ / /_(__  )
# /____/_/    \____/   /____/\___/_/  /_/ .___/\__/____/
#                                    /_/
#
# Scripts are brought to you by Martin L. (ATADA Stakepool)
# Telegram: @atada_stakepool   Github: github.com/gitmachtl
#
############################################################

#load variables and functions from common.sh
. "$(dirname "$0")"/00_common.sh

#Check command line parameter
if [ $# -lt 2 ] || [[ ! ${2^^} =~ ^(CLI|ENC)$ ]]; then
cat >&2 <<EOF
ERROR - Usage: $(basename $0) <NodePoolName> <KeyType: cli | enc>

Examples:
$(basename $0) mypool cli   ... generates the node BLS keys from standard CLI commands (was default before)
$(basename $0) mypool enc   ... generates the node BLS keys from standard CLI commands but encrypted via a Password

EOF
exit 1;
fi

nodeName="${1}"
keyType="${2}"

#trap to delete the produced files if aborted via CTRL+C(INT) or SIGINT
terminate(){
        echo -e "... doing cleanup ... \e[0m"
	file_unlock "${nodeName}.bls.vkey"
	rm -f "${nodeName}.bls.vkey"
	exit 1
}


### SET ERA TO DIJKSTRA -> WILL BE CHANGED TO LATEST LATER ON
cliEra="dijkstra"

#check if files already present
if [ -f "${nodeName}.bls.vkey" ]; then echo -e "\e[35mWARNING - ${nodeName}.bls.vkey already present, if you wanna renew it, please delete the .vkey and .skey file and re-run this command !\e[0m\n"; exit 2; fi
if [ -f "${nodeName}.bls.skey" ]; then echo -e "\e[35mWARNING - ${nodeName}.bls.skey already present, if you wanna renew it, please delete the .vkey and .skey file and re-run this command !\e[0m\n"; exit 2; fi

echo -e "\e[0mCreating BLS operational Keypairs"
echo


if [[ "${keyType^^}" == "CLI" ]]; then #Building it from the cli (unencrypted)

	${cardanocli} ${cliEra} node key-gen-BLS --verification-key-file "${nodeName}.bls.vkey" --signing-key-file "${nodeName}.bls.skey"
	checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
	file_lock ${nodeName}.bls.vkey
	file_lock ${nodeName}.bls.skey

	echo -e "\e[0mNode operational BLS-Verification-Key:\e[32m ${nodeName}.bls.vkey \e[90m"
	cat "${nodeName}.bls.vkey"
	echo
	echo -e "\e[0mNode operational BLS-Signing-Key:\e[32m ${nodeName}.bls.skey \e[90m"
	cat "${nodeName}.bls.skey"
	echo

elif [[ "${keyType^^}" == "ENC" ]]; then #Building it from the cli (encrypted)

        skeyJSON=$(${cardanocli} ${cliEra} node key-gen-BLS --verification-key-file "${nodeName}.bls.vkey" --signing-key-file /dev/stdout)
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
	file_lock ${nodeName}.bls.vkey

	echo -e "\e[0mNode operational BLS-Verification-Key:\e[32m ${nodeName}.bls.vkey \e[90m"
	cat "${nodeName}.bls.vkey"
	echo

	trap terminate SIGINT INT

        #Loop until we have two matching passwords
        pass_1="x"; pass_2="y"; #start with unmatched passwords
        while [[ "${pass_1}" != "${pass_2}" ]]; do

                        #Read in the password
                        echo -e "\e[0mPlease provide a strong password (min. 10 chars, uppercase, lowercase, specialchars) for the encryption ...\n";
                        pass_1=$(ask_pass "\e[33mEnter a strong Password for the BLS-SKEY (empty to abort)")
                        if [[ ${pass_1} == "" ]]; then echo -e "\n\e[35mAborted\e[0m\n\n"; file_unlock "${nodeName}.bls.vkey"; rm -f "${nodeName}.bls.vkey"; exit 1; fi #abort and remove the vkey/counter files
                        while [[ $(is_strong_password "${pass_1}") != "true" ]]; do
                                echo -e "\n\e[35mThis is not a strong password, lets try it again...\e[0m\n"
                                pass_1=$(ask_pass "\e[33mEnter a strong Password for the BLS-SKEY (empty to abort)")
	                        if [[ ${pass_1} == "" ]]; then echo -e "\n\e[35mAborted\e[0m\n\n"; file_unlock "${nodeName}.bls.vkey"; rm -f "${nodeName}.bls.vkey"; exit 1; fi #abort and remove the vkey/counter files
                        done
                        echo -e "\e[0m";

                        #Confirm the password
                        pass_2=$(ask_pass "\e[33mConfirm the strong Password (empty to abort)")
                        if [[ ${pass_2} == "" ]]; then echo -e "\n\e[35mAborted\e[0m\n\n"; file_unlock "${nodeName}.bls.vkey"; rm -f "${nodeName}.bls.vkey"; exit 1; fi #abort and remove the vkey/counter files
                        while [[ $(is_strong_password "${pass_2}") != "true" ]]; do
                                echo -e "\n\e[35mThis is not a strong password, lets try it again...\e[0m\n"
                                pass_2=$(ask_pass "\e[33mConfirm the strong Password (empty to abort)")
	                        if [[ ${pass_2} == "" ]]; then echo -e "\n\e[35mAborted\e[0m\n\n"; file_unlock "${nodeName}.bls.vkey"; rm -f "${nodeName}.bls.vkey"; exit 1; fi #abort and remove the vkey/counter files
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

        echo -ne "\e[0mWriting the file '\e[32m${nodeName}.bls.skey\e[0m' to disc ... "
        file_unlock "${nodeName}.bls.skey"
        echo "${encrJSON}" > "${nodeName}.bls.skey"
        if [ $? -ne 0 ]; then echo -e "\n\n\e[35mERROR, could not write to file!\n\n\e[0m"; exit 1; fi
	file_lock "${nodeName}.bls.skey"
        echo -e "\e[32mOK\e[0m\n"

	trap - SIGINT INT

	echo -e "\e[0mNode operational BLS-Signing-Key:\e[32m ${nodeName}.bls.skey \e[90m"
	cat "${nodeName}.bls.skey"
	echo

fi




echo -e "\e[0m\n"
