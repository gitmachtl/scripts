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

Usage:  $(basename $0) <DRep-Name/ID/Hash | Committee-Hot-Name/Hash | Pool-Name/ID | StakeName/Addr> and/or <Action-ID> and/or <Action-Type> or <all>

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

   $(basename $0) myStake
   -> Get the current vote(s) on which the StakeAccount 'myStake.staking.addr' is registered as Deposit-Return-Address.

   $(basename $0) stake1u9qdkcdltaf8falntwqkcz5mj3m5ndzengdhavewn9jzm3senatjc
   -> Get the current vote(s) on which the given StakeAddress is registered as Deposit-Return-Address.

   $(basename $0) infoaction
   -> Get all current vote(s) of type 'InfoAction'

   $(basename $0) all
   -> Get all current vote(s)


EOF
exit 1;
fi

#exit with an information, that the script needs at least conway era
case ${cliEra} in
        "babbage"|"alonzo"|"mary"|"allegra"|"shelley")
                echo -e "\n\e[91mINFORMATION - The chain is not in conway era yet. This script will start to work once we forked into conway era. Please check back later!\n\e[0m"; exit;
                ;;
esac



echo -e "\e[0mQuery the voting state for a DRep, Committee-Hot, Pool, StakeAddress and/or an Action-ID:"
echo

#Check can only be done in online mode
if ${offlineMode}; then echo -e "\e[35mYou have to be in ONLINE or LIGHT mode to do this!\e[0m\n"; exit 1; fi

#Default Variables
govActionID=""; voterHash=""; voterType=""; returnHash="";

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

	#Check if its a StakeAddress in Bech-Format
	elif [[ "${paramValue:0:5}" == "stake" ]]; then #parameter is most likely a bech32-stakeaddress
	        echo -ne "\e[0mCheck if given Stake-Address\e[32m ${paramValue}\e[0m is valid ..."
	        #lets do some further testing by converting the bech32 stakeaddress into the hexHash
	        returnHash=$(${bech32_bin} 2> /dev/null <<< "${paramValue,,}") #will have returncode 0 if the bech was valid
	        if [ $? -ne 0 ]; then echo -e "\n\n\e[91mERROR - \"${paramValue}\" is not a valid Bech32 Stake-Address.\e[0m"; exit 1; fi
	        echo -e "\e[32m OK\e[0m\n"
		returnHash=${returnHash:2} #reduce it to the hash itself without the mainnet/testnet prebyte e0/e1

	#Check if its a StakeAddress file in Bech-Format
	elif [[ -f "${paramValue}.staking.addr" ]]; then #parameter is a StakeAddress file, containing a bech32 address
		echo -ne "\e[0mReading from Stake-Address-File\e[32m ${paramValue}.staking.addr\e[0m ..."
		stakeAddr=$(cat "${paramValue}.staking.addr" 2> /dev/null)
		if [ $? -ne 0 ]; then echo -e "\n\n\e[91mERROR - Could not read from file \"${paramValue}.staking.addr\"\e[0m"; exit 1; fi
		echo -e "\e[32m OK\e[0m\n"
	        echo -ne "\e[0mCheck if given Stake-Address\e[32m ${stakeAddr}\e[0m is valid ..."
	        #lets do some further testing by converting the bech32 stakeaddress into the hexHash
	        returnHash=$(${bech32_bin} 2> /dev/null <<< "${stakeAddr,,}") #will have returncode 0 if the bech was valid
	        if [ $? -ne 0 ]; then echo -e "\n\n\e[91mERROR - \"${stakeAddr}\" is not a valid Bech32 Stake-Address.\e[0m"; exit 1; fi
	        echo -e "\e[32m OK\e[0m\n"
		returnHash=${returnHash:2} #reduce it to the hash itself without the mainnet/testnet prebyte e0/e1

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

	"light")        #showProcessAnimation "Query Governance-Action Info-LightMode: " &
#                       drepStateJSON=$(queryLight_drepInfo "${drepID}")
#                       if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${drepStateJSON}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
			echo -e "\n\e[91mINFORMATION - This script does not support Light-Mode yet, waiting for Koios support!\n\e[0m"; exit;
			;;
#

esac

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


#Filter for a returnHash
if [[ ${returnHash} != "" ]]; then
	echo -e "\e[0mFilter for Deposit-Return-Hash:\e[94m ${returnHash}\e[0m\n";
	actionStateJSON=$(jq -r ". | select( (.proposalProcedure.returnAddr.credential.keyHash) == \"${returnHash}\")" 2> /dev/null <<< "${actionStateJSON}");
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
		  read actionDepositReturnKeyType;
		  read actionDepositReturnHash;
		  read actionDepositReturnNetwork;
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
			.proposalProcedure.anchor.dataHash // "-", .proposedIn // "-", .expiresAfter // "-", (.proposalProcedure.returnAddr.credential|keys[0]) // "-", (.proposalProcedure.returnAddr.credential|flatten[0]) // "-", .proposalProcedure.returnAddr.network // "-",
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


		#DO A NICE OUTPUT OF THE DIFFERENT CONTENTS
		case "${actionTag}" in

				"InfoAction") 		#show the proposed major/minor version to fork to
							#Show referencing Action-Id if avaiable
							{ read prevActionUTXO; read prevActionIDX; } <<< $(jq -r '.txId // "-", .govActionIx // "-"' 2> /dev/null <<< ${actionContents})
							if [[ ${#prevActionUTXO} -gt 1 ]]; then echo -e "Reference-Action-ID: \e[32m${prevActionUTXO}#${prevActionIDX}\e[0m\n"; fi
							echo -e "\e[0mAction-Content:\e[36m Information\e[0m"
							echo -e "\e[0m";;


				"HardForkInitiation") 	#show the proposed major/minor version to fork to
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
							{ read prevActionUTXO; read prevActionIDX; read changeParameters; } <<< $(jq -r '.[0].txId // "-", .[0].govActionIx // "-", "\(.[1])" // "-"' 2> /dev/null <<< ${actionContents})
							if [[ ${#prevActionUTXO} -gt 1 ]]; then echo -e "Reference-Action-ID: \e[32m${prevActionUTXO}#${prevActionIDX}\e[0m\n"; fi
							echo -e "\e[0mAction-Content:\e[36m Change protocol parameters\n\e[0m"
			                                changeParameterRender=$(jq -r 'to_entries[] | "\\e[0mChange parameter\\e[32m \(.key) \\e[0m► \\e[94m\(.value)\\e[0m"' <<< ${changeParameters} 2> /dev/null)
			                                echo -e "${changeParameterRender}"
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
							{ read prevActionUTXO; read prevActionIDX; read anchorHash; read anchorURL; } <<< $(jq -r '.[0].txId // "-", .[0].govActionIx // "-", .[1].anchor.dataHash // "-", .[1].anchor.url // "-"' 2> /dev/null <<< ${actionContents})
							if [[ ${#prevActionUTXO} -gt 1 ]]; then echo -e "Reference-Action-ID: \e[32m${prevActionUTXO}#${prevActionIDX}\e[0m\n"; fi
							echo -e "\e[0mAction-Content:\e[36m Change to a new Constitution\e[0m\n"
							echo -e "\e[0mSet new\e[32m Constitution-URL \e[0m► \e[94m${anchorURL}\e[0m"
							echo -e "\e[0mSet new\e[32m Constitution-Hash \e[0m► \e[94m${anchorHash}\e[0m"
							echo -e "\e[0m";;

				"UpdateCommittee") 	#show the proposed infos for a committeeupdate
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
							echo -e "\e[0m";;

				"TreasuryWithdrawals")	#show the treasury withdrawals address and amount
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
							{ read withdrawalsAmount; read withdrawalsKeyType; read withdrawalsHash; read withdrawalsNetwork; } <<< $( jq -r '.[0][0][1], (.[0][0][0].credential|keys[0]) // "-", (.[0][0][0].credential|flatten[0]) // "-", .[0][0][0].network // "-"' 2> /dev/null <<< ${actionContents})
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

					                        *)              echo -e "\n\e[35mERROR - Unknown network type ${actionDepositReturnNetwork} for the Withdrawal KeyHash !\n\e[0m"; exit 1;
					                                        ;;
					                esac
			                                echo -e "\e[0mWithdrawal the\e[32m Amount \e[0m► \e[94m$(convertToADA ${withdrawalsAmount}) ADA / ${withdrawalsAmount} lovelaces\e[0m"
							echo -e "\e[0m";;

			esac

		echo -e "\e[0mCurrent Votes\tYes\tNo\tAbstain"
		echo -e "\e[0m---------------------------------------"
		echo -e "\e[94m        DReps\t\e[32m${actionDRepVoteYesCount}\t\e[91m${actionDRepVoteNoCount}\t\e[33m${actionDRepAbstainCount}\e[0m"
		echo -e "\e[94m   StakePools\t\e[32m${actionPoolVoteYesCount}\t\e[91m${actionPoolVoteNoCount}\t\e[33m${actionPoolAbstainCount}\e[0m"
		echo -e "\e[94m    Committee\t\e[32m${actionCommitteeVoteYesCount}\t\e[91m${actionCommitteeVoteNoCount}\t\e[33m${actionCommitteeAbstainCount}\e[0m"
		echo


		#### TODO : Stake calculation for the current voting state

		#If there is a voterHash, get the voting answer for it
		if [[ "${voterHash}" != "" ]]; then
			voteAnswer=$(jq -r ".dRepVotes[\"keyHash-${voterHash}\"] // .committeeVotes[\"keyHash-${voterHash}\"] // .dRepVotes[\"scriptHash-${voterHash}\"] // .committeeVotes[\"scriptHash-${voterHash}\"] // .stakePoolVotes[\"${voterHash}\"]" 2> /dev/null <<< "${actionEntry}")
			echo -ne "\e[97mVoting-Answer of the selected ${voterType}-Voter is: "
			case "${voteAnswer}" in
				"VoteYes")	echo -e "\e[102m\e[30m YES \e[0m\n";;
				"VoteNo")	echo -e "\e[101m\e[30m NO \e[0m\n";;
				"Abstain")	echo -e "\e[43m\e[30m ABSTAIN \e[0m\n";;
			esac
		fi
		echo


done

echo -e "\e[0m\n"
