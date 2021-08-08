#!/bin/bash

# Script is brought to you by ATADA_Stakepool, Telegram @atada_stakepool

#load variables from common.sh
. "$(dirname "$0")"/00_common.sh


#ShowUsage
showUsage() {
cat >&2 <<EOF
Usage:  $(basename $0) <From AddressName> <To AddressName OR HASH> <PolicyID.Name OR asset1-name OR PATH to the AssetFile(.asset)> <Amount of Assets to send OR keyword ALL>
        [Opt: Amount of lovelaces to include]
        [Opt: Transaction-Metadata.json/.cbor]
        [Opt: list of UTXOs to use, | is the separator]
        [Opt: Message comment, starting with "msg: ...", | is the separator]


Optional parameters:

- If you wanna send multiple Assets at the same time, you can use the | as the separator, must be in "..." for the parameter 3:
   "myassets/mypolicy.mytoken 10" ... to send 10 tokens specified in the asset-file
   "myassets/mypolicy.mytoken 10|asset1hgxml0wxcw903pdsgzr8gyvwg8ch40v0fvnmjl 20" ... to send 10 mytoken and 20 tokens with bech asset1...
   "asset1hgxml0wxcw903pdsgzr8gyvwg8ch40v0fvnmjl all|asset1ra679n0pql7hc57qjlah3cjhaygywgccsufmpn all" ... to send all tokens of the given asset-names

- You can also send all Assets with a specified policyID, or a policyID.name* with the * at the end for parameter 3:
  "b43131f2c82825ee3d81705de0896c611f35ed38e48e33a3bdf298dc.* all" ... to send out all your CryptoMage NFTs
  "34250edd1e9836f5378702fbf9416b709bc140e04f668cc355208518.Coin* all" .. to send out all your Assets for that policyID starting with the name "Coin"

- Normally you don't need to specify an Amount of lovelaces to include, the script will calculcate the minimum Amount that is needed by its own.
  If you wanna send a specific amount, just provide the amount in lovelaces as one of the optional parameters.

- If you wanna attach a Transaction-Message like a short comment, invoice-number, etc with the transaction:
   You can just add one or more Messages in quotes starting with "msg: ..." as a parameter. Max. 64chars / Message
   "msg: This is a short comment for the transaction" ... that would be a one-liner comment
   "msg: This is a the first comment line|and that is the second one" ... that would be a two-liner comment, | is the separator !

- You can attach a transaction-metadata.json by adding the filename of the .json file to the parameters

- You can attach a transaction-metadata.cbor by adding the filename of the .cbor file to the parameters (catalystvoting f.e.)

- In rare cases you wanna define the exact UTXOs that should be used for sending Assets out:
    "UTXO1#Index" ... to specify one UTXO, must be in "..."
    "UTXO1#Index|UTXO2#Index" ... to specify more UTXOs provide them with the | as separator, must be in "..."

EOF
}



#Read in all command line parameters, doing it that way preserves the  parameters in quotes ""
paramCnt=$#; allParameters=( "$@" );

optionalParameterIdxStart=4; #will be automatically reduced to 3 if assetToSend&amountToSend is within parameter 3

fromAddr=""; toAddr=""; bechAssetsToSendJSON="{}";

#Read in the fromAddr->sendFromAddr & toAddr->sendToAddr
if [ ${paramCnt} -ge 2 ]; then
	fromAddr="$(dirname $1)/$(basename ${allParameters[0]} .addr)"; fromAddr=${fromAddr/#.\//}
	if [ ! -f "${fromAddr}.addr" ]; then echo -e "\n\e[35mERROR - \"${fromAddr}.addr\" does not exist! Please create it first with script 03a or 02.\e[0m"; exit 1; fi
	if ! [[ -f "${fromAddr}.skey" || -f "${fromAddr}.hwsfile" ]]; then echo -e "\n\e[35mERROR - \"${fromAddr}.skey/hwsfile\" does not exist! Please create it first with script 03a or 02.\e[0m"; exit 1; fi
	sendFromAddr=$(cat ${fromAddr}.addr)
	check_address "${sendFromAddr}"

	toAddr="$(dirname $2)/$(basename ${allParameters[1]} .addr)"; toAddr=${toAddr/#.\//}
	#Check if toAddr file doesn not exists, make a dummy one in the temp directory and fill in the given parameter as the hash address
	if [ ! -f "${toAddr}.addr" ]; then echo "$(basename ${toAddr})" > ${tempDir}/tempTo.addr; toAddr="${tempDir}/tempTo"; fi
	sendToAddr=$(cat ${toAddr}.addr)
	check_address "${sendToAddr}"

	else echo -e "\n\e[35mERROR - Missing parameters FromAddress/ToAddress.\n\e[0m"; showUsage; exit 1;
fi

#Read in the assetToSend/amountToSend and check if the parameter#3[index 2] is in the form "xxx yyy"
#Also check about if the amount is a number or keyword ALL for each entry, etc...
if [ ${paramCnt} -ge 3 ]; then
        IFS='|' read -ra allAssetsToSend <<< "${allParameters[2]}" #split by the separator |
	for (( tmpCnt=0; tmpCnt<${#allAssetsToSend[@]}; tmpCnt++ )) #go thru all entries
                do
		        IFS=' ' read -ra tmpEntry <<< "$(trimString "${allAssetsToSend[tmpCnt]}")" #split the entry by the separator ' '

			assetToSend=${tmpEntry[0]}
			amountToSend=${tmpEntry[1]^^} #use the uppercase value (easier to check for keyword ALL)

			#If the total assetsEntryCombo amount is only one and the splitted entrycount is 1 (asset&amount) and the paramCnt >= 4 and the 4th parameter is a number or ALL, than use this as the amountToSend
			if [[ ${#allAssetsToSend[@]} -eq 1 ]] && [[ ${#tmpEntry[@]} -eq 1 ]] && [[ ${paramCnt} -ge 4 ]]; then
			fourthParameter=${allParameters[3]^^};
				if [[ -z "${fourthParameter##*[!0-9]*}" ]] && [[ ! "${fourthParameter}" == "ALL" ]]; then echo -e "\n\e[35mERROR - missing AssetName/File or sending amount is not a number or keyword ALL.\n\e[0m"; showUsage; exit 1;
				elif [[ $(bc <<< "${fourthParameter} < 1") -eq 1 ]]; then  echo -e "\n\e[35mError - Please input a positive sending amount !\e[0m\n"; exit 1; fi
			amountToSend=${fourthParameter};

			#If the splitted entry is not 2 (asset&amount), or if the amountToSend is not a number -> show usage and exit
			elif [[ ${#tmpEntry[@]} -ne 2 ]]; then echo -e "\n\e[35mERROR - Two parameters needed per Asset to send: AssetName/File/Bech and the Amount to send.\nIssue is with \"${assetToSend}\".\n\e[0m"; showUsage; exit 1;

			#If the splitted entry is 2 (what it should be), check about that the parameter is a number or keyword ALL
			elif [[ ${#tmpEntry[@]} -eq 2 ]]; then
				if [[ -z "${amountToSend##*[!0-9]*}" ]] && [[ ! "${amountToSend}" == "ALL" ]]; then echo -e "\n\e[35mERROR - Sending amount is not a number or keyword ALL, or below zero.\n\e[0m"; showUsage; exit 1;
				elif [[ $(bc <<< "${amountToSend} < 1") -eq 1 ]]; then  echo -e "\n\e[35mError - Please input a positive sending amount !\e[0m\n"; exit 1; fi
				optionalParameterIdxStart=3; #assetToSend and amountToSend was given within a single Parameter #3[index 2], so the optional parameters will start at index 3 in this case, normally at index 4
			fi

			#Collect all the given Assets in a JSON for easier access, also convert all the entries into the bech32 format

			#Check if the assetToSend is a bech32 assetname (starts with "asset" and bech32 tool confirms a valid bech name)
			if [[ "${assetToSend}" =~ ^asset(.*)$ ]] && [[ "${#assetToSend}" -eq 44 ]]; then
		        	tmp=$(${bech32_bin} 2> /dev/null <<< "${assetToSend}") #will have returncode 0 if the bech was valid
				if [ $? -ne 0 ]; then echo -e "\n\e[35mERROR - \"${assetToSend}\" is not a valid bech32 asset.\n\e[0m"; showUsage; exit 1; fi
				assetBechToSend=${assetToSend}; #just copy it, already a valid bech32 asset

			#Check if the assetToSend is a policyID.assetName string, if so, convert it bech32
			elif [[ "${assetToSend}" =~ ^[[:xdigit:]]{56}(\.[[:alnum:]]{1,32})?$ ]]; then
				if [[ "${assetToSend}" == *"."* ]]; then assetBechToSend=$(convert_tokenName2BECH $(echo ${assetToSend} | cut -d. -f 1) $(echo ${assetToSend} | cut -d. -f 2) )
								    else assetBechToSend=$(convert_tokenName2BECH "${assetToSend}") #nameless token
				fi

			#Check if the assetToSend is a policyID.* string, if so, store it as a bulk entry
			elif [[ "${assetToSend}" =~ ^[[:xdigit:]]{56}\.(.{0,31})\*$ ]]; then
				if [[ "${amountToSend}" == "ALL" ]]; then assetBechToSend="${assetToSend:0:-1}-BULK"; #cut of the last char * and store it in the sending list
								     else echo -e "\n\e[35mError with Bulk-Selection of policyID: \e[0m${assetToSend}\n\n\e[35mPlease set the sending amount to \e[0mALL \e[35m!\e[0m\n"; exit 1; fi

			#Check if the assetToSend is a file xxx.asset then read out the data from the file instead
			assetFile="$(dirname ${assetToSend})/$(basename "${assetToSend}" .asset).asset"
			elif [ -f "${assetFile}" ]; then
				tmpAssetPolicy="$(jq -r .policyID < ${assetFile})"
				tmpAssetName="$(jq -r .name < ${assetFile})"
				assetBechToSend=$(convert_tokenName2BECH ${tmpAssetPolicy} ${tmpAssetName} )

			#Otherwise print an error message, that the given assetToSend couldnot be resolved
			else
				echo -e "\n\e[35mERROR - The given asset \"${assetToSend}\" could not be resolved from a valid asset-file, bech32 asset or policyID.assetName!\n\e[0m"; showUsage; exit 1;
			fi

			#Collect the amounts of assets to send in the specific JSON. Add them up if assets are referenced more than once
			#The keyword ALL overwrites all other entries
			oldValue=$(jq -r ".\"${assetBechToSend}\".amount" <<< ${bechAssetsToSendJSON})
			sumUp=$(jq -r ".\"${assetBechToSend}\".sumup" <<< ${bechAssetsToSendJSON})
			if [[ ! "${oldValue}" == null ]] && [[ ! "${sumUp}" == "true" ]]; then
			   if ! ask "\e[33mYou specified the following asset more than once:\n\e[0m${assetToSend} (\e[32m${assetBechToSend}\e[0m)\n\e[33mDo you wanna sum the amount up for that specific asset?\e[0m" N; then echo; exit 1; else sumUp="true"; echo; fi
			fi
			if [[ "${amountToSend}" == "ALL" ]] || [[ "${oldValue}" == "ALL" ]]; then newValue="ALL"; else newValue=$(bc <<< "${oldValue}+${amountToSend}"); fi
                        bechAssetsToSendJSON=$( jq ". += {\"${assetBechToSend}\":{amount: \"${newValue}\", input: \"${assetToSend}\", sumup: \"${sumUp}\"}}" <<< ${bechAssetsToSendJSON})

			#echo -e "assetToSend: ${assetToSend}\namountToSend: ${amountToSend}\nassetBechTosend: ${assetBechToSend}\n"
                done

else echo -e "\n\e[35mERROR - Missing parameters AssetName/Amount.\n\e[0m"; showUsage; exit 1;

fi

#jq . <<< ${bechAssetsToSendJSON}; #debug output
#exit

#Check all optional parameters about there types and set the corresponding variables
#Starting with the 5th parameter (normally index4) up to the last parameter
metafileParameter=""; metafile=""; lovelacesToSend=0; filterForUTXO=""; transactionMessage="{}"; #Setting defaults

for (( tmpCnt=${optionalParameterIdxStart}; tmpCnt<${paramCnt}; tmpCnt++ ))
 do
	paramValue=${allParameters[$tmpCnt]}
	#echo -n "${tmpCnt}: ${paramValue} -> "

        #Check if an additional amount of lovelaces was set as parameter (not a message, not an UTXO#IDX, not empty, beeing a number)
	if [[ ! "${paramValue,,}" =~ ^msg:(.*)$ ]] && [[ ! "${paramValue}" =~ ^([[:xdigit:]]+#[[:digit:]]+(\|?)){1,}$ ]] && [[ ! ${paramValue} == "" ]] && [ ! -z "${paramValue##*[!0-9]*}" ]; then lovelacesToSend=${paramValue};

        #Check if an additional metadata.json/.cbor was set as parameter (not a message, not an UTXO#IDX, not empty, not beeing a number)
        elif [[ ! "${paramValue,,}" =~ ^msg:(.*)$ ]] && [[ ! "${paramValue}" =~ ^([[:xdigit:]]+#[[:digit:]]+(\|?)){1,}$ ]] && [[ ! ${paramValue} == "" ]] && [ -z "${paramValue##*[!0-9]*}" ]; then

             metafile="$(dirname ${paramValue})/$(basename $(basename ${paramValue} .json) .cbor)"; metafile=${metafile//.\//}
             if [ -f "${metafile}.json" ]; then metafile="${metafile}.json"
                #Do a simple basic check if the metadatum is in the 0..65535 range
                metadatum=$(jq -r "keys_unsorted[0]" ${metafile} 2> /dev/null)
                if [[ $? -ne 0 ]]; then echo "ERROR - '${metafile}' is not a valid JSON file"; exit 1; fi
                #Check if it is null, a number, lower then zero, higher then 65535, otherwise exit with an error
                if [ "${metadatum}" == null ] || [ -z "${metadatum##*[!0-9]*}" ] || [ "${metadatum}" -lt 0 ] || [ "${metadatum}" -gt 65535 ]; then echo "ERROR - MetaDatum Value '${metadatum}' in '${metafile}' must be in the range of 0..65535!"; exit 1; fi
                metafileParameter="${metafileParameter}--metadata-json-file ${metafile} "; metafileList="${metafileList}${metafile} "
             elif [ -f "${metafile}.cbor" ]; then metafile="${metafile}.cbor"
                metafileParameter="${metafileParameter}--metadata-cbor-file ${metafile} "; metafileList="${metafileList}${metafile} "
             else echo -e "The specified Metadata JSON/CBOR-File '${metafile}' does not exist. Fileextension must be '.json' or '.cbor' Please try again."; exit 1;
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

	fi #end of different parameters check

done

#Check if there are transactionMessages, if so, save the messages to a xxx.transactionMessage.json temp-file and add it to the list
if [[ ! "${transactionMessage}" == "{}" ]]; then
        transactionMessageMetadataFile="${tempDir}/$(basename ${fromAddr}).transactionMessage.json";
        tmp=$( jq . <<< ${transactionMessage} 2> /dev/null)
        if [ $? -eq 0 ]; then echo "${tmp}" > ${transactionMessageMetadataFile}; metafileParameter="${metafileParameter}--metadata-json-file ${transactionMessageMetadataFile} "; #add it to the list of metadata.jsons to attach
                         else echo -e "\n\e[35mERROR - Additional Transaction Message-Metafile is not valid:\n\n$${transactionMessage}\n\nPlease check your added Message-Paramters.\n\e[0m"; exit 1; fi
fi

echo -e "\e[0mSending assets from Address\e[32m ${fromAddr}.addr\e[0m to Address\e[32m ${toAddr}.addr\e[0m:"
echo

#get live values
currentTip=$(get_currentTip)
ttl=$(get_currentTTL)
currentEPOCH=$(get_currentEpoch)

echo -e "\e[0mCurrent Slot-Height:\e[32m ${currentTip} \e[0m(setting TTL[invalid_hereafter] to ${ttl})"
echo

echo -e "\e[0mSource Address ${fromAddr}.addr:\e[32m ${sendFromAddr} \e[90m"
echo -e "\e[0mDestination Address ${toAddr}.addr:\e[32m ${sendToAddr} \e[90m"
echo

#
# Checking UTXO Data of the source address and gathering data about total lovelaces and total assets
#
        #Get UTX0 Data for the address. When in online mode of course from the node and the chain, in offlinemode from the transferFile
        if ${onlineMode}; then
                                utxo=$(${cardanocli} query utxo --address ${sendFromAddr} ${magicparam} ); checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi;
                                utxoJSON=$(generate_UTXO "${utxo}" "${sendFromAddr}")
                                #utxoJSON=$(${cardanocli} query utxo --address ${sendFromAddr} ${magicparam} --out-file /dev/stdout); checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi;
                          else
                                readOfflineFile;        #Reads the offlinefile into the offlineJSON variable
                                utxoJSON=$(jq -r ".address.\"${sendFromAddr}\".utxoJSON" <<< ${offlineJSON})
                                if [[ "${utxoJSON}" == null ]]; then echo -e "\e[35mPayment-Address not included in the offline transferFile, please include it first online!\e[0m\n"; exit 1; fi
        fi

        #Only use UTXOs specified in the extra parameter if present
        if [[ ! "${filterForUTXO}" == "" ]]; then echo -e "\e[0mUTXO-Mode: \e[32mOnly using the UTXO with Hash ${filterForUTXO}\e[0m\n"; utxoJSON=$(filterFor_UTXO "${utxoJSON}" "${filterForUTXO}"); fi

	txcnt=$(jq length <<< ${utxoJSON}) #Get number of UTXO entries (Hash#Idx), this is also the number of --tx-in for the transaction
	if [[ ${txcnt} == 0 ]]; then echo -e "\e[35mNo funds on the Source Address!\e[0m\n"; exit 1; else echo -e "\e[32m${txcnt} UTXOs\e[0m found on the Source Address!\n"; fi

	#Calculating the total amount of lovelaces in all utxos on this address
        totalLovelaces=0

        totalAssetsJSON="{}"; 	#Building a total JSON with the different assetstypes "policyIdHash.name", amount and name
        totalPolicyIDsJSON="{}"; #Holds the different PolicyIDs as values "policyIDHash", length is the amount of different policyIDs

	assetsReturnString="";	#This will hold the String to append on the --tx-out if assets present or it will be empty


        #For each utxo entry, check the utxo#index and check if there are also any assets in that utxo#index
        #LEVEL 1 - different UTXOs
        for (( tmpCnt=0; tmpCnt<${txcnt}; tmpCnt++ ))
        do
        utxoHashIndex=$(jq -r "keys_unsorted[${tmpCnt}]" <<< ${utxoJSON})
        utxoAmount=$(jq -r ".\"${utxoHashIndex}\".value.lovelace" <<< ${utxoJSON})   #Lovelaces
        totalLovelaces=$(bc <<< "${totalLovelaces} + ${utxoAmount}" )
        echo -e "Hash#Index: ${utxoHashIndex}\tAmount: ${utxoAmount}"
        assetsJSON=$(jq -r ".\"${utxoHashIndex}\".value | del (.lovelace)" <<< ${utxoJSON}) #All values without the lovelaces entry
        assetsEntryCnt=$(jq length <<< ${assetsJSON})

        if [[ ${assetsEntryCnt} -gt 0 ]]; then
                        #LEVEL 2 - different policyIDs
                        for (( tmpCnt2=0; tmpCnt2<${assetsEntryCnt}; tmpCnt2++ ))
                        do
                        assetHash=$(jq -r "keys_unsorted[${tmpCnt2}]" <<< ${assetsJSON})  #assetHash = policyID
                        assetsNameCnt=$(jq ".\"${assetHash}\" | length" <<< ${assetsJSON})
                        totalPolicyIDsJSON=$( jq ". += {\"${assetHash}\": 1}" <<< ${totalPolicyIDsJSON})

                                #LEVEL 3 - different names under the same policyID
                                for (( tmpCnt3=0; tmpCnt3<${assetsNameCnt}; tmpCnt3++ ))
                                do
                                assetName=$(jq -r ".\"${assetHash}\" | keys_unsorted[${tmpCnt3}]" <<< ${assetsJSON})
                                assetAmount=$(jq -r ".\"${assetHash}\".\"${assetName}\"" <<< ${assetsJSON})
                                assetBech=$(convert_tokenName2BECH ${assetHash} ${assetName})
                                if [[ "${assetName}" == "" ]]; then point=""; else point="."; fi

                                oldValue=$(jq -r ".\"${assetHash}${point}${assetName}\".amount" <<< ${totalAssetsJSON})
                                newValue=$(bc <<< "${oldValue}+${assetAmount}")
                                totalAssetsJSON=$( jq ". += {\"${assetHash}${point}${assetName}\":{amount: \"${newValue}\", name: \"${assetName}\", bech: \"${assetBech}\"}}" <<< ${totalAssetsJSON})
                                echo -e "\e[90m                           Asset: ${assetBech}  Amount: ${assetAmount} ${assetName}\e[0m"

				#special process to lookup if there is a bulk sending entry in the ${bechAssetsToSendJSON}, if so, add the current asset with amount ALL to that list
				#this bulk sending is only processed for assets with an assetname like NFTs, not for nameless assets. they have to be sent separate
				if [[ ! "${assetName}" == "" ]] && [[ "${bechAssetsToSendJSON}" =~ ${assetHash}\.(.*)-BULK ]]; then
					tmpFullKeyFound=${BASH_REMATCH[0]}; tmpCompareFound=${BASH_REMATCH[0]:0:-5};
					if [[ ! $(grep "${tmpCompareFound}" <<< "${assetHash}.${assetName}") == "" ]]; then
					bechAssetsToSendJSON=$( jq ". += {\"${assetBech}\":{amount: \"ALL\", input: \"* ${assetHash}.${assetName}\"}}" <<< ${bechAssetsToSendJSON}) #add the current asset to the sending list
					bechAssetsToSendJSON=$( jq ".\"${tmpFullKeyFound}\".bulkfound = \"true\"" <<< ${bechAssetsToSendJSON}) #mark the bulksending entry itself as used by adding the key bulk=true to it for later filtering
					fi
				fi

                                done
                        done

        fi
        txInString="${txInString} --tx-in ${utxoHashIndex}"
        done
        echo -e "\e[0m-----------------------------------------------------------------------------------------------------"
        echo -e "Total ADA on the Address:\e[32m  $(convertToADA ${totalLovelaces}) ADA / ${totalLovelaces} lovelaces \e[0m\n"

	totalPolicyIDsCnt=$(jq length <<< ${totalPolicyIDsJSON});
        totalAssetsCnt=$(jq length <<< ${totalAssetsJSON})

if [[ ${totalAssetsCnt} -gt 0 ]]; then  echo -e "\e[32m${totalAssetsCnt} Asset-Type(s) / ${totalPolicyIDsCnt} different PolicyIDs\e[0m found on the Address!\n\n"; fi


#Showing the assets given to the script to send them out, compose the assetsSendString and also check the available amounts
printf "\e[33m%-80s %16s %-44s\e[0m\n" "Assets to send (given input reference, * means selected via bulk sending):" "Amount:" "Bech-Format:"

assetsSendString=""

#Filter out all bulk policyID entries that have found assets, they are marked with the key "bulkfound"="true"
bechAssetsToSendJSON=$(jq -r "with_entries(select(.value.bulkfound != \"true\"))" <<< ${bechAssetsToSendJSON})

bechAssetsToSendCnt=$(jq length <<< ${bechAssetsToSendJSON})
for (( tmpCnt=0; tmpCnt<${bechAssetsToSendCnt}; tmpCnt++ ))
	do
	assetBech=$(jq -r "keys_unsorted[${tmpCnt}]" <<< ${bechAssetsToSendJSON})
	assetAmount=$(jq -r ".\"${assetBech}\".amount" <<< ${bechAssetsToSendJSON})
	assetInput=$(jq -r ".\"${assetBech}\".input" <<< ${bechAssetsToSendJSON})

	#Get Entry (policyID.assetName) for that Asset from the totalAssetsJSON
	assetSearch=$(jq -r "with_entries(select(.value.bech==\"${assetBech}\"))" <<< ${totalAssetsJSON})
	assetHash=$(jq -r "keys[0]" <<< ${assetSearch})
	assetAvailableAmount=$(jq -r ".[].amount" <<< ${assetSearch})

	#If asset is not present in the totalAssetsJSON, than exit with an error
        if [[ "${assetHash}" == null ]]; then
		printf "\e[90m%-80s \e[35m%16s %-44s\e[0m\n" "${assetInput:0:80}" "${assetAmount}" "-";
		echo -e "\n\e[35mThis asset is not available on this address or on the selected UTXOs!\e[0m\n"; exit 1;
	fi

	#If given sending Amount is given as keyword ALL, replace the amount with the available one
	if [[ "${assetAmount}" == "ALL" ]]; then assetAmount=${assetAvailableAmount}; fi

	#If available assetAmount is not enough in the totalAssetsJSON, than exit with an error
        if [[ $(bc <<< "(${assetAvailableAmount}-${assetAmount}) < 0") -eq 1 ]]; then
		printf "\e[90m%-80s \e[35m%16s %-44s\e[0m\n" "${assetInput:0:80}" "${assetAmount}" "${assetBech}";
		echo -e "\n\e[35mThe assetAmount on this address or on the selected UTXOs is not enough. A maximum of ${assetAvailableAmount} is available!\e[0m\n"; exit 1;
	fi

        printf "\e[90m%-80s \e[33m%16s %-44s\e[0m\n" "${assetInput:0:80}" "${assetAmount}" "${assetBech}"

	#Compose the assetSendString, add the sending amount+hash
	assetsSendString+="+${assetAmount} ${assetHash}"

	#Update the totalAssetsJSON with the remaining amount of the asset
	amountToReturn=$(bc <<< "${assetAvailableAmount}-${assetAmount}");	#the rest amount of the asset that stays on the source address
	totalAssetsJSON=$( jq ".\"${assetHash}\".amount = \"${amountToReturn}\"" <<< ${totalAssetsJSON})
done

echo
echo

if [[ ${totalAssetsCnt} -gt 0 ]]; then
	printf "\e[91m%s\e[0m - PolicyID:          %11s    %16s %-44s  %7s  %s\n" "Assets remaining after transaction" "ASCII-Name:" "Amount:" "Bech-Format:" "Ticker:" "Meta-Name:"
	for (( tmpCnt=0; tmpCnt<${totalAssetsCnt}; tmpCnt++ ))
	do
		assetHashName=$(jq -r "keys[${tmpCnt}]" <<< ${totalAssetsJSON})
		assetAmount=$(jq -r ".\"${assetHashName}\".amount" <<< ${totalAssetsJSON})
		assetName=$(jq -r ".\"${assetHashName}\".name" <<< ${totalAssetsJSON})
		assetBech=$(jq -r ".\"${assetHashName}\".bech" <<< ${totalAssetsJSON})
		assetHashHex="${assetHashName:0:56}$(convert_assetNameASCII2HEX ${assetName})"

                if $queryTokenRegistry; then if $onlineMode; then metaResponse=$(curl -sL -m 20 "${tokenMetaServer}${assetHashHex}"); else metaResponse=$(jq -r ".tokenMetaServer.\"${assetHashHex}\"" <<< ${offlineJSON}); fi
			metaAssetName=$(jq -r ".name.value | select (.!=null)" 2> /dev/null <<< ${metaResponse}); if [[ ! "${metaAssetName}" == "" ]]; then metaAssetName="${metaAssetName} "; fi
			metaAssetTicker=$(jq -r ".ticker.value | select (.!=null)" 2> /dev/null <<< ${metaResponse})
		fi

		printf "\e[90m%-70s \e[32m%16s %44s  \e[90m%-7s  \e[36m%s\e[0m\n" "${assetHashName}" "${assetAmount}" "${assetBech}" "${metaAssetTicker}" "${metaAssetName}"

		#Compose the assetsReturnString, add only assets with a amount greater than zero
		if [[ $(bc <<< "${assetAmount}>0") -eq 1 ]]; then assetsReturnString+="+${assetAmount} ${assetHashName}"; fi #only include in the sendout if more than zero
        done
fi

echo
echo


#There are metadata file attached, list them:
if [[ ! "${metafileList}" == "" ]]; then echo -e "\e[0mInclude Metadata-File(s):\e[32m ${metafileList}\e[0m\n"; fi

#There are transactionMessages attached, show the metadatafile:
if [[ ! "${transactionMessage}" == "{}" ]]; then echo -e "\e[0mInclude Transaction-Message-Metadata-File:\e[32m ${transactionMessageMetadataFile}\n\e[90m"; cat ${transactionMessageMetadataFile}; echo -e "\e[0m"; fi


#
# Set the right rxcnt, in this case its always 2. One external destination address, one return address (sourceAddress)
#

rxcnt=2

#Read ProtocolParameters
if ${onlineMode}; then
                        protocolParametersJSON=$(${cardanocli} query protocol-parameters ${magicparam} ); #onlinemode
                  else
                        protocolParametersJSON=$(jq ".protocol.parameters" <<< ${offlineJSON}); #offlinemode
                  fi
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

minOutUTXO=$(calc_minOutUTXO "${protocolParametersJSON}" "${sendToAddr}+0${assetsSendString}")

minReturnUTXO=$(calc_minOutUTXO "${protocolParametersJSON}" "${sendToAddr}+0${assetsReturnString}")

#Generate Dummy-TxBody file for fee calculation
txBodyFile="${tempDir}/dummy.txbody"
rm ${txBodyFile} 2> /dev/null
${cardanocli} transaction build-raw ${nodeEraParam} ${txInString} --tx-out "${sendToAddr}+0${assetsSendString}" --tx-out "${sendToAddr}+0${assetsReturnString}" --invalid-hereafter ${ttl} --fee 0 ${metafileParameter} --out-file ${txBodyFile}
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
fee=$(${cardanocli} transaction calculate-min-fee --tx-body-file ${txBodyFile} --protocol-params-file <(echo ${protocolParametersJSON}) --tx-in-count ${txcnt} --tx-out-count ${rxcnt} ${magicparam} --witness-count 1 --byron-witness-count 0 | awk '{ print $1 }')
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

echo -e "\e[0mMinimum Transaction Fee for ${txcnt}x TxIn & ${rxcnt}x TxOut: \e[32m $(convertToADA ${fee}) ADA / ${fee} lovelaces \e[90m"

#
# Set the right amount of lovelacesToSend, lovelacesToReturn and also check about sendinglimits like minOutUTXO for returning assets if available
#

echo -e "\e[0mMinimum UTXO value for sending the asset: \e[32m ${minOutUTXO} lovelaces \e[90m"
echo
if [[ ${lovelacesToSend} -lt ${minOutUTXO} ]]; then lovelacesToSend=${minOutUTXO}; fi
echo -e "\e[0mLovelaces to send to ${toAddr}.addr: \e[33m $(convertToADA ${lovelacesToSend}) ADA / ${lovelacesToSend} lovelaces \e[90m"

lovelacesToReturn=$(( ${totalLovelaces} - ${fee} - ${lovelacesToSend} ))
echo -e "\e[0mLovelaces to return to ${fromAddr}.addr: \e[32m $(convertToADA ${lovelacesToReturn}) ADA / ${lovelacesToReturn} lovelaces \e[90m"
if [[ ${lovelacesToReturn} -lt ${minReturnUTXO} ]]; then echo -e "\n\e[35mError - Not enough funds on the source Addr! Minimum UTXO value to return is ${minReturnUTXO} lovelaces.\e[0m\n"; exit 1; fi

txBodyFile="${tempDir}/$(basename ${fromAddr}).txbody"
txFile="${tempDir}/$(basename ${fromAddr}).tx"

echo
echo -e "\e[0mBuilding the unsigned transaction body: \e[32m ${txBodyFile} \e[90m"
echo

#Building unsigned transaction body
rm ${txBodyFile} 2> /dev/null
${cardanocli} transaction build-raw ${nodeEraParam} ${txInString} --tx-out "${sendToAddr}+${lovelacesToSend}${assetsSendString}" --tx-out "${sendFromAddr}+${lovelacesToReturn}${assetsReturnString}" --invalid-hereafter ${ttl} --fee ${fee} ${metafileParameter} --out-file ${txBodyFile}
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

cat ${txBodyFile}
echo

echo -e "\e[0mSign the unsigned transaction body with the \e[32m${fromAddr}.skey\e[0m: \e[32m ${txFile} \e[0m"
echo

#Sign the unsigned transaction body with the SecureKey
rm ${txFile} 2> /dev/null

#If payment address is a hardware wallet, use the cardano-hw-cli for the signing
if [[ -f "${fromAddr}.hwsfile" ]]; then
        start_HwWallet; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

        #if rxcnt==2 that means that some funds are returned back to the hw-wallet and if its a staking address, we can hide the return
        #amount of lovelaces which could cause confusion. we have to add the --change-output-key-file parameters for payment and stake if
        #its a base address. this only works great for base addresses, otherwise a warning would pop up on the hw-wallet complaining about that
        #there are no rewards, tzz.
        hwWalletReturnStr=""
        if [[ ${rxcnt} == 2 ]]; then
                                        #but now we have to check if its a base address, in that case we also need to add the staking.hwsfile
                                        stakeFromAddr="$(basename ${fromAddr} .payment).staking"
                                        if [[ -f "${stakeFromAddr}.hwsfile" ]]; then hwWalletReturnStr="--change-output-key-file ${fromAddr}.hwsfile --change-output-key-file ${stakeFromAddr}.hwsfile"; fi
                                fi

        tmp=$(${cardanohwcli} transaction sign --tx-body-file ${txBodyFile} --hw-signing-file ${fromAddr}.hwsfile ${hwWalletReturnStr} ${magicparam} --out-file ${txFile} 2> /dev/stdout)
        if [[ "${tmp^^}" =~ (ERROR|DISCONNECT) ]]; then echo -e "\e[35m${tmp}\e[0m\n"; exit 1; else echo -e "\e[32mDONE\e[0m\n"; fi
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
else
        ${cardanocli} transaction sign --tx-body-file ${txBodyFile} --signing-key-file ${fromAddr}.skey ${magicparam} --out-file ${txFile}
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
fi

echo -ne "\e[90m"
cat ${txFile}
echo

if ask "\e[33mDoes this look good for you, continue ?" N; then
	echo
        if ${onlineMode}; then  #onlinesubmit
                                echo -ne "\e[0mSubmitting the transaction via the node... "
                                ${cardanocli} transaction submit --tx-file ${txFile} ${magicparam}
                                checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
                                echo -e "\e[32mDONE\n"

                                #Show the TxID
                                txID=$(${cardanocli} transaction txid --tx-file ${txFile}); echo -e "\e[0m TxID is: \e[32m${txID}\e[0m"
                                checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi;
                                if [[ ${magicparam^^} =~ (MAINNET|1097911063) ]]; then echo -e "\e[0mTracking: \e[32m${transactionExplorer}${txID}\n\e[0m"; fi


                          else  #offlinestore
                                txFileJSON=$(cat ${txFile} | jq .)
                                offlineJSON=$( jq ".transactions += [ { date: \"$(date -R)\",
                                                                        type: \"Transaction\",
                                                                        era: \"$(jq -r .protocol.era <<< ${offlineJSON})\",
                                                                        fromAddr: \"${fromAddr}\",
                                                                        sendFromAddr: \"${sendFromAddr}\",
                                                                        toAddr: \"${toAddr}\",
                                                                        sendToAddr: \"${sendToAddr}\",
                                                                        txJSON: ${txFileJSON} } ]" <<< ${offlineJSON})
                                #Write the new offileFile content
                                offlineJSON=$( jq ".history += [ { date: \"$(date -R)\", action: \"generated and signed utxo-token-transaction from '${fromAddr}' to '${toAddr}'\" } ]" <<< ${offlineJSON})
                                offlineJSON=$( jq ".general += {offlineCLI: \"${versionCLI}\" }" <<< ${offlineJSON})
                                offlineJSON=$( jq ".general += {offlineNODE: \"${versionNODE}\" }" <<< ${offlineJSON})
                                echo "${offlineJSON}" > ${offlineFile}
                                #Readback the tx content and compare it to the current one
                                readback=$(cat ${offlineFile} | jq -r ".transactions[-1].txJSON")
                                if [[ "${txFileJSON}" == "${readback}" ]]; then
                                                        showOfflineFileInfo;
                                                        echo -e "\e[33mTransaction txJSON has been stored in the '$(basename ${offlineFile})'.\nYou can now transfer it to your online machine for execution.\e[0m\n";
                                                 else
                                                        echo -e "\e[35mERROR - Could not verify the written data in the '$(basename ${offlineFile})'. Retry again or generate a new '$(basename ${offlineFile})'.\e[0m\n";
                                fi

        fi
fi


echo -e "\e[0m\n"



