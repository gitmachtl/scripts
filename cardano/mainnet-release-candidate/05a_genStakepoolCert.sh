#!/bin/bash

# Script is brought to you by ATADA_Stakepool, Telegram @atada_stakepool

#load variables from common.sh
#       socket          Path to the node.socket (also exports socket to CARDANO_NODE_SOCKET_PATH)
#       genesisfile     Path to the genesis.json
#       magicparam      TestnetMagic parameter
#       cardanocli      Path to the cardano-cli executable
#       cardanonode     Path to the cardano-node executable
. "$(dirname "$0")"/00_common.sh

if [[ $# -eq 1 && ! $1 == "" ]]; then poolFile=$1; else echo "ERROR - Usage: $(basename $0) <PoolNodeName> (pointing to the PoolNodeName.pool.json file)"; exit 1; fi

#Check if json file exists
if [ ! -f "${poolFile}.pool.json" ]; then echo -e "\n\e[33mERROR - \"${poolFile}.pool.json\" does not exist, a dummy one was created, please edit it and retry.\e[0m";
#Generate Dummy JSON File
echo "
{
  \"poolName\": \"${poolFile}\",
  \"poolOwner\": [
    {
    \"ownerName\": \"set_your_owner_name_here\"
    }
  ],
  \"poolRewards\": \"set_your_rewards_name_here_can_be_same_as_owner\",
  \"poolPledge\": \"100000000000\",
  \"poolCost\": \"10000000000\",
  \"poolMargin\": \"0.10\",
  \"poolRelays\": [
    {
      \"relayType\": \"ip or dns\",
      \"relayEntry\": \"x.x.x.x_or_the_dns-name_of_your_relay\",
      \"relayPort\": \"3001\"
    }
  ],
  \"poolMetaName\": \"THE NAME OF YOUR POOL\",
  \"poolMetaDescription\": \"THE DESCRIPTION OF YOUR POOL\",
  \"poolMetaTicker\": \"THE TICKER OF YOUR POOL\",
  \"poolMetaHomepage\": \"https://set_your_webserver_url_here\",
  \"poolMetaUrl\": \"https://set_your_webserver_url_here/$(basename ${poolFile}).metadata.json\",
  \"---\": \"--- DO NOT EDIT BELOW THIS LINE ---\"
}
" > ${poolFile}.pool.json
echo
echo -e "\e[0mStakepool Info JSON:\e[32m ${poolFile}.pool.json \e[90m"
cat ${poolFile}.pool.json
echo
echo -e "\e[0m"
exit 1; fi


#Small subroutine to read the value of the JSON and output an error is parameter is empty/missing
function readJSONparam() {
param=$(jq -r .$1 ${poolFile}.pool.json 2> /dev/null)
if [[ $? -ne 0 ]]; then echo "ERROR - ${poolFile}.pool.json is not a valid JSON file" >&2; exit 1;
elif [[ "${param}" == null ]]; then echo "ERROR - Parameter \"$1\" in ${poolFile}.pool.json does not exist" >&2; exit 1;
elif [[ "${param}" == "" ]]; then echo "ERROR - Parameter \"$1\" in ${poolFile}.pool.json is empty" >&2; exit 1;
fi
echo "${param}"
}

#Read the pool JSON file and extract the parameters -> report an error is something is missing or wrong/empty
poolName=$(readJSONparam "poolName"); if [[ ! $? == 0 ]]; then exit 1; fi
poolOwner=$(readJSONparam "poolOwner"); if [[ ! $? == 0 ]]; then exit 1; fi
rewardsName=$(readJSONparam "poolRewards"); if [[ ! $? == 0 ]]; then exit 1; fi
poolPledge=$(readJSONparam "poolPledge"); if [[ ! $? == 0 ]]; then exit 1; fi
poolCost=$(readJSONparam "poolCost"); if [[ ! $? == 0 ]]; then exit 1; fi
poolMargin=$(readJSONparam "poolMargin"); if [[ ! $? == 0 ]]; then exit 1; fi


#Check poolCost Setting
${cardanocli} shelley query protocol-parameters --cardano-mode ${magicparam} > protocol-parameters.json
checkError "$?"
minPoolCost=$(cat protocol-parameters.json | jq -r .minPoolCost)
if [[ ${poolCost} -lt ${minPoolCost} ]]; then #If poolCost is set to low, than ask for an automatic change
                echo
                if ask "\e[33mYour poolCost (${poolCost} lovelaces) is lower than the minPoolCost (${minPoolCost} lovelaces). Do you wanna change it to that ?\e[0m" N; then
			poolCost=${minPoolCost}
                        file_unlock ${poolFile}.pool.json       #update the ticker in the json itself to the new one too
                        newJSON=$(cat ${poolFile}.pool.json | jq ". += {poolCost: \"${poolCost}\"}")
                        echo "${newJSON}" > ${poolFile}.pool.json
                else
                        echo
                        echo "Please re-edit the poolCost entry in your ${poolFile}.pool.json, thx."
                        echo
                        exit 1
                fi
        fi

#Check PoolRelay Entries
tmp=$(readJSONparam "poolRelays"); if [[ ! $? == 0 ]]; then exit 1; fi
poolRelayCnt=$(jq -r '.poolRelays | length' ${poolFile}.pool.json)
poolRelays=""	#building string for the certificate
for (( tmpCnt=0; tmpCnt<${poolRelayCnt}; tmpCnt++ ))
do
  poolRelayEntryContent=$(jq -r .poolRelays[${tmpCnt}].relayEntry ${poolFile}.pool.json 2> /dev/null);
  if [[ "${poolRelayEntryContent}" == null || "${poolRelayEntryContent}" == "" ]]; then echo "ERROR - Parameter \"relayEntry\" in ${poolFile}.pool.json poolRelays-Array does not exist or is empty!"; exit 1;
  elif [[ "${#poolRelayEntryContent}" -gt 64 ]]; then echo -e "\e[0mERROR - The relayEntry parameter with content \"${poolRelayEntryContent}\" in your ${poolFile}.pool.json is too long. Max. 64chars allowed !\e[0m"; exit 1; fi

  #Load relay port data, verify later depending on the need (multihost does not need a port)
  poolRelayEntryPort=$(jq -r .poolRelays[${tmpCnt}].relayPort ${poolFile}.pool.json 2> /dev/null);
  poolRelayEntryType=$(jq -r .poolRelays[${tmpCnt}].relayType ${poolFile}.pool.json 2> /dev/null);
  if [[ "${poolRelayEntryType}" == null || "${poolRelayEntryType}" == "" ]]; then echo "ERROR - Parameter \"relayType\" in ${poolFile}.pool.json poolRelays-Array does not exist or is empty!"; exit 1; fi

  #Build relaystring depending on relaytype
  poolRelayEntryType=${poolRelayEntryType^^}  #convert to uppercase
  case ${poolRelayEntryType} in
  IP|IP4|IPV4)  #generate an IPv4 relay entry
	if [[ "${poolRelayEntryPort}" == null || "${poolRelayEntryPort}" == "" ]]; then echo "ERROR - Parameter \"relayPort\" in ${poolFile}.pool.json poolRelays-Array does not exist or is empty!"; exit 1; fi
	poolRelays="${poolRelays} --pool-relay-ipv4 ${poolRelayEntryContent} --pool-relay-port ${poolRelayEntryPort}";;

  IP6|IPV6)  #generate an IPv6 relay entry
	if [[ "${poolRelayEntryPort}" == null || "${poolRelayEntryPort}" == "" ]]; then echo "ERROR - Parameter \"relayPort\" in ${poolFile}.pool.json poolRelays-Array does not exist or is empty!"; exit 1; fi
	poolRelays="${poolRelays} --pool-relay-ipv6 ${poolRelayEntryContent} --pool-relay-port ${poolRelayEntryPort}";;

  DNS) #generate a dns single-relay A or AAAA entry
	if [[ "${poolRelayEntryPort}" == null || "${poolRelayEntryPort}" == "" ]]; then echo "ERROR - Parameter \"relayPort\" in ${poolFile}.pool.json poolRelays-Array does not exist or is empty!"; exit 1; fi
	poolRelays="${poolRelays} --single-host-pool-relay ${poolRelayEntryContent} --pool-relay-port ${poolRelayEntryPort}";;

  MULTISRV) #generate a dns SRV multi-relay entry
	#No port needed
        poolRelays="${poolRelays} --multi-host-pool-relay ${poolRelayEntryContent}";;

  * ) #unkown relay type
      echo "ERROR - The relayType parameter in ${poolFile}.pool.json with content \"${poolRelayEntryType}\" is unknown. Only \"IP/IP4/IPv4\", \"IP6/IPv6\", \"DNS\" or , \"MULTISRV\" is supported!"; exit 1;;
  esac
done


#Check PoolMetadata Entries
poolMetaNameOrig=$(readJSONparam "poolMetaName"); if [[ ! $? == 0 ]]; then exit 1; fi
	poolMetaName=${poolMetaNameOrig//[^[:alnum:][:space:]]/}   #Filter out forbidden chars and replace with _
	poolMetaName=$(trimString "${poolMetaName}")
       	if [[ ! "${poolMetaName}" == "${poolMetaNameOrig}" ]]; then #If corrected name is different than to the one in the pool.json file, ask if it is ok to use the new one
                echo
                if ask "\e[33mYour poolMetaName was corrected from '${poolMetaNameOrig}' to '${poolMetaName}' to fit the rules! Are you ok with this ?\e[0m" N; then
                        file_unlock ${poolFile}.pool.json       #update the name in the json itself to the new one too
                        newJSON=$(cat ${poolFile}.pool.json | jq ". += {poolMetaName: \"${poolMetaName}\"}")
                        echo "${newJSON}" > ${poolFile}.pool.json
                else
                        echo
                        echo "Please re-edit the poolMetaTicker entry in your ${poolFile}.pool.json, thx."
                        echo
                        exit 1
                fi
        fi

poolMetaTickerOrig=$(readJSONparam "poolMetaTicker"); if [[ ! $? == 0 ]]; then exit 1; fi
	poolMetaTicker=${poolMetaTickerOrig//[^[:alnum:]]/_}   #Filter out forbidden chars and replace with _
	poolMetaTicker=${poolMetaTicker^^} #convert to uppercase
	if [[ "${#poolMetaTicker}" -lt 3 || "${#poolMetaTicker}" -gt 5 ]]; then echo -e "\e[35mERROR - The poolMetaTicker Entry must be between 3-5 chars long !\e[0m"; exit 1; fi
	if [[ ! "${poolMetaTicker}" == "${poolMetaTickerOrig}" ]]; then #If corrected ticker is different than to the one in the pool.json file, ask if it is ok to use the new one
		echo
		if ask "\e[33mYour poolMetaTicker was corrected from '${poolMetaTickerOrig}' to '${poolMetaTicker}' to fit the rules! Are you ok with this ?\e[0m" N; then
			file_unlock ${poolFile}.pool.json	#update the ticker in the json itself to the new one too
			newJSON=$(cat ${poolFile}.pool.json | jq ". += {poolMetaTicker: \"${poolMetaTicker}\"}")
		        echo "${newJSON}" > ${poolFile}.pool.json
                else
			echo
			echo "Please re-edit the poolMetaTicker entry in your ${poolFile}.pool.json, thx."
			echo
			exit 1
		fi
        fi

poolMetaHomepage=$(readJSONparam "poolMetaHomepage"); if [[ ! $? == 0 ]]; then exit 1; fi
if [[ ! "${poolMetaHomepage}" =~ https?://.* || ${#poolMetaHomepage} -gt 64 ]]; then echo -e "\e[35mERROR - The poolMetaHomepage entry in your ${poolFile}.pool.json has an invalid URL format or is too long. Max. 64chars allowed !\e[0m\n\nPlease re-edit the poolMetaHomepage entry in your ${poolFile}.pool.json, thx."; exit 1; fi

poolMetaUrl=$(readJSONparam "poolMetaUrl"); if [[ ! $? == 0 ]]; then exit 1; fi
if [[ ! "${poolMetaUrl}" =~ https?://.* || ${#poolMetaUrl} -gt 64 ]]; then echo -e "\e[35mERROR - The poolMetaUrl entry in your ${poolFile}.pool.json has an invalid URL format or is too long. Max. 64chars allowed !\e[0m\n\nPlease re-edit the poolMetaUrl entry in your ${poolFile}.pool.json, thx."; exit 1; fi

poolMetaDescription=$(readJSONparam "poolMetaDescription"); if [[ ! $? == 0 ]]; then exit 1; fi


#Generate new <poolFile>.metadata.json File with the Entries and also read out the Hash of it
file_unlock ${poolFile}.metadata.json
#Generate Dummy JSON File
echo "{
  \"name\": \"${poolMetaName}\",
  \"description\": \"${poolMetaDescription}\",
  \"ticker\": \"${poolMetaTicker}\",
  \"homepage\": \"${poolMetaHomepage}\"
}" > ${poolFile}.metadata.json
chmod 444 ${poolFile}.metadata.json #Set it to 444, because it is public anyway so it can be copied over to a websever via scp too

#Generate HASH for the <poolFile>.metadata.json
poolMetaHash=$(${cardanocli} shelley stake-pool metadata-hash --pool-metadata-file ${poolFile}.metadata.json)
checkError "$?"

#Add the HASH to the <poolFile>.pool.json info file
file_unlock ${poolFile}.pool.json
newJSON=$(cat ${poolFile}.pool.json | jq ". += {poolMetaHash: \"${poolMetaHash}\"}")
echo "${newJSON}" > ${poolFile}.pool.json
file_lock ${poolFile}.pool.json


#Check if JSON file is a single owner (old) format than update the JSON with owner array and single owner
ownerType=$(jq -r '.poolOwner | type' ${poolFile}.pool.json)
if [[ "${ownerType}" == "string" ]]; then
        file_unlock ${poolFile}.pool.json
	newJSON=$(cat ${poolFile}.pool.json | jq ". += {poolOwner: [{\"ownerName\": \"${poolOwner}\"}]}")
	echo "${newJSON}" > ${poolFile}.pool.json	file_lock ${poolFile}.pool.json
	ownerCnt=1  #of course it is 1, we just converted a singleowner json into an arrayowner json
else #already an array, so check the number of owners in there
	ownerCnt=$(jq -r '.poolOwner | length' ${poolFile}.pool.json)
fi


ownerKeys="" #building string for the certificate

#Check needed inputfiles
if [ ! -f "${poolName}.node.vkey" ]; then echo -e "\e[0mERROR - ${poolName}.node.vkey is missing, please generate it with script 04a !\e[0m"; exit 1; fi
if [ ! -f "${poolName}.vrf.vkey" ]; then echo -e "\e[0mERROR - ${poolName}.vrf.vkey is missing, please generate it with script 04b !\e[0m"; exit 1; fi
if [ ! -f "${rewardsName}.staking.vkey" ]; then echo -e "\e[0mERROR - ${rewardsName}.staking.vkey is missing! Check poolRewards field in ${poolFile}.pool.json, or generate one with script 03a !\e[0m"; exit 1; fi
for (( tmpCnt=0; tmpCnt<${ownerCnt}; tmpCnt++ ))
do
  ownerName=$(jq -r .poolOwner[${tmpCnt}].ownerName ${poolFile}.pool.json)
  if [ ! -f "${ownerName}.staking.vkey" ]; then echo -e "\e[0mERROR - ${ownerName}.staking.vkey is missing! Check poolOwner/ownerName field in ${poolFile}.pool.json, or generate one with script 03a !\e[0m"; exit 1; fi
  #When we are in the loop, just build up also all the needed ownerkeys for the certificate
  ownerKeys="${ownerKeys} --pool-owner-stake-verification-key-file ${ownerName}.staking.vkey"
done
#OK, all needed files are present, continue



#Now, show the summary
echo
echo -e "\e[0mCreate a Stakepool registration certificate for PoolNode with \e[32m ${poolName}.node.vkey, ${poolName}.vrf.vkey\e[0m:"
echo
echo -e "\e[0mOwner Stake Keys:\e[32m ${ownerCnt}\e[0m owner(s) with the key(s)"
for (( tmpCnt=0; tmpCnt<${ownerCnt}; tmpCnt++ ))
do
  ownerName=$(jq -r .poolOwner[${tmpCnt}].ownerName ${poolFile}.pool.json)
  echo -e "\e[0m                 \e[32m ${ownerName}.staking.vkey \e[0m"
done
echo -e "\e[0m   Rewards Stake:\e[32m ${rewardsName}.staking.vkey \e[0m"
echo -e "\e[0m          Pledge:\e[32m ${poolPledge} \e[90mlovelaces"
echo -e "\e[0m            Cost:\e[32m ${poolCost} \e[90mlovelaces"
echo -e "\e[0m          Margin:\e[32m ${poolMargin} \e[0m"
echo
echo -e "\e[0mStakepool Metadata JSON:\e[32m ${poolFile}.metadata.json \e[90m"
cat ${poolFile}.metadata.json
echo

#Usage: cardano-cli shelley stake-pool registration-certificate --cold-verification-key-file FILE
#                                                              --vrf-verification-key-file FILE
#                                                               --pool-pledge LOVELACE
#                                                               --pool-cost LOVELACE
#                                                               --pool-margin DOUBLE
#                                                               --pool-reward-account-verification-key-file FILE
#                                                               --pool-owner-stake-verification-key-file FILE
#                                                               [--pool-relay-port INT
#                                                                 [--pool-relay-ipv4 STRING]
#                                                                 [--pool-relay-ipv6 STRING] |
#
#                                                                 [--pool-relay-port INT]
#                                                                 --single-host-pool-relay STRING |
#
#                                                                 --multi-host-pool-relay STRING]
#                                                               [--metadata-url URL
#                                                                 --metadata-hash HASH]
#                                                               (--mainnet |
#                                                                 --testnet-magic NATURAL)
#                                                               --out-file FILE
#  Create a stake pool registration certificate



file_unlock ${poolName}.pool.cert
${cardanocli} shelley stake-pool registration-certificate --cold-verification-key-file ${poolName}.node.vkey --vrf-verification-key-file ${poolName}.vrf.vkey --pool-pledge ${poolPledge} --pool-cost ${poolCost} --pool-margin ${poolMargin} --pool-reward-account-verification-key-file ${rewardsName}.staking.vkey ${ownerKeys} ${poolRelays} --metadata-url ${poolMetaUrl} --metadata-hash ${poolMetaHash} ${magicparam} --out-file ${poolName}.pool.cert
checkError "$?"

#No error, so lets update the pool JSON file with the date and file the certFile was created
if [[ $? -eq 0 ]]; then
	file_unlock ${poolFile}.pool.json
	newJSON=$(cat ${poolFile}.pool.json | jq ". += {regCertCreated: \"$(date -R)\"}" | jq ". += {regCertFile: \"${poolName}.pool.cert\"}")
	echo "${newJSON}" > ${poolFile}.pool.json
        file_lock ${poolFile}.pool.json
fi

file_lock ${poolName}.pool.cert

echo
echo -e "\e[0mStakepool registration certificate:\e[32m ${poolName}.pool.cert \e[90m"
cat ${poolName}.pool.cert
echo

echo
echo -e "\e[0mStakepool Info JSON:\e[32m ${poolFile}.pool.json \e[90m"
cat ${poolFile}.pool.json
echo

echo -e "\e[35mDon't forget to upload your \e[32m${poolFile}.metadata.json\e[35m file now to your webserver!"

echo -e "\e[0m"
