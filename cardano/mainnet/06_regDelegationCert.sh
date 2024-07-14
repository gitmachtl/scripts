#!/bin/bash

############################################################
#    _____ ____  ____     _____           _       __
#   / ___// __ \/ __ \   / ___/__________(_)___  / /______
#   \__ \/ /_/ / / / /   \__ \/ ___/ ___/ / __ \/ __/ ___/
#  ___/ / ____/ /_/ /   ___/ / /__/ /  / / /_/ / /_(__  )
# /____/_/    \____/   /____/\___/_/  /_/ .___/\__/____/
#                                    /_/
#
# Scripts are brought to you by Martin L. (ATADA Stakepool)
# Telegram: @atada_stakepool   Github: github.com/gitmachtl
#
############################################################

#load variables and functions from common.sh
. "$(dirname "$0")"/00_common.sh


#Check command line parameter
if [ $# -lt 2 ]; then
cat >&2 <<EOF

Usage:  $(basename $0) <StakeAddressName> <Base/PaymentAddressName (paying for the registration fees)>

        [Opt: Message comment, starting with "msg: ...", | is the separator]
        [Opt: encrypted message mode "enc:basic". Currently only 'basic' mode is available.]
        [Opt: passphrase for encrypted message mode "pass:<passphrase>", the default passphrase if 'cardano' is not provided]

Optional parameters:

- If you wanna attach a Transaction-Message like a short comment, invoice-number, etc with the transaction:
   You can just add one or more Messages in quotes starting with "msg: ..." as a parameter. Max. 64chars / Message
   "msg: This is a short comment for the transaction" ... that would be a one-liner comment
   "msg: This is a the first comment line|and that is the second one" ... that would be a two-liner comment, | is the separator !

   If you also wanna encrypt it, set the encryption mode to basic by adding "enc: basic" to the parameters.
   To change the default passphrase 'cardano' to you own, add the passphrase via "pass:<passphrase>"

- If you wanna attach a Metadata JSON:
   You can add a Metadata.json (Auxilierydata) filename as a parameter to send it alone with the transaction.
   There will be a simple basic check that the transaction-metadata.json file is valid.

- If you wanna attach a Metadata CBOR:
   You can add a Metadata.cbor (Auxilierydata) filename as a parameter to send it along with the transaction.
   Catalyst-Voting for example is done via the voting_metadata.cbor file.

Examples:

   $(basename $0) owner owner.payment
   -> Register the Delegation Certificate for 'owner', the wallet 'owner.payment' is paying for the transaction

   $(basename $0) owner owner.payment "msg: Delegation of owner to Stakepool xxx"
   -> Same as above, but with an additional transaction message to keep track of your transactions

EOF
exit 1;
fi

#At least 2 parameters were provided, use them
delegName="$(dirname $1)/$(basename $1 .staking)"; delegName=${delegName/#.\//};
regPayName="$(dirname $2)/$(basename $2 .addr)"; regPayName=${regPayName/#.\//};

#Check about required files: Delegation Certificate, Stake-Signing Key, Stake-Address for OnlineCheck, Payment Signing Key and Address of the payment Account
#For StakeKeyDelegation
if [ ! -f "${delegName}.deleg.cert" ]; then echo -e "\n\e[35mERROR - \"${delegName}.deleg.cert\" does not exist! Please create it first with script 05b.\n\e[0m"; exit 1; fi
if ! [[ -f "${delegName}.staking.skey" || -f "${delegName}.staking.hwsfile" ]]; then echo -e "\n\e[35mERROR - \"${delegName}.staking.skey/hwsfile\" does not exist! Please create it first with script 03a & 03b.\n\e[0m"; exit 1; fi
#For payment
if [ ! -f "${regPayName}.addr" ]; then echo -e "\n\e[35mERROR - \"${regPayName}.addr\" does not exist! Please create it first with script 03a.\n\e[0m"; exit 1; fi
if ! [[ -f "${regPayName}.skey" || -f "${regPayName}.hwsfile" ]]; then echo -e "\n\e[35mERROR - \"${regPayName}.skey\" does not exist! Please create it first with script 03a.\n\e[0m"; exit 1; fi

#Setting default variables
metafileParameter=""; metafile=""; transactionMessage="{}"; enc=""; passphrase="cardano" #Setting defaults

#Check all optional parameters about there types and set the corresponding variables
#Starting with the 3th parameter (index=2) up to the last parameter
paramCnt=$#;
allParameters=( "$@" )
for (( tmpCnt=2; tmpCnt<${paramCnt}; tmpCnt++ ))
 do
        paramValue=${allParameters[$tmpCnt]}
        #echo -n "${tmpCnt}: ${paramValue} -> "

        #Check if an additional metadata.json/.cbor was set as parameter (not a Message, not a UTXO#IDX, not empty, not a number)
        if [[ ! "${paramValue,,}" =~ ^msg:(.*)$ ]] && [[ ! "${paramValue,,}" =~ ^enc:(.*)$ ]] && [[ ! "${paramValue,,}" =~ ^pass:(.*)$ ]] && [[ ! "${paramValue,,}" =~ ^utxolimit:(.*)$ ]] && [[ ! "${paramValue,,}" =~ ^onlyutxowithasset:(.*)$ ]] && [[ ! "${paramValue,,}" =~ ^skiputxowithasset:(.*)$ ]] && [[ ! "${paramValue}" =~ ^([[:xdigit:]]+#[[:digit:]]+(\|?)){1,}$ ]] && [[ ! ${paramValue} == "" ]] && [ -z "${paramValue##*[!0-9]*}" ]; then

             metafile=${paramValue}; metafileExt=${metafile##*.}
             if [[ -f "${metafile}" && "${metafileExt^^}" == "JSON" ]]; then #its a json file
                #Do a simple basic check if the metadatum is in the 0..65535 range
                metadatum=$(jq -r "keys_unsorted[0]" "${metafile}" 2> /dev/null)
                if [[ $? -ne 0 ]]; then echo -e "\n\e[35mERROR - '${metafile}' is not a valid JSON file!\n\e[0m"; exit 1; fi
                #Check if it is null, a number, lower then zero, higher then 65535, otherwise exit with an error
                if [ "${metadatum}" == null ] || [ -z "${metadatum##*[!0-9]*}" ] || [ "${metadatum}" -lt 0 ] || [ "${metadatum}" -gt 65535 ]; then
                        echo -e "\n\e[35mERROR - MetaDatum Value '${metadatum}' in '${metafile}' must be in the range of 0..65535!\n\e[0m"; exit 1; fi
                metafileParameter="${metafileParameter}--metadata-json-file ${metafile} "; metafileList="${metafileList}'${metafile}' "
             elif [[ -f "${metafile}" && "${metafileExt^^}" == "CBOR" ]]; then #its a cbor file
                metafileParameter="${metafileParameter}--metadata-cbor-file ${metafile} "; metafileList="${metafileList}'${metafile}' "
             else echo -e "\n\e[35mERROR - The specified Metadata JSON/CBOR-File '${metafile}' does not exist. Fileextension must be '.json' or '.cbor' Please try again.\n\e[0m"; exit 1;
             fi

        #Check it its a MessageComment. Adding it to the JSON array if the length is <= 64 chars
        elif [[ "${paramValue,,}" =~ ^msg:(.*)$ ]]; then #if the parameter starts with "msg:" then add it
                msgString=$(trimString "${paramValue:4}");

                #Split the messages within the parameter at the "|" char
                IFS='|' read -ra allMessages <<< "${msgString}"

                #Add each message to the transactionMessage JSON
                for (( tmpCnt2=0; tmpCnt2<${#allMessages[@]}; tmpCnt2++ ))
                do
                        tmpMessage=${allMessages[tmpCnt2]}
                        if [[ $(byteLength "${tmpMessage}") -le 64 ]]; then
                                                transactionMessage=$( jq ".\"674\".msg += [ \"${tmpMessage}\" ]" <<< ${transactionMessage} 2> /dev/null);
                                                if [ $? -ne 0 ]; then echo -e "\n\e[35mMessage-Adding-ERROR: \"${tmpMessage}\" contain invalid chars for a JSON!\n\e[0m"; exit 1; fi
                        else echo -e "\n\e[35mMessage-Adding-ERROR: \"${tmpMessage}\" is too long, max. 64 bytes allowed, yours is $(byteLength "${tmpMessage}") bytes long!\n\e[0m"; exit 1;
                        fi
                done

        #Check if its a transaction message encryption type
        elif [[ "${paramValue,,}" =~ ^enc:(.*)$ ]]; then #if the parameter starts with "enc:" then set the encryption variable
                encryption=$(trimString "${paramValue:4}");

        #Check if its a transaction message encryption passphrase
        elif [[ "${paramValue,,}" =~ ^pass:(.*)$ ]]; then #if the parameter starts with "pass:" then set the passphrase variable
                passphrase="${paramValue:5}"; #don't do a trimstring here, because also spaces are a valid passphrase !

        fi #end of different parameters check

done

#Check if there are transactionMessages, if so, save the messages to a xxx.transactionMessage.json temp-file and add it to the list. Encrypt it if enabled.
if [[ ! "${transactionMessage}" == "{}" ]]; then

        transactionMessageMetadataFile="${tempDir}/$(basename ${regPayName}).transactionMessage.json";
        tmp=$( jq . <<< ${transactionMessage} 2> /dev/null)
        if [ $? -eq 0 ]; then #json is valid, so no bad chars found

                #Check if encryption is enabled, encrypt the msg part
                if [[ "${encryption,,}" == "basic" ]]; then
                        #check openssl
                        if ! exists openssl; then
                                echo -e "\e[33mYou need 'openssl', its needed to encrypt the transaction messages !\n\nInstall it on Ubuntu/Debian like:\n\e[97msudo apt update && sudo apt -y install openssl\n\n\e[33mThx! :-)\e[0m\n";
                                exit 2;
                        fi
                        msgPart=$( jq -crM ".\"674\".msg" <<< ${transactionMessage} 2> /dev/null )
                        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
                        encArray=$( openssl enc -e -aes-256-cbc -pbkdf2 -iter 10000 -a -k "${passphrase}" <<< ${msgPart} | awk {'print "\""$1"\","'} | sed '$ s/.$//' )
                        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
                        #compose new transactionMessage by using the encArray as the msg and also add the encryption mode 'basic' entry
                        tmp=$( jq ".\"674\".msg = [ ${encArray} ]" <<< '{"674":{"enc":"basic"}}' )
                        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

                elif [[ "${encryption}" != "" ]]; then #another encryption method provided
                        echo -e "\n\e[35mERROR - The given encryption mode '${encryption,,}' is not on the supported list of encryption methods. Only 'basic' from CIP-0083 is currently supported\n\n\e[0m"; exit 1;

                fi

                echo "${tmp}" > ${transactionMessageMetadataFile}; metafileParameter="${metafileParameter}--metadata-json-file ${transactionMessageMetadataFile} "; #add it to the list of metadata.jsons to attach

        else
                echo -e "\n\e[35mERROR - Additional Transaction Message-Metafile is not valid:\n\n$${transactionMessage}\n\nPlease check your added Message-Paramters.\n\e[0m"; exit 1;
        fi

fi

#Extracting infos directly from the delegation certificate
delegCBOR=$(jq -r ".cborHex" < "${delegName}.deleg.cert" 2> /dev/null)
delegPoolID=${delegCBOR: -56}

echo
echo -e "\e[0mRegister Delegation Certificate\e[32m ${delegName}.deleg.cert\e[0m with funds from Address\e[32m ${regPayName}.addr\e[0m:"
echo
echo -e "\e[0mDelegating \e[32m${delegName}\e[0m to pool with ID:\e[32m ${delegPoolID}\e[0m"
echo


#If in online/light mode, do a check if the pool to delegate to is registered
if ${onlineMode}; then

	#get the bech poolID
        delegationPoolID=$(${bech32_bin} "pool" <<< ${delegPoolID} | tr -d '\n')
        checkError "$?"; if [ $? -ne 0 ]; then echo -e "\n\e[35mERROR - Could not convert the Hex-PoolID from the Delegation-Certificate into a Bech Pool-ID.\e[0m\n"; exit 1; fi

	echo -e "\e[0mStaking Address will be delegated to Bech-PoolID:\e[33m ${delegationPoolID}\e[0m"

	if [[ ${onlineMode} == true && ${koiosAPI} != "" ]]; then

		#query poolinfo via poolid on koios
		errorcnt=0; error=-1;
		showProcessAnimation "Query Pool-Info via Koios: " &
		while [[ ${errorcnt} -lt 5 && ${error} -ne 0 ]]; do #try a maximum of 5 times to request the information
			error=0
			response=$(curl -sL -m 30 -X POST -w "---spo-scripts---%{http_code}" "${koiosAPI}/pool_info" -H "${koiosAuthorizationHeader}" -H "Accept: application/json" -H "Content-Type: application/json" -d "{\"_pool_bech32_ids\":[\"${delegationPoolID}\"]}" 2> /dev/null)
			if [[ $? -ne 0 ]]; then error=1; sleep 1; fi; #if there is an error, wait for a second and repeat
			errorcnt=$(( ${errorcnt} + 1 ))
		done
                stopProcessAnimation;

                #if no error occured, split the response string into JSON content and the HTTP-ResponseCode
                if [[ ${error} -eq 0 && "${response}" =~ (.*)---spo-scripts---([0-9]*)* ]]; then

                	responseJSON="${BASH_REMATCH[1]}"
			responseCode="${BASH_REMATCH[2]}"

			#if the responseCode is 200 (OK) and the received json only contains one entry in the array (will also not be 1 if not a valid json)
			if [[ ${responseCode} -eq 200 && $(jq ". | length" 2> /dev/null <<< ${responseJSON}) -eq 1 ]]; then
	                        { read poolNameInfo; read poolTickerInfo; read poolStatusInfo; } <<< $(jq -r ".[0].meta_json.name // \"-\", .[0].meta_json.ticker // \"-\", .[0].pool_status // \"-\"" 2> /dev/null <<< ${responseJSON})
				echo -e "   \t\e[0mInformation about the Pool: \e[32m${poolNameInfo} (${poolTickerInfo})\e[0m"
				echo -e "   \t\e[0m                    Status: \e[32m${poolStatusInfo}\e[0m"
                                echo
                        fi #responseCode & jsoncheck

		fi #error & response
                unset errorcnt error

	fi #onlineMode & koiosAPI

	#check if the pool to delegate to is already registered on chain, if not, abort
        case ${workMode} in

                "online")
			#check that the node is fully synced, otherwise the query would mabye return a false state
			if [[ $(get_currentSync) != "synced" ]]; then echo -e "\e[35mError - Node not fully synced or not running, please let your node sync to 100% first !\e[0m\n"; exit 1; fi
			#check ledger-state via the local node
			showProcessAnimation "Query-Ledger-State: " &
			poolsInLedger=$(${cardanocli} ${cliEra} query stake-pools 2> /dev/null); checkError "$?"; if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\n\e[35mERROR - Could not query stake-pools from the chain.\e[0m\n"; exit 1; fi
			stopProcessAnimation;

			#now lets see how often the delegationPoolID is listed: 0->Not on the chain, 1->On the chain, any other value -> ERROR
			poolInLedgerCnt=$(grep  "${delegationPoolID}" <<< ${poolsInLedger} | wc -l)

			if [[ ${poolInLedgerCnt} -eq 1 ]]; then echo -ne ""; #echo -e "\e[0mPool is registered on the chain, we continue ...\n";
			elif [[ ${poolInLedgerCnt} -eq 0 ]]; then echo -e "\e[33mPool is NOT on the chain, please register it first to do the delegation!\e[0m\n"; exit 1;
			else echo -e "\e[35mERROR - The Pool-ID is more than once in the ledgers stake-pool list, this shouldn't be possible!\e[0m"; exit 1;
			fi
			;;


		"light")
			#query about the poolinfo via koios has already been done a few lines before
			if [[ $(jq ". | length" 2> /dev/null <<< ${responseJSON}) -eq 1 ]]; then
				poolStatusInfo=$(jq -r ".[0].pool_status | select (.!=null)" 2> /dev/null <<< ${responseJSON})
	                        if [[ ${poolStatusInfo^^} != "REGISTERED" ]]; then
					echo -e "\e[33mPool-Status is currently '${poolStatusInfo}', please register it first to do the delegation!\e[0m\n"; exit 1;
				fi

                        else echo -e "\e[33mPool is NOT on the chain or Koios-API error, please register it first to do the delegation!\e[0m\n"; exit 1;

                        fi
			;;

	esac

	unset poolNameInfo, poolTickerInfo, poolStatusInfo

	#get the bech stakeaddress for mainnet/testnets directly out of the delegation certificate
	if [[ "${magicparam}" == *"mainnet"* ]]; then
		checkAddr=$(echo -n "e1${delegCBOR:12:56}" | ${bech32_bin} "stake");
	else
		checkAddr=$(echo -n "e0${delegCBOR:12:56}" | ${bech32_bin} "stake_test");
	fi

        echo -e "\e[0mChecking OnChain-Status for the Stake-Address:\e[32m ${checkAddr}\e[0m"
        echo

        #Get rewards state data for the address. When in online mode of course from the node and the chain, in light mode via koios
	        case ${workMode} in

	                "online")       #check that the node is fully synced, otherwise the query would mabye return a false state
	                                if [[ $(get_currentSync) != "synced" ]]; then echo -e "\e[35mError - Node not fully synced or not running, please let your node sync to 100% first !\e[0m\n"; exit 1; fi
	                		showProcessAnimation "Query-StakeAddress-Info: " &
	                                rewardsJSON=$(${cardanocli} ${cliEra} query stake-address-info --address ${checkAddr} 2> /dev/stdout )
	                                if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${rewardsJSON}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
	                                rewardsJSON=$(jq -rc . <<< "${rewardsJSON}")
	                                ;;

	                "light")        showProcessAnimation "Query-StakeAddress-Info-LightMode: " &
	                                rewardsJSON=$(queryLight_stakeAddressInfo "${checkAddr}")
	                                if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${rewardsJSON}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
	                                ;;

        esac

        rewardsEntryCnt=$(jq -r 'length' <<< ${rewardsJSON})

        #Checking about the content
        if [[ ${rewardsEntryCnt} == 0 ]]; then #not registered yet
		echo -e "\e[33mStaking Address is NOT on the chain, please register it first to do a delegation !\e[0m\n"; exit 1;
                else #already registered
                        #echo -e "Staking Address is registered on the chain, we continue ...\e[0m\n"

                        delegationPoolID=$(jq -r ".[0].delegation // .[0].stakeDelegation" <<< ${rewardsJSON})

                        #If delegated to a pool, show the current pool ID
                        if [[ ! ${delegationPoolID} == null ]]; then

                                echo -e "Staking Address is currently delegated to PoolID: \e[94m${delegationPoolID}\e[0m";

		                if [[ ${onlineMode} == true && ${koiosAPI} != "" ]]; then

 		                       #query poolinfo via poolid on koios
  		                      errorcnt=0; error=-1;
		                        showProcessAnimation "Query Pool-Info via Koios: " &
		                        while [[ ${errorcnt} -lt 5 && ${error} -ne 0 ]]; do #try a maximum of 5 times to request the information
		                                error=0
					        response=$(curl -sL -m 30 -X POST -w "---spo-scripts---%{http_code}" "${koiosAPI}/pool_info" -H "${koiosAuthorizationHeader}" -H "Accept: application/json" -H "Content-Type: application/json" -d "{\"_pool_bech32_ids\":[\"${delegationPoolID}\"]}" 2> /dev/null)
		                                if [[ $? -ne 0 ]]; then error=1; sleep 1; fi; #if there is an error, wait for a second and repeat
		                                errorcnt=$(( ${errorcnt} + 1 ))
		                        done
		                        stopProcessAnimation;

		                        #if no error occured, split the response string into JSON content and the HTTP-ResponseCode
		                        if [[ ${error} -eq 0 && "${response}" =~ (.*)---spo-scripts---([0-9]*)* ]]; then

		                                responseJSON="${BASH_REMATCH[1]}"
		                                responseCode="${BASH_REMATCH[2]}"

		                                #if the responseCode is 200 (OK) and the received json only contains one entry in the array (will also not be 1 if not a valid json)
		                                if [[ ${responseCode} -eq 200 && $(jq ". | length" 2> /dev/null <<< ${responseJSON}) -eq 1 ]]; then
				                        { read poolNameInfo; read poolTickerInfo; read poolStatusInfo; } <<< $(jq -r ".[0].meta_json.name // \"-\", .[0].meta_json.ticker // \"-\", .[0].pool_status // \"-\"" 2> /dev/null <<< ${responseJSON})
		                                        echo -e "\e[0m                                            Name: \e[94m${poolNameInfo} (${poolTickerInfo})\e[0m"
		                                        echo -e "\e[0m                                          Status: \e[94m${poolStatusInfo}\e[0m"
		                                        echo
							unset poolNameInfo poolTickerInfo poolStatusInfo
		                                fi #responseCode & jsoncheck

		                        fi #error & response
		                        unset errorcnt error

		                fi #onlineMode & koiosAPI

                        else
                                echo -e "\e[0mAccount is not delegated to a Pool yet - so lets change this :-)\n";
                        fi

        fi ## ${rewardsEntryCnt} == 0

fi ## ${onlineMode} == true



#get values to register the delegation certificate on the blockchain
#get live values
currentTip=$(get_currentTip); checkError "$?";
ttl=$(( ${currentTip} + ${defTTL} ))

echo -e "Current Slot-Height:\e[32m ${currentTip}\e[0m (setting TTL[invalid_hereafter] to ${ttl})"

rxcnt="1"               #transmit to one destination addr. all utxos will be sent back to the fromAddr

sendFromAddr=$(cat ${regPayName}.addr); check_address "${sendFromAddr}";
sendToAddr=$(cat ${regPayName}.addr); check_address "${sendToAddr}";

echo
echo -e "Pay fees from Address\e[32m ${regPayName}.addr\e[0m: ${sendFromAddr}"
echo

#------------------------------------------------
#
# Checking UTXO Data of the source address and gathering data about total lovelaces and total assets
#


        #Get UTX0 Data for the address. When in online mode of course from the node and the chain, in lightmode via API requests, in offlinemode from the transferFile
        case ${workMode} in
                "online")       #check that the node is fully synced, otherwise the query would mabye return a false state
                                if [[ $(get_currentSync) != "synced" ]]; then echo -e "\e[35mError - Node not fully synced or not running, please let your node sync to 100% first !\e[0m\n"; exit 1; fi
                                showProcessAnimation "Query-UTXO: " &
                                utxo=$(${cardanocli} ${cliEra} query utxo --address ${sendFromAddr} 2> /dev/stdout);
                                if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${utxo}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
                                showProcessAnimation "Convert-UTXO: " &
                                utxoJSON=$(generate_UTXO "${utxo}" "${sendFromAddr}"); stopProcessAnimation;
                                ;;

                "light")        showProcessAnimation "Query-UTXO-LightMode: " &
                                utxo=$(queryLight_UTXO "${sendFromAddr}");
                                if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${utxo}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
                                showProcessAnimation "Convert-UTXO: " &
                                utxoJSON=$(generate_UTXO "${utxo}" "${sendFromAddr}"); stopProcessAnimation;
                                ;;

                "offline")      readOfflineFile;        #Reads the offlinefile into the offlineJSON variable
                                utxoJSON=$(jq -r ".address.\"${sendFromAddr}\".utxoJSON" <<< ${offlineJSON} 2> /dev/null)
                                if [[ "${utxoJSON}" == null ]]; then echo -e "\e[35mPayment-Address not included in the offline transferFile, please include it first online!\e[0m\n"; exit 1; fi
                                ;;
        esac

	txcnt=$(jq length <<< ${utxoJSON}) #Get number of UTXO entries (Hash#Idx), this is also the number of --tx-in for the transaction
	if [[ ${txcnt} == 0 ]]; then echo -e "\e[35mNo funds on the Source Address!\e[0m\n"; exit 1; else echo -e "\e[32m${txcnt} UTXOs\e[0m found on the Source Address!\n"; fi

	#Calculating the total amount of lovelaces in all utxos on this address
        #totalLovelaces=$(jq '[.[].amount[0]] | add' <<< ${utxoJSON})

	totalLovelaces=0
        totalAssetsJSON="{}"; 	#Building a total JSON with the different assetstypes "policyIdHash.name", amount and name
        totalPolicyIDsJSON="{}"; #Holds the different PolicyIDs as values "policyIDHash", length is the amount of different policyIDs
	assetsOutString="";	#This will hold the String to append on the --tx-out if assets present or it will be empty

        #For each utxo entry, check the utxo#index and check if there are also any assets in that utxo#index
        #LEVEL 1 - different UTXOs

        readarray -t utxoHashIndexArray <<< $(jq -r "keys_unsorted[]" <<< ${utxoJSON})
        readarray -t utxoLovelaceArray <<< $(jq -r "flatten | .[].value.lovelace" <<< ${utxoJSON})
        readarray -t assetsEntryCntArray <<< $(jq -r "flatten | .[].value | del (.lovelace) | length" <<< ${utxoJSON})
        readarray -t assetsEntryJsonArray <<< $(jq -c "flatten | .[].value | del (.lovelace)" <<< ${utxoJSON})
        readarray -t utxoDatumHashArray <<< $(jq -r "flatten | .[].datumhash" <<< ${utxoJSON})

        for (( tmpCnt=0; tmpCnt<${txcnt}; tmpCnt++ ))
        do
        utxoHashIndex=${utxoHashIndexArray[${tmpCnt}]}
        utxoAmount=${utxoLovelaceArray[${tmpCnt}]} #Lovelaces
        totalLovelaces=$(bc <<< "${totalLovelaces} + ${utxoAmount}" )
        echo -e "Hash#Index: ${utxoHashIndex}\tADA: $(convertToADA ${utxoAmount}) \e[90m(${utxoAmount} lovelaces)\e[0m";
	if [[ ! "${utxoDatumHashArray[${tmpCnt}]}" == null ]]; then echo -e " DatumHash: ${utxoDatumHashArray[${tmpCnt}]}"; fi
        assetsEntryCnt=${assetsEntryCntArray[${tmpCnt}]}

        if [[ ${assetsEntryCnt} -gt 0 ]]; then

                        assetsJSON=${assetsEntryJsonArray[${tmpCnt}]}
                        assetHashIndexArray=(); readarray -t assetHashIndexArray <<< $(jq -r "keys_unsorted[]" <<< ${assetsJSON})
                        assetNameCntArray=(); readarray -t assetNameCntArray <<< $(jq -r "flatten | .[] | length" <<< ${assetsJSON})

                        #LEVEL 2 - different policyIDs
                        for (( tmpCnt2=0; tmpCnt2<${assetsEntryCnt}; tmpCnt2++ ))
                        do
                        assetHash=${assetHashIndexArray[${tmpCnt2}]} #assetHash = policyID
                        totalPolicyIDsLIST+="${assetHash}\n"

                        assetsNameCnt=${assetNameCntArray[${tmpCnt2}]}
                        assetNameArray=(); readarray -t assetNameArray <<< $(jq -r ".\"${assetHash}\" | keys_unsorted[]" <<< ${assetsJSON})
                        assetAmountArray=(); readarray -t assetAmountArray <<< $(jq -r ".\"${assetHash}\" | flatten | .[]" <<< ${assetsJSON})

                                #LEVEL 3 - different names under the same policyID
                                for (( tmpCnt3=0; tmpCnt3<${assetsNameCnt}; tmpCnt3++ ))
                                do
                                assetName=${assetNameArray[${tmpCnt3}]}
                                assetAmount=${assetAmountArray[${tmpCnt3}]}
                                assetBech=$(convert_tokenName2BECH "${assetHash}${assetName}" "")
                                if [[ "${assetName}" == "" ]]; then point=""; else point="."; fi
                                oldValue=$(jq -r ".\"${assetHash}${point}${assetName}\".amount" <<< ${totalAssetsJSON})
                                newValue=$(bc <<< "${oldValue}+${assetAmount}")
                                assetTmpName=$(convert_assetNameHEX2ASCII_ifpossible "${assetName}") #if it starts with a . -> ASCII showable name, otherwise the HEX-String
                                totalAssetsJSON=$( jq ". += {\"${assetHash}${point}${assetName}\":{amount: \"${newValue}\", name: \"${assetTmpName}\", bech: \"${assetBech}\"}}" <<< ${totalAssetsJSON})
                                if [[ "${assetTmpName:0:1}" == "." ]]; then assetTmpName=${assetTmpName:1}; else assetTmpName="{${assetTmpName}}"; fi

                                case "${assetHash}${assetTmpName:1:8}" in
                                        "${adahandlePolicyID}000de140" )        #$adahandle cip-68
                                                assetName=${assetName:8};
                                                echo -e "\e[90m                           Asset: ${assetBech}  \e[33mADA Handle(Own): \$$(convert_assetNameHEX2ASCII ${assetName}) ${assetTmpName}\e[0m"
                                                ;;
                                        "${adahandlePolicyID}00000000" )        #$adahandle virtual
                                                assetName=${assetName:8};
                                                echo -e "\e[90m                           Asset: ${assetBech}  \e[33mADA Handle(Vir): \$$(convert_assetNameHEX2ASCII ${assetName}) ${assetTmpName}\e[0m"
                                                ;;
                                        "${adahandlePolicyID}000643b0" )        #$adahandle reference
                                                assetName=${assetName:8};
                                                echo -e "\e[90m                           Asset: ${assetBech}  \e[33mADA Handle(Ref): \$$(convert_assetNameHEX2ASCII ${assetName}) ${assetTmpName}\e[0m"
                                                ;;
                                        "${adahandlePolicyID}"* )               #$adahandle cip-25
                                                echo -e "\e[90m                           Asset: ${assetBech}  \e[33mADA Handle: \$$(convert_assetNameHEX2ASCII ${assetName}) ${assetTmpName}\e[0m"
                                                ;;
                                        * ) #default
                                                echo -e "\e[90m                           Asset: ${assetBech}  Amount: ${assetAmount} ${assetTmpName}\e[0m"
                                                ;;
                                esac

                                done
                        done
        fi
        txInString="${txInString} --tx-in ${utxoHashIndex}"
        done
        echo -e "\e[0m-----------------------------------------------------------------------------------------------------"
        echo -e "Total ADA on the Address:\e[32m  $(convertToADA ${totalLovelaces}) ADA / ${totalLovelaces} lovelaces \e[0m\n"


        totalPolicyIDsCnt=$(echo -ne "${totalPolicyIDsLIST}" | sort | uniq | wc -l)
        totalAssetsCnt=$(jq length <<< ${totalAssetsJSON});
        if [[ ${totalAssetsCnt} -gt 0 ]]; then
                        echo -e "\e[32m${totalAssetsCnt} Asset-Type(s) / ${totalPolicyIDsCnt} different PolicyIDs\e[0m found on the Address!\n"
                        printf "\e[0m%-56s%11s    %16s %-44s  %7s  %s\n" "PolicyID:" "Asset-Name:" "Total-Amount:" "Bech-Format:" "Ticker:" "Meta-Name:"

                        totalAssetsJSON=$(jq --sort-keys . <<< ${totalAssetsJSON}) #sort the json by the hashname
                        assetHashNameArray=(); readarray -t assetHashNameArray <<< $(jq -r "keys_unsorted[]" <<< ${totalAssetsJSON})
                        assetAmountArray=(); readarray -t assetAmountArray <<< $(jq -r "flatten | .[].amount" <<< ${totalAssetsJSON})
                        assetNameArray=(); readarray -t assetNameArray <<< $(jq -r "flatten | .[].name" <<< ${totalAssetsJSON})
                        assetBechArray=(); readarray -t assetBechArray <<< $(jq -r "flatten | .[].bech" <<< ${totalAssetsJSON})

                        for (( tmpCnt=0; tmpCnt<${totalAssetsCnt}; tmpCnt++ ))
                        do
                        assetHashName=${assetHashNameArray[${tmpCnt}]}
                        assetAmount=${assetAmountArray[${tmpCnt}]}
                        assetName=${assetNameArray[${tmpCnt}]}
                        assetBech=${assetBechArray[${tmpCnt}]}
                        assetHashHex="${assetHashName//./}" #remove a . if present, we need a clean subject here for the registry request

                        if $queryTokenRegistry; then if $onlineMode; then metaResponse=$(curl -sL -m 20 "${tokenMetaServer}/${assetHashHex}"); else metaResponse=$(jq -r ".tokenMetaServer.\"${assetHashHex}\"" <<< ${offlineJSON}); fi
                                metaAssetName=$(jq -r ".name.value | select (.!=null)" 2> /dev/null <<< ${metaResponse}); if [[ ! "${metaAssetName}" == "" ]]; then metaAssetName="${metaAssetName} "; fi
                                metaAssetTicker=$(jq -r ".ticker.value | select (.!=null)" 2> /dev/null <<< ${metaResponse})
                        fi

                        if [[ "${assetName}" == "." ]]; then assetName=""; fi

                        printf "\e[90m%-70s \e[32m%16s %44s  \e[90m%-7s  \e[36m%s\e[0m\n" "${assetHashName:0:56}${assetName}" "${assetAmount}" "${assetBech}" "${metaAssetTicker}" "${metaAssetName}"
                        if [[ $(bc <<< "${assetAmount}>0") -eq 1 ]]; then assetsOutString+="+${assetAmount} ${assetHashName}"; fi #only include in the sendout if more than zero
                        done
        fi


echo


#There are metadata file(s) attached, list them:
if [[ ! "${metafileList}" == "" ]]; then echo -e "\e[0mInclude Metadata-File(s):\e[32m ${metafileList}\e[0m\n"; fi

#There are transactionMessages attached, show the metadatafile:
if [[ ! "${transactionMessage}" == "{}" ]]; then
        if [[ "${encArray}" ]]; then #if there is an encryption, show the original Metadata first with the encryption paramteters
        echo -e "\e[0mOriginal Transaction-Message:\n\e[90m"; jq -rM <<< ${transactionMessage}; echo -e "\e[0m";
        echo -e "\e[0mEncrypted Transaction-Message mode \e[32m${encryption,,}\e[0m with Passphrase '\e[32m${passphrase}\e[0m'";
        echo
        fi
        echo -e "\e[0mInclude Transaction-Message-Metadata-File:\e[32m ${transactionMessageMetadataFile}\n\e[90m"; cat ${transactionMessageMetadataFile}; echo -e "\e[0m";
fi

#Read ProtocolParameters
case ${workMode} in
        "online")       protocolParametersJSON=$(${cardanocli} ${cliEra} query protocol-parameters);; #onlinemode
        "light")        protocolParametersJSON=${lightModeParametersJSON};; #lightmode
        "offline")      protocolParametersJSON=$(jq ".protocol.parameters" <<< ${offlineJSON});; #offlinemode
esac
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

minOutUTXO=$(calc_minOutUTXO "${protocolParametersJSON}" "${sendToAddr}+1000000${assetsOutString}")

#-------------------------------------


#Generate Dummy-TxBody file for fee calculation
txBodyFile="${tempDir}/dummy.txbody"
rm ${txBodyFile} 2> /dev/null
${cardanocli} ${cliEra} transaction build-raw ${txInString} --tx-out "${sendToAddr}+${totalLovelaces}${assetsOutString}" --invalid-hereafter ${ttl} --fee 200000 ${metafileParameter} --certificate ${delegName}.deleg.cert --out-file ${txBodyFile}
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

#calculate the transaction fee. new parameters since cardano-cli 8.21.0
fee=$(${cardanocli} ${cliEra} transaction calculate-min-fee --tx-body-file ${txBodyFile} --protocol-params-file <(echo ${protocolParametersJSON}) --witness-count 2 --reference-script-size 0 2> /dev/stdout)
if [ $? -ne 0 ]; then echo -e "\n\e[35m${fee}\e[0m\n"; exit 1; fi
fee=${fee%% *} #only get the first part of 'xxxxxx Lovelaces'

echo -e "\e[0mMinimum transfer Fee for ${txcnt}x TxIn & ${rxcnt}x TxOut & 1x Certificate: \e[32m $(convertToADA ${fee}) ADA / ${fee} lovelaces \e[90m"
minRegistrationFund=$(( ${fee} ))

echo
echo -e "\e[0mMinimum funds required for registration (Sum of fees): \e[32m $(convertToADA ${minRegistrationFund}) ADA / ${minRegistrationFund} lovelaces \e[90m"
echo

#calculate new balance for destination address
lovelacesToSend=$(( ${totalLovelaces}-${minRegistrationFund} ))

echo -e "\e[0mLovelaces that will be returned to payment Address (UTXO-Sum minus fees): \e[32m $(convertToADA ${lovelacesToSend}) ADA / ${lovelacesToSend} lovelaces \e[90m (min. required ${minOutUTXO} lovelaces)"
echo

#Checking about minimum funds in the UTX0
if [[ ${lovelacesToSend} -lt ${minOutUTXO} ]]; then echo -e "\e[35mNot enough funds on the source Addr! Minimum UTXO value is ${minOutUTXO} lovelaces.\e[0m"; exit; fi

txBodyFile="${tempDir}/$(basename ${regPayName}).txbody"
txWitnessFile="${tempDir}/$(basename ${regPayName}).txwitness"
txFile="${tempDir}/$(basename ${regPayName}).tx"

echo
echo -e "\e[0mBuilding the unsigned transaction body with Delegation Certificate\e[32m ${delegName}.deleg.cert\e[0m certificates: \e[32m ${txBodyFile} \e[90m"
echo

#Building unsigned transaction body
rm ${txBodyFile} 2> /dev/null
${cardanocli} ${cliEra} transaction build-raw ${txInString} --tx-out "${sendToAddr}+${lovelacesToSend}${assetsOutString}" --invalid-hereafter ${ttl} --fee ${fee} ${metafileParameter} --certificate ${delegName}.deleg.cert --out-file ${txBodyFile}
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

dispFile=$(cat ${txBodyFile}); if ${cropTxOutput} && [[ ${#dispFile} -gt 4000 ]]; then echo "${dispFile:0:4000} ... (cropped)"; else echo "${dispFile}"; fi
echo

#Sign the unsigned transaction body with the SecureKey
rm ${txFile} 2> /dev/null
#If stakeaddress and payment address are from the same hardware files
paymentName=$(basename ${regPayName} .payment) #contains the name before the .payment.addr extension
stakingName=$(basename ${delegName} .staking) #contains the name before the .staking.addr extension
if [[ -f "${regPayName}.hwsfile" && -f "${delegName}.staking.hwsfile" && "${paymentName}" == "${stakingName}" ]]; then

        echo -ne "\e[0mAutocorrect the TxBody for canonical order: "
        tmp=$(autocorrect_TxBodyFile "${txBodyFile}"); if [ $? -ne 0 ]; then echo -e "\e[35m${tmp}\e[0m\n\n"; exit 1; fi
        echo -e "\e[32m${tmp}\e[90m\n"

	dispFile=$(cat ${txBodyFile}); if ${cropTxOutput} && [[ ${#dispFile} -gt 4000 ]]; then echo "${dispFile:0:4000} ... (cropped)"; else echo "${dispFile}"; fi
	echo

	echo -e "\e[0mSign (Witness+Assemble) the unsigned transaction body with the \e[32m${regPayName}.hwsfile\e[0m & \e[32m${delegName}.staking.hwsfile\e[0m: \e[32m ${txFile} \e[90m"
	echo

        #Witness and Assemble the TxFile
        start_HwWallet; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
        tmp=$(${cardanohwcli} transaction witness --tx-file ${txBodyFile} --hw-signing-file ${delegName}.staking.hwsfile --hw-signing-file ${regPayName}.hwsfile --change-output-key-file ${delegName}.staking.hwsfile --change-output-key-file ${regPayName}.hwsfile ${magicparam} --out-file ${txWitnessFile}-staking --out-file ${txWitnessFile}-payment 2> /dev/stdout)
        if [[ "${tmp^^}" =~ (ERROR|DISCONNECT) ]]; then echo -e "\e[35m${tmp}\e[0m\n"; exit 1; else echo -ne "\e[0mWitnessed ... "; fi
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

        ${cardanocli} ${cliEra} transaction assemble --tx-body-file ${txBodyFile} --witness-file ${txWitnessFile}-payment --witness-file ${txWitnessFile}-staking --out-file ${txFile}
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
        echo -e "Assembled ... \e[32mDONE\e[0m\n";


elif [[ -f "${delegName}.staking.skey" && -f "${regPayName}.skey" ]]; then #with the normal cli skey

        #read the needed signing keys into ram and sign the transaction
        skeyJSON1=$(read_skeyFILE "${regPayName}.skey"); if [ $? -ne 0 ]; then echo -e "\e[35m${skeyJSON1}\e[0m\n"; exit 1; else echo -e "\e[32mOK\e[0m\n"; fi
        skeyJSON2=$(read_skeyFILE "${delegName}.staking.skey"); if [ $? -ne 0 ]; then echo -e "\e[35m${skeyJSON2}\e[0m\n"; exit 1; else echo -e "\e[32mOK\e[0m\n"; fi


	echo -e "\e[0mSign the unsigned transaction body with the \e[32m${regPayName}.skey\e[0m & \e[32m${delegName}.staking.skey\e[0m: \e[32m ${txFile} \e[90m"
	echo

        ${cardanocli} ${cliEra} transaction sign --tx-body-file ${txBodyFile} --signing-key-file <(echo "${skeyJSON1}") --signing-key-file <(echo "${skeyJSON2}") --out-file ${txFile}
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

        #forget the signing keys
        unset skeyJSON1
        unset skeyJSON2

else
echo -e "\e[35mThis combination is not allowed! A Hardware-Wallet can only (must) be used to register its own delegation on the chain.\e[0m\n"; exit 1;
fi
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
echo -ne "\e[90m"
dispFile=$(cat ${txFile}); if ${cropTxOutput} && [[ ${#dispFile} -gt 4000 ]]; then echo "${dispFile:0:4000} ... (cropped)"; else echo "${dispFile}"; fi
echo

#Do a txSize Check to not exceed the max. txSize value
cborHex=$(jq -r .cborHex < ${txFile})
txSize=$(( ${#cborHex} / 2 ))
maxTxSize=$(jq -r .maxTxSize <<< ${protocolParametersJSON})
if [[ ${txSize} -le ${maxTxSize} ]]; then echo -e "\e[0mTransaction-Size: ${txSize} bytes (max. ${maxTxSize})\n"
                                     else echo -e "\n\e[35mError - ${txSize} bytes Transaction-Size is too big! The maximum is currently ${maxTxSize} bytes.\e[0m\n"; exit 1; fi


if ask "\e[33mDoes this look good for you ?" N; then

        echo
	case ${workMode} in
	"online")
				#onlinesubmit
                                echo -ne "\e[0mSubmitting the transaction via the node... "
                                ${cardanocli} ${cliEra} transaction submit --tx-file ${txFile}
                                if [ $? -ne 0 ]; then echo -e "\n\e[35mError - Make sure the pool is already registered.\n\e[0m\n"; exit $?; fi
                                echo -e "\e[32mDONE\n"

                                #Show the TxID
                                txID=$(${cardanocli} ${cliEra} transaction txid --tx-file ${txFile}); echo -e "\e[0m TxID is: \e[32m${txID}\e[0m"
                                checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi;
                                if [[ "${transactionExplorer}" != "" ]]; then echo -e "\e[0mTracking: \e[32m${transactionExplorer}/${txID}\n\e[0m"; fi
				;;


        "light")
                                #lightmode submit
                                showProcessAnimation "Submit-Transaction-LightMode: " &
                                txID=$(submitLight "${txFile}");
                                if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${txID}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
                                echo -e "\e[0mSubmit-Transaction-LightMode: \e[32mDONE\n"
                                if [[ "${transactionExplorer}" != "" ]]; then echo -e "\e[0mTracking: \e[32m${transactionExplorer}/${txID}\n\e[0m"; fi
                                ;;


	"offline")
				#offlinestore
                                txFileJSON=$(cat ${txFile} | jq .)
                                offlineJSON=$( jq ".transactions += [ { date: \"$(date -R)\",
                                                                        type: \"DelegationCertRegistration\",
                                                                        era: \"$(jq -r .protocol.era <<< ${offlineJSON})\",
                                                                        delegName: \"${delegName}\",
                                                                        fromAddr: \"${regPayName}\",
                                                                        sendFromAddr: \"${sendFromAddr}\",
                                                                        toAddr: \"${regPayName}\",
                                                                        sendToAddr: \"${sendToAddr}\",
                                                                        txJSON: ${txFileJSON} } ]" <<< ${offlineJSON})
                                #Write the new offileFile content
                                offlineJSON=$( jq ".history += [ { date: \"$(date -R)\", action: \"signed delegation cert registration transaction for '${delegName}', payment via '${regPayName}'\" } ]" <<< ${offlineJSON})
                                offlineJSON=$( jq ".general += {offlineCLI: \"${versionCLI}\" }" <<< ${offlineJSON})
                                echo "${offlineJSON}" > ${offlineFile}
                                #Readback the tx content and compare it to the current one
                                readback=$(cat ${offlineFile} | jq -r ".transactions[-1].txJSON")
                                if [[ "${txFileJSON}" == "${readback}" ]]; then
                                                        showOfflineFileInfo;
                                                        echo -e "\e[33mTransaction txJSON has been stored in the '$(basename ${offlineFile})'.\nYou can now transfer it to your online machine for execution.\e[0m\n";
                                                 else
                                                        echo -e "\e[35mERROR - Could not verify the written data in the '$(basename ${offlineFile})'. Retry again or generate a new '$(basename ${offlineFile})'.\e[0m\n";
                                fi
				;;

	esac

fi

echo -e "\e[0m\n"
