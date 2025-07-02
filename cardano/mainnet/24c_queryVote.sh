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

#Check can only be done in online mode
if ${offlineMode}; then echo -e "\e[35mYou have to be in ONLINE or LIGHT mode to do this!\e[0m\n"; exit 1; fi

#exit with an information, that the script needs at least conway era
case ${cliEra} in
        "babbage"|"alonzo"|"mary"|"allegra"|"shelley")
                echo -e "\n\e[91mINFORMATION - The chain is not in conway era yet. This script will start to work once we forked into conway era. Please check back later!\n\e[0m"; exit;
                ;;
esac


echo -e "\e[0mQuery the voting state for a DRep, Committee-Hot, Pool, StakeAddress and/or an Action-ID:"
echo

#Default Variables
govActionID=""; voterHash=""; voterType=""; returnHash="";
voterID="-" #voterID="-" -> disabled currently for light mode

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
		voterID=""

	#Check if its a Governance Action-ID in Bech-Format
	elif [[ "${paramValue:0:11}" == "gov_action1" ]]; then #parameter is most likely a bech32-action-id
	        echo -ne "\e[0mCheck if given Action Bech-ID\e[32m ${paramValue}\e[0m is valid ..."
	        #lets do some further testing by converting the bech32 DRep-id into a Hex-DRep-ID
	        govActionID=$(convert_actionBech2UTXO ${paramValue}) #converts the given action bech id (CIP-129) into standard UTXO#IDX format
	        if [ $? -ne 0 ]; then echo -e "\n\n\e[91mERROR - \"${paramValue}\" is not a valid Bech32 ACTION-ID.\e[0m"; exit 1; fi
	        echo -e "\e[32m OK\e[0m\n"
	        echo -e "\e[0mUsing Governance Action-ID:\e[32m ${govActionID}\e[0m\n"
		govActionUTXO=${govActionID:0:64}
		govActionIdx=$(( ${govActionID:65} + 0 )) #make sure to have single digits if provided like #00 #01 #02...
		voterID=""

	#Check if its a Voter-Hash. Could be a DRep, CC-Hot or Pool-Hash. We don't know.
	elif [[ "${paramValue,,}" =~ ^([[:xdigit:]]{56})$ ]]; then
		if [[ "${voterHash}" != "" ]]; then echo -e "\n\e[91mERROR - Only one Voter-Hash is allowed as parameter!\e[0m\n"; exit 1; fi
		voterHash="${paramValue,,}"
		voterType="Hash";

	#Check if its a DRep-ID in Bech-Format
	elif [[ "${paramValue:0:5}" == "drep1" && ${#paramValue} -eq 56 ]]; then #parameter is most likely a bech32-drep-id
	        echo -ne "\e[0mCheck if given DRep Bech-ID\e[32m ${paramValue}\e[0m is valid ..."
	        #lets do some further testing by converting the bech32 DRep-id into a Hex-DRep-ID
	        voterHash=$(${bech32_bin} 2> /dev/null <<< "${paramValue,,}") #will have returncode 0 if the bech was valid
	        if [ $? -ne 0 ]; then echo -e "\n\n\e[91mERROR - \"${paramValue}\" is not a valid Bech32 DRep-ID.\e[0m"; exit 1; fi
	        echo -e "\e[32m OK\e[0m\n"
		voterType="DRep"; voterID=${paramValue,,}

	#Check if its a DRep-ID in Bech-Format
	elif [[ "${paramValue:0:12}" == "drep_script1" && ${#paramValue} -eq 63 ]]; then #parameter is most likely a bech32-drep-id
	        echo -ne "\e[0mCheck if given DRep-Script Bech-ID\e[32m ${paramValue}\e[0m is valid ..."
	        #lets do some further testing by converting the bech32 DRep-id into a Hex-DRep-ID
	        voterHash=$(${bech32_bin} 2> /dev/null <<< "${paramValue,,}") #will have returncode 0 if the bech was valid
	        if [ $? -ne 0 ]; then echo -e "\n\n\e[91mERROR - \"${paramValue}\" is not a valid Bech32 DRep-Script-ID.\e[0m"; exit 1; fi
	        echo -e "\e[32m OK\e[0m\n"
		voterType="DRep"; voterID=${paramValue,,}

	#Check if its a DRep-ID in CIP129-Bech-Format
	elif [[ "${paramValue:0:5}" == "drep1" && ${#paramValue} -eq 58 ]]; then #parameter is most likely a CIP129 bech32-drep-id
	        echo -ne "\e[0mCheck if given CIP129 DRep Bech-ID\e[32m ${paramValue}\e[0m is valid ..."
	        #lets do some further testing by converting the bech32 DRep-id into a Hex-DRep-ID
	        voterHash=$(${bech32_bin} 2> /dev/null <<< "${paramValue,,}") #will have returncode 0 if the bech was valid
	        if [ $? -ne 0 ]; then echo -e "\n\n\e[91mERROR - \"${paramValue}\" is not a valid CIP129 Bech32 DRep-ID.\e[0m"; exit 1; fi
	        echo -e "\e[32m OK\e[0m\n"
		voterHash=${voterHash: -56}
		voterType="DRep"; voterID=${paramValue,,}

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
		voterType="DRep"; voterID=${drepID}

	#Check if its a Committee-Hot-ID in Bech-Format
	elif [[ "${paramValue:0:7}" == "cc_hot1" && ${#paramValue} -eq 58 ]]; then #parameter is most likely a bech32-committee-hot-id
	        echo -ne "\e[0mCheck if given Committee-Hot Bech-ID\e[32m ${paramValue}\e[0m is valid ..."
	        #lets do some further testing by converting the bech32 Committee-id into a Hex-Committee-ID
	        voterHash=$(${bech32_bin} 2> /dev/null <<< "${paramValue,,}") #will have returncode 0 if the bech was valid
	        if [ $? -ne 0 ]; then echo -e "\n\n\e[91mERROR - \"${paramValue}\" is not a valid Bech32 Committee-Hot-ID.\e[0m"; exit 1; fi
	        echo -e "\e[32m OK\e[0m\n"
		voterType="Committee-Hot"; voterID=${paramValue,,}

	#Check if its a Committee-Hot-ID in Bech-Format
	elif [[ "${paramValue:0:14}" == "cc_hot_script1" && ${#paramValue} -eq 65 ]]; then #parameter is most likely a bech32-committee-hot-id
	        echo -ne "\e[0mCheck if given Committee-Script-Hot Bech-ID\e[32m ${paramValue}\e[0m is valid ..."
	        #lets do some further testing by converting the bech32 Committee-id into a Hex-Committee-ID
	        voterHash=$(${bech32_bin} 2> /dev/null <<< "${paramValue,,}") #will have returncode 0 if the bech was valid
	        if [ $? -ne 0 ]; then echo -e "\n\n\e[91mERROR - \"${paramValue}\" is not a valid Bech32 Committee-Script-Hot-ID.\e[0m"; exit 1; fi
	        echo -e "\e[32m OK\e[0m\n"
		voterType="Committee-Hot"; voterID=${paramValue,,}

	#Check if its a Committee-Hot-ID in CIP129-Bech-Format
	elif [[ "${paramValue:0:7}" == "cc_hot1" && ${#paramValue} -eq 60 ]]; then #parameter is most likely a CIP129 bech32-committee-hot-id
	        echo -ne "\e[0mCheck if given CIP129 Committee-Hot Bech-ID\e[32m ${paramValue}\e[0m is valid ..."
	        #lets do some further testing by converting the bech32 Committee-id into a Hex-Committee-ID
	        voterHash=$(${bech32_bin} 2> /dev/null <<< "${paramValue,,}") #will have returncode 0 if the bech was valid
	        if [ $? -ne 0 ]; then echo -e "\n\n\e[91mERROR - \"${paramValue}\" is not a valid CIP129 Bech32 Committee-Hot-ID.\e[0m"; exit 1; fi
	        echo -e "\e[32m OK\e[0m\n"
		voterHash=${voterHash: -56}
		voterType="Committee-Hot"; voterID=${paramValue,,}

	#Check if its a Committee-Hot-Hash File
	elif [[ -f "${paramValue}.cc-hot.hash" ]]; then #parameter is a Committee Hot hash file, containing the hash id
		echo -ne "\e[0mReading from Committee-Hot-HASH-File\e[32m ${paramValue}.cc-hot.hash\e[0m ..."
		voterHash=$(cat "${paramValue}.cc-hot.hash" 2> /dev/null)
	        if [ $? -ne 0 ]; then echo -e "\n\n\e[35mERROR - Could not read from file \"${paramValue}.cc-hot.hash\"\e[0m"; exit 1; fi
	        echo -e "\e[32m OK\e[0m\n"
		if [[ ! "${voterHash,,}" =~ ^([[:xdigit:]]{56})$ ]]; then echo -e "\n\e[91mERROR - Content of Committee-Hot-Hash File '${paramValue}.cc-hot.hash' is not a valid Voter-Hash!\n\e[0m"; exit 1; fi
		voterType="Committee-Hot";

	#Check if its a Pool-ID in Bech-Format
	elif [[ "${paramValue:0:5}" == "pool1" && ${#paramValue} -eq 56 ]]; then #parameter is most likely a bech32-pool-id
	        echo -ne "\e[0mCheck if given Pool Bech-ID\e[32m ${paramValue}\e[0m is valid ..."
	        #lets do some further testing by converting the bech32 DRep-id into a Hex-DRep-ID
	        voterHash=$(${bech32_bin} 2> /dev/null <<< "${paramValue,,}") #will have returncode 0 if the bech was valid
	        if [ $? -ne 0 ]; then echo -e "\n\n\e[91mERROR - \"${paramValue}\" is not a valid Bech32 Pool-ID.\e[0m"; exit 1; fi
	        echo -e "\e[32m OK\e[0m\n"
		voterType="Pool"; voterID=${paramValue,,}

	#Check if its a Pool-ID File with the hex Pool-ID
	elif [[ -f "${paramValue}.pool.id" ]]; then #parameter is a Pool-ID file, containing the hash id in hex format
		echo -ne "\e[0mReading from Pool_ID-File\e[32m ${paramValue}.pool.id\e[0m ..."
		voterHash=$(cat "${paramValue}.pool.id" 2> /dev/null)
	        if [ $? -ne 0 ]; then echo -e "\n\n\e[35mERROR - Could not read from file \"${paramValue}.pool.id\"\e[0m"; exit 1; fi
	        echo -e "\e[32m OK\e[0m\n"
		if [[ ! "${voterHash,,}" =~ ^([[:xdigit:]]{56})$ ]]; then echo -e "\n\e[91mERROR - Content of Pool-ID File '${paramValue}.pool.id' is not a valid Voter-Hash!\n\e[0m"; exit 1; fi
		voterType="Pool";

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
		voterType=""; voterHash=""; govActionID=""; govActionUTXO=""; govActionIdx=""; govActionType=""; voterID="";
		break;

	#Unknown parameter
	else

		echo -e "\n\e[35mERROR - I don't know what to do with the parameter '${paramValue}'.\n\n\e[0mIf you wanna show all votes, please use the parameter 'all'.\n"; exit 1;

        fi #end of different parameters check

 done #for loop

#If in online/light mode, check cardano-signer to later on check the anchorURL
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

fi

if [[ "${voterHash}" != "" ]]; then echo -e "\e[0mVoter-Type is\e[32m ${voterType}\e[0m with the Voter-Hash:\e[94m ${voterHash}\e[0m\n"; fi

#Get state data for the Action-ID. In online mode of course from the node and the chain, in light mode via koios
case ${workMode} in

        "online")       if [[ $(get_currentSync) != "synced" ]]; then echo -e "\e[35mError - Node not fully synced or not running, please let your node sync to 100% first !\e[0m\n"; exit 1; fi
			showProcessAnimation "Query Governance-Action Info: " &
			govStateJSON=$(${cardanocli} ${cliEra} query gov-state 2> /dev/stdout)
                        if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${actionStateJSON}\e[0m\n"; exit 1; else stopProcessAnimation; fi;
			actionStateJSON=$(jq -r ".proposals | to_entries[] | .value" 2> /dev/null <<< "${govStateJSON}")
                        if [ $? -ne 0 ]; then echo -e "\e[35mERROR - ${actionStateJSON}\e[0m\n"; exit 1; fi;

			#Filter for a given Action-ID
			if [[ ${govActionUTXO} != "" && ${govActionIdx} != "" ]]; then
				actionStateJSON=$(jq -r ". | select(.actionId.txId == \"${govActionUTXO}\" and .actionId.govActionIx == ${govActionIdx})" 2> /dev/null <<< "${actionStateJSON}")
				if [[ "${actionStateJSON}" = "" ]]; then #action-id not on chain
				        echo -e "\e[0mThe provided Action-ID is\e[33m NOT present on the chain\e[0m!\e[0m\n";
				        exit 1;
				fi
			fi

			#Filter for a voterHash in online-mode
			if [[ "${voterHash}" != "" ]]; then
				actionStateJSON=$(jq -r ". | select( (.committeeVotes, .dRepVotes, .stakePoolVotes) | keys[] | contains(\"${voterHash}\"))" 2> /dev/null <<< "${actionStateJSON}");
			fi

			#Get currentEpoch for Active-dRep-Power-Filtering
			currentEpoch=$(get_currentEpoch)

			#Get the current protocolParameters for the dRep and pool voting thresholds
                        protocolParametersJSON=$(${cardanocli} ${cliEra} query protocol-parameters)

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

				*) 	#if any other type, throw an error
					echo -e "\e[35mERROR - Could not handle committeeThresholdType = ${committeeThresholdType}\e[0m\n"; exit 1
					;;
			esac

			#Generate the JSON of all committeeHotHashes and there names, depending on the committeeColdHashes
			ccMemberHotHashNamesJSON=$(jq -r "[ .[] | { \"\(.value.hotCredsAuthStatus.contents | keys[0])-\(.value.hotCredsAuthStatus.contents | flatten[0])\": (${ccMemberColdHashNames}[.key]) } ] | reduce .[] as \$o ({}; . * \$o)" <<< ${committeeStateJSON} 2> /dev/null)

                        ;;


	"light")	#Check the voterID and voterType and generate filter if possible
			case "${voterID}${voterType}" in
				"-DRep") 		voterID=$(${bech32_bin} "drep" <<< "${voterHash}" 2> /dev/null);;
				"-Committee-Hot")	voterID=$(${bech32_bin} "cc_hot" <<< "${voterHash}" 2> /dev/null);;
				"-Pool") 		voterID=$(${bech32_bin} "pool" <<< "${voterHash}" 2> /dev/null);;
				"-Hash")		echo -e "\e[35mSORRY - Filter by HASH is not supported yet in light-mode.\e[0m\n"; exit 1;;
				"-")			voterID="";; #fall back to disable filtering, show all
			esac

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

				*) 	#if any other type, throw an error
					echo -e "\e[35mERROR - Could not handle committeeThresholdType = ${committeeThresholdType}\e[0m\n"; exit 1
					;;
			esac
			;;

esac

{ read protocolVersionMajor; } <<< $(jq -r ".protocolVersion.major // -1" <<< ${protocolParametersJSON} 2> /dev/null)

#Filter for a given Action-Type
if [[ ${govActionType} != "" ]]; then
	actionStateJSON=$(jq -r ". | select( (.proposalProcedure.govAction.tag|ascii_downcase) == \"${govActionType}\")" 2> /dev/null <<< "${actionStateJSON}")
fi


#Filter for a returnHash
if [[ ${returnHash} != "" ]]; then
	echo -e "\e[0mFilter for Deposit-Return-Hash:\e[94m ${returnHash}\e[0m\n";
	actionStateJSON=$(jq -r ". | select( (.proposalProcedure.returnAddr.credential.keyHash) == \"${returnHash}\")" 2> /dev/null <<< "${actionStateJSON}");
fi

#Convert the result(s) into an array and get the number of entries
actionStateJSON=$(jq --slurp <<< ${actionStateJSON})
actionStateEntryCnt=$(jq -r "length" <<< ${actionStateJSON})
if [[ ${actionStateEntryCnt} -eq 0 ]]; then echo -e "\e[91mNo matching votes found.\e[0m\n"; else echo -e "\e[0mFound: \e[32m${actionStateEntryCnt} entry/entries\e[0m\n"; fi

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

				#Generate lists with the committee hashes that are voted yes, no or abstain.
				{ read committeeHashYes; read committeeHashNo; read committeeHashAbstain; } <<< $(jq -r '"\(.committeeVotes | with_entries(select(.value | contains("Yes"))) | keys )",
					"\(.committeeVotes | with_entries(select(.value | contains("No"))) | keys)",
					"\(.committeeVotes | with_entries(select(.value | contains("Abstain"))) | keys)"' <<< ${actionEntry} 2> /dev/null)
				;;
		esac

		#Setup variables
		totalAccept=""; totalAcceptIcon="";
		dRepAcceptIcon=""; poolAcceptIcon=""; committeeAcceptIcon="";
		dRepPowerThreshold="N/A"; poolPowerThreshold="N/A"; #N/A -> not available
		govActionTitle="";

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
					response=$(curl -sL -m 30 --max-filesize 10485760 -X GET -w "---spo-scripts---%{http_code}" "${queryURL}" --output "${tmpAnchorContent}" 2> /dev/null)
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
										{ read govActionTitle; read proofDepositReturnAddr; read proofWithdrawalAddr; } <<< $(jq -r '.body.title // "-", .body.onChain.depositReturnAddress // "-", .body.onChain.withdrawals[0].withdrawalAddress // "-"' ${tmpAnchorContent} 2> /dev/null)
										if [[ "${errorMsg}" != "" ]]; then echo -e "\e[0m          Notice: ${iconNo} ${errorMsg}\e[0m"; fi
										authors=$(jq -r --arg iconYes "${iconYes}" --arg iconNo "${iconNo}" '.authors[] | "\\e[0m       Signature: \(if .valid then $iconYes else $iconNo end) \(.name) (PubKey \(.publicKey))\\e[0m"' <<< ${signerJSON} 2> /dev/null)
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

		#Show an alert if there is a special proof for the deposit return address and it does not match up with the one in the action
		if [[ "${proofDepositReturnAddr}" != "-" ]]; then
			if [[ "${proofDepositReturnAddr}" == "${actionDepositAddr}" ]]; then
				echo -e "\e[0m${iconYes} The Deposit Return-StakeAddr in the govAction is the same as in the metadata proof!\e[0m\n";
			else
				echo -e "\e[0m${iconNo} The Deposit Return-StakeAddr in the govAction is not the same as in the metadata proof!\e[0m\n";
			fi
		fi

		#Show governance action title if available
		if [[ "${govActionTitle}" != "-" ]]; then
			echo -e "\e[0mAction-Title: \e[36m${govActionTitle}\e[0m\n"
		fi

		#DO A NICE OUTPUT OF THE DIFFERENT CONTENTS & DO THE RIGHT CALCULATIONS FOR THE ACCEPTANCE
		case "${actionTag}" in

				"InfoAction") 		#This is just an InfoAction
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

				"NoConfidence")		#This is just a NoConfidence action
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
							{ read withdrawalEntries; read withdrawalCounts; } <<< $(jq -r '"\(.[0])" // "[]", (.[0]|length) // 0' <<< ${actionContents} 2> /dev/null)
							echo -e "\e[0mAction-Content:\e[36m Withdrawal funds from the treasury\n\e[0m"

							#Show all found entries
							for (( tmpCnt3=0; tmpCnt3<${withdrawalCounts}; tmpCnt3++ ))
							do
								{ read withdrawalsAmount; read withdrawalsKeyType; read withdrawalsHash; read withdrawalsNetwork; } <<< $( jq -r ".[${tmpCnt3}][1] // 0, (.[${tmpCnt3}][0].credential|keys[0]) // null, (.[${tmpCnt3}][0].credential|flatten[0]) // null, .[${tmpCnt3}][0].network // null" 2> /dev/null <<< ${withdrawalEntries})
								case "${withdrawalsNetwork,,}${withdrawalsKeyType,,}" in

								*"scripthash")  echo -e "\e[0mWithdrawal to\e[32m ScriptHash \e[0m► \e[94m${withdrawalsHash}\e[0m"
										;;

								"mainnet"*)     withdrawalsAddr=$(${bech32_bin} "stake" <<< "e1${withdrawalsHash}" 2> /dev/null);
										if [[ $? -ne 0 ]]; then echo -e "\n\e[35mERROR - Could not get Withdrawals Stake-Address from KeyHash '${withdrawalsHash}' !\n\e[0m"; exit 1; fi
										echo -e "\e[0mWithdrawal to\e[32m StakeAddr \e[0m► \e[94m${withdrawalsAddr}\e[0m"
										;;

								"testnet"*)     withdrawalsAddr=$(${bech32_bin} "stake_test" <<< "e0${withdrawalsHash}" 2> /dev/null);
										if [[ $? -ne 0 ]]; then echo -e "\n\e[35mERROR - Could not get Withdrawals Stake-Address from KeyHash '${withdrawalsHash}' !\n\e[0m"; exit 1; fi
										echo -e "\e[0mWithdrawal to\e[32m StakeAddr \e[0m► \e[94m${withdrawalsAddr}\e[0m"
										;;

								"")             echo -e "\e[0mWithdrawal \e[32mdirectly\e[0m to the \e[94mDeposit-Return-Address\n\e[0m"
										withdrawalsAddr="${actionDepositAddr}"
										;;

								*)              echo -e "\n\e[35mERROR - Unknown network type ${withdrawalsNetwork} for the Withdrawal KeyHash !\n\e[0m"; exit 1;
										;;
								esac
								echo -e "\e[0mWithdrawal the\e[32m Amount \e[0m► \e[94m$(convertToADA ${withdrawalsAmount}) ADA / ${withdrawalsAmount} lovelaces\e[0m"
								echo -e "\e[0m"
							done

							#Show an alert if there is a special proof for the withdrawal address and it does not match up with the one in the action
							if [[ "${proofWithdrawalAddr}" != "-" ]]; then
								if [[ "${proofWithdrawalAddr}" == "${withdrawalsAddr}" ]]; then
									echo -e "\e[0m${iconYes} The Withdrawal StakeAddr in the govAction is the same as in the metadata proof!\e[0m\n";
								else
									echo -e "\e[0m${iconNo} The Withdrawal StakeAddr in the govAction is not the same as in the metadata proof!\e[0m\n";
								fi
							fi

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

		#If there is a voterHash, get the voting answer for it
		if [[ "${voterHash}" != "" ]]; then
			voteAnswer=$(jq -r ".dRepVotes[\"keyHash-${voterHash}\"] // .committeeVotes[\"keyHash-${voterHash}\"] // .dRepVotes[\"scriptHash-${voterHash}\"] // .committeeVotes[\"scriptHash-${voterHash}\"] // .stakePoolVotes[\"${voterHash}\"]" 2> /dev/null <<< "${actionEntry}")
			echo -ne "\e[97mVoting-Answer of the selected ${voterType}-Voter is: "
			case "${voteAnswer}" in
				*"Yes"*)	echo -e "\e[102m\e[30m YES \e[0m\n";;
				*"No"*)		echo -e "\e[101m\e[30m NO \e[0m\n";;
				*"Abstain"*)	echo -e "\e[43m\e[30m ABSTAIN \e[0m\n";;
			esac
		fi

		printf "\e[97mCurrent Votes\e[90m │     \e[0mYes\e[90m    │     \e[0mNo\e[90m     │   \e[0mAbstain\e[90m  │ \e[0mAlwNoConfi\e[90m │ \e[0mThreshold\e[90m │ \e[97mLive-Pct\e[90m │ \e[97mAccept\e[0m\n"
		printf "\e[90m──────────────┼────────────┼────────────┼────────────┼────────────┼───────────┼──────────┼────────\e[0m\n"
		if [[ "${dRepAcceptIcon}" != "" ]]; then
			printf "\e[94m%13s\e[90m │ \e[32m%10s\e[90m │ \e[91m%10s\e[90m │ \e[33m%10s\e[90m │ \e[33m%10s\e[90m │ \e[0m%7s %%\e[90m │ \e[97m%6s %%\e[90m │   %b \e[0m\n" "DReps" "${actionDRepVoteYesCount}" "${actionDRepVoteNoCount}" "${actionDRepAbstainCount}" "" "${dRepPowerThreshold}" "${dRepPct}" "${dRepAcceptIcon}"
			printf "\e[94m%13s\e[90m │ \e[32m%10s\e[90m │ \e[91m%10s\e[90m │ \e[33m%10s\e[90m │ \e[90m%10s\e[90m │ %9s │ %8s │ \e[0m\n" "" "$(convertToShortADA ${dRepPowerYes})" "$(convertToShortADA ${dRepPowerNo})" "$(convertToShortADA ${dRepPowerAbstain})" "$(convertToShortADA ${dRepPowerAlwaysNoConfidence})" "" ""
			else
			printf "\e[90m%13s\e[90m │ \e[90m%10s\e[90m │ \e[90m%10s\e[90m │ \e[90m%10s\e[90m │ \e[90m%10s\e[90m │ \e[90m%7s %%\e[90m │ \e[90m%6s %%\e[90m │   %b \e[0m\n" "DReps" "-" "-" "-" "-" "-" "-" ""
		fi
		printf "\e[90m──────────────┼────────────┼────────────┼────────────┼────────────┼───────────┼──────────┼────────\e[0m\n"
		if [[ "${poolAcceptIcon}" != "" ]]; then
			printf "\e[94m%13s\e[90m │ \e[32m%10s\e[90m │ \e[91m%10s\e[90m │ \e[33m%10s\e[90m │ \e[33m%10s\e[90m │ \e[0m%7s %%\e[90m │ \e[97m%6s %%\e[90m │   %b \e[0m\n" "StakePools" "${actionPoolVoteYesCount}" "${actionPoolVoteNoCount}" "${actionPoolAbstainCount}" "" "${poolPowerThreshold}" "${poolPct}" "${poolAcceptIcon}"
			printf "\e[94m%13s\e[90m │ \e[32m%10s\e[90m │ \e[91m%10s\e[90m │ \e[33m%10s\e[90m │ \e[90m%10s\e[90m │ %9s │ %8s │ \e[0m\n" "" "$(convertToShortADA ${poolPowerVotedYes})" "$(convertToShortADA ${poolPowerVotedNo})" "$(convertToShortADA ${poolPowerVotedAbstain})" "$(convertToShortADA ${poolPowerAlwaysNoConfidence})" "" ""
			else
			printf "\e[90m%13s\e[90m │ \e[90m%10s\e[90m │ \e[90m%10s\e[90m │ \e[90m%10s\e[90m │ \e[90m%10s\e[90m │ \e[90m%7s %%\e[90m │ \e[90m%6s %%\e[90m │   %b \e[0m\n" "StakePools" "-" "-" "-" "-" "-" "-" ""
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


done

echo -e "\e[0m\n"
