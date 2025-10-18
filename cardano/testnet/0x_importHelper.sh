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

  2|3 ) poolName="$(basename $(basename $1 .json) .pool)"; poolName=${poolName//[^[:alnum:]]/};
        importParameter="$2";
        if [[ $# -eq 3 ]]; then exportFile=$3; else exportFile=""; fi
	;;

  * ) cat >&2 <<EOF
Usage:    $(basename $0) <ImportName> <PoolID or InfoJSON> [optional Filename for export]

Example1: $(basename $0) mypool 5ca96bc27be2bdde3ec11b9f696cf21fad39e49097be9b0193e6b572

          This would import the pool settings from the pool with id '5ca96bc27be2bdde3ec11b9f696cf21fad39e49097be9b0193e6b572'
    	  in the folder 'mypool' as mypool.pool.json together with the keys for owner, rewards, ...


Example2  $(basename $0) mypool 5ca96bc27be2bdde3ec11b9f696cf21fad39e49097be9b0193e6b572 poolinfo.json

          This would export the Pool information on an online machine to the file poolinfo.json. So it can be imported
          on an offline machine.


Example2  $(basename $0) mypool poolinfo.json

          This would import the pool settings from the poolinfo.json file. You have to generate this poolinfo.json file before
	  on an online machine if you are working in offlineMode. Please check the README on Github for more details on how to do this.

EOF
  exit 1;;
esac

#Check if importParameter is an actual json file, otherwise try to fetch the information online
if [ -f "${importParameter}" ]; then
			echo -ne "\e[0mReading Pooldata from file: '\e[32m${importParameter}\e[0m' ... ";
			importJSON=$(jq . <${importParameter} 2> /dev/null)
			if [[ $? -ne 0 ]]; then echo "ERROR - ${importJSON} is not a valid JSON file"; exit 1; fi
			poolMetaUrl=$(jq -r ".meta_url" <<< ${importJSON})  #we use the metadata url entry to verify the online export worked fine before
                        if [[ ! "${poolMetaUrl}" =~ https?://.* || ${#poolMetaUrl} -gt 64 ]]; then echo -e "\e[33mERROR, the JSON file does not contain a a valid Metadata-URL!\e[0m\n"; exit 1; fi
                        echo -e "\e[32mOK\e[0m\n";

elif ${onlineMode}; then

			poolID="${importParameter}"

			#Check if the provided Pool-Identification is a Hex-PoolID(length56), a Bech32-PoolID(length56 and starting with pool1) or something else
			if [[ "${poolID//[![:xdigit:]]}" == "${poolID}" && ${#poolID} -eq 56 ]]; then #parameter is a hex-poolid

			        #converting the Hex-PoolID into a Bech-PoolID
			        poolIDBech=$(${bech32_bin} "pool" <<< ${poolID} | tr -d '\n')
			        checkError "$?"; if [ $? -ne 0 ]; then echo -e "\n\e[35mERROR - Could not convert the given Hex-PoolID \"${poolID}\" into a Bech Pool-ID.\e[0m\n"; exit 1; fi
			        echo -e "\e[0mConverted '${poolID}' to the Bech-PoolID:\e[32m ${poolIDBech}\e[0m"
			        echo

			elif [[ "${poolID:0:5}" == "pool1" && ${#poolID} -eq 56 ]]; then #parameter is most likely a bech32-poolid

			        #lets do some further testing by converting the bech32 pool-id into a hex-pool-id
			        tmp=$(${bech32_bin} 2> /dev/null <<< "${poolID}") #will have returncode 0 if the bech was valid
			        if [ $? -ne 0 ]; then echo -e "\n\e[35mERROR - \"${poolID}\" is not a valid Bech Pool-ID.\e[0m\n"; exit 1; fi
			        poolIDBech=${poolID}

			else	#not a hex pool id, not a bech pool id, not an existing file

				echo -e "\n\e[35mERROR - \"${poolID}\" is not a valid Pool-ID or a JSON-File.\e[0m\n"; exit 1;

			fi

			echo -ne "\e[0mFetching Pooldata online via koios for PoolID: '\e[32m${poolIDBech}\e[0m' ... ";
			#query poolinfo via poolid on koios
	                importJSON=$(curl -sL -m 30 -X POST "${koiosAPI}/pool_info" -H "${koiosAuthorizationHeader}" -H "Accept: application/json" -H "Content-Type: application/json" -d "{\"_pool_bech32_ids\":[\"${poolIDBech}\"]}" 2> /dev/null)

	                #check if the received json only contains one entry in the array (will also not be 1 if not a valid json)
	                if [[ $(jq ". | length" 2> /dev/null <<< ${importJSON}) -ne 1 ]]; then echo -e "\e[33mERROR, can't fetch the current online pool data from '${koiosAPI}/pool_info' !\e[0m\n"; exit 1; fi

			#reduce the json to be not in an array, we only work with one pool
			importJSON=$(jq -r .[0] <<< ${importJSON});

			poolMetaUrl=$(jq -r ".meta_url" <<< ${importJSON})
			if [[ ! "${poolMetaUrl}" =~ https?://.* || ${#poolMetaUrl} -gt 64 ]]; then echo -e "\e[33mERROR, not a valid Metadata-URL found in the online pool data!\e[0m\n"; exit 1; fi
			echo -e "\e[32mOK\e[0m\n";


			echo -ne "\e[0mFetching latest Pool-Update online via koios for PoolID: '\e[32m${poolIDBech}\e[0m' ... ";
			#query poolinfo via poolid on koios
	                latestUpdateJSON=$(curl -sL -m 30 -X GET "${koiosAPI}/pool_updates?_pool_bech32=${poolIDBech}" -H "${koiosAuthorizationHeader}" -H "Accept: application/json" 2> /dev/null | jq -r .[0] 2> /dev/null)
	                #check if the received json only contains one entry in the array (will also not be 1 if not a valid json)
	                if [[ ${latestUpdateJSON} == "" ]]; then echo -e "\e[33mERROR, can't fetch the latest pool update from '${koiosAPI}/pool_updates' !\e[0m\n"; exit 1; fi

			latestUpdateTime=$(jq -r ".block_time | select (.!=null)" <<< ${latestUpdateJSON})
			if [[ "$((${latestUpdateTime}+0))" -ne "${latestUpdateTime}" ]]; then echo -e "\e[33mERROR, not a valid block_time entry!\e[0m\n"; exit 1; fi
			echo -e "\e[32mOK\e[0m\n";
		        importJSON=$(jq ".lastupdate_time = ${latestUpdateTime}" 2> /dev/null <<< ${importJSON}); #Adding the actual Metadata content to teh importJSON

			latestUpdateEpoch=$(jq -r ".active_epoch_no | select (.!=null)" <<< ${latestUpdateJSON})
			if [[ "$((${active_epoch_no}+0))" -ne "${active_epoch_no}" ]]; then echo -e "\e[33mERROR, not a valid active_epoch_no entry!\e[0m\n"; exit 1; fi
			echo -e "\e[32mOK\e[0m\n";
		        importJSON=$(jq ".lastupdate_epoch = ${latestUpdateEpoch}" 2> /dev/null <<< ${importJSON}); #Adding the actual Metadata content to teh importJSON

			echo -ne "\e[0mFetching Metadata online from URL: '\e[32m${poolMetaUrl}\e[0m' ... "; #the poolinfo request via koios does not return the complete metadata information, so we grap it directly from the pool-server
        		poolMetaJSON=$(curl -sL "${poolMetaUrl}" 2> /dev/null)
			if [[ $? -ne 0 ]]; then echo -e "\e[33mERROR, can't fetch the current online pool data!\e[0m\n"; exit 1; fi
			poolMetaJSON=$(echo "${poolMetaJSON}" | jq -M) #Always bring it in a nice format
		        importJSON=$(jq ".metadata = ${poolMetaJSON}" 2> /dev/null <<< "${importJSON}"); #Adding the actual Metadata content to teh importJSON
			if [[ $? -ne 0 ]]; then echo -e "\e[33mERROR, not a valid Metadata JSON file found at '${poolMetaUrl}'!\e[0m\n"; exit 1; fi
			echo -e "\e[32mOK\e[0m\n";
else
			echo -e "\e[33mERROR, can't use PoolID in OfflineMode or import json file not found. Please fetch the import.json first\non an online machine and import the import.json instead of using a PoolID!\e[0m\n"; exit 1;
fi

#Export the merged InfoJSON to an external file if parameter was provided
if [[ ! "${exportFile}" == "" ]]; then
				  if ${offlineMode}; then echo -e "\e[35mYou have to be in ONLINE MODE to do this!\e[0m\n"; exit 1; fi
				  if [ -f "${exportFile}" ]; then echo -e "\n\e[33mERROR - \"${exportFile}\" already exist, please delete it first or choose another name.\e[0m"; exit 1; fi;
				  echo -ne "\e[0mExporting InfoJSON to the file: '\e[32m${exportFile}\e[0m' ... ";
				  tmp=$(echo "${importJSON}" > "${exportFile}"); checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
				  echo -e "\e[32mOK\e[0m\n";

                                  #Ask about attaching the metadata file into the offlineJSON, because we're cool :-)
				  fileToAttach="${exportFile}"
                                        if ask "\e[33mInclude the '${fileToAttach}' into '$(basename ${offlineFile})' to transfer it in one step?" N; then


						#Read the current offlineFile
						if [ -f "${offlineFile}" ]; then
						                                offlineJSON=$(jq . ${offlineFile} 2> /dev/null)
						                                if [[ $? -ne 0 ]]; then echo -e "\e[35mERROR - '$(basename ${offlineFile})' is not a valid JSON file, please delete it.\e[0m\n"; exit 1; fi
						                                if [[ $(trimString "${offlineJSON}") == "" ]]; then offlineJSON="{}"; fi #nothing in the file, make a new one
						                            else
						                                offlineJSON="{}";
		                                fi

				                offlineJSON=$( jq ".files.\"${fileToAttach}\" += { date: \"$(date -R)\", size: \"$(du -b ${fileToAttach} | cut -f1)\", base64: \"$(base64 -w 0 ${fileToAttach})\" }" <<< ${offlineJSON});

				                if [[ $? -eq 0 ]]; then
	                                        offlineJSON=$( jq ".history += [ { date: \"$(date -R)\", action: \"attached file '${fileToAttach}'\" } ]" <<< ${offlineJSON})
	                                        echo "${offlineJSON}" > ${offlineFile}
	                                        showOfflineFileInfo;
	                                        echo -e "\e[33mFile '${fileToAttach}' was attached into the '$(basename ${offlineFile})'. :-)\e[0m\n";
		                                else
	                                        echo -e "\e[35mERROR - Could not attach file '${fileToAttach}' to the '$(basename ${offlineFile})'. :-)\e[0m\n"; exit 1;
		                                fi
                                        fi

				  echo -e "\e[0mYou can now use/transfer this file on your OfflineMachine to import the data back in.\n"
				  exit 1;
fi

echo -e "\e[0mUsing the following name for the import process: '\e[32m${poolName}\e[0m'\n";

#Ask to continue if the destination directory exists
if [ -d "${poolName}" ] && ! ask "\e[33mThe destination import Directory '${poolName}' exists, do you wanna continue?" N; then echo; exit 1; fi

#Check if the destination directory exists, if not, try to make it
if [ ! -d "${poolName}" ]; then echo -ne "\e[0mCreating Directory with name: '\e[32m${poolName}\e[0m' ... "; mkdir -p ${poolName}; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi; echo -e "\e[32mOK\e[0m\n"; fi

#Check if json file exists
if [ -f "${poolName}/${poolName}.pool.json" ]; then echo -e "\n\e[33mERROR - \"${poolName}/${poolName}.pool.json\" already exist, please delete it first or choose another name.\e[0m"; exit 1; fi;


#InfoJSON about the pool data is held in the importJSON variable at this point

#Small subroutine to read the value of the JSON and output an error if parameter is empty/missing
function readJSONparam() {
param=$(jq -r .$1 <<<${importJSON} 2> /dev/null)
if [[ "${param}" == null ]]; then echo "ERROR - Parameter \"$1\" in does not exist" >&2; exit 1;
elif [[ "${param}" == "" ]]; then echo "ERROR - Parameter \"$1\" in is empty" >&2; exit 1;
fi
echo "${param}"
}

#Read the base data
poolPledge=$(readJSONparam "pledge"); if [[ ! $? == 0 ]]; then exit 1; fi
poolCost=$(readJSONparam "fixed_cost"); if [[ ! $? == 0 ]]; then exit 1; fi
poolMargin=$(readJSONparam "margin"); if [[ ! $? == 0 ]]; then exit 1; fi
poolMetaName=$(readJSONparam "metadata.name"); if [[ ! $? == 0 ]]; then exit 1; fi
poolMetaDescription=$(readJSONparam "metadata.description"); if [[ ! $? == 0 ]]; then exit 1; fi
poolMetaTicker=$(readJSONparam "metadata.ticker"); if [[ ! $? == 0 ]]; then exit 1; fi
poolMetaHomepage=$(readJSONparam "metadata.homepage"); if [[ ! $? == 0 ]]; then exit 1; fi
poolMetaExtendedMetaUrl=$(jq -r ".metadata.extended" <<< ${importJSON}); if [[ "${poolMetaExtendedMetaUrl}" == null ]]; then poolMetaExtendedMetaUrl=""; fi
poolStatus=$(readJSONparam "pool_status"); if [[ ! $? == 0 ]]; then exit 1; fi
poolLastUpdateTime=$(readJSONparam "lastupdate_time"); if [[ ! $? == 0 ]]; then exit 1; fi
poolLastUpdateEpoch=$(readJSONparam "lastupdate_epoch"); if [[ ! $? == 0 ]]; then exit 1; fi
poolID=$(readJSONparam "pool_id_hex"); if [[ ! $? == 0 ]]; then exit 1; fi
poolIDbech=$(readJSONparam "pool_id_bech32"); if [[ ! $? == 0 ]]; then exit 1; fi

#get the last used op_cert_counter on chain
poolNodeCounter=$(jq -r ".op_cert_counter" <<< "${importJSON}" 2> /dev/null)
if [[ "${poolNodeCounter}" == null ]]; then #no block minted on the chain until now. setting the NodeCounter to -1 so it will be incremented by 1 later on to match a NodeCounter=0
	echo -e "\e[0mInfo: No block minted on the blockchain yet by this poolID.\n"
	poolNodeCounter=-1;
fi

#Build the Skeleton
poolJSON=$(echo "
{
  \"poolName\": \"${poolName}\",
  \"poolOwner\": [
  ],
  \"poolRewards\": \"\",
  \"poolPledge\": \"${poolPledge}\",
  \"poolCost\": \"${poolCost}\",
  \"poolMargin\": \"${poolMargin}\",
  \"poolRelays\": [
  ],
  \"poolMetaName\": \"${poolMetaName}\",
  \"poolMetaDescription\": \"${poolMetaDescription}\",
  \"poolMetaTicker\": \"${poolMetaTicker}\",
  \"poolMetaHomepage\": \"${poolMetaHomepage}\",
  \"poolMetaUrl\": \"${poolMetaUrl}\",
  \"poolExtendedMetaUrl\": \"${poolMetaExtendedMetaUrl}\",
  \"---\": \"--- DO NOT EDIT OR DELETE BELOW THIS LINE ---\",
  \"poolID\": \"${poolID}\",
  \"poolIDbech\": \"${poolIDbech}\"
}
")

#echo "${poolJSON}";

#Adding Relays
poolRelayCnt=$(jq -r '.relays | length' <<< ${importJSON})
for (( tmpCnt=0; tmpCnt<${poolRelayCnt}; tmpCnt++ ))
do

  #get the entry value that is not null and not from key port
  poolRelayEntryContent=$(jq -r ".relays[${tmpCnt}] | to_entries[] | select ((.value != null) and (.key != \"port\")) | .value" <<< ${importJSON} 2> /dev/null);
  if [[ "${poolRelayEntryContent}" == null || "${poolRelayEntryContent}" == "" ]]; then echo "ERROR - Parameter \"entry\" in your Registration does not exist or is empty!"; exit 1;
  elif [[ ${#poolRelayEntryContent} -gt 64 ]]; then echo -e "\e[0mERROR - The relayEntry parameter with content \"${poolRelayEntryContent}\" in your ${poolFile}.pool.json is too long. Max. 64chars allowed !\e[0m"; exit 1; fi

  #get the keyname = type of the entry that is not null and not from key port
  poolRelayEntryType=$(jq -r ".relays[${tmpCnt}] | to_entries[] | select ((.value != null) and (.key != \"port\")) | .key" <<< ${importJSON} 2> /dev/null);
  if [[ "${poolRelayEntryType}" == null || "${poolRelayEntryType}" == "" ]]; then echo "ERROR - Parameter \"type\" does not exist or is empty!"; exit 1; fi

  #Load relay port data, verify later depending on the need (multihost does not need a port)
  poolRelayEntryPort=$(jq -r ".relays[${tmpCnt}].port | select (.!=null)" <<< ${importJSON} 2> /dev/null);

  #Add the entry to the List
  poolJSON=$( jq ".poolRelays += [ { relayType: \"${poolRelayEntryType}\", relayEntry: \"${poolRelayEntryContent}\", relayPort: \"${poolRelayEntryPort}\" } ]" <<< ${poolJSON})

done

#Add current date as regSubmitted entry, if the pool is already registered on the chain
if [[ "${poolStatus}" == "registered" ]]; then
	poolJSON=$(jq ".regEpoch = \"${poolLastUpdateEpoch}\"" <<< ${poolJSON})
	poolJSON=$(jq ".regSubmitted = \"$(date -R --date=@${poolLastUpdateTime})\"" <<< ${poolJSON})
fi

echo -e "\e[0mThe following content was prepared for the '\e[32m${poolName}/${poolName}.pool.json\e[0m' file, but not written yet:\n";
echo -e "\e[90m${poolJSON}\e[0m\n"


#ImportNodeKeys
importNodeSkey() {

        #If the sourcefile source not exist, drop an error message and repeat the prompt
        if [ ! -f "$1" ]; then echo -e "\n\e[35mERROR - \"$1\" does not exist, please retry.\e[0m\n" >&2; exit 1; fi;

        #Check if destination file already exists, if yes, abort with an error
        if [ -f "${poolName}/${poolName}.node.skey" ]; then echo -e "\n\e[35mERROR - \"${poolName}/${poolName}.node.skey\" already exist, please delete it first or choose another name.\e[0m\n" >&2; exit 1; fi;

	#Check the right type
	if [[ ! "$(jq -r .type $1)" == *"SigningKey"* ]]; then echo -e "\n\e[35mERROR - \"$1\" is not a valid node(cold).skey file.\e[0m\n" >&2; exit 1; fi;

        #Copy the source to the new destination file
        echo
        echo -ne "\n\e[0mCopying the file '\e[32m$1\e[0m' to new destination '\e[32m${poolName}/${poolName}.node.skey\e[0m' ... " >&2;
        cp "$1" "${poolName}/${poolName}.node.skey"; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
        file_lock "${poolName}/${poolName}.node.skey"
        echo -e "\e[32mOK\e[0m" >&2;

        #Generate the pairing Vkey file from the Skey file
        echo -ne "\e[0mGenerating file '\e[32m${poolName}/${poolName}.node.vkey\e[0m' ... " >&2;
        ${cardanocli} ${cliEra} key verification-key --signing-key-file "${poolName}/${poolName}.node.skey" --verification-key-file "${poolName}/${poolName}.node.vkey"; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
        file_lock "${poolName}/${poolName}.node.vkey"
        echo -e "\e[32mOK\e[0m" >&2;

        #Generate the node counter file

	echo -e "\e[0mCurrent OpCertCounter on Chain: \e[32m${poolNodeCounter}\e[0m" >&2;
	poolNodeCounter=$((${poolNodeCounter}+1))
	echo -e "\e[0mNew OpCertCounter for this import: \e[32m${poolNodeCounter}\e[0m" >&2;
        echo -ne "\e[0mGenerating file '\e[32m${poolName}/${poolName}.node.counter\e[0m' ... " >&2;
	${cardanocli} ${cliEra} node new-counter --cold-verification-key-file "${poolName}/${poolName}.node.vkey" --counter-value ${poolNodeCounter} --operational-certificate-issue-counter-file "${poolName}/${poolName}.node.counter"
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
        #NodeCounter file was written, now add the description in the file to reflect the next node counter number
        newCounterJSON=$(jq ".description = \"Next certificate issue number: ${poolNodeCounter}\"" < "${poolName}/${poolName}.node.counter")
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
        echo "${newCounterJSON}" > "${poolName}/${poolName}.node.counter"
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
        file_lock "${poolName}/${poolName}.node.counter"
        echo -e "\e[32mOK\e[0m" >&2;

exit 0
}


#Import the node cold keys
nodeSkey="node.skey";
read -e -i "${nodeSkey}" -p $'\e[33mPath to your "node(cold).skey" file or leave it blank to skip: \e[0m' nodeSkey
nodeSkey=${nodeSkey/\~/$HOME} #substitute ~ with $HOME because fileexist is stupid
while [[ ! "${nodeSkey}" == "" ]]; do

	returnCode=$(importNodeSkey "${nodeSkey}"); if [ $? -eq 0 ]; then break; fi

read -e -i "${nodeSkey}" -p $'\e[33mPath to your "node(cold).skey" file or leave it blank to skip: \e[0m' nodeSkey
nodeSkey=${nodeSkey/\~/$HOME}
done
echo


#ImportVrfKeys
importVrfSkey() {

        #If the sourcefile source not exist, drop an error message and repeat the prompt
        if [ ! -f "$1" ]; then echo -e "\n\e[35mERROR - \"$1\" does not exist, please retry.\e[0m\n" >&2; exit 1; fi;

        #Check if destination file already exists, if yes, abort with an error
        if [ -f "${poolName}/${poolName}.vrf.skey" ]; then echo -e "\n\e[35mERROR - \"${poolName}/${poolName}.vrf.skey\" already exist, please delete it first or choose another name.\e[0m\n" >&2; exit 1; fi;

        #Check the right type
        if [[ ! "$(jq -r .type $1)" == *"SigningKey"* ]]; then echo -e "\n\e[35mERROR - \"$1\" is not a valid vrf.skey file.\e[0m\n" >&2; exit 1; fi;

	#Probe the given VRF key hash with the one that is online
	newVRFstring=$(${cardanocli} ${cliEra} key verification-key --signing-key-file "${1}" --verification-key-file /dev/stdout | jq -r .cborHex) #the maybe new vrf string
	newVRFhash=$(${cardanocli} ${cliEra} node key-hash-VRF --verification-key "${newVRFstring:4}") #crop the first 4 chars before handing over the string
	oldVRFhash=$(jq -r ".vrf_key_hash" 2> /dev/null <<< ${importJSON} )
	if [[ ! "${newVRFhash}" == "${oldVRFhash}" ]]; then echo -e "\n\e[35mWARNING - VRF KeyHash does not match up with the one that is online right now!\e[0m\n" >&2; exit 1; fi;

        #Copy the source to the new destination file
        echo
        echo -ne "\n\e[0mCopying the file '\e[32m$1\e[0m' to new destination '\e[32m${poolName}/${poolName}.vrf.skey\e[0m' ... " >&2;
        cp "$1" "${poolName}/${poolName}.vrf.skey"; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
        file_lock ${poolName}/${poolName}.vrf.skey
        echo -e "\e[32mOK\e[0m" >&2;

        #Generate the pairing Vkey file from the Skey file
        echo -ne "\e[0mGenerating file '\e[32m${poolName}/${poolName}.vrf.vkey\e[0m' ... " >&2;
        ${cardanocli} ${cliEra} key verification-key --signing-key-file "${poolName}/${poolName}.vrf.skey" --verification-key-file "${poolName}/${poolName}.vrf.vkey"; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
        file_lock ${poolName}/${poolName}.vrf.vkey
        echo -e "\e[32mOK\e[0m\n" >&2;

exit 0
}

#Import the node vrf keys
vrfSkey="vrf.skey";
read -e -i "${vrfSkey}" -p $'\e[33mPath to your "vrf.skey" file or leave it blank to skip: \e[0m' vrfSkey
vrfSkey=${vrfSkey/\~/$HOME}
while [[ ! "${vrfSkey}" == "" ]]; do

        returnCode=$(importVrfSkey "${vrfSkey}"); if [ $? -eq 0 ]; then break; fi

read -e -i "${vrfSkey}" -p $'\e[33mPath to your "vrf.skey" file or leave it blank to skip: \e[0m' vrfSkey
vrfSkey=${vrfSkey/\~/$HOME}
done
echo

#ImportPaymentKeys
importPaymentSkey() {

        #If the sourcefile source not exist, drop an error message and repeat the prompt
        if [ ! -f "$1" ]; then echo -e "\n\e[35mERROR - \"$1\" does not exist, please retry.\e[0m\n" >&2; exit 1; fi;

        #Check if destination file already exists, if yes, abort with an error
        if [ -f "${poolName}/${ownerName}.payment.skey" ]; then echo -e "\n\e[35mERROR - \"${poolName}/${ownerName}.payment.skey\" already exist, please delete it first or choose another name.\e[0m\n" >&2; exit 1; fi;

        #Check the right type
        if [[ ! "$(jq -r .type $1)" == *"SigningKey"* ]]; then echo -e "\n\e[35mERROR - \"$1\" is not a valid payment.skey file.\e[0m\n" >&2; exit 1; fi;

        #Copy the source to the new destination file
        echo
        echo -ne "\n\t\e[0mCopying the file '\e[32m$1\e[0m' to new destination '\e[32m${poolName}/${ownerName}.payment.skey\e[0m' ... " >&2;
        cp "$1" "${poolName}/${ownerName}.payment.skey"; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
        file_lock ${poolName}/${ownerName}.payment.skey
        echo -e "\e[32mOK\e[0m" >&2;

        #Generate the pairing Vkey file from the Skey file
        echo -ne "\t\e[0mGenerating file '\e[32m${poolName}/${ownerName}.payment.vkey\e[0m' ... " >&2;
        ${cardanocli} ${cliEra} key verification-key --signing-key-file "${poolName}/${ownerName}.payment.skey" --verification-key-file "${poolName}/${ownerName}.payment.vkey"; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

	#If the verification key is an extended one, convert it into a non-extended one
	tmp=$(jq -r .type "${poolName}/${ownerName}.payment.vkey" 2> /dev/null)
        if [[ "${tmp^^}" == *"EXTENDED"* ]]; then
		${cardanocli} ${cliEra} key non-extended-key --extended-verification-key-file "${poolName}/${ownerName}.payment.vkey" --verification-key-file "${poolName}/${ownerName}.payment.vkey";
  		checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi;
	fi

        file_lock ${poolName}/${ownerName}.payment.vkey
        echo -e "\e[32mOK\e[0m\n" >&2;

exit 0
}

#ImportStakingKeys
importStakingSkey() {

        #If the sourcefile source not exist, drop an error message and repeat the prompt
        if [ ! -f "$1" ]; then echo -e "\n\e[35mERROR - \"$1\" does not exist, please retry.\e[0m\n" >&2; exit 1; fi;

        #Check if destination file already exists, if yes, abort with an error
        if [ -f "${poolName}/${ownerName}.staking.skey" ]; then echo -e "\n\e[35mERROR - \"${poolName}/${ownerName}.staking.skey\" already exist, please delete it first or choose another name.\e[0m\n" >&2; exit 1; fi;

        #Check the right type
        if [[ ! "$(jq -r .type $1)" == *"SigningKey"* ]]; then echo -e "\n\e[35mERROR - \"$1\" is not a valid stake.skey file.\e[0m\n" >&2; exit 1; fi;

        #Copy the source to the new destination file
        echo
        echo -ne "\n\t\e[0mCopying the file '\e[32m$1\e[0m' to new destination '\e[32m${poolName}/${ownerName}.staking.skey\e[0m' ... " >&2;
        cp "$1" "${poolName}/${ownerName}.staking.skey"; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
        file_lock ${poolName}/${ownerName}.staking.skey
        echo -e "\e[32mOK\e[0m" >&2;

        #Generate the pairing Vkey file from the Skey file
        echo -ne "\t\e[0mGenerating file '\e[32m${poolName}/${ownerName}.staking.vkey\e[0m' ... " >&2;
        ${cardanocli} ${cliEra} key verification-key --signing-key-file "${poolName}/${ownerName}.staking.skey" --verification-key-file "${poolName}/${ownerName}.staking.vkey"; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

        #If the verification key is an extended one, convert it into a non-extended one
        tmp=$(jq -r .type "${poolName}/${ownerName}.staking.vkey" 2> /dev/null)
        if [[ "${tmp^^}" == *"EXTENDED"* ]]; then
                ${cardanocli} ${cliEra} key non-extended-key --extended-verification-key-file "${poolName}/${ownerName}.staking.vkey" --verification-key-file "${poolName}/${ownerName}.staking.vkey";
                checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi;
        fi

        file_lock ${poolName}/${ownerName}.staking.vkey
        echo -e "\e[32mOK\e[0m\n" >&2;

exit 0
}


#Import owner keys
ownerName="owner";
ownerCounter=1;

#Loop with break exit if rewards account is present
while true; do

echo -ne "\e[33mPlease provide a name for the \e[32mPoolOwner #${ownerCounter} or RewardsAccount\e[33m or leave it blank to skip:\e[0m"
read -e -i "${ownerName}" -p " " ownerName
ownerName=${ownerName//[^[:alnum:]]-_/};
while [[ ! "${ownerName}" == "" ]]; do

	#Import payment keys
	paymentSkey="payment.skey";
	echo -ne "\n\t\e[33mPath to the 'payment.skey' of '${ownerName}', blank to abort: \e[0m"
	read -e -i "${paymentSkey}" -p " " paymentSkey
	paymentSkey=${paymentSkey/\~/$HOME}
	while [[ ! "${paymentSkey}" == "" ]]; do
        returnCode=$(importPaymentSkey "${paymentSkey}"); if [ $? -eq 0 ]; then returnCode=0; break; fi
	echo -ne "\t\e[33mPath to the 'payment.skey' of '${ownerName}', blank to abort: \e[0m"
	read -e -i "${paymentSkey}" -p " " paymentSkey
	paymentSkey=${paymentSkey/\~/$HOME}
	done

	#Only continue with StakingKeys if the PaymentKeys were successful
        if [ $returnCode -eq 0 ] && [ ! ${paymentSkey} == "" ]; then

	        #Import staking keys
	        stakingSkey="stake.skey";
		echo -ne "\n\t\e[33mPath to the 'stake.skey' of '${ownerName}', blank to abort: \e[0m"
		stakingSkey=${stakingSkey/\~/$HOME}
	        read -e -i "${stakingSkey}" -p " " stakingSkey
	        while [[ ! "${stakingSkey}" == "" ]]; do
	        returnCode=$(importStakingSkey "${stakingSkey}"); if [ $? -eq 0 ]; then returnCode=0; break; fi
		echo -ne "\t\e[33mPath to the 'stake.skey' of '${ownerName}', blank to abort: \e[0m"
	        read -e -i "${stakingSkey}" -p " " stakingSkey
		stakingSkey=${stakingSkey/\~/$HOME}
	        done


		#Only continue with the AddressBuild if Payment- and StakingKeys were successful
		if [ $returnCode -eq 0 ] && [ ! ${stakingSkey} == "" ]; then

			#Building a Payment Address
		        echo -ne "\t\e[0mGenerating file '\e[32m${poolName}/${ownerName}.payment.addr\e[0m' ... ";
			${cardanocli} ${cliEra} address build --payment-verification-key-file "${poolName}/${ownerName}.payment.vkey" --staking-verification-key-file "${poolName}/${ownerName}.staking.vkey" ${addrformat} > "${poolName}/${ownerName}.payment.addr"
			checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
			file_lock "${poolName}/${ownerName}.payment.addr"
		        echo -e "\e[32mOK\e[0m";

			#Building a Staking Address
		        echo -ne "\t\e[0mGenerating file '\e[32m${poolName}/${ownerName}.staking.addr\e[0m' ... ";
			${cardanocli} ${cliEra} stake-address build --staking-verification-key-file "${poolName}/${ownerName}.staking.vkey" ${addrformat} > "${poolName}/${ownerName}.staking.addr"
			checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
			file_lock "${poolName}/${ownerName}.staking.addr"
		        echo -e "\e[32mOK\e[0m";

			#Create an address registration certificate
			#Read ProtocolParameters
			case ${workMode} in
			        "online")       protocolParametersJSON=$(${cardanocli} ${cliEra} query protocol-parameters);; #onlinemode
			        "light")        protocolParametersJSON=${lightModeParametersJSON};; #lightmode
			        "offline")      readOfflineFile;        #Reads the offlinefile into the offlineJSON variable
			                        protocolParametersJSON=$(jq ".protocol.parameters" <<< ${offlineJSON});; #offlinemode
			esac
			checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
			#Lets use the currently set keyDeposit amount
			stakeAddressDepositFee=$(jq -r .stakeAddressDeposit <<< ${protocolParametersJSON})
		        echo -ne "\t\e[0mGenerating file '\e[32m${poolName}/${ownerName}.staking.cert\e[0m' with ${stakeAddressDepositFee} lovelace deposit fee ... ";
			${cardanocli} ${cliEra} stake-address registration-certificate --staking-verification-key-file "${poolName}/${ownerName}.staking.vkey" --key-reg-deposit-amt "${stakeAddressDepositFee}" --out-file "${poolName}/${ownerName}.staking.cert"
			checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
			file_lock "${poolName}/${ownerName}.staking.cert"
		        echo -e "\e[32mOK\e[0m";

                        #Create the delegation certificate to this pool
			if [ -f "${poolName}/${poolName}.node.vkey" ] && [ -f "${poolName}/${ownerName}.staking.vkey" ]; then
	                        echo -ne "\t\e[0mGenerating file '\e[32m${poolName}/${ownerName}.deleg.cert\e[0m' ... ";
				${cardanocli} ${cliEra} stake-address stake-delegation-certificate --stake-verification-key-file "${poolName}/${ownerName}.staking.vkey" --cold-verification-key-file "${poolName}/${poolName}.node.vkey" --out-file "${poolName}/${ownerName}.deleg.cert"
				checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
				file_lock "${poolName}/${ownerName}.deleg.cert"
			        echo -e "\e[32mOK\e[0m";
			fi

			#Add the ownerstaking address to the poolJSON file
			ownerAddr=$(cat "${poolName}/${ownerName}.staking.addr")

			#If the Address is part of the owners then add the owner
			tmp=$(jq -r ".owners[] | select(. == \"${ownerAddr}\")" 2> /dev/null <<< ${importJSON} )
			if [[ ${tmp} != "" ]]; then
				poolJSON=$( jq ".poolOwner += [ { ownerName: \"${ownerName}\", ownerWitness: \"local\" } ]" <<< ${poolJSON})
			        echo -e "\n\t\e[0mAdded '\e[32m${ownerName}\e[0m' as an owner in the ${poolName}.pool.json file. ";
			fi

                        #If the Address is also the rewards account, add it as the rewards account
			tmp=$(jq -r ".reward_addr" 2> /dev/null <<< ${importJSON} )
                        if [[ "${tmp}" == "${ownerAddr}" ]]; then
				poolJSON=$(jq ".poolRewards = \"${ownerName}\"" <<< ${poolJSON})
	                        echo -e "\t\e[0mAdded '\e[32m${ownerName}\e[0m' as the rewards-account in ${poolName}.pool.json file. ";
                        fi
		fi

	fi

echo

ownerCounter=$(( ${ownerCounter} + 1 )); ownerName="owner-${ownerCounter}"
echo -ne "\e[33mPlease provide a name for the \e[32mPoolOwner #${ownerCounter}\e[33m or leave it blank(delete) to skip:\e[0m"
read -e -i "${ownerName}" -p " " ownerName
ownerName=${ownerName//[^[:alnum:]]-_/};
done

poolRewards=$(jq -r ".poolRewards" <<< ${poolJSON})
if [[ ! "${poolRewards}" == "" ]]; then break; fi #break out of the endless while loop if there is already an rewards account present

echo
if ! ask "\e[33mCurrently there is no rewards account included, do you wanna go back and add a payment/staking keypair for the rewards account?" Y; then break; fi

ownerName="owner_andor_rewards"
echo
done #go back to add another owner/rewards account


#Finished, writing out the pool.json file

echo -ne "\n\e[0mWriting the pool.json file with name: '\e[32m${poolName}.pool.json\e[0m' ... "; echo "${poolJSON}" > "${poolName}/${poolName}.pool.json"; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi; echo -e "\e[32mOK\e[0m\n";
file_lock "${poolName}/${poolName}.pool.json"

echo -ne "\e[90m"
cat "${poolName}/${poolName}.pool.json"
echo

echo -e "\e[0mYou can find your imported files in the directory: '\e[32m${poolName}\e[0m'\n\n";
