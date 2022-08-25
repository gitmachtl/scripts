#!/bin/bash

# Script is brought to you by ATADA Stakepool, Telegram @atada_stakepool

#load variables and functions from common.sh
. "$(dirname "$0")"/00_common.sh


#Check command line parameter
if [ $# -lt 2 ] || [[ ! ${2^^} =~ ^(CLI|ENC|HW)$ ]]; then
cat >&2 <<EOF
ERROR - Usage: $(basename $0) <PolicyName> <KeyType: cli | enc | hw> [Optional valid xxx Slots, Policy invalid after xxx Slots (default=unlimited)]

Examples:
$(basename $0) assets/mypolicy cli      ... generates an unlimited Policy with CLI keys (was default method before)
$(basename $0) assets/mypolicy cli 600  ... This would generate CLI-Key Policy 'mypolicy' in the folder 'assets' limited to 600 Slots (600 Seconds) from now.
                                             No Token minting or burning would be possible after that time, starting now!
$(basename $0) assets/mypolicy enc      ... generates an unlimited Policy with CLI keys, but encrypted with a Password


Optional with Hardware-Ledger:
$(basename $0) myhwpolicy hw            ... generates an unlimited Policy with the keys on the HW-Wallet with the name 'myhwpolicy'
$(basename $0) myhwpolicy hw 300        ... generates a limited Policy (300 Seconds from now) with the keys on the HW-Wallet (useful for NFTs!)
EOF
exit 1;
else
policyName=$1;
keyType=$2;
if [[ $# -eq 3 && $3 -gt 0 ]]; then validBefore=$(( $(get_currentTip) + ${3} )); else validBefore="unlimited"; fi
fi

#trap to delete the produced files if aborted via CTRL+C(INT) or SIGINT
terminate(){
        echo -e "... doing cleanup ... \e[0m"
	file_unlock "${policyName}.policy.vkey"
	rm -f "${policyName}.policy.vkey" 2> /dev/null
	file_unlock "${policyName}.policy.skey"
	rm -f "${policyName}.policy.skey" 2> /dev/null
        exit 1
}


#warnings
if [ -f "${policyName}.policy.vkey" ]; then echo -e "\e[35mWARNING - ${policyName}.policy.vkey already present, delete it or use another name !\e[0m"; exit 2; fi
if [[ -f "${policyName}.policy.skey" || -f "${policyName}.policy.hwsfile" ]]; then echo -e "\e[35mWARNING - ${policyName}.policy.skey/hwsfile already present, delete it or use another name !\e[0m"; exit 2; fi
if [ -f "${policyName}.policy.script" ]; then echo -e "\e[35mWARNING - ${policyName}.policy.script already present, delete it or use another name !\e[0m"; exit 2; fi
if [ -f "${policyName}.policy.id" ]; then echo -e "\e[35mWARNING - ${policyName}.policy.id already present, delete it or use another name !\e[0m"; exit 2; fi

#Check if the destination directory for the policy exists, if not, try to make it
policyDirName="$(dirname ${policyName})"; policyDirName=${policyDirName/#.\//};
if [ ! -d "${policyDirName}" ]; then mkdir -p ${policyDirName}; checkError "$?"; fi


if [[ ${keyType^^} == "CLI" ]]; then #Building it from the cli (unencrypted)

	${cardanocli} address key-gen --verification-key-file "${policyName}.policy.vkey" --signing-key-file "${policyName}.policy.skey"
	checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
	file_lock "${policyName}.policy.vkey"
	file_lock "${policyName}.policy.skey"

	echo -e "\e[0mPolicy-Verification-Key: \e[32m ${policyName}.policy.vkey \e[90m"
	cat "${policyName}.policy.vkey" | jq
	echo
	echo -e "\e[0mPolicy-Signing-Key: \e[32m ${policyName}.policy.skey \e[90m"
	cat "${policyName}.policy.skey" | jq
	echo


elif [[ ${keyType^^} == "ENC" ]]; then #Building it from the cli (encrypted)

        skeyJSON=$(${cardanocli} address key-gen --verification-key-file "${policyName}.policy.vkey" --signing-key-file /dev/stdout 2> /dev/null)
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
        file_lock "${policyName}.policy.vkey"

	echo -e "\e[0mPolicy-Verification-Key: \e[32m ${policyName}.policy.vkey \e[90m"
	cat "${policyName}.policy.vkey" | jq
        echo

        trap terminate SIGINT INT

        #Loop until we have two matching passwords
        pass_1="x"; pass_2="y"; #start with unmatched passwords
        while [[ "${pass_1}" != "${pass_2}" ]]; do

                        #Read in the password
                        echo -e "\e[0mPlease provide a strong password (min. 10 chars, uppercase, lowercase, specialchars) for the encryption ...\n";
                        pass_1=$(ask_pass "\e[33mEnter a strong Password for the POLICY-SKEY (empty to abort)")
                        if [[ ${pass_1} == "" ]]; then echo -e "\n\e[35mAborted\e[0m\n\n"; file_unlock "${policyName}.policy.vkey"; rm -f "${policyName}.policy.vkey"; exit 1; fi #abort and remove the vkey file
                        while [[ $(is_strong_password "${pass_1}") != "true" ]]; do
                                echo -e "\n\e[35mThis is not a strong password, lets try it again...\e[0m\n"
                                pass_1=$(ask_pass "\e[33mEnter a strong Password for the POLICY-SKEY (empty to abort)")
                                if [[ ${pass_1} == "" ]]; then echo -e "\n\e[35mAborted\e[0m\n\n"; file_unlock "${policyName}.policy.vkey"; rm -f "${policyName}.policy.vkey"; exit 1; fi #abort and remove the vkey file
                        done
                        echo -e "\e[0m";

                        #Confirm the password
                        pass_2=$(ask_pass "\e[33mConfirm the strong Password (empty to abort)")
                        if [[ ${pass_2} == "" ]]; then echo -e "\n\e[35mAborted\e[0m\n\n"; file_unlock "${policyName}.policy.vkey"; rm -f "${policyName}.policy.vkey"; exit 1; fi #abort and remove the vkey file
                        while [[ $(is_strong_password "${pass_2}") != "true" ]]; do
                                echo -e "\n\e[35mThis is not a strong password, lets try it again...\e[0m\n"
                                pass_2=$(ask_pass "\e[33mConfirm the strong Password (empty to abort)")
                                if [[ ${pass_2} == "" ]]; then echo -e "\n\e[35mAborted\e[0m\n\n"; file_unlock "${policyName}.policy.vkey"; rm -f "${policyName}.policy.vkey"; exit 1; fi #abort and remove the vkey file
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

        echo -ne "\e[0mWriting the file '\e[32m${policyName}.policy.skey\e[0m' to disc ... "
        file_unlock "${policyName}.policy.skey"
        echo "${encrJSON}" > "${policyName}.policy.skey"
        if [ $? -ne 0 ]; then echo -e "\n\n\e[35mERROR, could not write to file!\n\n\e[0m"; exit 1; fi
        file_lock "${policyName}.policy.skey"
        echo -e "\e[32mOK\e[0m\n"

	trap - SIGINT INT

	echo -e "\e[0mPolicy-Signing-Key: \e[32m ${policyName}.policy.skey \e[90m"
	cat "${policyName}.policy.skey" | jq
	echo


else #Building it from hw


        #We need a hw minting keypair with vkey and hwsfile from a Hardware-Key, so lets' create them
	echo -e "\e[0mGenerating the Policy Keys via the HW-Wallet GUI ... \n"
        start_HwWallet; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
        tmp=$(${cardanohwcli} address key-gen --path 1855H/1815H/0H --verification-key-file ${policyName}.policy.vkey --hw-signing-file ${policyName}.policy.hwsfile 2> /dev/stdout)
        if [[ "${tmp^^}" =~ (ERROR|DISCONNECT) ]]; then echo -e "\e[35m${tmp}\e[0m\n"; exit 1; else echo -e "\e[32mDONE\e[0m\n"; fi
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

        #Edit the description in the vkey file to mark this as a hardware verification key
        vkeyJSON=$(cat ${policyName}.policy.vkey | jq ".description = \"Mint Hardware Verification Key\" ")
        echo "${vkeyJSON}" > ${policyName}.policy.vkey
        file_lock ${policyName}.policy.vkey
        file_lock ${policyName}.policy.hwsfile

        echo -e "\e[0mHardware-Policy-Verification-Key: \e[32m ${policyName}.policy.vkey \e[90m"
        cat ${policyName}.policy.vkey | jq
        echo
        echo -e "\e[0mHardware-Policy-Signing-File: \e[32m ${policyName}.policy.hwsfile \e[90m"
        cat ${policyName}.policy.hwsfile | jq
        echo


fi

policyKeyHASH=$(${cardanocli} address key-hash --payment-verification-key-file ${policyName}.policy.vkey)
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi


currentTip=$(get_currentTip)
echo -e "\e[0mCurrent Slot-Height:\e[32m ${currentTip} \e[0m"
echo -e "\e[0mPolicy invalid after Slot-Height:\e[33m ${validBefore}\e[0m"
echo

#Write out an unlimited SigningScript or a limited one
if [[ "${validBefore}" == "unlimited" ]]; then
					  echo "{ \"keyHash\": \"${policyKeyHASH}\", \"type\": \"sig\" }" > ${policyName}.policy.script
					  else
					  echo "{ \"type\": \"all\", \"scripts\": [ { \"slot\": ${validBefore}, \"type\": \"before\" }, { \"keyHash\": \"${policyKeyHASH}\", \"type\": \"sig\" } ] }" > ${policyName}.policy.script
fi
echo -e "\e[0mPolicy-Script: \e[32m ${policyName}.policy.script \e[90m"
file_lock ${policyName}.policy.script
cat ${policyName}.policy.script | jq
echo

if [[ "${keyType^^}" == "CLI" || "${keyType^^}" == "ENC" ]]; then #generate the policyID via cli command
				policyID=$(${cardanocli} transaction policyid --script-file ${policyName}.policy.script)
				else #show it via the hw-wallet. not really needed but a nice feature to also show the invalid hereafter value if present
				echo -e "\e[0mGeneration the PolicyID via the HW-Wallet GUI ... \n"
				start_HwWallet; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
				tmp=$(${cardanohwcli} transaction policyid --script-file ${policyName}.policy.script --hw-signing-file ${policyName}.policy.hwsfile 2> /dev/stdout)
				if [[ "${tmp^^}" =~ (ERROR|DISCONNECT) ]]; then echo -e "\e[35m${tmp}\e[0m\n"; exit 1; else echo -e "\e[32mDONE\e[0m\n"; fi
				checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
				policyID=${tmp}
fi

echo -e "${policyID}" > ${policyName}.policy.id
echo -e "\e[0mPolicy-ID: \e[32m ${policyName}.policy.id \e[90m"
file_lock ${policyName}.policy.id
cat ${policyName}.policy.id
echo

echo -e "\e[0m\n"

