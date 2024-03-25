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


#Display usage instructions
showUsage() {
cat >&2 <<EOF
Info:     $(basename $0) can protect your SKEY-Files by encrypting/decrypting them via a given password

Usage:    $(basename $0) <ENC|ENCRYPT|DEC|DECRYPT> <Name of SKEY-File>

Example:  $(basename $0) enc mywallet          ... Encrypts the mywallet.skey file
          $(basename $0) enc owner.payment     ... Encrypts the owner.payment.skey file
          $(basename $0) enc mypool.node.skey  ... Encrypts the mypool.node.skey file
          $(basename $0) enc mydrep.drep       ... Encrypts the mydrep.drep.skey file
          $(basename $0) enc mycom.cc-hot.skey ... Encrypts the mycom.cc-hot.skey file


          $(basename $0) dec mywallet          ... Decrypts the mywallet.skey file
          $(basename $0) dec owner.staking     ... Decrypts the owner.staking.skey file
          $(basename $0) dec mypool.vrf.skey   ... Decrypts the mypool.vrf.skey file

EOF
}


#Check commandline parameters
if [[ $# -lt 2 ]]; then showUsage; exit 1; fi  #check about two given parameters
case ${1^^} in

  ENC|ENCRYPT|DEC|DECRYPT )
		action="${1^^}"
		if [[ $# -ne 2 ]]; then showUsage; fi #only support for two parameters action+targetFile right now

		#select the targetFile, try the given file itself and also with the extension '.skey' appended
		if [ -f "${2}" ]; then targetFile="${2}"
		elif [ -f "${2}.skey" ]; then targetFile="${2}.skey"
		else showUsage; echo -e "\e[35mERROR - Cannot find the file '${2}' or '${2}.skey' !\e[0m\n"; exit 1;
		fi
		targetFile=${targetFile/#.\//} #remove a leading ./ if file is in the same directory, this is just a cosmetic change

		#check that the given file is actually a json and has a SigningKey in the type
		if [[ ! "$(jq -r .type "${targetFile}")" == *"SigningKey"* ]]; then echo -e "\n\e[35mERROR - '${targetFile}' does not look like to be a SKEY-File. Missing 'SigningKey' in the type!\e[0m\n" >&2; exit 1; fi;


		#check that the encryption/decryption tool gpg exists
		if ! exists gpg; then echo -e "\e[33mYou need the little tool 'gnupg', its needed to encrypt/decrypt the data !\n\nInstall it on Ubuntu/Debian like:\n\e[97msudo apt update && sudo apt -y install gnupg\n\n\e[33mThx! :-)\e[0m\n"; exit 1; fi

		;;

  * ) 		showUsage; echo -e "\e[35mERROR - Please use a supported action 'enc|encrypt|dec|decrypt' for the first parameter !\e[0m\n"; exit 1;
		;;
esac


#lets do it
case ${action} in

###########################################
###
### action = ENC or ENCRYPT
###
###########################################
  ENC|ENCRYPT )


		#show the current content of the skey file
		echo -e "\e[0mSKEY-File that will be encrypted: \e[32m${targetFile}\e[90m";
		skeyJSON=$(cat "${targetFile}")
		echo -e "${skeyJSON}"
		echo -e "\e[0m";

		#check that it is not already encrypted
		if [[ $(egrep "encrHex|Encrypted" "${targetFile}" | wc -l) -ne 0 ]]; then echo -e "\n\e[35mERROR - '${targetFile}' is already encrypted!\e[0m\n" >&2; exit 1; fi;

		#Ask to continue, default action is No -> abort
		if ! ask "\e[33mIs this correct, continue?" N; then echo -e "\n\e[35mAborted\e[0m\n\n"; exit 1; fi
		echo -e "\e[0m";


		#Loop until we have two matching passwords
		pass_1="x"; pass_2="y"; #start with unmatched passwords
		while [[ "${pass_1}" != "${pass_2}" ]]; do

			#Read in the password
			echo -e "\e[0mPlease provide a strong password (min. 10 chars, uppercase, lowercase, specialchars) for the encryption ...\n";
			pass_1=$(ask_pass "\e[33mEnter a strong Password (empty to abort)")
			if [[ ${pass_1} == "" ]]; then echo -e "\n\e[35mAborted\e[0m\n\n"; exit 1; fi
			while [[ $(is_strong_password "${pass_1}") != "true" ]]; do
				echo -e "\n\e[35mThis is not a strong password, lets try it again...\e[0m\n"
				pass_1=$(ask_pass "\e[33mEnter a strong Password (empty to abort)")
				if [[ ${pass_1} == "" ]]; then echo -e "\n\e[35mAborted\e[0m\n\n"; exit 1; fi
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

		echo -e "\e[0mEncrypted SKEY-File will look like:\e[90m";
		echo -e "${encrJSON}"
		echo -e "\e[0m";

		#overwrite the skey file
		if ask "\e[33mWrite encrypted SKEY-File to disc?" N; then

			echo -ne "\n\e[0mWriting the file '\e[32m${targetFile}\e[0m' to disc ... "
			file_unlock "${targetFile}"
			echo "${encrJSON}" > "${targetFile}"
			if [ $? -ne 0 ]; then echo -e "\n\n\e[35mERROR, could not write to file! Your '${targetFile}' may now be corrupted, please use your original SKEY content to recover it:\n${skeyJSON}\n\n\e[0m"; exit 1; fi
			file_lock "${targetFile}"
			echo -e "\e[32mOK\e[0m"
			unset skeyJSON

		else echo -e "\n\e[35mAborted\e[0m\n\n"; exit 1;

		fi

		echo
		echo -e "\e[0mEncrypted SKEY-File: \e[32m${targetFile}\e[90m";
		cat "${targetFile}"
		echo -e "\e[0m\n";

                ;;

###########################################
###
### action = DEC or DECRYPT
###
###########################################
  DEC|DECRYPT )

		#show the current content of the skey file
		echo -e "\e[0mSKEY-File that will be decrypted: \e[32m${targetFile}\e[90m";
		skeyJSON=$(cat "${targetFile}")
		echo -e "${skeyJSON}"
		echo -e "\e[0m";

		#check that it is not already decrypted
		if [[ $(egrep "encrHex|Encrypted" "${targetFile}" | wc -l) -eq 0 ]]; then echo -e "\n\e[35mERROR - '${targetFile}' is not encrypted!\e[0m\n" >&2; exit 1; fi;

		#Ask to continue, default action is No -> abort
		if ! ask "\e[33mIs this correct, continue?" N; then echo -e "\n\e[35mAborted\e[0m\n\n"; exit 1; fi
		echo -e "\e[0m";

		#Read in the password
		echo -e "\e[0mPlease provide the strong password (min. 10 chars, uppercase, lowercase, specialchars) for the decryption ...\n";
		password=$(ask_pass "\e[33mEnter the Password (empty to abort)")
		if [[ ${password} == "" ]]; then echo -e "\n\e[35mAborted\e[0m\n\n"; exit 1; fi
		while [[ $(is_strong_password "${password}") != "true" ]]; do
			echo -e "\n\e[35mThis is not a strong password, so it couldn't be the right one. Lets try it again...\e[0m\n"
			password=$(ask_pass "\e[33mEnter the Password (empty to abort)")
			if [[ ${password} == "" ]]; then echo -e "\n\e[35mAborted\e[0m\n\n"; exit 1; fi
		done
		echo -e "\e[0m\n";

		#Decrypt the data
		showProcessAnimation "Decrypting the cborHex: " &
		decrJSON=$(decrypt_skeyJSON "${skeyJSON}" "${password}"); if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\n\e[35mERROR - ${decrJSON}\e[0m\n"; exit 1; fi;
		stopProcessAnimation
		unset password

		echo -e "\e[32mOK, Decrypted SKEY-File will look like:\e[90m";
		echo -e "${decrJSON}"
		echo -e "\e[0m";

		#overwrite the skey file
		if ask "\e[33mWrite decrypted SKEY-File to disc?" N; then

			echo -ne "\n\e[0mWriting the file '\e[32m${targetFile}\e[0m' to disc ... "
			file_unlock "${targetFile}"
			echo "${decrJSON}" > "${targetFile}"
			unset decrJSON
			if [ $? -ne 0 ]; then echo -e "\n\n\e[35mERROR, could not write to file! Your '${targetFile}' may now be corrupted, please use your original SKEY content to recover it:\n${skeyJSON}\n\n\e[0m"; exit 1; fi
			file_lock "${targetFile}"
			echo -e "\e[32mOK\e[0m"
			unset skeyJSON

		else echo -e "\n\e[35mAborted\e[0m\n\n"; exit 1;

		fi

		echo
		echo -e "\e[0mDecrypted SKEY-File: \e[32m${targetFile}\e[90m";
		cat "${targetFile}"
		echo -e "\e[0m\n";

                ;;

esac


