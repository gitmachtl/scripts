#!/bin/bash

# Script is brought to you by ATADA Stakepool, Telegram @atada_stakepool

#load variables and functions from common.sh
. "$(dirname "$0")"/00_common.sh

if [ $# -ge 2 ]; then
		stakeAddr="$(dirname $1)/$(basename $1 .staking).staking"; stakeAddr=${stakeAddr/#.\//}
		toAddr="$(dirname $2)/$(basename $2 .addr)"; toAddr=${toAddr/#.\//}
                else
                 cat >&2 <<EOF

Usage:  $(basename $0) <StakeAddressName> <To AddressName or HASH or '\$adahandle'> [Opt: <FeePaymentAddressName>]

        [Opt: Message comment, starting with "msg: ...", | is the separator]
        [Opt: encrypted message mode "enc:basic". Currently only 'basic' mode is available.]
        [Opt: passphrase for encrypted message mode "pass:<passphrase>", the default passphrase is 'cardano' is not provided]
        [Opt: list of UTXOs to use, | is the separator]
        [Opt: no of input UTXOs limitation, starting with "utxolimit: ..."]
        [Opt: skip input UTXOs that contain assets (hex-format), starting with "skiputxowithasset: <policyID>(assetName)", | is the separator]
        [Opt: only input UTXOs that contain assets (hex-format), starting with "onlyutxowithasset: <policyID>(assetName)", | is the separator]


Examples:
	$(basename $0) owner.staking owner.payment        (claims the rewards from owner.staking.addr and sends them to owner.payment.addr, owner.payment.addr pays the fees)
	$(basename $0) owner.staking owner.payment "msg: rewards for epoch xxx" (claims the rewards like the first example, but also adds a transaction message)
	$(basename $0) owner.staking owner.payment funds  (claims the rewards from owner.staking.addr and sends them to owner.payment.addr, funds.addr pays the fees)

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

- In rare cases you wanna define the exact UTXOs that should be used for sending Funds out:
   "UTXO1#Index" ... to specify one UTXO, must be in quotes "..."
   "UTXO1#Index|UTXO2#Index" ... to specify more UTXOs provide them with the | as separator, must be in quotes "..."

- In rare cases you wanna define the maximum count of input UTXOs that will be used for building the Transaction:
   "utxolimit: xxx" ... to specify xxx number of input UTXOs to be used as maximum
   "utxolimit: 300" ... to specify a maximum of 300 input UTXOs that will be used for the transaction

- In rare cases you wanna skip input UTXOs that contains one or more defined Assets policyIDs(+assetName) in hex-format:
   "skiputxowithasset: yyy" ... to skip all input UTXOs that contains assets with the policyID yyy
   "skiputxowithasset: yyy|zzz" ... to skip all input UTXOs that contains assets with the policyID yyy or zzz

- In rare cases you wanna only use input UTXOs that contains one or more defined Assets policyIDs(+assetName) in hex-format:
   "onlyutxowithasset: yyy" ... to skip all input UTXOs that contains assets with the policyID yyy
   "onlyutxowithasset: yyy|zzz" ... to skip all input UTXOs that contains assets with the policyID yyy or zzz

EOF
  exit 1; fi

#Check all optional parameters about there types and set the corresponding variables
#Starting with the 4th parameter (index3) up to the last parameter
metafileParameter=""; metafile=""; filterForUTXO=""; transactionMessage="{}"; adahandleName= ; fromAddr= ; enc=""; passphrase="cardano" #Setting defaults

paramCnt=$#;

allParameters=( "$@" )
for (( tmpCnt=2; tmpCnt<${paramCnt}; tmpCnt++ ))
 do
        paramValue=${allParameters[$tmpCnt]}
        #echo "${tmpCnt}: ${paramValue} -> "

        #Check if an additional payment address or metadata.json/.cbor was set as parameter (not a Message, not a UTXO#IDX, not empty, not a number)
        if [[ ! "${paramValue,,}" =~ ^msg:(.*)$ ]] && [[ ! "${paramValue,,}" =~ ^enc:(.*)$ ]] && [[ ! "${paramValue,,}" =~ ^pass:(.*)$ ]] && [[ ! "${paramValue,,}" =~ ^utxolimit:(.*)$ ]] && [[ ! "${paramValue,,}" =~ ^onlyutxowithasset:(.*)$ ]] && [[ ! "${paramValue,,}" =~ ^skiputxowithasset:(.*)$ ]] && [[ ! "${paramValue}" =~ ^([[:xdigit:]]+#[[:digit:]]+(\|?)){1,}$ ]] && [[ ! ${paramValue} == "" ]] && [ -z "${paramValue##*[!0-9]*}" ]; then

		#Check if its a payment address file
		_fromAddr="$(dirname ${paramValue})/$(basename ${paramValue} .addr)"; _fromAddr=${_fromAddr/#.\//};
		if [[ -f "${_fromAddr}.addr" ]]; then fromAddr=${_fromAddr}; unset _fromAddr; #ok we found a payment file
		else #if it was not a paymentfile, the only option left is that it is a metadata file, lets check about that
	             metafile=${paramValue}; metafileExt=${metafile##*.}
	             if [[ -f "${metafile}" && "${metafileExt^^}" == "JSON" ]]; then #its a json file
	                #Do a simple basic check if the metadatum is in the 0..65535 range
	                metadatum=$(jq -r "keys_unsorted[0]" "${metafile}" 2> /dev/null)
	                if [[ $? -ne 0 ]]; then echo "ERROR - '${metafile}' is not a valid JSON file"; exit 1; fi
	                #Check if it is null, a number, lower then zero, higher then 65535, otherwise exit with an error
	                if [ "${metadatum}" == null ] || [ -z "${metadatum##*[!0-9]*}" ] || [ "${metadatum}" -lt 0 ] || [ "${metadatum}" -gt 65535 ]; then
	                        echo "ERROR - MetaDatum Value '${metadatum}' in '${metafile}' must be in the range of 0..65535!"; exit 1; fi
	                metafileParameter="${metafileParameter}--metadata-json-file ${metafile} "; metafileList="${metafileList}'${metafile}' "
	             elif [[ -f "${metafile}" && "${metafileExt^^}" == "CBOR" ]]; then #its a cbor file
	                metafileParameter="${metafileParameter}--metadata-cbor-file ${metafile} "; metafileList="${metafileList}'${metafile}' "
	             else echo -e "The specified Metadata JSON/CBOR-File '${metafile}' does not exist. Fileextension must be '.json' or '.cbor' Please try again."; exit 1;
	             fi

		fi

        #Check if an additional UTXO#IDX filter was set as parameter "hex#num(|)" at least 1 time, but can be more often}
        elif [[ "${paramValue}" =~ ^([[:xdigit:]]+#[[:digit:]]+(\|?)){1,}$ ]]; then filterForUTXO="${paramValue}";

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

        #Check if its an utxo amount limitation
        elif [[ "${paramValue,,}" =~ ^utxolimit:(.*)$ ]]; then #if the parameter starts with "utxolimit:" then set the utxolimit
                utxoLimitCnt=$(trimString "${paramValue:10}");
                if [[ ${utxoLimitCnt} -le 0 ]]; then echo -e "\n\e[35mUTXO-Limit-ERROR: Please use a number value greater than zero!\n\e[0m"; exit 1; fi

        #Check if its an skipUtxoWithPolicy set
        elif [[ "${paramValue,,}" =~ ^skiputxowithasset:(.*)$ ]]; then #if the parameter starts with "skiputxowithasset:" then set the skipUtxoWithAsset variable
                skipUtxoWithAssetTmp=$(trimString "${paramValue:18}"); skipUtxoWithAssetTmp=${skipUtxoWithAssetTmp,,}; #read the value and convert it to lowercase
                if [[ ! "${skipUtxoWithAssetTmp}" =~ ^(([[:xdigit:]][[:xdigit:]]){28,60}+(\|?)){1,}$ ]]; then
                        echo -e "\n\e[35mSkip-UTXO-With-Asset-ERROR: The given asset '${skipUtxoWithAssetTmp}' is not a valid policy(+assetname) hex string!\n\e[0m"; exit 1; fi
                skipUtxoWithAssetTmp=${skipUtxoWithAssetTmp//|/ }; #replace the | with a space so it can be read as an array
                skipUtxoWithAsset=""
                #Check each entry (separated via a | char) if they contain also assethex-parts, if so place a . in the middle. Concate the final string.
                for tmpEntry in ${skipUtxoWithAssetTmp}; do
                if [[ ${#tmpEntry} -gt 56 ]]; then skipUtxoWithAsset+="${tmpEntry:0:56}.${tmpEntry:56}|"; else skipUtxoWithAsset+="${tmpEntry}|"; fi #representation in the rawquery output is <hexPolicyID>.<hexAssetName>
                done
                skipUtxoWithAsset=${skipUtxoWithAsset%?}; #remove the last char "|"

        #Check if its an onlyUtxoWithPolicy set
        elif [[ "${paramValue,,}" =~ ^onlyutxowithasset:(.*)$ ]]; then #if the parameter starts with "onylutxowithasset:" then set the onlyUtxoWithAsset variable
                onlyUtxoWithAssetTmp=$(trimString "${paramValue:18}"); onlyUtxoWithAssetTmp=${onlyUtxoWithAssetTmp,,}; #read the value and convert it to lowercase
                if [[ ! "${onlyUtxoWithAssetTmp}" =~ ^(([[:xdigit:]][[:xdigit:]]){28,60}+(\|?)){1,}$ ]]; then
                        echo -e "\n\e[35mOnly-UTXO-With-Asset-ERROR: The given asset '${onlyUtxoWithAssetTmp}' is not a valid policy(+assetname) hex string!\n\e[0m"; exit 1; fi
                onlyUtxoWithAssetTmp=${onlyUtxoWithAssetTmp//|/ }; #replace the | with a space so it can be read as an array
                onlyUtxoWithAsset=""
                #Check each entry (separated via a | char) if they contain also assethex-parts, if so place a . in the middle. Concate the final string.
                for tmpEntry in ${onlyUtxoWithAssetTmp}; do
                if [[ ${#tmpEntry} -gt 56 ]]; then onlyUtxoWithAsset+="${tmpEntry:0:56}.${tmpEntry:56}|"; else onlyUtxoWithAsset+="${tmpEntry}|"; fi #representation in the rawquery output is <hexPolicyID>.<hexAssetName>
                done
                onlyUtxoWithAsset=${onlyUtxoWithAsset%?}; #remove the last char "|"

        #Check if its a transaction encryption
        elif [[ "${paramValue,,}" =~ ^enc:(.*)$ ]]; then #if the parameter starts with "enc:" then set the encryption variable
                encryption=$(trimString "${paramValue:4}");

        #Check if its a transaction encryption passphrase
        elif [[ "${paramValue,,}" =~ ^pass:(.*)$ ]]; then #if the parameter starts with "passphrase:" then set the passphrase variable
                passphrase="${paramValue:5}"; #don't do a trimstring here, because also spaces are a valid passphrase !

        fi #end of different parameters check

done

if [ ! -f "${stakeAddr}.addr" ]; then echo -e "\n\e[35mERROR - \"${stakeAddr}.addr\" does not exist!\e[0m"; exit 1; fi
if ! [[ -f "${stakeAddr}.skey" || -f "${stakeAddr}.hwsfile" ]]; then echo -e "\n\e[35mERROR - \"${stakeAddr}.skey/hwsfile\" Staking Signing Key or HardwareFile does not exist! Please create it first with script 03a.\e[0m"; exit 2; fi

#Check if toAddr file does not exists, make a dummy one in the temp directory and fill in the given parameter as the hash address
if [ ! -f "${toAddr}.addr" ]; then
                                toAddr=$(trimString "${toAddr}") #trim it if spaces present

                                #check if its a regular cardano payment address
                                typeOfAddr=$(get_addressType "${toAddr}");
                                if [[ ${typeOfAddr} == ${addrTypePayment} ]]; then echo "$(basename ${toAddr})" > ${tempDir}/tempTo.addr; toAddr="${tempDir}/tempTo";

                                #check if its an adahandle (root/sub/virtual)
                                elif checkAdaHandleFormat "${toAddr}"; then

                                        adahandleName=${toAddr,,}

                                        #resolve given adahandle into address
                                        resolveAdahandle "${adahandleName}" "toAddr" #if successful, it resolves the adahandle and writes it out into the variable 'toAddr'. also sets the variable 'utxo' if possible
                                        unset utxo #remove utxo information from the adahandle lookup, because we only use it as a destination target

                                        #resolveAdahandle did not exit with an error, so we resolved it
                                        echo "${toAddr}" > ${tempDir}/adahandle-resolve.addr; toAddr="${tempDir}/adahandle-resolve";

                                #otherwise post an error message
                                else echo -e "\n\e[35mERROR - Destination Address can't be resolved. Maybe filename wrong, or not a payment-address.\n\e[0m"; exit 1;

                                fi

else #there is a toAddr file present, lets check if a fromAddr was provided. if not, set it to the toAddr as default
	if [[ "${fromAddr}" == "" ]]; then fromAddr=${toAddr};
	echo "Set payment address to the destination address"
	fi
fi

#Check if there is a fromAddr present at this stage, its either a copy of the destination toAddr or it was provided via an optional parameter
if [[ "${fromAddr}" == "" ]]; then echo -e "\n\e[35mERROR - Fee Payment Address not provided. If you use for example an adahandle as the destination address, please specify an additional Fee Payment Address.\n\e[0m"; exit 1; fi

#Check if there are transactionMessages, if so, save the messages to a xxx.transactionMessage.json temp-file and add it to the list. Encrypt it if enabled.
if [[ ! "${transactionMessage}" == "{}" ]]; then

        transactionMessageMetadataFile="${tempDir}/$(basename ${fromAddr}).transactionMessage.json";
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
                fi

                echo "${tmp}" > ${transactionMessageMetadataFile}; metafileParameter="${metafileParameter}--metadata-json-file ${transactionMessageMetadataFile} "; #add it to the list of metadata.jsons to attach

        else
                echo -e "\n\e[35mERROR - Additional Transaction Message-Metafile is not valid:\n\n$${transactionMessage}\n\nPlease check your added Message-Paramters.\n\e[0m"; exit 1;
        fi

fi

sendFromAddr=$(trimString $(cat "${fromAddr}.addr")); check_address "${sendFromAddr}"
sendToAddr=$(trimString $(cat "${toAddr}.addr")); check_address "${sendToAddr}"
showToAddr=${adahandleName:-"${toAddr}.addr"} #shows the adahandle instead of the destination address file if available

stakingAddr=$(cat ${stakeAddr}.addr); check_address "${stakingAddr}"


echo -e "\e[0mClaim Staking Rewards from Address\e[32m ${stakeAddr}.addr\e[0m to Address\e[32m ${showToAddr}\e[0m with funds from Address\e[32m ${fromAddr}.addr\e[0m"
echo

#get live values
currentTip=$(get_currentTip); checkError "$?";
ttl=$(( ${currentTip} + ${defTTL} ))

echo -e "Current Slot-Height:\e[32m ${currentTip}\e[0m (setting TTL[invalid_hereafter] to ${ttl})"
echo
echo -e "Claim all rewards from Address ${stakeAddr}.addr: \e[32m${stakingAddr}\e[0m"
echo
echo -e "Send the rewards to Address ${showToAddr}: \e[32m${sendToAddr}\e[0m"
echo -e "Pay fees from Address ${fromAddr}.addr: \e[32m${sendFromAddr}\e[0m"

if [[ "${sendFromAddr}" == "${sendToAddr}" ]]; then rxcnt="1"; else rxcnt="2"; echo -e "\e[33mRewards-Destination-Address and Fee-Payment-Address are not the same.\e[0m"; fi

echo

        #Get rewards state data for the address. When in online mode of course from the node and the chain, in light mode via koios, in offlinemode from the transferFile
        case ${workMode} in

                "online")       showProcessAnimation "Query-StakeAddress-Info: " &
                                rewardsJSON=$(${cardanocli} ${cliEra} query stake-address-info --address ${stakingAddr} 2> /dev/null )
                                if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${rewardsJSON}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
                                rewardsJSON=$(jq -rc . <<< "${rewardsJSON}")
                                ;;

                "light")        showProcessAnimation "Query-StakeAddress-Info-LightMode: " &
                                rewardsJSON=$(queryLight_stakeAddressInfo "${stakingAddr}")
                                if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${rewardsJSON}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
                                ;;

                "offline")      readOfflineFile;        #Reads the offlinefile into the offlineJSON variable
                                rewardsJSON=$(jq -r ".address.\"${stakingAddr}\".rewardsJSON" <<< ${offlineJSON} 2> /dev/null)
                                if [[ "${rewardsJSON}" == null ]]; then echo -e "\e[35mAddress not included in the offline transferFile, please include it first online!\e[0m\n"; exit; fi
                                ;;

        esac

        rewardsEntryCnt=$(jq -r 'length' <<< ${rewardsJSON})

        if [[ ${rewardsEntryCnt} == 0 ]]; then echo -e "\e[35mStaking Address is not on the chain, register it first !\e[0m\n"; exit 1;
        else echo -e "\e[0mFound:\e[32m ${rewardsEntryCnt}\e[0m entries\n";
        fi

        rewardsSum=0

        for (( tmpCnt=0; tmpCnt<${rewardsEntryCnt}; tmpCnt++ ))
        do
        rewardsAmount=$(jq -r ".[${tmpCnt}].rewardAccountBalance" <<< ${rewardsJSON})

        delegationPoolID=$(jq -r ".[${tmpCnt}].delegation // .[${tmpCnt}].stakeDelegation" <<< ${rewardsJSON})

        rewardsSum=$((${rewardsSum}+${rewardsAmount}))

        echo -ne "[$((${tmpCnt}+1))]\t"

        #Checking about rewards on the stake address
        if [[ ${rewardsAmount} == 0 ]]; then echo -e "\e[35mNo rewards found on the stake Addr !\e[0m";
        else echo -e "Entry Rewards: \e[33m$(convertToADA ${rewardsAmount}) ADA / ${rewardsAmount} lovelaces\e[0m"
        fi

        #If delegated to a pool, show the current pool ID
        if [[ ! ${delegationPoolID} == null ]]; then
                echo -e "   \tAccount is delegated to a Pool with ID: \e[32m${delegationPoolID}\e[0m";

                if [[ ${onlineMode} == true && ${koiosAPI} != "" ]]; then

                        #query poolinfo via poolid on koios
			errorcnt=0; error=-1;
                        showProcessAnimation "Query Pool-Info via Koios: " &
        		while [[ ${errorcnt} -lt 5 && ${error} -ne 0 ]]; do #try a maximum of 5 times to request the information
                		error=0
				response=$(curl -sL -m 30 -X POST -w "---spo-scripts---%{http_code}" "${koiosAPI}/pool_info" -H "Accept: application/json" -H "Content-Type: application/json" -d "{\"_pool_bech32_ids\":[\"${delegationPoolID}\"]}" 2> /dev/null)
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

                else

                echo -e "   \tAccount is not delegated to a Pool !";

        fi

        echo

        done

	if [[ ${rewardsSum} -eq 0 ]]; then exit 1; fi;

        if [[ ${rewardsEntryCnt} -gt 1 ]]; then echo -e "   \t-----------------------------------------\n"; echo -e "   \tTotal Rewards: \e[33m$(convertToADA ${rewardsSum}) ADA / ${rewardsSum} lovelaces\e[0m\n"; fi


#-------------------------------------

echo -e "\n--------------------------------------------\n"


#
# Checking UTXO Data of the source address and gathering data about total lovelaces and total assets
#

        #Get UTX0 Data for the address. When in online mode of course from the node and the chain, in lightmode via API requests, in offlinemode from the transferFile
        case ${workMode} in
                "online")
				#check that the node is fully synced, otherwise the query would mabye return a false state
                                if [[ $(get_currentSync) != "synced" ]]; then echo -e "\e[35mError - Node not fully synced or not running, please let your node sync to 100% first !\e[0m\n"; exit 1; fi
                                showProcessAnimation "Query-UTXO: " &
                                utxo=$(${cardanocli} ${cliEra} query utxo --address ${sendFromAddr} 2> /dev/stdout);
                                if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${utxo}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
                                if [[ ${skipUtxoWithAsset} != "" ]]; then utxo=$(echo "${utxo}" | egrep -v "${skipUtxoWithAsset}" ); fi #if its set to keep utxos that contains certain policies, filter them out
                                if [[ ${onlyUtxoWithAsset} != "" ]]; then utxo=$(echo "${utxo}" | egrep "${onlyUtxoWithAsset}" ); utxo=$(echo -e "Header\n-----\n${utxo}"); fi #only use given utxos. rebuild the two header lines
                                if [[ ${utxoLimitCnt} -gt 0 ]]; then utxo=$(echo "${utxo}" | head -n $(( ${utxoLimitCnt} + 2 )) ); fi #if there was a utxo cnt limit set, reduce it (+2 for the header)
                                showProcessAnimation "Convert-UTXO: " &
                                utxoJSON=$(generate_UTXO "${utxo}" "${sendFromAddr}"); stopProcessAnimation;
                                ;;

                "light")
                                showProcessAnimation "Query-UTXO-LightMode: " &
                                utxo=$(queryLight_UTXO "${sendFromAddr}");
                                if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${utxo}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
                                if [[ ${skipUtxoWithAsset} != "" ]]; then utxo=$(echo "${utxo}" | egrep -v "${skipUtxoWithAsset}" ); fi #if its set to keep utxos that contains certain policies, filter them out
                                if [[ ${onlyUtxoWithAsset} != "" ]]; then utxo=$(echo "${utxo}" | egrep "${onlyUtxoWithAsset}" ); utxo=$(echo -e "Header\n-----\n${utxo}"); fi #only use given utxos. rebuild the two header lines
                                if [[ ${utxoLimitCnt} -gt 0 ]]; then utxo=$(echo "${utxo}" | head -n $(( ${utxoLimitCnt} + 2 )) ); fi #if there was a utxo cnt limit set, reduce it (+2 for the header)
                                showProcessAnimation "Convert-UTXO: " &
                                utxoJSON=$(generate_UTXO "${utxo}" "${sendFromAddr}"); stopProcessAnimation;
                                ;;


                "offline")      readOfflineFile;        #Reads the offlinefile into the offlineJSON variable
                                utxoJSON=$(jq -r ".address.\"${sendFromAddr}\".utxoJSON" <<< ${offlineJSON} 2> /dev/null)
                                if [[ "${utxoJSON}" == null ]]; then echo -e "\e[35mPayment-Address not included in the offline transferFile, please include it first online!\e[0m\n"; exit 1; fi
                                ;;
        esac

        #Only use UTXOs specied in the extra parameter if present
        if [[ ! "${filterForUTXO}" == "" ]]; then echo -e "\e[0mUTXO-Mode: \e[32mOnly using the UTXO with Hash ${filterForUTXO}\e[0m\n"; utxoJSON=$(filterFor_UTXO "${utxoJSON}" "${filterForUTXO}"); fi

	txcnt=$(jq length <<< ${utxoJSON}) #Get number of UTXO entries (Hash#Idx), this is also the number of --tx-in for the transaction
	if [[ ${txcnt} == 0 ]]; then echo -e "\e[35mNo funds on the Source Address!\e[0m\n"; exit 1; else echo -e "\e[32m${txcnt} UTXOs\e[0m found on the Source Address!\n"; fi

        totalLovelaces=0
        totalAssetsJSON="{}"; 	#Building a total JSON with the different assetstypes "policyIdHash.name", amount and name
        totalPolicyIDsLIST=""; #Buffer for the policyIDs, will be sorted/uniq/linecount at the end of the query
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
#       echo -e "Hash#Index: ${utxoHashIndex}\tAmount: ${utxoAmount}";
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

#There are metadata file attached, list them:
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
        "online")       protocolParametersJSON=$(${cardanocli} ${cliEra} query protocol-parameters );; #onlinemode
        "light")        protocolParametersJSON=${lightModeParametersJSON};; #lightmode
        "offline")      protocolParametersJSON=$(jq ".protocol.parameters" <<< ${offlineJSON});; #offlinemode
esac
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

minOutUTXO=$(calc_minOutUTXO "${protocolParametersJSON}" "${sendToAddr}+1000000${assetsOutString}")

#-------------------------------------

#withdrawal string
withdrawal="${stakingAddr}+${rewardsSum}"

#Generate Dummy-TxBody file for fee calculation
txBodyFile="${tempDir}/dummy.txbody"
rm ${txBodyFile} 2> /dev/null
if [[ ${rxcnt} == 1 ]]; then
                        ${cardanocli} ${cliEra} transaction build-raw ${txInString} --tx-out "${sendToAddr}+1000000${assetsOutString}" --invalid-hereafter ${ttl} --fee 0 ${metafileParameter} --withdrawal ${withdrawal} --out-file ${txBodyFile}
			checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
                        else
                        ${cardanocli} ${cliEra} transaction build-raw ${txInString} --tx-out "${sendFromAddr}+1000000${assetsOutString}" --tx-out ${sendToAddr}+1000000 --invalid-hereafter ${ttl} --fee 0 ${metafileParameter} --withdrawal ${withdrawal} --out-file ${txBodyFile}
			checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
fi
fee=$(${cardanocli} ${cliEra} transaction calculate-min-fee --tx-body-file ${txBodyFile} --protocol-params-file <(echo ${protocolParametersJSON}) --tx-in-count ${txcnt} --tx-out-count ${rxcnt} --witness-count 2 --byron-witness-count 0 | awk '{ print $1 }')

echo -e "\e[0mMimimum transfer Fee for ${txcnt}x TxIn & ${rxcnt}x TxOut & Withdrawal: \e[32m $(convertToADA ${fee}) ADA / ${fee} lovelaces \e[90m"

#If only one address (paying for the fees and also receiving the rewards)
#If two different addresse (fromAddr is paying for the fees, toAddr is getting the rewards)
if [[ ${rxcnt} == 1 ]]; then

			#calculate the lovelaces to return to the payment address
			lovelacesToReturn=$(( ${totalLovelaces}-${fee}+${rewardsSum} ))
			#Checking about minimum funds in the UTX0
                        echo -e "\e[0mLovelaces that will be returned to destination Address (UTXO-Sum - fees + rewards): \e[33m $(convertToADA ${lovelacesToReturn}) ADA / ${lovelacesToReturn} lovelaces \e[90m"
			if [[ ${lovelacesToReturn} -lt ${minOutUTXO} ]]; then echo -e "\e[35mNot enough funds on the source Addr! Minimum UTXO value is ${minOutUTXO} lovelaces.\e[0m"; exit; fi

			echo

			else

                        #calculate the lovelaces to return to the fee payment address
                        lovelacesToReturn=$(( ${totalLovelaces}-${fee} ))
                        #Checking about minimum funds in the UTX0
                        echo -e "\e[0mLovelaces that will be sent to the destination Address (rewards): \e[33m $(convertToADA ${rewardsSum}) ADA / ${rewardsSum} lovelaces \e[90m"
                        echo -e "\e[0mLovelaces that will be returned to the fee payment Address (UTXO-Sum - fees): \e[32m $(convertToADA ${lovelacesToReturn}) ADA / ${lovelacesToReturn} lovelaces \e[90m"
                        if [[ ${lovelacesToReturn} -lt ${minOutUTXO} ]]; then echo -e "\e[35mNot enough funds on the source Addr! Minimum UTXO value is ${minOutUTXO} lovelaces.\e[0m"; exit; fi
                        echo

fi

txBodyFile="${tempDir}/$(basename ${fromAddr}).txbody"
txWitnessFile="${tempDir}/$(basename ${fromAddr}).txwitness"
txFile="${tempDir}/$(basename ${fromAddr}).tx"
echo
echo -e "\e[0mBuilding the unsigned transaction body: \e[32m ${txBodyFile} \e[90m"
echo

#Building unsigned transaction body

if [[ ${rxcnt} == 1 ]]; then
			${cardanocli} ${cliEra} transaction build-raw ${txInString} --tx-out "${sendToAddr}+${lovelacesToReturn}${assetsOutString}" --invalid-hereafter ${ttl} --fee ${fee} ${metafileParameter} --withdrawal ${withdrawal} --out-file ${txBodyFile}
			else
                        ${cardanocli} ${cliEra} transaction build-raw ${txInString} --tx-out "${sendFromAddr}+${lovelacesToReturn}${assetsOutString}" --tx-out ${sendToAddr}+${rewardsSum} --invalid-hereafter ${ttl} --fee ${fee} ${metafileParameter} --withdrawal ${withdrawal} --out-file ${txBodyFile}
fi

dispFile=$(cat ${txBodyFile}); if ${cropTxOutput} && [[ ${#dispFile} -gt 4000 ]]; then echo "${dispFile:0:4000} ... (cropped)"; else echo "${dispFile}"; fi
echo

#If stakeaddress and payment address are from the same hardware files
paymentName=$(basename ${fromAddr} .payment) #contains the name before the .payment.addr extension
stakingName=$(basename ${stakeAddr} .staking) #contains the name before the .staking.addr extension
if [[ -f "${fromAddr}.hwsfile" && -f "${stakeAddr}.hwsfile" && "${paymentName}" == "${stakingName}" ]]; then

        echo -ne "\e[0mAutocorrect the TxBody for canonical order: "
        tmp=$(autocorrect_TxBodyFile "${txBodyFile}"); if [ $? -ne 0 ]; then echo -e "\e[35m${tmp}\e[0m\n\n"; exit 1; fi
        echo -e "\e[32m${tmp}\e[90m\n"

	dispFile=$(cat ${txBodyFile}); if ${cropTxOutput} && [[ ${#dispFile} -gt 4000 ]]; then echo "${dispFile:0:4000} ... (cropped)"; else echo "${dispFile}"; fi
	echo

	echo -e "\e[0mSign (Witness+Assemble) the unsigned transaction body with the \e[32m${fromAddr}.hwsfile\e[0m & \e[32m${stakeAddr}.hwsfile\e[0m: \e[32m ${txFile} \e[90m"
	echo

	#Witness and Assemble the TxFile
        start_HwWallet; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
        tmp=$(${cardanohwcli} transaction witness --tx-file ${txBodyFile} --hw-signing-file ${fromAddr}.hwsfile --hw-signing-file ${stakeAddr}.hwsfile --change-output-key-file ${fromAddr}.hwsfile --change-output-key-file ${stakeAddr}.hwsfile ${magicparam} --out-file ${txWitnessFile}-payment --out-file ${txWitnessFile}-staking 2> /dev/stdout)
        if [[ "${tmp^^}" =~ (ERROR|DISCONNECT) ]]; then echo -e "\e[35m${tmp}\e[0m\n"; exit 1; else echo -ne "\e[0mWitnessed ... "; fi
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

	${cardanocli} ${cliEra} transaction assemble --tx-body-file ${txBodyFile} --witness-file ${txWitnessFile}-payment --witness-file ${txWitnessFile}-staking --out-file ${txFile}
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
	echo -e "Assembled ... \e[32mDONE\e[0m\n";


elif [[ -f "${stakeAddr}.skey" && -f "${fromAddr}.skey" ]]; then #with the normal cli skey

        #read the needed signing keys into ram and sign the transaction
        skeyJSON1=$(read_skeyFILE "${fromAddr}.skey"); if [ $? -ne 0 ]; then echo -e "\e[35m${skeyJSON1}\e[0m\n"; exit 1; else echo -e "\e[32mOK\e[0m\n"; fi
        skeyJSON2=$(read_skeyFILE "${stakeAddr}.skey"); if [ $? -ne 0 ]; then echo -e "\e[35m${skeyJSON2}\e[0m\n"; exit 1; else echo -e "\e[32mOK\e[0m\n"; fi

	echo -e "\e[0mSign the unsigned transaction body with the \e[32m${fromAddr}.skey\e[0m & \e[32m${stakeAddr}.skey\e[0m: \e[32m ${txFile} \e[90m"
	echo

        ${cardanocli} ${cliEra} transaction sign --tx-body-file ${txBodyFile} --signing-key-file <(echo "${skeyJSON1}") --signing-key-file <(echo "${skeyJSON2}") --out-file ${txFile}
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

	#forget the signing keys
	unset skeyJSON1
	unset skeyJSON2

else
echo -e "\e[35mThis combination is not allowed! A Hardware-Wallet can only be used to claim its own staking rewards on the chain.\e[0m\n"; exit 1;
fi
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
echo -ne "\e[90m"

dispFile=$(cat ${txFile}); if ${cropTxOutput} && [[ ${#dispFile} -gt 4000 ]]; then echo "${dispFile:0:4000} ... (cropped)"; else echo "${dispFile}"; fi
echo

#If you wanna skip the Prompt, set the environment variable ENV_SKIP_PROMPT to "YES" - be careful!!!
#if ask "\e[33mDoes this look good for you, continue ?" N; then
if [ "${ENV_SKIP_PROMPT}" == "YES" ] || ask "\n\e[33mDoes this look good for you, continue ?" N; then

        echo
        case ${workMode} in
        "online")
                                #onlinesubmit
                                echo -ne "\e[0mSubmitting the transaction via the node... "
                                ${cardanocli} ${cliEra} transaction submit --tx-file ${txFile}
                                checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
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
                                                                        type: \"Withdrawal\",
                                                                        era: \"$(jq -r .protocol.era <<< ${offlineJSON})\",
                                                                        stakeAddr: \"${stakeAddr}\",
									stakingAddr: \"${stakingAddr}\",
									fromAddr: \"${fromAddr}\",
                                                                        sendFromAddr: \"${sendFromAddr}\",
                                                                        toAddr: \"${toAddr}\",
                                                                        sendToAddr: \"${sendToAddr}\",
                                                                        txJSON: ${txFileJSON} } ]" <<< ${offlineJSON})
                                #Write the new offileFile content
                                offlineJSON=$( jq ".history += [ { date: \"$(date -R)\", action: \"signed rewards withdrawal from '${stakeAddr}' to '${toAddr}', payment via '${fromAddr}'\" } ]" <<< ${offlineJSON})
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
