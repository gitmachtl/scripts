#!/bin/bash

# Script is brought to you by ATADA_Stakepool, Telegram @atada_stakepool

#load variables from common.sh
#       socket          Path to the node.socket (also exports socket to CARDANO_NODE_SOCKET_PATH)
#       genesisfile     Path to the genesis.json
#       magicparam      TestnetMagic parameter
#       cardanocli      Path to the cardano-cli executable
#       cardanonode     Path to the cardano-node executable
. "$(dirname "$0")"/00_common.sh

#Display usage instructions
showUsage() {
cat >&2 <<EOF

Usage: $(basename $0) <OpCertFilename* or PoolNodeName* or PoolID> <checkType for *: current | next>


Examples for detailed results via LocalNode (OpCertFile):

$(basename $0) mypool current
	... searches for the latest OpCertFile of mypool and checks it to be used as the CURRENT OpCert making blocks

$(basename $0) mypool next
	... searches for the latest OpCertFile of mypool and checks it to be used as the NEXT OpCert making blocks

$(basename $0) mypool.node-003.opcert current
	... uses the given OpCertFile and checks it to be used as the CURRENT OpCert making blocks

$(basename $0) mypool.node-003.opcert next
	... uses the given OpCertFile and checks it to be used as the NEXT OpCert making blocks

---

Examples only for the OpCertCounter via Koios (PoolID):

$(basename $0) pool1qqqqqdk4zhsjuxxd8jyvwncf5eucfskz0xjjj64fdmlgj735lr9
	... is looking up the current OpCertCounter via Koios for the given Bech32-Pool-ID

$(basename $0) 00000036d515e12e18cd3c88c74f09a67984c2c279a5296aa96efe89
	... is looking up the current OpCertCounter via Koios for the given HEX-Pool-ID

$(basename $0) mypool
	... is looking up the current OpCertCounter via Koios for the mypool.pool.id-bech file


EOF
}

#Check commandline parameters
#no params
if [[ $# -eq 0 ]]; then $(showUsage); exit 1; fi

#two params, but second one is not CURRENT or NEXT
if [ $# -eq 2 ] && [[ ! ${2^^} =~ ^(CURRENT|NEXT)$ ]]; then $(showUsage); exit 1; fi

#two params, second one is CURRENT or NEXT -> check the local OpCertFile
if [ $# -eq 2 ] && [[ ${2^^} =~ ^(CURRENT|NEXT)$ ]]; then

	checkSource="localFile";
	opCertFile=${1};
	checkType=${2^^};

	#Check that the given OpCertFile exists, first try to use the given file itself. After that, try to find the latest one for the given poolNodeName
	if [ ! -f "${opCertFile}" ]; then #not a direct file link, try to find the opcert
		opCertFile=$(ls -v "${opCertFile}".node-*.opcert 2> /dev/null | tail -n 1) #sorted by "version number" and only used the last entry
		if [ "${opCertFile}" != "" ]; then #if a file was found, ask if it should be used
			if ask "\e[33mShould the file '${opCertFile}' be used for the check?" Y; then
			echo
			else
			echo
			echo -e "\e[35mPlease specify the right OpCert-File name, thx.\e[0m\n"; exit 1;
		fi
		else
		echo -e "\e[35mError - Cannot find the given OpCertFile! If you don't have one, create one via scripts 04c & 04d.\e[0m\n"; exit 1;
		fi
	fi
fi

#only one parameter, its a pool-id
if [ $# -eq 1 ]; then
	poolID=${1,,} #lowercase for the given parameter

	#Check if the provided Pool-ID is a Hex-PoolID(length56) or a Bech32-PoolID(length56 and starting with pool1)
	if [[ "${poolID//[![:xdigit:]]}" == "${poolID}" && ${#poolID} -eq 56 ]]; then #parameter is a hex-poolid
	        echo
		echo -ne "\e[0mConverting HEX-Pool-ID \e[32m${poolID}\e[0m into Bech32: ";
	        ret=$(${bech32_bin} pool 2> /dev/null <<< "${poolID}") #will have returncode 0 if ok
	        if [ $? -ne 0 ]; then echo -e "\n\e[35mERROR - \"${poolID}\" couldn't be converted into a Bech32 format.\e[0m\n"; exit 1; fi
		poolID=${ret}
		echo -e "\e[32m${poolID}\e[0m" #poolID now in Bech32 format
		echo
		checkSource="poolID";

	#Bech32 Pool-ID
	elif [[ "${poolID:0:5}" == "pool1" && ${#poolID} -eq 56 ]]; then #parameter is most likely a bech32-poolid

	        #lets do some further testing by converting the beche32 pool-id into a hex-pool-id
	        tmp=$(${bech32_bin} 2> /dev/null <<< "${poolID}") #will have returncode 0 if the bech was valid
	        if [ $? -ne 0 ]; then echo -e "\n\e[35mERROR - \"${poolID}\" is not a valid Bech32-Pool-ID.\e[0m\n"; exit 1; fi
		checkSource="poolID";

	#Pool-ID file
	elif [ -f "${1}.pool.id-bech" ]; then
		poolIDfile="${1}.pool.id-bech"
		echo -e "\e[0mFound a file '${poolIDfile}', if you wanna do a detailed check, specify CURRENT or NEXT as\nthe 2nd parameter so the OpCertFile will be used instead of the Pool-ID!"
		if ask "\e[33mShould the Pool-ID from the file '${1}.pool.id-bech' be used for the OpCertCounter query?" Y; then
			echo
			poolID=$(cat ${poolIDfile})
			checkSource="poolID";
		else
		echo -e "\e[35mError - Cannot resolve the given PoolID!\e[0m\n"; $(showUsage);
		opCertFile=$(ls -v "${1}".node-*.opcert 2> /dev/null | tail -n 1) #sorted by "version number" and only used the last entry
			if [ "${opCertFile}" != "" ]; then #if a file was found, show a suggestion how to run the script
			echo -e "\n\e[0mYou could try to run:\n\e[33m$(basename $0) ${1} current\n\e[0mif you wanna use the latest OpCertFile '${opCertFile}'\n\n"; exit 1;
			fi
		fi
	else
		echo -e "\e[35mError - Cannot resolve the given PoolID!\e[0m\n"; $(showUsage); exit 1;
	fi

fi


#####
#
# Checking against a local OpCert File
#
####
if [[ "${checkSource}" == "localFile" ]]; then


#Node must be fully synced for the online query of the OpCertCounter, show info if starting in offline mode
if ${onlineMode}; then
	#check that the node is fully synced, otherwise the opcertcounter query could return a false state
	if [[ $(get_currentSync) != "synced" ]]; then echo -e "\e[35mError - Node not fully synced !\e[0m\n"; exit 2; fi
else
#Check can only be done in online mode
	echo -e "\e[35mYou have to be in ONLINE MODE to do this!\e[0m\n"; exit 1;
fi


echo -e "\e[0mChecking OpCertFile \e[32m${opCertFile}\e[0m for the correct OpCertCounter and KES-Interval:"
echo

#Dynamic
currentTimeSec=$(date -u +%s)                                           #In Secs(abs)
currentSlot=$(get_currentTip)
currentEPOCH=$(get_currentEpoch)
maxKESEvolutions=$(cat ${genesisfile} | jq -r .maxKESEvolutions)

#Static
slotLength=$(cat ${genesisfile} | jq -r .slotLength)                    #In Secs
slotsPerKESPeriod=$(cat ${genesisfile} | jq -r .slotsPerKESPeriod)      #Number

#Calculating KES period
currentKESperiod=$(( ${currentSlot} / (${slotsPerKESPeriod}*${slotLength}) ))
if [[ "${currentKESperiod}" -lt 0 ]]; then currentKESperiod=0; fi

echo -e "\e[0mCurrent EPOCH:\e[32m ${currentEPOCH}\e[0m"
echo

#query the current opcertstate from the chain
queryFile="${tempDir}/${nodeName}.query"
rm ${queryFile} 2> /dev/null

showProcessAnimation "Query operational certificate for the right values: " &
tmp=$(${cardanocli} query kes-period-info ${magicparam} --op-cert-file ${opCertFile} --out-file ${queryFile} 2> /dev/null);
stopProcessAnimation;
if [ $? -ne 0 ]; then echo -e "\n\n\e[35mError - Couldn't query the onChain OpCertCounter state !\e[0m"; echo; exit 2; fi
onChainOpcertCount=$(jq -r ".qKesNodeStateOperationalCertificateNumber | select (.!=null)" 2> /dev/null ${queryFile}); if [[ ${onChainOpcertCount} == "" ]]; then onChainOpcertCount=-1; fi #if there is none, set it to -1
onDiskOpcertCount=$(jq -r ".qKesOnDiskOperationalCertificateNumber | select (.!=null)" 2> /dev/null ${queryFile});
onDiskKESStart=$(jq -r ".qKesStartKesInterval | select (.!=null)" 2> /dev/null ${queryFile});
rm ${queryFile} 2> /dev/null
echo

#Verifying right KES Interval
echo -ne "\e[0mKES-Interval Check: "
expireKESperiod=$(( ${onDiskKESStart} + ${maxKESEvolutions} ))
kesError="false"

if [[ ${currentKESperiod} -ge ${onDiskKESStart} && ${currentKESperiod} -le ${expireKESperiod} ]]; then
	echo -e "\e[32mOK, within range\e[0m\n";
	echo -e "\e[0m    Current KES Period: \e[32m${currentKESperiod}\e[0m"
	echo -e "\e[0m File KES start Period: \e[32m${onDiskKESStart}\e[0m"
	echo -e "\e[0mFile KES expiry Period: \e[32m${expireKESperiod}\e[0m"
	echo

 	else
	echo -e "\e[35mFALSE, out of range !\e[0m\n";
	echo -e "\e[0m    Current KES Period: \e[32m${currentKESperiod}\e[0m"
	echo -e "\e[0m File KES start Period: \e[35m${onDiskKESStart}\e[0m"
	echo -e "\e[0mFile KES expiry Period: \e[35m${expireKESperiod}\e[0m"
	echo
	kesError="true"
fi

echo

nextChainOpcertCount=$(( ${onChainOpcertCount} + 1 )); #the next opcert counter that should be used on the chain is the last seen one + 1

 if [[ "${checkType}" == "NEXT" ]]; then
	#Verifying right OpCertCounter for the next OpCertCertificate used to make blocks
	echo -ne "\e[0mOpCertCounter Check - For NEXT usage: "

	if [[ ${nextChainOpcertCount} -eq ${onDiskOpcertCount} ]]; then
		echo -e "\e[32mOK, is latest+1\e[0m\n";
		echo -e "\e[0mLatest OnChain Counter: \e[32m${onChainOpcertCount//-1/not used yet}\e[0m"
		echo -e "\e[0mNext Counter should be: \e[32m${nextChainOpcertCount}\e[0m"
		echo -e "\e[0m       File Counter is: \e[32m${onDiskOpcertCount}\e[0m"
		echo
		if [[ ${kesError} == "true" ]]; then
			echo -e "\e[35mPlease generate a new OpCertFile with the same CounterNumber \e[33m${nextChainOpcertCount}\e[35m because of the KES-Error like:"
			echo -e "\e[33m./04c_genKESKeys.sh <poolNodeName>\e[0m"
			echo -e "\e[33m./04d_genNodeOpCert.sh <poolNodeName> ${nextChainOpcertCount}\e[0m"
		fi

	 	else
		echo -e "\e[35mFALSE, not latest+1\e[0m\n";
		echo -e "\e[0mLatest OnChain Counter: \e[32m${onChainOpcertCount//-1/not used yet}\e[0m"
		echo -e "\e[0mNext Counter should be: \e[32m${nextChainOpcertCount}\e[0m"
		echo -e "\e[0m       File Counter is: \e[35m${onDiskOpcertCount}\e[0m"
		echo
		echo -e "\e[35mPlease use the CounterNumber \e[33m${nextChainOpcertCount}\e[35m to generate a correct new OpCertFile using Scripts 04c & 04d like:"
		echo -e "\e[33m./04c_genKESKeys.sh <poolNodeName>\e[0m"
		echo -e "\e[33m./04d_genNodeOpCert.sh <poolNodeName> ${nextChainOpcertCount}\e[0m"

	fi

 else

	#Verifying right OpCertCounter for the currently used OpCertCertificate making blocks
	echo -ne "\e[0mOpCertCounter Check - CURRENTLY used: "

	if [[ ${onChainOpcertCount} -eq -1 && ${onDiskOpcertCount} -eq 0 ]]; then #No block generated yet

		echo -e "\e[32mOK, no block generated yet. File Counter 0 is the right current one.\e[0m\n";
		echo -e "\e[0mLatest OnChain Counter: \e[32m${onChainOpcertCount//-1/not used yet}\e[0m"
		echo -e "\e[0m       File Counter is: \e[32m${onDiskOpcertCount}\e[0m"
		echo -e "\e[0mNext Counter should be: \e[32m${nextChainOpcertCount}\e[0m"
		echo
		if [[ ${kesError} == "true" ]]; then
			echo -e "\e[35mPlease generate a new OpCertFile with the next CounterNumber \e[33m${nextChainOpcertCount}\e[35m because of the KES-Error like:"
			echo -e "\e[33m./04c_genKESKeys.sh <poolNodeName>\e[0m"
			echo -e "\e[33m./04d_genNodeOpCert.sh <poolNodeName> ${nextChainOpcertCount}\e[0m"
		fi

	elif [[ ${onChainOpcertCount} -eq ${onDiskOpcertCount} ]]; then	#Counters are equal

		echo -e "\e[32mOK, current File Counter matches the onChain one.\e[0m\n";
		echo -e "\e[0mLatest OnChain Counter: \e[32m${onChainOpcertCount//-1/not used yet}\e[0m"
		echo -e "\e[0m       File Counter is: \e[32m${onDiskOpcertCount}\e[0m"
		echo -e "\e[0mNext Counter should be: \e[32m${nextChainOpcertCount}\e[0m"
		echo
		if [[ ${kesError} == "true" ]]; then
			echo -e "\e[35mPlease generate a new OpCertFile with the next CounterNumber \e[33m${nextChainOpcertCount}\e[35m because of the KES-Error like:"
			echo -e "\e[33m./04c_genKESKeys.sh <poolNodeName>\e[0m"
			echo -e "\e[33m./04d_genNodeOpCert.sh <poolNodeName> ${nextChainOpcertCount}\e[0m"
		fi

 	else #Counters are not equal
		echo -e "\e[35mFALSE, OnChain Counter NOT equal to File Counter\e[0m\n";
		echo -e "\e[0mLatest OnChain Counter: \e[32m${onChainOpcertCount//-1/not used yet}\e[0m"
		echo -e "\e[0m       File Counter is: \e[35m${onDiskOpcertCount}\e[0m"
		echo

	fi

 fi

fi ##### Checking against a local OpCert File


#####
#
# Checking against a Bech32-Pool-ID
#
####
if [[ "${checkSource}" == "poolID" ]]; then

#Only possible in onlineMode -> KOIOS request
if ${offlineMode}; then	echo -e "\e[35mYou have to be in ONLINE MODE to do this!\e[0m\n"; exit 1; fi

echo -e "\e[0mChecking the OpCertCounter for the Pool-ID \e[32m${poolID}\e[0m via ${koiosAPI}:"
echo

#query poolinfo via poolid on koios
showProcessAnimation "Query Pool-Info via Koios: " &
response=$(curl -s -m 10 -X POST "${koiosAPI}/pool_info" -H "Accept: application/json" -H "Content-Type: application/json" -d "{\"_pool_bech32_ids\":[\"${poolID}\"]}" 2> /dev/null)
stopProcessAnimation;
#check if the received json only contains one entry in the array (will also not be 1 if not a valid json)
if [[ $(jq ". | length" 2> /dev/null <<< ${response}) -ne 1 ]]; then echo -e "\n\e[35mCould not query the information via Koios, maybe pool not registered yet.\n\nResponse was: ${response}\n\e[0m"; exit 1; fi
onChainOpcertCount=$(jq -r ".[0].op_cert_counter | select (.!=null)" 2> /dev/null <<< ${response})
poolName=$(jq -r ".[0].meta_json.name | select (.!=null)" 2> /dev/null <<< ${response})
poolTicker=$(jq -r ".[0].meta_json.ticker | select (.!=null)" 2> /dev/null <<< ${response})

echo -e "\e[0mGot the information back for the Pool: \e[32m${poolName} (${poolTicker})\e[0m"
echo

if [[ "${onChainOpcertCount}" != "" ]]; then
	echo -e "\e[0mThe last known OpCertCounter on the chain is: \e[32m${onChainOpcertCount}\e[0m"
	nextChainOpcertCount=$(( ${onChainOpcertCount} + 1 )); #the next opcert counter that should be used on the chain is the last seen one + 1
	echo
	echo -e "\e[0mIf you wanna create a new OpCert on an offline machine, you should use the counter \e[33m${nextChainOpcertCount}\e[0m for your next one like:"
	echo -e "\e[33m./04c_genKESKeys.sh <poolNodeName>\e[0m"
	echo -e "\e[33m./04d_genNodeOpCert.sh <poolNodeName> ${nextChainOpcertCount}\e[0m"

	else
	echo -e "\e[0mThere is no information available from the chain about the OpCertCounter.\nLooks like the pool has not made a block yet. So your current OpCertCounter should be set to \e[33m0\e[0m"
fi

fi ##### Checking against Bech32-Pool-ID

echo -e "\e[0m\n"
echo

