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
  2 ) deregPayName="$2";
      poolFile="$1";;
  * ) cat >&2 <<EOF
ERROR - Usage: $(basename $0) <PoolNodeName> <PaymentAddrForDeRegistration>
EOF
  exit 1;; esac

#Check if referenced JSON file exists
if [ ! -f "${poolFile}.pool.json" ]; then echo -e "\n\e[34mERROR - ${poolFile}.pool.json does not exist! Please create a minimal first with script 07a.\e[0m"; exit 2; fi

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
deregCertFile=$(readJSONparam "deregCertFile"); if [[ ! $? == 0 ]]; then exit 1; fi

#Checks for needed files
if [ ! -f "${deregCertFile}" ]; then echo -e "\n\e[34mERROR - \"${deregCertFile}\" does not exist! Please create it first with script 05d.\e[0m"; exit 2; fi
if [ ! -f "${poolName}.node.skey" ]; then echo -e "\n\e[34mERROR - \"${poolName}.node.skey\" does not exist! Please create it first with script 04a.\e[0m"; exit 2; fi
if [ ! -f "${deregPayName}.addr" ]; then echo -e "\n\e[35mERROR - \"${deregPayName}.addr\" does not exist! Please create it first with script 03a.\e[0m"; exit 1; fi
if [ ! -f "${deregPayName}.skey" ]; then echo -e "\n\e[35mERROR - \"${deregPayName}.skey\" does not exist! Please create it first with script 03a.\e[0m"; exit 1; fi

#-------------------------------------------------------------------------

echo
echo -e "\e[0mDe-Register (retire) StakePool Certificate\e[32m ${deregCertFile}\e[0m with funds from Address\e[32m ${deregPayName}.addr\e[0m:"
echo

#get live values
currentTip=$(get_currentTip)
ttl=$(get_currentTTL)
currentEPOCH=$(get_currentEpoch)

echo -e "Current Slot-Height:\e[32m ${currentTip}\e[0m (setting TTL to ${ttl})"

rxcnt="1"               #transmit to one destination addr. all utxos will be sent back to the fromAddr

sendFromAddr=$(cat ${deregPayName}.addr); check_address "${sendFromAddr}";
sendToAddr=$(cat ${deregPayName}.addr); check_address "${sendToAddr}";

echo
echo -e "Pay fees from Address\e[32m ${deregPayName}.addr\e[0m: ${sendFromAddr}"
echo


#Get UTX0 Data for the sendFromAddr
utx0=$(${cardanocli} shelley query utxo --address ${sendFromAddr} ${magicparam}); checkError "$?";
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

#Make a variable for all signing keys
signingKeys="--signing-key-file ${deregPayName}.skey --signing-key-file ${poolName}.node.skey"

#Generate Dummy-TxBody file for fee calculation
        txBodyFile="${tempDir}/dummy.txbody"
        rm ${txBodyFile} 2> /dev/null
        ${cardanocli} shelley transaction build-raw ${txInString} --tx-out ${sendToAddr}+0 --ttl ${ttl} --fee 0 --certificate ${deregCertFile} --out-file ${txBodyFile}
        checkError "$?"

fee=$(${cardanocli} shelley transaction calculate-min-fee --tx-body-file ${txBodyFile} --protocol-params-file protocol-parameters.json --tx-in-count ${txcnt} --tx-out-count ${rxcnt} ${magicparam} --witness-count 2 --byron-witness-count 0 | awk '{ print $1 }')
checkError "$?"

echo -e "\e[0mMinimum transfer Fee for ${txcnt}x TxIn & ${rxcnt}x TxOut & 1x Certificate: \e[32m ${fee} lovelaces \e[90m"

minDeRegistrationFund=${fee}
echo
echo -e "\e[0mMinimum funds required for de-registration (Sum of fees): \e[32m ${minDeRegistrationFund} lovelaces \e[90m"
echo

#calculate new balance for destination address
lovelacesToSend=$(( ${totalLovelaces}-${minDeRegistrationFund} ))

#Checking about minimum funds in the UTX0
if [[ ${lovelacesToSend} -lt 0 ]]; then echo -e "\e[35mNot enough funds on the payment Addr!\e[0m"; exit; fi

echo -e "\e[0mLovelaces that will be returned to payment Address (UTXO-Sum minus fees): \e[32m ${lovelacesToSend} lovelaces \e[90m"
echo

txBodyFile="${tempDir}/$(basename ${poolName}).txbody"
txFile="${tempDir}/$(basename ${poolName}).tx"

echo
echo -e "\e[0mBuilding the unsigned transaction body with\e[32m ${deregCertFile}\e[0m certificate: \e[32m ${txBodyFile} \e[90m"
echo

#Building unsigned transaction body
rm ${txBodyFile} 2> /dev/null
${cardanocli} shelley transaction build-raw ${txInString} --tx-out ${sendToAddr}+${lovelacesToSend} --ttl ${ttl} --fee ${fee} --certificate ${deregCertFile} --out-file ${txBodyFile}
checkError "$?"
cat ${txBodyFile}
echo
echo
echo -e "\e[0mSign the unsigned transaction body with the \e[32m${deregPayName}.skey\e[0m & \e[32m${poolName}.node.skey\e[0m: \e[32m ${txFile} \e[90m"
echo

#Sign the unsigned transaction body with the SecureKey
rm ${txFile} 2> /dev/null
${cardanocli} shelley transaction sign --tx-body-file ${txBodyFile} ${signingKeys} ${magicparam} --out-file ${txFile}
checkError "$?"
cat ${txFile}
echo

if ask "\e[33mDoes this look good for you? Continue ?" N; then
        echo
        echo -ne "\e[0mSubmitting the transaction via the node..."
        ${cardanocli} shelley transaction submit --tx-file ${txFile} ${magicparam}
	checkError "$?"

	#No error, so lets update the pool JSON file with the date and file the deregistration
	if [[ $? -eq 0 ]]; then
        file_unlock ${poolFile}.pool.json
        newJSON=$(cat ${poolFile}.pool.json | jq ". += {deregSubmitted: \"$(date)\"}")
	echo "${newJSON}" > ${poolFile}.pool.json
        file_lock ${poolFile}.pool.json
	echo -e "\e[32mDONE\n"
	else
	echo -e "\e[35mERROR\n"
	fi
fi

echo
echo -e "\e[0mStakepool Info JSON:\e[32m ${poolFile}.pool.json \e[90m"
cat ${poolFile}.pool.json
echo

echo -e "\e[0m\n"

