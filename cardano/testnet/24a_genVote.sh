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


if [ $# -lt 2 ]; then
cat >&2 <<EOF

Usage:  $(basename $0) <DRep-Name | Committee-Hot-Name | Pool-Name> <GovActionID | all>

        [Opt: Anchor-URL, starting with "url: ..."], in Online-/Light-Mode the Hash will be calculated
        [Opt: Anchor-HASH, starting with "hash: ..."], to overwrite the Anchor-Hash in Offline-Mode


Examples:

   $(basename $0) myDRep 4d45bc8c9080542172b2c76caeb93c88d7dca415c3a2c71b508cbfc3785e98a8#0
   -> Generate a Vote-File for the DRep-ID of myDRep (myDRep.drep.*) and the proposal in Action-ID 4d45b...a8#0.

   $(basename $0) myDRep 4d45bc8c9080542172b2c76caeb93c88d7dca415c3a2c71b508cbfc3785e98a8#0 "url: https://mydomain.com/myvotingthoughts.json"
   -> Generate a Vote-File for the DRep-ID of myDRep (myDRep.drep.*) and the proposal in Action-ID 4d45b...a8#0
   -> Also attaching an Anchor-URL to f.e. describe the voting decision, etc.

   $(basename $0) myDRep all
   -> Generate a Vote-Files for the DRep-ID of myDRep (myDRep.drep.*) on all unexpired governance actions in one go

EOF
exit 1;
fi

#Check can only be done in online mode
if ${offlineMode}; then echo -e "\e[35mYou have to be in ONLINE or LIGHT mode to do this! Signing and Submitting the Vote-Tx can of course be done later on in OFFLINE mode.\e[0m\n"; exit 1; fi

#exit with an information, that the script needs at least conway era
case ${cliEra} in
        "babbage"|"alonzo"|"mary"|"allegra"|"shelley")
                echo -e "\n\e[91mINFORMATION - The chain is not in conway era yet. This script will start to work once we forked into conway era. Please check back later!\n\e[0m"; exit;
                ;;
esac


#Parameter Count is 2 or more
voterName="${1}"; voterName=${voterName%\.};
voterName="$(dirname ${voterName})/$(basename $(basename $(basename $(basename ${voterName} .drep) .cc-hot) .node) .vkey)"; voterName=${voterName/#.\//};
voterFile="$(dirname ${1})/$(basename ${1} .vkey)"; voterFile=${voterFile/#.\//}; voterFile=${voterFile%\.};
govActionID="${2,,}";

#Setting default variables
anchorURL=""; anchorHASH=""; anchorPARAM=""; #Setting defaults

#Check all optional parameters about there types and set the corresponding variables
#Starting with the 3th parameter (index=2) up to the last parameter
paramCnt=$#;
allParameters=( "$@" )
for (( tmpCnt=2; tmpCnt<${paramCnt}; tmpCnt++ ))
 do
        paramValue=${allParameters[$tmpCnt]}

        #Check if its an anchor-url
        if [[ "${paramValue,,}" =~ ^url:(.*)$ ]]; then #if the parameter starts with "url:" then set the anchorURL variable
                anchorURL=$(trimString "${paramValue:4}");
                #Check that the provided URL starts with 'https://'
                if [[ ! "${anchorURL}" =~ https://.* && ! "${anchorURL}" =~ ipfs://.* ]] || [[ ${#anchorURL} -gt 128 ]]; then echo -e "\e[35mERROR - The provided Anchor-URL '${anchorURL}'\ndoes not start with https:// or ipfs:// or is too long. Max. 128 chars allowed !\e[0m\n"; exit 1; fi

        #Check if its an anchor-hash - its only needed to overwrite the value in offline mode
        elif [[ "${paramValue,,}" =~ ^hash:(.*)$ ]]; then #if the parameter starts with "hash:" then set the anchorHASH variable
                anchorHASH=$(trimString "${paramValue:5}"); #trim it
                anchorHASH=${anchorHASH,,}; #lower case
                #Check that the provided HASH is a valid hex hash
                if [[ "${anchorHASH//[![:xdigit:]]}" != "${anchorHASH}" || ${#anchorHASH} -ne 64 ]]; then #parameter is not in hex or not 64 chars long
                        echo -e "\e[35mERROR - The provided Anchor-HASH '${anchorHASH}' is not in HEX or not 64chars long !\e[0m\n"; exit 1; fi

        fi #end of different parameters check

 done



#Checks for needed files / parameters

#Validate a correct Governance Action ID and split it up into the UTXO and index part
#Check if its a Governance Action-ID in Bech-Format
if [[ "${govActionID:0:11}" == "gov_action1" ]]; then #parameter is most likely a bech32-action-id
                #lets do some further testing by converting the bech32 DRep-id into a Hex-DRep-ID
                govActionID=$(convert_actionBech2UTXO ${govActionID}) #converts the given action bech id (CIP-129) into standard UTXO#IDX format
                if [ $? -ne 0 ]; then echo -e "\n\n\e[91mERROR - \"${2,,}\" is not a valid Bech32 ACTION-ID.\e[0m"; exit 1; fi
                govActionUTXO=${govActionID:0:64}
                govActionIdx=$(( ${govActionID:65} + 0 )) #make sure to have single digits if provided like #00 #01 #02...
elif [[ "${govActionID}" =~ ^([[:xdigit:]]{64}+#[[:digit:]]{1,})$ ]]; then
	govActionUTXO=${govActionID:0:64}
	govActionIdx=$(( ${govActionID:65} + 0 )) #make sure to have single digits if provided like #00 #01 #02...
elif [[ "${govActionID}" == "all" ]]; then #do the voting on all current gov-actions
	govActionUTXO=""; govActionIdx="";
else
	echo -e "\n\e[35mERROR - Please provide a valid Governance-Action-ID in the format like: \e[0m365042be18639f776520fca54e9cb2df04ab9ecd43bf50078045d8cc6ee491be#0\n"; exit 1;
fi


#Check VKEY Files
if [ -f "${voterFile}.vkey" ]; then #voterName was specified like xxx.drep, xxx.cc-hot or xxx.pool already

	voterVkeyFile="${voterFile}.vkey"

	case "${voterVkeyFile}" in #check filename endings

		*".drep.vkey")
			voterType="DRep";
			;;

		*".cc-hot.vkey")
			voterType="Committee-Hot";
			;;

		*".node.vkey")
			voterType="Pool";
			;;

		*)
			echo -e "\n\e[35mERROR - Please specify a DRep/CC-Hot/Pool name like mydrep.drep, mycom.cc-hot or mypool.node \e[0m\n";
			exit 1
			;;

	esac


elif [ -f "${voterName}.drep.vkey" ]; then #parameter is a DRep verification key file

	voterVkeyFile="${voterName}.drep.vkey"
	voterType="DRep"


elif [ -f "${voterName}.cc-hot.vkey" ]; then #parameter is a Committee-Hot verification key file

	voterVkeyFile="${voterName}.cc-hot.vkey"
	voterType="Committee-Hot"


elif [ -f "${voterName}.node.vkey" ]; then #parameter is a Pool verification key file

	voterVkeyFile="${voterName}.node.vkey"
	voterType="Pool"

else

	echo -e "\n\e[35mERROR - \"${voterName}.drep/cc-hot/pool.vkey\" does not exist.\e[0m\n";
	exit 1

fi


echo -e "\e[0mGenerating a Vote-File for ${voterType} PublicKey-File\e[32m ${voterVkeyFile}\e[0m"
echo

#get the voterhash, this is used to display a previous voting answer if available
voterHash=$(jq -r ".cborHex" "${voterVkeyFile}" 2> /dev/null | cut -c 5-69 | xxd -r -ps | b2sum -l 224 -b | cut -d' ' -f 1 2> /dev/null)
if [[ ! "${voterHash,,}" =~ ^([[:xdigit:]]{56})$ ]]; then echo -e "\n\e[91mERROR - Could not generate Voter-Hash from VKEY-File '${voterVkeyFile}'\n\e[0m"; exit 1; fi

#If in online/light mode, check the anchorURL
if ${onlineMode}; then


        #Check the cardano-signer binary existance and version
        if ! exists "${cardanosigner}"; then
                #Try the one in the scripts folder
                if [[ -f "${scriptDir}/cardano-signer" ]]; then cardanosigner="${scriptDir}/cardano-signer";
                else majorError "Path ERROR - Path to the 'cardano-signer' binary is not correct or 'cardano-singer' binaryfile is missing!\nYou can find it here: https://github.com/gitmachtl/cardano-signer/releases\nThis is needed to generate the signed Metadata. Also please check your 00_common.sh or common.inc settings."; exit 1; fi
        fi
        cardanosignerCheck=$(${cardanosigner} --version 2> /dev/null)
        if [[ $? -ne 0 ]]; then echo -e "\e[35mERROR - This script needs a working 'cardano-signer' binary. Please make sure you have it present with with the right path in '00_common.sh' !\e[0m\n\n"; exit 1; fi
        cardanosignerVersion=$(echo ${cardanosignerCheck} | cut -d' ' -f 2)
        versionCheck "${minCardanoSignerVersion}" "${cardanosignerVersion}"
        if [[ $? -ne 0 ]]; then majorError "Version ${cardanosignerVersion} ERROR - Please use a cardano-signer version ${minCardanoSignerVersion} or higher !\nOld versions are not compatible, please upgrade - thx."; exit 1; fi
        echo -e "\e[0mUsing Cardano-Signer Version: \e[32m${cardanosignerVersion}\e[0m\n";


        #get Anchor-URL content and calculate the Anchor-Hash
        if [[ ${anchorURL} != "" ]]; then

                #we write out the downloaded content to a file 1:1, so we can do a hash calculation on the file itself rather than on text content
                tmpAnchorContent="${tempDir}/anchorURLContent.tmp"; touch "${tmpAnchorContent}"; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

                #check if the URL is a normal one or an ipfs one, in case of ipfs, use https://ipfs.io/ipfs/xxx to load the content
                if [[ "${anchorURL}" =~ ipfs://.* ]]; then queryURL="https://ipfs.io/ipfs/${anchorURL:7}"; echo -e "\e[0mUsing the Query-URL\e[32m ${queryURL}\e[0m for ipfs\n"; else queryURL="${anchorURL}"; fi

                errorcnt=0; error=-1;
                showProcessAnimation "Query Anchor-URL content: " &
                while [[ ${errorcnt} -lt 5 && ${error} -ne 0 ]]; do #try a maximum of 5 times to request the information
                        error=0
                        response=$(curl -sL -m 10  --max-filesize 10485760 -X GET -w "---spo-scripts---%{http_code}" "${queryURL}" --output "${tmpAnchorContent}" 2> /dev/null)
			errorcode=$?
                        if [[ ${errorcode} -ne 0 ]]; then error=1; sleep 1; fi; #if there is an error, wait for a second and repeat
                        errorcnt=$(( ${errorcnt} + 1 ))
                done
                stopProcessAnimation;

                #if no error occured, split the response string into the content and the HTTP-ResponseCode
                if [[ ${error} -eq 0 && "${response}" =~ (.*)---spo-scripts---([0-9]*)* ]]; then

                        responseCode="${BASH_REMATCH[2]}"

                        #Check the responseCode
                        case ${responseCode} in
                                "200" )
					#all good, continue
                                        tmp=$(jq . < "${tmpAnchorContent}" 2> /dev/null) #just a short check that the received content is a valid JSON file
                                        if [ $? -ne 0 ]; then echo -e "\n\e[35mERROR - The content of the Anchor-URL '${anchorURL}'\nis not in valid JSON format!\n\e[0m"; rm "${tmpAnchorContent}"; exit 1; fi
                                        contentHASH=$(b2sum -l 256 "${tmpAnchorContent}" 2> /dev/null | cut -d' ' -f 1)
                                        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
                                        echo -e "\e[0m Vote-Anchor-URL:\e[32m ${anchorURL}\e[0m"
                                        if [[ ${anchorHASH} != "" ]]; then echo -e "\n\e[33mProvided Anchor-HASH '${anchorHASH}' will be ignored, continue ...\e[0m\n"; fi
                                        anchorHASH="${contentHASH}" #set the anchorHASH not to the provided one, use the one calculated from the online file
                                        echo -e "\e[0m   Anchor-Status: ${iconYes}\e[32m HASH set to ${anchorHASH}\e[0m";

					#Now we are checking the Integrity of the Anchor-File and the Author-Signatures
					signerJSON=$(${cardanosigner} verify --cip100 --data-file "${tmpAnchorContent}" --json-extended 2> /dev/stdout)
					if [ $? -ne 0 ]; then
						echo -e "\e[0m     Anchor-Data: ${iconNo}\e[35m ${signerJSON}\e[0m";
					else
						errorMsg=$(jq -r .errorMsg <<< ${signerJSON} 2> /dev/null)
						echo -e "\e[0m     Anchor-Data: ${iconYes}\e[32m JSONLD structure is ok\e[0m";
						if [[ "${errorMsg}" != "" ]]; then echo -e "\e[0m          Notice: ${iconNo} ${errorMsg}\e[0m"; fi
						authors=$(jq -r --arg iconYes "${iconYes}" --arg iconNo "${iconNo}" '.authors[] | "\\e[0m       Signature: \(if .valid then $iconYes else $iconNo end) \(.name)\\e[0m"' <<< ${signerJSON} 2> /dev/null)
						if [[ "${authors}" != "" ]]; then echo -e "${authors}\e[0m"; fi
					fi
					echo
                                        rm "${tmpAnchorContent}" #cleanup
                                        ;;

                                "404" )
					#file-not-found
                                        echo -e "\n\e[35mERROR - No content was found on the given Anchor-URL '${anchorURL}'\nPlease upload it first to this location, thx!\n\e[0m"; exit 1; #exit with a failure
                                        ;;

                                * )     echo -e "\n\e[35mERROR - Query of the Anchor-URL failed!\nHTTP Request File: ${anchorURL}\nHTTP Response Code: ${responseCode}\n\e[0m"; exit 1; #exit with a failure and the http response code
                                        ;;
                        esac;

                else
			if [[ ${errorcode} -eq 63 ]]; then echo -e "\n\e[35mAnchor-URL-File is too large (>10MB) !\e[0m"; fi
                        echo -e "\n\e[35mERROR - Query of the Anchor-URL '${anchorURL}' failed!\n\e[0m"; exit 1;
                fi #error & response
                unset errorcnt error

        fi # ${anchorURL} != ""

fi ## ${onlineMode} == true


#In online/light mode we should now have an anchorHASH if an anchorURL was provided
#Do a check - important for Offline-Mode -> and generate the parameters for the anchor if ok
if [[ ${anchorURL} != "" && ${anchorHASH} != "" ]]; then anchorPARAM="--anchor-url ${anchorURL} --anchor-data-hash ${anchorHASH}";
elif [[ ${anchorURL} != "" && ${anchorHASH} == "" ]]; then echo -e "\n\e[35mERROR - Please also provide an Anchor-HASH via the parameter \"hash: xxxxx\".\n\e[0m"; exit 1;
elif [[ ${anchorURL} == "" && ${anchorHASH} != "" ]]; then echo -e "\n\e[35mERROR - Please also provide an Anchor-URL via the parameter \"url: xxxxx\".\n\e[0m"; exit 1;
fi

#Now lets check about the Action-ID
if [[ "${govActionUTXO}" != "" ]]; then echo -e "\e[0mAction-Tx-ID: \e[32m${govActionUTXO}\n\e[0mAction-Index: \e[32m${govActionIdx}\e[0m\n"; fi

#Get state data for the Action-ID. In online mode of course from the node and the chain, in light mode via koios
case ${workMode} in

        "online")       if [[ $(get_currentSync) != "synced" ]]; then echo -e "\e[35mError - Node not fully synced or not running, please let your node sync to 100% first !\e[0m\n"; exit 1; fi
			showProcessAnimation "Query Governance-Action Info: " &
			govStateJSON=$(${cardanocli} ${cliEra} query gov-state 2> /dev/stdout)
                        if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${actionStateJSON}\e[0m\n"; exit 1; else stopProcessAnimation; fi;
			actionStateJSON=$(jq -r ".proposals | to_entries[] | .value" 2> /dev/null <<< "${govStateJSON}")
                        if [ $? -ne 0 ]; then echo -e "\e[35mERROR - ${actionStateJSON}\e[0m\n"; exit 1; fi;

			#Get currentEpoch for Active-dRep-Power-Filtering
			currentEpoch=$(get_currentEpoch)

			#Filter out expired Action-IDs only
			actionStateJSON=$(jq -r ". | select( .expiresAfter >= ${currentEpoch} )" 2> /dev/null <<< "${actionStateJSON}")

			#Filter for a given Action-ID
			if [[ ${govActionUTXO} != "" && ${govActionIdx} != "" ]]; then
				actionStateJSON=$(jq -r ". | select(.actionId.txId == \"${govActionUTXO}\" and .actionId.govActionIx == ${govActionIdx})" 2> /dev/null <<< "${actionStateJSON}")
				if [[ "${actionStateJSON}" = "" ]]; then #action-id not on chain
				        echo -e "\e[0mThe provided Action-ID is\e[33m NOT present on the chain\e[0m!\e[0m\n";
				        exit 1;
				fi
			fi


                        #### Voting Power Stuff
                        #Get DRep Stake Distribution for quorum calculation later on
                        #Only calculate the
			dRepPowerDistributionJSON=$(${cardanocli} ${cliEra} query drep-state --all-dreps --include-stake | jq -r "[ .[] | select( .[1].expiry >= ${currentEpoch} ) | [ \"drep-\(.[0] | keys[0])-\(.[0] | to_entries[].value)\", (.[1].stake // 0) ] ]" 2> /dev/stdout) #replicates the 'drep-stake-distribution' output but only with active dreps and without drep-alwaysAbstain and drep-alwaysNoConfidence
                        if [ $? -ne 0 ]; then echo -e "\e[35mERROR - ${dRepPowerDistributionJSON}\e[0m\n"; exit 1; fi;

                        #Calculate the total dRep stake power (sum of all drep stake distribution entries without the alwaysAbstain and alwaysNoConfidence ones)
                        dRepPowerActive=$(jq -r "[.[][1]] | add" <<< "${dRepPowerDistributionJSON}" 2> /dev/null) #Sum of all active dRep voting powers, drep-alwaysAbstain and drep-alwaysNoConfidence are excluded

                        #Get the alwaysNoConfidence stake power (counts as a no-power in all actions, except the NoConfidence-Action, there it counts to the yes-power)
                        dRepStakeDistributionJSON=$(${cardanocli} ${cliEra} query drep-stake-distribution --all-dreps 2> /dev/stdout) #only used for the dRepPowerAlwaysNoConfidence calculation
                        dRepPowerAlwaysNoConfidence=$(jq -r '(.[] | select(.[0] == "drep-alwaysNoConfidence") | .[1]) // 0' <<< "${dRepStakeDistributionJSON}" 2> /dev/null)

			#Get new Pool Stake Distribution including default delgation, for quorum calculation later on - available with this command since cli 10.2.0.0
			showProcessAnimation "Query Stakepool-Distribution Info: " &
			poolStakeDistributionJSON=$(${cardanocli} ${cliEra} query spo-stake-distribution --all-spos 2> /dev/stdout)
                        if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${poolStakeDistributionJSON}\e[0m\n"; exit 1; else stopProcessAnimation; fi;

			#Get the totally staked ADA -> total pool power
			poolPowerTotal=$(jq -r '[ .[][1] ] | add  // 0' <<< "${poolStakeDistributionJSON}" 2> /dev/null)

			#Get the committee power distribution -> Generate an Array of CommitteeHotHashes and there Votingpower (MembersAuthorized count as 1, all others like MemberNotAuthorized or MemberResigned count as 0)
			committeeStateJSON=$(${cardanocli} ${cliEra} query committee-state | jq -r "[ .committee | to_entries[] | select(.value.hotCredsAuthStatus.tag == \"MemberAuthorized\" and .value.status == \"Active\") ]" 2> /dev/null)
			committeePowerDistributionJSON=$(jq -r "[ ( .[] | [ \"\(.value.hotCredsAuthStatus.contents |keys[0])-\(.value.hotCredsAuthStatus.contents.keyHash // .value.hotCredsAuthStatus.contents.scriptHash)\", 1 ] ) ]" <<< "${committeeStateJSON}" 2> /dev/null)
			if [[ ${committeePowerDistributionJSON} == "" ]]; then committeePowerDistributionJSON="[]"; fi #in case there is no committee yet

			#Get the total committee power -> only authorized and active keys in the list, so the totalPower is just the length of the array
			committeePowerTotal=$(jq -r "length // 0" <<< ${committeeStateJSON} 2> /dev/null)

			#Get the current committee member voting threshold
			{ read committeePowerThreshold; } <<< $(jq -r '"\(.committee.threshold)" // 0' <<< ${govStateJSON} 2> /dev/null)
			committeeThresholdType=$(jq -r "type" <<< "${committeePowerThreshold}" 2> /dev/null)
			case ${committeeThresholdType} in
				"object")
					{ read numerator; read denominator; } <<< $(jq -r '.numerator // "-", .denominator // "-"' <<< "${committeePowerThreshold}")
					committeePowerThreshold=$(bc <<< "scale=2; 100.00 * ${numerator} / ${denominator}")
					;;

				"number")
					committeePowerThreshold=$(bc <<< "scale=2; 100.00 * ${committeePowerThreshold}") #scale it to 0.00-100.00%
					;;

                                "null") #a null threshold symbolizes the state committeeNoConfidence
                                        committeePowerThreshold=-1
                                        ;;

				*)      #if any other type, throw an error
					echo -e "\e[35mERROR - Could not handle committeeThresholdType = ${committeeThresholdType}\e[0m\n"; exit 1
					;;
			esac

			#Generate the JSON of all committeeHotHashes and there names, depending on the committeeColdHashes
			ccMemberHotHashNamesJSON=$(jq -r "[ .[] | { \"\(.value.hotCredsAuthStatus.contents | keys[0])-\(.value.hotCredsAuthStatus.contents | flatten[0])\": (${ccMemberColdHashNames}[.key]) } ] | reduce .[] as \$o ({}; . * \$o)" <<< ${committeeStateJSON} 2> /dev/null)

			#Get the current protocolParameters for the dRep and pool voting thresholds
                        protocolParametersJSON=$(${cardanocli} ${cliEra} query protocol-parameters)
                        ;;


	"light")
			voterID="" #disable filtering
		        showProcessAnimation "Query Governance-Action Info-LightMode: " &
			actionStateJSON=$(queryLight_actionState "${govActionUTXO}" "${govActionIdx}" "${voterID}")
                        if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${actionStateJSON}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
			#Filter for a given Action-ID and/or Voter was already done in the queryLight_actionState
			#strip the outter array for now
			actionStateJSON=$(jq -r ".[]" 2> /dev/null <<< "${actionStateJSON}")

			#Get the committeeState -> only use active and authorized members -> use it to generate the CC names for hotHashes
			showProcessAnimation "Query Committee-State LightMode: " &
			committeeStateLightJSON=$(queryLight_committeeState "")
			if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${committeeStateLightJSON}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
			committeeStateJSON=$(jq -r "[ .committee | to_entries[] | select(.value.hotCredsAuthStatus.tag == \"MemberAuthorized\" and .value.status == \"Active\") ]" <<< "${committeeStateLightJSON}" 2> /dev/null)
			if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - Could not generate committeeStateJSON\e[0m\n"; exit $?; else stopProcessAnimation; fi;
			#Generate the JSON of all committeeHotHashes and there names, depending on the committeeColdHashes
			ccMemberHotHashNamesJSON=$(jq -r "[ .[] | { \"\(.value.hotCredsAuthStatus.contents | keys[0])-\(.value.hotCredsAuthStatus.contents | flatten[0])\": (${ccMemberColdHashNames}[.key]) } ] | reduce .[] as \$o ({}; . * \$o)" <<< ${committeeStateJSON} 2> /dev/null)

			#Get the current protocolParameters for the dRep, pool and committee voting thresholds
			protocolParametersJSON=${lightModeParametersJSON} #lightmode

			#Get the total committee power -> only authorized and active keys in the list, so the totalPower is just the length of the array
			committeePowerTotal=$(jq -r "length // 0" <<< ${committeeStateJSON} 2> /dev/null)

			#Get the current committee member count and voting threshold
			committeeThreshold=$(jq -r '"\(.threshold)" // 0' 2> /dev/null <<< "${committeeStateLightJSON}")
			committeeThresholdType=$(jq -r "type" <<< "${committeeThreshold}" 2> /dev/null)
			case ${committeeThresholdType} in
				"object")
					{ read numerator; read denominator; } <<< $(jq -r '.numerator // "-", .denominator // "-"' <<< "${committeeThreshold}")
					committeePowerThreshold=$(bc <<< "scale=2; 100 * ${numerator} / ${denominator}")
					;;

				"number")
					committeePowerThreshold=$(bc <<< "scale=2; 100 * ${committeeThreshold}")
					;;

                                "null") #a null threshold symbolizes the state committeeNoConfidence
                                        committeePowerThreshold=-1
                                        ;;

				*)      #if any other type, throw an error
					echo -e "\e[35mERROR - Could not handle committeeThresholdType = ${committeeThresholdType}\e[0m\n"; exit 1
					;;
			esac
			;;

esac

{ read protocolVersionMajor; } <<< $(jq -r ".protocolVersion.major // -1" <<< ${protocolParametersJSON} 2> /dev/null)

#Convert the result(s) into an array and get the number of entries
actionStateJSON=$(jq --slurp <<< ${actionStateJSON})
actionStateEntryCnt=$(jq -r "length" <<< ${actionStateJSON})
if [[ ${actionStateEntryCnt} -eq 0 ]]; then echo -e "\e[91mNo matching votes found.\e[0m\n"; else echo -e "\e[0mFound: \e[32m${actionStateEntryCnt} entry/entries\e[0m\n"; fi

#Show all found entries
for (( tmpCnt=0; tmpCnt<${actionStateEntryCnt}; tmpCnt++ ))
do

	#Get the indexed Entry
	actionEntry=$(jq -r ".[${tmpCnt}]" <<< ${actionStateJSON})

	#In Light-Mode, request the content of the individual votes now
	if [[ ${workMode} == "light" ]]; then
		{ read actionUTXO; read actionIdx; } <<< $(jq -r '.actionId.txId // "-", .actionId.govActionIx // "-"' <<< ${actionEntry})
		showProcessAnimation "Query Action-Votes LightMode: " &
		actionVotesJSON=$(queryLight_actionVotes "${actionUTXO}" "${actionIdx}")
                if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${actionVotesJSON}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
		#merge the requested content in the current actionEntry
		actionEntry=$(jq -r ". += ${actionVotesJSON}" 2> /dev/null <<< "${actionEntry}")
	fi

	#We have found an action, lets get the Tag and number of votes so far
	{ read actionTag; read actionUTXO; read actionIdx;  read actionContents;
	  read actionAnchorUrl; read actionAnchorHash;
	  read actionProposedInEpoch; read actionExpiresAfterEpoch;
	  read actionDepositReturnKeyType; read actionDepositReturnHash; read actionDepositReturnNetwork;
	  read actionDRepVoteYesCount; read actionDRepVoteNoCount; read actionDRepAbstainCount;
	  read actionPoolVoteYesCount; read actionPoolVoteNoCount; read actionPoolAbstainCount;
	  read actionCommitteeVoteYesCount; read actionCommitteeVoteNoCount; read actionCommitteeAbstainCount;
	} <<< $(jq -r '.proposalProcedure.govAction.tag // "-", .actionId.txId // "-", .actionId.govActionIx // "-", "\(.proposalProcedure.govAction.contents)" // "-", .proposalProcedure.anchor.url // "-",
		.proposalProcedure.anchor.dataHash // "-", .proposedIn // "-", .expiresAfter // "-",
		(.proposalProcedure.returnAddr.credential|keys[0]) // "-", (.proposalProcedure.returnAddr.credential|flatten[0]) // "-", .proposalProcedure.returnAddr.network // "-",
		(.dRepVotes | with_entries(select(.value | contains("Yes"))) | length),
		(.dRepVotes | with_entries(select(.value | contains("No"))) | length),
		(.dRepVotes | with_entries(select(.value | contains("Abstain"))) | length),
		(.stakePoolVotes | with_entries(select(.value | contains("Yes"))) | length),
		(.stakePoolVotes | with_entries(select(.value | contains("No"))) | length),
		(.stakePoolVotes | with_entries(select(.value | contains("Abstain"))) | length),
		(.committeeVotes | with_entries(select(.value | contains("Yes"))) | length),
		(.committeeVotes | with_entries(select(.value | contains("No"))) | length),
		(.committeeVotes | with_entries(select(.value | contains("Abstain"))) | length)' <<< ${actionEntry})

	#Get the CIP129 Bech-Version of the current Action-ID
	actionBechFormat=$(convert_actionUTXO2Bech "${actionUTXO}#${actionIdx}")

	case ${workMode} in

		"online") #Calculate the VotingPowers via cli
			#Generate lists with the DRep hashes that are voted yes, no or abstain. Add a 'drep-' infront of each entry to mach up the syntax in the 'drep-stake-distribution' json
			{ read dRepHashYes; read dRepHashNo; read dRepHashAbstain; } <<< $(jq -r '"\(.dRepVotes | with_entries(select(.value | contains("Yes"))) | keys | ["drep-\(.[])"] )",
				"\(.dRepVotes | with_entries(select(.value | contains("No"))) | keys | ["drep-\(.[])"])",
				"\(.dRepVotes | with_entries(select(.value | contains("Abstain"))) | keys | ["drep-\(.[])"])"' <<< ${actionEntry} 2> /dev/null)
			#Calculate the total power of the yes, no and abstain keys
			{ read dRepPowerYes; read dRepPowerNo; read dRepPowerAbstain;} <<< $(jq -r "([ .[] | select(.[0]==${dRepHashYes}[]) | .[1] ] | add) // 0,
				([ .[] | select(.[0]==${dRepHashNo}[]) | .[1] ] | add) // 0,
				([ .[] | select(.[0]==${dRepHashAbstain}[]) | .[1] ] | add) // 0" <<< "${dRepPowerDistributionJSON}" 2> /dev/null)
			#Calculate the acceptance percentage for the DRep group
			if [[ "${actionTag}" != "NoConfidence" ]]; then #normal percentage calculate if its not a NoConfidence
				dRepPct=$(bc <<< "scale=2; 100.00 * ${dRepPowerYes} / ( ${dRepPowerActive} + ${dRepPowerAlwaysNoConfidence} - ${dRepPowerAbstain} )" 2> /dev/null)
				if [[ "${dRepPct}" == "" ]]; then dRepPct=0; fi #little error hack
				else #in case of NoConfidence, the dRepPowerAlwaysNoConfidence counts towards the yes counts
				dRepPct=$(bc <<< "scale=2; 100.00 * ( ${dRepPowerYes} + ${dRepPowerAlwaysNoConfidence} ) / ( ${dRepPowerActive} + ${dRepPowerAlwaysNoConfidence} - ${dRepPowerAbstain} )" 2> /dev/null)
				if [[ "${dRepPct}" == "" ]]; then dRepPct=0; fi #little error hack
			fi
			#Generate lists with the pool hashes that are voted yes, no or abstain on this action
			{ read poolHashYes; read poolHashNo; read poolHashAbstain; } <<< $(jq -r '"\(.stakePoolVotes | with_entries(select(.value | contains("Yes"))) | keys )",
				"\(.stakePoolVotes | with_entries(select(.value | contains("No"))) | keys)",
				"\(.stakePoolVotes | with_entries(select(.value | contains("Abstain"))) | keys)"' <<< ${actionEntry} 2> /dev/null)

			#Calculate the total power of the yes, no and abstain keys that have actively voted on this action
			{ read poolPowerVotedYes; read poolPowerVotedNo; read poolPowerVotedAbstain;} <<< $(jq -r "([ .[] | select(.[0]==${poolHashYes}[]) | .[1] ] | add) // 0,
				([ .[] | select(.[0]==${poolHashNo}[]) | .[1] ] | add) // 0,
				([ .[] | select(.[0]==${poolHashAbstain}[]) | .[1] ] | add) // 0" <<< "${poolStakeDistributionJSON}" 2> /dev/null)

			#Generate a new total poolStakeDistribution which excludes any actively voted pools
			poolStakeDistributionNotVotedJSON=$(jq -r "[ .[] | select(.[0] | IN(${poolHashYes}[]) or IN(${poolHashNo}[]) or IN(${poolHashAbstain}[]) | not ) ]" <<< "${poolStakeDistributionJSON}" 2> /dev/null)

			#Calculate the total pool stake power (sum of all pool stake distribution entries without the alwaysAbstain and alwaysNoConfidence ones) of the pools that have not voted
			poolPowerNotVotedTotal=$(jq -r '[del(.[] | select(.[2] == "drep-alwaysAbstain" or .[2] == "drep-alwaysNoConfidence")) | .[][1]] | add' <<< "${poolStakeDistributionNotVotedJSON}" 2> /dev/null)

			#Get the alwaysNoConfidence pool stake power (counts as a no-power in all actions, except the NoConfidence-Action, there it counts to the yes-power)
			poolPowerAlwaysNoConfidence=$(jq -r '[ .[] | select(.[2] == "drep-alwaysNoConfidence") | .[1] ] | add  // 0' <<< "${poolStakeDistributionNotVotedJSON}" 2> /dev/null)

			#Calculate the acceptance percentage for the Pool group
			case "${actionTag}" in

				"NoConfidence") #Calculate the defaultAlwaysNoConfidence to the YES bucket, default alwaysAbstain is not used in the calculation
					poolPct=$(bc <<< "scale=2; 100.00 * ( ${poolPowerVotedYes} + ${poolPowerAlwaysNoConfidence} ) / ( ${poolPowerNotVotedTotal} + ${poolPowerAlwaysNoConfidence} + ${poolPowerVotedYes} + ${poolPowerVotedNo} )" 2> /dev/null)
					;;

				"HardForkInitiation") #The defaultAlwaysAbstain counts towards the NO bucket. So we can simply take the totalStake minus the actively voted abtain ones
					poolPct=$(bc <<< "scale=2; ( 100.00 * ${poolPowerVotedYes} ) / ( ${poolPowerTotal} - ${poolPowerVotedAbstain} )" 2> /dev/null)
					;;

				*) #Rest of the actions
					poolPct=$(bc <<< "scale=2; ( 100.00 * ${poolPowerVotedYes} ) / ( ${poolPowerNotVotedTotal} + ${poolPowerAlwaysNoConfidence} + ${poolPowerVotedYes} + ${poolPowerVotedNo} )" 2> /dev/null)
					;;
			esac
			if [[ "${poolPct}" == "" ]]; then poolPct=0; fi #little error hack

			#Generate lists with the committee hashes that are voted yes, no or abstain.
			{ read committeeHashYes; read committeeHashNo; read committeeHashAbstain; } <<< $(jq -r '"\(.committeeVotes | with_entries(select(.value | contains("Yes"))) | keys )",
				"\(.committeeVotes | with_entries(select(.value | contains("No"))) | keys)",
				"\(.committeeVotes | with_entries(select(.value | contains("Abstain"))) | keys)"' <<< ${actionEntry} 2> /dev/null)
			#Calculate the total power of the yes, no and abstain keys
			{ read committeePowerYes; read committeePowerNo; read committeePowerAbstain;} <<< $(jq -r "([ .[] | select(.[0]==${committeeHashYes}[]) | .[1] ] | add) // 0,
				([ .[] | select(.[0]==${committeeHashNo}[]) | .[1] ] | add) // 0,
				([ .[] | select(.[0]==${committeeHashAbstain}[]) | .[1] ] | add) // 0" <<< "${committeePowerDistributionJSON}" 2> /dev/null)

			#Calculate the acceptance percentage for the committee
			if [[ $((${committeePowerTotal}-${committeePowerAbstain})) -eq 0 ]]; then committeePct=0; else committeePct=$(bc <<< "scale=2; ( 100.00 * ${committeePowerYes} ) / ( ${committeePowerTotal} - ${committeePowerAbstain} )"); fi
			;;

		"light") #Get the VotingPowers/Percentage via koios
			showProcessAnimation "Query Votes-Percentages LightMode: " &
			actionVotesSummaryJSON=$(queryLight_actionVotesSummary "${actionBechFormat}")
			if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${actionVotesSummaryJSON}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
			{ read dRepPct;
				read poolPct;
				read committeePct;
				read dRepPowerAlwaysNoConfidence;
				read poolPowerAlwaysNoConfidence;
				read dRepPowerYes;
				read dRepPowerNo;
				read dRepPowerAbstain;
				read poolPowerVotedYes;
				read poolPowerVotedNo;
				read poolPowerVotedAbstain; } <<< $(jq -r '.[0].drep_yes_pct // 0,
								.[0].pool_yes_pct // 0,
								.[0].committee_yes_pct // 0,
								.[0].drep_always_no_confidence_vote_power // 0,
								.[0].pool_passive_always_no_confidence_vote_power // 0,
								.[0].drep_yes_vote_power // 0,
								.[0].drep_active_no_vote_power // 0,
								.[0].drep_active_abstain_vote_power // 0,
								.[0].pool_yes_vote_power // 0,
								.[0].pool_active_no_vote_power // 0,
								.[0].pool_active_abstain_vote_power // 0 ' <<< ${actionVotesSummaryJSON})

			#Generate lists with the committee hashes that have voted yes, no or abstain.
			{ read committeeHashYes; read committeeHashNo; read committeeHashAbstain; } <<< $(jq -r '"\(.committeeVotes | with_entries(select(.value | contains("Yes"))) | keys )",
				"\(.committeeVotes | with_entries(select(.value | contains("No"))) | keys)",
				"\(.committeeVotes | with_entries(select(.value | contains("Abstain"))) | keys)"' <<< ${actionEntry} 2> /dev/null)
			;;
	esac

	#Setup variables
	totalAccept=""; totalAcceptIcon="";
	dRepAcceptIcon=""; poolAcceptIcon=""; committeeAcceptIcon="";
	dRepPowerThreshold="N/A"; poolPowerThreshold="N/A"; #N/A -> not available

	echo
	echo -e "\e[36m--- Entry $((${tmpCnt}+1)) of ${actionStateEntryCnt} --- Action-ID ${actionUTXO}#${actionIdx}\e[0m"
	echo
	echo -e "Action-Bech: \e[32m${actionBechFormat}\e[0m"
	echo
	echo -e "Action-Type: \e[32m${actionTag}\e[0m   \tProposed in Epoch: \e[32m${actionProposedInEpoch}\e[0m   \tExpires after Epoch: \e[32m${actionExpiresAfterEpoch}\e[0m"
	echo

	#Show the Anchor-URL(HASH) if available
	if [[ "${actionAnchorUrl}" != "-" ]]; then
		echo -e "\e[0mAnchor-Url(Hash):\e[32m ${actionAnchorUrl} \e[0m(${actionAnchorHash})\n"
	fi

	#If in online/light mode, check the actionAnchorUrl
	if ${onlineMode}; then

	        #get Anchor-URL content and calculate the Anchor-Hash
	        if [[ "${actionAnchorUrl}" != "-" ]]; then

	                #we write out the downloaded content to a file 1:1, so we can do a hash calculation on the file itself rather than on text content
	                tmpAnchorContent="${tempDir}/actionAnchorUrlContent.tmp"; touch "${tmpAnchorContent}"; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

	                #check if the URL is a normal one or an ipfs one, in case of ipfs, use https://ipfs.io/ipfs/xxx to load the content
	                if [[ "${actionAnchorUrl}" =~ ipfs://.* ]]; then queryURL="https://ipfs.io/ipfs/${actionAnchorUrl:7}"; else queryURL="${actionAnchorUrl}"; fi

	                echo -e "\e[0m       Query-URL:\e[94m ${queryURL}\e[0m";

	                errorcnt=0; error=-1;
	                showProcessAnimation "Query Anchor-URL content: " &
	                while [[ ${errorcnt} -lt 5 && ${error} -ne 0 ]]; do #try a maximum of 5 times to request the information
	                        error=0
	                        response=$(curl -sL -m 10 --max-filesize 10485760 -X GET -w "---spo-scripts---%{http_code}" "${queryURL}" --output "${tmpAnchorContent}" 2> /dev/null)
	                        errorcode=$?;
	                        if [[ ${errorcode} -ne 0 ]]; then error=1; sleep 1; fi; #if there is an error, wait for a second and repeat
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
	                                                if [ "${contentHASH}" != "${actionAnchorHash}" ]; then
	                                                        echo -e "\e[0m   Anchor-Status: ${iconNo}\e[35m HASH does not match! Online-HASH is \e[33m${contentHASH}\e[0m";
	                                                else
	                                                        echo -e "\e[0m   Anchor-Status: ${iconYes}\e[32m File-Content-HASH is ok\e[0m";

	                                                        #Now we are checking the Integrity of the Anchor-File and the Author-Signatures
	                                                        signerJSON=$(${cardanosigner} verify --cip100 --data-file "${tmpAnchorContent}" --json-extended 2> /dev/stdout)
	                                                        if [ $? -ne 0 ]; then
	                                                                echo -e "\e[0m     Anchor-Data: ${iconNo}\e[35m ${signerJSON}\e[0m";
	                                                                else
	                                                                errorMsg=$(jq -r .errorMsg <<< ${signerJSON} 2> /dev/null)
	                                                                echo -e "\e[0m     Anchor-Data: ${iconYes}\e[32m JSONLD structure is ok\e[0m";
	                                                                if [[ "${errorMsg}" != "" ]]; then echo -e "\e[0m          Notice: ${iconNo} ${errorMsg}\e[0m"; fi
					                                authors=$(jq -r --arg iconYes "${iconYes}" --arg iconNo "${iconNo}" '.authors[] | "\\e[0m       Signature: \(if .valid then $iconYes else $iconNo end) \(.name)\\e[0m"' <<< ${signerJSON} 2> /dev/null)
	                                                                if [[ "${authors}" != "" ]]; then echo -e "${authors}\e[0m"; fi
	                                                        fi
	                                                fi
	                                                rm "${tmpAnchorContent}" #cleanup

	                                        fi #anchor is a json
	                                        ;;

	                                "404" ) #file-not-found
	                                        echo -e "\e[0m  Anchor-Status: ${iconNo}\e[35m No content was found on the Anchor-URL\e[0m";
	                                        ;;

	                                * )
	                                        echo -e "\e[0m  Anchor-Status: ${iconNo}\e[35m Query of the Anchor-URL failed!\n\nHTTP Request File: ${actionAnchorUrl}\nHTTP Response Code: ${responseCode}\n\e[0m";
	                                        ;;
	                        esac;

	                else
	                                        echo -e "\e[0m  Anchor-STATUS:\e[35m Query of the Anchor-URL failed!\e[0m";
	                                        if [[ ${errorcode} -eq 63 ]]; then echo -e "\e[0m    Anchor-File:\e[35m File is bigger than 10MB!\e[0m"; fi

	                fi #error & response
	                unset errorcnt error

	        fi # ${actionAnchorUrl} != ""

	fi ## ${onlineMode} == true

	echo

        #Show deposit return stakeaddress
        case "${actionDepositReturnNetwork,,}${actionDepositReturnKeyType,,}" in
		*"scripthash")	echo -e "\e[0mDeposit Return-ScriptHash:\e[32m ${actionDepositReturnHash} \e[0m\n"
				;;

		"mainnet"*)	actionDepositAddr=$(${bech32_bin} "stake" <<< "e1${actionDepositReturnHash}" 2> /dev/null);
				if [[ $? -ne 0 ]]; then echo -e "\n\e[35mERROR - Could not get Deposit-Return Stake-Address from Return-KeyHash '${actionDepositReturnHash}' !\n\e[0m"; exit 1; fi
				echo -e "\e[0mDeposit Return-StakeAddr:\e[32m ${actionDepositAddr} \e[0m\n"
				;;

		"testnet"*)	actionDepositAddr=$(${bech32_bin} "stake_test" <<< "e0${actionDepositReturnHash}" 2> /dev/null);
				if [[ $? -ne 0 ]]; then echo -e "\n\e[35mERROR - Could not get Deposit-Return Stake-Address from Return-KeyHash '${actionDepositReturnHash}' !\n\e[0m"; exit 1; fi
				echo -e "\e[0mDeposit Return-StakeAddr:\e[32m ${actionDepositAddr} \e[0m\n"
				;;

		*)              echo -e "\n\e[35mERROR - Unknown network type ${actionDepositReturnNetwork} for the Deposit-Return KeyHash !\n\e[0m"; exit 1;
				;;
	esac


	#DO A NICE OUTPUT OF THE DIFFERENT CONTENTS & DO THE RIGHT CALCULATIONS FOR THE ACCEPTANCE
	case "${actionTag}" in

			"InfoAction")
						#This is just an InfoAction
						#Show referencing Action-Id if avaiable
						{ read prevActionUTXO; read prevActionIDX; } <<< $(jq -r '.txId // "-", .govActionIx // "-"' 2> /dev/null <<< ${actionContents})
						if [[ ${#prevActionUTXO} -gt 1 ]]; then echo -e "Reference-Action-ID: \e[32m${prevActionUTXO}#${prevActionIDX}\e[0m\n"; fi
						echo -e "\e[0mAction-Content:\e[36m Information\e[0m"
						echo -e "\e[0m"

						dRepAcceptIcon="N/A"; poolAcceptIcon="N/A";
						totalAccept="N/A";
						#If we are in committeeNoConfidence mode(thresholdpower=-1), remove the committeeAcceptIcon
						if [[ ${committeePowerThreshold} == "-1" ]]; then committeeAcceptIcon="";
						elif [[ $(bc <<< "${committeePct} >= ${committeePowerThreshold}") -eq 1 ]]; then committeeAcceptIcon="\e[92m✅";
						else committeeAcceptIcon="\e[91m❌"; totalAccept+="NO";
						fi
						;;


			"HardForkInitiation")
						#show the proposed major/minor version to fork to
						# [
						#  null,  //or prev action-id
						#  {
						#    "major": 9,
						#    "minor": 1
						#  }
						# ]
						#Show referencing Action-Id if avaiable
						{ read prevActionUTXO; read prevActionIDX; read forkMajorVer; read forkMinorVer; } <<< $(jq -r '.[0].txId // "-", .[0].govActionIx // "-", .[1].major // "-", .[1].minor // "-"' 2> /dev/null <<< ${actionContents})
						if [[ ${#prevActionUTXO} -gt 1 ]]; then echo -e "Reference-Action-ID: \e[32m${prevActionUTXO}#${prevActionIDX}\e[0m\n"; fi
						echo -e "\e[0mAction-Content:\e[36m Do a Hardfork\e[0m\n"
						echo -e "\e[0mFork to\e[32m Protocol-Version \e[0m► \e[94m${forkMajorVer}.${forkMinorVer}\e[0m"
						echo -e "\e[0m"

						#Calculate acceptance: Get the right threshold, make it a nice percentage number, check if threshold is reached
						{ read dRepPowerThreshold; read poolPowerThreshold; } <<< $(jq -r '.dRepVotingThresholds.hardForkInitiation // 0, .poolVotingThresholds.hardForkInitiation // 0' <<< "${protocolParametersJSON}" 2> /dev/null)
						dRepPowerThreshold=$(bc <<< "scale=2; 100.00 * ${dRepPowerThreshold}")
						if [[ ${protocolVersionMajor} -ge 10 ]]; then #only do dRep check if we are at least in conway chang-2 phase
							if [[ $(bc <<< "${dRepPct} >= ${dRepPowerThreshold}") -eq 1 ]]; then dRepAcceptIcon="\e[92m✅"; else dRepAcceptIcon="\e[91m❌"; totalAccept+="NO"; fi
						fi
						poolPowerThreshold=$(bc <<< "scale=2; 100.00 * ${poolPowerThreshold}")
						if [[ $(bc <<< "${poolPct} >= ${poolPowerThreshold}") -eq 1 ]]; then poolAcceptIcon="\e[92m✅"; else poolAcceptIcon="\e[91m❌"; totalAccept+="NO"; fi

						#If we are in committeeNoConfidence mode(thresholdpower=-1), remove the committeeAcceptIcon
						if [[ ${committeePowerThreshold} == "-1" ]]; then committeeAcceptIcon=""; totalAccept+="NO";
						elif [[ $(bc <<< "${committeePct} >= ${committeePowerThreshold}") -eq 1 ]]; then committeeAcceptIcon="\e[92m✅";
						else committeeAcceptIcon="\e[91m❌"; totalAccept+="NO";
						fi
						;;


			"ParameterChange")
						#show the proposed parameterchanges
						# [
						#  {
						#    "govActionIx": 0,
						#    "txId": "950d4b364840a27afeba929324d51dec0fac80b00cf7ca37905de08e3eae5ca6"
						#  },
						#  {
						#    "poolVotingThresholds": {
						#      "committeeNoConfidence": 0.51,
						#      "committeeNormal": 0.04,
						#      "hardForkInitiation": 0.51,
						#      "motionNoConfidence": 0.51,
						#      "ppSecurityGroup": 0.51
						#    }
						#  },
						#  null
						# ]
						{ read prevActionUTXO; read prevActionIDX; read changeParameters; } <<< $(jq -r '.[0].txId // "-", .[0].govActionIx // "-", "\(.[1])" // "-"' 2> /dev/null <<< ${actionContents})
						if [[ ${#prevActionUTXO} -gt 1 ]]; then echo -e "Reference-Action-ID: \e[32m${prevActionUTXO}#${prevActionIDX}\e[0m\n"; fi
						echo -e "\e[0mAction-Content:\e[36m Change protocol parameters\n\e[0m"
						changeParameterRender=$(jq -r 'to_entries[] | "\\e[0mChange parameter\\e[32m \(.key) \\e[0m► \\e[94m\(.value)\\e[0m"' <<< ${changeParameters} 2> /dev/null)
						echo -e "${changeParameterRender}"
						echo -e "\e[0m"

						dRepPowerThreshold="0"; #start with a zero threshold, we are searching the max value in the next steps

						#Calculate acceptance depending on the security group a parameter belongs to: Get the right threshold, make it a nice percentage number, check if threshold is reached
						case "${changeParameters}" in

							#SECURITY GROUP - pools must vote on it
							*"maxBlockBodySize"*|*"maxTxSize"*|*"maxBlockHeaderSize"*|*"maxValueSize"*|*"maxBlockExecutionUnits"*|*"txFeePerByte"*|*"txFeeFixed"*|*"utxoCostPerByte"*|*"govActionDeposit"*|*"minFeeRefScriptCostPerByte"*)
								{ read poolPowerThreshold; } <<< $(jq -r '.poolVotingThresholds.ppSecurityGroup // 0' <<< "${protocolParametersJSON}" 2> /dev/null)
								poolPowerThreshold=$(bc <<< "scale=2; 100.00 * ${poolPowerThreshold}")
								if [[ $(bc <<< "${poolPct} >= ${poolPowerThreshold}") -eq 1 ]]; then poolAcceptIcon="\e[92m✅"; else poolAcceptIcon="\e[91m❌"; totalAccept+="NO"; fi
								echo -e "A parameter from the \e[32mSECURITY\e[0m group is present ► \e[94mStakePools must vote\e[0m"
								;;& #also check next condition

							#NETWORK GROUP
							*"maxBlockBodySize"*|*"maxTxSize"*|*"maxBlockHeaderSize"*|*"maxValueSize"*|*"maxTxExecutionUnits"*|*"maxBlockExecutionUnits"*|*"maxCollateralInputs"*)
								dRepPowerThreshold=$(jq -r "[ ${dRepPowerThreshold}, .dRepVotingThresholds.ppNetworkGroup // 0 ] | max" <<< "${protocolParametersJSON}" 2> /dev/null)
								echo -e "A parameter from the \e[32mNETWORK\e[0m group is present"
								;;& #also check next condition

							#ECONOMIC GROUP
							*"txFeePerByte"*|*"txFeeFixed"*|*"stakeAddressDeposit"*|*"stakePoolDeposit"*|*"monetaryExpansion"*|*"treasuryCut"*|*"minPoolCost"*|*"utxoCostPerByte"*|*"executionUnitPrices"*)
								dRepPowerThreshold=$(jq -r "[ ${dRepPowerThreshold}, .dRepVotingThresholds.ppEconomicGroup // 0 ] | max" <<< "${protocolParametersJSON}" 2> /dev/null)
								echo -e "A parameter from the \e[32mECONOMIC\e[0m group is present"
								;;& #also check next condition

							#TECHNICAL GROUP
							*"poolPledgeInfluence"*|*"poolRetireMaxEpoch"*|*"stakePoolTargetNum"*|*"costModels"*|*"collateralPercentage"*)
								dRepPowerThreshold=$(jq -r "[ ${dRepPowerThreshold}, .dRepVotingThresholds.ppTechnicalGroup // 0 ] | max" <<< "${protocolParametersJSON}" 2> /dev/null)
								echo -e "A parameter from the \e[32mTECHNICAL\e[0m group is present"
								;;& #also check next condition

							#GOVERNANCE GROUP
							*"govActionLifetime"*|*"govActionDeposit"*|*"dRepDeposit"*|*"dRepActivity"*|*"committeeMinSize"*|*"committeeMaxTermLength"*|*"VotingThresholds"*)
								dRepPowerThreshold=$(jq -r "[ ${dRepPowerThreshold}, .dRepVotingThresholds.ppGovGroup // 0 ] | max" <<< "${protocolParametersJSON}" 2> /dev/null)
								echo -e "A parameter from the \e[32mGOVERNANCE\e[0m group is present"
								;;

						esac

						#Throw an error if for some reason, the dRepPowerThreshold is still at zero or empty
						if [[ "${dRepPowerThreshold}" == "0" || "${dRepPowerThreshold}" == "" ]]; then echo -e "\e[35mERROR - Something went wrong finding the dRepPowerThreshold.\n\e[0m"; exit 1; fi

						echo

						#Now lets use the choosen threshold (highest of all involved groups)
						dRepPowerThreshold=$(bc <<< "scale=2; 100.00 * ${dRepPowerThreshold}")
						if [[ ${protocolVersionMajor} -ge 10 ]]; then #only do dRep check if we are at least in conway chang-2 phase
							if [[ $(bc <<< "${dRepPct} >= ${dRepPowerThreshold}") -eq 1 ]]; then dRepAcceptIcon="\e[92m✅"; else dRepAcceptIcon="\e[91m❌"; totalAccept+="NO"; fi
						fi

						#If we are in committeeNoConfidence mode(thresholdpower=-1), remove the committeeAcceptIcon
						if [[ ${committeePowerThreshold} == "-1" ]]; then committeeAcceptIcon=""; totalAccept+="NO";
						elif [[ $(bc <<< "${committeePct} >= ${committeePowerThreshold}") -eq 1 ]]; then committeeAcceptIcon="\e[92m✅";
						else committeeAcceptIcon="\e[91m❌"; totalAccept+="NO";
						fi
						;;


			"NewConstitution")
						#show the proposed infos/anchor for a new constition
						# [
						#  {
						#    "govActionIx": 0,
						#    "txId": "597686b8c917ba2c74cd0018f3fb325bddf0f1fe747038170c41373376c03b5c"
						#  },
						#  {
						#    "anchor": {
						#      "dataHash": "9dc89b0f3e54b36759e886236f10744667996fd10306a188d54c39ade5fb18b8",
						#      "url": "http://bit.ly / NBPet"
						#    }
						#  }
						# ]
						{ read prevActionUTXO; read prevActionIDX; read anchorHash; read anchorURL; read scriptHash; } <<< $(jq -r '.[0].txId // "-", .[0].govActionIx // "-", .[1].anchor.dataHash // "-", .[1].anchor.url // "-", .[1].script // "-"' 2> /dev/null <<< ${actionContents})
						if [[ ${#prevActionUTXO} -gt 1 ]]; then echo -e "Reference-Action-ID: \e[32m${prevActionUTXO}#${prevActionIDX}\e[0m\n"; fi
						echo -e "\e[0mAction-Content:\e[36m Change to a new Constitution\e[0m\n"
						echo -e "\e[0mSet new\e[32m Constitution-URL \e[0m► \e[94m${anchorURL}\e[0m"
						echo -e "\e[0mSet new\e[32m Constitution-Hash \e[0m► \e[94m${anchorHash}\e[0m"
						echo -e "\e[0mSet new\e[32m Guardrails-Script-Hash \e[0m► \e[94m${scriptHash}\e[0m"
						echo -e "\e[0m"

						#Calculate acceptance: Get the right threshold, make it a nice percentage number, check if threshold is reached
						{ read dRepPowerThreshold; } <<< $(jq -r '.dRepVotingThresholds.updateToConstitution // 0' <<< "${protocolParametersJSON}" 2> /dev/null)
						dRepPowerThreshold=$(bc <<< "scale=2; 100.00 * ${dRepPowerThreshold}")
						if [[ $(bc <<< "${dRepPct} >= ${dRepPowerThreshold}") -eq 1 ]]; then dRepAcceptIcon="\e[92m✅"; else dRepAcceptIcon="\e[91m❌"; totalAccept+="NO"; fi
						poolAcceptIcon=""; #pools not allowed to vote on this
						#If we are in committeeNoConfidence mode(thresholdpower=-1), remove the committeeAcceptIcon
						if [[ ${committeePowerThreshold} == "-1" ]]; then committeeAcceptIcon=""; totalAccept+="NO";
						elif [[ $(bc <<< "${committeePct} >= ${committeePowerThreshold}") -eq 1 ]]; then committeeAcceptIcon="\e[92m✅";
						else committeeAcceptIcon="\e[91m❌"; totalAccept+="NO";
						fi
						;;


			"UpdateCommittee")
						#show the proposed infos for a committeeupdate
						# [
						#  null,
						#  [],  #remove members in this section
						#  {
						#    "keyHash-5f1b4429fe3bda963a7b70ab81135112a785afcf55ccd695b122e794": 379,   #adding new members in this section
						#    "keyHash-9393c87a66b1f7dd4f9b486a49232de92e39e18b3b20ac4a539b4df2": 379,
						#    "keyHash-a0de8358f1bd3644b4482bee197197c075a82ef2088b0a0ed561b7ee": 379,
						#    "keyHash-a88042b034c1ecb45468dccbe91dcac8c6c39f7bee7b7a8dde41e4d4": 379,
						#    "keyHash-b7bfc26ddc6718133a204af6872149b69de83dd3350f60b257e55773": 379,
						#    "keyHash-cebc104901ccf159028eb89aec4b96b820936d9f2d92c310cf610220": 379,
						#    "keyHash-faa9ee9fd9cba8cc01c07a34469e2d9fc9132985abe9f802bbf5cdc7": 379
						#  },
						#  {
						#    "denominator": 7, #threshold
						#    "numerator": 4
						#  }
						#]
						{ read prevActionUTXO; read prevActionIDX; read committeeKeyHashesRemove; read committeeKeyHashesAdd; read committeeThreshold; } <<< $(jq -r '.[0].txId // "-", .[0].govActionIx // "-", "\(.[1])" // "[]", "\(.[2])" // "[]", "\(.[3])" // "-"' 2> /dev/null <<< ${actionContents})
						if [[ ${#prevActionUTXO} -gt 1 ]]; then echo -e "Reference-Action-ID: \e[32m${prevActionUTXO}#${prevActionIDX}\e[0m\n"; fi
						committeeKeyHashesAdd=$(jq -r "keys" <<< ${committeeKeyHashesAdd} 2> /dev/null)
						committeeKeyHashesRemove=$(jq -r "[.[].keyHash]" <<< ${committeeKeyHashesRemove} 2> /dev/null)
						echo -ne "\e[0mAction-Content:\e[36m Threshold -> "
						committeeThresholdType=$(jq -r "type" <<< ${committeeThreshold} 2> /dev/null)
						case ${committeeThresholdType} in
							"object")
								{ read numerator; read denominator; } <<< $(jq -r '.numerator // "-", .denominator // "-"' <<< ${committeeThreshold})
								echo -e "Approval of a governance measure requires ${numerator} out of ${denominator} ($(bc <<< "scale=0; (${numerator}*100/${denominator})/1")%) of the votes of committee members.\e[0m\n"
								;;

							"number")
								echo -e "Approval of a governance measure requires $(bc <<< "scale=0; (${committeeThreshold}*100)/1")% of the votes of committee members.\e[0m\n"
								;;
						esac

						addHashesRender=$(jq -r '.[2] // {} | to_entries[] | "\\e[0mAdding\\e[32m \(.key)-\(.value)" | split("-") | "\(.[0]) \\e[0m► \\e[94m\(.[1])\\e[0m (max term epoch \(.[2]))"' <<< ${actionContents} 2> /dev/null)
						remHashesRender=$(jq -r '.[1][] // [] | to_entries[] | "\\e[0mRemove\\e[32m \(.key) \\e[0m◄ \\e[91m\(.value)\\e[0m"' <<< ${actionContents} 2> /dev/null)
						echo -e "${addHashesRender}"
						echo -e "${remHashesRender}"
						echo -e "\e[0m"

						#Calculate acceptance: Get the right threshold, make it a nice percentage number, check if threshold is reached

						#If we are in committeeNoConfidence mode(thresholdpower=-1), use the committeeNoConfidence parameter set
						if [[ ${committeePowerThreshold} != "-1" ]]; then
							{ read dRepPowerThreshold; read poolPowerThreshold; } <<< $(jq -r '.dRepVotingThresholds.committeeNormal // 0, .poolVotingThresholds.committeeNormal // 0' <<< "${protocolParametersJSON}" 2> /dev/null)
						else
							{ read dRepPowerThreshold; read poolPowerThreshold; } <<< $(jq -r '.dRepVotingThresholds.committeeNoConfidence // 0, .poolVotingThresholds.committeeNoConfidence // 0' <<< "${protocolParametersJSON}" 2> /dev/null)
						fi
						dRepPowerThreshold=$(bc <<< "scale=2; 100.00 * ${dRepPowerThreshold}")
						if [[ $(bc <<< "${dRepPct} >= ${dRepPowerThreshold}") -eq 1 ]]; then dRepAcceptIcon="\e[92m✅"; else dRepAcceptIcon="\e[91m❌"; totalAccept+="NO"; fi
						poolPowerThreshold=$(bc <<< "scale=2; 100.00 * ${poolPowerThreshold}")
						if [[ $(bc <<< "${poolPct} >= ${poolPowerThreshold}") -eq 1 ]]; then poolAcceptIcon="\e[92m✅"; else poolAcceptIcon="\e[91m❌"; totalAccept+="NO"; fi
						committeeAcceptIcon=""; #committee not allowed to vote on this
						;;

			"NoConfidence")
						#This is just a NoConfidence action
						#Show referencing Action-Id if avaiable
						{ read prevActionUTXO; read prevActionIDX; } <<< $(jq -r '.txId // "-", .govActionIx // "-"' 2> /dev/null <<< ${actionContents})
						if [[ ${#prevActionUTXO} -gt 1 ]]; then echo -e "Reference-Action-ID: \e[32m${prevActionUTXO}#${prevActionIDX}\e[0m\n"; fi
						echo -e "\e[0mAction-Content:\e[36m No Confidence in the Committee\e[0m"
						echo -e "\e[0m"

						#Calculate acceptance: Get the right threshold, make it a nice percentage number, check if threshold is reached
						{ read dRepPowerThreshold; read poolPowerThreshold; } <<< $(jq -r '.dRepVotingThresholds.committeeNoConfidence // 0, .poolVotingThresholds.committeeNoConfidence // 0' <<< "${protocolParametersJSON}" 2> /dev/null)
						dRepPowerThreshold=$(bc <<< "scale=2; 100.00 * ${dRepPowerThreshold}")
						if [[ $(bc <<< "${dRepPct} >= ${dRepPowerThreshold}") -eq 1 ]]; then dRepAcceptIcon="\e[92m✅"; else dRepAcceptIcon="\e[91m❌"; totalAccept+="NO"; fi
						poolPowerThreshold=$(bc <<< "scale=2; 100.00 * ${poolPowerThreshold}")
						if [[ $(bc <<< "${poolPct} >= ${poolPowerThreshold}") -eq 1 ]]; then poolAcceptIcon="\e[92m✅"; else poolAcceptIcon="\e[91m❌"; totalAccept+="NO"; fi
						committeeAcceptIcon=""; #committee not allowed to vote on this
						;;

			"TreasuryWithdrawals")
						#show the treasury withdrawals address and amount
						#[
						#  [
						#    [
						#      {
						#        "credential": {
						#          "keyHash": "c13582aec9a44fcc6d984be003c5058c660e1d2ff1370fd8b49ba73f"
						#        },
						#        "network": "Testnet"
						#      },
						#      1234567890
						#    ]
						#  ],
						#  null
						#]
						{ read withdrawalsAmount; read withdrawalsKeyType; read withdrawalsHash; read withdrawalsNetwork; } <<< $( jq -r '.[0][0][1] // "0", (.[0][0][0].credential|keys[0]) // "-", (.[0][0][0].credential|flatten[0]) // "-", .[0][0][0].network // "-"' 2> /dev/null <<< ${actionContents})
						echo -e "\e[0mAction-Content:\e[36m Withdrawal funds from the treasury\n\e[0m"

						case "${withdrawalsNetwork,,}${withdrawalsKeyType,,}" in

							*"scripthash")	echo -e "\e[0mWithdrawal to\e[32m ScriptHash \e[0m► \e[94m${withdrawalsHash}\e[0m"
									;;

							"mainnet"*)	withdrawalsAddr=$(${bech32_bin} "stake" <<< "e1${withdrawalsHash}" 2> /dev/null);
									if [[ $? -ne 0 ]]; then echo -e "\n\e[35mERROR - Could not get Withdrawals Stake-Address from KeyHash '${withdrawalsHash}' !\n\e[0m"; exit 1; fi
									echo -e "\e[0mWithdrawal to\e[32m StakeAddr \e[0m► \e[94m${withdrawalsAddr}\e[0m"
									;;

							"testnet"*)	withdrawalsAddr=$(${bech32_bin} "stake_test" <<< "e0${withdrawalsHash}" 2> /dev/null);
									if [[ $? -ne 0 ]]; then echo -e "\n\e[35mERROR - Could not get Withdrawals Stake-Address from KeyHash '${withdrawalsHash}' !\n\e[0m"; exit 1; fi
									echo -e "\e[0mWithdrawal to\e[32m StakeAddr \e[0m► \e[94m${withdrawalsAddr}\e[0m"
									;;

							"")		echo -e "\e[0mWithdrawal \e[32mdirectly\e[0m to the \e[94mDeposit-Return-Address\n\e[0m"
									;;

							*)              echo -e "\n\e[35mERROR - Unknown network type ${withdrawalsNetwork} for the Withdrawal KeyHash !\n\e[0m"; exit 1;
									;;
						esac
						echo -e "\e[0mWithdrawal the\e[32m Amount \e[0m► \e[94m$(convertToADA ${withdrawalsAmount}) ADA / ${withdrawalsAmount} lovelaces\e[0m"
						echo -e "\e[0m"

						#Calculate acceptance: Get the right threshold, make it a nice percentage number, check if threshold is reached
						{ read dRepPowerThreshold; } <<< $(jq -r '.dRepVotingThresholds.treasuryWithdrawal // 0' <<< "${protocolParametersJSON}" 2> /dev/null)
						dRepPowerThreshold=$(bc <<< "scale=2; 100.00 * ${dRepPowerThreshold}")
						if [[ $(bc <<< "${dRepPct} >= ${dRepPowerThreshold}") -eq 1 ]]; then dRepAcceptIcon="\e[92m✅"; else dRepAcceptIcon="\e[91m❌"; totalAccept+="NO"; fi
						poolAcceptIcon=""; #pools not allowed to vote on this
						#If we are in committeeNoConfidence mode(thresholdpower=-1), remove the committeeAcceptIcon
						if [[ ${committeePowerThreshold} == "-1" ]]; then committeeAcceptIcon=""; totalAccept+="NO";
						elif [[ $(bc <<< "${committeePct} >= ${committeePowerThreshold}") -eq 1 ]]; then committeeAcceptIcon="\e[92m✅";
						else committeeAcceptIcon="\e[91m❌"; totalAccept+="NO";
						fi
						;;



	esac

	printf "\e[97mCurrent Votes\e[90m │     \e[0mYes\e[90m    │     \e[0mNo\e[90m     │   \e[0mAbstain\e[90m  │ \e[0mAlwNoConfi\e[90m │ \e[0mThreshold\e[90m │ \e[97mLive-Pct\e[90m │ \e[97mAccept\e[0m\n"
	printf "\e[90m──────────────┼────────────┼────────────┼────────────┼────────────┼───────────┼──────────┼────────\e[0m\n"
	if [[ "${dRepAcceptIcon}" != "" ]]; then
		printf "\e[94m%13s\e[90m │ \e[32m%10s\e[90m │ \e[91m%10s\e[90m │ \e[33m%10s\e[90m │ \e[33m%10s\e[90m │ \e[0m%7s %%\e[90m │ \e[97m%6s %%\e[90m │   %b \e[0m\n" "DReps" "${actionDRepVoteYesCount}" "${actionDRepVoteNoCount}" "${actionDRepAbstainCount}" "" "${dRepPowerThreshold}" "${dRepPct}" "${dRepAcceptIcon}"
		printf "\e[94m%13s\e[90m │ \e[32m%10s\e[90m │ \e[91m%10s\e[90m │ \e[33m%10s\e[90m │ \e[90m%10s\e[90m │ %9s │ %8s │ \e[0m\n" "" "$(convertToShortADA ${dRepPowerYes})" "$(convertToShortADA ${dRepPowerNo})" "$(convertToShortADA ${dRepPowerAbstain})" "$(convertToShortADA ${dRepPowerAlwaysNoConfidence})" "" ""
		else
		printf "\e[90m%13s\e[90m │ \e[90m%10s\e[90m │ \e[90m%10s\e[90m │ \e[33m%10s\e[90m │ \e[90m%10s\e[90m │ \e[90m%7s %%\e[90m │ \e[90m%6s %%\e[90m │   %b \e[0m\n" "DReps" "-" "-" "-" "-" "-" "-" ""
	fi
	printf "\e[90m──────────────┼────────────┼────────────┼────────────┼────────────┼───────────┼──────────┼────────\e[0m\n"
	if [[ "${poolAcceptIcon}" != "" ]]; then
		printf "\e[94m%13s\e[90m │ \e[32m%10s\e[90m │ \e[91m%10s\e[90m │ \e[33m%10s\e[90m │ \e[33m%10s\e[90m │ \e[0m%7s %%\e[90m │ \e[97m%6s %%\e[90m │   %b \e[0m\n" "StakePools" "${actionPoolVoteYesCount}" "${actionPoolVoteNoCount}" "${actionPoolAbstainCount}" "" "${poolPowerThreshold}" "${poolPct}" "${poolAcceptIcon}"
		printf "\e[94m%13s\e[90m │ \e[32m%10s\e[90m │ \e[91m%10s\e[90m │ \e[33m%10s\e[90m │ \e[90m%10s\e[90m │ %9s │ %8s │ \e[0m\n" "" "$(convertToShortADA ${poolPowerVotedYes})" "$(convertToShortADA ${poolPowerVotedNo})" "$(convertToShortADA ${poolPowerVotedAbstain})" "$(convertToShortADA ${poolPowerAlwaysNoConfidence})" "" ""
		else
		printf "\e[90m%13s\e[90m │ \e[90m%10s\e[90m │ \e[90m%10s\e[90m │ \e[33m%10s\e[90m │ \e[90m%10s\e[90m │ \e[90m%7s %%\e[90m │ \e[90m%6s %%\e[90m │   %b \e[0m\n" "StakePools" "-" "-" "-" "-" "-" "-" ""
	fi
	printf "\e[90m──────────────┼────────────┼────────────┼────────────┼────────────┼───────────┼──────────┼────────\e[0m\n"
	if [[ "${committeeAcceptIcon}" != "" ]]; then
		printf "\e[94m%13s\e[90m │ \e[32m%10s\e[90m │ \e[91m%10s\e[90m │ \e[33m%10s\e[90m │ \e[90m%10s\e[90m │ \e[0m%7s %%\e[90m │ \e[97m%6s %%\e[90m │   %b \e[0m\n" "Committee" "${actionCommitteeVoteYesCount}" "${actionCommitteeVoteNoCount}" "${actionCommitteeAbstainCount}" "" "${committeePowerThreshold}" "${committeePct}" "${committeeAcceptIcon}"
		else
		printf "\e[90m%13s\e[90m │ \e[90m%10s\e[90m │ \e[90m%10s\e[90m │ \e[90m%10s\e[90m │ \e[90m%10s\e[90m │ \e[90m%7s %%\e[90m │ \e[90m%6s %%\e[90m │   %b \e[0m\n" "Committee" "-" "-" "-" "" "-" "-"
	fi

	#show CC names that have voted -> replace the hotHash with the name from the ccMemberHotHashNames-JSON, convert linebreaks into spaces (make it a line), wordwrap the line, trimstrim each line, make it an array
	readarray -t committeeNamesYes <<< $(jq -r ".[] | ${ccMemberHotHashNamesJSON}[.] // \"Unknown?\"" <<< "${committeeHashYes}" 2> /dev/null | tr '\n' ' ' | fold -w 11 -s | awk '{$1=$1};1')
	readarray -t committeeNamesNo <<< $(jq -r ".[] | ${ccMemberHotHashNamesJSON}[.] // \"Unknown?\"" <<< "${committeeHashNo}" 2> /dev/null | tr '\n' ' ' | fold -w 11 -s | awk '{$1=$1};1')
	readarray -t committeeNamesAbstain <<< $(jq -r ".[] | ${ccMemberHotHashNamesJSON}[.] // \"Unknown?\"" <<< "${committeeHashAbstain}" 2> /dev/null | tr '\n' ' ' | fold -w 11 -s | awk '{$1=$1};1')
	tmpCnt2=0
	while [[ "${committeeNamesYes[${tmpCnt2}]}${committeeNamesNo[${tmpCnt2}]}${committeeNamesAbstain[${tmpCnt2}]}" != "" ]]; do
		printf "\e[94m%13s\e[90m │ \e[32m%10s\e[90m │ \e[91m%10s\e[90m │ \e[33m%10s\e[90m │ \e[90m%10s\e[90m │ \e[0m%7s  \e[90m │ \e[97m%6s  \e[90m │ \e[0m\n" "" "${committeeNamesYes[${tmpCnt2}]}" "${committeeNamesNo[${tmpCnt2}]}" "${committeeNamesAbstain[${tmpCnt2}]}" "" "" ""
		tmpCnt2=$(( ${tmpCnt2} + 1 ))
	done
	unset committeeNamesYes committeeNamesNo committeeNamesAbstain tmpCnt2

	printf "\e[90m──────────────┴────────────┴────────────┴────────────┴────────────┴───────────┴──────────┼────────\e[0m\n"
	case "${totalAccept}" in
		*"N/A"*)	totalAcceptIcon="N/A";;
		*"NO"*)		totalAcceptIcon="\e[91m❌";;
		*)		totalAcceptIcon="\e[92m✅";;
	esac
	printf  "\e[97m%88s\e[90m │   %b \e[0m\n" "Full approval of the proposal" "${totalAcceptIcon}"

	#show an alert if we are in the no confidence mode
	if [[ ${committeePowerThreshold} == "-1" ]]; then echo -e "\e[35mWe are currently in the 'No Confidence' state !\e[0m\n"; fi

	echo

	#If there is a voterHash, get the voting answer for it
	if [[ "${voterHash}" != "" ]]; then
		voteAnswer=$(jq -r ".dRepVotes[\"keyHash-${voterHash}\"] // .committeeVotes[\"keyHash-${voterHash}\"] // .dRepVotes[\"scriptHash-${voterHash}\"] // .committeeVotes[\"scriptHash-${voterHash}\"] // .stakePoolVotes[\"${voterHash}\"]" 2> /dev/null <<< "${actionEntry}")
		#In case its included in the answers, show the current on chain status
		case "${voteAnswer}" in
			*"Yes"*)	echo -e "\e[97mYou've already voted on this Action-ID before, your on chain ${voterType}-Voter answer is: \e[102m\e[30m YES \e[0m\n";;
			*"No"*)	echo -e "\e[97mYou've already voted on this Action-ID before, your on chain ${voterType}-Voter answer is: \e[101m\e[30m NO \e[0m\n";;
			*"Abstain"*)	echo -e "\e[97mYou've already voted on this Action-ID before, your on chain ${voterType}-Voter answer is: \e[43m\e[30m ABSTAIN \e[0m\n";;
		esac
	fi


#Check if the used voterType is allowed to do a vote on the actionTag
case "${voterType}_${actionTag}" in

	"Committee-Hot_NoConfidence"|"Committee-Hot_UpdateCommittee"|"Pool_NewConstitution"|"Pool_TreasuryWithdrawals")
		echo -e "\n\e[91mSORRY - This voterType '${voterType}' is not allowed to vote on an action of type '${actionTag}'!\n\e[0m"; exit 1
		;;

	"Pool_ParameterChange")
		if [[ "${parameterSecurityGroup}" == "false" ]]; then echo -e "\n\e[91mSORRY - This proposal does not contain a parameter of the SecurityGroup, so voterType '${voterType}' is not allowed to vote!\n\e[0m"; exit 1; fi
		;;

	"DRep_ParameterChange"|"DRep_HardForkInitiation")
		if [[ ${protocolVersionMajor} -lt 10 ]]; then #if we are not in chang-2 phase
			echo -e "\n\e[91mSORRY - This voterType '${voterType}' is not allowed to vote on an action of type '${actionTag}' during Conway-Bootstrap-Phase (Chang-1) !\n\e[0m"; exit 1
		fi
		;;

esac

#Get the voting answer from the user
while true; do
	# Ask the question (not using "read -p" as it uses stderr not stdout)
        echo -ne "\e[0mPlease vote on that Action-ID [\e[32mYes\e[0m/\e[91mNo\e[0m/\e[33mAbstain\e[0m/\e[90mSkip\e[0m/CANCEL] ? "

        # Read the answer (use /dev/tty in case stdin is redirected from somewhere else)
        read reply </dev/tty

        # Default?
        if [ -z "$reply" ]; then
            reply="CANCEL"
        fi

        # Check if the reply is valid
        case "$reply" in
		Y*|y*) 	voteParam="--yes";
			echo -e "\nYour voting decision is set to: \e[32mYES\e[0m";
			break ;;

		N*|n*) 	voteParam="--no";
			echo -e "\nYour voting decision is set to: \e[91mNO\e[0m";
			break ;;

		A*|a*) 	voteParam="--abstain";
			echo -e "\nYour voting decision is set to: \e[33mABSTAIN\e[0m";
			break ;;

		S*|s*)	voteParam=""; break ;; #just skip that vote

		C*|c*) 	echo -e "\e[0m\n"; exit;; #exit the script
        esac

done

echo -e "\e[0m"


#Generate vote file if a decision was choosen, skip it if not
if [[ "${voteParam}" != "" ]]; then

	#Output filename for the Voting-Certificate
	datestr=$(date +"%y%m%d%H%M%S")
	case ${voterType} in

		"DRep")
			votingFile="${voterName}_${datestr}.drep.vote"
			vkeyParam="--drep-verification-key-file";;

		"Committee-Hot")
			votingFile="${voterName}_${datestr}.cc-hot.vote"
			vkeyParam="--cc-hot-verification-key-file";;

		"Pool")
			votingFile="${voterName}_${datestr}.pool.vote"
			vkeyParam="--cold-verification-key-file";;

	esac

	#Generate the vote file depending on the choice made above
	voteJSON=$(${cardanocli} ${cliEra} governance vote create ${voteParam} --governance-action-tx-id "${actionUTXO}" --governance-action-index "${actionIdx}" ${vkeyParam} "${voterVkeyFile}" ${anchorPARAM} --out-file /dev/stdout 2> /dev/stdout)
	checkError "$?"; if [ $? -ne 0 ]; then echo -e "\e[35mERROR - ${voteJSON}\e[0m\n"; exit 1; fi
	echo "${voteJSON}" > "${votingFile}"; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

	echo -e "\e[0mCreated the Vote-Certificate file: \e[32m${votingFile}\e[90m"
	cat "${votingFile}"
	echo -e "\e[0m"

	echo
	echo -e "\e[33mIf you wanna submit the Vote-Certificate now, please run the script 24b like:"
	echo -e "\"./24b_regVote.sh ${voterName} myWallet ${votingFile}\"\e[0m"
	echo

fi

done #every govaction entry

echo -e "\e[0m\n"
