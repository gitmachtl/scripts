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

case $# in
  1 ) checkCommitteeName="$(dirname $1)/$(basename $1 .hash)"; checkCommitteeName=${checkCommitteeName/#.\//};
      checkCommiteeID=${1,,};;
  * ) cat >&2 <<EOF
Usage:  $(basename $0) <Committee-Name | committeeHASH-Hex | committeeHASH-Bech "cc_cold1.../cc_hot1...">

EOF
  exit 1;; esac

#Check can only be done in online mode
if ${offlineMode}; then echo -e "\e[35mYou have to be in ONLINE or LIGHT mode to do this!\e[0m\n"; exit 1; fi

echo -e "\e[0mChecking CommitteeKey-Information on Chain - Resolving given Info into CommitteeKey-HASH:\n"

#Check about the various input options: hex hash, bech id, .hash file, .cc-cold.hash file, .cc-hot.hash file, .vkey file, .cc-cold.vkey file, .cc-hot.vkey file
if [[ "${checkCommiteeID//[![:xdigit:]]}" == "${checkCommiteeID}" && ${#checkCommiteeID} -eq 56 ]]; then #parameter is a hex-drepid

	#Its a hex HASH
	committeeHASH=${checkCommiteeID}


elif [[ ("${checkCommiteeID:0:8}" == "cc_cold1" || "${checkCommiteeID:0:7}" == "cc_hot1") && (${#checkCommiteeID} -eq 59 || ${#checkCommiteeID} -eq 58) ]]; then #parameter is most likely a bech32-id

	#Its a bech ID cc_cold1... or cc_hot1...
	echo -ne "\e[0mCheck if given Bech-ID\e[32m ${checkCommiteeID}\e[0m is valid ..."
	#lets do some further testing by converting the bech32 Committee-id into a Hex-Committee-HASH
	committeeHASH=$(${bech32_bin} 2> /dev/null <<< "${checkCommiteeID}") #will have returncode 0 if the bech was valid
        if [ $? -ne 0 ]; then echo -e "\n\n\e[35mERROR - \"${checkCommiteeID}\" is not a valid Bech32 Committee-HASH.\e[0m"; exit 1; fi
	echo -e "\e[32m OK\e[0m\n"


elif [ -f "${checkCommitteeName}.hash" ]; then #parameter is a Committee hash file, containing the hash id

	#Its a *.hash file
	echo -ne "\e[0mReading from Committee-HASH-File\e[32m ${checkCommitteeName}.hash\e[0m ..."
	checkCommiteeID=$(cat "${checkCommitteeName}.hash" 2> /dev/null)
        if [ $? -ne 0 ]; then echo -e "\n\n\e[35mERROR - Could not read from file \"${checkCommitteeName}.hash\"\e[0m"; exit 1; fi
	echo -e "\e[32m OK\e[0m\n"
	#lets do some further testing that the read hash is in hex format
	if [[ "${checkCommiteeID//[![:xdigit:]]}" != "${checkCommiteeID}" || ${#checkCommiteeID} -ne 56 ]]; then #parameter is a hex-drepid
		echo -e "\e[35mERROR - \"${checkCommiteeID}\" is not a valid Bech32 Committee-HASH.\e[0m"; exit 1;
	fi
	committeeHASH=${checkCommiteeID}


elif [ -f "${checkCommitteeName}.cc-cold.hash" ]; then #parameter is a Committee Cold hash file, containing the hash id

	#Its a *.cc-cold.hash file
	echo -ne "\e[0mReading from Committee-Cold-HASH-File\e[32m ${checkCommitteeName}.cc-cold.hash\e[0m ..."
	checkCommiteeID=$(cat "${checkCommitteeName}.cc-cold.hash" 2> /dev/null)
        if [ $? -ne 0 ]; then echo -e "\n\n\e[35mERROR - Could not read from file \"${checkCommitteeName}.cc-cold.hash\"\e[0m"; exit 1; fi
	echo -e "\e[32m OK\e[0m\n"
	#lets do some further testing that the read hash is in hex format
	if [[ "${checkCommiteeID//[![:xdigit:]]}" != "${checkCommiteeID}" || ${#checkCommiteeID} -ne 56 ]]; then #parameter is a hex-drepid
		echo -e "\e[35mERROR - \"${checkCommiteeID}\" is not a valid Bech32 Committee-HASH.\e[0m"; exit 1;
	fi
	committeeHASH=${checkCommiteeID}


elif [ -f "${checkCommitteeName}.cc-hot.hash" ]; then #parameter is a Committee Hot hash file, containing the hash id

	#Its a *.cc-hot.hash file
	echo -ne "\e[0mReading from Committee-Hot-HASH-File\e[32m ${checkCommitteeName}.cc-hot.hash\e[0m ..."
	checkCommiteeID=$(cat "${checkCommitteeName}.cc-hot.hash" 2> /dev/null)
        if [ $? -ne 0 ]; then echo -e "\n\n\e[35mERROR - Could not read from file \"${checkCommitteeName}.cc-hot.hash\"\e[0m"; exit 1; fi
	echo -e "\e[32m OK\e[0m\n"
	#lets do some further testing that the read hash is in hex format
	if [[ "${checkCommiteeID//[![:xdigit:]]}" != "${checkCommiteeID}" || ${#checkCommiteeID} -ne 56 ]]; then #parameter is a hex-drepid
		echo -e "\e[35mERROR - \"${checkCommiteeID}\" is not a valid Bech32 Committee-HASH.\e[0m"; exit 1;
	fi
	committeeHASH=${checkCommiteeID}


elif [ -f "${checkCommitteeName}.vkey" ]; then #parameter is a Committee verification key file

	#Its a *.vkey file
	echo -ne "\e[0mConvert from Verification-Key-File\e[32m ${checkCommitteeName}.vkey\e[0m ..."
	#Get the committeeHASH from the vkey file to just show it
	committeeHASH=$(${cardanocli} ${cliEra} governance committee key-hash --verification-key-file "${checkCommitteeName}.vkey" 2> /dev/null)
        if [ $? -ne 0 ]; then echo -e "\n\n\e[35mERROR - Could not generate the Committee-HASH from \"${checkCommitteeName}.vkey\"\e[0m"; exit 1; fi
	echo -e "\e[32m OK\e[0m\n"


elif [ -f "${checkCommitteeName}.cc-cold.vkey" ]; then #parameter is a Committee Cold verification key file

	#Its a *.cc-cold.vkey file
	echo -ne "\e[0mConvert from Cold-Verification-Key-File\e[32m ${checkCommitteeName}.cc-cold.vkey\e[0m ..."
	#Get the committeeHASH from the vkey file to just show it
	committeeHASH=$(${cardanocli} ${cliEra} governance committee key-hash --verification-key-file "${checkCommitteeName}.cc-cold.vkey" 2> /dev/null)
        if [ $? -ne 0 ]; then echo -e "\n\n\e[35mERROR - Could not generate the Committee-HASH from \"${checkCommitteeName}.cc-cold.vkey\"\e[0m"; exit 1; fi
	echo -e "\e[32m OK\e[0m\n"


elif [ -f "${checkCommitteeName}.cc-hot.vkey" ]; then #parameter is a Committee Hot verification key file

	#Its a *.cc-hot.vkey file
	echo -ne "\e[0mConvert from Hot-Verification-Key-File\e[32m ${checkCommitteeName}.cc-hot.vkey\e[0m ..."
	#Get the committeeHASH from the vkey file to just show it
	committeeHASH=$(${cardanocli} ${cliEra} governance committee key-hash --verification-key-file "${checkCommitteeName}.cc-hot.vkey" 2> /dev/null)
        if [ $? -ne 0 ]; then echo -e "\n\n\e[35mERROR - Could not generate the Committee-HASH from \"${checkCommitteeName}.cc-hot.vkey\"\e[0m"; exit 1; fi
	echo -e "\e[32m OK\e[0m\n"


else

	echo -e "\n\e[35mERROR - \"Cannot read in information for ${checkCommitteeName}.[cc-cold/cc-hot].[hash/vkey]\"\n\"${checkCommiteeID}\" is also not a valid Committee-HASH in Hex- or Bech-Format!\e[0m"; exit 1

fi

echo -e "\e[0mChecking Information about the CommitteeKey-HASH:\e[32m ${committeeHASH}\e[0m\n"


# We don't make a difference if the given CommitteeKey-HASH is for a Cold-Key or for a Hot-Key, we query for both

# Get state data for the committeeHASH. When in online mode of course from the node and the chain, in light mode via koios

# COLD KEY CHECK
case ${workMode} in

        "online")
                        #echo -e "\e[0mChecking Information about the Committee-COLD-HASH:\e[0m\n"
                        showProcessAnimation "Query Committee-State Info: " &
                        committeeStateJSON=$(${cardanocli} ${cliEra} query committee-state --cold-verification-key-hash ${committeeHASH} 2> /dev/stdout )
                        if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${committeeStateJSON}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
                        ;;

#       "light")        ;;
#
#        "offline")      readOfflineFile; #Reads the offlinefile into the offlineJSON variable
#                        drepStateJSON=$(jq -r ".drep.\"${drepID}\".drepStateJSON" <<< ${offlineJSON} 2> /dev/null)
#                        if [[ "${drepStateJSON}" == null ]]; then echo -e "\e[35mDRep-ID not included in the offline transferFile, please include it first online!\e[0m\n"; exit; fi
#                        ;;
        *) ;;

esac


#If there is no information in the result (length of the committee entrie is zero), try to query for the committeeHASH as a Hot-Key
if [[ $(jq -r ".committee | length" <<< ${committeeStateJSON}) -eq 0 ]]; then

	# HOT KEY CHECK
	case ${workMode} in

	        "online")
	                        #echo -e "\e[0mChecking Information about the Committee-HOT-HASH:\e[0m\n"
	                        showProcessAnimation "Query Committee-State Info: " &
	                        committeeStateJSON=$(${cardanocli} ${cliEra} query committee-state --hot-key-hash ${committeeHASH} 2> /dev/stdout )
	                        if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${committeeStateJSON}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
	                        ;;

	#       "light")        ;;
	#
	#        "offline")      readOfflineFile; #Reads the offlinefile into the offlineJSON variable
	#                        drepStateJSON=$(jq -r ".drep.\"${drepID}\".drepStateJSON" <<< ${offlineJSON} 2> /dev/null)
	#                        if [[ "${drepStateJSON}" == null ]]; then echo -e "\e[35mDRep-ID not included in the offline transferFile, please include it first online!\e[0m\n"; exit; fi
	#                        ;;
	        *) ;;

	esac
fi

#### DATA FORMAT
#{
#    "committee": {
#        "keyHash-5f1b4429fe3bda963a7b70ab81135112a785afcf55ccd695b122e794": {
#            "expiration": null,
#            "hotCredsAuthStatus": {
#                "contents": {
#                    "keyHash": "5aa349227e4068c85c03400396bcea13c7fd57d0ec78c604bc768fc5"
#                },
#                "tag": "MemberAuthorized"
#            },
#            "nextEpochChange": {
#                "tag": "ToBeRemoved"
#            },
#            "status": "Unrecognized"
#        }
#    },
#    "epoch": 240,
#    "quorum": 0.0
#}

comColdHashArray=(); readarray -t comColdHashArray <<< $(jq -r ".committee | keys_unsorted[]" <<< "${committeeStateJSON}" 2> /dev/null)
comColdHashArrayCnt=$(jq -r ".committee | length" <<< "${committeeStateJSON}" 2> /dev/null)

#If the amount of entries is zero, exit with a message that no information was found
if [[ ${comColdHashArrayCnt} == 0 ]]; then
	echo -e "\e[0mFound: \e[33m0 entries\e[0m\n"
	echo -e "\e[0mCommitteeKey HASH is \e[33mNOT\e[0m on the chain, no informations found!\n\e[0m";
	exit;
fi

echo -e "\e[0mFound: \e[32m${comColdHashArrayCnt} entry/entries\e[0m\n"

#Information was found, this can be one entry or more in case a Committee-Hot-Key was used multiple times
#Loop thru the results and list them
for (( tmpCnt=0; tmpCnt<${comColdHashArrayCnt}; tmpCnt++ ))
do
	comColdEntry=${comColdHashArray[${tmpCnt}]} #key-hash entry

	{ read comColdEntryCnt;
	  read comColdHotAuthHash;
	  read comColdHotAuthTag;
	  read comColdExpirationEpoch;
	  read comColdStatus;
	  read comColdNextEpochChange; } <<< $(jq -r ".committee | length, ( .\"${comColdEntry}\" | .hotCredsAuthStatus.contents.keyHash // \"-\", .hotCredsAuthStatus.tag // \"-\", .expiration // \"-\", .status // \"-\", .nextEpochChange.tag // \"-\")" <<< ${committeeStateJSON})

	comColdHash=${comColdEntry: -56} #last 56chars of the entry is the hash itself

	if [[ ${comColdHashArrayCnt} -gt 1 ]]; then echo -e "\e[0m----- Entry \e[32m$((${tmpCnt}+1)) \e[0mof \e[32m${comColdHashArrayCnt}\e[0m -----\n"; fi

	case ${comColdHotAuthTag} in

		"MemberResigned") #Resigned
		        echo -e "\e[0m Committee-Cold-Key HASH: \e[33m${comColdHash} (RESIGNED) ";;

		*) #Registered
			#Highlight the entry in green if it was the hash we initially searched for
			if [[ "${comColdHash}" == "${committeeHASH}" ]]; then activeColor="\e[32m"; else activeColor="\e[94m"; fi
		        echo -e "\e[0m Committee-Cold-Key HASH: ${activeColor}${comColdHash}";;

	esac

	#Highlight the entry in green if it was the hash we initially searched for
	if [[ "${comColdHotAuthHash}" == "${committeeHASH}" ]]; then activeColor="\e[32m"; else activeColor="\e[94m"; fi
        echo -e "\e[0mAuthorizing-Hot-Key HASH: ${activeColor}${comColdHotAuthHash}\e[0m"
        echo -e "\e[0m    Current Status / Tag: \e[94m${comColdStatus} / ${comColdHotAuthTag}\e[0m"
        echo -e "\e[0m        Expiration Epoch: \e[94m${comColdExpirationEpoch}\e[0m"
        echo -e "\e[0m       Next Epoch Change: \e[94m${comColdNextEpochChange}\e[0m"
        echo
	echo

done

echo -e "\e[0m\n"
