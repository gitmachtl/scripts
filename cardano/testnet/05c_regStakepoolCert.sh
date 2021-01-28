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
  2|3) regPayName="$(dirname $2)/$(basename $2 .addr)"; regPayName=${regPayName/#.\//}
      poolFile="$(dirname $1)/$(basename $(basename $1 .json) .pool)"; poolFile=${poolFile/#.\//};;
  * ) cat >&2 <<EOF
ERROR - Usage: $(basename $0) <PoolNodeName> <PaymentAddrForRegistration> [optional keyword REG to force a registration, REREG to force a re-registration]
EOF
  exit 1;; esac

if [[ $# -eq 3 ]]; then  forceParam=$3; else forceParam=""; fi


#Check if referenced JSON file exists
if [ ! -f "${poolFile}.pool.json" ]; then echo -e "\n\e[35mERROR - ${poolFile}.pool.json does not exist! Please create it first with script 05a.\e[0m"; exit 1; fi

poolJSON=$(cat ${poolFile}.pool.json)	#Read PoolJSON File into poolJSON variable for modifications within this script

#Check if there is already an opened witness in the poolJSON, if not create a new one with the current utctime in seconds as id
regWitnessID=$(jq -r .regWitness.id <<< ${poolJSON} 2> /dev/null);
if [[ "${regWitnessID}" == null || "${regWitnessID}" == 0 ]]; then #Opening up a new witness in the poolJSON
	regWitnessID=""; #used later to determine if it is a new witnesscollection or an existing one
	poolJSON=$(jq ".regWitness = { id: $(date +%s), type: \"\", ttl: 0, regPayName: \"\", txBody: {}, witnesses: {} }" <<< ${poolJSON})
	#Write the opened Witness only if the txBody was created successfully
	else
	regWitnessDate=$(date --date="@${regWitnessID}") #Get date of the already existing witnesscollection
fi

#Small subroutine to read the value of the JSON and output an error if parameter is empty/missing
function readJSONparam() {
param=$(jq -r .$1 <<< ${poolJSON} 2> /dev/null)
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
regProtectionKey=$(jq -r .regProtectionKey <<< ${poolJSON} 2> /dev/null); if [[ "${regProtectionKey}" == null ]]; then regProtectionKey=""; fi

#Checks for needed local files
if [ ! -f "${regCertFile}" ]; then echo -e "\n\e[35mERROR - \"${regCertFile}\" StakePool (Re)registration-Certificate does not exist or was already submitted before!\n\nPlease create it by running script:\e[0m 05a_genStakepoolCert.sh ${poolFile}\n"; exit 1; fi
if [ ! -f "${poolName}.node.vkey" ]; then echo -e "\n\e[35mERROR - \"${poolName}.node.vkey\" does not exist! Please create it first with script 04a.\e[0m"; exit 1; fi
if [ ! -f "${poolName}.node.skey" ]; then echo -e "\n\e[35mERROR - \"${poolName}.node.skey\" does not exist! Please create it first with script 04a.\e[0m"; exit 1; fi
if [ ! -f "${regPayName}.addr" ]; then echo -e "\n\e[35mERROR - \"${regPayName}.addr\" does not exist! Please create it first with script 03a or 02.\e[0m"; exit 1; fi
if [ ! -f "${regPayName}.skey" ]; then echo -e "\n\e[35mERROR - \"${regPayName}.skey\" does not exist! Please create it first with script 03a or 02. No hardware-wallet allowed for poolRegistration payments! :-(\e[0m\n"; exit 1; fi


#Load regSubmitted value from the pool.json. If there is an entry, than do a Re-Registration (changes the Fee!)
regSubmitted=$(jq -r .regSubmitted <<< ${poolJSON} 2> /dev/null); if [[ "${regSubmitted}" == null ]]; then regSubmitted=""; fi

#SO, now only do the following stuff the first time when no witnesscollection exists -> starting a new poolregistration/poolderegistration. No change possible after witnesscollection opening
if [[ "${regWitnessID}" == "" ]]; then

	#Add the node witness and payment witness at first entries
	poolJSON=$(jq ".regWitness.witnesses.\"${poolName}.node\".witness = {}" <<< ${poolJSON});
	poolJSON=$(jq ".regWitness.witnesses.\"${regPayName}\".witness = {}" <<< ${poolJSON});

	#Force registration instead of re-registration via optional command line command "force"
	if [[ "${forceParam}" == "" ]]; then
		deregSubmitted=$(jq -r .deregSubmitted <<< ${poolJSON} 2> /dev/null); if [[ ! "${deregSubmitted}" == null ]]; then echo -e "\n\e[35mERROR - I'am confused, the pool was registered and retired before. Please specify if you wanna register or reregister the pool now with the optional keyword REG or REREG !\e[0m\n"; exit 1; fi
	elif [[ "${forceParam^^}" == "REG" ]]; then regSubmitted="";  	#force a new registration
	elif [[ "${forceParam^^}" == "REREG" ]]; then regSubmitted="xxx";	#force a re-registration
	fi

else #WitnessID and data already in the poolJSON
       storedRegPayName=$(jq -r .regWitness.regPayName <<< ${poolJSON}) #load data from already started witness collection
       if [[ ! "${forceParam}" == "" ]]; then #if a force parameter was given but there is already a witness in the poolJSON, exit with an error, not allowed, you have to start a new witness
                echo -e "\e[35mERROR - You already started a witness collection. If you wanna change the Registration-Type (reg or rereg) now,\nyou have to start all over again by running:\e[33m 05d_poolWitness.sh clear ${poolFile}\e[35m\n\nIf you just wanna complete your started poolRegistration run:\e[33m 05c_regStakepoolCert ${poolFile} ${storedRegPayName}\n\e[35mwithout the REG or REREG keyword. :-)\e[0m\n";
		exit 1;
       fi
fi

ownerCnt=$(jq -r '.poolOwner | length' <<< ${poolJSON})
certCnt=$(( ${ownerCnt} + 1 ))	#Total number of needed certificates: poolRegistrationCertificate and every poolOwnerDelegationCertificate
registrationCerts="--certificate ${regCertFile}" #list of all needed certificates: poolRegistrationCertificat and every poolOwnerDelegationCertificate
witnessCount=2	#Total number of needed witnesses: poolnode skey, registration payment skey/hwsfile + each owner witness + maybe rewards account witness
hardwareWalletIncluded="no"

#Lets first count all needed witnesses and check about the delegation certificates
for (( tmpCnt=0; tmpCnt<${ownerCnt}; tmpCnt++ ))
do
  ownerName=$(jq -r .poolOwner[${tmpCnt}].ownerName <<< ${poolJSON})
  witnessCount=$(( ${witnessCount} + 1 )) #Every owner is of course also needed as witness
  if [ ! -f "${ownerName}.staking.vkey" ]; then echo -e "\e[0mERROR - \"${ownerName}.staking.vkey\" is missing! Check poolOwner/ownerName field in ${poolFile}.pool.json, or generate one with script 03a !\e[0m"; exit 1; fi
  if [[ "$(jq -r .description < ${ownerName}.staking.vkey)" == *"Hardware"* ]]; then hardwareWalletIncluded="yes"; fi
  if [ ! -f "${ownerName}.deleg.cert" ]; then echo -e "\e[35mERROR - \"${ownerName}.deleg.cert\" does not exist! Please create it first with script 05b.\e[0m"; exit 1; fi
  #When we are in the loop, just build up also all the needed signingkeys & certificates for the transaction
  registrationCerts="${registrationCerts} --certificate ${ownerName}.deleg.cert"
  #Also check, if the ownername is the same as the one in the rewards account, if so we don't need an extra signing key later
  if [[ "${regWitnessID}" == "" ]]; then poolJSON=$(jq ".regWitness.witnesses.\"${ownerName}.staking\" = {}" <<< ${poolJSON}); fi #include the witnesses in the poolJSON if its a new collection
done

#If a hardware wallet is involved as an owner, then reduce the certificates to only the stakepoolRegistrationCertificate, its not allowed to also submit the delegationCertificates in one transaction :-(
if [[ "${hardwareWalletIncluded}" == "yes" ]]; then
registrationCerts="--certificate ${regCertFile}" #reduce back to only the poolRegistrationCertificate
certCnt=1	#reduce back to only one certificate
fi

#-------------------------------------------------------------------------

#get values to register the staking address on the blockchain
currentTip=$(get_currentTip)
currentEPOCH=$(get_currentEpoch)

if [[ "${regWitnessID}" == "" ]]; then #New witness collection
	ttl=$(get_currentTTL)
	else
	ttl=$(jq -r .regWitness.ttl <<< ${poolJSON}) #load data from already started witness collection
        if [[ ${ttl} -lt ${currentTip} ]]; then #if the TTL stored in the witness collection is lower than the current tip, the transaction window is over
                echo -e "\e[35mERROR - You have waited too long to assemble the witness collection, TTL is now lower than the current chain tip!\nYou have to start all over again by running:\e[33m 05d_poolWitness.sh clear ${poolFile}\e[0m\n"; exit 1;
        fi
        storedRegPayName=$(jq -r .regWitness.regPayName <<< ${poolJSON}) #load data from already started witness collection
	if [[ ! "${regPayName}" == "${storedRegPayName}" ]]; then #if stored payment name has changed, exit with an error, not allowed, you have to start a new witness
		echo -e "\e[35mERROR - You already started a witness collection, the payment name was \e[32m${storedRegPayName}\e[35m !\nIf you wanna change the payment account you have to start all over again by running:\e[33m 05d_poolWitness.sh clear ${poolFile}\e[35m\n\nIf you just wanna complete your started poolRegistration, run:\e[33m 05c_regStakepoolCert ${poolFile} ${storedRegPayName}\n\n\e[0m"; exit 1;
	fi
fi

echo -e "\e[0m(Re)Register StakePool Certificate\e[32m ${regCertFile}\e[0m and Owner-Delegations with funds from Address\e[32m ${regPayName}.addr\e[0m:"
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
	checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
	#Compare the HASH now, if they don't match up, output an ERROR message and exit
	if [[ ! "${poolMetaHash}" == "${onlineMetaHash}" ]]; then
		echo -e "\e[33mERROR - HASH mismatch!\n\nPlease make sure to upload your MetaData JSON file correctly to your webserver!\nPool-Registration aborted! :-(\e[0m\n";
	        echo -e "Your local \e[32m${poolFile}.metadata.json\e[0m with HASH \e[32m${poolMetaHash}\e[0m:\n"
		echo -e "--- BEGIN ---"
		cat ${poolFile}.metadata.json
	        echo -e "---  END  ---\n\n"
	        echo -e "Your remote file at \e[32m${poolMetaUrl}\e[0m with HASH \e[32m${onlineMetaHash}\e[0m:\n"
	        echo -e "--- BEGIN ---\e[35m"
	        echo "${tmpMetadataJSON}"
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

checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

echo -e "\e[0m   Owner Stake Keys:\e[32m ${ownerCnt}\e[0m owner(s) with the key(s)"
for (( tmpCnt=0; tmpCnt<${ownerCnt}; tmpCnt++ ))
do
  ownerName=$(jq -r .poolOwner[${tmpCnt}].ownerName <<< ${poolJSON})
  echo -ne "\e[0m                    \e[32m ${ownerName}.staking.vkey\e[0m & \e[32m${ownerName}.deleg.cert \e[0m"
  if [[ "$(jq -r .description < ${ownerName}.staking.vkey)" == *"Hardware"* ]]; then echo -e "(Hardware-Key)"; else echo; fi
done
echo -ne "\e[0m      Rewards Stake:\e[32m ${rewardsName}.staking.vkey \e[0m"
  if [[ "$(jq -r .description < ${rewardsName}.staking.vkey)" == *"Hardware"* ]]; then echo -e "(Hardware-Key)"; else echo; fi
echo -e "\e[0m   Witnesses needed:\e[32m ${witnessCount} signed witnesses \e[0m"
echo -e "\e[0m             Pledge:\e[32m ${poolPledge} \e[90mlovelaces"
echo -e "\e[0m               Cost:\e[32m ${poolCost} \e[90mlovelaces"
echo -e "\e[0m             Margin:\e[32m ${poolMargin} \e[0m"
echo
echo -e "\e[0m      Current EPOCH:\e[32m ${currentEPOCH}\e[0m"
echo -e "\e[0mCurrent Slot-Height:\e[32m ${currentTip}\e[0m (set TTL[invalid_hereafter] is ${ttl})"

rxcnt="1"               #transmit to one destination addr. all utxos will be sent back to the fromAddr

sendFromAddr=$(cat ${regPayName}.addr)
sendToAddr=$(cat ${regPayName}.addr)

echo
echo -e "Pay fees from Address\e[32m ${regPayName}.addr\e[0m: ${sendFromAddr}"
echo

#------------------------------------------------------------------

#SO, now only do the following stuff the first time when no witnesscollection exists -> starting a new poolregistration/poolderegistration. No change possible after witnesscollection opening
if [[ "${regWitnessID}" == "" ]]; then

#
# Checking UTXO Data of the source address and gathering data about total lovelaces and total assets
#
        #Get UTX0 Data for the address. When in online mode of course from the node and the chain, in offlinemode from the transferFile
        if ${onlineMode}; then
                                utxoJSON=$(${cardanocli} ${subCommand} query utxo --address ${sendFromAddr} --cardano-mode ${magicparam} ${nodeEraParam} --out-file /dev/stdout); checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi;
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
        utxoHashIndex=$(jq -r "keys_unsorted[${tmpCnt}]" <<< ${utxoJSON})
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
        echo -e "Total ADA on the Address:\e[32m $(convertToADA ${totalLovelaces}) ADA / ${totalLovelaces} lovelaces \e[0m\n"
        totalPolicyIDsCnt=$(jq length <<< ${totalPolicyIDsJSON});
        totalAssetsCnt=$(jq length <<< ${totalAssetsJSON})
        if [[ ${totalAssetsCnt} -gt 0 ]]; then
                        echo -e "\e[32m${totalAssetsCnt} Asset-Type(s) / ${totalPolicyIDsCnt} different PolicyIDs\e[0m found on the Address!\n"
                        printf "\e[0m%-70s %16s %s\n" "PolicyID.Name:" "Total-Amount:" "Name:"
                        for (( tmpCnt=0; tmpCnt<${totalAssetsCnt}; tmpCnt++ ))
                        do
                        assetHashName=$(jq -r "keys_unsorted[${tmpCnt}]" <<< ${totalAssetsJSON})
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
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
fee=$(${cardanocli} ${subCommand} transaction calculate-min-fee --tx-body-file ${txBodyFile} --protocol-params-file <(echo ${protocolParametersJSON}) --tx-in-count ${txcnt} --tx-out-count ${rxcnt} ${magicparam} --witness-count ${witnessCount} --byron-witness-count 0 | awk '{ print $1 }')
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
echo -e "\e[0mMinimum transfer Fee for ${txcnt}x TxIn & ${rxcnt}x TxOut & ${certCnt}x Certificate: \e[32m $(convertToADA ${fee}) ADA / ${fee} lovelaces \e[90m"

#Check if pool was registered before and calculate Fee for registration or set it to zero for re-registration
if [[ "${regSubmitted}" == "" ]]; then   #pool not registered before
				  poolDepositFee=$(jq -r .poolDeposit <<< ${protocolParametersJSON})
				  echo -e "\e[0mPool Deposit Fee: \e[32m ${poolDepositFee} lovelaces \e[90m"
				  minRegistrationFees=$(( ${poolDepositFee}+${fee} ))
				  registrationType="PoolRegistration"
				  echo
				  echo -e "\e[0mMinimum funds required for registration (Sum of fees): \e[32m $(convertToADA ${minRegistrationFees}) ADA / ${minRegistrationFees} lovelaces \e[90m"
				  echo
				  else   #pool was registered before -> reregistration -> no poolDepositFee
				  poolDepositFee=0
				  minRegistrationFees=$(( ${poolDepositFee}+${fee} ))
				  registrationType="PoolReRegistration"
				  echo
				  echo -e "\e[0mMinimum funds required for re-registration (Sum of fees): \e[32m $(convertToADA ${minRegistrationFees}) ADA / ${minRegistrationFees} lovelaces \e[90m"
				  echo
fi

#calculate new balance for destination address
lovelacesToSend=$(( ${totalLovelaces}-${minRegistrationFees} ))

echo -e "\e[0mLovelaces that will be returned to payment Address (UTXO-Sum minus fees): \e[32m $(convertToADA ${lovelacesToSend}) ADA / ${lovelacesToSend} lovelaces \e[90m (min. required ${minOutUTXO} lovelaces)"
echo

#Checking about minimum funds in the UTX0
if [[ ${lovelacesToSend} -lt ${minOutUTXO} ]]; then echo -e "\e[35mNot enough funds on the source Addr! Minimum UTXO value is ${minOutUTXO} lovelaces.\e[0m"; exit; fi

txBodyFile="${tempDir}/$(basename ${poolName}).txbody"

echo -e "\e[0mBuilding the unsigned transaction body with \e[32m ${regCertFile}\e[0m and all PoolOwner Delegation certificates: \e[32m ${txBodyFile} \e[90m"
echo

#Building unsigned transaction body
rm ${txBodyFile} 2> /dev/null
${cardanocli} ${subCommand} transaction build-raw ${nodeEraParam} ${txInString} --tx-out "${sendToAddr}+${lovelacesToSend}${assetsOutString}" --invalid-hereafter ${ttl} --fee ${fee} ${registrationCerts} --out-file ${txBodyFile}
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
cat ${txBodyFile} | head -n 6   #only show first 6 lines
echo

#So now lets ask if this payment looks ok, it will not be displayed later if a witness is missing
if ! ask "\e[33mDoes this look good for you? Continue?" N; then exit 1; fi #if not ok, abort
echo

#OK txBody was built sucessfully so now write it to the witnesscollection in the poolJSON

poolJSON=$(jq ".regWitness.ttl = ${ttl}" <<< ${poolJSON})
poolJSON=$(jq ".regWitness.txBody = $(cat ${txBodyFile})" <<< ${poolJSON})
poolJSON=$(jq ".regWitness.regPayName = \"${regPayName}\"" <<< ${poolJSON})
poolJSON=$(jq ".regWitness.regPayAmount = ${minRegistrationFees}" <<< ${poolJSON})
poolJSON=$(jq ".regWitness.regPayReturn = ${lovelacesToSend}" <<< ${poolJSON})
poolJSON=$(jq ".regWitness.type = \"${registrationType}\"" <<< ${poolJSON})
poolJSON=$(jq ".regWitness.hardwareWalletIncluded = \"${hardwareWalletIncluded}\"" <<< ${poolJSON})

#Fill the witness count with the node-coldkey witness
echo -e "\e[0mAdding the pool node witness '\e[33m${poolName}.node.skey\e[0m' ...\n"
tmpWitness=$(${cardanocli} transaction witness --tx-body-file ${txBodyFile} --signing-key-file ${poolName}.node.skey ${magicparam} --out-file /dev/stdout)
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
poolJSON=$(jq ".regWitness.witnesses.\"${poolName}.node\".witness = ${tmpWitness}" <<< ${poolJSON}); #include the witnesses in the poolJSON if its a new collection

#Fill the witnesses with the local payment witness, must be a normal cli skey
echo -e "\e[0mAdding the payment witness from a local payment address '\e[33m${regPayName}.skey\e[0m' ...\n"
tmpWitness=$(${cardanocli} transaction witness --tx-body-file ${txBodyFile} --signing-key-file ${regPayName}.skey ${magicparam} --out-file /dev/stdout)
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
poolJSON=$(jq ".regWitness.witnesses.\"${regPayName}\".witness = ${tmpWitness}" <<< ${poolJSON}); #include the witnesses in the poolJSON if its a new collection

#Fill the witnesses with the local owner accounts, if you wanna do this in multiple steps you should set ownerWitness: "external" in the pool.json
for (( tmpCnt=0; tmpCnt<${ownerCnt}; tmpCnt++ ))
do

  ownerName=$(jq -r .poolOwner[${tmpCnt}].ownerName <<< ${poolJSON})
  ownerWitness=$(jq -r .poolOwner[${tmpCnt}].ownerWitness <<< ${poolJSON});

  if [[ "${ownerWitness}" == null || "${ownerWitness}" == "" || "${ownerWitness^^}" == "LOCAL" ]]; then #local account process now

    if [[ $(jq ".regWitness.witnesses.\"${ownerName}.staking\".witness | length" <<< ${poolJSON}) == 0 ]]; then #only process witness if the entry in the witness collection is empty

	#Fill the witnesses with the local owner witness
	if [ -f "${ownerName}.staking.skey" ]; then #key is a normal one
	        echo -e "\e[0mAdding the owner witness from a local signing key '\e[33m${ownerName}.skey\e[0m' ...\n"
	        tmpWitness=$(${cardanocli} transaction witness --tx-body-file ${txBodyFile} --signing-key-file ${ownerName}.staking.skey ${magicparam} --out-file /dev/stdout)
	        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
	        poolJSON=$(jq ".regWitness.witnesses.\"${ownerName}.staking\".witness = ${tmpWitness}" <<< ${poolJSON}); #include the witnesses in the poolJSON

	elif [ -f "${ownerName}.staking.hwsfile" ]; then #key is a hardware wallet
	        tmpWitnessFile="${tempDir}/$(basename ${poolName}).tmp.witness"
	        echo -e "\e[0mAdding the owner witness from a local Hardware-Wallet key '\e[33m${ownerName}.hwsfile\e[0m' ..."
	        #echo -e "\e[33mPlease open the Cardano-App on your Hardware-Wallet to approve the action of the owner witness ... \e[0m\n"
		#if [[ "$(which ${cardanohwcli})" == "" ]]; then echo -e "\n\e[35mError - cardano-hw-cli binary not found, please install it first and set the path to it correct in the 00_common.sh, common.inc or $HOME/.common.inc !\e[0m\n"; exit 1; fi
		start_HwWallet; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
		tmp=$(${cardanohwcli} shelley transaction witness --tx-body-file ${txBodyFile} --hw-signing-file ${ownerName}.staking.hwsfile ${magicparam} --out-file ${tmpWitnessFile} 2> /dev/stdout)
	        if [[ "${tmp^^}" == *"ERROR"* ]]; then echo -e "\e[35m${tmp}\e[0m\n"; exit 1; else echo -e "\e[32mDONE\e[0m"; fi
	        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

		#Doing a txWitness Hack, because currently the ledger-fw is not using the right Era - Must be removed later when corrected!
		tmpWitness=$(cat ${tmpWitnessFile})
		if [[ "$(jq -r .type < ${txBodyFile})" == "TxBodyMary" ]]; then tmpWitness=$(jq ".type = \"TxWitness MaryEra\"" <<< ${tmpWitness}); fi
		if [[ "$(jq -r .type < ${txBodyFile})" == "TxBodyAllegra" ]]; then tmpWitness=$(jq ".type = \"TxWitness AllegraEra\"" <<< ${tmpWitness}); fi
	        poolJSON=$(jq ".regWitness.witnesses.\"${ownerName}.staking\".witness = ${tmpWitness}" <<< ${poolJSON}); #include the witnesses in the poolJSON

	else
	echo -e "\e[35mError - Owner Signing Key for \"${ownerName}\" not found. No ${ownerName}.staking.skey/hwsfile found !${tmp}\e[0m\n"; exit 1;
	fi
    fi

  #elif [[ "${ownerName}" == "${rewardsName}" ]]; then poolJSON=$(jq ".regWitness.witnesses.\"${rewardsName}.staking\".witness = {process: \"external\"}" <<< ${poolJSON}); #mark rewards witness to not process because external

  fi

done

file_unlock ${poolFile}.pool.json
echo "${poolJSON}" > ${poolFile}.pool.json
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
file_lock ${poolFile}.pool.json

fi # regWitnessID was empty / new witness collection

#--------------------------------------------------------------
# witness collection with the local files/hardware wallets was collected and writen in the poolJSON
# we land here also if a witness was created before

regWitnessID=$(jq -r ".regWitness.id" <<< ${poolJSON})
regWitnessDate=$(date --date="@${regWitnessID}" -R)
regWitnessType=$(jq -r ".regWitness.type" <<< ${poolJSON})
regWitnessTxBody=$(jq -r ".regWitness.txBody" <<< ${poolJSON})
regWitnessHardwareWalletIncluded=$(jq -r ".regWitness.hardwareWalletIncluded" <<< ${poolJSON})
regWitnessPayAmount=$(jq -r ".regWitness.regPayAmount" <<< ${poolJSON})
regWitnessPayReturn=$(jq -r ".regWitness.regPayReturn" <<< ${poolJSON})

echo -e "Lovelaces you have to pay: \e[32m $(convertToADA ${regWitnessPayAmount}) ADA / ${regWitnessPayAmount} lovelaces\e[0m"
echo -e " Lovelaces to be returned: \e[32m $(convertToADA ${regWitnessPayReturn}) ADA / ${regWitnessPayReturn} lovelaces\e[0m"
echo
echo -e "\e[0mThis will be a: \e[32m${regWitnessType}\e[0m";
echo
echo -e "\e[0mWitness-Collection with ID \e[32m${regWitnessID}\e[0m, lets check about the needed Witnesses for the \e[32m${regWitnessType}\e[0m:\n"
echo -e "\e[0mWitness-Collection creation date: \e[32m${regWitnessDate}\e[0m"
echo

missingWitness=""	#will be set to yes if we have at least one missing witness
witnessCnt=$(jq ".regWitness.witnesses | length" <<< ${poolJSON})
for (( tmpCnt=0; tmpCnt<${witnessCnt}; tmpCnt++ ))
do

  witnessName=$(jq -r ".regWitness.witnesses | keys_unsorted[${tmpCnt}]" <<< ${poolJSON})

  if [[ $(jq ".regWitness.witnesses.\"${witnessName}\".witness | length" <<< ${poolJSON}) -gt 0 ]]; then #witness data is in the json
	echo -e "\e[32m[ Ready ]\e[90m ${witnessName} \e[0m"
  else
	missingWitness="yes"
	extWitnessFile="${poolFile}_$(basename ${witnessName} .staking)_${regWitnessID}.witness"
        extWitness=$(jq . <<< "{ \"id\": ${regWitnessID}, \"date-created\": \"${regWitnessDate}\", \"ttl\": ${ttl}, \"type\": \"${regWitnessType}\", \"poolFile\": \"${poolFile}\", \"poolMetaTicker\": \"${poolMetaTicker}\", \"signing-name\": \"${witnessName}\", \"signing-vkey\": $(cat ${witnessName}.vkey), \"txBody\": ${regWitnessTxBody}, \"signedWitness\": {}, \"date-signed\": {} }")
	checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
	if [ ! -f "${extWitnessFile}" ]; then #Write it only if file is not present
		echo "${extWitness}" > ${extWitnessFile}
		checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
		echo -e "\e[35m[Missing]\e[90m ${witnessName} \e[0m-> Sign and add it via script \e[33m05d_poolWitness.sh\e[0m and the specific WitnessTransferFile:\e[33m ${extWitnessFile}\e[0m"
                else
                echo -e "\e[35m[Missing]\e[90m ${witnessName} \e[0m-> Sign and add it via script \e[33m05d_poolWitness.sh\e[0m and the specific WitnessTransferFile:\e[33m ${extWitnessFile} \e[35m(still exists!?) \e[0m"
	fi
  fi


done

echo
if [[ "${missingWitness}" == "yes" ]]; then

	if ${offlineMode}; then #In offlinemode, ask about adding each witnessfile to the offlineTransfer.json

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

echo -e "\n\e[35mThere are missing witnesses for this transaction, please sign and add them via the script \e[33m05d_poolWitness.sh sign/add\e[0m\nRe-Run this script if you have collected all witnesses.\n\n";
echo -e "\e[35mIf you wanna clean the witnesses for this poolFile (start over), please clear them via the script \e[33m05d_poolWitness.sh clear ${poolFile}\e[0m\n\n";

exit 1;
fi

#------------------------------------------------------------------------
# All witnesses are present, so now lets assemble the transaction together
#

txFile="${tempDir}/$(basename ${poolName}).tx"

echo -e "\e[0mAssemble the Transaction with the payment \e[32m${regPayName}.skey\e[0m, node\e[32m ${poolName}.node.skey\e[0m and all PoolOwner Witnesses: \e[32m ${txFile} \e[90m"
echo

witnessString=; witnessContent="";
witnessCnt=$(jq ".regWitness.witnesses | length" <<< ${poolJSON})
for (( tmpCnt=0; tmpCnt<${witnessCnt}; tmpCnt++ ))
do
  witnessName=$(jq -r ".regWitness.witnesses | keys_unsorted[${tmpCnt}]" <<< ${poolJSON})
  witnessContent=$(jq -r ".regWitness.witnesses.\"${witnessName}\".witness" <<< ${poolJSON})
  tmpWitnessFile="${tempDir}/$(basename ${poolName}).witness_${tmpCnt}.tx"
  echo "${witnessContent}" > ${tmpWitnessFile}
  witnessString="${witnessString}--witness-file ${tmpWitnessFile} "
done

#Assemble the transaction
rm ${txFile} 2> /dev/null
${cardanocli} ${subCommand} transaction assemble --tx-body-file <(echo ${regWitnessTxBody}) ${witnessString} --out-file ${txFile}
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
cat ${txFile} | head -n 6   #only show first 6 lines
echo

#Do temporary witness file cleanup
for (( tmpCnt=0; tmpCnt<${witnessCnt}; tmpCnt++ ))
do
  tmpWitnessFile="${tempDir}/$(basename ${poolName}).witness_${tmpCnt}.tx"
  rm -f ${tmpWitnessFile}
done

#Read out the POOL-ID
poolIDhex=$(${cardanocli} ${subCommand} stake-pool id --cold-verification-key-file ${poolName}.node.vkey --output-format hex)	#New method since 1.23.0
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

poolIDbech=$(${cardanocli} ${subCommand} stake-pool id --cold-verification-key-file ${poolName}.node.vkey)      #New method since 1.23.0
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

echo -e "\e[0mPool-ID:\e[32m ${poolIDhex} / ${poolIDbech} \e[90m"
echo

#Show a warning to respect the pledge amount
if [[ ${poolPledge} -gt 0 ]]; then echo -e "\e[35mATTENTION - You're registered Pledge will be set to ${poolPledge} lovelaces, please respect it with the sum of all registered owner addresses!\e[0m\n"; fi

#Show a message about the registration type
echo -e "\e[0mThis will be a: \e[32m${regWitnessType}\e[0m\n";
offlineRegistrationType="${regWitnessType}"; #Just as Type info for the offline file, same as the regWitnessType

if ask "\e[33mDoes this look good for you? Do you have enough pledge in your owner account(s), continue and register on chain ?" N; then
        echo

        if ${onlineMode}; then  #onlinesubmit
			        echo -ne "\e[0mSubmitting the transaction via the node..."
			        ${cardanocli} ${subCommand} transaction submit --tx-file ${txFile} --cardano-mode ${magicparam}
			        #No error, so lets update the pool JSON file with the date and file the certFile was registered on the blockchain
			        if [[ $? -eq 0 ]]; then
			        file_unlock ${poolFile}.pool.json
			        newJSON=$(cat ${poolFile}.pool.json | jq ". += {regEpoch: \"${currentEPOCH}\"}" | jq ". += {regSubmitted: \"$(date -R)\"}" | jq "del (.regWitness)")
			        echo "${newJSON}" > ${poolFile}.pool.json
			        file_lock ${poolFile}.pool.json
			        echo -e "\e[32mDONE\n"

				#Delete the just used RegistrationCertificat so it can't be submitted again as a mistake, build one again with 05a first
				file_unlock ${regCertFile}
				rm ${regCertFile}

			        else
			        echo -e "\n\n\e[35mERROR (Code $?) !\e[0m"; exit 1;
			        fi
                                echo
                                echo -e "\e[0mStakepool Info JSON:\e[32m ${poolFile}.pool.json \e[90m"
                                cat ${poolFile}.pool.json
                                echo

				#Display information to manually register the OwnerDelegationCertificates on the chain if a hardware-wallet is involved. With only cli based staking keys, we can include all the delegation certificates in one transaction
				if [[ "${regWitnessHardwareWalletIncluded}" == "yes" ]]; then
				        echo -e "\n\e[33mThere is at least one Hardware-Wallet involved, so you have to register the DelegationCertificate for each Owner in additional transactions after the ${regWitnessType} !\e[0m\n"; fi

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
				        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
					echo
					fi
				fi

                                #Ask about attaching the extended-metadata file into the offlineJSON, because we're cool :-)
                                fileToAttach="${poolFile}.extended-metadata.json"
                                if [ -f "${fileToAttach}" ]; then
                                        if ask "\e[33mInclude the '${fileToAttach}' into '$(basename ${offlineFile})' to transfer it in one step?" N; then
                                        offlineJSON=$( jq ".files.\"${fileToAttach}\" += { date: \"$(date -R)\", size: \"$(du -b ${fileToAttach} | cut -f1)\", base64: \"$(base64 -w 0 ${fileToAttach})\" }" <<< ${offlineJSON});
					checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
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
			                                newJSON=$(cat ${poolFile}.pool.json | jq ". += {regEpoch: \"${currentEPOCH}\"}" | jq ". += {regSubmitted: \"$(date -R) (only offline, no proof)\"}" | jq "del (.regWitness)")
			                                echo "${newJSON}" > ${poolFile}.pool.json
			                                file_lock ${poolFile}.pool.json
                                                        showOfflineFileInfo;
                                                        echo -e "\e[33mTransaction txJSON has been stored in the '$(basename ${offlineFile})'.\nYou can now transfer it to your online machine for execution.\e[0m\n";
							#Display information to manually register the OwnerDelegationCertificates on the chain if a hardware-wallet is involved. With only cli based staking keys, we can include all the delegation certificates in one transaction
							if [[ "${regWitnessHardwareWalletIncluded}" == "yes" ]]; then echo -e "\n\e[33mThere is at least one Hardware-Wallet involved, so you have to register the DelegationCertificate for each Owner in additional transactions after the ${regWitnessType} !\e[0m\n"; fi

			                                #Delete the just used RegistrationCertificat so it can't be submitted again as a mistake, build one again with 05a first
			                                file_unlock ${regCertFile}
			                                rm ${regCertFile}

                                                 else
                                                        echo -e "\e[35mERROR - Could not verify the written data in the '$(basename ${offlineFile})'. Retry again or generate a new '$(basename ${offlineFile})'.\e[0m\n";
                                fi

        fi


else #ask: Does this look good for you? Do you have enough pledge in your owner account(s), continue and register on chain ?

	#Ok, if said not, lets ask if the collected witnesses should be deleted from the poolFile
	if ask "\n\e[33mDo you wanna delete the witness collection from the ${poolFile}.pool.json ?" N; then
                #Clears the witnesscollection in the ${poolFile}
                poolJSON=$(cat ${poolFile}.pool.json)   #Read PoolJSON File into poolJSON variable for modifications within this script
                if [[ $( jq -r ".regWitness | length" <<< ${poolJSON}) -gt 0 ]]; then
                                poolJSON=$( jq "del (.regWitness)" <<< ${poolJSON})
                                file_unlock ${poolFile}.pool.json
                                echo "${poolJSON}" > ${poolFile}.pool.json
                                checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
                                file_unlock ${poolFile}.pool.json
                else
                echo -e "\n\e[0mThere are no witnesses in the ${poolFile} !\e[0m\n";
                fi
	fi


fi

echo -e "\e[0m\n"

