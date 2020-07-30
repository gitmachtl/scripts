#!/bin/bash
. "$(dirname "$0")"/00_common.sh

#Helper functions
convertsecs() {
 ((h=(${1}+0)/3600))
 ((m=((${1}+0)%3600)/60))
 ((s=(${1}+0)%60))
 printf "%03dh %02dm %02ds\n" $h $m $s
}

# Byron to Shelley Epoch Transition Length
byronToShelleyEpochs=208

currentEpoch=$(get_currentEpoch)
timeUntilNextEpoch=$(convertsecs $(get_timeUntilNextEpoch))

echo -e "Current EPOCH: ${currentEpoch}"
echo -e "Time until next EPOCH: ${timeUntilNextEpoch}"

#Static
slotLength=$(cat ${genesisfile} | jq -r .slotLength) 			#In Secs
epochLength=$(cat ${genesisfile} | jq -r .epochLength)			#In Secs
slotsPerKESPeriod=$(cat ${genesisfile} | jq -r .slotsPerKESPeriod)	#Number
startTimeByron=$(cat ${genesisfile_byron} | jq -r .startTime) 		#In Secs(abs)
#startTimeByron=1506203091
startTimeGenesis=$(cat ${genesisfile} | jq -r .systemStart)		#In Text
startTimeSec=$(date --date=${startTimeGenesis} +%s) 			#In Secs(abs)
transTimeEnd=$(( ${startTimeSec}+(${byronToShelleyEpochs}*${epochLength}) )) 			#In Secs(abs) End of the TransitionPhase
byronSlots=$(( (${startTimeSec}-${startTimeByron}) / 20 ))  		#NumSlots between ByronChainStart and ShelleyGenesisStart(TransitionStart)
transSlots=$(( (${byronToShelleyEpochs}*${epochLength}) / 20 ))				#NumSlots in the TransitionPhase

#Dynamic
currentTimeSec=$(date -u +%s) 						#In Secs(abs)

#Calculate current slot
if [[ "${currentTimeSec}" -lt "${transTimeEnd}" ]];
	then #In Transistion Phase between ShelleyGenesisStart and TransitionEnd
	currentSlot=$(( ${byronSlots} + (${currentTimeSec}-${startTimeSec}) / 20 ))
	else #After Transition Phase
	currentSlot=$(( ${byronSlots} + ${transSlots} + ((${currentTimeSec}-${transTimeEnd}) / ${slotLength}) ))
fi

#currentKESperiod=$(( (${currentTimeSec}-${transTimeEnd}) / (${slotsPerKESPeriod}*${slotLength}) ))
currentKESperiod=$(( (${currentSlot}-${byronSlots}) / (${slotsPerKESPeriod}*${slotLength}) ))

#Calculating Expire KES Period and Date/Time
maxKESEvolutions=$(cat ${genesisfile} | jq -r .maxKESEvolutions)
expiresKESperiod=$(( ${currentKESperiod} + ${maxKESEvolutions} ))
#expireTimeSec=$(( ${transTimeEnd} + (${slotLength}*${expiresKESperiod}*${slotsPerKESPeriod}) ))
expireTimeSec=$(( ${currentTimeSec} + (${slotLength}*${maxKESEvolutions}*${slotsPerKESPeriod}) ))
expireDate=$(date --date=@${expireTimeSec})

echo -e "Current KES Period: ${currentKESperiod}"
echo -e "KES Keys expire after Period: ${expiresKESperiod} (${expireDate})"

echo -e "Current Slot: ${currentSlot}      (byronSlots=${byronSlots}  transSlots=${transSlots})"
#echo -e "ByronStartTime: ${startTimeByron}"
#echo -e "ShelleyStartTime: ${startTimeSec}"
#echo -e "TransTimeEnd: ${transTimeEnd}"
#echo -e "CurrentTimeSec: ${currentTimeSec}"
