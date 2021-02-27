#!/bin/bash

# Script is brought to you by ATADA_Stakepool, Telegram @atada_stakepool

#load variables from common.sh
. "$(dirname "$0")"/00_common.sh

#Display usage instructions
showUsage() {
cat >&2 <<EOF
Usage:    $(basename $0) sign <witnessfile> <signingkey>              ... Signs the witnessFile with the given signingKey
	  $(basename $0) sign mypool_ledger_128463691.witness ledger  ... Signs the witnessFile with the ledger.staking key

          $(basename $0) add <witnessfile> <poolFileName>             ... Adds a signed witnessFile to the waiting collection of the <poolFileName>
          $(basename $0) add mypool_ledger_128463691.witness mypool   ... Adds the signed witnessFile to the mypool.pool.json witness collection

          $(basename $0) clear <poolFileName>  ... Clears any witness collections in the <poolFileName>.pool.json
          $(basename $0) clear mypool          ... Clears all witnesses in mypool.pool.json for a fresh start

          $(basename $0) info <poolFileName>   ... Shows the current witness state in the <poolFileName>.pool.json
          $(basename $0) info mypool           ... Shows the current witness state in the mypool.pool.json to see if some are still missing

EOF
}

showWitnessCollection() {
regWitnessID=$(jq -r ".regWitness.id" <<< ${poolJSON})
regWitnessDate=$(date --date="@${regWitnessID}" -R)
regWitnessType=$(jq -r ".regWitness.type" <<< ${poolJSON})
regWitnessTxBody=$(jq -r ".regWitness.txBody" <<< ${poolJSON})
regWitnessPayName=$(jq -r ".regWitness.regPayName" <<< ${poolJSON})
poolMetaTicker=$(jq -r ".poolMetaTicker" <<< ${poolJSON})

currentTip=$(get_currentTip)
ttl=$(jq -r ".regWitness.ttl" <<< ${poolJSON})

echo -e "\e[0mChecking Witness Content in the poolFile: \e[32m${poolFile}.pool.json\e[0m"
echo
echo -e "\e[0m            ID: \e[32m${regWitnessID}\e[0m\tCreation date: \e[32m${regWitnessDate}\e[0m"
echo -ne "\e[0m   Current-Tip: \e[32m${currentTip}   \e[0m\tTransaction-TTL: "
if [[ ${ttl} -lt ${currentTip} ]]; then #if the TTL stored in the witness collection is lower than the current tip, the transaction window is over
echo -e "\e[35m${ttl}\n\nYou have waited too long to assemble the witness collection! Start all over again by running:\e[33m 05d_poolWitness.sh clear ${poolFile}\e[0m\n\n"; exit 1;
else
echo -e "\e[32m${ttl}\e[0m (window is still open)";
fi
echo -e "\e[0m          Type: \e[32m${regWitnessType}\e[0m"
echo -e "\e[0mpoolMetaTicker: \e[32m${poolMetaTicker}\e[0m"
echo -e "\e[0m   Payment via: \e[32m${regWitnessPayName}\e[0m"
echo
witnessCnt=$(jq ".regWitness.witnesses | length" <<< ${poolJSON})
echo -e "\e[0m Witnesses-Cnt: \e[32m${witnessCnt}\e[0m"
echo

missingWitness=""       #will be set to yes if we have at least one missing witness
for (( tmpCnt=0; tmpCnt<${witnessCnt}; tmpCnt++ ))
do

  witnessName=$(jq -r ".regWitness.witnesses | keys_unsorted[${tmpCnt}]" <<< ${poolJSON})

  if [[ $(jq ".regWitness.witnesses.\"${witnessName}\".witness | length" <<< ${poolJSON}) -gt 0 ]]; then #witness data is in the json

        echo -e "\e[90m\t[$((${tmpCnt}+1))]\t\e[32m[ Ready ]    \e[0m ${witnessName} \e[0m"
  else
        missingWitness="yes"
        extWitnessFile="${poolFile}.$(basename ${witnessName}).witness"
        echo -e "\e[90m\t[$((${tmpCnt}+1))]\t\e[35m[Missing]    \e[0m ${witnessName} \e[0m-> Sign and add it via script \e[33m05d_poolWitness.sh\e[0m and the specific witness file:\e[33m ${extWitnessFile}\e[0m"
  fi

done
echo

if [[ "${missingWitness}" == "yes" ]]; then

        if ${offlineMode}; then #In offlinemode, ask about adding each witnessfile to the offlineTransfer.json

		readOfflineFile;

                for (( tmpCnt=0; tmpCnt<${witnessCnt}; tmpCnt++ ))
                do

                        witnessName=$(jq -r ".regWitness.witnesses | keys_unsorted[${tmpCnt}]" <<< ${poolJSON})

                        if [[ $(jq ".regWitness.witnesses.\"${witnessName}\".witness | length" <<< ${poolJSON}) -eq 0 ]]; then
                                fileToAttach="${poolFile}.$(basename ${witnessName}).witness"
                                #Ask about attaching the metadata file into the offlineJSON, because we're cool :-)
                                if [ -f "${fileToAttach}" ]; then
                                        if ask "\e[33mInclude the '${fileToAttach}' into '$(basename ${offlineFile})' to transfer it in one step?" N; then
                                        offlineJSON=$( jq ".files.\"${fileToAttach}\" += { date: \"$(date -R)\", size: \"$(du -b ${fileToAttach} | cut -f1)\", base64: \"$(base64 -w 0 ${fileToAttach})\" }" <<< ${offlineJSON});
                                        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
                                        echo "${offlineJSON}" > ${offlineFile}
                                        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
                                        echo
                                        fi
                                fi



                        fi
                done
        fi

echo -e "\n\e[35mThere are missing witnesses for this Transaction, please sign and add them\e[0m\n";

else

echo -e "\n\e[32mLooking good, no missing witnesses. You should be ready to re-run script: \e[33m05c_regStakepoolCert.sh ${poolFile} ${regWitnessPayName}\e[0m\n\n";

fi

}


################################################
# MAIN START
#
# Check commandline parameters
#
if [[ $# -eq 0 ]]; then $(showUsage); exit 1; fi
case ${1} in

  sign )
		action="${1}";
                if [[ $# -eq 3 ]]; then witnessFile="$(dirname ${2})/$(basename ${2} .witness).witness"; witnessFile=${witnessFile/#.\//}; signingKey="$(dirname ${3})/$(basename ${3} .staking).staking"; signingKey=${signingKey/#.\//}; else echo -e "\e[35mMissing parameters!\e[0m\n"; showUsage; exit 1; fi
                if [ ! -f "${witnessFile}" ]; then echo -e "\e[35mError - ${witnessFile} file not found !\e[0m\n"; showUsage; exit 1; fi
 		if ! [[ -f "${signingKey}.skey" || -f "${signingKey}.hwsfile" ]]; then echo -e "\n\e[35mError - \"${signingKey}.skey/hwsfile\" file not found !\e[0m"; showUsage; exit 1; fi
 		if [ ! -f "${signingKey}.vkey" ]; then echo -e "\n\e[35mError - \"${signingKey}.vkey\" file not found !\e[0m"; showUsage; exit 1; fi
		;;

  add )
                action="${1}";
                if [[ $# -eq 3 ]]; then poolFile="$(dirname ${3})/$(basename $(basename ${3} .json) .pool)"; poolFile=${poolFile/#.\//}; witnessFile="$(dirname ${2})/$(basename ${2} .witness).witness"; witnessFile=${witnessFile/#.\//}; else echo -e "\e[35mMissing parameters!\e[0m\n"; showUsage; exit 1; fi
                if [ ! -f "${witnessFile}" ]; then echo -e "\e[35mError - ${witnessFile} file not found !\e[0m\n"; showUsage; exit 1; fi
                if [ ! -f "${poolFile}.pool.json" ]; then echo -e "\e[35mError - ${poolFile}.pool.json file not found !\e[0m\n"; showUsage; exit 1; fi
                ;;

  clear|info )
                action="${1}";
                if [[ $# -eq 2 ]]; then poolFile="$(dirname ${2})/$(basename $(basename ${2} .json) .pool)"; poolFile=${poolFile/#.\//}; else echo -e "\e[35mMissing parameters!\e[0m\n"; showUsage; exit 1; fi
                if [ ! -f "${poolFile}.pool.json" ]; then echo -e "\e[35mError - ${poolFile}.pool.json file not found !\e[0m\n"; showUsage; exit 1; fi
                ;;

  * ) 		showUsage; exit 1;
		;;
esac

case ${action} in

  clear )
		#Clears the witnesscollection in the ${poolFile}
		poolJSON=$(cat ${poolFile}.pool.json)   #Read PoolJSON File into poolJSON variable for modifications within this script

		if [[ $( jq -r ".regWitness | length" <<< ${poolJSON}) -gt 0 ]]; then

			if ask "\e[33mDo you really wanna delete the witness collection? Continue ?" N; then
				poolJSON=$( jq "del (.regWitness)" <<< ${poolJSON})
				file_unlock ${poolFile}.pool.json
				echo "${poolJSON}" > ${poolFile}.pool.json
				checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
				file_unlock ${poolFile}.pool.json
			fi

		else
		echo -e "\n\e[0mThere are no witnesses in the ${poolFile} !\e[0m\n";
		fi
		echo
		exit
                ;;

  info )
		#Shows the info about the witnessCollection in the ${poolFile}
                poolJSON=$(cat ${poolFile}.pool.json)   #Read PoolJSON File into poolJSON variable for modifications within this script
                if [[ $( jq -r ".regWitness | length" <<< ${poolJSON}) -gt 0 ]]; then
                #Displays infos about the witness content in the ${poolFile}
                showWitnessCollection;
		else
                echo -e "\n\e[0mThere are no witnesses in the ${poolFile}.pool.json !\e[0m\n";
                fi
                exit;
                ;;


  add )
                poolJSON=$(cat ${poolFile}.pool.json)   #Read PoolJSON File into poolJSON variable for modifications within this script
                if [[ $( jq -r ".regWitness | length" <<< ${poolJSON}) -eq 0 ]]; then echo -e "\n\e[0mThere are no witnesses in the ${poolFile}.pool.json !\e[0m\n"; exit 1; fi

                witnessJSON=$(cat ${witnessFile} | jq . 2> /dev/null)   #Read witnessFile into witnessJSON variable
                if [[ $? -ne 0 ]]; then echo "ERROR - ${witnessFile} is not a valid JSON file" >&2; exit 1; fi

                witnessID=$(jq -r ".id" <<< ${witnessJSON})
                witnessDate=$(jq -r ".\"date-created\"" <<< ${witnessJSON})
                witnessSignedDate=$(jq -r ".\"date-signed\"" <<< ${witnessJSON})
                witnessType=$(jq -r ".type" <<< ${witnessJSON})
                witnessTxBody=$(jq -r ".txBody" <<< ${witnessJSON})
                witnessSigningName=$(jq -r ".\"signing-name\"" <<< ${witnessJSON})
                witnessSigningVkey=$(jq -r ".\"signing-vkey\"" <<< ${witnessJSON} | jq .)
                witnessPoolMetaTicker=$(jq -r ".poolMetaTicker" <<< ${witnessJSON})
                currentTip=$(get_currentTip)


		regWitnessID=$(jq -r ".regWitness.id" <<< ${poolJSON})
		regWitnessDate=$(date --date="@${regWitnessID}" -R)
		regWitnessType=$(jq -r ".regWitness.type" <<< ${poolJSON})
		regWitnessTxBody=$(jq -r ".regWitness.txBody" <<< ${poolJSON})
		regWitnessPayName=$(jq -r ".regWitness.regPayName" <<< ${poolJSON})
		poolMetaTicker=$(jq -r ".poolMetaTicker" <<< ${poolJSON})

		currentTip=$(get_currentTip)
		ttl=$(jq -r ".regWitness.ttl" <<< ${poolJSON})

		echo -e "\e[0mAdding a Signed Witness \e[32m${witnessFile}\e[0m into the poolFile: \e[32m${poolFile}.pool.json\e[0m"
		echo
		echo -e "\e[0m            ID: \e[32m${regWitnessID}\e[0m\tCreation date: \e[32m${regWitnessDate}\e[0m"
		echo -ne "\e[0m   Current-Tip: \e[32m${currentTip}   \e[0m\tTransaction-TTL: "
		if [[ ${ttl} -lt ${currentTip} ]]; then #if the TTL stored in the witness collection is lower than the current tip, the transaction window is over
		echo -e "\e[35m${ttl}\n\nYou have waited too long to assemble the witness collection! Start all over again by running:\e[33m 05d_poolWitness.sh clear ${poolFile}\e[0m\n\n"; exit 1;
		else
		echo -e "\e[32m${ttl}\e[0m (window is still open)";
		fi
		echo -e "\e[0m          Type: \e[32m${regWitnessType}\e[0m"
		echo -e "\e[0mpoolMetaTicker: \e[32m${poolMetaTicker}\e[0m"
		echo -e "\e[0m   Payment via: \e[32m${regWitnessPayName}\e[0m"
		echo
		echo -ne "\e[0mImporting a Witness for \e[32m${witnessSigningName} (${witnessSignedDate})\e[0m ... \e[0m"

		#Check about all details so that it matches up
		if [[ ! "${witnessID}" == "${regWitnessID}" ]]; then echo -e "\n\n\e[35mThe Witness-ID (${witnessID}) does not match to the one in the ${poolFile}.pool.json ! \e[0m\n\n"; exit 1; fi

                #If not signed, exit with a message
              	if [[ $(jq ".signedWitness | length" <<< ${witnessJSON}) -eq 0 ]]; then echo -e "\n\n\e[35mThe witness you wanna add is not signed yet, you can sign it with script: \e[0m05d_poolWitness.sh sign\e[0m\n\n"; exit 1; fi
		witnessSignedWitness=$(jq -r ".signedWitness" <<< ${witnessJSON})

		if [[ ! "${witnessType}" == "${regWitnessType}" ]]; then echo -e "\n\n\e[35mThe Witness-Type (${witnessType}) does not match to the one in the ${poolFile}.pool.json ! \e[0m\n\n"; exit 1; fi
		if [[ ! "${witnessPoolMetaTicker}" == "${poolMetaTicker}" ]]; then echo -e "\n\n\e[35mThe Witness-PoolTicker (${witnessPoolMetaTicker}) does not match to the one in the ${poolFile}.pool.json ! \e[0m\n\n"; exit 1; fi
		if [[ ! "${witnessTxBody}" == "${regWitnessTxBody}" ]]; then echo -e "\n\n\e[35mThe Witness-TxBody does not match to the one in the ${poolFile}.pool.json ! \e[0m\n\n"; exit 1; fi

		#If a key with the provided ${witnessSigningName} is not present, exit with a message
		tmpWitnessEntry=$(jq ".regWitness.witnesses.\"${witnessSigningName}\"" <<< ${poolJSON})
		if [[ "${tmpWitnessEntry}" == null ]]; then echo -e "\n\n\e[35mThe Witness-Name (${witnessSigningName}) does not exist in the ${poolFile}.pool.json ! \e[0m\n\n"; exit 1; fi

		#If there is already a filled witness entry for the proviced ${witnessSigningName} than ask if we should overwrite the entry
		tmpWitnessEntry=$(jq ".regWitness.witnesses.\"${witnessSigningName}\".witness | length" <<< ${poolJSON})

		if [[ ${tmpWitnessEntry} -gt 0 ]]; then
			if ask "\e[33mWitness already in the ${poolFile}.pool.json, do you wanna overwrite it?" N; then
				poolJSON=$(jq ".regWitness.witnesses.\"${witnessSigningName}\".witness = ${witnessSignedWitness}" <<< ${poolJSON}); #include the witnesses in the poolJSON
				checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
                        else exit 1; fi

                else

                                poolJSON=$(jq ".regWitness.witnesses.\"${witnessSigningName}\".witness = ${witnessSignedWitness}" <<< ${poolJSON}); #include the witnesses in the poolJSON
                                checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
 		fi

		#Write the witness into the poolFile
                file_unlock ${poolFile}.pool.json
                echo "${poolJSON}" > ${poolFile}.pool.json
		checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
                file_lock ${poolFile}.pool.json


		#Readback the witness to confirm its in the poolFile
                readback=$(cat ${poolFile}.pool.json | jq -r ".regWitness.witnesses.\"${witnessSigningName}\".witness")
                if [[ "${witnessSignedWitness}" == "${readback}" ]]; then
			echo -e "\e[32mSuccess !\e[0m"
			echo
			echo -ne "\e[90mDoing some Clean-Up, deleting WitnessTransferFile ... \e[0m";
			rm -f ${witnessFile};
			checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi;
			echo -e "\e[90mDONE\e[0m";
			else
			echo -e "\n\n\e[35mThe signed Witness could not be written into the ${poolFile}.pool.json ! \e[0m\n\n";
			exit 1;
		fi


		echo
		witnessCnt=$(jq ".regWitness.witnesses | length" <<< ${poolJSON})
		echo -e "\e[0m Witnesses-Cnt: \e[32m${witnessCnt}\e[0m"
		echo

		missingWitness=""       #will be set to yes if we have at least one missing witness
		for (( tmpCnt=0; tmpCnt<${witnessCnt}; tmpCnt++ ))
		do

		  witnessName=$(jq -r ".regWitness.witnesses | keys_unsorted[${tmpCnt}]" <<< ${poolJSON})

		  if [[ $(jq ".regWitness.witnesses.\"${witnessName}\".witness | length" <<< ${poolJSON}) -gt 0 ]]; then #witness data is in the json

		        echo -e "\e[90m\t[$((${tmpCnt}+1))]\t\e[32m[ Ready ]    \e[0m ${witnessName} \e[0m"
		  else
		        missingWitness="yes"
		        extWitnessFile="${poolFile}.$(basename ${witnessName}).witness"
		        echo -e "\e[90m\t[$((${tmpCnt}+1))]\t\e[35m[Missing]    \e[0m ${witnessName} \e[0m-> Sign and add it via script \e[33m05d_poolWitness.sh\e[0m and the specific witness file:\e[33m ${extWitnessFile}\e[0m"
		  fi

		done
		echo

		if [[ "${missingWitness}" == "yes" ]]; then

		        if ${offlineMode}; then #In offlinemode, ask about adding each witnessfile to the offlineTransfer.json

		                readOfflineFile;

		                for (( tmpCnt=0; tmpCnt<${witnessCnt}; tmpCnt++ ))
		                do

		                        witnessName=$(jq -r ".regWitness.witnesses | keys_unsorted[${tmpCnt}]" <<< ${poolJSON})

		                        if [[ $(jq ".regWitness.witnesses.\"${witnessName}\".witness | length" <<< ${poolJSON}) -eq 0 ]]; then
		                                fileToAttach="${poolFile}.$(basename ${witnessName}).witness"
		                                #Ask about attaching the metadata file into the offlineJSON, because we're cool :-)
		                                if [ -f "${fileToAttach}" ]; then
		                                        if ask "\e[33mInclude the '${fileToAttach}' into '$(basename ${offlineFile})' to transfer it in one step?" N; then
		                                        offlineJSON=$( jq ".files.\"${fileToAttach}\" += { date: \"$(date -R)\", size: \"$(du -b ${fileToAttach} | cut -f1)\", base64: \"$(base64 -w 0 ${fileToAttach})\" }" <<< ${offlineJSON});
		                                        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
		                                        echo "${offlineJSON}" > ${offlineFile}
		                                        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
		                                        echo
		                                        fi
		                                fi



		                        fi
		                done
	        	fi

		echo -e "\n\e[35mThere are missing witnesses for this Transaction, please sign and add them\e[0m\n";

		else

		echo -e "\n\e[32mLooking good, no missing witnesses. You should be ready to re-run script: \e[33m05c_regStakepoolCert.sh ${poolFile} ${regWitnessPayName}\e[0m\n\n";

		fi

		exit
		;;

  sign )
		#Sign the given witnessFile with the signingKey
                witnessJSON=$(cat ${witnessFile} | jq . 2> /dev/null)   #Read witnessFile into witnessJSON variable for modifications within this script
		if [[ $? -ne 0 ]]; then echo "ERROR - ${witnessFile} is not a valid JSON file" >&2; exit 1; fi

		witnessID=$(jq -r ".id" <<< ${witnessJSON})
		witnessDate=$(jq -r ".\"date-created\"" <<< ${witnessJSON})
		witnessType=$(jq -r ".type" <<< ${witnessJSON})
		witnessTxBody=$(jq -r ".txBody" <<< ${witnessJSON})
		ttl=$(jq -r ".ttl" <<< ${witnessJSON})
		witnessSigningName=$(jq -r ".\"signing-name\"" <<< ${witnessJSON})
		witnessSigningVkey=$(jq -r ".\"signing-vkey\"" <<< ${witnessJSON} | jq .)
		poolMetaTicker=$(jq -r ".poolMetaTicker" <<< ${witnessJSON})
		currentTip=$(get_currentTip)

		echo -e "\e[0mSigning Witness in the witnessFile \e[32m${witnessFile}\e[0m with the signing key: \e[32m${signingKey}\e[0m"
		echo
		echo -e "\e[0m            ID: \e[32m${witnessID}\e[0m\tCreation date: \e[32m${witnessDate}\e[0m"
		echo -ne "\e[0m   Current-Tip: \e[32m${currentTip}   \e[0m\tTransaction-TTL: "
		if [[ ${ttl} -lt ${currentTip} ]]; then #if the TTL stored in the witness collection is lower than the current tip, the transaction window is over
		echo -e "\e[35m${ttl}\n\nYou have waited too long to assemble the witness collection! Start all over again by running:\e[33m 05d_poolWitness.sh clear ${poolFile}\e[0m\n\n"; exit 1;
		else
		echo -e "\e[32m${ttl}\e[0m (window is still open)";
		fi
		echo -e "\e[0m          Type: \e[32m${witnessType}\e[0m"
		echo -e "\e[0mpoolMetaTicker: \e[32m${poolMetaTicker}\e[0m"
		echo -ne "\e[0m Generated for: \e[32m${witnessSigningName}\e[0m"
		if [[ ! "${signingKey}" == "${witnessSigningName}" ]]; then echo -e " \e[33m(Name mismatch, but maybe the VKEY is ok, lets check)\e[0m"; fi
		echo

		#If already signed, exit with a message
		if [[ $(jq ".signedWitness | length" <<< ${witnessJSON}) -gt 0 ]]; then echo -e "\n\n\e[33mWitness was already signed, you can now add it back into the WitnessCollection with script: \e[0m05d_poolWitness.sh\e[0m\n\n"; exit 1; fi

		#Check that the used vkey is the same as in the witness file
		echo
		echo -ne "\e[0mChecking \e[32m${signingKey}.vkey\e[0m content against witness: "
		vkeyJSON=$(cat ${signingKey}.vkey | jq .)
		if [[ "${vkeyJSON}" == "${witnessSigningVkey}" ]]; then echo -e "\e[32mOK\e[0m\n"; else echo -e "\e[35mError - Thats the wrong Signing Key !\e[0m"; exit 1; fi

		tmpWitnessFile="${tempDir}/$(basename ${signingKey}).tmp.witness"

		#Sign via normal cli skey or hardware key, depends on the content of the vkey description
		if [[ "$(jq -r .description < ${signingKey}.vkey)" == *"Hardware"* ]]; then #Signing via Hardwarekey

			echo -e "\e[0mSigning via Hardware-Wallet ...\n"
			if [ ! -f "${signingKey}.hwsfile" ]; then echo -e "\n\e[35mError - \"${signingKey}.hwsfile\" file not found !\e[0m"; exit 1; fi
	                start_HwWallet; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
			tmp=$(${cardanohwcli} transaction witness --tx-body-file <(echo ${witnessTxBody}) --hw-signing-file ${signingKey}.hwsfile ${magicparam} --out-file ${tmpWitnessFile} 2> /dev/stdout)
			if [[ "${tmp^^}" == *"ERROR"* ]]; then echo -e "\e[35m${tmp}\e[0m\n"; exit 1; else echo -e "\e[32mDONE\e[0m"; fi
			checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

	                tmpWitness=$(cat ${tmpWitnessFile})
	                #Doing a txWitness Hack, because currently the ledger-fw is not using the right Era - Must be removed later when corrected!
	                #Disabled now with cardano-hw-cli release 1.1.2
			#if [[ "$(jq -r .type <<< ${witnessTxBody})" == "TxBodyMary" ]]; then tmpWitness=$(jq ".type = \"TxWitness MaryEra\"" <<< ${tmpWitness}); fi
	                #if [[ "$(jq -r .type <<< ${witnessTxBody})" == "TxBodyAllegra" ]]; then tmpWitness=$(jq ".type = \"TxWitness AllegraEra\"" <<< ${tmpWitness}); fi

                	witnessJSON=$(jq ".signedWitness = ${tmpWitness}" <<< ${witnessJSON}); #include the witness in the witnessJSON
			checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
                	witnessJSON=$(jq ".\"date-signed\" = \"$(date -R)\"" <<< ${witnessJSON}); #include the date in the witnessJSON
			checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi


		else #Signing via normal cli key

                        echo -e "\e[0mSigning via CLI-Key ...\n"
                        if [ ! -f "${signingKey}.skey" ]; then echo -e "\n\e[35mError - \"${signingKey}.skey\" file not found !\e[0m"; exit 1; fi
			tmpWitness=$(${cardanocli} transaction witness --tx-body-file <(echo ${witnessTxBody}) --signing-key-file ${signingKey}.skey ${magicparam} --out-file /dev/stdout)
                        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
                        witnessJSON=$(jq ".signedWitness = ${tmpWitness}" <<< ${witnessJSON}); #include the witness in the witnessJSON
                        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
                        witnessJSON=$(jq ".\"date-signed\" = \"$(date -R)\"" <<< ${witnessJSON}); #include the date in the witnessJSON
                        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

		fi

                echo "${witnessJSON}" > ${witnessFile}
                if [ $? -eq 0 ]; then
                          echo -e "\n\n\e[33mWitness was successfully signed, you can now add it back into the WitnessCollection with script: \e[0m05d_poolWitness.sh add\e[0m\n\n";
                                 else
                          echo -e "\n\n\e[35mError - Witness could not be written back to the ${witnessFile} !\e[0m\n\n";
                fi
		exit
		;;
esac
