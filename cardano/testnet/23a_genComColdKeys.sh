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
if [ $# -lt 2 ] || [[ ! ${2^^} =~ ^(CLI|HW|ENC|MNEMONICS)$ ]]; then
cat >&2 <<EOF
ERROR - Usage: $(basename $0) <CommitteeName> <KeyType: cli | enc | hw | mnemonics>

Optional parameters:

   ["Idx: 0-2147483647"] Sets the IndexNo of the DerivationPath for HW-Keys and CLI-Mnemonics: 1852H/1815H/*H/4/<IndexNo> (default: 0)
   ["Acc: 0-2147483647"] Sets the AccountNo of the DerivationPath for HW-Keys and CLI-Mnemonics: 1852H/1815H/<AccountNo>H/4/* (default: 0)
   ["Mnemonics: 24-words-mnemonics"] To provide a given set of 24 mnemonic words to derive the CLI-Mnemonics keys, otherwise new ones will be generated.

Examples:
$(basename $0) myCom cli             ... generates committee COLD keys (no mnemonic/passphrase support)
$(basename $0) myCom enc             ... generates committee COLD keys + encrypted via a Password
$(basename $0) myCom hw              ... generates committee COLD keys using Ledger/Trezor HW-Wallet (Normal-Path 1852H/1815H/<Acc>/4/<Idx>)
$(basename $0) myCom mnemonics       ... generates committee COLD keys and also generate Mnemonics for LightWallet import possibilities

Examples with Mnemonics:
$(basename $0) myCom mnemonics "mnemonics: word1 word2 ... word24"  ... generates committee COLD keys from the given 24 Mnemonic words (Path 1852H/1815H/<Acc>/4/<Idx>)
$(basename $0) myCom mnemonics "acc:4" "idx:5"  ... generates committee COLD keys and new Mnemonics for the path 1852H/1815H/H4/4/5

Example with Hardware-Account/Index-Numbers:
$(basename $0) myCom hw "acc:1"        ... generates committee COLD keys using Ledger/Trezor HW-Keys and SubAccount# 1, Index# 0

EOF
exit 1;
else

	#exit with an information, that the script needs at least conway era
	case ${cliEra} in
	        "babbage"|"alonzo"|"mary"|"allegra"|"shelley")
	                echo -e "\n\e[91mINFORMATION - The chain is not in conway era yet. This script will start to work once we forked into conway era. Please check back later!\n\e[0m"; exit;
	                ;;
	esac

	#Set the comColdName and the choosen keyType
	comColdName="$(dirname $1.hash)/$(basename $1 .hash)"; comColdName=${comColdName/#.\//};
	keyType=${2^^};

	#set default values for the derivation path accountNumber and indexNumber
	accNo=0;
	idxNo=0;
	mnemonics="";

	#Check all optional parameters about there types and set the corresponding variables
	#Starting with the 3th parameter (index=2) up to the last parameter
	paramCnt=$#;
	allParameters=( "$@" )
	for (( tmpCnt=2; tmpCnt<${paramCnt}; tmpCnt++ ))
	do
        	paramValue=${allParameters[$tmpCnt]}

		#Check if its an accountNo parameter
	        if [[ "${paramValue,,}" =~ ^acc:(.*)$ ]]; then
	                accNo=$(trimString "${paramValue:4}");
			if [ "${accNo}" == null ] || [ -z "${accNo##*[!0-9]*}" ] || [ $(bc <<< "${accNo} < 0") -eq 1 ] || [ $(bc <<< "${accNo} > 2147483647") -eq 1 ]; then echo -e "\e[35mERROR - Account# is out of range (0-2147483647)!\e[0m"; exit 1; fi

		#Check if its an indexNo parameter
	        elif [[ "${paramValue,,}" =~ ^idx:(.*)$ ]]; then
                	idxNo=$(trimString "${paramValue:4}");
			if [ "${idxNo}" == null ] || [ -z "${idxNo##*[!0-9]*}" ] || [ $(bc <<< "${idxNo} < 0") -eq 1 ] || [ $(bc <<< "${idxNo} > 2147483647") -eq 1 ]; then echo -e "\e[35mERROR - Account# is out of range (0-2147483647)!\e[0m"; exit 1; fi

	        #Check if mnemonics are provided
	        elif [[ "${paramValue,,}" =~ ^mnemonics:(.*)$ ]]; then #if the parameter starts with "enc:" then set the encryption variable
                	mnemonics=$(trimString "${paramValue:10}");
			mnemonics=$(tr -s ' ' <<< ${mnemonics,,}) #convert to lowercase and remove multispaces between words
			mnemonicsWordcount=$(wc -w <<< ${mnemonics})
			if [[ ${mnemonicsWordcount} -ne 24 ]]; then echo -e "\e[35mERROR - Please provide 24 mnemonic words and not ${mnemonicsWordcount} words. The words must be space separated.\e[0m\n"; exit 1; fi

	        fi #end of different parameters check
	done

fi


#trap to delete the produced files if aborted via CTRL+C(INT) or SIGINT
terminate(){
        echo -e "... doing cleanup ... \e[0m"
	file_unlock "${comColdName}.cc-cold.vkey"
	rm -f "${comColdName}.cc-cold.vkey" 2> /dev/null
	file_unlock "${comColdName}.cc-cold.skey"
	rm -f "${comColdName}.cc-cold.vkey" 2> /dev/null
	file_unlock "${comColdName}.cc-cold.hash"
	rm -f "${comColdName}.cc-cold.hash" 2> /dev/null
	file_unlock "${comColdName}.cc-cold.mnemonics"
	rm -f "${comColdName}.cc-cold.mnemonics" 2> /dev/null
        exit 1
}


#warnings
if [ -f "${comColdName}.cc-cold.vkey" ]; then echo -e "\e[35mWARNING - ${comColdName}.cc-cold.vkey already present, delete it or use another name !\e[0m"; exit 2; fi
if [[ -f "${comColdName}.cc-cold.skey" ||  -f "${comColdName}.cc-cold.hwsfile" ]]; then echo -e "\e[35mWARNING - ${comColdName}.cc-cold.skey/hwsfile already present, delete it or use another name. Only one instance allowed !\e[0m"; exit 2; fi
if [ -f "${comColdName}.cc-cold.hash" ]; then echo -e "\e[35mWARNING - ${comColdName}.cc-cold.hash already present, delete it or use another name !\e[0m"; exit 2; fi


##############################
#### Building the Committee Cold Keys
##############################

if [[ "${keyType}" == "CLI" ]]; then #Committee Cold Keys via CLI (unencrypted)

	#We need a normal Committee Cold keypair with vkey and skey, so let's create that one
	${cardanocli} ${cliEra} governance committee key-gen-cold --cold-verification-key-file "${comColdName}.cc-cold.vkey" --cold-signing-key-file "${comColdName}.cc-cold.skey"
	checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
	file_lock ${comColdName}.cc-cold.vkey
	file_lock ${comColdName}.cc-cold.skey
	echo -e "\e[0mCommittee Cold-Verification-Key: \e[32m ${comColdName}.cc-cold.vkey \e[90m"
	cat ${comColdName}.cc-cold.vkey
	echo
	echo -e "\e[0mCommittee Cold-Signing-Key: \e[32m ${comColdName}.cc-cold.skey \e[90m"
	cat ${comColdName}.cc-cold.skey
	echo



elif [[ "${keyType}" == "MNEMONICS" ]]; then #Committee Cold Keys via Mnemonics (unencrypted)

	#Check warnings
	if [ -f "${comColdName}.cc-cold.mnemonics" ]; then echo -e "\e[35mWARNING - ${comColdName}.cc-cold.mnemonics already present, delete it or use another name !\e[0m"; exit 1; fi

	echo
	echo -e "\e[0mGenerating CLI Committee Cold-Keys via Derivation-Path:\e[32m 1852H/1815H/${accNo}H/4/${idxNo}\e[0m"
	echo

	#Check the cardano-signer binary existance and version
	if ! exists "${cardanosigner}"; then
	#Try the one in the scripts folder
	if [[ -f "${scriptDir}/cardano-signer" ]]; then cardanosigner="${scriptDir}/cardano-signer";
	else majorError "Path ERROR - Path to the 'cardano-signer' binary is not correct or 'cardano-singer' binaryfile is missing!\nYou can find it here: https://github.com/gitmachtl/cardano-signer/releases\nThis is needed to generate the signed Metadata. Also please check your 00_common.sh or common.inc settings."; exit 1; fi
	fi
	cardanosignerCheck=$(${cardanosigner} --version 2> /dev/null)
	if [[ $? -ne 0 ]]; then echo -e "\e[35mERROR - This script needs a working 'cardano-signer' binary. Please make sure you have it present with with the right path in '00_common.sh' !\e[0m\n\n"; exit 1; fi
	cardanosignerVersion=$(echo ${cardanosignerCheck} | cut -d' ' -f 2)
	versionCheck "${minCardanoSignerVersion}" "${cardanosignerVersion}"
	if [[ $? -ne 0 ]]; then majorError "Version ${cardanosignerVersion} ERROR - Please use a cardano-signer version ${minCardanoSignerVersion} or higher !\nOld versions are not compatible, please upgrade - thx."; exit 1; fi

	echo -e "\e[0mUsing Cardano-Signer Version: \e[32m${cardanosignerVersion}\e[0m\n";

	if [[ ${mnemonics} != "" ]]; then #use the provided mnemonics
		echo -e "\e[0mUsing Mnemonics:\e[32m ${mnemonics}\e[0m"
		#Generate the Files with given mnemonics
		signerJSON=$(${cardanosigner} keygen --path "1852H/1815H/${accNo}H/4/${idxNo}" --mnemonics "${mnemonics}" --json-extended --out-vkey "${comColdName}.cc-cold.vkey" --out-skey "${comColdName}.cc-cold.skey" 2> /dev/stdout)
	        if [ $? -ne 0 ]; then echo -e "\e[35mERROR - ${signerJSON}\e[0m\n\n"; exit 1; fi
        else
                #Generate the Files and read the mnemonics
		signerJSON=$(${cardanosigner} keygen --path "1852H/1815H/${accNo}H/4/${idxNo}" --json-extended --out-vkey "${comColdName}.cc-cold.vkey" --out-skey "${comColdName}.cc-cold.skey" 2> /dev/stdout)
	        if [ $? -ne 0 ]; then echo -e "\e[35mERROR - ${signerJSON}\e[0m\n\n"; exit 1; fi
		mnemonics=$(jq -r ".mnemonics" <<< ${signerJSON} 2> /dev/null)
		checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
		echo -e "\e[0mCreated Mnemonics:\e[32m ${mnemonics}\e[0m"

        fi
	echo -e "${mnemonics}" > "${comColdName}.cc-cold.mnemonics"
        if [ $? -ne 0 ]; then
		echo -e "\e[35mERROR - Couldn't write file '${comColdName}.cc-cold.mnemonics'\e[0m\n\n"; exit 1;
	else
		echo -e "\e[0mMnemonics written to file:\e[32m ${comColdName}.cc-cold.mnemonics\e[0m"
	fi
	echo

	file_lock ${comColdName}.cc-cold.mnemonics
	file_lock ${comColdName}.cc-cold.vkey
	file_lock ${comColdName}.cc-cold.skey

        echo -e "\e[0mCommittee Cold-Verification-Key (Acc# ${accNo}, Idx# ${idxNo}): \e[32m ${comColdName}.cc-cold.vkey \e[90m"
        cat ${comColdName}.cc-cold.vkey
        echo
        echo -e "\e[0mCommittee Cold-Signing-Key (Acc# ${accNo}, Idx# ${idxNo}): \e[32m ${comColdName}.cc-cold.skey \e[90m"
        cat ${comColdName}.cc-cold.skey
        echo


elif [[ "${keyType}" == "ENC" ]]; then #Committee Cold Keys via CLI (encrypted)

	#We need a normal Committee Cold keypair with vkey and skey, so let's create that one
        skeyJSON=$(${cardanocli} ${cliEra} governance committee key-gen-cold --cold-verification-key-file "${comColdName}.cc-cold.vkey" --cold-signing-key-file /dev/stdout 2> /dev/null)
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
        file_lock ${comColdName}.cc-cold.vkey

        echo -e "\e[0mCommittee Cold-Verification-Key: \e[32m ${comColdName}.cc-cold.vkey \e[90m"
        cat ${comColdName}.cc-cold.vkey
        echo

	trap terminate SIGINT INT

        #Loop until we have two matching passwords
        pass_1="x"; pass_2="y"; #start with unmatched passwords
        while [[ "${pass_1}" != "${pass_2}" ]]; do

                        #Read in the password
                        echo -e "\e[0mPlease provide a strong password (min. 10 chars, uppercase, lowercase, specialchars) for the encryption ...\n";
                        pass_1=$(ask_pass "\e[33mEnter a strong Password for the Committee Cold-SKEY (empty to abort)")
                        if [[ ${pass_1} == "" ]]; then echo -e "\n\e[35mAborted\e[0m\n\n"; file_unlock "${comColdName}.cc-cold.vkey"; rm -f "${comColdName}.cc-cold.vkey"; exit 1; fi #abort and remove the vkey file
                        while [[ $(is_strong_password "${pass_1}") != "true" ]]; do
                                echo -e "\n\e[35mThis is not a strong password, lets try it again...\e[0m\n"
                                pass_1=$(ask_pass "\e[33mEnter a strong Password for the Committee Cold-SKEY (empty to abort)")
                                if [[ ${pass_1} == "" ]]; then echo -e "\n\e[35mAborted\e[0m\n\n"; file_unlock "${comColdName}.cc-cold.vkey"; rm -f "${comColdName}.cc-cold.vkey"; exit 1; fi #abort and remove the vkey file
                        done
                        echo -e "\e[0m";

                        #Confirm the password
                        pass_2=$(ask_pass "\e[33mConfirm the strong Password (empty to abort)")
                        if [[ ${pass_2} == "" ]]; then echo -e "\n\e[35mAborted\e[0m\n\n"; file_unlock "${comColdName}.cc-cold.vkey"; rm -f "${comColdName}.cc-cold.vkey"; exit 1; fi #abort and remove the vkey file
                        while [[ $(is_strong_password "${pass_2}") != "true" ]]; do
                                echo -e "\n\e[35mThis is not a strong password, lets try it again...\e[0m\n"
                                pass_2=$(ask_pass "\e[33mConfirm the strong Password (empty to abort)")
	                        if [[ ${pass_2} == "" ]]; then echo -e "\n\e[35mAborted\e[0m\n\n"; file_unlock "${comColdName}.cc-cold.vkey"; rm -f "${comColdName}.cc-cold.vkey"; exit 1; fi #abort and remove the vkey file
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

        echo -ne "\e[0mWriting the file '\e[32m${comColdName}.cc-cold.skey\e[0m' to disc ... "
        file_unlock "${comColdName}.cc-cold.skey"
        echo "${encrJSON}" > "${comColdName}.cc-cold.skey"
        if [ $? -ne 0 ]; then echo -e "\n\n\e[35mERROR, could not write to file!\n\n\e[0m"; exit 1; fi
        file_lock "${comColdName}.cc-cold.skey"
        echo -e "\e[32mOK\e[0m\n"

	trap - SIGINT INT

	echo -e "\e[0mCommittee Cold-Signing-Key: \e[32m ${comColdName}.cc-cold.skey \e[90m"
	cat ${comColdName}.cc-cold.skey
	echo

else  #Committee Cold Keys via HW-Wallet

	echo -e "\e[0mGenerating HW-Committee Cold Keys via Derivation-Path:\e[32m 1852H/1815H/${accNo}H/4/${idxNo}\e[0m"
	echo

	#We need a Committee Cold keypair with vkey and hwsfile from a Hardware-Key, sol lets create them
	#ONLY LEDGER HW WALLET SUPPORTS THIS ACTION
        start_HwWallet "Ledger"; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
  	tmp=$(${cardanohwcli} address key-gen --path 1852H/1815H/${accNo}H/4/${idxNo} --verification-key-file ${comColdName}.cc-cold.vkey --hw-signing-file ${comColdName}.cc-cold.hwsfile 2> /dev/stdout)
        if [[ "${tmp^^}" =~ (ERROR|DISCONNECT) ]]; then echo -e "\e[35m${tmp}\e[0m\n"; exit 1; else echo -e "\e[32mDONE\e[0m\n"; fi
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

#	#Edit the type+description in the vkey file temporary
#	vkeyJSON=$(cat ${comColdName}.cc-cold.vkey | jq ".type = \"Committee ColdVerificationKey_ed25519\" " | jq ".description = \"Hardware Delegate Representative Verification Key\" ")
#	echo "${vkeyJSON}" > ${comColdName}.cc-cold.vkey
#	#Edit the type+description in the hwsfile file temporary
#	hwsfileJSON=$(cat ${comColdName}.cc-cold.hwsfile | jq ".type = \"Committee ColdHWSigningFile_ed25519\" " | jq ".description = \"Hardware Delegate Representative Signing Key\" ")
#	echo "${hwsfileJSON}" > ${comColdName}.cc-cold.hwsfile

        file_lock ${comColdName}.cc-cold.vkey
        file_lock ${comColdName}.cc-cold.hwsfile

        echo -e "\e[0mCommittee Cold-Verification-Key (Acc# ${accNo}, Idx# ${idxNo}): \e[32m ${comColdName}.cc-cold.vkey \e[90m"
        cat ${comColdName}.cc-cold.vkey
        echo
        echo -e "\e[0mCommittee Cold-HardwareSigning-File (Acc# ${accNo}, Idx# ${idxNo}): \e[32m ${comColdName}.cc-cold.hwsfile \e[90m"
        cat ${comColdName}.cc-cold.hwsfile
        echo

fi

#Building the Committee Cold HASH
${cardanocli} ${cliEra} governance committee key-hash --verification-key-file "${comColdName}.cc-cold.vkey" > "${comColdName}.cc-cold.hash"
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
file_lock "${comColdName}.cc-cold.hash"

echo -e "\e[0mCommittee Cold-HASH built: \e[32m ${comColdName}.cc-cold.hash \e[90m"
cat "${comColdName}.cc-cold.hash"
echo

echo
echo -e "\e[35mPlease now generate Committee Hot Keys, run the script 23b_genComHotKeys.sh !\e[0m"
echo


