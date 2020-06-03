#!/bin/bash

# Script is brought to you by ATADA_Stakepool, Telegram @atada_stakepool

#load variables from common.sh
#       socket          Path to the node.socket (also exports socket to CARDANO_NODE_SOCKET_PATH)
#       genesisfile     Path to the genesis.json
#       magicparam      TestnetMagic parameter
#       cardanocli      Path to the cardano-cli executable
#       cardanonode     Path to the cardano-node executable
. "$(dirname "$0")"/00_common.sh

if [[ $# -eq 1 && ! $1 == "" ]]; then addrName=$1; else echo "ERROR - Usage: $0 <name>"; exit 2; fi

#check that *.kes.counter and *.node.counter is present
if [ ! -f "${addrName}.kes.counter" ]; then echo -e "\e[0mERROR - Please generate new KES Keys with ${addrName}.kes.counter first ...\e[0m"; exit 2; fi
if [ ! -f "${addrName}.node.counter" ]; then echo -e "\e[0mERROR - Please generate Node Keys with ${addrName}.node.counter first with script 04a ...\e[0m"; exit 2; fi


#grab the next issue number from the counter file
nextKESnumber=$(cat ${addrName}.node.counter | awk 'match($0,/Next certificate issue number: [0-9]+/) {print substr($0, RSTART+31,RLENGTH-31)}')
nextKESnumber=$(printf "%03d" ${nextKESnumber})  #to get a nice 4 digit output

#grab the latest generated KES number
latestKESnumber=$(cat ${addrName}.kes.counter)

if [[ ! "${nextKESnumber}" == "${latestKESnumber}" ]]; then echo -e "\e[0mERROR - Please generate new KES Keys first ...\e[0m"; exit 2; fi

echo
echo -e "\e[0mIssue a new Node operational certificate using KES-vKey \e[32m${addrName}.kes-${latestKESnumber}.vkey\e[0m and Cold-sKey \e[32m${addrName}.node.skey\e[0m:"
echo

#calculating current KES period
startTimeGenesis=$(cat ${genesisfile} | jq -r .startTime)
startTimeSec=$(date --date=${startTimeGenesis} +%s)	#in seconds (UTC)
currentTimeSec=$(date -u +%s)				#in seconds (UTC)
slotsPerKESPeriod=$(cat ${genesisfile} | jq -r .slotsPerKESPeriod)
slotLength=$(cat ${genesisfile} | jq -r .slotLength)
currentKESperiod=$(( (${currentTimeSec}-${startTimeSec}) / (${slotsPerKESPeriod}*${slotLength}) ))  #returns a integer number, we like that

#Calculating Expire KES Period and Date/Time
maxKESEvolutions=$(cat ${genesisfile} | jq -r .maxKESEvolutions)
expiresKESperiod=$(( ${currentKESperiod} + ${maxKESEvolutions} ))
expireTimeSec=$(( ${startTimeSec} + ( ${slotLength} * ${expiresKESperiod} * ${slotsPerKESPeriod} ) ))
expireDate=$(date --date=@${expireTimeSec})

file_unlock ${addrName}.kes-expire.json
echo -e "{\n\t\"latestKESfileindex\": ${latestKESnumber},\n\t\"currentKESperiod\": ${currentKESperiod},\n\t\"expireKESperiod\": ${expiresKESperiod},\n\t\"expireKESdate\": \"${expireDate}\"\n}" > ${addrName}.kes-expire.json
file_lock ${addrName}.kes-expire.json

echo -e "\e[0mCurrent KES period:\e[32m ${currentKESperiod}\e[90m"
echo


file_unlock ${addrName}.node-${latestKESnumber}.opcert
file_unlock ${addrName}.node.counter

${cardanocli} shelley node issue-op-cert --hot-kes-verification-key-file ${addrName}.kes-${latestKESnumber}.vkey --cold-signing-key-file ${addrName}.node.skey --operational-certificate-issue-counter ${addrName}.node.counter --kes-period ${currentKESperiod} --out-file ${addrName}.node-${latestKESnumber}.opcert

file_lock ${addrName}.node-${latestKESnumber}.opcert
file_lock ${addrName}.node.counter


echo
echo -e "\e[0mNode operational certificate:\e[32m ${addrName}.node-${latestKESnumber}.opcert \e[90m"
cat ${addrName}.node-${latestKESnumber}.opcert
echo

echo
echo -e "\e[0mUpdated Operational Certificate Issue Counter:\e[32m ${addrName}.node.counter \e[90m"
cat ${addrName}.node.counter
echo

echo
echo -e "\e[0mUpdated Expire date json:\e[32m ${addrName}.kes-expire.json \e[90m"
cat ${addrName}.kes-expire.json
echo


echo -e "\e[0mNew \e[32m${addrName}.kes-${latestKESnumber}.skey\e[0m and \e[32m${addrName}.node-${latestKESnumber}.opcert\e[0m files ready for upload to the server."
echo


