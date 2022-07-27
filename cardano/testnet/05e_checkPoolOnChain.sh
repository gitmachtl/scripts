#!/bin/bash

# Script is brought to you by ATADA_Stakepool, Telegram @atada_stakepool

#load variables and functions from common.sh
. "$(dirname "$0")"/00_common.sh


#Check for the given parameter count
if [[ $# -eq 1 && $1 != "" ]]; then
	poolNodeName="$(dirname $1)/$(basename $(basename $(basename $(basename $1 .json) .id) .id-bech) .pool)"; poolNodeName=${poolNodeName/#.\//}
	poolID=${1,,}
 				else
	echo -e "ERROR - Usage: $(basename $0) <PoolNodeName or PoolID-Hex \"5e12e18...\" or PoolID-Bech \"pool1...\">\n"; exit 1
fi


#Node must be fully synced for the online query of the OpCertCounter, show info if starting in offline mode
if ${onlineMode}; then
        #check that the node is fully synced, otherwise the opcertcounter query could return a false state
        if [[ $(get_currentSync) != "synced" ]]; then echo -e "\e[35mError - Node not fully synced !\e[0m\n"; exit 2; fi
else
#Check can only be done in online mode
        echo -e "\e[35mYou have to be in ONLINE MODE to do this!\e[0m\n"; exit 1;
fi



#Check if the provided Pool-Identification is a Hex-PoolID(length56), a Bech32-PoolID(length56 and starting with pool1) or a pool.id / pool.id-bech / pool.json File
if [[ "${poolID//[![:xdigit:]]}" == "${poolID}" && ${#poolID} -eq 56 ]]; then #parameter is a hex-poolid

        echo -e "\e[0mChecking OnChain-Status for HEX-PoolID:\e[32m ${poolID}\e[0m"
        echo
	#converting the Hex-PoolID into a Bech-PoolID
	poolIDBech=$(${bech32_bin} "pool" <<< ${poolID} | tr -d '\n')
        checkError "$?"; if [ $? -ne 0 ]; then echo -e "\n\e[35mERROR - Could not convert the given Hex-PoolID \"${poolID}\" into a Bech Pool-ID.\e[0m\n"; exit 1; fi
        echo -e "\e[0mConverted to the Bech-PoolID for verification:\e[32m ${poolIDBech}\e[0m"
        echo

elif [[ "${poolID:0:5}" == "pool1" && ${#poolID} -eq 56 ]]; then #parameter is most likely a bech32-poolid

        #lets do some further testing by converting the bech32 pool-id into a hex-pool-id
        tmp=$(${bech32_bin} 2> /dev/null <<< "${poolID}") #will have returncode 0 if the bech was valid
        if [ $? -ne 0 ]; then echo -e "\n\e[35mERROR - \"${poolID}\" is not a valid Bech Pool-ID.\e[0m\n"; exit 1; fi
	poolIDBech=${poolID}

elif [ -f "${poolNodeName}.pool.id-bech" ]; then #there is a pool.id-bech file present, try to use this

        echo -e "\e[0mChecking the Pool-ID-Bech File for a valid PoolID:\e[32m ${poolNodeName}.pool.id-bech\e[0m"
        echo
	#read in the Bech-PoolID from the pool.id-bech file
	poolID=$(cat "${poolNodeName}.pool.id-bech" | tr -d '\n')
	#check if the content is a valid bech
	if [[ "${poolID:0:5}" == "pool1" && ${#poolID} -eq 56 ]]; then #parameter is most likely a bech32-poolid
	        #lets do some further testing by converting the bech32 pool-id into a hex-pool-id
	        tmp=$(${bech32_bin} 2> /dev/null <<< "${poolID}") #will have returncode 0 if the bech was valid
	        if [ $? -ne 0 ]; then echo -e "\n\e[35mERROR - The content of the Pool-ID-Bech File \"${poolNodeName}.pool.id-bech\" is not a valid Bech-PoolID.\e[0m\n"; exit 1; fi
		poolIDBech=${poolID}
	        echo -e "\e[0mThe Pool-ID File contains the following Bech-PoolID:\e[32m ${poolIDBech}\e[0m"
		echo
	else
		echo -e "\n\e[35mERROR - The content of the Pool-ID-Bech File \"${poolNodeName}.pool.id\" is not a valid Hex-PoolID.\e[0m\n";
	fi

elif [ -f "${poolNodeName}.pool.id" ]; then #there is a pool.id file present, try to use this

        echo -e "\e[0mChecking the Pool-ID File for a valid PoolID:\e[32m ${poolNodeName}.pool.id\e[0m"
        echo
	#read in the Hex-PoolID from the pool.id file
	poolID=$(cat "${poolNodeName}.pool.id" | tr -d '\n')
	#check if the content is a valid pool hex
	if [[ "${poolID//[![:xdigit:]]}" == "${poolID}" && ${#poolID} -eq 56 ]]; then
	        echo -e "\e[0mThe Pool-ID File contains the following HEX-PoolID:\e[32m ${poolID}\e[0m"
		echo
		#converting the Hex-PoolID into a Bech-PoolID
		poolIDBech=$(${bech32_bin} "pool" <<< ${poolID} | tr -d '\n')
	        checkError "$?"; if [ $? -ne 0 ]; then echo -e "\n\e[35mERROR - Could not convert the given Pool-ID File \"${poolNodeName}.pool.id\" into a Bech Pool-ID.\e[0m\n"; exit 1; fi
	        echo -e "\e[0mConverted to the Bech-PoolID for verification:\e[32m ${poolIDBech}\e[0m"
	        echo
	else
		echo -e "\n\e[35mERROR - The content of the Pool-ID File \"${poolNodeName}.pool.id\" is not a valid Hex-PoolID.\e[0m\n"; exit 1;
	fi

elif [ -f "${poolNodeName}.pool.json" ]; then #there is a pool.json file present, try to use this

        echo -e "\e[0mChecking the Pool-File for a Pool-ID:\e[32m ${poolNodeName}.pool.json\e[0m"
        echo
	#read out the Bech and Hex Pool-ID entries in the pool.json file
	poolID=$(jq -r ".poolID" "${poolNodeName}.pool.json" 2> /dev/null)
	poolIDBech=$(jq -r ".poolIDbech" "${poolNodeName}.pool.json" 2> /dev/null)

	#Checking out the Bech Pool-ID entry
        if [[ "${poolIDBech:0:5}" == "pool1" && ${#poolIDBech} -eq 56 ]]; then #parameter is most likely a bech32-poolid
                #lets do some further testing by converting the bech32 pool-id into a hex-pool-id
                tmp=$(${bech32_bin} 2> /dev/null <<< "${poolIDBech}") #will have returncode 0 if the bech was valid
                if [ $? -ne 0 ]; then echo -e "\n\e[35mERROR - The content of the poolIDBech entry in your \"${poolNodeName}.pool.json\" is not a valid Bech-PoolID. This is pretty strange, please check it!\e[0m\n"; exit 1; fi
                echo -e "\e[0mThe Pool-File contains the following Bech-PoolID:\e[32m ${poolIDBech}\e[0m"
                echo

	#Checking out the Hex Pool-ID entry
	elif [[ "${poolID//[![:xdigit:]]}" == "${poolID}" && ${#poolID} -eq 56 ]]; then
                echo -e "\e[0mThe Pool-File contains the following HEX-PoolID:\e[32m ${poolID}\e[0m"
                echo
                #converting the Hex-PoolID into a Bech-PoolID
                poolIDBech=$(${bech32_bin} "pool" <<< ${poolID} | tr -d '\n')
                checkError "$?"; if [ $? -ne 0 ]; then echo -e "\n\e[35mERROR - Could not convert the Hex Pool-ID \"${poolID}\" into a Bech Pool-ID.\e[0m\n"; exit 1; fi
                echo -e "\e[0mConverted to the Bech-PoolID for verification:\e[32m ${poolIDBech}\e[0m"
                echo
        else
                echo -e "\n\e[35mERROR - Your Pool-File \"${poolNodeName}.pool.json\" does not contain a valid Hex- or Bech-Pool-ID.\e[0m\n"; exit 1;
        fi

else
        echo -e "\n\e[35mERROR - Could not resolve your given parameter into a Hex-Pool-ID, Bech-Pool-ID.\nAlso i cannot get the information for the ${poolNodeName}.pool.id, ${poolNodeName}.pool.id-bech or ${poolNodeName}.pool.json file !\e[0m"; exit 1
fi



#OK, we should have a well formated Bech-Pool-ID in the poolIDBech variable now

echo -e "\e[0mChecking OnChain-Status for Bech-PoolID:\e[32m ${poolIDBech}\e[0m"
echo

#check ledger-state
showProcessAnimation "Query-Ledger-State: " &
poolsInLedger=$(${cardanocli} query stake-pools ${magicparam} 2> /dev/null); checkError "$?"; if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\n\e[35mERROR - Could not query stake-pools from the chain.\e[0m\n"; exit 1; fi
stopProcessAnimation;

#now lets see how often the poolIDBech is listed: 0->Not on the chain, 1->On the chain, any other value -> ERROR
poolInLedgerCnt=$(grep  "${poolIDBech}" <<< ${poolsInLedger} | wc -l)

if [[ ${poolInLedgerCnt} -eq 1 ]]; then echo -e "\e[32mYES, the Pool-ID is in the ledgers stake-pool list!\e[0m";
elif [[ ${poolInLedgerCnt} -eq 0 ]]; then echo -e "\e[33mNO, the Pool-ID is NOT in the ledgers stake-pool list!\e[0m";
else echo -e "\e[35mERROR - The Pool-ID is more than once in the ledgers stake-pool list, this shouldn't be possible!\e[0m"
fi

echo -e "\e[0m\n"
