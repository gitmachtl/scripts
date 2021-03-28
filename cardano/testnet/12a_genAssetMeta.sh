#!/bin/bash

# Script is brought to you by ATADA_Stakepool, Telegram @atada_stakepool

#load variables from common.sh
#       socket          Path to the node.socket (also exports socket to CARDANO_NODE_SOCKET_PATH)
#       genesisfile     Path to the genesis.json
#       magicparam      TestnetMagic parameter
#       cardanocli      Path to the cardano-cli executable
#       cardanonode     Path to the cardano-node executable
. "$(dirname "$0")"/00_common.sh

#Check cardano-metadata-submitter tool if given path is ok, if not try to use the one in the scripts folder
if ! exists "${cardanometa}"; then
                                #Try the one in the scripts folder
                                if [[ -f "${scriptDir}/cardano-metadata-submitter" ]]; then cardanometa="${scriptDir}/cardano-metadata-submitter";
                                else majorError "Path ERROR - Path to the 'cardano-metadata-submitter' binary is not correct or 'cardano-metadata-submitter' binaryfile is missing!\nYou can find it here: https://github.com/input-output-hk/cardano-metadata-submitter\nThis is needed to format and sign the NativeAsset Metadata Registry file. Please check your 00_common.sh or common.inc settings."; exit 1; fi
fi

case $# in

  1 ) policyName="$(echo $1 | cut -d. -f 1)";
      assetName="$(echo $1 | cut -d. -f 2-)"; assetName=$(basename "${assetName}" .asset); #assetName=${assetName//./};
      ;;

  * ) cat >&2 <<EOF
Usage:  $(basename $0) <PolicyName.AssetName>

EOF
  exit 1;; esac

#Check assetName for alphanummeric only, 32 chars max
if [[ "${assetName}" == ".asset" ]]; then assetName="";
elif [[ ! "${assetName}" == "${assetName//[^[:alnum:]]/}" ]]; then echo -e "\e[35mError - Your given AssetName '${assetName}' should only contain alphanummeric chars!\e[0m"; exit 1; fi
if [[ ${#assetName} -gt 32 ]]; then echo -e "\e[35mError - Your given AssetName is too long, maximum of 32 chars allowed!\e[0m"; exit 1; fi

# Check for needed input files
if [ ! -f "${policyName}.policy.id" ]; then echo -e "\n\e[35mERROR - \"${policyName}.policy.id\" id-file does not exist! Please create it first with script 10.\e[0m"; exit 1; fi
if [ ! -f "${policyName}.policy.script" ]; then echo -e "\n\e[35mERROR - \"${policyName}.policy.script\" scriptfile does not exist! Please create it first with script 10.\e[0m"; exit 1; fi
if [ ! -f "${policyName}.policy.skey" ]; then echo -e "\n\e[35mERROR - \"${policyName}.policy.skey\" signing key does not exist! Please create it first with script 10.\e[0m"; exit 1; fi
policyID=$(cat ${policyName}.policy.id)

assetFileName="${policyName}.${assetName}.asset"

assetNameBech=$(convert_tokenName2BECH ${policyID} ${assetName})
assetSubject="${policyID}$(convert_assetNameASCII2HEX ${assetName})"

echo -e "\e[0mGenerating Metadata for the Asset \e[32m'${assetName}'\e[0m with Policy \e[32m'${policyName}'\e[0m: ${assetNameBech}"

#set timetolife (inherent hereafter) to the currentTTL or to the value set in the policy.script for the "before" slot (limited policy lifespan)
ttlFromScript=$(cat ${policyName}.policy.script | jq -r ".scripts[] | select(.type == \"before\") | .slot" 2> /dev/null || echo "unlimited")
if [[ ! ${ttlFromScript} == "unlimited" ]]; then ttl=${ttlFromScript}; else ttl=$(get_currentTTL); fi
echo
echo -e "\e[0mPolicy valid before Slot-Height:\e[33m ${ttlFromScript}\e[0m"
echo

#If there is no Asset-File, build up the skeleton and add some initial data
if [ ! -f "${assetFileName}" ]; then
				assetFileJSON="{}"
				assetFileJSON=$(jq ". += {metaName: \"${assetName}\",
							  metaDescription: \"\",
							  \"---\": \"--- Optional additional info ---\",
							  metaTicker: \"\",
							  metaUrl: \"\",
							  metaLogoPNG: \"\",
							  \"===\": \"--- DO NOT EDIT BELOW THIS LINE !!! ---\",
			        			  minted: \"0\",
                                                          name: \"${assetName}\",
                                                          bechName: \"${assetNameBech}\",
                                                          policyID: \"${policyID}\",
                                                          policyValidBeforeSlot: \"${ttlFromScript}\",
                                                          subject: \"${assetSubject}\",
                                                          lastUpdate: \"$(date -R)\",
                                                          lastAction: \"created Asset-File\"}" <<< ${assetFileJSON})

			        file_unlock ${assetFileName}
			        echo -e "${assetFileJSON}" > ${assetFileName}

			        echo -e "\e[0mAsset-File: \e[32m ${assetFileName} \e[90m\n"
			        cat ${assetFileName}
			        echo

				echo -e "\e[33mA new Asset-File \e[32m'${assetFileName}'\e[33m was created. Please edit the values for the meta-Entries\nto fit your needs. After that, save the file and rerun this script again!"
				echo -e "\e[0m\n"
				exit
fi

#Asset-File exists, lets read out the parameters and save them back in the ordern shown above
#so we have a better editing format in there

#Build Skeleton, all available entries in the real assetFileJSON will overwrite the skeleton entries
assetFileSkeletonJSON=$(jq ". += {metaName: \"${assetName}\",
                                  metaDescription: \"\",
                                  \"---\": \"--- Optional additional info ---\",
                                  metaTicker: \"\",
                                  metaUrl: \"\",
                                  metaLogoPNG: \"\",
                                  \"===\": \"--- DO NOT EDIT BELOW THIS LINE !!! ---\",
                                  minted: \"0\",
                                  name: \"${assetName}\",
                                  bechName: \"${assetNameBech}\",
                                  policyID: \"${policyID}\",
                                  policyValidBeforeSlot: \"${ttlFromScript}\",
                                  subject: \"${assetSubject}\",
                                  lastUpdate: \"$(date -R)\",
                                  lastAction: \"update Asset-File\"}" <<< "{}")

#Read in the current file
assetFileJSON=$(cat ${assetFileName})

#Combine the Skeleton with the real one and
assetFileJSON=$(echo "${assetFileSkeletonJSON} ${assetFileJSON}" | jq -rs 'reduce .[] as $item ({}; . * $item)')

#Write it out again and lock it
file_unlock ${assetFileName}
echo -e "${assetFileJSON}" > ${assetFileName}
file_lock ${assetFileName}

echo -e "\e[0mAsset-File: \e[32m ${assetFileName} \e[90m\n"
echo "${assetFileJSON}"
echo

#So, now we're at the point were we can work with a Full-Data JSON file, now lets check about each
#Metadata Registry parameter

assetSubject=$(jq -r ".subject" <<< ${assetFileJSON})

echo -e "\e[0mGenerating Registry-Submitter-JSON:\e[32m ${assetSubject}.json \e[0m\n"

submitterArray=("--init" "${assetSubject}")

#Check metaName
echo -ne "Adding 'metaName'        ... "
metaName=$(jq -r ".metaName" <<< ${assetFileJSON})
#if [[ ! "${metaName//[[:space:]]}" == "${metaName}" ]]; then echo -e "\e[35mERROR - The metaName '${metaName}' contains spaces, not allowed !\e[0m\n"; exit 1; fi
if [[ ${#metaName} -lt 1 || ${#metaName} -gt 50 ]]; then echo -e "\e[35mERROR - The metaName '${metaName}' is missing or too long. Max. 50chars allowed !\e[0m\n"; exit 1; fi
submitterArray+=("--name" "${metaName}")
echo -e "\e[32mOK\e[0m"

#Check metaDescription
echo -ne "Adding 'metaDescription' ... "
metaDescription=$(jq -r ".metaDescription" <<< ${assetFileJSON})
if [[ ${#metaDescription} -gt 500 ]]; then echo -e "\e[35mERROR - The metaDescription is too long. Max. 500chars allowed !\e[0m\n"; exit 1; fi
submitterArray+=("--description" "${metaDescription}")
echo -e "\e[32mOK\e[0m"

#Add policy script
echo -ne "Adding 'policyScript'    ... "
submitterArray+=("--policy" "${policyName}.policy.script")
echo -e "\e[32mOK\e[0m"

#Check metaTicker - optional
metaTicker=$(jq -r ".metaTicker" <<< ${assetFileJSON})
if [[ ! "${metaTicker}" == "" ]]; then
echo -ne "Adding 'metaTicker'      ... "
	#if [[ ! "${metaTicker//[[:space:]]}" == "${metaTicker}" ]]; then echo -e "\e[35mERROR - The metaTicker '${metaTicker}' contains spaces, not allowed !\e[0m\n"; exit 1; fi
	if [[ ${#metaTicker} -lt 2 || ${#metaTicker} -gt 5 ]]; then echo -e "\e[35mERROR - The metaTicker '${metaTicker}' must be between 3-5 chars!\e[0m\n"; exit 1; fi
	submitterArray+=("--ticker" "${metaTicker}")
	echo -e "\e[32mOK\e[0m"
fi


#Check metaUrl - optional
metaUrl=$(jq -r ".metaUrl" <<< ${assetFileJSON})
if [[ ! "${metaUrl}" == "" ]]; then
	echo -ne "Adding 'metaUrl'         ... "
	if [[ ! "${metaUrl}" =~ https://.* || ${#metaUrl} -gt 250 ]]; then echo -e "\e[35mERROR - The metaUrl has an invalid URL format (must be starting with https://) or is too long. Max. 250 chars allowed !\e[0m\n"; exit 1; fi
	submitterArray+=("--url" "${metaUrl}")
	echo -e "\e[32mOK\e[0m"
fi


#Check metaSubUnitDecimals - optional
#metaSubUnitDecimals=$(jq -r ".metaSubUnitDecimals" <<< ${assetFileJSON})
#if [[ ${metaSubUnitDecimals} -gt 0 ]]; then
#	echo -ne "Adding 'metaSubUnit'     ... "
#	if [[ ${metaSubUnitDecimals} -gt 19 ]]; then echo -e "\e[35mERROR - The metaSubUnitDecimals '${metaSubUnitDecimals}' is too big. Max. value is 19 decimals !\e[0m\n"; exit 1; fi
#	metaSubUnitName=$(jq -r ".metaSubUnitName" <<< ${assetFileJSON})
#	if [[ ! "${metaSubUnitName//[[:space:]]}" == "${metaSubUnitName}" ]]; then echo -e "\e[35mERROR - The metaSubUnitName '${metaSubUnitName}' contains spaces, not allowed !\e[0m\n"; exit 1; fi
#	if [[ ${#metaSubUnitName} -lt 1 || ${#metaSubUnitName} -gt 30 ]]; then echo -e "\e[35mERROR - The metaSubUnitName '${metaSubUnitName}' is too too long. Max. 30chars allowed !\e[0m\n"; exit 1; fi
#	submitterArray+=("--unit" "${metaSubUnitDecimals},${metaSubUnitName}")
#	echo -e "\e[32mOK\e[0m"
#fi

#Check metaPNG - optional
metaLogoPNG=$(jq -r ".metaLogoPNG" <<< ${assetFileJSON})
if [[ ! "${metaLogoPNG}" == "" ]]; then
	echo -ne "Adding 'metaLogoPNG'     ... "
	if [ ! -f "${metaLogoPNG}" ]; then echo -e "\e[35mERROR - The metaLogoPNG '${metaLogoPNG}' file was not found !\e[0m\n"; exit 1; fi
	if [[ $(file -b "${metaLogoPNG}" | grep "PNG" | wc -l) -eq 0 ]]; then echo -e "\e[35mERROR - The metaLogoPNG '${metaLogoPNG}' is not a valid PNG image file !\e[0m\n"; exit 1; fi
	submitterArray+=("--logo" "${metaLogoPNG}")
	echo -e "\e[32mOK\e[0m"
fi

echo

#Execute the file generation and add all the parameters
echo -ne "Execute draft generation and adding parameters ... "
#tmp=$(/bin/bash -c "${cardanometa} ${submitterArray}")
tmp=$(${cardanometa} "${submitterArray[@]}")
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
echo -e "\e[32mOK\e[90m (${tmp})\e[0m"

#Sign the metadata registry submission json draft file
echo -ne "Signing with '${policyName}.policy.skey' ... "
tmp=$(${cardanometa} ${assetSubject} -a "${policyName}.policy.skey")
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
echo -e "\e[32mOK\e[0m"

#Finanlize the metadata registry submission json draft file
echo -ne "Finalizing the draft file ... "
tmp=$(${cardanometa} ${assetSubject} --finalize)
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
echo -e "\e[32mOK\e[90m (${tmp})\e[0m"
assetFileJSON=$(cat ${assetFileName})
assetFileJSON=$(jq ". += {lastUpdate: \"$(date -R)\", lastAction: \"created Metadata-Submitter-File\"}" <<< ${assetFileJSON})
file_unlock ${assetFileName}
echo -e "${assetFileJSON}" > ${assetFileName}
file_lock ${assetFileName}


#Moving Submitter JSON into the same directory as the assetFile
assetDir=$(dirname ${assetFileName})
if [[ ! "${assetDir}" == "." ]]; then
	echo -ne "Moving final JSON into '${assetDir}' Directory ... "
	mv "${assetSubject}.json" "${assetDir}"
	checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
	echo -e "\e[32mOK\e[0m"
fi

assetFileLocation="${assetDir}/${assetSubject}.json"; assetFileLocation=${assetFileLocation/#.\//}

echo
echo -e "\e[33mYour Metadata-Registry-JSON File is now ready to be submitted to: \e[32mhttps://github.com/cardano-foundation/cardano-token-registry"
echo -e "\e[33mas a Pull-Request...\n\nYou can find your file here: \e[32m${assetFileLocation}\e[0m";

echo -e "\e[0m\n"



