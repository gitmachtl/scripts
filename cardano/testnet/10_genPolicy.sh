#!/bin/bash

# Script is brought to you by ATADA_Stakepool, Telegram @atada_stakepool

#load variables from common.sh
#       socket          Path to the node.socket (also exports socket to CARDANO_NODE_SOCKET_PATH)
#       genesisfile     Path to the genesis.json
#       magicparam      TestnetMagic parameter
#       cardanocli      Path to the cardano-cli executable
#       cardanonode     Path to the cardano-node executable
. "$(dirname "$0")"/00_common.sh

case $# in

  1|2 ) policyName=$1;;

  * ) cat >&2 <<EOF
Usage:    $(basename $0) <PolicyName> [Optional valid xxx Slots, Policy invalid after xxx Slots (default=unlimited)]


Example:  $(basename $0) assets/mypolicy 600

          This would generate Policy 'mypolicy' in the folder 'assets' limited to 600 Slots (600 Seconds) from now.
          No Token minting or burning would be possible after that time, starting now!

EOF
  exit 1;; esac

if [[ $# -eq 2 && $2 -gt 0 ]]; then validBefore=$(( $(get_currentTip) + ${2} )); else validBefore="unlimited"; fi

#warnings
if [ -f "${policyName}.policy.vkey" ]; then echo -e "\e[35mWARNING - ${policyName}.policy.vkey already present, delete it or use another name !\e[0m"; exit 2; fi
if [ -f "${policyName}.policy.skey" ]; then echo -e "\e[35mWARNING - ${policyName}.policy.skey already present, delete it or use another name !\e[0m"; exit 2; fi
if [ -f "${policyName}.policy.script" ]; then echo -e "\e[35mWARNING - ${policyName}.policy.script already present, delete it or use another name !\e[0m"; exit 2; fi
if [ -f "${policyName}.policy.id" ]; then echo -e "\e[35mWARNING - ${policyName}.policy.id already present, delete it or use another name !\e[0m"; exit 2; fi

#Check if the destination directory for the policy exists, if not, try to make it
policyDirName="$(dirname ${policyName})"; policyDirName=${policyDirName/#.\//};
if [ ! -d "${policyDirName}" ]; then mkdir -p ${policyDirName}; checkError "$?"; fi

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

policyKeyHASH=$(${cardanocli} address key-hash --payment-verification-key-file ${policyName}.policy.vkey)

currentTip=$(get_currentTip)
echo -e "\e[0mCurrent Slot-Height:\e[32m ${currentTip} \e[0m"
echo -e "\e[0mPolicy valid before Slot-Height:\e[33m ${validBefore}\e[0m"
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

policyID=$(${cardanocli} transaction policyid --script-file ${policyName}.policy.script)
echo -e "${policyID}" > ${policyName}.policy.id
echo -e "\e[0mPolicy-ID: \e[32m ${policyName}.policy.id \e[90m"
file_lock ${policyName}.policy.id
cat ${policyName}.policy.id
echo

echo -e "\e[0m\n"

