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

#Currently supported Action-Types
#supportedGovActionType="InfoAction, TreasuryWithdrawals, NewConstitution, NoConfidence, ParameterChange, UpdateCommittee, HardForkInitiation"
supportedGovActionType="InfoAction, TreasuryWithdrawals, NewConstitution, NoConfidence, ParameterChange, UpdateCommittee, HardForkInitiation"

#Check command line parameter
if [ $# -lt 2 ]; then
cat >&2 <<EOF

Usage:  $(basename $0) <StakeAddress/Name> <ActionType> <Anchor-Url "url: ..."> [additional parameters based on the ActionType]

Currently supported ActionTypes:
	${supportedGovActionType}

Always required parameter:
        "url: https://..." or "url: ipfs://..."
				-> Anchor-Url (in Online-/Light-Mode the Hash will be calculated)
        ["hash: ..."] 		-> Anchor-HASH, to set the Anchor-Hash in Offline-Mode

- Required for Action-Type 'TreasuryWithdrawals':
	"amount: xxx" 		-> Withdrawal-Amount in lovelaces
	["addr: stake1..."] 	-> StakeAddress which should receive the withdrawal (same as StakeAddress if not provided)

- Required for Action-Type 'NewConstitution':
        "constitution-url: https://..." or "constitution-url: ipfs://..."
				-> Constitution-Url (in Online-/Light-Mode the Hash will be calculated)
        ["constitution-hash: ..."] 		-> Constitution-HASH, to set the Anchor-Hash in Offline-Mode

- Required for Action-Type 'HardForkInitiation':
	"ver: X.Y" 		-> Protocol-Version X.Y to fork to

- Required for Action-Type 'UpdateCommittee':
	"threshold: x/y"	-> Rational committee vote threshold value between 0.0-1.0 like 0.66 or 2/3
	["add-hash: ..."]	-> Adding a cold Key-Hash to the committee
	["add-script: ..."]	-> Adding a cold Script-Hash to the committee
	["rem-hash: ..."]	-> Removing a cold Key-Hash from the committee
	["rem-script: ..."]	-> Removing a cold Script-Hash from the committee
	["epoch: xxx"]		-> Max. Term epoch (defaults to current epoch + max term length)

- Required for Action-Type 'ParameterChange':
	"name_of_parameter: value" -> Supported parameter names & values: min-fee-linear LOVELACE, min-fee-constant LOVELACE, max-block-body-size WORD32, max-tx-size WORD32, max-block-header-size WORD16, key-reg-deposit-amt NATURAL, pool-reg-deposit NATURAL, pool-retirement-epoch-interval WORD32, number-of-pools NATURAL, pool-influence RATIONAL, treasury-expansion RATIONAL, monetary-expansion RATIONAL, min-pool-cost NATURAL, price-execution-steps RATIONAL, price-execution-memory RATIONAL, max-value-size INT, collateral-percent INT, max-collateral-inputs INT, utxo-cost-per-byte LOVELACE, pool-voting-threshold-motion-no-confidence RATIONAL, pool-voting-threshold-committee-normal RATIONAL, pool-voting-threshold-committee-no-confidence RATIONAL, pool-voting-threshold-hard-fork-initiation RATIONAL, pool-voting-threshold-pp-security-group RATIONAL, drep-voting-threshold-motion-no-confidence RATIONAL, drep-voting-threshold-committee-normal RATIONAL, drep-voting-threshold-committee-no-confidence RATIONAL, drep-voting-threshold-update-to-constitution RATIONAL, drep-voting-threshold-hard-fork-initiation RATIONAL, drep-voting-threshold-pp-network-group RATIONAL, drep-voting-threshold-pp-economic-group RATIONAL, drep-voting-threshold-pp-technical-group RATIONAL, drep-voting-threshold-pp-governance-group RATIONAL, drep-voting-threshold-treasury-withdrawal RATIONAL, min-committee-size INT, committee-term-length WORD32, governance-action-lifetime WORD32, new-governance-action-deposit NATURAL, drep-deposit LOVELACE, drep-activity WORD32, ref-script-cost-per-byte RATIONAL



EOF
exit 1;
fi

#exit with an information, that the script needs at least conway era
case ${cliEra} in
        "babbage"|"alonzo"|"mary"|"allegra"|"shelley")
                echo -e "\n\e[91mINFORMATION - The chain is not in conway era yet. This script will start to work once we forked into conway era. Please check back later!\n\e[0m"; exit;
                ;;
esac


#At least 2 parameters were provided, use them

#Check Action-Type parameter
govActionType="${2,,}"
if [[ "${supportedGovActionType,,}" != *"${govActionType}"* ]]; then echo -e "\n\e[33mINFO - Action-Type '${govActionType}' is not supported right now. Currently supported Action-Types are:\n${supportedGovActionType}\n\e[0m"; exit 1; fi


#Check StakeAddress for Deposit-Return
stakeAddrName="$(dirname $1)/$(basename $1 .staking)"; stakeAddrName=${stakeAddrName/#.\//};
if [ -f "${stakeAddrName}.staking.addr" ]; then #try to read stake address from .addr file
	stakeAddr=$(cat "${stakeAddrName}.staking.addr" 2> /dev/null)
	if [ $? -ne 0 ]; then echo -e "\n\e[91mERROR - Could not read from file '${stakeAddrName}.staking.addr'\n\e[0m"; exit 1; fi
	tmp=$(${bech32_bin} 2> /dev/null <<< "${stakeAddr,,}") #will have returncode 0 if the bech was valid
	if [ $? -ne 0 ]; then echo -e "\n\e[91mERROR - '${stakeAddr}' is not a valid Bech32 Stake-Address.\n\e[0m"; exit 1; fi
elif [[ "${stakeAddrName,,}" == "stake"* ]]; then #parameter is most likely a bech32-stakeaddress
	tmp=$(${bech32_bin} 2> /dev/null <<< "${stakeAddrName,,}") #will have returncode 0 if the bech was valid
	if [ $? -ne 0 ]; then echo -e "\n\e[91mERROR - '${stakeAddrName}' is not a valid Bech32 Stake-Address.\n\e[0m"; exit 1; fi
	stakeAddr=${stakeAddrName,,}; stakeAddrName=${govActionType}; #set the stakeAddrName to the govActionType so we have a nice prefix for the output filename
else
	echo -e "\n\e[91mERROR - \"${stakeAddrName}.staking.addr\" Stake Address file does not exist, also no valid Bech-StakeAddress provided.\n\e[0m"; exit 1;
fi



echo
echo -e "\e[0mGenerate an Action-File of type \e[32m${govActionType^^}\e[0m with Deposit-Return to: \e[32m${stakeAddrName}\e[0m"
echo
echo -e "\e[0mReturning deposit to Stake-Address: \e[32m${stakeAddr}\e[0m"
echo

#Setting default variables
anchorURL=""; anchorHASH=""; #Setting defaults
committeeTermEpoch=0;

paramCnt=$#;
allParameters=( "$@" )
#First check about the anchor-url and hash, thats a required parameter for all actions
#Check all parameters and set the corresponding variables
#Starting with the 3th parameter (index=2) up to the last parameter
for (( tmpCnt=2; tmpCnt<${paramCnt}; tmpCnt++ ))
 do
        paramValue=${allParameters[$tmpCnt]}

        #Check if its an anchor-url
        if [[ "${paramValue,,}" =~ ^url:(.*)$ ]]; then #if the parameter starts with "url:" then set the anchorURL variable
                anchorURL=$(trimString "${paramValue:4}");
		#Check that the provided URL starts with 'https://'
		if [[ ! "${anchorURL}" =~ https://.* && ! "${anchorURL}" =~ ipfs://.* ]] || [[ ${#anchorURL} -gt 128 ]]; then echo -e "\e[91mERROR - The provided Anchor-URL '${anchorURL}'\ndoes not start with https:// or ipfs:// or is too long. Max. 128 chars allowed !\e[0m\n"; exit 1; fi

        #Check if its an anchor-hash - its only needed to overwrite the value in offline mode
        elif [[ "${paramValue,,}" =~ ^hash:(.*)$ ]]; then #if the parameter starts with "hash:" then set the anchorHASH variable
                anchorHASH=$(trimString "${paramValue:5}"); #trim it
		anchorHASH=${anchorHASH,,}; #lower case
		#Check that the provided HASH is a valid hex hash
		if [[ "${anchorHASH//[![:xdigit:]]}" != "${anchorHASH}" || ${#anchorHASH} -ne 64 ]]; then #parameter is not in hex or not 64 chars long
			echo -e "\e[91mERROR - The provided Anchor-HASH '${anchorHASH}' is not in HEX or not 64chars long !\e[0m\n"; exit 1; fi

        #Check if its the committee term epoch - a more in depth check will be done later if necessary
        elif [[ "${paramValue,,}" =~ ^epoch:(.*)$ ]]; then #if the parameter starts with "epoch:" then set the committeeTermEpoch variable
                value=$(trimString "${paramValue:6}");
                #Check if the provided Amount is a positive number
		if [[ -z "${value##*[!0-9]*}" ]]; then
			echo -e "\e[91mERROR - The provided committee end term epoch '${value}' is not a positive number !\e[0m\n"; exit 1; fi
		committeeTermEpoch=${value}

        fi #end of different parameters check

 done

#Throw an error if no anchor url set
if [[ ${anchorURL} == "" ]]; then echo -e "\n\e[91mERROR - Please provide an Anchor-URL via the parameter \"url: https://...\" or \"url: ipfs://...\".\n\e[0m"; exit 1; fi

#If in online/light mode, check the anchorURL
if ${onlineMode}; then

		#we write out the downloaded content to a file 1:1, so we can do a hash calculation on the file itself rather than on text content
		tmpAnchorContent="${tempDir}/AnchorURLContent.tmp"; touch "${tmpAnchorContent}"; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

		#check if the URL is a normal one or an ipfs one, in case of ipfs, use https://ipfs.io/ipfs/xxx to load the content
		if [[ "${anchorURL}" =~ ipfs://.* ]]; then queryURL="https://ipfs.io/ipfs/${anchorURL:7}"; echo -e "\e[0mUsing the Query-URL\e[32m ${queryURL}\e[0m for ipfs\n"; else queryURL="${anchorURL}"; fi

		errorcnt=0; error=-1;
		showProcessAnimation "Query Anchor-URL content: " &
		while [[ ${errorcnt} -lt 5 && ${error} -ne 0 ]]; do #try a maximum of 5 times to request the information
			error=0
		        response=$(curl -sL -m 30 -X GET -w "---spo-scripts---%{http_code}" "${queryURL}" --output "${tmpAnchorContent}" 2> /dev/null)
			if [[ $? -ne 0 ]]; then error=1; sleep 1; fi; #if there is an error, wait for a second and repeat
			errorcnt=$(( ${errorcnt} + 1 ))
		done
		stopProcessAnimation;

		#if no error occured, split the response string into the content and the HTTP-ResponseCode
		if [[ ${error} -eq 0 && "${response}" =~ (.*)---spo-scripts---([0-9]*)* ]]; then

                        responseCode="${BASH_REMATCH[2]}"

			#Check the responseCode
			case ${responseCode} in
				"200" ) #all good, continue
					tmp=$(jq . < "${tmpAnchorContent}" 2> /dev/null) #just a short check that the received content is a valid JSON file
					if [ $? -ne 0 ]; then

						echo -e "\e[0m   Anchor-STATUS: ${iconNo}\e[35m not a valid JSON format!\e[0m";
						rm "${tmpAnchorContent}";

					else #anchor-url is a json

						contentHASH=$(b2sum -l 256 "${tmpAnchorContent}" 2> /dev/null | cut -d' ' -f 1)
						checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
						echo -e "\e[0mAnchor-URL(HASH):\e[32m ${anchorURL} \e[0m(\e[94m${contentHASH}\e[0m)"
						if [[ ${anchorHASH} != "" && ${anchorHASH} != ${contentHASH} ]]; then echo -e "\n\e[91mWARNING - Provided Anchor-HASH '${anchorHASH}' is wrong and will be ignored ...\e[0m\n"; fi
						anchorHASH="${contentHASH}" #set the anchorHASH not to the provided one, use the one calculated from the online file

						echo -e "\e[0m   Anchor-Status: ${iconYes}\e[32m File-Content-HASH set to '${anchorHASH}'\e[0m";

						#Now we are checking the Integrity of the Anchor-File and the Author-Signatures
						signerJSON=$(${cardanosigner} verify --cip100 --data-file "${tmpAnchorContent}" --json-extended 2> /dev/stdout)
						if [ $? -ne 0 ]; then
							echo -e "\e[0m     Anchor-Data: ${iconNo}\e[35m ${signerJSON}\e[0m";
						else
							errorMsg=$(jq -r .errorMsg <<< ${signerJSON} 2> /dev/null)
							echo -e "\e[0m     Anchor-Data: ${iconYes}\e[32m JSONLD structure is ok\e[0m";
							if [[ "${errorMsg}" != "" ]]; then echo -e "\e[0m           Error: ${iconNo} ${errorMsg}\e[0m"; fi
							authors=$(jq -r --arg iconYes "${iconYes}" --arg iconNo "${iconNo}" '.authors[] | "\\e[0m       Signature: \(if .valid then $iconYes else $iconNo end) \(.name)\\e[0m"' <<< ${signerJSON} 2> /dev/null)
							if [[ "${authors}" != "" ]]; then echo -e "${authors}\e[0m"; fi
						fi
						echo
                                                rm "${tmpAnchorContent}" #cleanup
					fi #anchor is a json
					;;

				"4"* ) #file-not-found
					echo -e "\n\e[91mERROR 404 - No content was found on the given Anchor-URL '${anchorURL}'\nPlease upload it first to this location, thx!\n\nHTTP Response Code: ${responseCode}\n\e[0m"; exit 1; #exit with a failure
					;;

		                * )     echo -e "\n\e[91mERROR - Query of the Anchor-URL failed!\nHTTP Request File: ${anchorURL}\nHTTP Response Code: ${responseCode}\n\e[0m"; exit 1; #exit with a failure and the http response code
					;;
			esac;

#		        #Check the responseCode
#		        case ${responseCode} in
#		                "200" ) #all good, continue
#					tmp=$(jq . < "${tmpAnchorContent}" 2> /dev/null) #just a short check that the received content is a valid JSON file
#					if [ $? -ne 0 ]; then echo -e "\n\e[91mERROR - The content of the Anchor-URL '${anchorURL}'\nis not in valid JSON format!\n\e[0m"; rm "${tmpAnchorContent}"; exit 1; fi
#					contentHASH=$(b2sum -l 256 "${tmpAnchorContent}" 2> /dev/null | cut -d' ' -f 1)
#					checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
#					echo -e "\e[0mAnchor-URL(HASH):\e[32m ${anchorURL} \e[0m(\e[94m${contentHASH}\e[0m)"
#					echo
#					if [[ ${anchorHASH} != "" && ${anchorHASH} != ${contentHASH} ]]; then echo -e "\e[91mWARNING - Provided Anchor-HASH '${anchorHASH}' is wrong and will be ignored ...\e[0m\n"; fi
#					anchorHASH="${contentHASH}" #set the anchorHASH not to the provided one, use the one calculated from the online file
#					rm "${tmpAnchorContent}" #cleanup
#					;;
#
#		                "404" ) #file-not-found
#					echo -e "\n\e[91mERROR 404 - No content was not found on the given Anchor-URL '${anchorURL}'\nPlease upload it first to this location, thx!\n\e[0m"; exit 1; #exit with a failure
#					;;
#
#		                * )     echo -e "\n\e[91mERROR - Query of the Anchor-URL failed!\nHTTP Request File: ${anchorURL}\nHTTP Response Code: ${responseCode}\n\e[0m"; exit 1; #exit with a failure and the http response code
#					;;
#		        esac;

		else
			echo -e "\n\e[91mERROR - Query of the Anchor-URL '${anchorURL}' failed!\n\e[0m"; exit 1;
		fi #error & response
		unset errorcnt error

else #offline mode

	echo -e "\e[0mAnchor-URL(HASH):\e[32m ${anchorURL} \e[0m(\e[94m${anchorHASH}\e[0m)"
	echo -e "\n\e[91mWARNING - We cannot verify the correct Anchor-HASH in Offline-Mode, so be careful to use the correct one!\e[0m\n"

fi ## ${onlineMode} == true

#In online/light mode we should now have an anchorHASH if an anchorURL was provided
#Do a check - important for Offline-Mode
if [[ ${anchorURL} != "" && ${anchorHASH} == "" ]]; then echo -e "\n\e[91mERROR - Please also provide an Anchor-HASH via the parameter \"hash: xxxxx\".\n\e[0m"; exit 1; fi

#-------------------------------------

#Read ProtocolParameters
case ${workMode} in
        "online")       #onlinemode
			protocolParametersJSON=$(${cardanocli} ${cliEra} query protocol-parameters)
			constitutionParametersJSON=$(${cardanocli} ${cliEra} query constitution 2> /dev/null | jq -r . 2> /dev/null)
			if [[ ${constitutionParametersJSON} == "" ]]; then echo -e "\n\e[91mERROR - Could not query constitution state.\e[0m"; exit 1; fi
			#get the previous actions ids for the various action types
			prevActionIDsJSON=$(${cardanocli} ${cliEra} query gov-state 2> /dev/null | jq -r ".nextRatifyState.nextEnactState.prevGovActionIds")
			if [[ ${prevActionIDsJSON} == "" ]]; then echo -e "\n\e[91mERROR - Could not query last used Action-IDs.\e[0m"; exit 1; fi
			#merge the governanceParameters and prevActionIDs into the normal protocolParameters
			protocolParametersJSON=$( jq --sort-keys ".constitution += ${constitutionParametersJSON} | .prevActionIDs += ${prevActionIDsJSON}" <<< ${protocolParametersJSON})
			;;

        "light")        #lightmode
			protocolParametersJSON=${lightModeParametersJSON}
			;;

        "offline")      ##offlinemode
			readOfflineFile;        #Reads the offlinefile into the offlineJSON variable
			protocolParametersJSON=$(jq ".protocol.parameters" <<< ${offlineJSON})
			;;
esac
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

{ read protocolVersionMajor; read protocolVersionMinor; read actionDepositFee; read committeeMaxTermLength; } <<< $(jq -r ".protocolVersion.major // -1, .protocolVersion.minor // -1, .govActionDeposit // -1, .committeeMaxTermLength // -1" <<< ${protocolParametersJSON} 2> /dev/null)

#Do a check if we are at least in conway-era (protocol major 9 and above)
if [[ ${protocolVersionMajor} -lt 9 ]]; then
	echo -e "\n\e[91mINFORMATION - The current era on the chain does not support governance actions, please wait until the chain forks to at least conway-bootstrap mode!\n\e[0m"; exit 1; fi

if [[ ${actionDepositFee} -lt 0 ]]; then
	echo -e "\n\e[91mERROR - Could not query the current Action-Deposit fee amount!\n\e[0m"; exit 1; fi

echo -e "\e[0mAction-Deposit Fee:\e[32m $(convertToADA ${actionDepositFee}) ADA / ${actionDepositFee} lovelaces\n\e[0m"

if [[ ${committeeMaxTermLength} -lt 0 ]]; then
	echo -e "\n\e[91mERROR - Could not query the current Committee-MaxTermEpochLength value!\n\e[0m"; exit 1; fi

#-------------------------------------

#Read in additional parameters based on the type of the action
case "${govActionType,,}" in


	#---------------- INFO ACTION -----------------
	"infoaction")
		#we already have all needed information, only info needed is the anchorURL+anchorHASH
		;;


	#---------------- NO CONFIDENCE -----------------
	"noconfidence")
		#do a protocol version check
		if [[ ${protocolVersionMajor} -lt 10 ]]; then
			echo -e "\n\e[91mINFORMATION - Its not possible to do a '${govActionType}' action during Conway-Bootstrap (protocol v9) phase. Please wait until the chain is in full Governance-Mode (protocol v10).\n\e[0m"; exit 1; fi
		#we already have all needed information, only info needed is the anchorURL+anchorHASH
		;;


	#---------------- TREASURY WITHDRAWALS -----------------
	"treasurywithdrawals") #amount: <lovelaces to receive>, addr: <optional receiving stakeaddress>
		#do a protocol version check
		if [[ ${protocolVersionMajor} -lt 10 ]]; then
			echo -e "\n\e[91mINFORMATION - Its not possible to do a '${govActionType}' action during Conway-Bootstrap (protocol v9) phase. Please wait until the chain is in full Governance-Mode (protocol v10).\n\e[0m"; exit 1; fi
		echo -e "\e[90m------------\e[0m\n"
		fundsReceivingStakeAddr=${stakeAddr}; #default receiver is the same as the deposit-return
		fundsReceivingAmount=0;
		#Starting with the 3th parameter (index=2) up to the last parameter
		for (( tmpCnt=2; tmpCnt<${paramCnt}; tmpCnt++ ))
		 do
		        paramValue=${allParameters[$tmpCnt]}

		        #Check if its the transfer amount
		        if [[ "${paramValue,,}" =~ ^amount:(.*)$ ]]; then #if the parameter starts with "amount:" then set the anchorURL variable
		                value=$(trimString "${paramValue:7}");
		                #Check if the provided Amount is a positive number
				if [[ -z "${value##*[!0-9]*}" ]]; then
					echo -e "\e[91mERROR - The provided transfer amount '${value}' is not a positive number !\e[0m\n"; exit 1; fi
				fundsReceivingAmount=${value}

		        #Check if its a receiving stake address
		        elif [[ "${paramValue,,}" =~ ^addr:(.*)$ ]]; then #if the parameter starts with "addr:" then set the anchorHASH variable
		                value=$(trimString "${paramValue:5}"); #trim it
				if [[ "${value,,}" != "stake"* ]]; then echo -e "\n\e[91mERROR - '${value}' is not a valid Bech32 Stake-Address to receive funds.\n\e[0m"; exit 1; fi
				tmp=$(${bech32_bin} 2> /dev/null <<< "${value,,}") #check the bech integrity
				if [ $? -ne 0 ]; then echo -e "\n\e[91mERROR - '${paramValue}' does not contain a valid Bech32 Stake-Address to receive funds.\n\e[0m"; exit 1; fi
				fundsReceivingStakeAddr=${value}

		        fi #end of different parameters

		 done
		unset value;
		unset tmp;

		#Check about all needed parameters
		if [[ ${fundsReceivingAmount} -eq 0 ]]; then echo -e "\n\e[91mERROR Missing Parameter:\n\t\"amount: xxx\", amount of lovelaces to withdraw from the treasury, will be sent to the given StakeAddress\n\e[0m"; exit 1; fi

		echo -e "Withdrawal-Amount: \e[33m$(convertToADA ${fundsReceivingAmount}) ADA / ${fundsReceivingAmount} lovelaces\e[0m"
		echo -e "  Withdrawal-Addr: \e[33m${fundsReceivingStakeAddr}\e[0m"
		echo
		echo -e "\e[90m------------\e[0m\n"
		;;


	#---------------- HARDFORK INITATION -----------------
	"hardforkinitiation") #ver: X.Y
		echo -e "\e[90m------------\e[0m\n"
		forkMajorVer=""; forkMinorVer=""; #defaults

		#Starting with the 3th parameter (index=2) up to the last parameter
		for (( tmpCnt=2; tmpCnt<${paramCnt}; tmpCnt++ ))
		 do

		        cliParam=${allParameters[$tmpCnt]} #cliParam -> like "min-pool-cost: 170"

			#split up the given cliParam into paramName(+lowercase) and paramValue by the : char
			paramName=$(trimString "${cliParam%%:*}"); paramName=${paramName,,}
			paramValue=$(trimString "${cliParam#*:}")

			case ${paramName} in
				"url"|"hash") continue;; #skip to next parameter if its one we already checked about (url|hash)
				"ver") #get the version to fork to
					if [[ "${paramValue}" =~ ^([0-9]{1,2})"."([0-9]{1,2})$ ]]; then
						forkMajorVer=${BASH_REMATCH[1]}; forkMinorVer=${BASH_REMATCH[2]};
					else
						echo -e "\n\e[91mERROR Parameter:\n\t\"ver: X.Y\", the given parameter '${paramValue}' is not in the right format like '10.0'\n\e[0m"; exit 1;
					fi
					;;
			esac

		 done

		#Check about all needed parameters
		if [[ "${forkMajorVer}" == "" || "${forkMinorVer}" == "" ]]; then echo -e "\n\e[91mERROR Missing Parameter:\n\t\"ver: X.Y\", please provide the parameter for the version you wanna fork to in the format like '10.0'\n\e[0m"; exit 1; fi

		#some additional sanity checks
		if [[ ${forkMajorVer} -lt ${protocolVersionMajor} ]]; then echo -e "\n\e[91mERROR - Current Protocol-Version is ${protocolVersionMajor}.${protocolVersionMinor} -> You can't fork to a lower protocol version than the current one!\n\e[0m"; exit 1;
		elif [[ ${forkMajorVer} -eq ${protocolVersionMajor} && ${forkMinorVer} -lt ${protocolVersionMinor} ]]; then echo -e "\n\e[91mERROR - Current Protocol-Version is ${protocolVersionMajor}.${protocolVersionMinor} -> You can't fork to a lower minor protocol version than the current one!\n\e[0m"; exit 1;
		elif [[ ${forkMajorVer} -gt $((${protocolVersionMajor}+1)) ]]; then echo -e "\n\e[91mERROR - Current Protocol-Version is ${protocolVersionMajor}.${protocolVersionMinor} -> You can only increase the protocol major version by one!\n\e[0m"; exit 1;
		elif [[ ${forkMajorVer} -eq $((${protocolVersionMajor}+1)) && ${forkMinorVer} -ne 0 ]]; then echo -e "\n\e[91mERROR - Current Protocol-Version is ${protocolVersionMajor}.${protocolVersionMinor} -> If you fork to a greater protocol major version, the minor version must be 0!\n\e[0m"; exit 1;
		fi

		echo -e "\e[0mFork to\e[32m Protocol-Version \e[0m► \e[94m${forkMajorVer}.${forkMinorVer}\e[0m"
		echo
		echo -e "\e[90m------------\e[0m\n"
		;;


	#---------------- UPDATE COMMITTEE -----------------
	"updatecommittee") #threshold: <rational>, optional add-hash, add-script, rem-hash, rem-script
		#do a protocol version check
		if [[ ${protocolVersionMajor} -lt 10 ]]; then
			echo -e "\n\e[91mINFORMATION - Its not possible to do a '${govActionType}' action during Conway-Bootstrap (protocol v9) phase. Please wait until the chain is in full Governance-Mode (protocol v10).\n\e[0m"; exit 1; fi
		echo -e "\e[90m------------\e[0m\n"
		committeeUpdateStr="";

		#Setting the default committeeMaxTermLength
		currentEPOCH=$(get_currentEpoch); checkError "$?";
		committeeMaxEpoch=$(( ${currentEPOCH} + ${committeeMaxTermLength} ))

		#Check if a committeeTermEpoch was provided via parameter
		if [[ ${committeeTermEpoch} -ne 0 ]] && [[ ${committeeTermEpoch} -le ${currentEPOCH} || ${committeeTermEpoch} -gt ${committeeMaxEpoch} ]]; then
			echo -e "\n\e[91mERROR - The value for the committee end term epoch must be bigger than the current epoch ${currentEPOCH} and max ${committeeMaxEpoch}!\n\e[0m"; exit 1;
		elif [[ ${committeeTermEpoch} -eq 0 ]]; then committeeTermEpoch=${committeeMaxEpoch}; #not provided, set it to the max term epoch
		fi

		echo -e "\e[0mSet\e[32m term end-epoch \e[0m► \e[94m${committeeTermEpoch}\e[0m"

		#Starting with the 3th parameter (index=2) up to the last parameter
		for (( tmpCnt=2; tmpCnt<${paramCnt}; tmpCnt++ ))
		 do

		        cliParam=${allParameters[$tmpCnt]} #cliParam -> like "min-pool-cost: 170"

			#split up the given cliParam into paramName(+lowercase) and paramValue by the : char
			paramName=$(trimString "${cliParam%%:*}"); paramName=${paramName,,}
			paramValue=$(trimString "${cliParam#*:}")

			case ${paramName} in
				"url"|"hash"|"epoch") continue;; #skip to next parameter if its one we already checked about (url|hash|epoch)

				"threshold") #read the thresholdvalue and check if its a rational in the 0-1 boundary
					if [[ -n "${paramValue//[0-9.\/]}" || -z "${paramValue//[!.\/]}" || "${paramValue:0:1}" == "." || "${paramValue: -1}" == "." || $(bc <<< "scale=18; (${paramValue}) > 1.0") -eq 1 ]]; then echo -e "\n\e[91mERROR - The value for parameter '${paramName} = ${paramValue}' should be a positive RATIONAL in the format 2/3 or 0.66666. Range must be from 0.0 to 1.0\e[0m"; exit 1; fi
					#check that this parameter is not already in the list
					if [[ "${committeeUpdateStr}" == *"--threshold"* ]]; then echo -e "\n\e[91mERROR - The parameter 'threshold' is already in the list, please only provide it once.\n\e[0m"; exit 1; fi
					echo -e "\e[0mSet\e[32m threshold \e[0m► \e[94m${paramValue}\e[0m"
					committeeUpdateStr+="--threshold ${paramValue} "
					;;

				"add-hash") #add a committee cold KEY hash
					paramValue=${paramValue,,}
					if [[ "${paramValue//[![:xdigit:]]}" != "${paramValue}" || ${#paramValue} -ne 56 ]]; then echo -e "\n\e[91mERROR - The value for parameter '${paramName} = ${paramValue}' is not a valid hex hash. Make sure its only hex and 56 chars long!\e[0m"; exit 1; fi
					#check that this hash is not already in the list
					if [[ "${committeeUpdateStr}" == *"${paramValue}"* ]]; then echo -e "\n\e[91mERROR - The hash '${paramValue}' is already in the list, please only provide it once.\n\e[0m"; exit 1; fi
					echo -e "\e[0mAdd\e[32m Cold-KeyHash \e[0m► \e[94m${paramValue}\e[0m"
					committeeUpdateStr+="--add-cc-cold-verification-key-hash ${paramValue} --epoch ${committeeTermEpoch} "
					;;

				"rem-hash") #remove a committee cold KEY hash
					paramValue=${paramValue,,}
					if [[ "${paramValue//[![:xdigit:]]}" != "${paramValue}" || ${#paramValue} -ne 56 ]]; then echo -e "\n\e[91mERROR - The value for parameter '${paramName} = ${paramValue}' is not a valid hex hash. Make sure its only hex and 56 chars long!\e[0m"; exit 1; fi
					#check that this hash is not already in the list
					if [[ "${committeeUpdateStr}" == *"${paramValue}"* ]]; then echo -e "\n\e[91mERROR - The hash '${paramValue}' is already in the list, please only provide it once.\n\e[0m"; exit 1; fi
					echo -e "\e[0mRem\e[32m Cold-KeyHash \e[0m◄ \e[91m${paramValue}\e[0m"
					committeeUpdateStr+="--remove-cc-cold-verification-key-hash ${paramValue} "
					;;

				"add-script") #add a committee cold SCRIPT hash
					paramValue=${paramValue,,}
					if [[ "${paramValue//[![:xdigit:]]}" != "${paramValue}" || ${#paramValue} -ne 56 ]]; then echo -e "\n\e[91mERROR - The value for parameter '${paramName} = ${paramValue}' is not a valid hex hash. Make sure its only hex and 56 chars long!\e[0m"; exit 1; fi
					#check that this hash is not already in the list
					if [[ "${committeeUpdateStr}" == *"${paramValue}"* ]]; then echo -e "\n\e[91mERROR - The hash '${paramValue}' is already in the list, please only provide it once.\n\e[0m"; exit 1; fi
					echo -e "\e[0mAdd\e[32m Cold-ScriptHash \e[0m► \e[94m${paramValue}\e[0m"
					committeeUpdateStr+="--add-cc-cold-script-hash ${paramValue} --epoch ${committeeTermEpoch} "
					;;

				"rem-script") #remove a committee cold SCRIPT hash
					paramValue=${paramValue,,}
					if [[ "${paramValue//[![:xdigit:]]}" != "${paramValue}" || ${#paramValue} -ne 56 ]]; then echo -e "\n\e[91mERROR - The value for parameter '${paramName} = ${paramValue}' is not a valid hex hash. Make sure its only hex and 56 chars long!\e[0m"; exit 1; fi
					#check that this hash is not already in the list
					if [[ "${committeeUpdateStr}" == *"${paramValue}"* ]]; then echo -e "\n\e[91mERROR - The hash '${paramValue}' is already in the list, please only provide it once.\n\e[0m"; exit 1; fi
					echo -e "\e[0mRem\e[32m Cold-ScriptHash \e[0m◄ \e[91m${paramValue}\e[0m"
					committeeUpdateStr+="--remove-cc-cold-script-hash ${paramValue} "
					;;


				*)	echo -e "\n\e[91mERROR - I don't know what to do with the parameter '${paramName}' for the UpdateCommittee-Action!\n\e[0m";
					exit 1;
					;;

			esac

		 done

		#Check about all needed parameters
		if [[ "${committeeUpdateStr}" != *"--threshold"* ]]; then echo -e "\n\e[91mERROR Missing Parameter:\n\t\"threshold: x/y\" -> Rational committee vote threshold value between 0.0-1.0 like 0.66 or 2/3\n\e[0m"; exit 1; fi

		echo
		echo -e "\e[90m------------\e[0m\n"
		;;



	#---------------- NEW CONSTITUION -----------------
	"newconstitution") #constitution-url/hash needed
		#do a protocol version check
		if [[ ${protocolVersionMajor} -lt 10 ]]; then
			echo -e "\n\e[91mINFORMATION - Its not possible to do a '${govActionType}' action during Conway-Bootstrap (protocol v9) phase. Please wait until the chain is in full Governance-Mode (protocol v10).\n\e[0m"; exit 1; fi
		echo -e "\e[90m------------\e[0m\n"
		constitutionURL=""; constitutionHASH=""; #Setting defaults
		#Starting with the 3th parameter (index=2) up to the last parameter
		for (( tmpCnt=2; tmpCnt<${paramCnt}; tmpCnt++ ))
		 do
		        paramValue=${allParameters[$tmpCnt]}

		        #Check if its an constitution-url
		        if [[ "${paramValue,,}" =~ ^constitution-url:(.*)$ ]]; then #if the parameter starts with "constitution-url:" then set the anchorURL variable
		                constitutionURL=$(trimString "${paramValue:17}");
				#Check that the provided URL starts with 'https://' or 'ipfs://'
				if [[ ! "${constitutionURL}" =~ https://.* && ! "${constitutionURL}" =~ ipfs://.* ]] || [[ ${#constitution} -gt 128 ]]; then echo -e "\e[91mERROR - The provided Constitution-URL '${constitutionURL}'\ndoes not start with https:// or ipfs:// or is too long. Max. 128 chars allowed !\e[0m\n"; exit 1; fi

		        #Check if its an constitution-hash - its only needed to overwrite the value in offline mode
		        elif [[ "${paramValue,,}" =~ ^constitution-hash:(.*)$ ]]; then #if the parameter starts with "hash:" then set the anchorHASH variable
		                constitutionHASH=$(trimString "${paramValue:18}"); #trim it
				constitutionHASH=${constitutionHASH,,}; #lower case
				#Check that the provided HASH is a valid hex hash
				if [[ "${constitutionHASH//[![:xdigit:]]}" != "${constitutionHASH}" || ${#constitutionHASH} -ne 64 ]]; then #parameter is not in hex or not 64 chars long
					echo -e "\e[91mERROR - The provided Constitution-HASH '${constitutionHASH}' is not in HEX or not 64chars long !\e[0m\n"; exit 1; fi

		        fi #end of different parameters check

		 done

		#Check about all needed parameters
		if [[ "${constitutionURL}" == "" ]]; then echo -e "\n\e[91mERROR Missing Parameter:\n\t\"constitution-url: https://...\" or \"constitution-url: ipfs://..:\", URL pointing to the online hosted Constitution file.\n\e[0m"; exit 1; fi

		#If in online/light mode, check the constitutionURL
		if ${onlineMode}; then

			#we write out the downloaded content to a file 1:1, so we can do a hash calculation on the file itself rather than on text content
			tmpConstitutionContent="${tempDir}/ConstitutionURLContent.tmp"; touch "${tmpConstitutionContent}"; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

			#check if the URL is a normal one or an ipfs one, in case of ipfs, use https://ipfs.io/ipfs/xxx to load the content
			if [[ "${constitutionURL}" =~ ipfs://.* ]]; then queryURL="https://ipfs.io/ipfs/${constitutionURL:7}"; echo -e "\e[0mUsing the Query-URL\e[32m ${queryURL}\e[0m for ipfs\n"; else queryURL="${constitutionURL}"; fi

			errorcnt=0; error=-1;
			showProcessAnimation "Query Constitution-URL content: " &
			while [[ ${errorcnt} -lt 5 && ${error} -ne 0 ]]; do #try a maximum of 5 times to request the information
				error=0
		        	response=$(curl -sL -m 30 -X GET -w "---spo-scripts---%{http_code}" "${queryURL}" --output "${tmpConstitutionContent}" 2> /dev/null)
				if [[ $? -ne 0 ]]; then error=1; sleep 1; fi; #if there is an error, wait for a second and repeat
				errorcnt=$(( ${errorcnt} + 1 ))
			done
			stopProcessAnimation;

			#if no error occured, split the response string into the content and the HTTP-ResponseCode
			if [[ ${error} -eq 0 && "${response}" =~ (.*)---spo-scripts---([0-9]*)* ]]; then

                        	responseCode="${BASH_REMATCH[2]}"

		        	#Check the responseCode
		        	case ${responseCode} in
		                	"200" ) #all good, continue
						contentHASH=$(b2sum -l 256 "${tmpConstitutionContent}" 2> /dev/null | cut -d' ' -f 1)
						checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
						echo -e "\e[0mConstitution-URL(HASH):\e[32m ${constitutionURL} \e[0m(\e[94m${contentHASH}\e[0m)"
						if [[ ${constitutionHASH} != "" && ${constitutionHASH} != ${contentHASH} ]]; then echo -e "Provided Constitution-HASH '${constitutionHASH}' will be ignored, continue ...\n"; fi
						constitutionHASH="${contentHASH}" #set the constitutionHASH not to the provided one, use the one calculated from the online file
						rm "${tmpConstitutionContent}" #cleanup
						;;

		                	"404" ) #file-not-found
						echo -e "\n\e[91mERROR 404 - No content was not found on the given Constitution-URL '${constitutionURL}'\nPlease upload it first to this location, thx!\n\e[0m"; exit 1; #exit with a failure
						;;

		                	* )     echo -e "\n\e[91mERROR - Query of the Constitution-URL failed!\nHTTP Request File: ${constitutionURL}\nHTTP Response Code: ${responseCode}\n\e[0m"; exit 1; #exit with a failure and the http response code
						;;
		        	esac;

			else
				echo -e "\n\e[91mERROR - Query of the Constitution-URL '${constitutionURL}' failed!\n\e[0m"; exit 1;
			fi #error & response
			unset errorcnt error

		fi ## ${onlineMode} == true

		#In online/light mode we should now have an constitutionHASH if an constitutionURL was provided
		#Do a check - important for Offline-Mode
		if [[ ${constitutionURL} != "" && ${constitutionHASH} == "" ]]; then echo -e "\n\e[91mERROR - Please also provide an Constitution-HASH via the parameter \"hash: xxxxx\".\n\e[0m"; exit 1; fi

		echo
		echo -e "\e[90m------------\e[0m\n"
		;;



	#---------------- PARAMETER CHANGE -----------------
	"parameterchange") #extra info -> paramters to update
		echo -e "\e[90m------------\e[0m\n"
		paramUpdateStr="" #

		declare -A PARAMETER_LIST
		PARAMETER_LIST=(
			"min-fee-linear" "LOVELACE"
			"min-fee-constant" "LOVELACE"
			"max-block-body-size" "WORD32"
			"max-tx-size" "WORD32"
			"max-block-header-size" "WORD16"
			"key-reg-deposit-amt" "NATURAL"
			"pool-reg-deposit" "NATURAL"
			"pool-retirement-epoch-interval" "WORD32"
			"number-of-pools" "NATURAL"
			"pool-influence" "RATIONAL"
			"treasury-expansion" "RATIONAL"
			"monetary-expansion" "RATIONAL"
			"min-pool-cost" "NATURAL"
			"price-execution-steps" "RATIONAL"
			"price-execution-memory" "RATIONAL"
			"max-value-size" "INT"
			"collateral-percent" "INT"
			"max-collateral-inputs" "INT"
			"utxo-cost-per-byte" "LOVELACE"
			"pool-voting-threshold-motion-no-confidence" "RATIONAL"
			"pool-voting-threshold-committee-normal" "RATIONAL"
			"pool-voting-threshold-committee-no-confidence" "RATIONAL"
			"pool-voting-threshold-hard-fork-initiation" "RATIONAL"
			"pool-voting-threshold-pp-security-group" "RATIONAL"
			"drep-voting-threshold-motion-no-confidence" "RATIONAL"
			"drep-voting-threshold-committee-normal" "RATIONAL"
			"drep-voting-threshold-committee-no-confidence" "RATIONAL"
			"drep-voting-threshold-update-to-constitution" "RATIONAL"
			"drep-voting-threshold-hard-fork-initiation" "RATIONAL"
			"drep-voting-threshold-pp-network-group" "RATIONAL"
			"drep-voting-threshold-pp-economic-group" "RATIONAL"
			"drep-voting-threshold-pp-technical-group" "RATIONAL"
			"drep-voting-threshold-pp-governance-group" "RATIONAL"
			"drep-voting-threshold-treasury-withdrawal" "RATIONAL"
			"min-committee-size" "INT"
			"committee-term-length" "WORD32"
			"governance-action-lifetime" "WORD32"
			"new-governance-action-deposit" "NATURAL"
			"drep-deposit" "LOVELACE"
			"drep-activity" "WORD32"
			"ref-script-cost-per-byte" "RATIONAL"
			)

		#Starting with the 3th parameter (index=2) up to the last parameter
		for (( tmpCnt=2; tmpCnt<${paramCnt}; tmpCnt++ ))
		 do
		        cliParam=${allParameters[$tmpCnt]} #cliParam -> like "min-pool-cost: 170"

			#split up the given cliParam into paramName(+lowercase) and paramValue by the : char
			paramName=$(trimString "${cliParam%%:*}"); paramName=${paramName,,}
			paramValue=$(trimString "${cliParam#*:}")

			#check that this parameter is not already in the list
			if [[ "${paramUpdateStr}" == *"--${paramName}"* ]]; then echo -e "\n\e[91mERROR - The parameter '${paramName}' is already in the list, please only provide it once.\n\e[0m"; exit 1; fi

			#skip to next parameter if its one we already checked about, if not, read out the paramType from the PARAMETER_LIST array
			case ${paramName} in
				"url"|"hash") continue;;
				*) #read the value type from the array
					paramType=${PARAMETER_LIST[${paramName}]}
					#throw an 'unknown parameter' error if its not in the list
					if [[ "${paramType}" == "" ]]; then echo -e "\n\e[91mERROR - I don't know what to do with the parameter '${paramName}'!\n\nSupported-Parameter names:\n$(printf '%s\n' ${!PARAMETER_LIST[@]} | sort)\n\e[0m"; exit 1; fi
					;;
			esac

			#we have a paramName, a paramValue and the paramType that must be used. lets check about the correct type
			case ${paramType,,} in
				"rational") 	#try to check that its a rational number:
						# check for only allowed chars "0-9./" (-n returns true if string is not empty)
						# check that at least a "." or "/" char must be included (-z return true if string is empty)
						# check that the first or last char is not a ".", so we wanna full decimals like "1.0" and not "1."
						# check that the value itself is <= 1.0
						if [[ -n "${paramValue//[0-9.\/]}" || -z "${paramValue//[!.\/]}" || "${paramValue:0:1}" == "." || "${paramValue: -1}" == "." || $(bc <<< "scale=18; (${paramValue}) > 1.0") -eq 1 ]]; then echo -e "\n\e[91mERROR - The value for parameter '${paramName} = ${paramValue}' should be a positive RATIONAL in the format 2/3 or 0.66666. Range must be from 0.0 to 1.0\n\e[0m"; exit 1; fi
						;;

				"natural") 	#check that its just a number greater than zero:
						# check for only allowed chars "0-9" (-n returns true if string is not empty)
						# check that its not zero
						if [[ -n "${paramValue//[0-9]}" || ${paramValue} -eq 0 ]]; then echo -e "\n\e[91mERROR - The value for parameter '${paramName} = ${paramValue}' should be a natural number greater than zero. No decimals allowed.\n\e[0m"; exit 1; fi
						;;

				*) 		#for the rest we check that its just a positive number incl. zero
						# check for only allowed chars "0-9" (-n returns true if string is not empty)
						if [[ -n "${paramValue//[0-9]}" ]]; then echo -e "\n\e[91mERROR - The value for parameter '${paramName} = ${paramValue}' should be an positive integer or zero. No decimals allowed.\n\e[0m"; exit 1; fi
						;;
			esac

			echo -e "\e[0mChange parameter\e[32m ${paramName} \e[0m► \e[94m${paramValue}\e[0m"

			paramUpdateStr+="--${paramName} ${paramValue} "

		 done

		#Check for parameter groups, if one of them is provided, all of them must be provided
		#--pool-voting-threshold are 5 parameters
		if [[ $(( $(egrep -o "pool-voting-threshold" <<< ${paramUpdateStr} | wc -l) % 5 )) -ne 0 ]]; then echo -e "\n\e[91mERROR - If you provide a parameter of the group 'pool-voting-threshold', you have to provide all 5 of them:\n$(printf '%s\n' ${!PARAMETER_LIST[@]} | grep 'pool-voting-threshold')\n\e[0m"; exit 1; fi

		#--drep-voting-threshold are 10 parameters
		if [[ $(( $(egrep -o "drep-voting-threshold" <<< ${paramUpdateStr} | wc -l) % 10 )) -ne 0 ]]; then echo -e "\n\e[91mERROR - If you provide a parameter of the group 'drep-voting-threshold', you have to provide all 10 of them:\n$(printf '%s\n' ${!PARAMETER_LIST[@]} | grep 'drep-voting-threshold')\n\e[0m"; exit 1; fi

		#Check if there is at least one parameter to update
		if [[ "${paramUpdateStr}" == "" ]]; then echo -e "\n\e[91mERROR - Please provide at least one parameter to update/change.\n\nCurrently supported parameters are:\n$(printf '%s\n' ${!PARAMETER_LIST[@]} | sort)\n\e[0m"; exit 1 ; fi

		echo
		echo -e "\e[90m------------\e[0m\n"
		;;

	#--------------------------------------------------------------------------------------------------
	*) #we should not land here
		echo -e "\n\e[91mERROR - Unknown Action-Type '${govActionType}' cannot be processed, sorry.\n\e[0m";
		exit 1
		;;

esac


#-------------------------------------

#GENERATE THE ACTION-FILE
datestr=$(date +"%y%m%d%H%M%S")
if [[ "${stakeAddrName}" == "${govActionType}" ]]; then
	actionFile="${stakeAddrName}_${datestr}.action"
	else
	actionFile="${stakeAddrName}_${govActionType}_${datestr}.action"
fi

#set the parameters we need in all types --mainnet/--testnet, deposit addr, deposit amount, anchor-url, anchor-hash, output-file
commonParam="${magicparam:0:9} --deposit-return-stake-address ${stakeAddr} --governance-action-deposit ${actionDepositFee} --anchor-url ${anchorURL} --anchor-data-hash ${anchorHASH} --out-file /dev/stdout"

echo -ne "\e[0mGenerate the Action-File ... "

case "${govActionType,,}" in

        "infoaction") #only common parameters

		constitutionScriptHash='-' #doesn't matter, so we blank it out

		actionFileContent=$(${cardanocli} ${cliEra} governance action create-info ${commonParam} 2> /dev/stdout)
		;;


        "treasurywithdrawals") #common parameters + funds-receiving-stake-key-hash + transfer amount(lovelaces)

		tmp=$(${bech32_bin} <<< ${fundsReceivingStakeAddr} 2> /dev/null)
		if [ $? -ne 0 ]; then echo -e "\n\n\e[91mERROR - Could not generate HASH from ${fundsReceivingStakeAddr}\n\e[0m"; exit 1; fi
		fundsReceivingStakeKeyHash=${tmp:2}

		{ read constitutionScriptHash; } <<< $(jq -r ".constitution.script // \"-\"" <<< ${protocolParametersJSON} 2> /dev/null)

		if [[ ${constitutionScriptHash} != "-" ]]; then #constitution script hash present
			commonParam+=" --constitution-script-hash ${constitutionScriptHash}"
		fi

		actionFileContent=$(${cardanocli} ${cliEra} governance action create-treasury-withdrawal ${commonParam} --funds-receiving-stake-key-hash ${fundsReceivingStakeKeyHash} --transfer ${fundsReceivingAmount} 2> /dev/stdout)
		;;


	"noconfidence") #common parameters + last action id for same action

		{ read prevActionUTXO; read prevActionIDX; } <<< $(jq -r ".prevActionIDs.Committee.txId // \"-\", .prevActionIDs.Committee.govActionIx // \"-\"" <<< ${protocolParametersJSON} 2> /dev/null)
		if [[ ${prevActionUTXO} == "-" ]]; then #no previous action id
			actionFileContent=$(${cardanocli} ${cliEra} governance action create-no-confidence ${commonParam} 2> /dev/stdout)
			else
			actionFileContent=$(${cardanocli} ${cliEra} governance action create-no-confidence ${commonParam} --prev-governance-action-tx-id ${prevActionUTXO} --prev-governance-action-index ${prevActionIDX} 2> /dev/stdout)
		fi
		;;


        "newconstitution") #common parameters + constitution-url/hash

		{ read prevActionUTXO; read prevActionIDX; } <<< $(jq -r ".prevActionIDs.Constitution.txId // \"-\", .prevActionIDs.Constitution.govActionIx // \"-\"" <<< ${protocolParametersJSON} 2> /dev/null)
		if [[ ${prevActionUTXO} == "-" ]]; then #no previous action id
			actionFileContent=$(${cardanocli} ${cliEra} governance action create-constitution ${commonParam} --constitution-url ${constitutionURL} --constitution-hash ${constitutionHASH} 2> /dev/stdout)
			else
			actionFileContent=$(${cardanocli} ${cliEra} governance action create-constitution ${commonParam} --constitution-url ${constitutionURL} --constitution-hash ${constitutionHASH} --prev-governance-action-tx-id ${prevActionUTXO} --prev-governance-action-index ${prevActionIDX} 2> /dev/stdout)
		fi
		;;


        "hardforkinitiation") #common parameters + majorVersion to fork to + minorVersion to fork to (+prev action-id)

		{ read prevActionUTXO; read prevActionIDX; } <<< $(jq -r ".prevActionIDs.HardFork.txId // \"-\", .prevActionIDs.HardFork.govActionIx // \"-\"" <<< ${protocolParametersJSON} 2> /dev/null)
		if [[ ${prevActionUTXO} == "-" ]]; then #no previous action id
			actionFileContent=$(${cardanocli} ${cliEra} governance action create-hardfork ${commonParam} --protocol-major-version ${forkMajorVer} --protocol-minor-version ${forkMinorVer} 2> /dev/stdout)
			else
			actionFileContent=$(${cardanocli} ${cliEra} governance action create-hardfork ${commonParam} --protocol-major-version ${forkMajorVer} --protocol-minor-version ${forkMinorVer} --prev-governance-action-tx-id ${prevActionUTXO} --prev-governance-action-index ${prevActionIDX} 2> /dev/stdout)
		fi
		;;


        "updatecommittee") #common parameters + committee parameters to update (+prev action-id)

		{ read prevActionUTXO; read prevActionIDX; } <<< $(jq -r ".prevActionIDs.Committee.txId // \"-\", .prevActionIDs.Committee.govActionIx // \"-\"" <<< ${protocolParametersJSON} 2> /dev/null)
		if [[ ${prevActionUTXO} == "-" ]]; then #no previous action id
			actionFileContent=$(${cardanocli} ${cliEra} governance action update-committee ${commonParam} ${committeeUpdateStr} 2> /dev/stdout)
			else
			actionFileContent=$(${cardanocli} ${cliEra} governance action update-committee ${commonParam} --prev-governance-action-tx-id ${prevActionUTXO} --prev-governance-action-index ${prevActionIDX} ${committeeUpdateStr} 2> /dev/stdout)
		fi
		;;


        "parameterchange") #common parameters + parameters to update + last action id for same action

		{ read prevActionUTXO; read prevActionIDX; read constitutionScriptHash; } <<< $(jq -r ".prevActionIDs.PParamUpdate.txId // \"-\", .prevActionIDs.PParamUpdate.govActionIx // \"-\", .constitution.script // \"-\"" <<< ${protocolParametersJSON} 2> /dev/null)

		if [[ ${constitutionScriptHash} != "-" ]]; then #constitution script hash present
			commonParam+=" --constitution-script-hash ${constitutionScriptHash}"
		fi

		if [[ ${prevActionUTXO} != "-" ]]; then #previous action id present
			commonParam+=" --prev-governance-action-tx-id ${prevActionUTXO} --prev-governance-action-index ${prevActionIDX}"
		fi

		actionFileContent=$(${cardanocli} ${cliEra} governance action create-protocol-parameters-update ${commonParam} ${paramUpdateStr} 2> /dev/stdout)
		;;

esac

if [ $? -ne 0 ]; then echo -e "\n\n\e[91mERROR - ${actionFileContent}\n\e[0m"; exit 1; fi
file_unlock "${actionFile}"
echo -e "${actionFileContent}" > "${actionFile}" 2> /dev/null
if [ $? -ne 0 ]; then echo -e "\n\n\e[91mERROR - Could not write out the Action-File ${actionFile} !\n\e[0m"; exit 1; fi
file_lock "${actionFile}"
unset actionFileContent
echo -e "\e[32mOK\n\e[0m"

if [[ ${#prevActionUTXO} -gt 1 ]]; then echo -e "\e[0mReferencing last Action-ID:\e[32m ${prevActionUTXO}#${prevActionIDX}\n\e[0m"; fi

if [[ "${constitutionScriptHash}" != "-" ]]; then echo -e "\e[0mReferencing Constitution-Script-HASH:\e[32m ${constitutionScriptHash}\n\e[0m"; fi

echo -e "\e[0mAction-File built:\e[32m ${actionFile}\e[90m"
cat "${actionFile}"
echo

echo -e "\e[33mIf you wanna submit the Action now, please run the script 25b like:"
echo -e "\"./25b_regAction.sh myWallet ${actionFile}\"\e[0m"
echo

echo -e "\e[0m"


