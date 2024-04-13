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


if [ $# -lt 1 ]; then #we need at least one parameter
cat >&2 <<EOF

Usage:  $(basename $0) <DRep-Name/ID/Hash | Committee-Hot-Name/Hash | Pool-Name/ID> and/or <Action-ID> and/or <Action-Type> or <all>

ActionTypes: HardForkInitiation, InfoAction, NewConstitution, NoConfidence, ParameterChange, TreasuryWithdrawals, UpdateCommittee

Examples:

   $(basename $0) myDRep
   -> Get the current vote(s) on which the DRep 'myDRep' voted.

   $(basename $0) drep13mna226yvxz682sf5d57m55lf9yh05clhyxahkl9psgc7ycthtu
   -> Get the current vote(s) on which the DRep with id 'drep13mna226yvxz682sf5d57m55lf9yh05clhyxahkl9psgc7ycthtu' voted.

   $(basename $0) 5aa349227e4068c85c03400396bcea13c7fd57d0ec78c604bc768fc5
   -> Get the current vote(s) on which the Hash '5aa349227e4068c85c03400396bcea13c7fd57d0ec78c604bc768fc5' voted.

   $(basename $0) 4d45bc8c9080542172b2c76caeb93c88d7dca415c3a2c71b508cbfc3785e98a8#0
   -> Get the current status of Action-ID '4d45bc8c9080542172b2c76caeb93c88d7dca415c3a2c71b508cbfc3785e98a8#0'

   $(basename $0) myDrep 4d45bc8c9080542172b2c76caeb93c88d7dca415c3a2c71b508cbfc3785e98a8#0
   -> Get the vote of 'myDrep' on Action-ID '4d45bc8c9080542172b2c76caeb93c88d7dca415c3a2c71b508cbfc3785e98a8#0'

   $(basename $0) infoaction
   -> Get all current vote(s) of type 'InfoAction'

   $(basename $0) all
   -> Get all current vote(s)


EOF
exit 1;
fi

echo -e "\e[0mQuery the voting state of a DRep, Committee-Hot, Pool and/or an Action-ID:"
echo

#Check can only be done in online mode
if ${offlineMode}; then echo -e "\e[35mYou have to be in ONLINE or LIGHT mode to do this!\e[0m\n"; exit 1; fi

#Default Variables
govActionID=""; voterHash=""; voterType="";

#Parameter Count is 1 or more

#Check all parameters about there types and set the corresponding variables
#Starting with the 1st parameter (index=0) up to the last parameter
paramCnt=$#;
allParameters=( "$@" )
for (( tmpCnt=0; tmpCnt<${paramCnt}; tmpCnt++ ))
 do
        paramValue=${allParameters[$tmpCnt]}

	#Check if its a Governance Action-ID
	if [[ "${paramValue,,}" =~ ^([[:xdigit:]]{64}+#[[:digit:]]{1,})$ ]]; then
		if [[ "${govActionID}" != "" ]]; then echo -e "\n\e[91mERROR - Only one Action-ID is allowed as parameter!\e[0m\n"; exit 1; fi
		govActionID="${paramValue,,}"
	        echo -e "\e[0mUsing Governance Action-ID:\e[32m ${govActionID}\e[0m\n"
		govActionUTXO=${govActionID:0:64}
		govActionIdx=$(( ${govActionID:65} + 0 )) #make sure to have single digits if provided like #00 #01 #02...

	#Check if its a Voter-Hash. Could be a DRep, CC-Hot or Pool-Hash. We don't know.
	elif [[ "${paramValue,,}" =~ ^([[:xdigit:]]{56})$ ]]; then
		if [[ "${voterHash}" != "" ]]; then echo -e "\n\e[91mERROR - Only one Voter-Hash is allowed as parameter!\e[0m\n"; exit 1; fi
		voterHash="${paramValue,,}"
		voterType="Hash"

	#Check if its a DRep-ID in Bech-Format
	elif [[ "${paramValue:0:5}" == "drep1" && ${#paramValue} -eq 56 ]]; then #parameter is most likely a bech32-drep-id
	        echo -ne "\e[0mCheck if given DRep Bech-ID\e[32m ${paramValue}\e[0m is valid ..."
	        #lets do some further testing by converting the bech32 DRep-id into a Hex-DRep-ID
	        voterHash=$(${bech32_bin} 2> /dev/null <<< "${paramValue,,}") #will have returncode 0 if the bech was valid
	        if [ $? -ne 0 ]; then echo -e "\n\n\e[91mERROR - \"${paramValue}\" is not a valid Bech32 DRep-ID.\e[0m"; exit 1; fi
	        echo -e "\e[32m OK\e[0m\n"
		voterType="DRep"

	#Check if its a DRep-ID file with a Bech-ID
	elif [[ -f "${paramValue}.drep.id" ]]; then #parameter is a DRep id file, containing a bech32 id
		echo -ne "\e[0mReading from DRep-ID-File\e[32m ${paramValue}.drep.id\e[0m ..."
		drepID=$(cat "${paramValue}.drep.id" 2> /dev/null)
		if [ $? -ne 0 ]; then echo -e "\n\n\e[91mERROR - Could not read from file \"${paramValue}.drep.id\"\e[0m"; exit 1; fi
		echo -e "\e[32m OK\e[0m\n"
	        echo -ne "\e[0mCheck if the DRep Bech-ID\e[32m ${drepID}\e[0m is valid ..."
	        voterHash=$(${bech32_bin} 2> /dev/null <<< "${drepID}") #will have returncode 0 if the bech was valid
	        if [ $? -ne 0 ]; then echo -e "\n\n\e[91mERROR - \"${drepID}\" is not a valid Bech32 DRep-ID.\e[0m"; exit 1; fi
		echo -e "\e[32m OK\e[0m\n"
		voterType="DRep"

	#Check if its a Committee-Hot-ID in Bech-Format
	elif [[ "${paramValue:0:7}" == "cc_hot1" && ${#paramValue} -eq 58 ]]; then #parameter is most likely a bech32-committee-hot-id
	        echo -ne "\e[0mCheck if given Committee-Hot Bech-ID\e[32m ${paramValue}\e[0m is valid ..."
	        #lets do some further testing by converting the bech32 DRep-id into a Hex-DRep-ID
	        voterHash=$(${bech32_bin} 2> /dev/null <<< "${paramValue,,}") #will have returncode 0 if the bech was valid
	        if [ $? -ne 0 ]; then echo -e "\n\n\e[91mERROR - \"${paramValue}\" is not a valid Bech32 Committee-Hot-ID.\e[0m"; exit 1; fi
	        echo -e "\e[32m OK\e[0m\n"
		voterType="Committee-Hot"

	#Check if its a Committee-Hot-Hash File
	elif [[ -f "${paramValue}.cc-hot.hash" ]]; then #parameter is a Committee Hot hash file, containing the hash id
		echo -ne "\e[0mReading from Committee-Hot-HASH-File\e[32m ${paramValue}.cc-hot.hash\e[0m ..."
		voterHash=$(cat "${paramValue}.cc-hot.hash" 2> /dev/null)
	        if [ $? -ne 0 ]; then echo -e "\n\n\e[35mERROR - Could not read from file \"${paramValue}.cc-hot.hash\"\e[0m"; exit 1; fi
	        echo -e "\e[32m OK\e[0m\n"
		if [[ ! "${voterHash,,}" =~ ^([[:xdigit:]]{56})$ ]]; then echo -e "\n\e[91mERROR - Content of Committee-Hot-Hash File '${paramValue}.cc-hot.hash' is not a valid Voter-Hash!\n\e[0m"; exit 1; fi
		voterType="Committee-Hot"

	#Check if its a Pool-ID in Bech-Format
	elif [[ "${paramValue:0:5}" == "pool1" && ${#paramValue} -eq 56 ]]; then #parameter is most likely a bech32-pool-id
	        echo -ne "\e[0mCheck if given Pool Bech-ID\e[32m ${paramValue}\e[0m is valid ..."
	        #lets do some further testing by converting the bech32 DRep-id into a Hex-DRep-ID
	        voterHash=$(${bech32_bin} 2> /dev/null <<< "${paramValue,,}") #will have returncode 0 if the bech was valid
	        if [ $? -ne 0 ]; then echo -e "\n\n\e[91mERROR - \"${paramValue}\" is not a valid Bech32 Pool-ID.\e[0m"; exit 1; fi
	        echo -e "\e[32m OK\e[0m\n"
		voterType="Pool"

	#Check if its a Pool-ID File with the hex Pool-ID
	elif [[ -f "${paramValue}.pool.id" ]]; then #parameter is a Pool-ID file, containing the hash id in hex format
		echo -ne "\e[0mReading from Pool_ID-File\e[32m ${paramValue}.pool.id\e[0m ..."
		voterHash=$(cat "${paramValue}.pool.id" 2> /dev/null)
	        if [ $? -ne 0 ]; then echo -e "\n\n\e[35mERROR - Could not read from file \"${paramValue}.pool.id\"\e[0m"; exit 1; fi
	        echo -e "\e[32m OK\e[0m\n"
		if [[ ! "${voterHash,,}" =~ ^([[:xdigit:]]{56})$ ]]; then echo -e "\n\e[91mERROR - Content of Pool-ID File '${paramValue}.pool.id' is not a valid Voter-Hash!\n\e[0m"; exit 1; fi
		voterType="Pool"

	#Check VKEY Files for all three types
	elif [[ -f "${paramValue}.vkey" ]]; then #parameter was the first part of a vkey file
	        voterVkeyFile="${paramValue}.vkey"
	        case "${voterVkeyFile}" in #check filename endings
			*".drep.vkey") 		voterType="DRep";;
	                *".cc-hot.vkey")	voterType="Committee-Hot";;
			*".node.vkey")		voterType="Pool";;
	                *) echo -e "\n\e[35mERROR - Please specify a DRep/CC-Hot/Pool name like mydrep.drep, mycom.cc-hot or mypool.node \e[0m\n"; exit 1;;
		esac
	        echo -ne "\e[0mReading ${voterType} VKEY-File\e[32m ${voterVkeyFile}\e[0m ..."
		voterHash=$(jq -r ".cborHex" "${voterVkeyFile}" 2> /dev/null | cut -c 5-69 | xxd -r -ps | b2sum -l 224 -b | cut -d' ' -f 1 2> /dev/null)
		if [[ ! "${voterHash,,}" =~ ^([[:xdigit:]]{56})$ ]]; then echo -e "\n\e[91mERROR - Could not generate Voter-Hash from VKEY-File '${voterVkeyFile}'\n\e[0m"; exit 1; fi
	        echo -e "\e[32m OK\e[0m\n"

	#Check if its a DRep VKEY file
	elif [[ -f "${paramValue}.drep.vkey" ]]; then #parameter is a DRep verification key file
		voterVkeyFile="${paramValue}.drep.vkey"
		voterType="DRep"
	        echo -ne "\e[0mReading ${voterType} VKEY-File\e[32m ${voterVkeyFile}\e[0m ..."
		voterHash=$(jq -r ".cborHex" "${voterVkeyFile}" 2> /dev/null | cut -c 5-69 | xxd -r -ps | b2sum -l 224 -b | cut -d' ' -f 1 2> /dev/null)
		if [[ ! "${voterHash,,}" =~ ^([[:xdigit:]]{56})$ ]]; then echo -e "\n\e[91mERROR - Could not generate Voter-Hash from VKEY-File '${voterVkeyFile}'\n\e[0m"; exit 1; fi
	        echo -e "\e[32m OK\e[0m\n"

	#Check if its as Committee-Hot VKEY file
	elif [[ -f "${paramValue}.cc-hot.vkey" ]]; then #parameter is a Committee-Hot verification key file
		voterVkeyFile="${paramValue}.cc-hot.vkey"
		voterType="Committee-Hot"
	        echo -ne "\e[0mReading ${voterType} VKEY-File\e[32m ${voterVkeyFile}\e[0m ..."
		voterHash=$(jq -r ".cborHex" "${voterVkeyFile}" 2> /dev/null | cut -c 5-69 | xxd -r -ps | b2sum -l 224 -b | cut -d' ' -f 1 2> /dev/null)
		if [[ ! "${voterHash,,}" =~ ^([[:xdigit:]]{56})$ ]]; then echo -e "\n\e[91mERROR - Could not generate Voter-Hash from VKEY-File '${voterVkeyFile}'\n\e[0m"; exit 1; fi
	        echo -e "\e[32m OK\e[0m\n"

	#Check if its as Pool VKEY file
	elif [[ -f "${paramValue}.node.vkey" ]]; then #parameter is a Pool verification key file
		voterVkeyFile="${paramValue}.node.vkey"
		voterType="Pool"
	        echo -ne "\e[0mReading ${voterType} VKEY-File\e[32m ${voterVkeyFile}\e[0m ..."
		voterHash=$(jq -r ".cborHex" "${voterVkeyFile}" 2> /dev/null | cut -c 5-69 | xxd -r -ps | b2sum -l 224 -b | cut -d' ' -f 1 2> /dev/null)
		if [[ ! "${voterHash,,}" =~ ^([[:xdigit:]]{56})$ ]]; then echo -e "\n\e[91mERROR - Could not generate Voter-Hash from VKEY-File '${voterVkeyFile}'\n\e[0m"; exit 1; fi
	        echo -e "\e[32m OK\e[0m\n"

	#Check if its an Action-Type
	elif [[ "${paramValue,,}" == "hardforkinitiation" || "${paramValue,,}" == "infoaction" || "${paramValue,,}" == "newconstitution" || "${paramValue,,}" == "noconfidence" || "${paramValue,,}" == "parameterchange" || "${paramValue,,}" == "treasurywithdrawals" || "${paramValue,,}" == "updatecommittee" ]]; then
		if [[ "${govActionType}" != "" ]]; then echo -e "\n\e[91mERROR - Only one Action-Type is allowed as parameter!\e[0m\n"; exit 1; fi
		govActionType="${paramValue,,}"
	        echo -e "\e[0mUsing Governance Action-Type:\e[32m ${govActionType}\e[0m\n"

	#Exit the check if the keyword 'all' was used -> don't filter on a action-id or voter-hash or action-type
	elif [[ "${paramValue,,}" == "all" ]]; then
		voterType=""; voterHash=""; govActionID=""; govActionUTXO=""; govActionIdx=""; govActionType="";
		break;

	#Unknown parameter
	else

		echo -e "\n\e[35mERROR - I don't know what to do with the parameter '${paramValue}'.\n\n\e[0mIf you wanna show all votes, please use the parameter 'all'.\n"; exit 1;

        fi #end of different parameters check

 done #for loop

if [[ "${voterHash}" != "" ]]; then echo -e "\e[0mVoter-Type is\e[32m ${voterType}\e[0m with the Voter-Hash:\e[94m ${voterHash}\e[0m\n"; fi

#Get state data for the Action-ID. In online mode of course from the node and the chain, in light mode via koios
case ${workMode} in

        "online")       showProcessAnimation "Query Governance-Action Info: " &
			actionStateJSON=$(${cardanocli} ${cliEra} query gov-state 2> /dev/stdout)
                        if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${actionStateJSON}\e[0m\n"; exit 1; else stopProcessAnimation; fi;
			actionStateJSON=$(jq -r ".proposals | to_entries[] | .value" 2> /dev/null <<< "${actionStateJSON}")
                        if [ $? -ne 0 ]; then echo -e "\e[35mERROR - ${actionStateJSON}\e[0m\n"; exit 1; fi;
                        ;;

#       "light")        showProcessAnimation "Query DRep-ID-Info-LightMode: " &
#                       drepStateJSON=$(queryLight_drepInfo "${drepID}")
#                       if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${drepStateJSON}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
#                       ;;
#

esac

#jq -r . <<< ${actionStateJSON}


#Filter for a given Action-ID
if [[ ${govActionUTXO} != "" && ${govActionIdx} != "" ]]; then
	actionStateJSON=$(jq -r ". | select(.actionId.txId == \"${govActionUTXO}\" and .actionId.govActionIx == ${govActionIdx})" 2> /dev/null <<< "${actionStateJSON}")
	if [[ "${actionStateJSON}" = "" ]]; then #action-id not on chain
	        echo -e "\e[0mThe provided Action-ID is\e[33m NOT present on the chain\e[0m!\e[0m\n";
	        exit 1;
	fi
fi


#Filter for a given Action-Type
if [[ ${govActionType} != "" ]]; then
	actionStateJSON=$(jq -r ". | select( (.proposalProcedure.govAction.tag|ascii_downcase) == \"${govActionType}\")" 2> /dev/null <<< "${actionStateJSON}")
fi


#Filter for a given voterHash -> voterType set
case "${voterType}" in

	"DRep") #Filter for a DRep keyHash entry
		actionStateJSON=$(jq -r ". | select(.dRepVotes[\"keyHash-${voterHash}\"] != null)" 2> /dev/null <<< "${actionStateJSON}");;

	"Committee-Hot") #Filter for a Committee-Hot keyHash entry
		actionStateJSON=$(jq -r ". | select(.committeeVotes[\"keyHash-${voterHash}\"] != null)" 2> /dev/null <<< "${actionStateJSON}");;

	"Pool") #Filter for a Pool Hash entry
		actionStateJSON=$(jq -r ". | select(.stakePoolVotes[\"${voterHash}\"] != null)" 2> /dev/null <<< "${actionStateJSON}");;

	"Hash") #Filter just for a hash, can be a DRep, Committee or Pool Hash
		actionStateJSON=$(jq -r ". | select( (.dRepVotes[\"keyHash-${voterHash}\"] != null) or (.committeeVotes[\"keyHash-${voterHash}\"] != null) or (.stakePoolVotes[\"${voterHash}\"] != null) )" 2> /dev/null <<< "${actionStateJSON}");;

esac



#Convert the result(s) into an array and get the number of entries
actionStateJSON=$(jq --slurp <<< ${actionStateJSON})
actionStateEntryCnt=$(jq -r "length" <<< ${actionStateJSON})
if [[ ${actionStateEntryCnt} -eq 0 ]]; then echo -e "\e[91mNo matching votes found.\e[0m\n"; else echo -e "\e[0mFound: \e[32m${actionStateEntryCnt} entry/entries\e[0m\n"; fi

#jq -r . <<< ${actionStateJSON}

#Example Format
#[
#  {
#    "actionId": {
#      "govActionIx": 0,
#      "txId": "c8a384db801e8a9ebd123978403949edeb451da0cd532fd2d4b62725a3ec86a4"
#    },
#    "committeeVotes": {},
#    "dRepVotes": {},
#    "expiresAfter": 309,
#    "proposalProcedure": {
#      "anchor": {
#        "dataHash": "8c6fafdaa386c090ae9481cef4cba58813139e24f5246f1324c2ff63bdfb0234",
#        "url": "https://petloverstake.com/petlaw3.txt"
#      },
#      "deposit": 50000000000,
#      "govAction": {
#        "tag": "InfoAction"
#      },
#      "returnAddr": {
#        "credential": {
#          "keyHash": "afb9a5a94bab39ff1b7822a181050d683eaf67f262b2a0874da12067"
#        },
#        "network": "Testnet"
#      }
#    },
#    "proposedIn": 303,
#    "stakePoolVotes": {}
#  }
#]


#Show all found entries
for (( tmpCnt=0; tmpCnt<${actionStateEntryCnt}; tmpCnt++ ))
do

		#Get the indexed Entry
		actionEntry=$(jq -r ".[${tmpCnt}]" <<< ${actionStateJSON})

		#We have found an action, lets get the Tag and number of votes so far
		{ read actionTag;
		  read actionUTXO;
		  read actionIdx;
		  read actionContents;
		  read actionAnchorUrl;
		  read actionAnchorHash;
		  read actionProposedInEpoch;
		  read actionExpiresAfterEpoch;
		  read actionDRepVoteYesCount;
		  read actionDRepVoteNoCount;
		  read actionDRepAbstainCount;
		  read actionPoolVoteYesCount;
		  read actionPoolVoteNoCount;
		  read actionPoolAbstainCount;
		  read actionCommitteeVoteYesCount;
		  read actionCommitteeVoteNoCount;
		  read actionCommitteeAbstainCount;
		} <<< $(jq -r '.proposalProcedure.govAction.tag // "-", .actionId.txId // "-", .actionId.govActionIx // "-", "\(.proposalProcedure.govAction.contents)" // "-", .proposalProcedure.anchor.url // "-",
			.proposalProcedure.anchor.dataHash // "-", .proposedIn // "-", .expiresAfter // "-",
			(.dRepVotes | with_entries(select(.value == "VoteYes")) | length),
			(.dRepVotes | with_entries(select(.value == "VoteNo")) | length),
			(.dRepVotes | with_entries(select(.value == "Abstain")) | length),
			(.stakePoolVotes | with_entries(select(.value == "VoteYes")) | length),
			(.stakePoolVotes | with_entries(select(.value == "VoteNo")) | length),
			(.stakePoolVotes | with_entries(select(.value == "Abstain")) | length),
			(.committeeVotes | with_entries(select(.value == "VoteYes")) | length),
			(.committeeVotes | with_entries(select(.value == "VoteNo")) | length),
			(.committeeVotes | with_entries(select(.value == "Abstain")) | length)' <<< ${actionEntry})

		echo
		echo -e "\e[36m--- Entry $((${tmpCnt}+1)) of ${actionStateEntryCnt} --- Action-ID ${actionUTXO}#${actionIdx}\e[0m"
		echo
		echo -e "\e[0mAction-Type: \e[32m${actionTag}\e[0m   \tProposed in Epoch: \e[32m${actionProposedInEpoch}\e[0m   \tExpires after Epoch: \e[32m${actionExpiresAfterEpoch}\e[0m"
		echo

		#Show the Anchor-URL(HASH) if available
		if [[ "${actionAnchorUrl}" != "-" ]]; then
			echo -e "\e[0mAnchor-Url(Hash):\e[32m ${actionAnchorUrl} \e[0m(${actionAnchorHash})\n"
		fi

		#TO DO - MAKE A NICER OUTPUT OF THE DIFFERENT CONTENTS
		actionContents=$(jq -r . <<< "${actionContents}") #convert it to nice json format
		if [[ "${actionContents}" != null ]]; then
			case "${actionTag}" in

				"HardForkInitiation") 	#show the proposed major/minor version to fork to
							# [
							#  null,
							#  {
							#    "major": 9,
							#    "minor": 1
							#  }
							# ]
							{ read forkToMajor; read forkToMinor; } <<< $(jq -r '.[1].major // "-", .[1].minor // "-"' 2> /dev/null <<< ${actionContents})
							echo -e "\e[0mAction-Content:\e[36m Do a Hardfork to Protocol-Version ${forkToMajor}.${forkToMinor}"
							echo -e "\e[0m";;

				"ParameterChange") 	#show the proposed parameterchanges
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
							changeParameters=$(jq -rM '.[1] // "-"' 2> /dev/null <<< ${actionContents})
							echo -e "\e[0mAction-Content:\e[36m Change protocol parameters\n${changeParameters}"
							echo -e "\e[0m";;

				"NewConstitution") 	#show the proposed infos/anchor for a new constition
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
							{ read anchorHash; read anchorURL; } <<< $(jq -r '.[1].anchor.dataHash // "-", .[1].anchor.url // "-"' 2> /dev/null <<< ${actionContents})
							echo -e "\e[0mAction-Content:\e[36m Change to a new Constitution\n     \e[0mUrl(Hash):\e[36m ${anchorURL} (${anchorHash})"
							echo -e "\e[0m";;

				*) echo -e "\e[0mAction-Content:\n\e[36m${actionContents}"; echo -e "\e[0m";;


			esac
		fi # actionContents != null

		echo -e "\e[0mCurrent Votes\tYes\tNo\tAbstain"
		echo -e "\e[0m---------------------------------------"
		echo -e "\e[94m        DReps\t\e[32m${actionDRepVoteYesCount}\t\e[91m${actionDRepVoteNoCount}\t\e[33m${actionDRepAbstainCount}\e[0m"
		echo -e "\e[94m   StakePools\t\e[32m${actionPoolVoteYesCount}\t\e[91m${actionPoolVoteNoCount}\t\e[33m${actionPoolAbstainCount}\e[0m"
		echo -e "\e[94m    Committee\t\e[32m${actionCommitteeVoteYesCount}\t\e[91m${actionCommitteeVoteNoCount}\t\e[33m${actionCommitteeAbstainCount}\e[0m"
		echo

		#If there is a voterHash, get the voting answer for it
		if [[ "${voterHash}" != "" ]]; then
			voteAnswer=$(jq -r ".dRepVotes[\"keyHash-${voterHash}\"] // .committeeVotes[\"keyHash-${voterHash}\"] // .stakePoolVotes[\"${voterHash}\"]" 2> /dev/null <<< "${actionEntry}")
			echo -ne "\e[97mVoting-Answer of the selected ${voterType}-Voter is: "
			case "${voteAnswer}" in
#				"VoteYes")	echo -e "\e[32mYES\e[0m\n";;
				"VoteYes")	echo -e "\e[102m\e[30m YES \e[0m\n";;
#				"VoteNo")	echo -e "\e[91mNO\e[0m\n";;
				"VoteNo")	echo -e "\e[101m\e[30m NO \e[0m\n";;
#				"Abstain")	echo -e "\e[33mABSTAIN\e[0m\n";;
				"Abstain")	echo -e "\e[43m\e[30m ABSTAIN \e[0m\n";;
			esac
		fi
		echo


done

echo -e "\e[0m\n"
