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

Usage: $(basename $0) new cli <CalidusKeyName>                          ... Generates a new 24-Words-Mnemonic and derives the Calidus-Pool KeyPair with the given name
       $(basename $0) new cli <CalidusKeyName> "<24-words-mnenonics>"   ... Generates a new Calidus-Pool KeyPair with the given name from an existing 24-Words-Mnemonic
       $(basename $0) new hw  <CalidusKeyName>                          ... Generates a new Calidus-Pool KeyPair with the given name from a HW-Wallet

       $(basename $0) genmeta <CalidusKeyName> <PoolNodeName> [nonce]
          ... Generates the Calidus Pool-Key Registration-Metadata in JSON format. [Option: nonce]

       $(basename $0) query <CalidusKeyName|Calidus-ID|Calidus-PublicKeyHex|Pool-ID|PoolNodeName> or 'all'
          ... Queries the Koios-API for the Calidus-Pool Key or for a CalidusID/Pool-ID in bech format
              Or use the keyword 'all' to get all registered entries

Examples:

       $(basename $0) new cli example
          ... Generates a new Calidus-Pool KeyPair example.calidus.skey/vkey, writes Mnemonics to example.calidus.mnemonics

       $(basename $0) genmeta example mypool
          ... Generates the Calidus Registration-Metadata for the Calidus-Key example.calidus.vkey and signs it with the mypool.node.skey/hwsfile

       $(basename $0) query example
          ... Searches the API for entries about the example Calidus-Key

       $(basename $0) query pool1rdaxrw3722f0x3nx4uam9u9c6dh9qqd2g83r2uyllf53qmmj5uu
          ... Searches the API for entries about the given Pool-ID

EOF
}

################################################
# MAIN START
#
# Check commandline parameters
#
paramCnt=$#;
allParameters=( "$@" )
calidusPATH="1852H/1815H/0H/0/0"

case ${1,,} in

  ### Generate new calidus Keys
  new )

		if [[ ${paramCnt} -lt 3 ]]; then showUsage; exit 1;
                elif [[ ${paramCnt} -ge 3 ]]; then
			method="${allParameters[1]}";
			calidusKeyName="${allParameters[2]}"; calidusKeyName=${calidusKeyName/#.\//};
		else echo -e "\e[35mMissing parameters!\e[0m\n"; showUsage; exit 1; fi

		if [ -f "${calidusKeyName}.calidus.vkey" ]; then echo -e "\e[35mError - ${calidusKeyName}.calidus.vkey already exists, please delete it first if you wanna overwrite it !\e[0m\n"; exit 1; fi
		if [ -f "${calidusKeyName}.calidus.skey" ]; then echo -e "\e[35mError - ${calidusKeyName}.calidus.skey already exists, please delete it first if you wanna overwrite it !\e[0m\n"; exit 1; fi
		if [ -f "${calidusKeyName}.calidus.hwsfile" ]; then echo -e "\e[35mError - ${calidusKeyName}.calidus.hwsfile already exists, please delete it first if you wanna overwrite it !\e[0m\n"; exit 1; fi

                echo -e "\e[0mGenerating a new Calidus-KeyPair with the name: \e[32m${calidusKeyName}\e[0m"
		echo
		echo -e "\e[0mDeriving Calidus-Keys from Path:\e[32m ${calidusPATH}\e[0m"
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

		#Getting the calidus Key Pair via CLI or via HW-Wallet
		case ${method,,} in

		   cli )

	                if [[ ${paramCnt} -ge 4 ]]; then
				mnemonics="${allParameters[3]}" #read the mnemonics
				mnemonics=$(trimString "${mnemonics,,}") #convert to lowercase and trim it
				mnemonicsWordcount=$(wc -w <<< ${mnemonics})
				if [[ ${mnemonicsWordcount} -ne 24 ]]; then echo -e "\e[35mError - Please provide 24 Mnemonic Words, you've provided ${mnemonicsWordcount}!\e[0m\n"; exit 1; fi
			fi

			if [[ ${mnemonics} != "" ]]; then #use the provided mnemonics
				echo -e "\e[0mUsing Mnemonics:\e[32m ${mnemonics}\e[0m"
				#Generate the Calidus-Key-Files with given mnemonics
				calidusKeyJSON=$(${cardanosigner} keygen --path calidus --mnemonics "${mnemonics}" --json-extended --out-skey "${calidusKeyName}.calidus.skey" --out-vkey "${calidusKeyName}.calidus.vkey")
				checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
			else
				#Generate the Calidus-Key-Files and new mnemonics
				calidusKeyJSON=$(${cardanosigner} keygen --path calidus --json-extended --out-skey "${calidusKeyName}.calidus.skey" --out-vkey "${calidusKeyName}.calidus.vkey")
				checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
				mnemonics=$(jq -r ".mnemonics" <<< ${calidusKeyJSON} 2> /dev/stdout)
				echo -e "\e[0mCreated Mnemonics:\e[32m ${mnemonics}\e[0m"
			fi

			echo

			file_lock ${calidusKeyName}.calidus.skey
			echo -e "\e[0mCalidus-Signing(Secret)-Key: \e[32m ${calidusKeyName}.calidus.skey \e[90m"
			cat "${calidusKeyName}.calidus.skey"
			echo -e "\e[0m"

	                file_lock ${calidusKeyName}.calidus.vkey
			echo -e "\e[0mCalidus-Verification(Public)-Key: \e[32m ${calidusKeyName}.calidus.vkey \e[90m"
			cat "${calidusKeyName}.calidus.vkey"
			echo -e "\e[0m"

			#write out the used mnemonics
			echo "${mnemonics}" > "${calidusKeyName}.calidus.mnemonics" 2> /dev/null
			checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
			file_lock ${calidusKeyName}.calidus.mnemonics
			echo -e "\e[0mMnemonics-File: \e[32m ${calidusKeyName}.calidus.mnemonics\e[90m"
			cat "${calidusKeyName}.calidus.mnemonics"
			echo -e "\e[0m"

			#write out the calidus id
			calidusIdBech=$(jq -r ".calidusIdBech" <<< ${calidusKeyJSON} 2> /dev/stdout)
			echo "${calidusIdBech}" > "${calidusKeyName}.calidus.id" 2> /dev/null
			checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
			file_lock ${calidusKeyName}.calidus.id
			echo -e "\e[0mCalidus-ID-File: \e[32m ${calidusKeyName}.calidus.id\e[90m"
			cat "${calidusKeyName}.calidus.id"
			echo -e "\e[0m"

			exit 0;
			;; #cli


		   hw )

			echo -e "\e[35mDeriving the Calidus Key from a HW-Wallet is currently suspended until we have an own derivation-path. Please generate a 'cli' based on !\e[0m\n"; showUsage; exit 1;

			#We need a calidus keypair with vkey and hwsfile from a Hardware-Key, so lets create them
			start_HwWallet "" "" ""; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
			tmp=$(${cardanohwcli} address key-gen --path 1852H/1815H/0H/0/0 --verification-key-file "${calidusKeyName}.calidus.vkey" --hw-signing-file "${calidusKeyName}.calidus.hwsfile" 2> /dev/stdout)
			if [[ "${tmp^^}" =~ (ERROR|DISCONNECT) ]]; then echo -e "\e[35m${tmp}\e[0m\n"; exit 1; else echo -e "\e[32mDONE\e[0m\n"; fi
			checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

			#Set the right description according to CIP36
			hwsfileJSON=$(jq " .description = \"Hardware Calidus Pool Signing File\" " "${calidusKeyName}.calidus.hwsfile")
			echo "${hwsfileJSON}" > "${calidusKeyName}.calidus.hwsfile" 2> /dev/null
			checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
		        file_lock "${calidusKeyName}.calidus.hwsfile"

			vkeyJSON=$(jq " .description = \"Hardware Calidus Pool Verification Key\" " "${calidusKeyName}.calidus.vkey")
			echo "${vkeyJSON}" > "${calidusKeyName}.calidus.vkey" 2> /dev/null
			checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
		        file_lock "${calidusKeyName}.calidus.vkey"

			echo -e "\e[0mHardware-calidus-Signing-Key: \e[32m ${calidusKeyName}.calidus.hwsfile \e[90m"
			cat "${calidusKeyName}.calidus.hwsfile"
			echo
			echo
	                echo -e "\e[0mHardware-calidus-Public-Key: \e[32m ${calidusKeyName}.calidus.vkey \e[90m"
	                cat "${calidusKeyName}.calidus.vkey"
	                echo
			echo -e "\e[0m"

			exit 0;
			;; #hw

		   * )
			echo -e "\e[35mERROR - Method not supported. Please use 'cli' or 'hw' !\e[0m\n"; showUsage; exit 1;
			;;
		esac

                ;; #new




  ### Generate the registration metadata
  genmeta )

		#Check about 4 input parameters
		if [[ ${paramCnt} -lt 3 ]]; then echo -e "\e[35mIncorrect parameter count!\e[0m\n"; showUsage; exit 1; fi

		#Calidus Key check
		calidusKeyName="$(dirname ${allParameters[1]})/$(basename $(basename ${allParameters[1]} .vkey) .calidus)"; calidusKeyName=${calidusKeyName/#.\//};
		if ! [[ -f "${calidusKeyName}.calidus.vkey" ]]; then echo -e "\e[35mError - ${calidusKeyName}.calidus.vkey does not exist, please create the key first using option 'new cli ${calidusKeyName}' !\e[0m\n"; exit 1; fi

		#Pool Key check
		poolKeyName="$(dirname ${allParameters[2]})/$(basename $(basename $(basename ${allParameters[2]} .skey) .hwsfile) .node)"; poolKeyName=${poolKeyName/#.\//};
		if ! [[ -f "${poolKeyName}.node.skey" || -f "${poolKeyName}.node.hwsfile" ]]; then echo -e "\e[35mError - ${poolKeyName}.node.skey(hwsfile) does not exist, please create the key first using scripts 04 !\e[0m\n"; exit 1; fi

		#Nonce check
		if [[ ${paramCnt} -eq 4 ]]; then
			nonce=${allParameters[3]}
			if [[ -n "${nonce//[0-9]}" || ${nonce} -eq 0 ]]; then echo -e "\n\e[91mERROR - The value for nonce '${nonce}' should be a natural number greater than zero.\n\e[0m"; exit 1; fi
		fi

		#Output filename for the Calidus-Registration-JSON-Metadata
		datestr=$(date +"%y%m%d%H%M%S")
		calidusRegistrationFile="$(dirname ${allParameters[2]})/$(basename ${poolKeyName})_${datestr}.calidus-registration.json"; calidusRegistrationFile=${calidusRegistrationFile/#.\//};
		if [ -f "${calidusRegistrationFile}" ]; then echo -e "\e[35mError - ${calidusRegistrationFile} already exists, please delete it first if you wanna overwrite it !\e[0m\n"; exit 1; fi

                echo -e "\e[0mGenerating the Calidus-Registration-MetadataFile(JSON): \e[32m${calidusRegistrationFile}\e[0m"
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

		#Collect all needed informations
		#1. Get the Pool-ID hex
		#If the pool key is on a HW-Wallet, do it all via cardano-hw-cli
		if [ -f "${poolKeyName}.node.hwsfile" ]; then

	                echo -e "\e[0mUsing the Calidus-KeyFile \e[32m${calidusKeyName}.calidus.vkey\e[0m and the Hardware Pool-KeyFile \e[32m${poolKeyName}.node.hwsfile\e[0m"
			echo
			if [ -f "${poolKeyName}.pool.id-bech" ]; then #there is a pool.id-bech file present, try to use this
			        echo -e "\e[0mChecking the Pool-ID-Bech File for a valid PoolID:\e[32m ${poolKeyName}.pool.id-bech\e[0m"
			        echo
			        #read in the Bech-PoolID from the pool.id-bech file
			        poolIdBech=$(cat "${poolKeyName}.pool.id-bech" | tr -d '\n')
			        #check if the content is a valid bech
			        if [[ "${poolIdBech:0:5}" == "pool1" && ${#poolIdBech} -eq 56 ]]; then #parameter is most likely a bech32-poolid
			                #lets do some further testing by converting the bech32 pool-id into a hex-pool-id
			                poolIdHex=$(${bech32_bin} 2> /dev/null <<< "${poolIdBech}") #will have returncode 0 if the bech was valid
			                if [ $? -ne 0 ]; then echo -e "\n\e[35mERROR - The content of the Pool-ID-Bech File \"${poolKeyName}.pool.id-bech\" is not a valid Bech-PoolID.\e[0m\n"; exit 1; fi
		                echo -e "\e[0mThe Pool-ID File contains the following Bech-PoolID:\e[32m ${poolIdBech}\e[0m"
		                echo
			        else
		                echo -e "\n\e[35mERROR - The content of the Pool-ID-Bech File \"${poolKeyName}.pool.id-bech\" is not a valid Bech-PoolID.\e[0m\n";
			        fi

			elif [ -f "${poolKeyName}.pool.id" ]; then #there is a pool.id file present, try to use this
				echo -e "\e[0mChecking the Pool-ID File for a valid PoolID:\e[32m ${poolKeyName}.pool.id\e[0m"
				echo
				#read in the Hex-PoolID from the pool.id file
				poolIdHex=$(cat "${poolKeyName}.pool.id" | tr -d '\n')
				#check if the content is a valid pool hex
				if [[ "${poolIdHex//[![:xdigit:]]}" == "${poolIdHex}" && ${#poolIdHex} -eq 56 ]]; then
			                echo -e "\e[0mThe Pool-ID File contains the following HEX-PoolID:\e[32m ${poolIdHex}\e[0m"
			                #converting the Hex-PoolID into a Bech-PoolID
			                poolIdBech=$(${bech32_bin} "pool" <<< ${poolIdHex} | tr -d '\n')
			                checkError "$?"; if [ $? -ne 0 ]; then echo -e "\n\e[35mERROR - Could not convert the given Pool-ID File \"${poolKeyName}.pool.id\" into a Bech Pool-ID.\e[0m\n"; exit 1; fi
			                echo
			        else
			                echo -e "\n\e[35mERROR - The content of the Pool-ID File \"${poolKeyName}.pool.id\" is not a valid Hex-PoolID.\e[0m\n"; exit 1;
			        fi

			elif [ -f "${poolKeyName}.node.vkey" ]; then #there is a node.vkey file present, try to use this
				echo -ne "\e[0mConverting the Pool Vkey-File \e[32m${poolKeyName}.node.vkey\e[0m into a Pool-ID ... "
				nodeVkeyCbor=$(jq -r .cborHex < "${poolKeyName}.node.vkey" 2> /dev/stdout)
				if [ $? -ne 0 ]; then echo -e "\e[35mError - ${nodeVkeyCbor}\e[0m\n"; exit 1; fi
				#Generate the Pool-ID hex
				poolIdHex=$(tail -c +5 <<< ${nodeVkeyCbor} | xxd -r -ps | b2sum -l 224 -b | cut -d' ' -f 1)
				#check if the content is a valid pool hex
				if [[ "${poolIdHex//[![:xdigit:]]}" == "${poolIdHex}" && ${#poolIdHex} -eq 56 ]]; then
			                echo -e "\e[32mOK\e[0m"
			                #converting the Hex-PoolID into a Bech-PoolID
			                poolIdBech=$(${bech32_bin} "pool" <<< ${poolIdHex} | tr -d '\n')
			                checkError "$?"; if [ $? -ne 0 ]; then echo -e "\n\e[35mERROR - Could not convert the given Pool-ID File \"${poolKeyName}.pool.id\" into a Bech Pool-ID.\e[0m\n"; exit 1; fi
			                echo
			        fi

			else
				 echo -e "\e[35mError - None of the ${poolKeyName}.pool.id/id-bech or ${poolKeyName}.node.vkey file exist !\e[0m\n"; exit 1; 
			fi

			#We have a valid pool hex id not in poolIdHex

			#2.Get the Calidus Public Key hex
			echo -ne "\e[0mConverting the Calidus Vkey-File \e[32m${calidusKeyName}.calidus.vkey\e[0m into the Calidus-ID ... "
				calidusVkeyCbor=$(jq -r .cborHex < "${calidusKeyName}.calidus.vkey" 2> /dev/stdout)
				if [ $? -ne 0 ]; then echo -e "\e[35mError - ${calidusVkeyCbor}\e[0m\n"; exit 1; fi
				calidusPublicKey=$(tail -c +5 <<< ${calidusVkeyCbor} 2> /dev/stdout)
				if [ $? -ne 0 ]; then echo -e "\e[35mError - ${calidusPublicKey}\e[0m\n"; exit 1; fi
				#generate the Calidus-ID
				calidusIdHex="a1$(echo -n ${calidusPublicKey} | xxd -r -ps | b2sum -l 224 -b | cut -d' ' -f 1)"
				#check if the content is a valid hex
				if [[ "${calidusIdHex//[![:xdigit:]]}" == "${calidusIdHex}" && ${#calidusIdHex} -eq 58 ]]; then
			                echo -e "\e[32mOK\e[0m"
			                #converting into the Calidus-ID-Bech
			                calidusIdBech=$(${bech32_bin} "calidus" <<< ${calidusIdHex} | tr -d '\n')
			                checkError "$?"; if [ $? -ne 0 ]; then echo -e "\n\e[35mERROR - Could not convert the Calidus Vkey-File \"${calidusKeyName}.calidus.vkey\" into a Calidus ID.\e[0m\n"; exit 1; fi
			                echo
			        else
			                echo -e "\n\e[35mERROR - Something went wrong while converting the \"${calidusKeyName}.calidus.vkey\" into a Calidus ID.\e[0m\n"; exit 1;
			        fi

			#3.Nonce
			if [[ ${nonce} == "" ]]; then nonce=$(get_currentTip); fi

			echo -e "\e[0m           Pool-ID: \e[94m${poolIdBech}\e[0m"
			echo -e "\e[0m       Pool-ID-Hex: \e[32m${poolIdHex}\e[0m"
			echo -e "\e[0m        Calidus-ID: \e[94m${calidusIdBech}\e[0m"
			echo -e "\e[0m Calidus PublicKey: \e[32m${calidusPublicKey}\e[0m"
			echo -e "\e[0m             Nonce: \e[32m${nonce}\e[0m"
			echo

			#4.Generate the Payload CBOR
			payloadCBOR=""
			payloadCBOR+=$(to_cbor map 5) # map with 5 entries
			payloadCBOR+=$(to_cbor unsigned 1) # map key 1
			payloadCBOR+=$(to_cbor array 2) # array with 2 entries
			payloadCBOR+=$(to_cbor unsigned 1) # scope is pool id registration
			payloadCBOR+=$(to_cbor bytes "${poolIdHex}") #byte array with the pool id
			payloadCBOR+=$(to_cbor unsigned 2) # map key 2
			payloadCBOR+=$(to_cbor array 0) # array with no entries
			payloadCBOR+=$(to_cbor unsigned 3) # map key 3
			payloadCBOR+=$(to_cbor array 1) # array with 1 entry
			payloadCBOR+=$(to_cbor unsigned 2) # witness type is CIP-0008
			payloadCBOR+=$(to_cbor unsigned 4) # map key 4
			payloadCBOR+=$(to_cbor unsigned ${nonce}) # nonce
			payloadCBOR+=$(to_cbor unsigned 7) # map key 2
			payloadCBOR+=$(to_cbor bytes "${calidusPublicKey}") #byte array with the calidus public key

			#5.Generate the message to sign (=hash of the payloadCBOR)
			messageHex=$(echo -n ${payloadCBOR} | xxd -r -ps | b2sum -l 256 | cut -d' ' -f 1)

			#6.Generate the hashed version of it because the HW-Gui shows the message to sign and also the hash of it
			hashedMessageHex=$(echo -n ${messageHex} | xxd -r -ps | b2sum -l 224 | cut -d' ' -f 1)

			echo -e "\e[0m           Message: \e[32m${messageHex}\e[0m"
			echo -e "\e[0m      Message hash: \e[32m${hashedMessageHex}\e[0m"
			echo

			#7.Do a CIP0008 message signing via cardano-hw-cli
			if ! ask "\e[33mSigning message via Pool-Cold-Key on the Hardware-Wallet, continue?\e[0m" Y; then echo; echo -e "\e[35mABORT - Signing aborted...\e[0m"; echo; exit 2; fi
			echo

			signedMessageFile="${tempDir}/$(basename ${calidusKeyName}).signedMessage"

			start_HwWallet "Ledger|Keystone" "" ""; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
			tmp=$(${cardanohwcli} message sign --message-hex "${messageHex}" --signing-path-hwsfile "${poolKeyName}.node.hwsfile" --out-file "${signedMessageFile}" 2> /dev/stdout)
			if [[ "${tmp^^}" =~ (ERROR|DISCONNECT) ]]; then echo -e "\e[35m${tmp}\e[0m\n"; exit 1; else echo -e "\e[32mDONE\e[0m\n"; fi
			checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

			#Getting the COSE-Key and COSE-Sign1 from the hardware signing
			{ read coseKey; read coseSign1; } <<< $(jq -r '.COSE_Key_hex // "-", .COSE_Sign1_hex // "-"' < "${signedMessageFile}" 2> /dev/stdout)

			#Get the Signature maps
			echo -e "\e[0mVerify with Cardano-Signer Version: \e[32m${cardanosignerVersion}\e[0m\n";
			verifyCip8JSON=$(${cardanosigner} verify --cip8 --cose-key "${coseKey}" --cose-sign1 "${coseSign1}" --json-extended --include-maps 2> /dev/stdout)
			if [ $? -ne 0 ]; then echo -e "\e[35m${verifyCip8JSON}\e[0m\n"; exit $?; fi
			unset skeyJSON

			#Getting some parameters to show
			{ read result; read coseKeyJSON; read coseSign1JSON; } <<< $(jq -r '.result, "\(.maps.COSE_Key // "-")", "\(.maps.COSE_Sign1 // "-")"' <<< ${verifyCip8JSON})
			if [[ ${result} != "true" ]]; then echo -e "\e[35mError - Could not verify the Signature\e[0m\n"; exit $?; fi

			#Replace the hashed tag true/false with 0,1
			coseSign1JSON=$(echo -n "${coseSign1JSON}" | sed 's/{"hashed":false}/0/g' | sed 's/{"hashed":true}/1/g')

			#Compose the payloadJSON
			payloadJSON="{\"1\":[1,\"0x${poolIdHex}\"],\"2\":[],\"3\":[2],\"4\": ${nonce},\"7\":\"0x${calidusPublicKey}\"}"

			#Compose the registrationMetadataJSON
			calidusRegistrationMetadataJSON=$(jq -rM <<< "{ \"867\": { \"0\": 2, \"1\": ${payloadJSON}, \"2\": [ { \"1\": ${coseKeyJSON}, \"2\": ${coseSign1JSON} } ] } }")

			echo "${calidusRegistrationMetadataJSON}" > "${calidusRegistrationFile}" 2> /dev/null

	                if [[ -f "${calidusRegistrationFile}" ]]; then #all good
				echo -e "\e[0mCalidus-Pool-Key Registration-File: \e[32m${calidusRegistrationFile}\e[90m"
				cat "${calidusRegistrationFile}"
				echo -e "\e[0m"
				echo -e "\e[0mThe Metadata-Registration-JSON File \"\e[32m${calidusRegistrationFile}\e[0m\" has been generated. :-)\n\nYou can now submit it on the chain by including it in a transaction with Script: 01_sendLovelaces.sh\nExample:\e[33m 01_sendLovelaces.sh mywallet mywallet min ${calidusRegistrationFile}\n\e[0m";
				echo
			else #hmm, something went wrong
				echo -e "\e[35mError - Something went wrong while generating the \"${calidusRegistrationFile}\" metadata file !\e[0m\n"; exit 1;
			fi


		else #generate the Calidus Pool Key Registration via cardano-signer

	                echo -e "\e[0mUsing the Calidus-KeyFile \e[32m${calidusKeyName}.calidus.vkey\e[0m and the Pool-KeyFile \e[32m${poolKeyName}.node.skey\e[0m"
			echo

			#Check about a given nonce
			if [[ ${nonce} != "" ]]; then nonceParam="--nonce ${nonce}"; else nonceParam=""; fi

			#Read in the Secret key and encrypt it if needed
			skeyJSON=$(read_skeyFILE "${poolKeyName}.node.skey"); if [ $? -ne 0 ]; then echo -e "\e[35m${skeyJSON}\e[0m\n"; exit 1; else echo -e "\e[32mOK\e[0m\n"; fi

			#Generate the registration metadata file
			echo -e "\e[0mSigning with Cardano-Signer Version: \e[32m${cardanosignerVersion}\e[0m\n";
			signerJSON=$(${cardanosigner} sign --cip88 --calidus-public-key ${calidusKeyName}.calidus.vkey --secret-key <(echo "${skeyJSON}") ${nonceParam} --json-extended 2> /dev/stdout)
			if [ $? -ne 0 ]; then echo -e "\e[35m${signerJSON}\e[0m\n"; exit $?; fi
			unset skeyJSON

			#Getting the parameters
			{ read poolIdBech; read poolIdHex; read calidusPublicKey; read calidusIdBech; read nonce; read calidusRegistrationJSON; } <<< $(jq -rM '.poolIdBech // "-", .poolIdHex // "-", .calidusPublicKey // "-", .calidusIdBech // "-", .nonce // "-", "\(.output.json // "-")"' <<< ${signerJSON})
			unset signerJSON

			echo -e "\e[0m           Pool-ID: \e[94m${poolIdBech}\e[0m"
			echo -e "\e[0m       Pool-ID-Hex: \e[32m${poolIdHex}\e[0m"
			echo -e "\e[0m        Calidus-ID: \e[94m${calidusIdBech}\e[0m"
			echo -e "\e[0m Calidus PublicKey: \e[32m${calidusPublicKey}\e[0m"
			echo -e "\e[0m             Nonce: \e[32m${nonce}\e[0m"
			echo

			#write out the registration metadata file in nice format(monochrom)
			tmp=$(jq -rM <<< ${calidusRegistrationJSON} > "${calidusRegistrationFile}" 2> /dev/stdout)
			if [ $? -ne 0 ]; then echo -e "\e[35m${tmp}\e[0m\n"; exit $?; fi

	                if [[ -f "${calidusRegistrationFile}" ]]; then #all good
				echo -e "\e[0mCalidus-Pool-Key Registration-File: \e[32m${calidusRegistrationFile}\e[90m"
				cat "${calidusRegistrationFile}"
				echo -e "\e[0m"
				echo -e "\e[0mThe Metadata-Registration-JSON File \"\e[32m${calidusRegistrationFile}\e[0m\" has been generated. :-)\n\nYou can now submit it on the chain by including it in a transaction with Script: 01_sendLovelaces.sh\nExample:\e[33m 01_sendLovelaces.sh mywallet mywallet min ${calidusRegistrationFile}\n\e[0m";
				echo
			else #hmm, something went wrong
				echo -e "\e[35mError - Something went wrong while generating the \"${calidusRegistrationFile}\" metadata file !\e[0m\n"; exit 1;
			fi

		fi

                exit 0;
                ;;


  ### Query the Calidus-VKEY / Calidus-ID / Pool-ID
  query )

	#Query only possible if not offline mode
	if ${offlineMode}; then echo -e "\e[35mYou have to be in ONLINE MODE to do this!\e[0m\n"; exit 1; fi

	#Check about input parameters
	if [[ ${paramCnt} -ne 2 ]]; then echo -e "\e[35mIncorrect parameter count!\e[0m\n"; showUsage; exit 1; fi

        paramValue=${allParameters[1]} #get the parameter behind "query". that can be a calidus public key hex, calidus-pool-key in bech format, a calidus-key.vkey file, a pool-id in bech format or a pool.node.vkey file

	#Check if its a Calidus-ID in Bech-Format
	if [[ "${paramValue:0:8}" == "calidus1" && ${#paramValue} -eq 61 ]]; then #parameter is most likely a calidus id in bech format
	        echo -ne "\e[0mCheck if given Calidus Bech-ID\e[32m ${paramValue}\e[0m is valid ..."
	        calidusIdHex=$(${bech32_bin} 2> /dev/null <<< "${paramValue,,}") #will have returncode 0 if the bech was valid
	        if [[ $? -ne 0 || ${calidusIdHex:0:2} != "a1" ]]; then echo -e "\n\n\e[91mERROR - \"${paramValue}\" is not a valid Calidus-ID.\e[0m"; exit 1; fi
	        echo -e "\e[32m OK\e[0m\n"
		calidusIdBech=${paramValue,,}
		searchType="Calidus ID";

	#Check if its a Calidus-ID file with a Bech-ID
	elif [[ -f "${paramValue}.calidus.id" ]]; then #parameter is a Calidus ID file, containing a bech32 id
		echo -ne "\e[0mReading from Calidus-ID-File\e[32m ${paramValue}.calidus.id\e[0m ..."
		calidusIdBech=$(cat "${paramValue}.calidus.id" 2> /dev/null)
		if [ $? -ne 0 ]; then echo -e "\n\n\e[91mERROR - Could not read from file \"${paramValue}.calidus.id\"\e[0m"; exit 1; fi
		echo -e "\e[32m OK\e[0m"
	        echo -ne "\e[0mCheck if Calidus Bech-ID\e[32m ${calidusIdBech}\e[0m is valid ..."
	        calidusIdHex=$(${bech32_bin} 2> /dev/null <<< "${calidusIdBech}") #will have returncode 0 if the bech was valid
	        if [[ $? -ne 0 || ${calidusIdHex:0:2} != "a1" ]]; then echo -e "\n\n\e[91mERROR - \"${calidusIdBech}\" is not a valid Calidus-ID.\e[0m"; exit 1; fi
	        echo -e "\e[32m OK\e[0m\n"
		calidusIdBech=${calidusIdBech,,}
		searchType="Calidus ID";

	#Check if its a Calidus-Public-Key-Hex
	elif [[ "${paramValue,,}" =~ ^([[:xdigit:]]{64})$ ]]; then
		echo -e "\e[0mUsing given Calidus Public-Key hex: \e[32m${paramValue,,}\e[0m\n"
		calidusPublicKeyHex="${paramValue,,}"
		searchType="Calidus Public-Key";

	#Check if its a Calidus-Public-Key-File
	elif [[ -f "${paramValue}.calidus.vkey" ]]; then #parameter was the first part of a vkey file
		echo -ne "\e[0mConverting the Calidus Vkey-File \e[32m${paramValue}.calidus.vkey\e[0m into the Calidus Public-Key ... "
		calidusVkeyCbor=$(jq -r .cborHex < "${paramValue}.calidus.vkey" 2> /dev/stdout)
		if [ $? -ne 0 ]; then echo -e "\n\n\e[91mError - ${calidusVkeyCbor}\e[0m\n"; exit 1; fi
		calidusPublicKeyHex=$(tail -c +5 <<< ${calidusVkeyCbor} 2> /dev/stdout)
		if [ $? -ne 0 ]; then echo -e "\n\n\e[91mError - ${calidusPublicKeyHex}\e[0m\n"; exit 1; fi
	        echo -e "\e[32m OK\e[0m\n"
		searchType="Calidus Public-Key";

	#Check if its a Pool-ID in Bech-Format
	elif [[ "${paramValue:0:5}" == "pool1" && ${#paramValue} -eq 56 ]]; then #parameter is most likely a bech32-pool-id
	        echo -ne "\e[0mCheck if given Pool Bech-ID\e[32m ${paramValue}\e[0m is valid ..."
	        #lets do some further testing by converting the bech32 Pool-ID into a Hex-Pool-ID
	        poolIdHex=$(${bech32_bin} 2> /dev/null <<< "${paramValue,,}") #will have returncode 0 if the bech was valid
	        if [ $? -ne 0 ]; then echo -e "\n\n\e[91mERROR - \"${paramValue}\" is not a valid Bech32 Pool-ID.\e[0m"; exit 1; fi
	        echo -e "\e[32m OK\e[0m\n"
		poolIdBech=${paramValue,,}
		searchType="Pool ID";

	#Check if its a Pool-ID File with the hex Pool-ID
	elif [[ -f "${paramValue}.pool.id" ]]; then #parameter is a Pool-ID file, containing the id in hex format
		echo -ne "\e[0mReading from Pool_ID-File\e[32m ${paramValue}.pool.id\e[0m ..."
		poolIdHex=$(cat "${paramValue}.pool.id" 2> /dev/null)
	        if [ $? -ne 0 ]; then echo -e "\n\n\e[35mERROR - Could not read from file \"${paramValue}.pool.id\"\e[0m"; exit 1; fi
		#check if the content is a valid pool hex
		if [[ ! "${poolIdHex,,}" =~ ^([[:xdigit:]]{56})$ ]]; then echo -e "\n\e[91mERROR - Content of Pool-ID File '${paramValue}.pool.id' is not a valid Pool-ID hex!\n\e[0m"; exit 1; fi
                #converting the Hex-PoolID into a Bech-PoolID
                poolIdBech=$(${bech32_bin} "pool" <<< ${poolIdHex} | tr -d '\n')
                checkError "$?"; if [ $? -ne 0 ]; then echo -e "\n\n\e[91mERROR - Could not convert the the Pool-ID File \"${paramValue}.pool.id\" into a Bech Pool-ID.\e[0m\n"; exit 1; fi
	        echo -e "\e[32m OK\e[0m\n"
		searchType="Pool ID";

	#Check if its a node Vkey File
	elif [ -f "${paramValue}.node.vkey" ]; then #there is a node.vkey file present, try to use this
		echo -ne "\e[0mConverting the Pool Vkey-File \e[32m${paramValue}.node.vkey\e[0m into a Pool-ID ... "
		nodeVkeyCbor=$(jq -r .cborHex < "${paramValue}.node.vkey" 2> /dev/stdout)
		if [ $? -ne 0 ]; then echo -e "\n\n\e[91mError - ${nodeVkeyCbor}\e[0m\n"; exit 1; fi
		#Generate the Pool-ID hex
		poolIdHex=$(tail -c +5 <<< ${nodeVkeyCbor} | xxd -r -ps | b2sum -l 224 -b | cut -d' ' -f 1)
		#check if the content is a valid pool hex
		if [[ ! "${poolIdHex,,}" =~ ^([[:xdigit:]]{56})$ ]]; then echo -e "\n\n\e[91mERROR - Could not convert the given Pool Vkey-File \"${paramValue}.node.vkey\" into a Bech Pool-ID.\e[0m\n"; exit 1; fi
                #converting the Hex-PoolID into a Bech-PoolID
                poolIdBech=$(${bech32_bin} "pool" <<< ${poolIdHex} | tr -d '\n')
                checkError "$?"; if [ $? -ne 0 ]; then echo -e "\n\n\e[91mERROR - Could not convert the given Pool Vkey-File \"${paramValue}.node.vkey\" into a Bech Pool-ID.\e[0m\n"; exit 1; fi
                echo -e "\e[32mOK\e[0m\n"
		searchType="Pool ID";

	#Query all entries
	elif [[ "${paramValue,,}" == "all" ]]; then #query all entries
	        echo -e "\e[0mQuery Calidus Pool-Keys: Filter none (\e[94mALL\e[0m)\n"
		searchType="ALL"

	#Unknown parameter
	else

		echo -e "\n\e[91mERROR - I don't know what to do with the parameter '${paramValue}'.\n\n\e[0m"; exit 1;

        fi #end of different parameters check

	#set an additional filter for the koios request depending on the input data
	case "${searchType}" in
		"Calidus Public-Key")	koiosFilter="&calidus_pub_key=eq.${calidusPublicKeyHex}";;
		"Calidus ID")		koiosFilter="&calidus_id_bech32=eq.${calidusIdBech}";;
		"Pool ID")		koiosFilter="&pool_id_bech32=eq.${poolIdBech}";;
		*)			koiosFilter="";;
	esac

	#set variables for koios request
	errorcnt=0
	error=-1

	showProcessAnimation "Query Calidus Pool-Key Info via Koios: " &
	while [[ ${errorcnt} -lt 5 && ${error} -ne 0 ]]; do #try a maximum of 5 times to request the information via koios API
		error=0
		response=$(curl -sL -m 30 -X GET -w "---spo-scripts---%{http_code}" "${koiosAPI}/pool_calidus_keys?pool_status=eq.registered&order=calidus_nonce.asc${koiosFilter}" -H "${koiosAuthorizationHeader}" -H "Accept: application/json" 2> /dev/null)
                if [ $? -ne 0 ]; then error=1; fi;
                errorcnt=$(( ${errorcnt} + 1 ))
        done
	stopProcessAnimation;
        if [[ ${error} -ne 0 ]]; then echo -e "\e[91mSORRY - Query of the Koios-API via curl failed, tried 5 times.\e[0m\n"; exit 1; fi; #curl query failed

        #Split the response string into JSON content and the HTTP-ResponseCode
        if [[ "${response}" =~ (.*)---spo-scripts---([0-9]*)* ]]; then
                responseJSON="${BASH_REMATCH[1]}"
                responseCode="${BASH_REMATCH[2]}"
        else
                echo -e "\e[91mSORRY - Query of the Koios-API via curl failed. Could not separate Content and ResponseCode.\e[0m\n"; exit 1; #curl query failed
        fi

        #Check the responseCode
        case ${responseCode} in
                "200" ) ;; #all good, continue
                * )     echo -e "\e[91mSORRY - HTTP Response code: ${responseCode}\e[0m\n"; exit 1; #exit with a failure and the http response code
        esac;

	jsonRet=$(jq -r . <<< "${responseJSON}" 2> /dev/null)
	if [ $? -ne 0 ]; then echo -e "\e[91mSORRY - Query via Koios-API (${koiosAPI}) failed, not a JSON response.\e[0m\n"; exit 1; fi; #reponse is not a json file

	#Get the number of entries and show them all
	calidusEntryCount=$(jq -r "length" <<< "${jsonRet}" 2> /dev/null)
	if [[ ${calidusEntryCount} -eq 0 ]]; then echo -e "${iconNo} \e[91mNo entries found :-(\e[0m\n"; exit 1; fi;

	echo -e "${iconYes} \e[0mFound \e[32m${calidusEntryCount} entry/entries\e[0m for your request :-)\n"

	#color the results depending on the requested input
	colorCalidusPublicKey="\e[32m"
	colorCalidusID="\e[32m"
	colorPoolID="\e[32m"
	colorHighlight="\e[94m"
	case "${searchType}" in
		"Calidus Public-Key")	colorCalidusPublicKey=${colorHighlight};;
		"Calidus ID")		colorCalidusID=${colorHighlight};;
		"Pool ID"|"ALL")	colorPoolID=${colorHighlight};;
	esac

	#Show all the results
	for (( tmpCnt=0; tmpCnt<${calidusEntryCount}; tmpCnt++ ))
	do

		#get all the values
	        { read poolIdBech;
	          read calidusNonce;
	          read calidusPublicKeyHex;
	          read calidusIdBech;
	          read txHash;
	          read epochNo;
		  read blockTime; } <<< $(jq -r ".[${tmpCnt}] | .pool_id_bech32 // \"-\", .calidus_nonce // \"-\", .calidus_pub_key // \"-\", .calidus_id_bech32 // \"-\", .tx_hash // \"-\", .epoch_no // \"-\", .block_time // \"-\"" <<< ${jsonRet} 2> /dev/null)

		#show them to the user
		echo -e "\e[0m              Date: $(date --date=@${blockTime})\e[0m"
		echo -e "\e[0m           Pool-ID: ${colorPoolID}${poolIdBech}\e[0m"
		echo -e "\e[0m        Calidus-ID: ${colorCalidusID}${calidusIdBech}\e[0m"
		echo -e "\e[0m Calidus PublicKey: ${colorCalidusPublicKey}${calidusPublicKeyHex}\e[0m"
		echo -e "\e[0m     Calidus Nonce: \e[90m${calidusNonce}\e[0m"
		echo -e "\e[0m             Epoch: \e[90m${epochNo}\e[0m"
		echo -e "\e[0m           Tx-Hash: \e[90m${txHash}\e[0m"
		echo

	done

	#Get the number of unique Calidus-Keys
	uniqCalidusKeyCount=$(jq -r "[.[].calidus_id_bech32] | unique | length" <<< ${jsonRet} 2> /dev/null)
	if [[ ${uniqCalidusKeyCount} -ge 1 && ${calidusEntryCount} -gt 1 ]]; then echo -e "${iconYes} \e[0mStats: \e[32m${uniqCalidusKeyCount} unique\e[0m Calidus Keys for \e[32m${calidusEntryCount} registered\e[0m Pools\n"; fi
	;;


  * )	showUsage; exit 1;
	;;
esac

