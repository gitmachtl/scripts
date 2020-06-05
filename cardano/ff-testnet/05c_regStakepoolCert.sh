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
if [[ $# -gt 0 && ! $1 == "" ]]; then poolFile=$1; else echo "ERROR - Usage: $(basename $0) <PoolNodeName> [optional keyword FORCE to force a registration instead of a re-Registration]"; exit 2; fi

#Check if referenced JSON file exists
if [ ! -f "${poolFile}.pool.json" ]; then echo -e "\n\e[35mERROR - ${poolFile}.pool.json does not exist! Please create it first with script 05a.\e[0m"; exit 2; fi

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

#Load regSubmitted value from the pool.json. If there is an entry, than do a Re-Registration (changes the Fee!)
regSubmitted=$(jq -r .regSubmitted ${poolFile}.pool.json 2> /dev/null)
if [[ "${regSubmitted}" == null ]]; then regSubmitted=""; fi

#Force registration instead of re-registration via optional command line command "force"
forceParam=$2
if [[ ${forceParam^^} == "FORCE" ]]; then regSubmitted=""; fi #progress like no regSubmitted before



#Checks for needed files
if [ ! -f "${ownerName}.deleg.cert" ]; then echo -e "\n\e[34mERROR - \"${ownerName}.deleg.cert\" does not exist! Please create it first with script 05b.\e[0m"; exit 2; fi
if [ ! -f "${regCertFile}" ]; then echo -e "\n\e[34mERROR - \"${regCertFile}\" does not exist! Please create it first with script 05a.\e[0m"; exit 2; fi
if [ ! -f "${ownerName}.payment.addr" ]; then echo -e "\n\e[34mERROR - \"${ownerName}.payment.addr\" does not exist! Please create it first with script 03a.\e[0m"; exit 2; fi
if [ ! -f "${ownerName}.payment.skey" ]; then echo -e "\n\e[34mERROR - \"${ownerName}.payment.skey\" does not exist! Please create it first with script 03a.\e[0m"; exit 2; fi
if [ ! -f "${ownerName}.staking.skey" ]; then echo -e "\n\e[34mERROR - \"${ownerName}.staking.skey\" does not exist! Please create it first with script 03a.\e[0m"; exit 2; fi
if [ ! -f "${rewardsName}.staking.skey" ]; then echo -e "\n\e[34mERROR - \"${rewardsName}.staking.skey\" does not exist! Please create it first with script 03a.\e[0m"; exit 2; fi
if [ ! -f "${poolName}.node.skey" ]; then echo -e "\n\e[34mERROR - \"${poolName}.node.skey\" does not exist! Please create it first with script 04a.\e[0m"; exit 2; fi
if [ ! -f "${poolName}.node.vkey" ]; then echo -e "\n\e[34mERROR - \"${poolName}.node.vkey\" does not exist! Please create it first with script 04a.\e[0m"; exit 2; fi


#-------------------------------------------------------------------------


#get values to register the staking address on the blockchain
currentTip=$(get_currentTip)
ttl=$(get_currentTTL)
currentEPOCH=$(get_currentEpoch)

echo
echo -e "\e[0m(Re)Register StakePool Certificate\e[32m ${regCertFile}\e[0m and PoolOwner Delegation Certificate\e[32m ${ownerName}.deleg.cert\e[0m with funds from Address\e[32m ${ownerName}.payment.addr\e[0m:"
echo
echo -e "\e[0m        Owner Stake:\e[32m ${ownerName}.staking.vkey \e[0m"
echo -e "\e[0m      Rewards Stake:\e[32m ${rewardsName}.staking.vkey \e[0m"
echo -e "\e[0m             Pledge:\e[32m ${poolPledge} \e[90mlovelaces"
echo -e "\e[0m               Cost:\e[32m ${poolCost} \e[90mlovelaces"
echo -e "\e[0m             Margin:\e[32m ${poolMargin} \e[0m"
echo
echo -e "\e[0m      Current EPOCH:\e[32m ${currentEPOCH}\e[0m"
echo -e "\e[0mCurrent Slot-Height:\e[32m ${currentTip}\e[0m (setting TTL to ${ttl})"

rxcnt="1"               #transmit to one destination addr. all utxos will be sent back to the fromAddr

sendFromAddr=$(cat ${ownerName}.payment.addr)
sendToAddr=$(cat ${ownerName}.payment.addr)

echo
echo -e "Pay fees from Address\e[32m ${ownerName}.payment.addr\e[0m: ${sendFromAddr}"
echo


#Get UTX0 Data for the sendFromAddr
utx0=$(${cardanocli} shelley query utxo --address ${sendFromAddr} ${magicparam})
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
fromINDEX=$(echo ${utx0entry} | awk '{print $2}')
sourceLovelaces=$(echo ${utx0entry} | awk '{print $3}')
echo -e "HASH: ${fromHASH}\t INDEX: ${fromINDEX}\t LOVELACES: ${sourceLovelaces}"

totalLovelaces=$((${totalLovelaces}+${sourceLovelaces}))
txInString=$(echo -e "${txInString} --tx-in ${fromHASH}#${fromINDEX}")

done < <(printf "${utx0}\n" | tail -n ${txcnt})


echo -e "Total lovelaces in UTX0:\e[32m  ${totalLovelaces} lovelaces \e[90m"
echo

#Getting protocol parameters from the blockchain, calculating fees
${cardanocli} shelley query protocol-parameters ${magicparam} > protocol-parameters.json

#cardano-cli shelley transaction calculate-min-fee \
#    --tx-in-count 1 \
#    --tx-out-count 1 \
#    --ttl 430000 \
#    --testnet-magic 42 \
#    --signing-key-file pay.skey \
#    --signing-key-file node.skey \
#    --signing-key-file stake.skey \
#    --certificate pool.cert \
#    --certificate deleg.cert \
#    --protocol-params-file params.json

#Make a variable for all signing keys, also depenting if we have to add a different rewards staking address or not
signingKeys="--signing-key-file ${ownerName}.payment.skey --signing-key-file ${poolName}.node.skey --signing-key-file ${ownerName}.staking.skey"
if [[ ! "${ownerName}" == "${rewardsName}" ]]; then signingKeys="${signingKeys} --signing-key-file ${rewardsName}.staking.skey"; fi

fee=$(${cardanocli} shelley transaction calculate-min-fee --protocol-params-file protocol-parameters.json --tx-in-count ${txcnt} --tx-out-count ${rxcnt} --ttl ${ttl} ${magicparam} ${signingKeys} --certificate ${regCertFile} --certificate ${ownerName}.deleg.cert | awk '{ print $2 }')
echo -e "\e[0mMinimum transfer Fee for ${txcnt}x TxIn & ${rxcnt}x TxOut & 2x Certificate: \e[32m ${fee} lovelaces \e[90m"

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

txBodyFile="${tempDir}/${ownerName}.txbody"
txFile="${tempDir}/${ownerName}.tx"

echo
echo -e "\e[0mBuilding the unsigned transaction body with \e[32m ${regCertFile}\e[0m and PoolOwner Delegation Certificate\e[32m ${ownerName}.deleg.cert\e[0m certificates: \e[32m ${txBodyFile} \e[90m"
echo

#Building unsigned transaction body
${cardanocli} shelley transaction build-raw ${txInString} --tx-out ${sendToAddr}+${lovelacesToSend} --ttl ${ttl} --fee ${fee} --tx-body-file ${txBodyFile} --certificate ${regCertFile} --certificate ${ownerName}.deleg.cert

cat ${txBodyFile} | head -n 6   #only show first 6 lines
echo

echo -e "\e[0mSign the unsigned transaction body with the \e[32m${ownerName}.payment.skey\e[0m,\e[32m ${ownerName}.staking.skey (rewards ${rewardsName}.staking.skey)\e[0m & \e[32m${poolName}.node.skey\e[0m Keys: \e[32m ${txFile} \e[90m"
echo

#Sign the unsigned transaction body with the SecureKey
${cardanocli} shelley transaction sign --tx-body-file ${txBodyFile} ${signingKeys} --tx-file ${txFile} ${magicparam}

cat ${txFile} | head -n 6   #only show first 6 lines
echo

#Read out the POOL-ID and store it in the ${poolName}.pool.json
#poolID=$(cat ${ownerName}.deleg.cert | tail -n 1 | cut -c 6-) #Old method
poolID=$(${cardanocli} shelley stake-pool id --verification-key-file ${poolName}.node.vkey)	#New method since 1.13.0

file_unlock ${poolFile}.pool.json
newJSON=$(cat ${poolFile}.pool.json | jq ". += {poolID: \"${poolID}\"}")
echo "${newJSON}" > ${poolFile}.pool.json
file_lock ${poolFile}.pool.json

echo -e "\e[0mStakepool Info JSON:\e[32m ${poolFile}.pool.json \e[90m"
cat ${poolFile}.pool.json
echo

echo -e "\e[0mPool-ID:\e[32m ${poolID} \e[90m"
echo

#Show a warning, if the minimum Pledge will be not respected after the pool registration
if [[ ${lovelacesToSend} -lt ${poolPledge} ]]; then echo -e "\e[35mWARNING - You're registered Pledge will not be respected after registration. Not enough stake on the payment Addr!\e[0m\n"; fi


#Show a message if it's a reRegistration
if [[ ! "${regSubmitted}" == "" ]]; then   #pool registered before
				  echo -e "\e[35mThis will be a Pool Re-Registration\e[0m\n";
fi

if ask "\e[33mDoes this look good for you? Do you have enough pledge in your ${ownerName}.payment account, continue and register on chain ?" N; then
        echo
        echo -ne "\e[0mSubmitting the transaction via the node..."
        ${cardanocli} shelley transaction submit --tx-file ${txFile} ${magicparam}

	#No error, so lets update the pool JSON file with the date and file the certFile was registered on the blockchain
	if [[ $? -eq 0 ]]; then
        file_unlock ${poolFile}.pool.json
        newJSON=$(cat ${poolFile}.pool.json | jq ". += {regEpoch: \"${currentEPOCH}\"}" | jq ". += {regSubmitted: \"$(date)\"}")
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

