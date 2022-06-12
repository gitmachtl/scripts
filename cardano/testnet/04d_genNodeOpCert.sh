#!/bin/bash

# Script is brought to you by ATADA_Stakepool, Telegram @atada_stakepool

#load variables from common.sh
#       socket          Path to the node.socket (also exports socket to CARDANO_NODE_SOCKET_PATH)
#       genesisfile     Path to the genesis.json
#       magicparam      TestnetMagic parameter
#       cardanocli      Path to the cardano-cli executable
#       cardanonode     Path to the cardano-node executable
. "$(dirname "$0")"/00_common.sh

if [[ $# -ge 1 && ! $1 == "" ]]; then nodeName=$1; else echo -e "Usage: $0 <NodePoolName> (Optional: newOpCertCounterValue)\n\n"; exit 2; fi
if [[ $# -eq 2 ]]; then useOpCertCounter=$2; if [[ -z "${useOpCertCounter##*[!0-9]*}" ]]; then echo -e "\nError - Given OpCertCounter value is not a pos. number !\n\n"; exit 2; fi; fi #if there is an optional given number for the next OpCertCounter

#Node must be fully synced for the online query of the OpCertCounter
if ${onlineMode}; then
	#check that the node is fully synced, otherwise the opcertcounter query could return a false state
	if [[ $(get_currentSync) != "synced" ]]; then echo -e "\e[35mError - Node not fully synced !\e[0m\n"; exit 2; fi
fi


#check that *.node.skey/hwsfile is present
if ! [[ -f "${nodeName}.node.skey" || -f "${nodeName}.node.hwsfile" ]]; then echo -e "\e[0mERROR - Cannot find '${nodeName}.node.skey/hwsfile', please generate Node Keys with ${nodeName}.node.counter first with script 04a ...\e[0m"; exit 2; fi

#check that there is are new kes keys present by checking the counters. If counterfiles are present, check that the values are identical
if [[ -f "${nodeName}.kes.counter" && -f "${nodeName}.kes.counter-next" ]]; then
	latestKESnumber=$(cat ${nodeName}.kes.counter); latestKESnumber=$(printf "%03d" $((10#${latestKESnumber})) )
	nextKESnumber=$(cat ${nodeName}.kes.counter-next); nextKESnumber=$(printf "%03d" $((10#${nextKESnumber})) )
	if [[ "${latestKESnumber}" != "${nextKESnumber}" ]]; then echo -e "\n\e[35mERROR - Please generate new KES Keys first using script 04c !\e[0m\n"; exit 2; fi
else
	echo -e "\n\e[35mERROR - Please generate new KES Keys first using script 04c !\e[0m\n"; exit 2;
fi


loop=0
question="Do you wanna use the given OpCertCounter"
#
#Entering the Loop of generating a new OpCert. Loop will autoexit if the results are ok. Otherwise ask the user to rerun the script and correct the OpCertCounter
#
#
while true; do


#check if there was a new given "useOpCertCounter" value
if [[ "${useOpCertCounter}" != "" ]]; then

					if ask "\e[33m${question} '${useOpCertCounter}' as the next one?" Y; then

						poolNodeCounter=${useOpCertCounter}; #set to the given value
						if [ ! -f "${nodeName}.node.vkey" ]; then echo -e "\n\e[35mERROR - Cannot find '${nodeName}.node.vkey', please generate Node Keys first with script 04a ...\e[0m\n"; exit 2; fi
						file_unlock "${nodeName}.node.counter"
						${cardanocli} node new-counter --cold-verification-key-file ${nodeName}.node.vkey --counter-value ${poolNodeCounter} --operational-certificate-issue-counter-file ${nodeName}.node.counter
						checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
						#NodeCounter file was written, now add the description in the file to reflect the next node counter number
						newCounterJSON=$(jq ".description = \"Next certificate issue number: $((${poolNodeCounter}+0))\"" < "${nodeName}.node.counter")
						checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
						echo "${newCounterJSON}" > "${nodeName}.node.counter"
						checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
						file_lock "${nodeName}.node.counter"

						echo -e "\n\e[0mThe \e[32m${nodeName}.node.counter\e[0m file was updated with the index: \e[32m${poolNodeCounter}\e[0m\n";

					elif [[ ${loop} -eq 1 ]]; then echo; echo -e "\e[35mABORT - Opcert Generation aborted...\e[0m"; echo; exit 2;

					fi

fi


#check if there is a node.counter file, if not, ask about generating a new one
if [ ! -f "${nodeName}.node.counter" ]; then

					if ask "\e[33mCannot find '${nodeName}.node.counter', do you wanna create a new one?" N; then

							poolNodeCounter=0; #set to zero for now
							if [ ! -f "${nodeName}.node.vkey" ]; then echo -e "\n\e[35mERROR - Cannot find '${nodeName}.node.vkey', please generate Node Keys first with script 04a ...\e[0m\n"; exit 2; fi
							${cardanocli} node new-counter --cold-verification-key-file ${nodeName}.node.vkey --counter-value ${poolNodeCounter} --operational-certificate-issue-counter-file ${nodeName}.node.counter
							checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
							#NodeCounter file was written, now add the description in the file to reflect the next node counter number
							newCounterJSON=$(jq ".description = \"Next certificate issue number: $((${poolNodeCounter}+0))\"" < "${nodeName}.node.counter")
							checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
							echo "${newCounterJSON}" > "${nodeName}.node.counter"
							checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
							file_lock "${nodeName}.node.counter"

							echo -e "\n\e[0mAn new ${nodeName}.node.counter File was created with index ${poolNodeCounter}. You can now rerun this script 04d again to generate the opcert.\n\n\e[0m"; exit 1;
					else

					echo -e "\n\e[35mERROR - Cannot create new OperationalCertificate (opcert) without a '${nodeName}.node.counter' file!\n\e[0m"; exit 2;

					fi
fi

echo
echo -e "\e[0mIssue a new Node operational certificate using KES-vKey \e[32m${nodeName}.kes-${latestKESnumber}.vkey\e[0m and Cold-sKey \e[32m${nodeName}.node.skey/hwsfile\e[0m:"
echo

#Static
slotLength=$(cat ${genesisfile} | jq -r .slotLength)                    #In Secs
epochLength=$(cat ${genesisfile} | jq -r .epochLength)                  #In Secs
slotsPerKESPeriod=$(cat ${genesisfile} | jq -r .slotsPerKESPeriod)      #Number
startTimeByron=$(cat ${genesisfile_byron} | jq -r .startTime)           #In Secs(abs)
startTimeGenesis=$(cat ${genesisfile} | jq -r .systemStart)             #In Text
startTimeSec=$(date --date=${startTimeGenesis} +%s)                     #In Secs(abs)
transTimeEnd=$(( ${startTimeSec}+(${byronToShelleyEpochs}*${epochLength}) ))                 #In Secs(abs) End of the TransitionPhase = Start of KES Period 0
byronSlots=$(( (${startTimeSec}-${startTimeByron}) / 20 ))              #NumSlots between ByronChainStart and ShelleyGenesisStart(TransitionStart)
transSlots=$(( (${byronToShelleyEpochs}*${epochLength}) / 20 ))                         #NumSlots in the TransitionPhase

#Dynamic
currentTimeSec=$(date -u +%s)                                           #In Secs(abs)

#Calculate current slot
if [[ "${currentTimeSec}" -lt "${transTimeEnd}" ]];
        then #In Transistion Phase between ShelleyGenesisStart and TransitionEnd
        currentSlot=$(( ${byronSlots} + (${currentTimeSec}-${startTimeSec}) / 20 ))
        else #After Transition Phase
        currentSlot=$(( ${byronSlots} + ${transSlots} + ((${currentTimeSec}-${transTimeEnd}) / ${slotLength}) ))
fi

#Calculating KES period
currentKESperiod=$(( (${currentSlot}-${byronSlots}) / (${slotsPerKESPeriod}*${slotLength}) ))
if [[ "${currentKESperiod}" -lt 0 ]]; then currentKESperiod=0; fi

echo -e "\e[0mCurrent KES period:\e[32m ${currentKESperiod}\e[0m"
echo

#Calculating Expire KES Period and Date/Time
maxKESEvolutions=$(cat ${genesisfile} | jq -r .maxKESEvolutions)
expiresKESperiod=$(( ${currentKESperiod} + ${maxKESEvolutions} ))
#expireTimeSec=$(( ${transTimeEnd} + (${slotLength}*${expiresKESperiod}*${slotsPerKESPeriod}) ))
expireTimeSec=$(( ${currentTimeSec} + (${slotLength}*${maxKESEvolutions}*${slotsPerKESPeriod}) ))
expireDate=$(date --date=@${expireTimeSec})

file_unlock ${nodeName}.kes-expire.json
echo -e "{\n\t\"latestKESfileindex\": \"${latestKESnumber}\",\n\t\"currentKESperiod\": \"${currentKESperiod}\",\n\t\"expireKESperiod\": \"${expiresKESperiod}\",\n\t\"expireKESdate\": \"${expireDate}\"\n}" > ${nodeName}.kes-expire.json
file_lock ${nodeName}.kes-expire.json


#Generate the opcert from a classic cli node skey or from a hwsfile (hw-wallet)
if [ -f "${nodeName}.node.skey" ]; then #key is a normal one
                echo -ne "\e[0mGenerating a new opcert from a cli signing key '\e[33m${nodeName}.node.skey\e[0m' ... "
		file_unlock ${nodeName}.node-${latestKESnumber}.opcert
		file_unlock ${nodeName}.node.counter
		${cardanocli} node issue-op-cert --hot-kes-verification-key-file ${nodeName}.kes-${latestKESnumber}.vkey --cold-signing-key-file ${nodeName}.node.skey --operational-certificate-issue-counter ${nodeName}.node.counter --kes-period ${currentKESperiod} --out-file ${nodeName}.node-${latestKESnumber}.opcert
		checkError "$?"; if [ $? -ne 0 ]; then file_lock ${nodeName}.node-${latestKESnumber}.opcert; file_lock ${nodeName}.node.counter; exit $?; fi
		file_lock ${nodeName}.node-${latestKESnumber}.opcert
		file_lock ${nodeName}.node.counter

elif [ -f "${nodeName}.node.hwsfile" ]; then #key is a hardware wallet
                if ! ask "\e[0mGenerating the new opcert from a local Hardware-Wallet keyfile '\e[33m${nodeName}.node.hwsfile\e[0m', continue?" Y; then echo; echo -e "\e[35mABORT - Opcert Generation aborted...\e[0m"; echo; exit 2; fi

                start_HwWallet "Ledger"; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
		file_unlock ${nodeName}.node-${latestKESnumber}.opcert
		file_unlock ${nodeName}.node.counter
                tmp=$(${cardanohwcli} node issue-op-cert --kes-verification-key-file ${nodeName}.kes-${latestKESnumber}.vkey --kes-period ${currentKESperiod} --operational-certificate-issue-counter ${nodeName}.node.counter --hw-signing-file ${nodeName}.node.hwsfile --out-file ${nodeName}.node-${latestKESnumber}.opcert 2> /dev/stdout)
                if [[ "${tmp^^}" =~ (ERROR|DISCONNECT) ]]; then echo -e "\e[35m${tmp}\e[0m\n"; file_lock ${nodeName}.node-${latestKESnumber}.opcert; file_lock ${nodeName}.node.counter; exit 1; else echo -e "\e[32mDONE\e[0m"; fi
		file_lock ${nodeName}.node-${latestKESnumber}.opcert
		file_lock ${nodeName}.node.counter
                checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
else
     		echo -e "\e[35mError - Node Cold Signing Key for \"${nodeName}\" not found. No ${nodeName}.node.skey/hwsfile found !\e[0m\n"; exit 1;
fi

echo -e "\e[32mOK\e[0m\n"

#in onlineMode, check the opcert file against the current chain status to use the right OpCertCounter value
if ${onlineMode}; then
echo -ne "\e[0mChecking operational certificate \e[32m${nodeName}.node-${latestKESnumber}.opcert\e[0m for the right OpCertCounter ... "

	#query the current opcertstate from the chain
	queryFile="${tempDir}/${nodeName}.query"
	rm ${queryFile} 2> /dev/null
	tmp=$(${cardanocli} query kes-period-info ${magicparam} --op-cert-file ${nodeName}.node-${latestKESnumber}.opcert --out-file ${queryFile} 2> /dev/null);
	if [ $? -ne 0 ]; then echo -e "\n\n\e[35mError - Couldn't query the onChain OpCertCounter state !\e[0m"; echo; exit 2; fi

	onChainOpcertCount=$(jq -r ".qKesNodeStateOperationalCertificateNumber | select (.!=null)" 2> /dev/null ${queryFile}); if [[ ${onChainOpcertCount} == "" ]]; then onChainOpcertCount=-1; fi #if there is none, set it to -1
	onDiskOpcertCount=$(jq -r ".qKesOnDiskOperationalCertificateNumber | select (.!=null)" 2> /dev/null ${queryFile});
	rm ${queryFile} 2> /dev/null

	nextChainOpcertCount=$(( ${onChainOpcertCount} + 1 )); #the next opcert counter that should be used on the chain is the last seen one + 1

	if [[ ${nextChainOpcertCount} -eq ${onDiskOpcertCount} ]]; then
		echo -e "\e[32mOK\e[0m\n";
		echo -e "\e[0mLatest OnChain Counter: \e[32m${onChainOpcertCount//-1/not used yet}\e[0m"
		echo -e "\e[0mNext Counter should be: \e[32m${nextChainOpcertCount}\e[0m"
		echo -e "\e[0m     OnDisk Counter is: \e[32m${onDiskOpcertCount}\e[0m"
		echo
		break; #exit the while loop


 	else
		echo -e "\e[35mFALSE\e[0m\n";
		echo -e "\e[0mLatest OnChain Counter: \e[32m${onChainOpcertCount//-1/not used yet}\e[0m"
		echo -e "\e[0mNext Counter should be: \e[32m${nextChainOpcertCount}\e[0m"
		echo -e "\e[0m     OnDisk Counter Is: \e[35m${onDiskOpcertCount}\e[0m"
		echo

		#Issued OpCert is having the wrong Counter, so delete the files directly
		file_unlock "${nodeName}.node-${latestKESnumber}.opcert"
		rm "${nodeName}.node-${latestKESnumber}.opcert"

		useOpCertCounter=${nextChainOpcertCount}
		loop=1
		question="Do you wanna use the correct OpCertCounter"
		echo

	fi


else #offlinemode

	break; #exit the while loop in offline mode, we cannot query anything further here

fi #onlinemode

done #WHILE Loop



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

nextKESnumber=$(printf "%03d" $(( 10#${nextKESnumber} + 1 ))) #setting the next KES indexnumber
file_unlock "${nodeName}.kes.counter-next"
echo ${nextKESnumber} > "${nodeName}.kes.counter-next"
file_lock "${nodeName}.kes.counter-next"

echo
echo -e "\e[0mUpdated KES-Next-Counter:\e[32m ${nodeName}.kes.counter-next\e[90m"
cat ${nodeName}.kes.counter-next
echo

echo -e "\e[0mNew \e[32m${nodeName}.kes-${latestKESnumber}.skey\e[0m and \e[32m${nodeName}.node-${latestKESnumber}.opcert\e[0m files ready for upload to the server."
echo

if ${offlineMode}; then echo -e "\e[33mThis was generated in Offline-Mode, please verify the new OpCertCounter on an Online-Machine like:\n\e[36m./04e_checkNodeOpCert.sh ${nodeName}.node-${latestKESnumber}.opcert next\e[0m\n"; fi

echo -e "\e[0m\n"
