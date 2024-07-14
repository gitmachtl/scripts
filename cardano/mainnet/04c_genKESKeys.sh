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
$(basename $0) mypool cli   ... generates the KES keys from standard CLI commands (was default before)
$(basename $0) mypool enc   ... generates the KES keys from standard CLI commands but encrypted via a Password

EOF
exit 1;
fi

nodeName="${1}"
keyType="${2}"


#trap to delete the produced files if aborted via CTRL+C(INT) or SIGINT
terminate(){
        echo -e "... doing cleanup ... \e[0m"
	file_unlock "${nodeName}.kes-${nextKESnumber}.vkey"
	rm -f "${nodeName}.kes-${nextKESnumber}.vkey"
	exit 1
}


echo -e "\e[0mCreating KES operational Keypairs"
echo

#read the current kes.counter file if it exists
if [ -f "${nodeName}.kes.counter" ]; then
	currentKESnumber=$(cat "${nodeName}.kes.counter");
	currentKESnumber=$(printf "%03d" $((10#${currentKESnumber})) ); #to get a nice 3 digit output
	else
	currentKESnumber="";
fi

#grab the next issue number from the kes.counter-next file
#if it doesn't exist yet, check if there is an existing kes.counter file (upgrade path) and use that as a base for the new one
if [ ! -f "${nodeName}.kes.counter-next" ]; then

	echo -e "\e[0mKES-Counter-Next file doesn't exist yet, create it:\e[32m ${nodeName}.kes.counter-next \e[90m"

	#if there is an existing counter, set the next value to +1, otherwise set it to 0. because its the first one that will be created
	if [ "${currentKESnumber}" != "" ]; then nextKESnumber=$(( 10#${currentKESnumber} + 1 )); else nextKESnumber=0; fi

	nextKESnumber=$(printf "%03d" $((10#${nextKESnumber})) )  #to get a nice 3 digit output
	echo ${nextKESnumber} > ${nodeName}.kes.counter-next
	file_lock ${nodeName}.kes.counter-next
	cat ${nodeName}.kes.counter-next
	echo

	else #kes.counter-next file exists, read in the value
	nextKESnumber=$(cat "${nodeName}.kes.counter-next"); nextKESnumber=$(printf "%03d" $((10#${nextKESnumber})) )  #to get a nice 3 digit output
	echo -e "\e[0mKES-Counter-Next:\e[32m ${nodeName}.kes.counter-next \e[90m"
	cat ${nodeName}.kes.counter-next
	echo

fi

#check if the current one is already at the same counter as the next-counter, if so, don't generate new kes keys. will need an opcert generation in between
#to increment further
if [[ "${nextKESnumber}" == "${currentKESnumber}" ]]; then echo -e "\e[0mINFO - There is no need to create new KES Keys, please generate a new OpCert first with the latest existing ones using script 04d !\n\e[0m"; exit 2; fi


#Check if there are already node cold files
if [ -f "${nodeName}.kes-${nextKESnumber}.vkey" ]; then echo -e "\e[35mWARNING - ${nodeName}.kes-${nextKESnumber}.vkey already present, delete it first !\e[0m"; exit 2; fi
if [ -f "${nodeName}.kes-${nextKESnumber}.skey" ]; then echo -e "\e[35mWARNING - ${nodeName}.kes-${nextKESnumber}.skey already present, delete it first !\e[0m"; exit 2; fi


#Build KES Keys unencrypted or encrypted
if [[ "${keyType^^}" == "CLI" ]]; then #Building it from the cli (unencrypted)

	${cardanocli} ${cliEra} node key-gen-KES --verification-key-file "${nodeName}.kes-${nextKESnumber}.vkey" --signing-key-file "${nodeName}.kes-${nextKESnumber}.skey"
	checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
	file_lock "${nodeName}.kes-${nextKESnumber}.vkey"
	file_lock "${nodeName}.kes-${nextKESnumber}.skey"

	echo -e "\e[0mNode operational KES-Verification-Key:\e[32m ${nodeName}.kes-${nextKESnumber}.vkey \e[90m"
	cat ${nodeName}.kes-${nextKESnumber}.vkey
	echo

elif [[ "${keyType^^}" == "ENC" ]]; then #Building it from the cli (encrypted)


        skeyJSON=$(${cardanocli} ${cliEra} node key-gen-KES --verification-key-file "${nodeName}.kes-${nextKESnumber}.vkey" --signing-key-file /dev/stdout 2> /dev/null)
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
	file_lock ${nodeName}.kes-${nextKESnumber}.vkey

	echo -e "\e[0mNode operational KES-Verification-Key:\e[32m ${nodeName}.kes-${nextKESnumber}.vkey \e[90m"
	cat "${nodeName}.kes-${nextKESnumber}.vkey"
	echo

	trap terminate SIGINT INT

        #Loop until we have two matching passwords
        pass_1="x"; pass_2="y"; #start with unmatched passwords
        while [[ "${pass_1}" != "${pass_2}" ]]; do

                        #Read in the password
                        echo -e "\e[0mPlease provide a strong password (min. 10 chars, uppercase, lowercase, specialchars) for the encryption ...\n";
                        pass_1=$(ask_pass "\e[33mEnter a strong Password for the KES-SKEY (empty to abort)")
                        if [[ ${pass_1} == "" ]]; then echo -e "\n\e[35mAborted\e[0m\n\n"; file_unlock "${nodeName}.kes-${nextKESnumber}.vkey"; rm -f "${nodeName}.kes-${nextKESnumber}.vkey"; exit 1; fi #abort and remove the vkey/counter files
                        while [[ $(is_strong_password "${pass_1}") != "true" ]]; do
                                echo -e "\n\e[35mThis is not a strong password, lets try it again...\e[0m\n"
                                pass_1=$(ask_pass "\e[33mEnter a strong Password for the KES-SKEY (empty to abort)")
                                if [[ ${pass_1} == "" ]]; then echo -e "\n\e[35mAborted\e[0m\n\n"; file_unlock "${nodeName}.kes-${nextKESnumber}.vkey"; rm -f "${nodeName}.kes-${nextKESnumber}.vkey"; exit 1; fi #abort and remove the vkey/counter files
                        done
                        echo -e "\e[0m";

                        #Confirm the password
                        pass_2=$(ask_pass "\e[33mConfirm the strong Password (empty to abort)")
                        if [[ ${pass_2} == "" ]]; then echo -e "\n\e[35mAborted\e[0m\n\n"; exit 1; fi
                        while [[ $(is_strong_password "${pass_2}") != "true" ]]; do
                                echo -e "\n\e[35mThis is not a strong password, lets try it again...\e[0m\n"
                                pass_2=$(ask_pass "\e[33mConfirm the strong Password (empty to abort)")
                                if [[ ${pass_2} == "" ]]; then echo -e "\n\e[35mAborted\e[0m\n\n"; exit 1; fi
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

        echo -ne "\e[0mWriting the file '\e[32m${nodeName}.kes-${nextKESnumber}.skey\e[0m' to disc ... "
        file_unlock "${nodeName}.kes-${nextKESnumber}.skey"
        echo "${encrJSON}" > "${nodeName}.kes-${nextKESnumber}.skey"
        if [ $? -ne 0 ]; then echo -e "\n\n\e[35mERROR, could not write to file!\n\n\e[0m"; exit 1; fi
        file_lock "${nodeName}.kes-${nextKESnumber}.skey"
        echo -e "\e[32mOK\e[0m\n"

	trap - SIGINT INT

else
	echo "You should not land here, this is for the future."; exit 1
fi

echo -e "\e[0mNode operational KES-Signing-Key:\e[32m ${nodeName}.kes-${nextKESnumber}.skey \e[90m"
cat "${nodeName}.kes-${nextKESnumber}.skey"
echo

file_unlock "${nodeName}.kes.counter"
echo ${nextKESnumber} > "${nodeName}.kes.counter"
file_lock "${nodeName}.kes.counter"
echo -e "\e[0mUpdated KES-Counter:\e[32m ${nodeName}.kes.counter \e[90m"
cat "${nodeName}.kes.counter"
echo

echo -e "\e[0m\n"


