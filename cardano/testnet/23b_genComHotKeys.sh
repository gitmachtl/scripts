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

   ["Idx: 0-2147483647"] Sets the IndexNo of the DerivationPath for HW-Keys and CLI-Mnemonics: 1852H/1815H/*H/5/<IndexNo> (default: 0)
   ["Acc: 0-2147483647"] Sets the AccountNo of the DerivationPath for HW-Keys and CLI-Mnemonics: 1852H/1815H/<AccountNo>H/5/* (default: 0)
   ["Mnemonics: 24-words-mnemonics"] To provide a given set of 24 mnemonic words to derive the CLI-Mnemonics keys, otherwise new ones will be generated.

Examples:
$(basename $0) myCom cli             ... generates committee HOT keys (no mnemonic/passphrase support)
$(basename $0) myCom enc             ... generates committee HOT keys + encrypted via a Password
$(basename $0) myCom hw              ... generates committee HOT keys using Ledger/Trezor HW-Wallet (Normal-Path 1852H/1815H/<Acc>/5/<Idx>)
$(basename $0) myCom mnemonics       ... generates committee HOT keys and also generate Mnemonics for LightWallet import possibilities

Examples with Mnemonics:
$(basename $0) myCom mnemonics "mnemonics: word1 word2 ... word24"  ... generates committee HOT keys from the given 24 Mnemonic words (Path 1852H/1815H/<Acc>/5/<Idx>)
$(basename $0) myCom mnemonics "acc:4" "idx:5"  ... generates committee HOT keys and new Mnemonics for the path 1852H/1815H/H4/5/5

Example with Hardware-Account/Index-Numbers:
$(basename $0) myCom hw "acc:1"        ... generates committee HOT keys using Ledger/Trezor HW-Keys and SubAccount# 1, Index# 0

EOF
exit 1;
else

	#exit with an information, that the script needs at least conway era
	case ${cliEra} in
	        "babbage"|"alonzo"|"mary"|"allegra"|"shelley")
	                echo -e "\n\e[91mINFORMATION - The chain is not in conway era yet. This script will start to work once we forked into conway era. Please check back later!\n\e[0m"; exit;
	                ;;
	esac

	#Set the comHotName and the choosen keyType
	comHotName="$(dirname $1.hash)/$(basename $1 .hash)"; comHotName=${comHotName/#.\//};
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
	file_unlock "${comHotName}.cc-hot.vkey"
	rm -f "${comHotName}.cc-hot.vkey" 2> /dev/null
	file_unlock "${comHotName}.cc-hot.skey"
	rm -f "${comHotName}.cc-hot.vkey" 2> /dev/null
	file_unlock "${comHotName}.cc-hot.hash"
	rm -f "${comHotName}.cc-hot.hash" 2> /dev/null
	file_unlock "${comHotName}.cc-hot.mnemonics"
	rm -f "${comHotName}.cc-hot.mnemonics" 2> /dev/null
        exit 1
}

#warning if hot-keys already present with that name
if [[ -f "${comHotName}.cc-hot.vkey" || -f "${comHotName}.cc-hot.skey" || -f "${comHotName}.cc-hot.hwsfile" || -f "${comHotName}.cc-hot.hash" ]]; then

	if ask "\n\e[33mWARNING - There are already Committee-Hot-Keys with the name '${comHotName}' present, do you wanna delete them and generate new ones ?" N; then
	        echo -ne "\n\e[0mDeleting '\e[32m${comHotName}.cc-hot.vkey/skey/hwsfile/hash/mnemonics\e[0m' files ... "
		file_unlock "${comHotName}.cc-hot.vkey"
		rm -f "${comHotName}.cc-hot.vkey" 2> /dev/null
		file_unlock "${comHotName}.cc-hot.skey"
		rm -f "${comHotName}.cc-hot.vkey" 2> /dev/null
		file_unlock "${comHotName}.cc-hot.hwsfile"
		rm -f "${comHotName}.cc-hot.hwsfile" 2> /dev/null
		file_unlock "${comHotName}.cc-hot.hash"
		rm -f "${comHotName}.cc-hot.hash" 2> /dev/null
		file_unlock "${comHotName}.cc-hot.mnemonics"
		rm -f "${comHotName}.cc-hot.mnemonics" 2> /dev/null
		echo -e "\e[32mDONE\e[0m\n"
	else
		echo -e "\e[0m";
		exit 1;
	fi #ask

fi #warning



##############################
#### Building the Committee Hot Keys
##############################

if [[ "${keyType}" == "CLI" ]]; then #Committee Hot Keys via CLI (unencrypted)

	#We need a normal Committee Hot keypair with vkey and skey, so let's create that one
	${cardanocli} ${cliEra} governance committee key-gen-hot --verification-key-file "${comHotName}.cc-hot.vkey" --signing-key-file "${comHotName}.cc-hot.skey"
	checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
	file_lock ${comHotName}.cc-hot.vkey
	file_lock ${comHotName}.cc-hot.skey
	echo -e "\e[0mCommittee Hot-Verification-Key: \e[32m ${comHotName}.cc-hot.vkey \e[90m"
	cat ${comHotName}.cc-hot.vkey
	echo
	echo -e "\e[0mCommittee Hot-Signing-Key: \e[32m ${comHotName}.cc-hot.skey \e[90m"
	cat ${comHotName}.cc-hot.skey
	echo



elif [[ "${keyType}" == "MNEMONICS" ]]; then #Committee Hot Keys via Mnemonics (unencrypted)

	#Check warnings
	if [ -f "${comHotName}.cc-hot.mnemonics" ]; then echo -e "\e[35mWARNING - ${comHotName}.cc-hot.mnemonics already present, delete it or use another name !\e[0m"; exit 1; fi

	echo
	echo -e "\e[0mGenerating CLI Committee Hot-Keys via Derivation-Path:\e[32m 1852H/1815H/${accNo}H/5/${idxNo}\e[0m"
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
		signerJSON=$(${cardanosigner} keygen --path "1852H/1815H/${accNo}H/5/${idxNo}" --mnemonics "${mnemonics}" --json-extended --out-vkey "${comHotName}.cc-hot.vkey" --out-skey "${comHotName}.cc-hot.skey" 2> /dev/stdout)
	        if [ $? -ne 0 ]; then echo -e "\e[35mERROR - ${signerJSON}\e[0m\n\n"; exit 1; fi
        else
                #Generate the Files and read the mnemonics
		signerJSON=$(${cardanosigner} keygen --path "1852H/1815H/${accNo}H/5/${idxNo}" --json-extended --out-vkey "${comHotName}.cc-hot.vkey" --out-skey "${comHotName}.cc-hot.skey" 2> /dev/stdout)
	        if [ $? -ne 0 ]; then echo -e "\e[35mERROR - ${signerJSON}\e[0m\n\n"; exit 1; fi
		mnemonics=$(jq -r ".mnemonics" <<< ${signerJSON} 2> /dev/null)
		checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
		echo -e "\e[0mCreated Mnemonics:\e[32m ${mnemonics}\e[0m"

        fi
	echo -e "${mnemonics}" > "${comHotName}.cc-hot.mnemonics"
        if [ $? -ne 0 ]; then
		echo -e "\e[35mERROR - Couldn't write file '${comHotName}.cc-hot.mnemonics'\e[0m\n\n"; exit 1;
	else
		echo -e "\e[0mMnemonics written to file:\e[32m ${comHotName}.cc-hot.mnemonics\e[0m"
	fi
	echo

	file_lock ${comHotName}.cc-hot.mnemonics
	file_lock ${comHotName}.cc-hot.vkey
	file_lock ${comHotName}.cc-hot.skey

        echo -e "\e[0mCommittee Hot-Verification-Key (Acc# ${accNo}, Idx# ${idxNo}): \e[32m ${comHotName}.cc-hot.vkey \e[90m"
        cat ${comHotName}.cc-hot.vkey
        echo
        echo -e "\e[0mCommittee Hot-Signing-Key (Acc# ${accNo}, Idx# ${idxNo}): \e[32m ${comHotName}.cc-hot.skey \e[90m"
        cat ${comHotName}.cc-hot.skey
        echo


elif [[ "${keyType}" == "ENC" ]]; then #Committee Hot Keys via CLI (encrypted)

	#We need a normal Committee Hot keypair with vkey and skey, so let's create that one
        skeyJSON=$(${cardanocli} ${cliEra} governance committee key-gen-hot --verification-key-file "${comHotName}.cc-hot.vkey" --signing-key-file /dev/stdout 2> /dev/null)
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
        file_lock ${comHotName}.cc-hot.vkey

        echo -e "\e[0mCommittee Hot-Verification-Key: \e[32m ${comHotName}.cc-hot.vkey \e[90m"
        cat ${comHotName}.cc-hot.vkey
        echo

	trap terminate SIGINT INT

        #Loop until we have two matching passwords
        pass_1="x"; pass_2="y"; #start with unmatched passwords
        while [[ "${pass_1}" != "${pass_2}" ]]; do

                        #Read in the password
                        echo -e "\e[0mPlease provide a strong password (min. 10 chars, uppercase, lowercase, specialchars) for the encryption ...\n";
                        pass_1=$(ask_pass "\e[33mEnter a strong Password for the Committee Hot-SKEY (empty to abort)")
                        if [[ ${pass_1} == "" ]]; then echo -e "\n\e[35mAborted\e[0m\n\n"; file_unlock "${comHotName}.cc-hot.vkey"; rm -f "${comHotName}.cc-hot.vkey"; exit 1; fi #abort and remove the vkey file
                        while [[ $(is_strong_password "${pass_1}") != "true" ]]; do
                                echo -e "\n\e[35mThis is not a strong password, lets try it again...\e[0m\n"
                                pass_1=$(ask_pass "\e[33mEnter a strong Password for the Committee Hot-SKEY (empty to abort)")
                                if [[ ${pass_1} == "" ]]; then echo -e "\n\e[35mAborted\e[0m\n\n"; file_unlock "${comHotName}.cc-hot.vkey"; rm -f "${comHotName}.cc-hot.vkey"; exit 1; fi #abort and remove the vkey file
                        done
                        echo -e "\e[0m";

                        #Confirm the password
                        pass_2=$(ask_pass "\e[33mConfirm the strong Password (empty to abort)")
                        if [[ ${pass_2} == "" ]]; then echo -e "\n\e[35mAborted\e[0m\n\n"; file_unlock "${comHotName}.cc-hot.vkey"; rm -f "${comHotName}.cc-hot.vkey"; exit 1; fi #abort and remove the vkey file
                        while [[ $(is_strong_password "${pass_2}") != "true" ]]; do
                                echo -e "\n\e[35mThis is not a strong password, lets try it again...\e[0m\n"
                                pass_2=$(ask_pass "\e[33mConfirm the strong Password (empty to abort)")
	                        if [[ ${pass_2} == "" ]]; then echo -e "\n\e[35mAborted\e[0m\n\n"; file_unlock "${comHotName}.cc-hot.vkey"; rm -f "${comHotName}.cc-hot.vkey"; exit 1; fi #abort and remove the vkey file
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

        echo -ne "\e[0mWriting the file '\e[32m${comHotName}.cc-hot.skey\e[0m' to disc ... "
        file_unlock "${comHotName}.cc-hot.skey"
        echo "${encrJSON}" > "${comHotName}.cc-hot.skey"
        if [ $? -ne 0 ]; then echo -e "\n\n\e[35mERROR, could not write to file!\n\n\e[0m"; exit 1; fi
        file_lock "${comHotName}.cc-hot.skey"
        echo -e "\e[32mOK\e[0m\n"

	trap - SIGINT INT

	echo -e "\e[0mCommittee Hot-Signing-Key: \e[32m ${comHotName}.cc-hot.skey \e[90m"
	cat ${comHotName}.cc-hot.skey
	echo

else  #Committee Hot Keys via HW-Wallet

	echo -e "\e[0mGenerating HW-Committee Hot Keys via Derivation-Path:\e[32m 1852H/1815H/${accNo}H/5/${idxNo}\e[0m"
	echo

	#We need a Committee Hot keypair with vkey and hwsfile from a Hardware-Key, sol lets create them
	#ONLY LEDGER HW WALLET SUPPORTS THIS ACTION
        start_HwWallet "Ledger|Keystone"; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
  	tmp=$(${cardanohwcli} address key-gen --path 1852H/1815H/${accNo}H/5/${idxNo} --verification-key-file ${comHotName}.cc-hot.vkey --hw-signing-file ${comHotName}.cc-hot.hwsfile 2> /dev/stdout)
        if [[ "${tmp^^}" =~ (ERROR|DISCONNECT) ]]; then echo -e "\e[35m${tmp}\e[0m\n"; exit 1; else echo -e "\e[32mDONE\e[0m\n"; fi
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

	#Edit the type in the vkey file temporary
	vkeyJSON=$(cat ${comHotName}.cc-hot.vkey | jq ".type = \"ConstitutionalCommitteeHotVerificationKey_ed25519\"")
	echo "${vkeyJSON}" > ${comHotName}.cc-hot.vkey
	#Edit the type in the hwsfile file temporary
	hwsfileJSON=$(cat ${comHotName}.cc-hot.hwsfile | jq ".type = \"ConstitutionalCommitteeHotHWSigningFile_ed25519\"")
	echo "${hwsfileJSON}" > ${comHotName}.cc-hot.hwsfile

        file_lock ${comHotName}.cc-hot.vkey
        file_lock ${comHotName}.cc-hot.hwsfile

        echo -e "\e[0mCommittee Hot-Verification-Key (Acc# ${accNo}, Idx# ${idxNo}): \e[32m ${comHotName}.cc-hot.vkey \e[90m"
        cat ${comHotName}.cc-hot.vkey
        echo
	echo
        echo -e "\e[0mCommittee Hot-HardwareSigning-File (Acc# ${accNo}, Idx# ${idxNo}): \e[32m ${comHotName}.cc-hot.hwsfile \e[90m"
        cat ${comHotName}.cc-hot.hwsfile
        echo
	echo

fi

#Building the Committee Hot HASH
${cardanocli} ${cliEra} governance committee key-hash --verification-key-file "${comHotName}.cc-hot.vkey" > "${comHotName}.cc-hot.hash"
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
file_lock "${comHotName}.cc-hot.hash"

echo -e "\e[0mCommittee Hot-HASH built: \e[32m ${comHotName}.cc-hot.hash \e[90m"
cat "${comHotName}.cc-hot.hash"
echo

echo
echo -e "\e[35mIf you wanna register/authorize the new Committee Hot Keys on the chain, please run the script 23c_regComAuthCert.sh !\e[0m"
echo


