#!/bin/bash
. "$(dirname "$0")"/00_common.sh

#Helper functions
convertsecs() {
 ((h=(${1}+0)/3600))
 ((m=((${1}+0)%3600)/60))
 ((s=(${1}+0)%60))
 printf "%03dh %02dm %02ds\n" $h $m $s
}

currentEpoch=$(get_currentEpoch)
timeUntilNextEpoch=$(convertsecs $(get_timeUntilNextEpoch))

echo -e "Current EPOCH: ${currentEpoch}"
echo -e "Time until next EPOCH: ${timeUntilNextEpoch}"

#Calculating current KES-Period
startTimeGenesis=$(cat ${genesisfile} | jq -r .systemStart)
startTimeSec=$(date --date=${startTimeGenesis} +%s)
currentTimeSec=$(date -u +%s)
slotsPerKESPeriod=$(cat ${genesisfile} | jq -r .slotsPerKESPeriod)
slotLength=$(cat ${genesisfile} | jq -r .slotLength)
currentKESperiod=$(( (${currentTimeSec}-${startTimeSec}) / (${slotsPerKESPeriod}*${slotLength}) ))

#Calculating Expire KES Period and Date/Time
maxKESEvolutions=$(cat ${genesisfile} | jq -r .maxKESEvolutions)
expiresKESperiod=$(( ${currentKESperiod} + ${maxKESEvolutions} ))
expireTimeSec=$(( ${startTimeSec} + (${slotLength}*${expiresKESperiod}*${slotsPerKESPeriod}) ))
expireDate=$(date --date=@${expireTimeSec})

echo -e "Current KES Period: ${currentKESperiod}"
echo -e "KES Keys expire after Period: ${expiresKESperiod} (${expireDate})"

#Calculate current slot
currentSlot=$(( (${currentTimeSec}-${startTimeSec}) / ${slotLength} ))
echo -e "Current Slot: ${currentSlot}"
