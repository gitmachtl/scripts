#!/bin/bash

# Script is brought to you by ATADA_Stakepool, Telegram @atada_stakepool

#load variables from common.sh
#       socket          Path to the node.socket (also exports socket to CARDANO_NODE_SOCKET_PATH)
#       genesisfile     Path to the genesis.json
#       magicparam      TestnetMagic parameter
#       cardanocli      Path to the cardano-cli executable
#       cardanonode     Path to the cardano-node executable
. "$(dirname "$0")"/00_common.sh

if [[ $# -eq 1 && ! $1 == "" ]]; then nodeName=$1; else echo "ERROR - Usage: $0 <NodePoolName>"; exit 2; fi

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

${cardanocli} node key-gen-KES --verification-key-file ${nodeName}.kes-${nextKESnumber}.vkey --signing-key-file ${nodeName}.kes-${nextKESnumber}.skey
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
file_lock ${nodeName}.kes-${nextKESnumber}.vkey
file_lock ${nodeName}.kes-${nextKESnumber}.skey

echo -e "\e[0mNode operational KES-Verification-Key:\e[32m ${nodeName}.kes-${nextKESnumber}.vkey \e[90m"
cat ${nodeName}.kes-${nextKESnumber}.vkey
echo

echo -e "\e[0mNode operational KES-Signing-Key:\e[32m ${nodeName}.kes-${nextKESnumber}.skey \e[90m"
cat ${nodeName}.kes-${nextKESnumber}.skey
echo

file_unlock ${nodeName}.kes.counter
echo ${nextKESnumber} > ${nodeName}.kes.counter
file_lock ${nodeName}.kes.counter
echo -e "\e[0mUpdated KES-Counter:\e[32m ${nodeName}.kes.counter \e[90m"
cat ${nodeName}.kes.counter
echo

echo -e "\e[0m\n"
