#!/bin/bash

# Script is brought to you by ATADA_Stakepool, Telegram @atada_stakepool

#load variables from common.sh
#       socket          Path to the node.socket (also exports socket to CARDANO_NODE_SOCKET_PATH)
#       genesisfile     Path to the genesis.json
#       magicparam      TestnetMagic parameter
#       cardanocli      Path to the cardano-cli executable
#       cardanonode     Path to the cardano-node executable
. "$(dirname "$0")"/00_common.sh

#Check token-metadata-creator tool if given path is ok, if not try to use the one in the scripts folder
if ! exists "${cardanometa}"; then
                                #Try the one in the scripts folder
                                if [[ -f "${scriptDir}/token-metadata-creator" ]]; then cardanometa="${scriptDir}/token-metadata-creator";
                                else majorError "Path ERROR - Path to the 'token-metadata-creator' binary is not correct or 'token-metadata-creator' binaryfile is missing!\nYou can find it here: https://github.com/input-output-hk/offchain-metadata-tools\nThis is needed to format and sign the NativeAsset Metadata Registry file. Please check your 00_common.sh or common.inc settings."; exit 1; fi
fi

case $# in

  1 ) policyName="$(echo $1 | cut -d. -f 1)";
      assetName="$(echo $1 | cut -d. -f 2-)"; assetName=$(basename "${assetName}" .asset); #assetName=${assetName//./};
      ;;

  * ) cat >&2 <<EOF
Usage:  $(basename $0) <PolicyName.AssetName>

EOF
  exit 1;; esac

assetFileName="${policyName}.${assetName}.asset" #save the output assetfilename here, because at that state the assetName is with or without the {} brackets

# Check for needed input files
if [ ! -f "${policyName}.policy.id" ]; then echo -e "\n\e[35mERROR - \"${policyName}.policy.id\" id-file does not exist! Please create it first with script 10.\e[0m"; exit 1; fi
if [ ! -f "${policyName}.policy.script" ]; then echo -e "\n\e[35mERROR - \"${policyName}.policy.script\" scriptfile does not exist! Please create it first with script 10.\e[0m"; exit 1; fi
if [ -f "${policyName}.policy.hwsfile" ]; then echo -e "\n\e[35mERROR - \"${policyName}.policy.hwsfile\" - Signing with hardware wallet policies is currently not supported :-( \e[0m"; exit 1; fi
if [ ! -f "${policyName}.policy.skey" ]; then echo -e "\n\e[35mERROR - \"${policyName}.policy.skey\" signing key does not exist! Please create it first with script 10.\e[0m"; exit 1; fi
policyID=$(cat ${policyName}.policy.id)

#Check assetName for alphanummeric / hex
if [[ "${assetName}" == ".asset" ]]; then assetName="";
elif [[ "${assetName,,}" =~ ^\{([[:xdigit:]][[:xdigit:]]){1,}\}$ ]]; then assetName=${assetName,,}; assetName=${assetName:1:-1}; assetHexName=${assetName} #store given hexname in own variable
elif [[ ! "${assetName}" == "${assetName//[^[:alnum:]]/}" ]]; then echo -e "\e[35mError - Your given AssetName '${assetName}' should only contain alphanummeric chars!
Otherwise you can use the binary hexformat like \"{8ac33ed560000eacce}\" as the assetName! Make sure to use full hex-pairs.\e[0m"; exit 1;
else assetName=$(convert_assetNameASCII2HEX ${assetName})
fi

#assetName is in HEX-Format after this point
if [[ ${#assetName} -gt 64 ]]; then echo -e "\e[35mError - Your given AssetName is too long, maximum of 32 bytes allowed!\e[0m"; exit 1; fi  #checking for a length of 64 because a byte is two hexchars

assetNameBech=$(convert_tokenName2BECH "${policyID}${assetName}" "")
assetSubject="${policyID}${assetName}"

echo -e "\e[0mGenerating Metadata for the Asset \e[32m'${assetName}' -> '$(convert_assetNameHEX2ASCII_ifpossible ${assetName})'\e[0m with Policy \e[32m'${policyName}'\e[0m: ${assetNameBech}"

#set timetolife (inherent hereafter) to the currentTTL or to the value set in the policy.script for the "before" slot (limited policy lifespan)
ttlFromScript=$(cat ${policyName}.policy.script | jq -r ".scripts[] | select(.type == \"before\") | .slot" 2> /dev/null || echo "unlimited")
if [[ ! ${ttlFromScript} == "unlimited" ]]; then ttl=${ttlFromScript}; else ttl=$(get_currentTTL); fi
echo
echo -e "\e[0mPolicy valid before Slot-Height:\e[33m ${ttlFromScript}\e[0m"
echo

#If there is no Asset-File, build up the skeleton and add some initial data
if [ ! -f "${assetFileName}" ]; then

				assetTmpName=$(convert_assetNameHEX2ASCII_ifpossible "${assetName}") #if it starts with a . -> ASCII showable name, otherwise the HEX-String
                                if [[ "${assetTmpName:0:1}" == "." ]]; then assetTmpName=${assetTmpName:1}; fi

				assetFileJSON="{}"
				assetFileJSON=$(jq ". += {metaName: \"${assetTmpName:0:50}\",
							  metaDescription: \"\",
							  \"---\": \"--- Optional additional info ---\",
							  metaDecimals: \"\",
							  metaTicker: \"\",
							  metaUrl: \"\",
							  metaLogoPNG: \"\",
							  \"===\": \"--- DO NOT EDIT BELOW THIS LINE !!! ---\",
			        			  minted: \"0\",
                                                          name: \"${assetTmpName}\",
                                                          hexname: \"${assetHexName}\",
                                                          bechName: \"${assetNameBech}\",
                                                          policyID: \"${policyID}\",
                                                          policyValidBeforeSlot: \"${ttlFromScript}\",
                                                          subject: \"${assetSubject}\",
							  sequenceNumber: \"0\",
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

#Asset-File exists, lets read out the parameters and save them back in the order shown above
#so we have a better editing format in there

#Build Skeleton, all available entries in the real assetFileJSON will overwrite the skeleton entries
assetFileSkeletonJSON=$(jq ". += {metaName: \"${assetName}\",
                                  metaDescription: \"\",
                                  \"---\": \"--- Optional additional info ---\",
                                  metaDecimals: \"0\",
                                  metaTicker: \"\",
                                  metaUrl: \"\",
                                  metaLogoPNG: \"\",
                                  \"===\": \"--- DO NOT EDIT BELOW THIS LINE !!! ---\",
                                  minted: \"0\",
                                  name: \"${assetName}\",
				  hexname: \"\",
                                  bechName: \"${assetNameBech}\",
                                  policyID: \"${policyID}\",
                                  policyValidBeforeSlot: \"${ttlFromScript}\",
                                  subject: \"${assetSubject}\",
				  sequenceNumber: \"0\",
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
sequenceNumber=$(jq -r ".sequenceNumber" <<< ${assetFileJSON})
newSequenceNumber=$(( ${sequenceNumber} + 1 ))

echo -e "\e[0mGenerating Token-Registry-JSON for sequenceNumber ${newSequenceNumber}:\e[32m ${assetSubject}.json \e[0m\n"

creatorArray=("entry" "${assetSubject}" "--init")

#Check metaName
echo -ne "Adding 'metaName'        ... "
metaName=$(jq -r ".metaName" <<< ${assetFileJSON})
#if [[ ! "${metaName//[[:space:]]}" == "${metaName}" ]]; then echo -e "\e[35mERROR - The metaName '${metaName}' contains spaces, not allowed !\e[0m\n"; exit 1; fi
if [[ ${#metaName} -lt 1 || ${#metaName} -gt 50 ]]; then echo -e "\e[35mERROR - The metaName '${metaName}' is missing or too long. Max. 50chars allowed !\e[0m\n"; exit 1; fi
creatorArray+=("--name" "${metaName}")
echo -e "\e[32mOK\e[0m"


#Check metaDescription
echo -ne "Adding 'metaDescription' ... "
metaDescription=$(jq -r ".metaDescription" <<< ${assetFileJSON})
if [[ ${#metaDescription} -lt 1 || ${#metaDescription} -gt 500 ]]; then echo -e "\e[35mERROR - The metaDescription is too short or too long. Min. 1char, Max. 500chars allowed !\e[0m\n"; exit 1; fi
creatorArray+=("--description" "${metaDescription}")
echo -e "\e[32mOK\e[0m"


#Add policy script
echo -ne "Adding 'policyScript'    ... "
creatorArray+=("--policy" "${policyName}.policy.script")
echo -e "\e[32mOK\e[0m"


#Check metaTicker - optional
metaTicker=$(jq -r ".metaTicker" <<< ${assetFileJSON})
if [[ ! "${metaTicker}" == "" ]]; then
echo -ne "Adding 'metaTicker'      ... "
	#if [[ ! "${metaTicker//[[:space:]]}" == "${metaTicker}" ]]; then echo -e "\e[35mERROR - The metaTicker '${metaTicker}' contains spaces, not allowed !\e[0m\n"; exit 1; fi
	if [[ ${#metaTicker} -lt 3 || ${#metaTicker} -gt 9 ]]; then echo -e "\e[35mERROR - The metaTicker '${metaTicker}' must be between 3-9 chars!\e[0m\n"; exit 1; fi
	creatorArray+=("--ticker" "${metaTicker}")
	echo -e "\e[32mOK\e[0m"
fi


#Check metaUrl - optional
metaUrl=$(jq -r ".metaUrl" <<< ${assetFileJSON})
if [[ ! "${metaUrl}" == "" ]]; then
	echo -ne "Adding 'metaUrl'         ... "
	if [[ ! "${metaUrl}" =~ https://.* || ${#metaUrl} -gt 250 ]]; then echo -e "\e[35mERROR - The metaUrl has an invalid URL format (must be starting with https://) or is too long. Max. 250 chars allowed !\e[0m\n"; exit 1; fi
	creatorArray+=("--url" "${metaUrl}")
	echo -e "\e[32mOK\e[0m"
fi


#Check metaDecimals - optional
metaDecimals=$(jq -r ".metaDecimals" <<< ${assetFileJSON})
if [[ ${metaDecimals} != "" ]] && [ ! -z "${metaDecimals##*[!0-9]*}" ] && [ ${metaDecimals} -ge 0 ]; then #if a number and greater/equal to zero
	echo -ne "Adding 'metaDecimals'    ... "
	if [[ ${metaDecimals} -gt 255 ]]; then echo -e "\e[35mERROR - The metaDecimals '${metaDecimals}' is too big. Max. value is 255 decimals !\e[0m\n"; exit 1; fi
	creatorArray+=("--decimals" "${metaDecimals}")
	echo -e "\e[32mOK\e[0m"

elif [[ ${metaDecimals} != "" ]] && [ -z "${metaDecimals##*[!0-9]*}" ]; then #if not a number, show an errormessage
	 echo -e "\e[35mERROR - The metaDecimals '${metaDecimals}' is not a number. The value range is 0 to 255 or empty!\e[0m\n"; exit 1;
fi


#Check metaPNG - optional
metaLogoPNG=$(jq -r ".metaLogoPNG" <<< ${assetFileJSON})
if [[ ! "${metaLogoPNG}" == "" ]]; then
	echo -ne "Adding 'metaLogoPNG'     ... "
	if [ ! -f "${metaLogoPNG}" ]; then echo -e "\e[35mERROR - The metaLogoPNG '${metaLogoPNG}' file was not found !\e[0m\n"; exit 1; fi
	if [[ $(file -b "${metaLogoPNG}" | grep "PNG" | wc -l) -eq 0 ]]; then echo -e "\e[35mERROR - The metaLogoPNG '${metaLogoPNG}' is not a valid PNG image file !\e[0m\n"; exit 1; fi
	creatorArray+=("--logo" "${metaLogoPNG}")
	echo -e "\e[32mOK\e[0m"
fi

echo

#Execute the file generation and add all the parameters
echo -ne "Create JSON draft and adding parameters ... "
#tmp=$(/bin/bash -c "${cardanometa} ${creatorArray}")
tmp=$(${cardanometa} "${creatorArray[@]}")
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
echo -e "\e[32mOK\e[90m (${tmp})\e[0m"

#Update the sequenceNumber to the next higher value
echo -ne "Update sequenceNumber to ${newSequenceNumber} ... "
sed -i "s/\"sequenceNumber\":\ .*,/\"sequenceNumber\":\ ${newSequenceNumber},/g" ${tmp}
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
echo -e "\e[32mOK\e[0m"

#Sign the metadata registry submission json draft file
echo -ne "Signing with '${policyName}.policy.skey' ... "
tmp=$(${cardanometa} entry ${assetSubject} -a "${policyName}.policy.skey")
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
echo -e "\e[32mOK\e[0m"

#Finanlize the metadata registry submission json draft file
echo -ne "Finalizing the draft file ... "
tmp=$(${cardanometa} entry ${assetSubject} --finalize)
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
echo -e "\e[32mOK\e[90m (${tmp})\e[0m"
metaFile=${tmp}

#Validating the metadata registry submission json file
echo -ne "Validating the final file ... "
tmp=$(${cardanometa} validate ${metaFile})
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
echo -e "\e[32mOK\e[0m"

assetFileJSON=$(cat ${assetFileName})
assetFileJSON=$(jq ". += {sequenceNumber: \"${newSequenceNumber}\", lastUpdate: \"$(date -R)\", lastAction: \"created Token-Registry-JSON\"}" <<< ${assetFileJSON})
file_unlock ${assetFileName}
echo -e "${assetFileJSON}" > ${assetFileName}
file_lock ${assetFileName}


#Moving Submitter JSON into the same directory as the assetFile
assetDir=$(dirname ${assetFileName})
if [[ ! "${assetDir}" == "." ]]; then
	echo -ne "Moving final JSON into '${assetDir}' Directory ... "
	mv "${metaFile}" "${assetDir}"
	checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
	echo -e "\e[32mOK\e[0m"
fi

assetFileLocation="${assetDir}/${assetSubject}.json"; assetFileLocation=${assetFileLocation/#.\//}

echo
echo -e "\e[33mYour Token-Registry-JSON File is now ready to be submitted to: \e[32mhttps://github.com/cardano-foundation/cardano-token-registry"
echo -e "\e[33mas a Pull-Request...\n\nYou can find your file here: \e[32m${assetFileLocation}\e[0m";

echo -e "\e[0m\n"



