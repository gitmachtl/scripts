#!/bin/bash

# Script is brought to you by ATADA_Stakepool, Telegram @atada_stakepool

#load variables from common.sh
#       socket          Path to the node.socket (also exports socket to CARDANO_NODE_SOCKET_PATH)
#       genesisfile     Path to the genesis.json
#       magicparam      TestnetMagic parameter
#       cardanocli      Path to the cardano-cli executable
#       cardanonode     Path to the cardano-node executable
. "$(dirname "$0")"/00_common.sh

if [[ $# -eq 1 && ! $1 == "" ]]; then nodeName=$1; else echo "ERROR - Usage: $0 <name>"; exit 2; fi

#check that *.kes.counter and *.node.counter is present
if [ ! -f "${nodeName}.kes.counter" ]; then echo -e "\e[0mERROR - Please generate new KES Keys with ${nodeName}.kes.counter first ...\e[0m"; exit 2; fi
if [ ! -f "${nodeName}.node.counter" ]; then echo -e "\e[0mERROR - Please generate Node Keys with ${nodeName}.node.counter first with script 04a ...\e[0m"; exit 2; fi


#grab the next issue number from the counter file
nextKESnumber=$(cat ${nodeName}.node.counter | jq -r .description | awk 'match($0,/Next certificate issue number: [0-9]+/) {print substr($0, RSTART+31,RLENGTH-31)}')
nextKESnumber=$(printf "%03d" ${nextKESnumber})  #to get a nice 4 digit output

#grab the latest generated KES number
latestKESnumber=$(cat ${nodeName}.kes.counter)

if [[ ! "${nextKESnumber}" == "${latestKESnumber}" ]]; then echo -e "\e[0mERROR - Please generate new KES Keys first ...\e[0m"; exit 2; fi

echo
echo -e "\e[0mIssue a new Node operational certificate using KES-vKey \e[32m${nodeName}.kes-${latestKESnumber}.vkey\e[0m and Cold-sKey \e[32m${nodeName}.node.skey\e[0m:"
echo

#Static
slotLength=$(cat ${genesisfile} | jq -r .slotLength)                    #In Secs
epochLength=$(cat ${genesisfile} | jq -r .epochLength)                  #In Secs
slotsPerKESPeriod=$(cat ${genesisfile} | jq -r .slotsPerKESPeriod)      #Number
startTimeByron=$(cat ${genesisfile_byron} | jq -r .startTime)           #In Secs(abs)
startTimeGenesis=$(cat ${genesisfile} | jq -r .systemStart)             #In Text
startTimeSec=$(date --date=${startTimeGenesis} +%s)                     #In Secs(abs)
transTimeEnd=$(( ${startTimeSec}+(2*${epochLength}) ))                  #In Secs(abs) End of the TransitionPhase = Start of KES Period 0
slotsPerKESPeriod=$(cat ${genesisfile} | jq -r .slotsPerKESPeriod)	#Number

#Dynamic
currentTimeSec=$(date -u +%s)                                           #In Secs(abs)

#Calculating KES period
currentKESperiod=$(( (${currentTimeSec}-${transTimeEnd}) / (${slotsPerKESPeriod}*${slotLength}) ))
if [[ "${currentKESperiod}" -lt 0 ]]; then currentKESperiod=0; fi

#Calculating Expire KES Period and Date/Time
maxKESEvolutions=$(cat ${genesisfile} | jq -r .maxKESEvolutions)
expiresKESperiod=$(( ${currentKESperiod} + ${maxKESEvolutions} ))
expireTimeSec=$(( ${transTimeEnd} + (${slotLength}*${expiresKESperiod}*${slotsPerKESPeriod}) ))
expireDate=$(date --date=@${expireTimeSec} -R)



file_unlock ${nodeName}.kes-expire.json
echo -e "{\n\t\"latestKESfileindex\": \"${latestKESnumber}\",\n\t\"currentKESperiod\": \"${currentKESperiod}\",\n\t\"expireKESperiod\": \"${expiresKESperiod}\",\n\t\"expireKESdate\": \"${expireDate}\"\n}" > ${nodeName}.kes-expire.json
file_lock ${nodeName}.kes-expire.json

echo -e "\e[0mCurrent KES period:\e[32m ${currentKESperiod}\e[90m"
echo


file_unlock ${nodeName}.node-${latestKESnumber}.opcert
file_unlock ${nodeName}.node.counter

${cardanocli} shelley node issue-op-cert --hot-kes-verification-key-file ${nodeName}.kes-${latestKESnumber}.vkey --cold-signing-key-file ${nodeName}.node.skey --operational-certificate-issue-counter ${nodeName}.node.counter --kes-period ${currentKESperiod} --out-file ${nodeName}.node-${latestKESnumber}.opcert
checkError "$?"

file_lock ${nodeName}.node-${latestKESnumber}.opcert
file_lock ${nodeName}.node.counter


echo
echo -e "\e[0mNode operational certificate:\e[32m ${nodeName}.node-${latestKESnumber}.opcert \e[90m"
cat ${nodeName}.node-${latestKESnumber}.opcert
echo

echo
echo -e "\e[0mUpdated Operational Certificate Issue Counter:\e[32m ${nodeName}.node.counter \e[90m"
cat ${nodeName}.node.counter
echo

echo
echo -e "\e[0mUpdated Expire date json:\e[32m ${nodeName}.kes-expire.json \e[90m"
cat ${nodeName}.kes-expire.json
echo


echo -e "\e[0mNew \e[32m${nodeName}.kes-${latestKESnumber}.skey\e[0m and \e[32m${nodeName}.node-${latestKESnumber}.opcert\e[0m files ready for upload to the server."
echo

echo -e "\e[0m\n"
