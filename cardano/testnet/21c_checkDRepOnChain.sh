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
  1 ) checkDRepName="$(dirname $1)/$(basename $(basename $1 .id) .drep)"; checkDRepName=${checkDRepName/#.\//};
      checkDRepID=${1,,};;
  * ) cat >&2 <<EOF
Usage:  $(basename $0) <DRep-Name | DRepID-Hex | DRepID-Bech "drep1...">

EOF
  exit 1;; esac

#Check can only be done in online mode
#if ${offlineMode}; then echo -e "\e[35mYou have to be in ONLINE or LIGHT mode to do this!\e[0m\n"; exit 1; fi

echo -e "\e[0mChecking DRep-Information on Chain - Resolving given Info into DRep-ID:\n"

#Check if the provided DRep-Identification is a Hex-DRepID(length56), a Bech32-DRepID(length56 and starting with drep1) or a DRep-VKEY-File
if [[ "${checkDRepID//[![:xdigit:]]}" == "${checkDRepID}" && ${#checkDRepID} -eq 56 ]]; then #parameter is a hex-drepid

	echo -ne "\e[0mConvert given HEX-ID \e[32m${checkDRepID}\e[0m ..."
	drepID=$(${bech32_bin} "drep" <<< "${checkDRepID}" 2> /dev/null)
        if [ $? -ne 0 ]; then echo -e "\n\n\e[35mERROR - Couldn't convert HEX-ID into Bech-ID.\e[0m"; exit 1; fi
	echo -e "\e[32m OK\e[0m\n"


elif [[ "${checkDRepID:0:5}" == "drep1" && ${#checkDRepID} -eq 56 ]]; then #parameter is most likely a bech32-drepid

	echo -ne "\e[0mCheck if given Bech-ID\e[32m ${checkDRepID}\e[0m is valid ..."
	#lets do some further testing by converting the bech32 DRep-id into a Hex-DRep-ID
	tmp=$(${bech32_bin} 2> /dev/null <<< "${checkDRepID}") #will have returncode 0 if the bech was valid
        if [ $? -ne 0 ]; then echo -e "\n\n\e[35mERROR - \"${checkDRepID}\" is not a valid Bech32 DRep-ID.\e[0m"; exit 1; fi
	echo -e "\e[32m OK\e[0m\n"
	drepID=${checkDRepID}

elif [ -f "${checkDRepName}.drep.vkey" ]; then #parameter is a DRep verification key file

	echo -ne "\e[0mConvert from Verification-Key-File\e[32m ${checkDRepName}.drep.vkey\e[0m ..."
	#Get the drepID from the vkey file to just show it
	drepID=$(${cardanocli} ${cliEra} governance drep id --drep-verification-key-file "${checkDRepName}.drep.vkey" --out-file /dev/stdout 2> /dev/null)
        if [ $? -ne 0 ]; then echo -e "\n\n\e[35mERROR - Could not generate the DRep-ID from \"${checkDRepName}.drep.vkey\"\e[0m"; exit 1; fi
	echo -e "\e[32m OK\e[0m\n"

elif [ -f "${checkDRepName}.drep.id" ]; then #parameter is a DRep verification id file, containing a bech32 id

	echo -ne "\e[0mReading from DRep-ID-File\e[32m ${checkDRepName}.drep.id\e[0m ..."
	checkDRepID=$(cat "${checkDRepName}.drep.id" 2> /dev/null)
        if [ $? -ne 0 ]; then echo -e "\n\n\e[35mERROR - Could not read from file \"${checkDRepName}.drep.id\"\e[0m"; exit 1; fi
	echo -e "\e[32m OK\e[0m\n"
	#lets do some further testing by converting the bech32 DRep-id into a Hex-DRep-ID
	tmp=$(${bech32_bin} 2> /dev/null <<< "${checkDRepID}") #will have returncode 0 if the bech was valid
        if [ $? -ne 0 ]; then echo -e "\e[35mERROR - \"${checkDRepID}\" is not a valid Bech32 DRep-ID.\e[0m"; exit 1; fi
	drepID=${checkDRepID}

else
	echo -e "\n\e[35mERROR - \"${checkDRepName}.drep.vkey/id\" does not exist, nor is \"${checkDRepID}\" a valid DRep-ID in Hex- or Bech-Format!\e[0m"; exit 1
fi

echo -e "\e[0mChecking Information about the DRep-ID:\e[32m ${drepID}\e[0m\n"

#Get state data for the drepID. When in online mode of course from the node and the chain, in light mode via koios
case ${workMode} in

        "online")       showProcessAnimation "Query DRep-ID Info: " &
#                        drepStateJSON=$(${cardanocli} ${cliEra} query drep-state --drep-key-hash ${drepID} --include-stake 2> /dev/stdout )
                        drepStateJSON=$(${cardanocli} ${cliEra} query drep-state --drep-key-hash ${drepID} 2> /dev/stdout )
                        if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${drepStateJSON}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
                        drepStateJSON=$(jq -r .[0] <<< "${drepStateJSON}") #get rid of the outer array
                        ;;

#       "light")        showProcessAnimation "Query DRep-ID-Info-LightMode: " &
#                       drepStateJSON=$(queryLight_drepInfo "${drepID}")
#                       if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${drepStateJSON}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
#                       ;;

        "offline")      readOfflineFile; #Reads the offlinefile into the offlineJSON variable
                        drepStateJSON=$(jq -r ".drep.\"${drepID}\".drepStateJSON" <<< ${offlineJSON} 2> /dev/null)
                        if [[ "${drepStateJSON}" == null ]]; then echo -e "\e[35mDRep-ID not included in the offline transferFile, please include it first online!\e[0m\n"; exit; fi
                        ;;

esac

#jq -r . <<< ${drepStateJSON}


{ read drepEntryCnt;
  read drepDepositAmount;
  read drepAnchorURL;
  read drepAnchorHASH;
  read drepExpireEpoch;
  read drepDelegatedStake; } <<< $(jq -r 'length, .[1].deposit, .[1].anchor.url // "-", .[1].anchor.dataHash // "-", .[1].expiry // "-", .[1].stake // 0' <<< ${drepStateJSON})

#Checking about the content
if [[ ${drepEntryCnt} == 0 ]]; then #not registered yet
        echo -e "\e[0mDRep-ID is\e[33m NOT registered on the chain\e[0m!\e[0m\n";
	exit 1;

elif [[ ${drepExpireEpoch} -lt $(get_currentEpoch) ]]; then #activity expired
	echo -e "\e[0mDRep-ID is \e[32mregistered\e[0m but activity \e[91mexpired\e[0m on the chain!\n"
	echo -e "\e[0m Deposit-Amount:\e[32m ${drepDepositAmount}\e[0m lovelaces"
	echo -e "\e[0m Inactive-Epoch:\e[91m ${drepExpireEpoch}\e[0m"

else #normal registration and not expired
	echo -e "\e[0mDRep-ID is \e[32mregistered\e[0m on the chain!\n"
	echo -e "\e[0m Deposit-Amount:\e[32m ${drepDepositAmount}\e[0m lovelaces"
	echo -e "\e[0m   Expire-Epoch:\e[32m ${drepExpireEpoch}\e[0m"
fi

echo -e "\e[0m     Anchor-URL:\e[32m ${drepAnchorURL}\e[0m"
echo -e "\e[0m    Anchor-HASH:\e[32m ${drepAnchorHASH}\e[0m"
echo -e "\e[0mDelegated-Stake:\e[32m $(convertToADA ${drepDelegatedStake}) ADA\e[0m"
echo

#If in online/light mode, check the drepAnchorURL
if ${onlineMode}; then

        #get Anchor-URL content and calculate the Anchor-Hash
        if [[ ${drepAnchorURL} != "-" ]]; then

                #we write out the downloaded content to a file 1:1, so we can do a hash calculation on the file itself rather than on text content
                tmpAnchorContent="${tempDir}/DRepAnchorURLContent.tmp"; touch "${tmpAnchorContent}"; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

                #check if the URL is a normal one or an ipfs one, in case of ipfs, use https://ipfs.io/ipfs/xxx to load the content
                if [[ "${drepAnchorURL}" =~ ipfs://.* ]]; then queryURL="https://ipfs.io/ipfs/${drepAnchorURL:7}"; else queryURL="${drepAnchorURL}"; fi

		echo -e "\e[0m      Query-URL:\e[94m ${queryURL}\e[0m";

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

						echo -e "\e[0m  Anchor-STATUS:\e[35m not a valid JSON format!\e[0m";
						rm "${tmpAnchorContent}";

					else #anchor-url is a json

	                                        contentHASH=$(b2sum -l 256 "${tmpAnchorContent}" 2> /dev/null | cut -d' ' -f 1)
	                                        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
	                                        if [ "${contentHASH}" != "${drepAnchorHASH}" ]; then
							echo -e "\e[0m  Anchor-STATUS:\e[35m HASH does not match! Online-HASH is \e[33m${contentHASH}\e[0m";
						else
							echo -e "\e[0m  Anchor-STATUS:\e[32m Format and HASH is valid!\e[0m";
						fi
	                                        rm "${tmpAnchorContent}" #cleanup

					fi #anchor is a json
                                        ;;

                                "404" ) #file-not-found
					echo -e "\e[0m  Anchor-STATUS:\e[35m No content was found on the Anchor-URL\e[0m";
                                        ;;

                                * )
					echo -e "\e[0m  Anchor-STATUS:\e[35m Query of the Anchor-URL failed!\n\nHTTP Request File: ${drepAnchorURL}\nHTTP Response Code: ${responseCode}\n\e[0m";
                                        ;;
                        esac;

                else

					echo -e "\e[0m  Anchor-STATUS:\e[35m Query of the Anchor-URL failed!\e[0m";

                fi #error & response
                unset errorcnt error

        fi # ${drepAnchorURL} != ""

fi ## ${onlineMode} == true


echo -e "\e[0m\n"
