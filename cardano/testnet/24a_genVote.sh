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

Usage:  $(basename $0) <DRep-Name | Committee-Hot-Name | Pool-Name> <GovActionID>

        [Opt: Anchor-URL, starting with "url: ..."], in Online-/Light-Mode the Hash will be calculated
        [Opt: Anchor-HASH, starting with "hash: ..."], to overwrite the Anchor-Hash in Offline-Mode


Examples:

   $(basename $0) myDRep 4d45bc8c9080542172b2c76caeb93c88d7dca415c3a2c71b508cbfc3785e98a8#0
   -> Generate a Vote-File for the DRep-ID of myDRep (myDRep.drep.*) and the proposal in Action-ID 4d45b...a8#0.

   $(basename $0) myDRep 4d45bc8c9080542172b2c76caeb93c88d7dca415c3a2c71b508cbfc3785e98a8#0 "url: https://mydomain.com/myvotingthoughts.json"
   -> Generate a Vote-File for the DRep-ID of myDRep (myDRep.drep.*) and the proposal in Action-ID 4d45b...a8#0
   -> Also attaching an Anchor-URL to f.e. describe the voting decision, etc.

EOF
exit 1;
fi

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
if [[ "${govActionID}" =~ ^([[:xdigit:]]{64}+#[[:digit:]]{1,})$ ]]; then
	govActionUTXO=${govActionID:0:64}
	govActionIdx=$(( ${govActionID:65} + 0 )) #make sure to have single digits if provided like #00 #01 #02...
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

#If in online/light mode, check the anchorURL
if ${onlineMode}; then

        #get Anchor-URL content and calculate the Anchor-Hash
        if [[ ${anchorURL} != "" ]]; then

                #we write out the downloaded content to a file 1:1, so we can do a hash calculation on the file itself rather than on text content
                tmpAnchorContent="${tempDir}/DRepAnchorURLContent.tmp"; touch "${tmpAnchorContent}"; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

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
                                        if [ $? -ne 0 ]; then echo -e "\n\e[35mERROR - The content of the Anchor-URL '${anchorURL}'\nis not in valid JSON format!\n\e[0m"; rm "${tmpAnchorContent}"; exit 1; fi
                                        contentHASH=$(b2sum -l 256 "${tmpAnchorContent}" 2> /dev/null | cut -d' ' -f 1)
                                        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
                                        echo -e "\e[0mAnchor-URL(HASH):\e[32m ${anchorURL} (${contentHASH})\e[0m"
                                        echo
                                        if [[ ${anchorHASH} != "" ]]; then echo -e "\e[33mProvided Anchor-HASH '${anchorHASH}' will be ignored, continue ...\e[0m\n"; fi
                                        anchorHASH="${contentHASH}" #set the anchorHASH not to the provided one, use the one calculated from the online file
                                        rm "${tmpAnchorContent}" #cleanup
                                        ;;

                                "404" ) #file-not-found
                                        echo -e "\n\e[35mERROR - No content was not found on the given Anchor-URL '${anchorURL}'\nPlease upload it first to this location, thx!\n\e[0m"; exit 1; #exit with a failure
                                        ;;

                                * )     echo -e "\n\e[35mERROR - Query of the Anchor-URL failed!\nHTTP Request File: ${anchorURL}\nHTTP Response Code: ${responseCode}\n\e[0m"; exit 1; #exit with a failure and the http response code
                                        ;;
                        esac;

                else
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
echo -e "\e[0mAction-Tx-ID: \e[32m${govActionUTXO}\e[0m"
echo -e "\e[0mAction-Index: \e[32m${govActionIdx}\e[0m"
echo


#Get state data for the Action-ID. In online mode of course from the node and the chain, in light mode via koios
case ${workMode} in

        "online")       showProcessAnimation "Query Governance-Action Info: " &
			actionStateJSON=$(${cardanocli} ${cliEra} query gov-state 2> /dev/stdout)
                        if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${actionStateJSON}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
			actionStateJSON=$(jq -r ".proposals | to_entries[] | .value | select(.actionId.txId == \"${govActionUTXO}\" and .actionId.govActionIx == ${govActionIdx})" 2> /dev/null <<< "${actionStateJSON}")
                        ;;

#       "light")        showProcessAnimation "Query DRep-ID-Info-LightMode: " &
#                       drepStateJSON=$(queryLight_drepInfo "${drepID}")
#                       if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${drepStateJSON}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
#                       ;;
#
#        "offline")      readOfflineFile; #Reads the offlinefile into the offlineJSON variable
#                        drepStateJSON=$(jq -r ".drep.\"${drepID}\".drepStateJSON" <<< ${offlineJSON} 2> /dev/null)
#                        if [[ "${drepStateJSON}" == null ]]; then echo -e "\e[35mDRep-ID not included in the offline transferFile, please include it first online!\e[0m\n"; exit; fi
#                        ;;

esac

case ${workMode} in

	"online"|"light")

		#Checking about the action content
		if [[ "${actionStateJSON}" = "" ]]; then #proposal not on chain
		        echo -e "\e[0mThe provided Action-ID is\e[33m NOT present on the chain\e[0m!\e[0m\n";
		        exit 1;
		fi


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
                } <<< $(jq -r '.proposalProcedure.govAction.tag // "-", .actionId.txId // "-", .actionId.govActionIx // "-", "\(.action.contents)" // "-", .proposalProcedure.anchor.url // "-",
                        .proposalProcedure.anchor.dataHash // "-", .proposedIn // "-", .expiresAfter // "-",
                        (.dRepVotes | with_entries(select(.value == "VoteYes")) | length),
                        (.dRepVotes | with_entries(select(.value == "VoteNo")) | length),
                        (.dRepVotes | with_entries(select(.value == "Abstain")) | length),
                        (.stakePoolVotes | with_entries(select(.value == "VoteYes")) | length),
                        (.stakePoolVotes | with_entries(select(.value == "VoteNo")) | length),
                        (.stakePoolVotes | with_entries(select(.value == "Abstain")) | length),
                        (.committeeVotes | with_entries(select(.value == "VoteYes")) | length),
                        (.committeeVotes | with_entries(select(.value == "VoteNo")) | length),
                        (.committeeVotes | with_entries(select(.value == "Abstain")) | length)' <<< ${actionStateJSON})


		echo -e "\e[0mAction-ID is of type: \e[32m${actionTag}\e[0m"
		echo
		echo -e "\e[0m   Proposed in Epoch: \e[32m${actionProposedInEpoch}\e[0m"
		echo -e "\e[0m Expires after Epoch: \e[32m${actionExpiresAfterEpoch}\e[0m"
		echo

                #Show the Anchor-URL(HASH) if available
                if [[ "${actionAnchorUrl}" != "-" ]]; then
                        echo -e "\e[0mAnchor-Url(Hash):\e[32m ${actionAnchorUrl} \e[0m(${actionAnchorHash})\n"
                fi

		echo -e "\e[0mCurrent Votes\tYes\tNo\tAbstain"
		echo -e "\e[0m---------------------------------------"
		echo -e "\e[94m        DReps\t\e[32m${actionDRepVoteYesCount}\t\e[91m${actionDRepVoteNoCount}\t\e[33m${actionDRepAbstainCount}\e[0m"
		echo -e "\e[94m   StakePools\t\e[32m${actionPoolVoteYesCount}\t\e[91m${actionPoolVoteNoCount}\t\e[33m${actionPoolAbstainCount}\e[0m"
		echo -e "\e[94m    Committee\t\e[32m${actionCommitteeVoteYesCount}\t\e[91m${actionCommitteeVoteNoCount}\t\e[33m${actionCommitteeAbstainCount}\e[0m"
		echo

		#TO DO - MAKE A NICER OUTPUT OF THE DIFFERENT CONTENTS
		actionContents=$(jq -r . <<< "${actionContents}") #convert it to nice json format
		echo -e "\e[0mContents of Action-ID:"
		echo -e "\e[90m${actionContents}\e[0m"
		echo

		#Check if the used voterType is allowed to do a vote on the actionTag
		case "${voterType}_${actionTag}" in
			"Committee-Hot_NoConfidence"|"Committee-Hot_UpdateCommittee"|"Pool_NewConstitution"|"Pool_ParameterChange"|"Pool_TreasuryWithdrawals")
				echo -e "\n\e[91mSORRY - This voterType '${voterType}' is not allowed to vote on an action from type '${actionTag}'!\n\e[0m"; exit 1;;
		esac

		;; #online|light

esac

#echo -e "\e[0mYour voting decision on that Action-ID?\e[32m"
#select choice in "Yes" "No" "Abstain" "Cancel"; do
#	case ${choice} in
#		"Yes" ) actionVote="Yes"; break;;
#		"No" ) actionVote="No"; break;;
#		"Abstain" ) actionVote="Abstain"; break;;
#		* ) echo -e "\e[0m"; exit;;
#	esac
#done

#Get the voting answer from the user
while true; do
	# Ask the question (not using "read -p" as it uses stderr not stdout)
        echo -ne "\e[0mPlease vote on that Action-ID [\e[32mYes\e[0m/\e[91mNo\e[0m/\e[33mAbstain\e[0m/CANCEL] ? "

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

		C*|c*) 	echo -e "\e[0m\n"; exit;;
        esac
done

echo -e "\e[0m"

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
voteJSON=$(${cardanocli} ${cliEra} governance vote create ${voteParam} --governance-action-tx-id "${govActionUTXO}" --governance-action-index "${govActionIdx}" ${vkeyParam} "${voterVkeyFile}" ${anchorPARAM} --out-file /dev/stdout 2> /dev/stdout)
checkError "$?"; if [ $? -ne 0 ]; then echo -e "\e[35mERROR - ${voteJSON}\e[0m\n"; exit 1; fi
echo "${voteJSON}" > "${votingFile}"; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

echo -e "\e[0mCreated the Vote-Certificate file: \e[32m${votingFile}\e[90m"
cat "${votingFile}"
echo -e "\e[0m"

echo
echo -e "\e[91mIf you wanna submit the Vote-Certificate now, please run the script 24b !\e[0m"
echo

echo -e "\e[0m\n"
