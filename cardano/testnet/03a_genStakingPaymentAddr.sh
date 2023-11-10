#!/bin/bash

# Script is brought to you by ATADA Stakepool, Telegram @atada_stakepool

#load variables and functions from common.sh
. "$(dirname "$0")"/00_common.sh


#Check command line parameter
if [ $# -lt 2 ] || [[ ! ${2^^} =~ ^(CLI|HW|HWMULTI|HYBRID|HYBRIDMULTI|ENC|HYBRIDENC|HYBRIDMULTIENC|MNEMONICS)$ ]]; then
cat >&2 <<EOF
ERROR - Usage: $(basename $0) <AddressName> <KeyType: cli | enc | hw | hwmulti | hybrid | hybridmulti | hybridenc | hybridmultienc | mnemonics>

Optional parameters:

   ["Idx: 0-2147483647"] Sets the IndexNo of the DerivationPath for HW-Keys and CLI-Mnemonics: 1852H/1815H/*H/*/IndexNo (default: 0)
   ["Acc: 0-2147483647"] Sets the AccountNo of the DerivationPath for HW-KEys and CLI-Mnemonics: 1852H/1815H/<AccountNo>H/*/* (default: 0)
   ["Mnemonics: 24-words-mnemonics"] To provide a given set of 24 mnemonic words to derive the CLI-Mnemonics keys, otherwise new ones will be generated.

Examples:
$(basename $0) owner cli             ... generates Payment & Staking keys via cli (this is the normal mode)
$(basename $0) owner enc             ... generates Payment & Staking keys via cli and encrypted via a Password
$(basename $0) owner hw              ... generates Payment & Staking keys using Ledger/Trezor HW-Keys (Normal-Path 1852H/1815H/<Acc>/0,2/<Idx>)
$(basename $0) owner hwmulti         ... generates Payment & Staking keys using Ledger/Trezor HW-Keys (MultiSig-Path 1854H/1815H/<Acc>/0,2/<Idx>)
$(basename $0) owner hybrid          ... generates Payment keys using Ledger/Trezor HW-Keys, Staking keys via cli (comfort mode for multiowner pools)
$(basename $0) owner hybridenc       ... generates Payment keys using Ledger/Trezor HW-Keys, Staking keys via cli and encrypted via a Password
$(basename $0) owner hybridmulti     ... generates Payment keys using Ledger/Trezor HW-Keys (MultiSig-Path 1854H/1815H/<Acc>/0/<Idx>), Staking keys via cli
$(basename $0) owner hybridmultienc  ... generates Payment keys using Ledger/Trezor HW-Keys (MultiSig-Path 1854H/1815H/<Acc>/0/<Idx>), Staking keys via cli and encrypted via a Password
$(basename $0) owner mnemonics       ... generates Payment & Staking keys via cli and also generates Mnemonics for LightWallet import possibilities

Examples with Hardware-Account/Index-Numbers:
$(basename $0) owner hw "acc:1"        ... generates Payment & Staking keys using Ledger/Trezor HW-Keys and SubAccount# 1, Index# 0
$(basename $0) owner hybrid "acc:5"    ... generates Payment keys using Ledger/Trezor HW-Keys with SubAccount# 5, Index# 0, Staking keys via cli (comfort mode for multiowner pools)
$(basename $0) owner hybrid "acc:3" "idx:1"  ... generates Payment keys using Ledger/Trezor HW-Keys with SubAccount# 3, Index# 1, Staking keys via cli
$(basename $0) owner hybridenc "acc:7" ... generates Payment keys using Ledger/Trezor HW-Keys with SubAccount# 7, Index# 0, Staking keys via cli and encrypted via a Password

Example with Mnemonics:
$(basename $0) owner mnemonics "mnemonics: word1 word2 ... word24"  ... generates Payment & Staking keys via cli from the given 24 Mnemonic words (Path 1852H/1815H/<Acc>/0,2/<Idx>)
$(basename $0) owner mnemonics "acc:4" "idx:3"  ... generates Payment & Staking keys via cli and new Mnemonics for the path 1852H/1815H/H4/0,2/3


EOF
exit 1;
else

	#Set the addrName and the choosen keyType
	addrName="$(dirname $1)/$(basename $1 .addr)"; addrName=${addrName/#.\//};
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

#switching to multisig HW-RootPath if needed
if [[ "${keyType}" == *"MULTI"* ]]; then
	hwRootPath="1854";
	multiSigPrefix="MultiSig-";
	else
	hwRootPath="1852";
	multiSigPrefix="";
fi


##############################
#### Building the Payment Keys
##############################

if [[ "${keyType}" == "CLI" ]]; then #Payment Keys via CLI (unencrypted)

	#We need a normal payment(base) keypair with vkey and skey, so let's create that one
	${cardanocli} ${cliEra} address key-gen --verification-key-file "${addrName}.payment.vkey" --signing-key-file "${addrName}.payment.skey"
	checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
	file_lock ${addrName}.payment.vkey
	file_lock ${addrName}.payment.skey
	echo -e "\e[0mPayment(Base)-Verification-Key: \e[32m ${addrName}.payment.vkey \e[90m"
	cat ${addrName}.payment.vkey
	echo
	echo -e "\e[0mPayment(Base)-Signing-Key: \e[32m ${addrName}.payment.skey \e[90m"
	cat ${addrName}.payment.skey
	echo



elif [[ "${keyType}" == "MNEMONICS" ]]; then #Payment Keys via Mnemonics (unencrypted)

	#Check warnings
	if [ -f "${addrName}.payment.mnemonics" ]; then echo -e "\e[35mWARNING - ${addrName}.payment.mnemonics already present, delete it or use another name !\e[0m"; exit 1; fi

	echo
	echo -e "\e[0mGenerating CLI Payment-Keys via Derivation-Path:\e[32m ${hwRootPath}H/1815H/${accNo}H/0/${idxNo}\e[0m"
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
		signerJSON=$(${cardanosigner} keygen --path "${hwRootPath}H/1815H/${accNo}H/0/${idxNo}" --mnemonics "${mnemonics}" --with-chain-code --json-extended --out-skey "${addrName}.payment.skey" 2> /dev/stdout)
	        if [ $? -ne 0 ]; then echo -e "\e[35mERROR - ${signerJSON}\e[0m\n\n"; exit 1; fi
        else
                #Generate the Files and read the mnemonics
		signerJSON=$(${cardanosigner} keygen --path "${hwRootPath}H/1815H/${accNo}H/0/${idxNo}" --with-chain-code --json-extended --out-skey "${addrName}.payment.skey" 2> /dev/stdout)
	        if [ $? -ne 0 ]; then echo -e "\e[35mERROR - ${signerJSON}\e[0m\n\n"; exit 1; fi
		mnemonics=$(jq -r ".mnemonics" <<< ${signerJSON} 2> /dev/null)
		checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
		echo -e "\e[0mCreated Mnemonics:\e[32m ${mnemonics}\e[0m"

        fi
	echo -e "${mnemonics}" > "${addrName}.payment.mnemonics"
        if [ $? -ne 0 ]; then 
		echo -e "\e[35mERROR - Couldn't write file '${addrName}.payment.mnemonics'\e[0m\n\n"; exit 1;
	else
		echo -e "\e[0mMnemonics written to file:\e[32m ${addrName}.payment.mnemonics\e[0m"
	fi
	echo

	vkeyJSON=$(jq -r ".output.vkey" <<< ${signerJSON} 2> /dev/null)
	checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
	vkeyJSON=$(${cardanocli} ${cliEra} key non-extended-key --extended-verification-key-file <(echo "${vkeyJSON}") --verification-key-file /dev/stdout) #convert the extended vkey into a normal one
	checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
	vkeyJSON=$(jq ".description = \"Payment Verification Key\"" <<< ${vkeyJSON} 2> /dev/null)
	checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
	echo -e "${vkeyJSON}" > "${addrName}.payment.vkey"
        if [ $? -ne 0 ]; then echo -e "\e[35mERROR - Couldn't write file '${addrName}.payment.vkey'\e[0m\n\n"; exit 1; fi

	file_lock ${addrName}.payment.mnemonics
	file_lock ${addrName}.payment.vkey
	file_lock ${addrName}.payment.skey
	echo -e "\e[0mPayment(Base)-Verification-Key: \e[32m ${addrName}.payment.vkey \e[90m"
	cat ${addrName}.payment.vkey
	echo
	echo -e "\e[0mPayment(Base)-Signing-Key: \e[32m ${addrName}.payment.skey \e[90m"
	cat ${addrName}.payment.skey
	echo



elif [[ "${keyType}" == "ENC" ]]; then #Payment Keys via CLI (encrypted)

	#We need a normal payment(base) keypair with vkey and skey, so let's create that one
        skeyJSON=$(${cardanocli} ${cliEra} address key-gen --verification-key-file "${addrName}.payment.vkey" --signing-key-file /dev/stdout 2> /dev/null)
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

	echo -e "\e[0mGenerating HW PaymentKeys via Derivation-Path:\e[32m ${hwRootPath}H/1815H/${accNo}H/0/${idxNo}\e[0m"
	echo

	#We need a payment(base) keypair with vkey and hwsfile from a Hardware-Key, sol lets' create them
        start_HwWallet; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
  	tmp=$(${cardanohwcli} address key-gen --path ${hwRootPath}H/1815H/${accNo}H/0/${idxNo} --verification-key-file ${addrName}.payment.vkey --hw-signing-file ${addrName}.payment.hwsfile 2> /dev/stdout)
        if [[ "${tmp^^}" =~ (ERROR|DISCONNECT) ]]; then echo -e "\e[35m${tmp}\e[0m\n"; exit 1; else echo -e "\e[32mDONE\e[0m\n"; fi
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

	#Edit the description in the vkey file to mark this as a hardware verification key
	vkeyJSON=$(cat ${addrName}.payment.vkey | jq ".description = \"Payment Hardware Verification Key\" ")
	echo "${vkeyJSON}" > ${addrName}.payment.vkey

        file_lock ${addrName}.payment.vkey
        file_lock ${addrName}.payment.hwsfile

        echo -e "\e[0m${multiSigPrefix}Payment(Base)-Verification-Key (Acc# ${accNo}, Idx# ${idxNo}): \e[32m ${addrName}.payment.vkey \e[90m"
        cat ${addrName}.payment.vkey
        echo
        echo -e "\e[0m${multiSigPrefix}Payment(Base)-HardwareSigning-File (Acc# ${accNo}, Idx# ${idxNo}): \e[32m ${addrName}.payment.hwsfile \e[90m"
        cat ${addrName}.payment.hwsfile
        echo

fi

echo

##############################
#### Building the Staking Keys
##############################

if [[ "${keyType}" == "CLI" || "${keyType}" == "HYBRID" || "${keyType}" == "HYBRIDMULTI" ]]; then #Staking Keys via CLI (unencrypted)

	#Building the StakeAddress Keys from CLI for the normal CLI type or when HYBRID was choosen
	${cardanocli} ${cliEra} stake-address key-gen --verification-key-file "${addrName}.staking.vkey" --signing-key-file "${addrName}.staking.skey"
	checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
	file_lock ${addrName}.staking.vkey
	file_lock ${addrName}.staking.skey

	echo -e "\e[0mVerification(Rewards)-Staking-Key: \e[32m ${addrName}.staking.vkey \e[90m"
	cat ${addrName}.staking.vkey
	echo
	echo -e "\e[0mSigning(Rewards)-Staking-Key: \e[32m ${addrName}.staking.skey \e[90m"
	cat ${addrName}.staking.skey
	echo



elif [[ "${keyType}" == "MNEMONICS" ]]; then #Payment Keys via Mnemonics (unencrypted)

	echo -e "\e[0mGenerating CLI Staking-Keys via Derivation-Path:\e[32m ${hwRootPath}H/1815H/${accNo}H/2/0\e[0m"
	echo

	echo -e "\e[0mUsing Cardano-Signer Version: \e[32m${cardanosignerVersion}\e[0m\n";

	#After the payment key generation with or without given mnemonics, at this point there are mnemonics available via
	#the ${mnemonics} variable

	#Generate the Files with mnemonics
	signerJSON=$(${cardanosigner} keygen --path "${hwRootPath}H/1815H/${accNo}H/2/${idxNo}" --mnemonics "${mnemonics}" --with-chain-code --json-extended --out-skey "${addrName}.staking.skey" 2> /dev/stdout)
        if [ $? -ne 0 ]; then echo -e "\e[35mERROR - ${signerJSON}\e[0m\n\n"; exit 1; fi

	vkeyJSON=$(jq -r ".output.vkey" <<< ${signerJSON} 2> /dev/null)
	checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
	vkeyJSON=$(${cardanocli} ${cliEra} key non-extended-key --extended-verification-key-file <(echo "${vkeyJSON}") --verification-key-file /dev/stdout) #convert the extended vkey into a normal one
	checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
	vkeyJSON=$(jq ".description = \"Stake Verification Key\"" <<< ${vkeyJSON} 2> /dev/null)
	checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
	echo -e "${vkeyJSON}" > "${addrName}.staking.vkey"
        if [ $? -ne 0 ]; then echo -e "\e[35mERROR - Couldn't write file '${addrName}.staking.vkey'\e[0m\n\n"; exit 1; fi

	file_lock ${addrName}.staking.vkey
	file_lock ${addrName}.staking.skey

	echo -e "\e[0mVerification(Rewards)-Staking-Key: \e[32m ${addrName}.staking.vkey \e[90m"
	cat ${addrName}.staking.vkey
	echo
	echo -e "\e[0mSigning(Rewards)-Staking-Key: \e[32m ${addrName}.staking.skey \e[90m"
	cat ${addrName}.staking.skey
	echo



elif [[ "${keyType}" == "ENC" || "${keyType}" == "HYBRIDENC" || "${keyType}" == "HYBRIDMULTIENC" ]]; then #Staking Keys via CLI (encrypted)

	#Building the StakeAddress Keys from CLI for the normal CLI type or when HYBRID was choosen
	skeyJSON=$(${cardanocli} ${cliEra} stake-address key-gen --verification-key-file "${addrName}.staking.vkey" --signing-key-file /dev/stdout 2> /dev/null)
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

	echo -e "\e[0mGenerating HW Staking-Keys via Derivation-Path:\e[32m ${hwRootPath}H/1815H/${accNo}H/2/0\e[0m"
	echo

        #We need the staking keypair with vkey and hwsfile from a Hardware-Key, so lets' create them
        start_HwWallet; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
        tmp=$(${cardanohwcli} address key-gen --path ${hwRootPath}H/1815H/${accNo}H/2/0 --verification-key-file ${addrName}.staking.vkey --hw-signing-file ${addrName}.staking.hwsfile 2> /dev/stdout)
        if [[ "${tmp^^}" =~ (ERROR|DISCONNECT) ]]; then echo -e "\e[35m${tmp}\e[0m\n"; exit 1; else echo -e "\e[32mDONE\e[0m\n"; fi
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

        #Edit the description in the vkey file to mark this as a hardware verification key
        vkeyJSON=$(cat ${addrName}.staking.vkey | jq ".description = \"Stake Hardware Verification Key\" ")
        echo "${vkeyJSON}" > ${addrName}.staking.vkey

        file_lock ${addrName}.staking.vkey
        file_lock ${addrName}.staking.hwsfile

        echo -e "\e[0m${multiSigPrefix}Verification(Rewards)-Staking-Key (Acc# ${accNo}, Idx# 0): \e[32m ${addrName}.staking.vkey \e[90m"
        cat ${addrName}.staking.vkey
        echo
        echo -e "\e[0m${multiSigPrefix}Signing(Rewards)-HardwareSigning-File (Acc# ${accNo}, Idx# 0): \e[32m ${addrName}.staking.hwsfile \e[90m"
        cat ${addrName}.staking.hwsfile
        echo

fi

#Building a Payment Address
${cardanocli} ${cliEra} address build --payment-verification-key-file "${addrName}.payment.vkey" --staking-verification-key-file "${addrName}.staking.vkey" ${addrformat} > "${addrName}.payment.addr"
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
file_lock "${addrName}.payment.addr"

echo -e "\e[0mPayment(Base)-Address built: \e[32m ${addrName}.payment.addr \e[90m"
cat "${addrName}.payment.addr"
echo
echo

#Building a Staking Address
${cardanocli} ${cliEra} stake-address build --staking-verification-key-file "${addrName}.staking.vkey" ${addrformat} > "${addrName}.staking.addr"
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
file_lock "${addrName}.staking.addr"

echo -e "\e[0mStaking(Rewards)-Address built: \e[32m ${addrName}.staking.addr \e[90m"
cat "${addrName}.staking.addr"
echo

#create an address registration certificate

#Read ProtocolParameters
if ${onlineMode}; then
                        protocolParametersJSON=$(${cardanocli} query protocol-parameters ); #onlinemode
                  else
                        protocolParametersJSON=$(jq ".protocol.parameters" <<< ${offlineJSON}); #offlinemode
                  fi
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

stakeAddressDepositFee=$(jq -r .stakeAddressDeposit <<< ${protocolParametersJSON})
echo -e "\e[0mStake Address Deposit Fee: \e[32m ${stakeAddressDepositFee} lovelaces \e[90m"
echo

${cardanocli} ${cliEra} stake-address registration-certificate --staking-verification-key-file "${addrName}.staking.vkey" --key-reg-deposit-amt "${stakeAddressDepositFee}" --out-file "${addrName}.staking.cert"
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
file_lock "${addrName}.staking.cert"

echo -e "\e[0mStaking-Address-Registration-Certificate built: \e[32m ${addrName}.staking.cert \e[90m"
cat "${addrName}.staking.cert"
echo
echo
echo -e "\e[35mIf you wanna register the Staking-Address, please now run the script 03b_regStakingAddrCert.sh !\e[0m"
echo


