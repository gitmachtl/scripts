#!/bin/bash

# Script is brought to you by ATADA_Stakepool, Telegram @atada_stakepool

#load variables from common.sh
#       socket          Path to the node.socket (also exports socket to CARDANO_NODE_SOCKET_PATH)
#       genesisfile     Path to the genesis.json
#       magicparam      TestnetMagic parameter
#       cardanocli      Path to the cardano-cli executable
#       cardanonode     Path to the cardano-node executable
. "$(dirname "$0")"/00_common.sh

#Check command line parameter
if [ $# -lt 2 ] || [[ ! ${2^^} =~ ^(CLI|HW)$ ]]; then
cat >&2 <<EOF
ERROR - Usage: $(basename $0) <PolicyName> <KeyType: cli | hw> [Optional valid xxx Slots, Policy invalid after xxx Slots (default=unlimited)]

Examples:
$(basename $0) assets/mypolicy cli      ... generates an unlimited Policy with CLI keys (was default method before)
$(basename $0) assets/mypolicy cli 600  ... This would generate CLI-Key Policy 'mypolicy' in the folder 'assets' limited to 600 Slots (600 Seconds) from now.
                                                 No Token minting or burning would be possible after that time, starting now!

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


#warnings
if [ -f "${policyName}.policy.vkey" ]; then echo -e "\e[35mWARNING - ${policyName}.policy.vkey already present, delete it or use another name !\e[0m"; exit 2; fi
if [[ -f "${policyName}.policy.skey" || -f "${policyName}.policy.hwsfile" ]]; then echo -e "\e[35mWARNING - ${policyName}.policy.skey/hwsfile already present, delete it or use another name !\e[0m"; exit 2; fi
if [ -f "${policyName}.policy.script" ]; then echo -e "\e[35mWARNING - ${policyName}.policy.script already present, delete it or use another name !\e[0m"; exit 2; fi
if [ -f "${policyName}.policy.id" ]; then echo -e "\e[35mWARNING - ${policyName}.policy.id already present, delete it or use another name !\e[0m"; exit 2; fi

#Check if the destination directory for the policy exists, if not, try to make it
policyDirName="$(dirname ${policyName})"; policyDirName=${policyDirName/#.\//};
if [ ! -d "${policyDirName}" ]; then mkdir -p ${policyDirName}; checkError "$?"; fi


if [[ ${keyType^^} == "CLI" ]]; then #Building it from the cli

	${cardanocli} address key-gen --verification-key-file ${policyName}.policy.vkey --signing-key-file ${policyName}.policy.skey
	checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
	file_lock ${policyName}.policy.vkey
	file_lock ${policyName}.policy.skey

	echo -e "\e[0mPolicy-Verification-Key: \e[32m ${policyName}.policy.vkey \e[90m"
	cat ${policyName}.policy.vkey | jq
	echo
	echo -e "\e[0mPolicy-Signing-Key: \e[32m ${policyName}.policy.skey \e[90m"
	cat ${policyName}.policy.skey | jq
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

if [[ ${keyType^^} == "CLI" ]]; then #generate the policyID via cli command
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

