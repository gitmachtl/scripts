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

if [[ $# -ge 1 && ! $1 == "" ]]; then nodeName=$1; else echo -e "Usage: $0 <NodePoolName> (Optional: newOpCertCounterValue)\n\n"; exit 2; fi
if [[ $# -eq 2 ]]; then useOpCertCounter=$2; if [[ -z "${useOpCertCounter##*[!0-9]*}" ]]; then echo -e "\nError - Given OpCertCounter value is not a pos. number !\n\n"; exit 2; fi; fi #if there is an optional given number for the next OpCertCounter

#Node must be fully synced for the online query of the OpCertCounter
if ${onlineMode}; then
	#check that the node is fully synced, otherwise the opcertcounter query could return a false state
	if [[ $(get_currentSync) != "synced" ]]; then echo -e "\e[35mError - Node not fully synced !\e[0m\n"; exit 2; fi
fi


#check that *.node.skey/hwsfile is present, we also need the *.node.vkey for the poolID and maybe for an opcert generation
if ! [[ -f "${nodeName}.node.skey" || -f "${nodeName}.node.hwsfile" ]]; then echo -e "\e[0mERROR - Cannot find '${nodeName}.node.skey/hwsfile', please generate Node Keys with ${nodeName}.node.counter first with script 04a ...\e[0m"; exit 2; fi
if [ ! -f "${nodeName}.node.vkey" ]; then echo -e "\n\e[35mERROR - Cannot find '${nodeName}.node.vkey', please generate Node Keys first with script 04a ...\e[0m\n"; exit 2; fi


#check that there is a new kes keys present by checking the counters. If counterfiles are present, check that the values are identical
if [[ -f "${nodeName}.kes.counter" && -f "${nodeName}.kes.counter-next" ]]; then
	latestKESnumber=$(cat ${nodeName}.kes.counter); latestKESnumber=$(printf "%03d" $((10#${latestKESnumber})) )
	nextKESnumber=$(cat ${nodeName}.kes.counter-next); nextKESnumber=$(printf "%03d" $((10#${nextKESnumber})) )
	if [[ "${latestKESnumber}" != "${nextKESnumber}" ]]; then echo -e "\n\e[35mERROR - Please generate new KES Keys first using script 04c !\e[0m\n"; exit 2; fi
else
	echo -e "\n\e[35mERROR - Please generate new KES Keys first using script 04c !\e[0m\n"; exit 2;
fi


kesVkeyFile="${nodeName}.kes-${latestKESnumber}.vkey"
if ! [[ -f "${kesVkeyFile}" ]]; then echo -e "\e[0mERROR - Cannot find '${kesVkeyFile}', please generate new KES Keys first using script 04c !\e[0m"; exit 2; fi


loop=0
question="Do you wanna use the given OpCertCounter"
skeyJSON=""
#
#Entering the Loop of generating a new OpCert. Loop will autoexit if the results are ok. Otherwise ask the user to rerun the script and correct the OpCertCounter
#
#
while true; do

#check if there was a new given "useOpCertCounter" value
if [[ "${useOpCertCounter}" != "" ]]; then

					if ask "\e[33m${question} '${useOpCertCounter}' as the next one?" Y; then

						poolNodeCounter=${useOpCertCounter}; #set to the given value
						file_unlock "${nodeName}.node.counter"
						${cardanocli} ${cliEra} node new-counter --cold-verification-key-file ${nodeName}.node.vkey --counter-value ${poolNodeCounter} --operational-certificate-issue-counter-file ${nodeName}.node.counter
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
							${cardanocli} ${cliEra} node new-counter --cold-verification-key-file ${nodeName}.node.vkey --counter-value ${poolNodeCounter} --operational-certificate-issue-counter-file ${nodeName}.node.counter
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
echo -e "\e[0mIssue a new Node operational certificate using KES-vKey \e[32m${kesVkeyFile}\e[0m and Cold-sKey \e[32m${nodeName}.node.skey/hwsfile\e[0m:"
echo

#Reading kesVkeyFile cborHex to show the Vkey-Bech32-String
kesVkeyBech=$(jq -r .cborHex ${kesVkeyFile} 2> /dev/null | tail -c +5 | ${bech32_bin} "kes_vk" 2> /dev/null)
echo -e "\e[0mKES-vKey-File Bech:\e[32m ${kesVkeyBech}\e[0m"

#PoolID from node.vkey file
poolID=$(${cardanocli} ${cliEra} stake-pool id --cold-verification-key-file "${nodeName}.node.vkey" --output-format bech32 2> /dev/null);
echo -e "\e[0mOpcert for Pool-ID:\e[32m ${poolID}\e[0m"
echo

#Calculating KES period
currentSlot=$(get_currentTip); checkError "$?";

#Check the presence of the genesisfile (shelley)
if [[ ! -f "${genesisfile}" ]]; then majorError "Path ERROR - Path to the shelley genesis file '${genesisfile}' is wrong or the file is missing!"; exit 1; fi
{ read slotLength; read slotsPerKESPeriod; read maxKESEvolutions; } <<< $(jq -r ".slotLength // \"null\", .slotsPerKESPeriod // \"null\", .maxKESEvolutions // \"null\"" < ${genesisfile} 2> /dev/null)

currentKESperiod=$(( ${currentSlot} / (${slotsPerKESPeriod}*${slotLength}) ))
if [[ "${currentKESperiod}" -lt 0 ]]; then currentKESperiod=0; fi
echo -e "\e[0mCurrent KES period:\e[32m ${currentKESperiod}\e[0m\n"

#Calculating Expire KES Period and Date/Time
currentTimeSec=$(date -u +%s)
expiresKESperiod=$(( ${currentKESperiod} + ${maxKESEvolutions} ))
expireTimeSec=$(( ${currentTimeSec} + (${slotLength}*${maxKESEvolutions}*${slotsPerKESPeriod}) ))
expireDate=$(date --date=@${expireTimeSec})

file_unlock ${nodeName}.kes-expire.json
echo -e "{\n\t\"latestKESfileindex\": \"${latestKESnumber}\",\n\t\"currentKESperiod\": \"${currentKESperiod}\",\n\t\"expireKESperiod\": \"${expiresKESperiod}\",\n\t\"expireKESdate\": \"${expireDate}\"\n}" > ${nodeName}.kes-expire.json
file_lock ${nodeName}.kes-expire.json

opcertFile="${nodeName}.node-${latestKESnumber}.opcert"

#Generate the opcert from a classic cli node skey or from a hwsfile (hw-wallet)
if [ -f "${nodeName}.node.skey" ]; then #key is a normal one

	        #read the needed signing keys into ram, this whole part is running in a big while loop for the opcert autocorrection, so only load new skeyJSON if it was empty
	        if [[ "${skeyJSON}" == "" ]]; then
						skeyJSON=$(read_skeyFILE "${nodeName}.node.skey"); if [ $? -ne 0 ]; then echo -e "\e[35m${skeyJSON}\e[0m\n"; exit 1; else echo -e "\e[32mOK\e[0m\n"; fi
		fi

                echo -ne "\e[0mGenerating a new opcert from a cli signing key '\e[33m${nodeName}.node.skey\e[0m' ... "
		file_unlock ${opcertFile}
		file_unlock ${nodeName}.node.counter
		${cardanocli} ${cliEra} node issue-op-cert --hot-kes-verification-key-file ${kesVkeyFile} --cold-signing-key-file <(echo "${skeyJSON}") --operational-certificate-issue-counter-file ${nodeName}.node.counter --kes-period ${currentKESperiod} --out-file ${opcertFile}
		checkError "$?"; if [ $? -ne 0 ]; then file_lock ${opcertFile}; file_lock ${nodeName}.node.counter; exit $?; fi
		file_lock ${opcertFile}
		file_lock ${nodeName}.node.counter

elif [ -f "${nodeName}.node.hwsfile" ]; then #key is a hardware wallet

                if ! ask "\e[0mGenerating the new opcert from a local Hardware-Wallet keyfile '\e[33m${nodeName}.node.hwsfile\e[0m', continue?" Y; then echo; echo -e "\e[35mABORT - Opcert Generation aborted...\e[0m"; echo; exit 2; fi

                start_HwWallet "Ledger|Keystone"; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
		file_unlock ${opcertFile}
		file_unlock ${nodeName}.node.counter
                tmp=$(${cardanohwcli} node issue-op-cert --kes-verification-key-file ${kesVkeyFile} --kes-period ${currentKESperiod} --operational-certificate-issue-counter-file ${nodeName}.node.counter --hw-signing-file ${nodeName}.node.hwsfile --out-file ${opcertFile} 2> /dev/stdout)
                if [[ "${tmp^^}" =~ (ERROR|DISCONNECT) ]]; then echo -e "\e[35m${tmp}\e[0m\n"; file_lock ${opcertFile}; file_lock ${nodeName}.node.counter; exit 1; else echo -e "\e[32mDONE\e[0m"; fi
		file_lock ${opcertFile}
		file_lock ${nodeName}.node.counter
                checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
else
     		echo -e "\e[35mError - Node Cold Signing Key for \"${nodeName}\" not found. No ${nodeName}.node.skey/hwsfile found !\e[0m\n"; exit 1;
fi

echo -e "\e[32mOK\e[0m\n"

#in onlineMode, check the opcert file against the current chain status to use the right OpCertCounter value
if ${onlineMode}; then

	case ${workMode} in

	"online")
		echo -e "\e[0mChecking operational certificate \e[32m${opcertFile}\e[0m for the right OpCertCounter:"
		echo

	        #check that the node is fully synced, otherwise the opcertcounter query could return a false state
	        if [[ $(get_currentSync) != "synced" ]]; then echo -e "\e[35mError - Node not fully synced !\e[0m\n"; exit 2; fi

		#query the current opcertstate from the local node
		queryFile="${tempDir}/opcert.query"
		rm ${queryFile} 2> /dev/null
		tmp=$(${cardanocli} ${cliEra} query kes-period-info --op-cert-file ${opcertFile} --out-file ${queryFile} 2> /dev/stdout);
		if [ $? -ne 0 ]; then echo -e "\n\n\e[35mError - Couldn't query the onChain OpCertCounter state !\n${tmp}\e[0m"; echo; exit 2; fi

		onChainOpcertCount=$(jq -r ".qKesNodeStateOperationalCertificateNumber | select (.!=null)" 2> /dev/null ${queryFile}); if [[ ${onChainOpcertCount} == "" ]]; then onChainOpcertCount=-1; fi #if there is none, set it to -1
		onDiskOpcertCount=$(jq -r ".qKesOnDiskOperationalCertificateNumber | select (.!=null)" 2> /dev/null ${queryFile});
		rm ${queryFile} 2> /dev/null

	        echo -e "\e[0mThe last known OpCertCounter on the chain is: \e[32m${onChainOpcertCount//-1/not used yet}\e[0m"
		;;

	"light")
		#query the current opcertstate via online api
		echo -e "\e[0mChecking the OpCertCounter for the Pool-ID \e[32m${poolID}\e[0m via ${koiosAPI}:"
		echo
		#query poolinfo via poolid on koios
		showProcessAnimation "Query Pool-Info via Koios: " &
		response=$(curl -sL -m 30 -X POST "${koiosAPI}/pool_info" -H "${koiosAuthorizationHeader}" -H "Accept: application/json" -H "Content-Type: application/json" -d "{\"_pool_bech32_ids\":[\"${poolID}\"]}" 2> /dev/null)
		stopProcessAnimation;
		tmp=$(jq -r . <<< ${response}); if [ $? -ne 0 ]; then echo -e "\n\n\e[35mError - Koios API request sent not back a valid JSON !\e[0m"; echo; exit 2; fi
		#check if the received json only contains one entry in the array (will also not be 1 if not a valid json)
		if [[ $(jq ". | length" 2> /dev/null <<< ${response}) -eq 1 ]]; then
			onChainOpcertCount=$(jq -r ".[0].op_cert_counter | select (.!=null)" 2> /dev/null <<< ${response})
			poolName=$(jq -r ".[0].meta_json.name | select (.!=null)" 2> /dev/null <<< ${response})
			poolTicker=$(jq -r ".[0].meta_json.ticker | select (.!=null)" 2> /dev/null <<< ${response})
			echo -e "\e[0mGot the information back for the Pool: \e[32m${poolName} (${poolTicker})\e[0m"
			echo
		        echo -e "\e[0mThe last known OpCertCounter on the chain is: \e[32m${onChainOpcertCount}\e[0m"
		else
			echo -e "\e[0mThere is no information available from the chain about the OpCertCounter. Looks like the pool has not made a block yet.\nSo we are going with a next counter of \e[33m0\e[0m"
			onChainOpcertCount=-1 #if there is none, set it to -1
		fi

		#lets read out the onDiscOpcertNumber directly from the opcert file
		cborHex=$(jq -r ".cborHex" "${opcertFile}" 2> /dev/null);
		if [ $? -ne 0 ]; then echo -e "\n\n\e[35mError - Couldn't read the opcert file '${opcertFile}' !\e[0m"; echo; exit 2; fi
		onDiskOpcertCount=$(int_from_cbor "${cborHex:72}") #opcert counter starts at index 72, lets decode the unsigned integer number
		if [ $? -ne 0 ]; then echo -e "\n\n\e[35mError - Couldn't decode opcert counter from file '${opcertFile}' !\e[0m"; echo; exit 2; fi
#		onDiskKESStart=$(int_from_cbor "${cborHex:72}" 1) #kes start counter is the next number after the opcert number, so lets skip 1 number
#		echo -e "\e[0m  File KES start Period: \e[35m${onDiskKESStart}\e[0m"
		;;


	*)	exit;;

	esac

	nextChainOpcertCount=$(( ${onChainOpcertCount} + 1 )); #the next opcert counter that should be used on the chain is the last seen one + 1

	echo

	if [[ ${nextChainOpcertCount} -eq ${onDiskOpcertCount} ]]; then
		echo -e "\e[0mCheck: \e[32mOK\e[0m\n";
		echo -e "\e[0mLatest OnChain Counter: \e[32m${onChainOpcertCount//-1/not used yet}\e[0m"
		echo -e "\e[0mNext Counter should be: \e[32m${nextChainOpcertCount}\e[0m"
		echo -e "\e[0m     OnDisk Counter is: \e[32m${onDiskOpcertCount}\e[0m"
		echo
		break; #exit the while loop

	else
		echo -e "\e[0mCheck: \e[35mFALSE\e[0m\n";
		echo -e "\e[0mLatest OnChain Counter: \e[32m${onChainOpcertCount//-1/not used yet}\e[0m"
		echo -e "\e[0mNext Counter should be: \e[32m${nextChainOpcertCount}\e[0m"
		echo -e "\e[0m     OnDisk Counter Is: \e[35m${onDiskOpcertCount}\e[0m"
		echo

		#Issued OpCert is having the wrong Counter, so delete the files directly
		file_unlock "${opcertFile}"
		rm "${opcertFile}"

		useOpCertCounter=${nextChainOpcertCount}
		loop=1
		question="Do you wanna use the correct OpCertCounter"
		echo

	fi


else #offlinemode

	break; #exit the while loop in offline mode, we cannot query anything further here

fi #onlinemode

done #WHILE Loop

#forget the signing keys
unset skeyJSON




echo -e "\e[0mNode operational certificate:\e[32m ${opcertFile} \e[90m"
cat ${opcertFile}
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

echo -e "\e[0mNew \e[32m${nodeName}.kes-${latestKESnumber}.skey\e[0m and \e[32m${opcertFile}\e[0m files ready for upload to the server."
echo

if ${offlineMode}; then echo -e "\e[33mThis was generated in Offline-Mode, please verify the new OpCertCounter on an Online-Machine like:\n\e[36m./04e_checkNodeOpCert.sh ${opcertFile} next\e[0m\n"; fi

echo -e "\e[0m\n"
