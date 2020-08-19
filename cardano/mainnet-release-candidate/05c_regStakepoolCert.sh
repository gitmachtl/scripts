#!/bin/bash

# Script is brought to you by ATADA_Stakepool, Telegram @atada_stakepool

#load variables from common.sh
#       socket          Path to the node.socket (also exports socket to CARDANO_NODE_SOCKET_PATH)
#       genesisfile     Path to the genesis.json
#       magicparam      TestnetMagic parameter
#       cardanocli      Path to the cardano-cli executable
#       cardanonode     Path to the cardano-node executable
. "$(dirname "$0")"/00_common.sh

#Check command line parameter
case $# in
  2|3) regPayName="$2";
      poolFile="$1";;
  * ) cat >&2 <<EOF
ERROR - Usage: $(basename $0) <PoolNodeName> <PaymentAddrForRegistration> [optional keyword REG to force a registration, REREG to force a re-registration]
EOF
  exit 1;; esac

#Check if referenced JSON file exists
if [ ! -f "${poolFile}.pool.json" ]; then echo -e "\n\e[35mERROR - ${poolFile}.pool.json does not exist! Please create it first with script 05a.\e[0m"; exit 1; fi

#Small subroutine to read the value of the JSON and output an error if parameter is empty/missing
function readJSONparam() {
param=$(jq -r .$1 ${poolFile}.pool.json 2> /dev/null)
if [[ $? -ne 0 ]]; then echo "ERROR - ${poolFile}.pool.json is not a valid JSON file" >&2; exit 1;
elif [[ "${param}" == null ]]; then echo "ERROR - Parameter \"$1\" in ${poolFile}.pool.json does not exist" >&2; exit 1;
elif [[ "${param}" == "" ]]; then echo "ERROR - Parameter \"$1\" in ${poolFile}.pool.json is empty" >&2; exit 1;
fi
echo "${param}"
}

#Read the pool JSON file and extract the parameters -> report an error is something is missing or wrong/empty and exit
poolName=$(readJSONparam "poolName"); if [[ ! $? == 0 ]]; then exit 1; fi
ownerName=$(readJSONparam "poolOwner"); if [[ ! $? == 0 ]]; then exit 1; fi
rewardsName=$(readJSONparam "poolRewards"); if [[ ! $? == 0 ]]; then exit 1; fi
poolPledge=$(readJSONparam "poolPledge"); if [[ ! $? == 0 ]]; then exit 1; fi
poolCost=$(readJSONparam "poolCost"); if [[ ! $? == 0 ]]; then exit 1; fi
poolMargin=$(readJSONparam "poolMargin"); if [[ ! $? == 0 ]]; then exit 1; fi
regCertFile=$(readJSONparam "regCertFile"); if [[ ! $? == 0 ]]; then exit 1; fi
poolMetaUrl=$(readJSONparam "poolMetaUrl"); if [[ ! $? == 0 ]]; then exit 1; fi
poolMetaHash=$(readJSONparam "poolMetaHash"); if [[ ! $? == 0 ]]; then exit 1; fi


#Load regSubmitted value from the pool.json. If there is an entry, than do a Re-Registration (changes the Fee!)
regSubmitted=$(jq -r .regSubmitted ${poolFile}.pool.json 2> /dev/null)
if [[ "${regSubmitted}" == null ]]; then regSubmitted=""; fi

#Force registration instead of re-registration via optional command line command "force"
if [[ $# -eq 3 ]]; then forceParam=$3; fi
if [[ ${forceParam^^} == "REG" ]]; then regSubmitted="";  	#force a new registration
elif [[ ${forceParam^^} == "REREG" ]]; then regSubmitted="xxx";	#force a re-registration
fi

#Checks for needed files
if [ ! -f "${regCertFile}" ]; then echo -e "\n\e[35mERROR - \"${regCertFile}\" does not exist! Please create it first with script 05a.\e[0m"; exit 1; fi
if [ ! -f "${rewardsName}.staking.skey" ]; then echo -e "\n\e[35mERROR - \"${rewardsName}.staking.skey\" does not exist! Please create it first with script 03a.\e[0m"; exit 1; fi
if [ ! -f "${poolName}.node.skey" ]; then echo -e "\n\e[35mERROR - \"${poolName}.node.skey\" does not exist! Please create it first with script 04a.\e[0m"; exit 1; fi
if [ ! -f "${poolName}.node.vkey" ]; then echo -e "\n\e[35mERROR - \"${poolName}.node.vkey\" does not exist! Please create it first with script 04a.\e[0m"; exit 1; fi
if [ ! -f "${regPayName}.addr" ]; then echo -e "\n\e[35mERROR - \"${regPayName}.addr\" does not exist! Please create it first with script 03a.\e[0m"; exit 1; fi
if [ ! -f "${regPayName}.skey" ]; then echo -e "\n\e[35mERROR - \"${regPayName}.skey\" does not exist! Please create it first with script 03a.\e[0m"; exit 1; fi

ownerCnt=$(jq -r '.poolOwner | length' ${poolFile}.pool.json)
certCnt=$(( ${ownerCnt} + 1 ))
signingKeys="--signing-key-file ${regPayName}.skey --signing-key-file ${poolName}.node.skey"
witnessCount=2
registrationCerts="--certificate ${regCertFile}"
rewardsAccountIncluded="no"
for (( tmpCnt=0; tmpCnt<${ownerCnt}; tmpCnt++ ))
do
  ownerName=$(jq -r .poolOwner[${tmpCnt}].ownerName ${poolFile}.pool.json)
  if [ ! -f "${ownerName}.staking.skey" ]; then echo -e "\e[35mERROR - ${ownerName}.staking.skey is missing, please generate it with script 03a !\e[0m"; exit 1; fi
  if [ ! -f "${ownerName}.deleg.cert" ]; then echo -e "e[35mERROR - \"${ownerName}.deleg.cert\" does not exist! Please create it first with script 05b.\e[0m"; exit 1; fi
  #When we are in the loop, just build up also all the needed signingkeys & certificates for the transaction
  signingKeys="${signingKeys} --signing-key-file ${ownerName}.staking.skey"
  witnessCount=$(( ${witnessCount} + 1 ))
  registrationCerts="${registrationCerts} --certificate ${ownerName}.deleg.cert"
  #Also check, if the ownername is the same as the one in the rewards account, if so we don't need an extra signing key later
  if [[ "${ownerName}" == "${rewardsName}" ]]; then rewardsAccountIncluded="yes"; fi
done

#Add the rewards account signing staking key if needed
if [[ "${rewardsAccountIncluded}" == "no" ]]; then signingKeys="${signingKeys} --signing-key-file ${rewardsName}.staking.skey";   witnessCount=$(( ${witnessCount} + 1 )); fi


#-------------------------------------------------------------------------


#get values to register the staking address on the blockchain
currentTip=$(get_currentTip)
ttl=$(get_currentTTL)
currentEPOCH=$(get_currentEpoch)

echo
echo -e "\e[0m(Re)Register StakePool Certificate\e[32m ${regCertFile}\e[0m with funds from Address\e[32m ${regPayName}.addr\e[0m:"
echo

#Metadata-JSON HASH PreCheck: Check and compare the online metadata.json file hash with
#the one in the currently pool.json file. If they match up, continue. Otherwise exit with an ERROR
#Fetch online metadata.json file from the pool webserver
echo -ne "\e[0mMetadata HASH Check: Fetching the MetaData JSON file from \e[32m${poolMetaUrl}\e[0m ... "
tmpMetadataJSON="${tempDir}/$(basename ${poolName}).metadata.json"
curl -sL "${poolMetaUrl}" -o "${tmpMetadataJSON}" 2> /dev/null
if [[ $? -ne 0 ]]; then echo -e "\e[33mERROR, can't fetch the file!\e[0m\n"; exit 1; fi
#Check the downloaded file that is a valid JSON file
tmpCheckJSON=$(jq . "${tmpMetadataJSON}"  2> /dev/null)
if [[ $? -ne 0 ]]; then echo -e "\e[33mERROR - Not a valid JSON file on the webserver!\e[0m\n"; exit 1; fi
#Ok, downloaded file is a valid JSON file. So now look into the HASH
onlineMetaHash=$(${cardanocli} shelley stake-pool metadata-hash --pool-metadata-file "${tmpMetadataJSON}")
checkError "$?"
#Compare the HASH now, if they don't match up, output an ERROR message and exit
if [[ ! "${poolMetaHash}" == "${onlineMetaHash}" ]]; then
	echo -e "\e[33mERROR - HASH mismatch!\n\nPlease make sure to upload your MetaData JSON file correctly to your webserver!\nPool-Registration aborted! :-(\e[0m\n";
        echo -e "Your local \e[32m${poolFile}.metadata.json\e[0m with HASH \e[32m${poolMetaHash}\e[0m:\n"
	echo -e "--- BEGIN ---"
	cat ${poolFile}.metadata.json
        echo -e "---  END  ---\n\n"
        echo -e "Your remote file at \e[32m${poolMetaUrl}\e[0m with HASH \e[32m${onlineMetaHash}\e[0m:\n"
        echo -e "--- BEGIN ---\e[35m"
        cat ${tmpMetadataJSON}
        echo -e "\e[0m---  END  ---"
	echo -e "\e[0m\n"
	exit 1;
else echo -e "\e[32mOK\e[0m\n"; fi
#Ok, HASH is the same, continue


#Getting protocol parameters from the blockchain for fee calculation, minPoolCost, ...
${cardanocli} shelley query protocol-parameters --cardano-mode ${magicparam} > protocol-parameters.json
checkError "$?"
minPoolCost=$(cat protocol-parameters.json | jq -r .minPoolCost)

echo -e "\e[0m   Owner Stake Keys:\e[32m ${ownerCnt}\e[0m owner(s) with the key(s)"
for (( tmpCnt=0; tmpCnt<${ownerCnt}; tmpCnt++ ))
do
  ownerName=$(jq -r .poolOwner[${tmpCnt}].ownerName ${poolFile}.pool.json)
  echo -e "\e[0m                    \e[32m ${ownerName}.staking.vkey\e[0m & \e[32m${ownerName}.deleg.cert \e[0m"
done
echo -e "\e[0m      Rewards Stake:\e[32m ${rewardsName}.staking.vkey \e[0m"
echo -e "\e[0m      Witness Count:\e[32m ${witnessCount} signing keys \e[0m"
echo -e "\e[0m             Pledge:\e[32m ${poolPledge} \e[90mlovelaces"
echo -e "\e[0m               Cost:\e[32m ${poolCost} \e[90mlovelaces"
echo -e "\e[0m      Chain minCost:\e[32m ${minPoolCost} \e[90mlovelaces"
echo -e "\e[0m             Margin:\e[32m ${poolMargin} \e[0m"
echo
echo -e "\e[0m      Current EPOCH:\e[32m ${currentEPOCH}\e[0m"
echo -e "\e[0mCurrent Slot-Height:\e[32m ${currentTip}\e[0m (setting TTL to ${ttl})"

rxcnt="1"               #transmit to one destination addr. all utxos will be sent back to the fromAddr

#Check again about the minPoolCost
if [[ ${poolCost} -lt ${minPoolCost} ]]; then echo -e "\e[35mYour poolCost setting is too low, the current minPoolCost is ${minPoolCost} lovelaces !\e[0m"; exit 1; fi

sendFromAddr=$(cat ${regPayName}.addr)
sendToAddr=$(cat ${regPayName}.addr)

echo
echo -e "Pay fees from Address\e[32m ${regPayName}.addr\e[0m: ${sendFromAddr}"
echo


#Get UTX0 Data for the sendFromAddr
utx0=$(${cardanocli} shelley query utxo --address ${sendFromAddr} --cardano-mode ${magicparam}); checkError "$?"
utx0linecnt=$(echo "${utx0}" | wc -l)
txcnt=$((${utx0linecnt}-2))

if [[ ${txcnt} -lt 1 ]]; then echo -e "\e[35mNo funds on the payment Addr!\e[0m"; exit; else echo "${txcnt} UTXOs found on the payment Addr!"; fi

echo

#Calculating the total amount of lovelaces in all utxos on this address

totalLovelaces=0
txInString=""

while IFS= read -r utx0entry
do
fromHASH=$(echo ${utx0entry} | awk '{print $1}')
fromHASH=${fromHASH//\"/}
fromINDEX=$(echo ${utx0entry} | awk '{print $2}')
sourceLovelaces=$(echo ${utx0entry} | awk '{print $3}')
echo -e "HASH: ${fromHASH}\t INDEX: ${fromINDEX}\t LOVELACES: ${sourceLovelaces}"

totalLovelaces=$((${totalLovelaces}+${sourceLovelaces}))
txInString=$(echo -e "${txInString} --tx-in ${fromHASH}#${fromINDEX}")

done < <(printf "${utx0}\n" | tail -n ${txcnt})


echo -e "Total lovelaces in UTX0:\e[32m  ${totalLovelaces} lovelaces \e[90m"
echo

#Generate Dummy-TxBody file for fee calculation
        txBodyFile="${tempDir}/dummy.txbody"
	rm ${txBodyFile} 2> /dev/null
        ${cardanocli} shelley transaction build-raw ${txInString} --tx-out ${sendToAddr}+0 --ttl ${ttl} --fee 0 ${registrationCerts} --out-file ${txBodyFile}
	checkError "$?"
fee=$(${cardanocli} shelley transaction calculate-min-fee --tx-body-file ${txBodyFile} --protocol-params-file protocol-parameters.json --tx-in-count ${txcnt} --tx-out-count ${rxcnt} ${magicparam} --witness-count ${witnessCount} --byron-witness-count 0 | awk '{ print $1 }')
checkError "$?"
echo -e "\e[0mMinimum transfer Fee for ${txcnt}x TxIn & ${rxcnt}x TxOut & ${certCnt}x Certificate: \e[32m ${fee} lovelaces \e[90m"

#Check if pool was registered before and calculate Fee for registration or set it to zero for re-registration
if [[ "${regSubmitted}" == "" ]]; then   #pool not registered before
				  poolDepositFee=$(cat protocol-parameters.json | jq -r .poolDeposit)
				  echo -e "\e[0mPool Deposit Fee: \e[32m ${poolDepositFee} lovelaces \e[90m"
				  minRegistrationFund=$(( ${poolDepositFee}+${fee} ))
				  echo
				  echo -e "\e[0mMinimum funds required for registration (Sum of fees): \e[32m ${minRegistrationFund} lovelaces \e[90m"
				  echo
				  else   #pool was registered before -> reregistration -> no poolDepositFee
				  poolDepositFee=0
				  minRegistrationFund=$(( ${poolDepositFee}+${fee} ))
				  echo
				  echo -e "\e[0mMinimum funds required for re-registration (Sum of fees): \e[32m ${minRegistrationFund} lovelaces \e[90m"
				  echo
fi

#calculate new balance for destination address
lovelacesToSend=$(( ${totalLovelaces}-${minRegistrationFund} ))

#Checking about minimum funds in the UTX0
if [[ ${lovelacesToSend} -lt 0 ]]; then echo -e "\e[35mNot enough funds on the payment Addr!\e[0m"; exit; fi

echo -e "\e[0mLovelaces that will be returned to payment Address (UTXO-Sum minus fees): \e[32m ${lovelacesToSend} lovelaces \e[90m"
echo

txBodyFile="${tempDir}/$(basename ${poolName}).txbody"
txFile="${tempDir}/$(basename ${poolName}).tx"

echo
echo -e "\e[0mBuilding the unsigned transaction body with \e[32m ${regCertFile}\e[0m and all PoolOwner Delegation certificates: \e[32m ${txBodyFile} \e[90m"
echo

#Building unsigned transaction body
rm ${txBodyFile} 2> /dev/null
${cardanocli} shelley transaction build-raw ${txInString} --tx-out ${sendToAddr}+${lovelacesToSend} --ttl ${ttl} --fee ${fee} ${registrationCerts} --out-file ${txBodyFile}
checkError "$?"
cat ${txBodyFile} | head -n 6   #only show first 6 lines
echo

echo -e "\e[0mSign the unsigned transaction body with the \e[32m${regPayName}.skey\e[0m,\e[32m ${poolName}.node.skey\e[0m and all PoolOwner Staking Keys: \e[32m ${txFile} \e[90m"
echo

#Sign the unsigned transaction body with the SecureKey
rm ${txFile} 2> /dev/null
${cardanocli} shelley transaction sign --tx-body-file ${txBodyFile} ${signingKeys} --out-file ${txFile} ${magicparam}
checkError "$?"
cat ${txFile} | head -n 6   #only show first 6 lines
echo

#Read out the POOL-ID
poolIDhex=$(${cardanocli} shelley stake-pool id --verification-key-file ${poolName}.node.vkey --output-format hex)	#New method since 1.19.0
checkError "$?"

poolIDbech=$(${cardanocli} shelley stake-pool id --verification-key-file ${poolName}.node.vkey)      #New method since 1.19.0
checkError "$?"

echo -e "\e[0mStakepool Info JSON:\e[32m ${poolFile}.pool.json \e[90m"
cat ${poolFile}.pool.json
echo

echo -e "\e[0mPool-ID:\e[32m ${poolIDhex} / ${poolIDbech} \e[90m"
echo

#Show a warning to respect the pledge amount
if [[ ${poolPledge} -gt 0 ]]; then echo -e "\e[35mATTENTION - You're registered Pledge will be set to ${poolPledge} lovelaces, please respected it with the sum of all registered owner addresses!\e[0m\n"; fi


#Show a message if it's a reRegistration
if [[ ! "${regSubmitted}" == "" ]]; then   #pool registered before
				  echo -e "\e[35mThis will be a Pool Re-Registration\e[0m\n";
fi

if ask "\e[33mDoes this look good for you? Do you have enough pledge in your ${ownerName}.payment account, continue and register on chain ?" N; then
        echo
        echo -ne "\e[0mSubmitting the transaction via the node..."
        ${cardanocli} shelley transaction submit --tx-file ${txFile} --cardano-mode ${magicparam}
	#No error, so lets update the pool JSON file with the date and file the certFile was registered on the blockchain
	if [[ $? -eq 0 ]]; then
        file_unlock ${poolFile}.pool.json
        newJSON=$(cat ${poolFile}.pool.json | jq ". += {regEpoch: \"${currentEPOCH}\"}" | jq ". += {regSubmitted: \"$(date -R)\"}")
	echo "${newJSON}" > ${poolFile}.pool.json
        file_lock ${poolFile}.pool.json
	fi
        echo -e "\e[32mDONE\n"
fi

echo
echo -e "\e[0mStakepool Info JSON:\e[32m ${poolFile}.pool.json \e[90m"
cat ${poolFile}.pool.json
echo

echo -e "\e[0m\n"

