#!/bin/bash

#load variables from common.sh
#       socket          Path to the node.socket (also exports socket to CARDANO_NODE_SOCKET_PATH)
#       genesisfile     Path to the genesis.json
#       magicparam      TestnetMagic paramter
. "$(dirname "$0")"/00_common.sh

if [[ ! $1 == "" ]]; then addrName=$1; else echo "ERROR - Usage: $0 <AdressName>"; exit 2; fi

checkAddr=$(cat ${addrName}.addr)

echo
echo -e "\e[0mChecking UTXO of Address-File\e[32m ${addrName}.addr\e[0m: ${checkAddr}"
echo

#Get UTX0 Data for the address
utx0=$(${cardanocli} shelley query utxo --address ${checkAddr} ${magicparam})
utx0linecnt=$(echo "${utx0}" | wc -l)
txcnt=$((${utx0linecnt}-2))

if [[ ${txcnt} -lt 1 ]]; then echo -e "\e[35mNo funds on the Address!\e[0m"; exit; else echo -e "\e[32m${txcnt} UTXOs\e[0m found on the Address!"; fi
echo

#Calculating the total amount of lovelaces in all utxos on this address
totalLovelaces=0
txInString=""

while IFS= read -r utx0entry
do
fromHASH=$(echo ${utx0entry} | awk '{print $1}')
fromINDEX=$(echo ${utx0entry} | awk '{print $2}')
sourceLovelaces=$(echo ${utx0entry} | awk '{print $3}')
echo -e "HASH: ${fromHASH}\tIdx: ${fromINDEX}\tAmount: ${sourceLovelaces}"
totalLovelaces=$((${totalLovelaces}+${sourceLovelaces}))
done < <(printf "${utx0}\n" | tail -n ${txcnt})

echo -e "\e[0m-----------------------------------------------------------------------------------------------------"
echo -e "Total lovelaces in UTX0:\e[32m  ${totalLovelaces} lovelaces \e[90m"
echo
