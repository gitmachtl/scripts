#!/bin/bash

# Script is brought to you by ATADA_Stakepool, Telegram @atada_stakepool

#load variables from common.sh
#       socket          Path to the node.socket (also exports socket to CARDANO_NODE_SOCKET_PATH)
#       genesisfile     Path to the genesis.json
#       magicparam      TestnetMagic parameter
#       cardanocli      Path to the cardano-cli executable
#       cardanonode     Path to the cardano-node executable
. "$(dirname "$0")"/00_common.sh

#Check can only be done in online mode
if ${offlineMode}; then echo -e "\e[35mYou have to be in ONLINE MODE to do this!\e[0m\n"; exit 1; fi

case $# in

  1 ) param1=${1,,}; #get the lowercase version
      policyName="$(echo $1 | cut -d. -f 1)";
      assetName="$(echo $1 | cut -d. -f 2-)"; assetName=$(basename "${assetName}" .asset); #assetName=${assetName//./};
      ;;

  * ) cat >&2 <<EOF
Usage:  $(basename $0) <PolicyName.AssetName OR assetSubject(HexCode)>

EOF
  exit 1;; esac

#Check assetName
if [[ "${assetName}" == ".asset" ]]; then assetName=""; fi
assetFileName="${policyName}.${assetName}.asset"

#Check if the assetFile exists, if yes, read out the parameters. Otherwise check if the provided parameter is a subject(policyID|assetName) hex string
if [ -f "${assetFileName}" ]; then
				#Read in the current file
				assetFileJSON=$(cat ${assetFileName})
				assetSubject=$(jq -r ".subject" <<< ${assetFileJSON}); checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
				if [[ "${assetSubject//[![:xdigit:]]}" == "${assetSubject}" && ${#assetSubject} -ge 56 && ${#assetSubject} -le 120 ]]; then
		         		echo -e "\e[0mUsing local Asset-File: \e[32m ${assetFileName} \e[90m\n"
	                                cat ${assetFileName}
	                                echo -e "\e[0m\n"
				else
					echo -e "\e[35mError - Not a valid assetSubject (subject) Entry found in the assetFile. Please try to run script 12a before !\e[0m\n"; exit 1;
				fi

elif [[ "${param1//[![:xdigit:]]}" == "${param1}" && ${#param1} -ge 56 && ${#param1} -le 120 ]]; then
				assetSubject="${param1}" #use parameter 1 as assetSubject
else #Display an ErrorMessage if neither assetFile or directSubjectHexCode is working
 echo -e "\e[35mError - The provided parameter is not a valid assetFile (wrong path?), also it is not a valid HexCode for a direct Subject-Request!\e[0m\n"; exit 1;
fi


#Checking Mainnet or Testnet Metadata Registry Server
if [[ "${magicparam}" == *"mainnet"* ]]; then
					  echo -e "\e[0mChecking Mainnet-Token-Registry for Asset-Subject: \e[32m${assetSubject}\e[0m\n"
					  metaResponse=$(curl -sL "https://tokens.cardano.org/metadata/${assetSubject}")
					 else
					  echo -e "\e[0mChecking \e[33mTestnet-\e[0mToken-Registry for Asset-Subject: \e[32m${assetSubject}\e[0m\n"
					  metaResponse=$(curl -sL "https://metadata.cardano-testnet.iohkdev.io/metadata/${assetSubject}")
fi

echo -ne "\e[0mServer Response: "

#Display Error-Message is no valid JSON returned
tmp=$(jq . 2> /dev/null <<< ${metaResponse} )
if [ $? -ne 0 ]; then
			echo -e "\e[35mInvalid JSON\n\n${metaResponse}\e[0m\n"; exit 1
		 else
			echo -e "\e[32mValid JSON\e[0m";
fi

echo
echo -ne "\e[90m           Name: \e[32m"; ret=$(jq -r ".name.value | select (.!=null)" 2> /dev/null <<< ${metaResponse}); echo -e "${ret}\e[0m"
echo -ne "\e[90m    Description: \e[32m"; ret=$(jq -r ".description.value | select (.!=null)" 2> /dev/null <<< ${metaResponse}); echo -e "${ret}\e[0m"
echo -ne "\e[90m         Ticker: \e[32m"; ret=$(jq -r ".ticker.value | select (.!=null)" 2> /dev/null <<< ${metaResponse}); echo -e "${ret}\e[0m"
echo -ne "\e[90m            Url: \e[32m"; ret=$(jq -r ".url.value | select (.!=null)" 2> /dev/null <<< ${metaResponse}); echo -e "${ret}\e[0m"
echo -ne "\e[90m    SubUnitName: \e[32m"; ret=$(jq -r ".unit.value.name | select (.!=null)" 2> /dev/null <<< ${metaResponse}); echo -e "${ret}\e[0m"
echo -ne "\e[90m SubUnitDecimal: \e[32m"; ret=$(jq -r ".unit.value.decimals | select (.!=null)" 2> /dev/null <<< ${metaResponse}); echo -e "${ret}\e[0m"

echo -ne "\e[90m        LogoPNG: \e[32m"; ret=$(jq -r ".logo.value" 2> /dev/null <<< ${metaResponse});
	if [[ ! "${ret}" == null ]]; then
					tmpPNG="${tempDir}/tmp.png"
					base64 --decode <(echo "${ret}") 2> /dev/null > ${tmpPNG}
					echo -e "present with $(du -b ${tmpPNG} | cut -f1) bytes \e[90m(downloaded to ${tmpPNG})\e[0m";
				     else
					echo -e "\e[0m";
	fi

echo



