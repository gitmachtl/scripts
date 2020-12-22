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
poolMetaTicker=$(readJSONparam "poolMetaTicker"); if [[ ! $? == 0 ]]; then exit 1; fi
regProtectionKey=$(jq -r .regProtectionKey ${poolFile}.pool.json 2> /dev/null); if [[ "${regProtectionKey}" == null ]]; then regProtectionKey=""; fi


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
if [ ! -f "${regPayName}.addr" ]; then echo -e "\n\e[35mERROR - \"${regPayName}.addr\" does not exist! Please create it first with script 03a or 02.\e[0m"; exit 1; fi
if [ ! -f "${regPayName}.skey" ]; then echo -e "\n\e[35mERROR - \"${regPayName}.skey\" does not exist! Please create it first with script 03a or 02.\e[0m"; exit 1; fi

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

echo -e "\e[0m(Re)Register StakePool Certificate\e[32m ${regCertFile}\e[0m with funds from Address\e[32m ${regPayName}.addr\e[0m:"
echo

if ${onlineMode}; then

	#Check if the regProtectionKey is correct, this is a service to not have any duplicated Tickers on the Chain. If you know how to code you can see that it is easy, just a little protection for Noobs
	echo -ne "\e[0m\x54\x69\x63\x6B\x65\x72\x20\x50\x72\x6F\x74\x65\x63\x74\x69\x6F\x6E\x20\x43\x68\x65\x63\x6B\x20\x66\x6F\x72\x20\x54\x69\x63\x6B\x65\x72\x20'\e[32m${poolMetaTicker}\e[0m': "
	checkResult=$(curl -m 5 -s $(echo -e "\x68\x74\x74\x70\x73\x3A\x2F\x2F\x6D\x79\x2D\x69\x70\x2E\x61\x74\x2F\x63\x68\x65\x63\x6B\x74\x69\x63\x6B\x65\x72\x3F\x74\x69\x63\x6B\x65\x72\x3D${poolMetaTicker}&key=${regProtectionKey}") );
	if [[ $? -ne 0 ]]; then echo -e "\e[33m\x50\x72\x6F\x74\x65\x63\x74\x69\x6F\x6E\x20\x53\x65\x72\x76\x69\x63\x65\x20\x6F\x66\x66\x6C\x69\x6E\x65\e[0m";
			   else
				if [[ ! "${checkResult}" == "OK" ]]; then
								echo -e "\e[35mFailed\e[0m";
							        echo -e "\n\e[35mERROR - This Stakepool-Ticker '${poolMetaTicker}' is protected, your need the right registration-protection-key to interact with this Ticker!\n";
	                                               		echo -e "If you wanna protect your Ticker too, please reach out to @atada_stakepool on Telegram to get your unique ProtectionKey, Thx !\e[0m\n\n"; exit 1;
							 else
								echo -e "\e[32mOK\e[0m";
				fi
	fi
	echo

	#Metadata-JSON HASH PreCheck: Check and compare the online metadata.json file hash with
	#the one in the currently pool.json file. If they match up, continue. Otherwise exit with an ERROR
	#Fetch online metadata.json file from the pool webserver
	echo -ne "\e[0mMetadata HASH Check: Fetching the MetaData JSON file from \e[32m${poolMetaUrl}\e[0m ... "
	tmpMetadataJSON=$(curl -sL "${poolMetaUrl}" 2> /dev/null)
	if [[ $? -ne 0 ]]; then echo -e "\e[33mERROR, can't fetch the metadata file from the webserver!\e[0m\n"; exit 1; fi
	#Check the downloaded data that is a valid JSON file
	tmpCheckJSON=$(echo "${tmpMetadataJSON}" | jq . 2> /dev/null)
	if [[ $? -ne 0 ]]; then echo -e "\e[33mERROR - Not a valid JSON file on the webserver!\e[0m\n"; exit 1; fi
	#Ok, downloaded file is a valid JSON file. So now look into the HASH
	onlineMetaHash=$(${cardanocli} ${subCommand} stake-pool metadata-hash --pool-metadata-file <(echo "${tmpMetadataJSON}") )
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

fi; #onlinemode

#Read ProtocolParameters
if ${onlineMode}; then
                        protocolParametersJSON=$(${cardanocli} ${subCommand} query protocol-parameters --cardano-mode ${magicparam} ${nodeEraParam}); #onlinemode
                  else
			readOfflineFile;
                        protocolParametersJSON=$(jq ".protocol.parameters" <<< ${offlineJSON}); #offlinemode
                  fi
checkError "$?"

minPoolCost=$(jq -r .minPoolCost <<< ${protocolParametersJSON})

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
echo -e "\e[0mCurrent Slot-Height:\e[32m ${currentTip}\e[0m (setting TTL[invalid_hereafter] to ${ttl})"

rxcnt="1"               #transmit to one destination addr. all utxos will be sent back to the fromAddr

#Check again about the minPoolCost
if [[ ${poolCost} -lt ${minPoolCost} ]]; then echo -e "\e[35mYour poolCost setting is too low, the current minPoolCost is ${minPoolCost} lovelaces !\e[0m"; exit 1; fi

sendFromAddr=$(cat ${regPayName}.addr)
sendToAddr=$(cat ${regPayName}.addr)

echo
echo -e "Pay fees from Address\e[32m ${regPayName}.addr\e[0m: ${sendFromAddr}"
echo

#------------------------------------------------------------------

#
# Checking UTXO Data of the source address and gathering data about total lovelaces and total assets
#
        #Get UTX0 Data for the address. When in online mode of course from the node and the chain, in offlinemode from the transferFile
        if ${onlineMode}; then
                                utxoJSON=$(${cardanocli} ${subCommand} query utxo --address ${sendFromAddr} --cardano-mode ${magicparam} ${nodeEraParam} --out-file /dev/stdout); checkError "$?";
                          else
                                readOfflineFile;        #Reads the offlinefile into the offlineJSON variable
                                utxoJSON=$(jq -r ".address.\"${sendFromAddr}\".utxoJSON" <<< ${offlineJSON})
                                if [[ "${utxoJSON}" == null ]]; then echo -e "\e[35mPayment-Address not included in the offline transferFile, please include it first online!\e[0m\n"; exit; fi
        fi
  	txcnt=$(jq length <<< ${utxoJSON}) #Get number of UTXO entries (Hash#Idx), this is also the number of --tx-in for the transaction
	if [[ ${txcnt} == 0 ]]; then echo -e "\e[35mNo funds on the Source Address!\e[0m\n"; exit; else echo -e "\e[32m${txcnt} UTXOs\e[0m found on the Source Address!\n"; fi

        #Convert UTXO into mary style if UTXO is shelley/allegra style
        if [[ ! "$(jq -r '[.[]][0].amount | type' <<< ${utxoJSON})" == "array" ]]; then utxoJSON=$(convert_UTXO "${utxoJSON}"); fi

	#Calculating the total amount of lovelaces in all utxos on this address
        totalLovelaces=$(jq '[.[].amount[0]] | add' <<< ${utxoJSON})

        totalAssetsJSON="{}"; 	#Building a total JSON with the different assetstypes "policyIdHash.name", amount and name
        totalPolicyIDsJSON="{}"; #Holds the different PolicyIDs as values "policyIDHash", length is the amount of different policyIDs

	assetsOutString="";	#This will hold the String to append on the --tx-out if assets present or it will be empty

        #For each utxo entry, check the utxo#index and check if there are also any assets in that utxo#index
        #LEVEL 1 - different UTXOs
        for (( tmpCnt=0; tmpCnt<${txcnt}; tmpCnt++ ))
        do
        utxoHashIndex=$(jq -r "keys[${tmpCnt}]" <<< ${utxoJSON})
        utxoAmount=$(jq -r ".\"${utxoHashIndex}\".amount[0]" <<< ${utxoJSON})   #Lovelaces
        echo -e "Hash#Index: ${utxoHashIndex}\tAmount: ${utxoAmount}"
        assetsJSON=$(jq -r ".\"${utxoHashIndex}\".amount[1]" <<< ${utxoJSON})
        assetsEntryCnt=$(jq length <<< ${assetsJSON})
        if [[ ${assetsEntryCnt} -gt 0 ]]; then
                        #LEVEL 2 - different policyID/assetHASH
                        for (( tmpCnt2=0; tmpCnt2<${assetsEntryCnt}; tmpCnt2++ ))
                        do
                        assetHash=$(jq -r ".[${tmpCnt2}][0]" <<< ${assetsJSON})  #assetHash = policyID
                        assetsNameCnt=$(jq ".[${tmpCnt2}][1] | length" <<< ${assetsJSON})
                        totalPolicyIDsJSON=$( jq ". += {\"${assetHash}\": 1}" <<< ${totalPolicyIDsJSON})

                                #LEVEL 3 - different names under the same policyID
                                for (( tmpCnt3=0; tmpCnt3<${assetsNameCnt}; tmpCnt3++ ))
                                do
                                assetName=$(jq -r ".[${tmpCnt2}][1][${tmpCnt3}][0]" <<< ${assetsJSON})
                                assetAmount=$(jq -r ".[${tmpCnt2}][1][${tmpCnt3}][1]" <<< ${assetsJSON})
                                oldValue=$(jq -r ".\"${assetHash}.${assetName}\".amount" <<< ${totalAssetsJSON})
                                newValue=$((${oldValue}+${assetAmount}))
                                totalAssetsJSON=$( jq ". += {\"${assetHash}.${assetName}\":{amount: ${newValue}, name: \"${assetName}\"}}" <<< ${totalAssetsJSON})
                                echo -e "\e[90m            PolID: ${assetHash}\tAmount: ${assetAmount} ${assetName}\e[0m"
                                done
                         done
        fi
        txInString="${txInString} --tx-in ${utxoHashIndex}"
        done
        echo -e "\e[0m-----------------------------------------------------------------------------------------------------"
        totalInADA=$(bc <<< "scale=6; ${totalLovelaces} / 1000000")
        echo -e "Total ADA on the Address:\e[32m  ${totalInADA} ADA / ${totalLovelaces} lovelaces \e[0m\n"
        totalPolicyIDsCnt=$(jq length <<< ${totalPolicyIDsJSON});
        totalAssetsCnt=$(jq length <<< ${totalAssetsJSON})
        if [[ ${totalAssetsCnt} -gt 0 ]]; then
                        echo -e "\e[32m${totalAssetsCnt} Asset-Type(s) / ${totalPolicyIDsCnt} different PolicyIDs\e[0m found on the Address!\n"
                        printf "\e[0m%-70s %16s %s\n" "PolicyID.Name:" "Total-Amount:" "Name:"
                        for (( tmpCnt=0; tmpCnt<${totalAssetsCnt}; tmpCnt++ ))
                        do
                        assetHashName=$(jq -r "keys[${tmpCnt}]" <<< ${totalAssetsJSON})
                        assetAmount=$(jq -r ".\"${assetHashName}\".amount" <<< ${totalAssetsJSON})
                        assetName=$(jq -r ".\"${assetHashName}\".name" <<< ${totalAssetsJSON})
                        printf "\e[90m%-70s \e[32m%16s %s\e[0m\n" "${assetHashName}" "${assetAmount}" "${assetName}"
                        if [[ ${assetAmount} -gt 0 ]]; then assetsOutString+="+${assetAmount} ${assetHashName}"; fi #only include in the sendout if more than zero
                        done
        fi
echo

minOutUTXO=$(get_minOutUTXO "${protocolParametersJSON}" "${totalAssetsCnt}" "${totalPolicyIDsCnt}")

#------------------------------------------------------------------


#Generate Dummy-TxBody file for fee calculation
txBodyFile="${tempDir}/dummy.txbody"
rm ${txBodyFile} 2> /dev/null
${cardanocli} ${subCommand} transaction build-raw ${nodeEraParam} ${txInString} --tx-out "${sendToAddr}+0${assetsOutString}" --invalid-hereafter ${ttl} --fee 0 ${registrationCerts} --out-file ${txBodyFile}
checkError "$?"
fee=$(${cardanocli} ${subCommand} transaction calculate-min-fee --tx-body-file ${txBodyFile} --protocol-params-file <(echo ${protocolParametersJSON}) --tx-in-count ${txcnt} --tx-out-count ${rxcnt} ${magicparam} --witness-count ${witnessCount} --byron-witness-count 0 | awk '{ print $1 }')
checkError "$?"
echo -e "\e[0mMinimum transfer Fee for ${txcnt}x TxIn & ${rxcnt}x TxOut & ${certCnt}x Certificate: \e[32m ${fee} lovelaces \e[90m"

#Check if pool was registered before and calculate Fee for registration or set it to zero for re-registration
if [[ "${regSubmitted}" == "" ]]; then   #pool not registered before
				  poolDepositFee=$(jq -r .poolDeposit <<< ${protocolParametersJSON})
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

echo -e "\e[0mLovelaces that will be return to payment Address (UTXO-Sum minus fees): \e[32m ${lovelacesToSend} lovelaces \e[90m (min. required ${minOutUTXO} lovelaces)"
echo

#Checking about minimum funds in the UTX0
if [[ ${lovelacesToSend} -lt ${minOutUTXO} ]]; then echo -e "\e[35mNot enough funds on the source Addr! Minimum UTXO value is ${minOutUTXO} lovelaces.\e[0m"; exit; fi

txBodyFile="${tempDir}/$(basename ${poolName}).txbody"
txFile="${tempDir}/$(basename ${poolName}).tx"

echo
echo -e "\e[0mBuilding the unsigned transaction body with \e[32m ${regCertFile}\e[0m and all PoolOwner Delegation certificates: \e[32m ${txBodyFile} \e[90m"
echo

#Building unsigned transaction body
rm ${txBodyFile} 2> /dev/null
${cardanocli} ${subCommand} transaction build-raw ${nodeEraParam} ${txInString} --tx-out "${sendToAddr}+${lovelacesToSend}${assetsOutString}" --invalid-hereafter ${ttl} --fee ${fee} ${registrationCerts} --out-file ${txBodyFile}
checkError "$?"
cat ${txBodyFile} | head -n 6   #only show first 6 lines
echo

echo -e "\e[0mSign the unsigned transaction body with the \e[32m${regPayName}.skey\e[0m,\e[32m ${poolName}.node.skey\e[0m and all PoolOwner Staking Keys: \e[32m ${txFile} \e[90m"
echo

#Sign the unsigned transaction body with the SecureKey
rm ${txFile} 2> /dev/null
${cardanocli} ${subCommand} transaction sign --tx-body-file ${txBodyFile} ${signingKeys} --out-file ${txFile} ${magicparam}
checkError "$?"
cat ${txFile} | head -n 6   #only show first 6 lines
echo

#Read out the POOL-ID
poolIDhex=$(${cardanocli} ${subCommand} stake-pool id --cold-verification-key-file ${poolName}.node.vkey --output-format hex)	#New method since 1.23.0
checkError "$?"

poolIDbech=$(${cardanocli} ${subCommand} stake-pool id --cold-verification-key-file ${poolName}.node.vkey)      #New method since 1.23.0
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
				  offlineRegistrationType="PoolReRegistration"; #Just as Type info for the offline file
				    else
				  offlineRegistrationType="PoolRegistration"; #Just as Type info for the offline File
fi

if ask "\e[33mDoes this look good for you? Do you have enough pledge in your owner account(s), continue and register on chain ?" N; then
        echo

        if ${onlineMode}; then  #onlinesubmit
			        echo -ne "\e[0mSubmitting the transaction via the node..."
			        ${cardanocli} ${subCommand} transaction submit --tx-file ${txFile} --cardano-mode ${magicparam}
			        #No error, so lets update the pool JSON file with the date and file the certFile was registered on the blockchain
			        if [[ $? -eq 0 ]]; then
			        file_unlock ${poolFile}.pool.json
			        newJSON=$(cat ${poolFile}.pool.json | jq ". += {regEpoch: \"${currentEPOCH}\"}" | jq ". += {regSubmitted: \"$(date -R)\"}")
			        echo "${newJSON}" > ${poolFile}.pool.json
			        file_lock ${poolFile}.pool.json
			        echo -e "\e[32mDONE\n"
			        else
			        echo -e "\n\n\e[35mERROR (Code $?) !\e[0m"; exit 1;
			        fi
                                echo
                                echo -e "\e[0mStakepool Info JSON:\e[32m ${poolFile}.pool.json \e[90m"
                                cat ${poolFile}.pool.json
                                echo

                          else  #offlinestore
                                txFileJSON=$(cat ${txFile} | jq .)
                                offlineJSON=$( jq ".transactions += [ { date: \"$(date -R)\",
                                                                        type: \"${offlineRegistrationType}\",
                                                                        era: \"$(jq -r .protocol.era <<< ${offlineJSON})\",
                                                                        fromAddr: \"${regPayName}\",
                                                                        sendFromAddr: \"${sendFromAddr}\",
                                                                        toAddr: \"${regPayName}\",
                                                                        sendToAddr: \"${sendToAddr}\",
									poolMetaTicker: \"${poolMetaTicker}\",
									regProtectionKey: \"${regProtectionKey}\",
									poolMetaUrl: \"${poolMetaUrl}\",
									poolMetaHash: \"${poolMetaHash}\",
                                                                        txJSON: ${txFileJSON} } ]" <<< ${offlineJSON})
                                #Write the new offileFile content
                                offlineJSON=$( jq ".history += [ { date: \"$(date -R)\", action: \"signed pool registration transaction for '${poolMetaTicker}', payment via '${regPayName}'\" } ]" <<< ${offlineJSON})
                                offlineJSON=$( jq ".general += {offlineCLI: \"${versionCLI}\" }" <<< ${offlineJSON})

				#Ask about attaching the metadata file into the offlineJSON, because we're cool :-)
				fileToAttach="${poolFile}.metadata.json"
				if [ -f "${fileToAttach}" ]; then
					if ask "\e[33mInclude the '${fileToAttach}' into '$(basename ${offlineFile})' to transfer it in one step?" N; then
					offlineJSON=$( jq ".files.\"${fileToAttach}\" += { date: \"$(date -R)\", size: \"$(du -b ${fileToAttach} | cut -f1)\", base64: \"$(base64 -w 0 ${fileToAttach})\" }" <<< ${offlineJSON});
				        checkError "$?"
					echo
					fi
				fi

                                #Ask about attaching the extended-metadata file into the offlineJSON, because we're cool :-)
                                fileToAttach="${poolFile}.extended-metadata.json"
                                if [ -f "${fileToAttach}" ]; then
                                        if ask "\e[33mInclude the '${fileToAttach}' into '$(basename ${offlineFile})' to transfer it in one step?" N; then
                                        offlineJSON=$( jq ".files.\"${fileToAttach}\" += { date: \"$(date -R)\", size: \"$(du -b ${fileToAttach} | cut -f1)\", base64: \"$(base64 -w 0 ${fileToAttach})\" }" <<< ${offlineJSON});
					checkerror "$?"
					echo
                                        fi
                                fi

                                echo "${offlineJSON}" > ${offlineFile}
                                #Readback the tx content and compare it to the current one
                                readback=$(cat ${offlineFile} | jq -r ".transactions[-1].txJSON")
                                if [[ "${txFileJSON}" == "${readback}" ]]; then
							echo
							echo -e "\e[0mStakepool Info JSON:\e[32m ${poolFile}.pool.json \e[90m"
							cat ${poolFile}.pool.json
							echo
			                                file_unlock ${poolFile}.pool.json
			                                newJSON=$(cat ${poolFile}.pool.json | jq ". += {regEpoch: \"${currentEPOCH}\"}" | jq ". += {regSubmitted: \"$(date -R) (only offline, no proof)\"}")
			                                echo "${newJSON}" > ${poolFile}.pool.json
			                                file_lock ${poolFile}.pool.json
                                                        showOfflineFileInfo;
                                                        echo -e "\e[33mTransaction txJSON has been stored in the '$(basename ${offlineFile})'.\nYou can now transfer it to your online machine for execution.\e[0m\n";
                                                 else
                                                        echo -e "\e[35mERROR - Could not verify the written data in the '$(basename ${offlineFile})'. Retry again or generate a new '$(basename ${offlineFile})'.\e[0m\n";
                                fi

        fi

fi

echo -e "\e[0m\n"

