#!/bin/bash

# Script is brought to you by ATADA_Stakepool, Telegram @atada_stakepool

#load variables from common.sh
. "$(dirname "$0")"/00_common.sh


#ShowUsage
showUsage() {
cat >&2 <<EOF
Usage:  $(basename $0) <From AddressName> <To AddressName or HASH or '\$adahandle'> <PolicyID.Name OR asset1-name OR PATH to the AssetFile(.asset)> <Amount of Assets to send OR keyword ALL>
        [Opt: Amount of lovelaces to include]
        [Opt: Transaction-Metadata.json/.cbor]
        [Opt: list of UTXOs to use, | is the separator]
        [Opt: Message comment, starting with "msg: ...", | is the separator]
        [Opt: no of input UTXOs limitation, starting with "utxolimit: ..."]
        [Opt: skip input UTXOs that contain assets (hex-format), starting with "skiputxowithasset: <policyID>(assetName)", | is the separator]
        [Opt: only use input UTXOs that contain assets (hex-format), starting with "onlyutxowithasset: <policyID>(assetName)", | is the separator]
        [Opt: keep a certain PolicyID while doing a 'ALLASSETS' transaction, starting with "keeppolicy: <policyID>", | is the separator]

Optional parameters:

- If you wanna send multiple Assets at the same time, you can use the | as the separator, must be in "..." for the parameter 3:
   "myassets/mypolicy.mytoken 10" ... to send 10 tokens specified in the asset-file
   "myassets/mypolicy.mytoken 10|asset1hgxml0wxcw903pdsgzr8gyvwg8ch40v0fvnmjl 20" ... to send 10 mytoken and 20 tokens with bech asset1...
   "asset1hgxml0wxcw903pdsgzr8gyvwg8ch40v0fvnmjl all|asset1ra679n0pql7hc57qjlah3cjhaygywgccsufmpn all" ... to send all tokens of the given asset-names

- You can also send all Assets with a specified policyID, or a policyID.ASCIIname* with the * at the end for parameter 3:
  "b43131f2c82825ee3d81705de0896c611f35ed38e48e33a3bdf298dc.* all" ... to send out all your CryptoMage NFTs
  "34250edd1e9836f5378702fbf9416b709bc140e04f668cc355208518.Coin* all" .. to send out all your Assets for that policyID starting with the name "Coin"

- You can also send Assets in Hex-ByteArray format without the . decimator in the name, bulk sending also works via the * char at the end:
  "affeaffec82825ee3d81705de0896c611f35ed38e48e33a3bdf298dc1122334455667788 15" ... to send out 15 your that ByteArray named Asset
  "34250edd1e9836f5378702fbf9416b709bc140e04f668cc35520851800123456* all" .. to send out all your Assets for that policyID and Hex-ByteArray

- If you wanna send ALL Assets to another address you can use the special keyword "ALLASSETS" for the Asset. The remaining ADA will stay on the SourceAddr:
  $(basename $0) <FromAddress> <ToAddress> ALLASSETS ... will send ALL Assets out
  $(basename $0) <FromAddress> <ToAddress> ALLASSETS "keeppolicy: yyy" ... will send ALL Assets out, but keeps the ones with policyID yyy

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

- In rare cases you wanna define the maximum count of input UTXOs that will be used for building the Transaction:
   "utxolimit: xxx" ... to specify xxx number of input UTXOs to be used as maximum
   "utxolimit: 300" ... to specify a maximum of 300 input UTXOs that will be used for the transaction

- In rare cases you wanna skip input UTXOs that contains one or more defined Assets policyIDs(+assetName) in hex-format:
   "skiputxowithasset: yyy" ... to skip all input UTXOs that contains assets with the policyID yyy
   "skiputxowithasset: yyy|zzz" ... to skip all input UTXOs that contains assets with the policyID yyy or zzz

- In rare cases you wanna use input UTXOs that contains one or more defined Assets policyIDs(+assetName) in hex-format:
   "onlyutxowithasset: yyy" ... to skip all input UTXOs that contains assets with the policyID yyy
   "onlyutxowithasset: yyy|zzz" ... to skip all input UTXOs that contains assets with the policyID yyy or zzz

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
	if [ ! -f "${toAddr}.addr" ]; then
                                toAddr=$(trimString "${toAddr}") #trim it if spaces present

                                #check if its a regular cardano payment address
                                typeOfAddr=$(get_addressType "${toAddr}");
                                if [[ ${typeOfAddr} == ${addrTypePayment} ]]; then echo "$(basename ${toAddr})" > ${tempDir}/tempTo.addr; toAddr="${tempDir}/tempTo";

                                #check if its an adahandle
                                elif [[ "${toAddr,,}" =~ ^\$[a-z0-9_.-]{1,15}$ ]]; then
                                        if ${offlineMode}; then echo -e "\n\e[35mERROR - Adahandles are only supported in Online mode.\n\e[0m"; exit 1; fi
                                        adahandleName=${toAddr,,}
                                        assetNameHex=$(convert_assetNameASCII2HEX ${adahandleName:1})
                                        #query adahandle asset holding address via koios
                                        showProcessAnimation "Query Adahandle into holding address: " &
                                        response=$(curl -s -m 10 -X GET "${koiosAPI}/asset_address_list?_asset_policy=${adahandlePolicyID}&_asset_name=${assetNameHex}" -H "Accept: application/json" 2> /dev/null)
                                        stopProcessAnimation;
                                        #check if the received json only contains one entry in the array (will also not be 1 if not a valid json)
                                        if [[ $(jq ". | length" 2> /dev/null <<< ${response}) -ne 1 ]]; then echo -e "\n\e[35mCould not resolve Adahandle to an address.\n\e[0m"; exit 1; fi
                                        toAddr=$(jq -r ".[0].payment_address" <<< ${response} 2> /dev/null)
                                        typeOfAddr=$(get_addressType "${toAddr}");
                                        if [[ ${typeOfAddr} != ${addrTypePayment} ]]; then echo -e "\n\e[35mERROR - Resolved address '${toAddr}' is not a valid payment address.\n\e[0m"; exit 1; fi;
                                        showProcessAnimation "Verify Adahandle is on resolved address: " &
                                        utxo=$(${cardanocli} query utxo --address ${toAddr} ${magicparam} ); stopProcessAnimation; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi;
                                        if [[ $(grep "${adahandlePolicyID}.${assetNameHex} " <<< ${utxo} | wc -l) -ne 1 ]]; then
                                                 echo -e "\n\e[35mERROR - Resolved address '${toAddr}' does not hold the \$adahandle '${adahandleName}' !\n\e[0m"; exit 1; fi;
                                        echo -e "\e[0mFound \$adahandle '${adahandleName}' on Address:\e[32m ${toAddr}\e[0m"
                                        echo "$(basename ${toAddr})" > ${tempDir}/adahandle-resolve.addr; toAddr="${tempDir}/adahandle-resolve";

                                #otherwise post an error message
                                else echo -e "\n\e[35mERROR - Destination Address can't be resolved. Maybe filename wrong, or not a payment-address.\n\e[0m"; exit 1;

                                fi
	fi

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
			if [[ "${assetToSend^^}" == "ALLASSETS" || "${assetToSend^^}" == "FORCEADA" ]]; then  #autoset amount to ALL if the special keyword ALLASSETS is found
				amountToSend="ALL"; tmpEntry[1]="ALL";
				else
			        amountToSend=${tmpEntry[1]^^} #use the uppercase value (easier to check for keyword ALL)
			fi

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

			#Preload the assetFile search variable for a check below
 			assetFile="$(dirname ${assetToSend})/$(basename "${assetToSend}" .asset).asset"

			#Check if the assetToSend is a bech32 assetname (starts with "asset" and bech32 tool confirms a valid bech name)
			if [[ "${assetToSend}" =~ ^asset(.*)$ ]] && [[ "${#assetToSend}" -eq 44 ]]; then
		        	tmp=$(${bech32_bin} 2> /dev/null <<< "${assetToSend}") #will have returncode 0 if the bech was valid
				if [ $? -ne 0 ]; then echo -e "\n\e[35mERROR - \"${assetToSend}\" is not a valid bech32 asset.\n\e[0m"; showUsage; exit 1; fi
				assetBechToSend=${assetToSend}; #just copy it, already a valid bech32 asset

			#All HEX Format Input
                        #Check if the assetToSend is a policyIDassetName HEX-String, if so, convert it to bech32.
			#Counting directly on HEX-Pairs, thats 56bytes for the policyID -> 28pairs and, zero (policyID only) up to 32 bytes for the
			#assetName part so range is from 28+(0to32) pair -> 28 to 60 pairs
                        elif [[ "${assetToSend}" =~ ^([[:xdigit:]][[:xdigit:]]){28,60}$ ]]; then assetBechToSend=$(convert_tokenName2BECH "${assetToSend}" "");

			#Check if the assetToSend is a policyID.assetName ASCII-string, if so, convert it bech32
			elif [[ "${assetToSend}" =~ ^[[:xdigit:]]{56}\.[[:alnum:]]{1,32}$ ]]; then assetBechToSend=$(convert_tokenName2BECH $(echo ${assetToSend} | cut -d. -f 1) $(echo ${assetToSend} | cut -d. -f 2) )

			#BULK-HEX Send
			#Check if the assetToSend is a policyIDassetName HEX-String* , if so, store it as a bulk entry
			elif [[ "${assetToSend}" =~ ^([[:xdigit:]][[:xdigit:]]){28,59}\*$ ]]; then echo "hex-bulk"; #only up to 59 hex pairs, 60 pairs would be a single asset, no need to check for bulk
				if [[ "${amountToSend}" == "ALL" ]]; then assetBechToSend="${assetToSend:0:56}.${assetToSend:56:-1}-BULK"; echo ${assetBechToSend} #cut of the last char * and store it in the sending list
								     else echo -e "\n\e[35mError with Bulk-Selection of asset: \e[0m${assetToSend}\n\n\e[35mPlease set the sending amount to \e[0mALL \e[35m!\e[0m\n"; exit 1; fi

			#BULK-ASCII Send
			#Check if the assetToSend is a policyID.* string, if so, store it as a bulk entry
			elif [[ "${assetToSend}" =~ ^[[:xdigit:]]{56}\.([[:alnum:]]{0,31})\*$ ]]; then #only up to 31 chars, 32 chars is a single asset, no need to check for bulk
				tmpAssetPolicy=$(echo ${assetToSend} | cut -d. -f 1) #given policyID in hex
				tmpAssetName=$(echo ${assetToSend:0:-1} | cut -d. -f 2) #given policyID in ascii
				tmpAssetNameHEX=$(convert_assetNameASCII2HEX "${tmpAssetName}")
				if [[ "${amountToSend}" == "ALL" ]]; then assetBechToSend="${tmpAssetPolicy}.${tmpAssetNameHEX}-BULK"; #cut of the last char * and store it in the sending list
								     else echo -e "\n\e[35mError with Bulk-Selection of asset: \e[0m${assetToSend}\n\n\e[35mPlease set the sending amount to \e[0mALL \e[35m!\e[0m\n"; exit 1; fi

			#BULK-ALL
			elif [[ "${assetToSend^^}" == "ALLASSETS" || "${assetToSend^^}" == "FORCEADA" ]]; then assetBechToSend="***SEND-ALL-BULK***"

			#Check if the assetToSend is a file xxx.asset then read out the data from the file instead
			elif [ -f "${assetFile}" ]; then
				tmpAssetPolicy="$(jq -r .policyID < ${assetFile})"
				tmpAssetName="$(jq -r .name < ${assetFile})"
				tmpAssetHexName="$(jq -r .hexname < ${assetFile})"
				if [[ "${tmpAssetHexName,,}" =~ ^([[:xdigit:]][[:xdigit:]]){1,32}$ ]]; then #hex-pair name
													assetBechToSend=$(convert_tokenName2BECH "${tmpAssetPolicy}${tmpAssetHexName,,}" "")
				elif [[ "${tmpAssetName}" == "${tmpAssetName//[^[:alnum:]]/}" ]]; then #readale ascii name
													assetBechToSend=$(convert_tokenName2BECH "${tmpAssetPolicy}" "${tmpAssetName}")
				else echo -e "\n\e[35mError - I don't understand the format of the name in the given assetFile '${assetFile}' ! \e[0m\n"; exit 1; fi

			#Otherwise print an error message, that the given assetToSend could not be resolved
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
	if [[ ! "${paramValue,,}" =~ ^msg:(.*)$ ]] && [[ ! "${paramValue,,}" =~ ^utxolimit:(.*)$ ]] && [[ ! "${paramValue,,}" =~ ^skiputxowithasset:(.*)$ ]] && [[ ! "${paramValue,,}" =~ ^onlyutxowithasset:(.*)$ ]] && [[ ! "${paramValue,,}" =~ ^keeppolicy:(.*)$ ]] && [[ ! "${paramValue}" =~ ^([[:xdigit:]]+#[[:digit:]]+(\|?)){1,}$ ]] && [[ ! ${paramValue} == "" ]] && [ ! -z "${paramValue##*[!0-9]*}" ]; then lovelacesToSend=${paramValue};

        #Check if an additional metadata.json/.cbor was set as parameter (not a message, not an UTXO#IDX, not empty, not beeing a number)
        elif [[ ! "${paramValue,,}" =~ ^msg:(.*)$ ]] && [[ ! "${paramValue,,}" =~ ^utxolimit:(.*)$ ]] && [[ ! "${paramValue,,}" =~ ^skiputxowithasset:(.*)$ ]] && [[ ! "${paramValue,,}" =~ ^onlyutxowithasset:(.*)$ ]] && [[ ! "${paramValue,,}" =~ ^keeppolicy:(.*)$ ]] && [[ ! "${paramValue}" =~ ^([[:xdigit:]]+#[[:digit:]]+(\|?)){1,}$ ]] && [[ ! ${paramValue} == "" ]] && [ -z "${paramValue##*[!0-9]*}" ]; then

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

        #Check if its an utxo amount limitation
        elif [[ "${paramValue,,}" =~ ^utxolimit:(.*)$ ]]; then #if the parameter starts with "utxolimit:" then set the utxolimit
                utxoLimitCnt=$(trimString "${paramValue:10}");
                if [[ ${utxoLimitCnt} -le 0 ]]; then
                        echo -e "\n\e[35mUTXO-Limit-ERROR: Please use a number value greater than zero!\n\e[0m"; exit 1;
                fi

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

        #Check if its an keepPolicy set
        elif [[ "${paramValue,,}" =~ ^keeppolicy:(.*)$ ]]; then #if the parameter starts with "keeppolicy:" then set the utxolimit
                keepAssetPolicy=$(trimString "${paramValue:11}"); keepAssetPolicy=${keepAssetPolicy,,}; #read the value and convert it to lowercase
                if [[ ! "${keepAssetPolicy}" =~ ^(([[:xdigit:]][[:xdigit:]]){28}+(\|?)){1,}$ ]]; then
                        echo -e "\n\e[35mKeepAsset-Policy-ERROR: The given policy '${keepAssetPolicy}' is not a valid policy hex string!\n\e[0m"; exit 1;
                fi

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
                                showProcessAnimation "Query-UTXO: " &
                                utxo=$(${cardanocli} query utxo --address ${sendFromAddr} ${magicparam} ); stopProcessAnimation; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi;
                                if [[ ${skipUtxoWithAsset} != "" ]]; then utxo=$(echo "${utxo}" | egrep -v "${skipUtxoWithAsset}" ); fi #if its set to keep utxos that contains certain policies, filter them out
                                if [[ ${onlyUtxoWithAsset} != "" ]]; then utxo=$(echo "${utxo}" | egrep "${onlyUtxoWithAsset}" ); utxo=$(echo -e "Header\n-----\n${utxo}"); fi #only use given utxos. rebuild the two header lines
                                if [[ ${utxoLimitCnt} -gt 0 ]]; then utxo=$(echo "${utxo}" | head -n $(( ${utxoLimitCnt} + 2 )) ); fi #if there was a utxo cnt limit set, reduce it (+2 for the header)
                                showProcessAnimation "Convert-UTXO: " &
                                utxoJSON=$(generate_UTXO "${utxo}" "${sendFromAddr}"); stopProcessAnimation;
                          else
				readOfflineFile;	#Reads the offlinefile into the offlineJSON variable
                                utxoJSON=$(jq -r ".address.\"${sendFromAddr}\".utxoJSON" <<< ${offlineJSON})
                                if [[ "${utxoJSON}" == null ]]; then echo -e "\e[35mPayment-Address not included in the offline transferFile, please include it first online!\e[0m\n"; exit 1; fi
        fi

        #Only use UTXOs specied in the extra parameter if present
        if [[ ! "${filterForUTXO}" == "" ]]; then echo -e "\e[0mUTXO-Mode: \e[32mOnly using the UTXO with Hash ${filterForUTXO}\e[0m\n"; utxoJSON=$(filterFor_UTXO "${utxoJSON}" "${filterForUTXO}"); fi

	txcnt=$(jq length <<< ${utxoJSON}) #Get number of UTXO entries (Hash#Idx), this is also the number of --tx-in for the transaction
	if [[ ${txcnt} == 0 ]]; then echo -e "\e[35mNo funds on the Source Address!\e[0m\n"; exit 1; else echo -e "\e[32m${txcnt} UTXOs\e[0m found on the Source Address!\n"; fi

        totalLovelaces=0
        totalAssetsJSON="{}"; 	#Building a total JSON with the different assetstypes "policyIdHash.name", amount and name
        totalPolicyIDsLIST=""; #Buffer for the policyIDs, will be sorted/uniq/linecount at the end of the query
	assetsReturnString="";	#This will hold the String to append on the --tx-out if assets present or it will be empty

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

                                case ${assetHash} in
                                        f0ff48bbb7bbe9d59a40f1ce90e9e9d0ff5002ec48f232b49ca0fb9a )      #$adahandle
                                                echo -e "\e[90m                           Asset: ${assetBech}  ADA Handle: \$$(convert_assetNameHEX2ASCII ${assetName}) ${assetTmpName}\e[0m"
                                                ;;
                                        * ) #default
                                                echo -e "\e[90m                           Asset: ${assetBech}  Amount: ${assetAmount} ${assetTmpName}\e[0m"
                                                ;;
                                esac

				#special process to add all assets to the sending list
				if [[ "${bechAssetsToSendJSON}" == *"***SEND-ALL-BULK***"* && "${keepAssetPolicy}" != *"${assetHash}"* ]]; then
					assetTmpName=$(convert_assetNameHEX2ASCII_ifpossible "${assetName}") #if it starts with a . -> ASCII showable name, otherwise the HEX-String
                                        bechAssetsToSendJSON=$( jq ". += {\"${assetBech}\":{amount: \"ALL\", input: \"* ${assetHash}${assetTmpName}\"}}" <<< ${bechAssetsToSendJSON}) #add the current asset to the sending list
                                        bechAssetsToSendJSON=$( jq ".\"***SEND-ALL-BULK***\".bulkfound = \"true\"" <<< ${bechAssetsToSendJSON}) #mark the bulksending entry itself as used by adding the key bulk=true to it for later filter$

				#special process to lookup if there is a bulk sending entry in the ${bechAssetsToSendJSON}, if so, add the current asset with amount ALL to that list
				#this bulk sending is only processed for assets with an assetname like NFTs, not for nameless assets. they have to be sent separate
				elif [[ ! "${assetName}" == "" ]] && [[ "${bechAssetsToSendJSON}" =~ ${assetHash}\.(.*)-BULK ]]; then
					tmpFullKeyFound=${BASH_REMATCH[0]}; tmpCompareFound=${BASH_REMATCH[0]:0:-5};
					if [[ ! $(grep "${tmpCompareFound}" <<< "${assetHash}.${assetName}") == "" ]]; then
					assetTmpName=$(convert_assetNameHEX2ASCII_ifpossible "${assetName}") #if it starts with a . -> ASCII showable name, otherwise the HEX-String
					bechAssetsToSendJSON=$( jq ". += {\"${assetBech}\":{amount: \"ALL\", input: \"* ${assetHash}${assetTmpName}\"}}" <<< ${bechAssetsToSendJSON}) #add the current asset to the sending list
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

        totalPolicyIDsCnt=$(echo -ne "${totalPolicyIDsLIST}" | sort | uniq | wc -l)
        totalAssetsCnt=$(jq length <<< ${totalAssetsJSON});
        if [[ ${totalAssetsCnt} -gt 0 ]]; then
	        echo -e "\e[32m${totalAssetsCnt} Asset-Type(s) / ${totalPolicyIDsCnt} different PolicyIDs\e[0m found on the Address!\n"
	fi



#Showing the assets given to the script to send them out, compose the assetsSendString and also check the available amounts
printf "\e[33m%-80s %16s %-44s\e[0m\n" "Assets to send (given input reference, * means selected via bulk sending):" "Amount:" "Bech-Format:"

assetsSendString=""

#Filter out all bulk policyID entries that have found assets, they are marked with the key "bulkfound"="true"
bechAssetsToSendJSON=$(jq -r "with_entries(select(.value.bulkfound != \"true\"))" <<< ${bechAssetsToSendJSON})

#Filter out the Bulksend entry itself to force also lovelace only transaction when the keyword was "FORCEADA", not used very often, but a special tag
if [[ "${assetToSend^^}" == "FORCEADA" ]]; then bechAssetsToSendJSON=$(jq -r "del (.\"***SEND-ALL-BULK***\")" <<< ${bechAssetsToSendJSON}); fi

assetBechArray=; readarray -t assetBechArray < <(jq -r "keys_unsorted[]" <<< ${bechAssetsToSendJSON})
bechAssetsToSendCnt=${#assetBechArray[@]} #note the < <(xxx) above, it must be in this way, otherwise the length would always be at least 1!
assetAmountArray=(); readarray -t assetAmountArray <<< $(jq -r "flatten | .[].amount" <<< ${bechAssetsToSendJSON})
assetInputArray=(); readarray -t assetInputArray <<< $(jq -r "flatten | .[].input" <<< ${bechAssetsToSendJSON})

for (( tmpCnt=0; tmpCnt<${bechAssetsToSendCnt}; tmpCnt++ ))
	do
	assetBech=${assetBechArray[${tmpCnt}]}
	assetAmount=${assetAmountArray[${tmpCnt}]}
	assetInput=${assetInputArray[${tmpCnt}]}

	#Get Entry (policyID.assetName) for that Asset from the totalAssetsJSON
	assetSearch=$(jq -r "with_entries(select(.value.bech==\"${assetBech}\"))" <<< ${totalAssetsJSON})
	assetHash=$(jq -r "keys[0]" <<< ${assetSearch})
	assetAvailableAmount=$(jq -r ".[].amount" <<< ${assetSearch})

	#If asset is not present in the totalAssetsJSON, than exit with an error
        if [[ "${assetHash}" == null ]]; then
		printf "\e[90m%-80s \e[35m%16s %-44s\e[0m\n" "${assetInput:0:80}" "${assetAmount}" "-";
		echo -e "\n\e[35mNo Assets available on this address or on the selected UTXOs!\e[0m\n"; exit 1;
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
			printf "\e[91m%s\e[0m - PolicyID:          %11s              %16s %-44s  %7s  %s\n" "Assets remaining after transaction" "Asset-Name:" "Amount:" "Bech-Format:" "Ticker:" "Meta-Name:"

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

	                        if $queryTokenRegistry; then if $onlineMode; then metaResponse=$(curl -sL -m 20 "${tokenMetaServer}${assetHashHex}"); else metaResponse=$(jq -r ".tokenMetaServer.\"${assetHashHex}\"" <<< ${offlineJSON}); fi
	                                metaAssetName=$(jq -r ".name.value | select (.!=null)" 2> /dev/null <<< ${metaResponse}); if [[ ! "${metaAssetName}" == "" ]]; then metaAssetName="${metaAssetName} "; fi
	                                metaAssetTicker=$(jq -r ".ticker.value | select (.!=null)" 2> /dev/null <<< ${metaResponse})
	                        fi

	                        if [[ "${assetName}" == "." ]]; then assetName=""; fi

	                        printf "\e[90m%-80s \e[32m%16s %44s  \e[90m%-7s  \e[36m%s\e[0m\n" "${assetHashName:0:56}${assetName}" "${assetAmount}" "${assetBech}" "${metaAssetTicker}" "${metaAssetName}"

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

#minOutUTXO=$(calc_minOutUTXO "${protocolParametersJSON}" "${sendToAddr}+0${assetsSendString}")
minOutUTXO=$(calc_minOutUTXO "${protocolParametersJSON}" "${sendToAddr}+1000000${assetsSendString}")
minReturnUTXO=$(calc_minOutUTXO "${protocolParametersJSON}" "${sendToAddr}+1000000${assetsReturnString}")

#Generate Dummy-TxBody file for fee calculation
txBodyFile="${tempDir}/dummy.txbody"
rm ${txBodyFile} 2> /dev/null
${cardanocli} transaction build-raw --cddl-format ${nodeEraParam} ${txInString} --tx-out "${sendToAddr}+1000000${assetsSendString}" --tx-out "${sendToAddr}+1000000${assetsReturnString}" --invalid-hereafter ${ttl} --fee 0 ${metafileParameter} --out-file ${txBodyFile}
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
txWitnessFile="${tempDir}/$(basename ${fromAddr}).txwitness"
txFile="${tempDir}/$(basename ${fromAddr}).tx"

echo
echo -e "\e[0mBuilding the unsigned transaction body: \e[32m ${txBodyFile} \e[90m"
echo

#Building unsigned transaction body
rm ${txBodyFile} 2> /dev/null
${cardanocli} transaction build-raw --cddl-format ${nodeEraParam} ${txInString} --tx-out "${sendToAddr}+${lovelacesToSend}${assetsSendString}" --tx-out "${sendFromAddr}+${lovelacesToReturn}${assetsReturnString}" --invalid-hereafter ${ttl} --fee ${fee} ${metafileParameter} --out-file ${txBodyFile}
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

dispFile=$(cat ${txBodyFile}); if ${cropTxOutput} && [[ ${#dispFile} -gt 4000 ]]; then echo "${dispFile:0:4000} ... (cropped)"; else echo "${dispFile}"; fi
echo

#Sign the unsigned transaction body with the SecureKey
rm ${txFile} 2> /dev/null

#If payment address is a hardware wallet, use the cardano-hw-cli for the signing
if [[ -f "${fromAddr}.hwsfile" ]]; then

        echo -ne "\e[0mAutocorrect the TxBody for canonical order: "
        tmp=$(autocorrect_TxBodyFile "${txBodyFile}"); if [ $? -ne 0 ]; then echo -e "\e[35m${tmp}\e[0m\n\n"; exit 1; fi
        echo -e "\e[32m${tmp}\e[90m\n"

	dispFile=$(cat ${txBodyFile}); if ${cropTxOutput} && [[ ${#dispFile} -gt 4000 ]]; then echo "${dispFile:0:4000} ... (cropped)"; else echo "${dispFile}"; fi
	echo

        echo -e "\e[0mSign (Witness+Assemble) the unsigned transaction body with the \e[32m${fromAddr}.hwsfile\e[0m: \e[32m ${txFile}\e[0m"
        echo

	#Witness and Assemble the TxFile
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

        tmp=$(${cardanohwcli} transaction witness --tx-file ${txBodyFile} --hw-signing-file ${fromAddr}.hwsfile ${hwWalletReturnStr} ${magicparam} --out-file ${txWitnessFile} 2> /dev/stdout)
        if [[ "${tmp^^}" =~ (ERROR|DISCONNECT) ]]; then echo -e "\e[35m${tmp}\e[0m\n"; exit 1; else echo -ne "\e[0mWitnessed ... "; fi
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

        ${cardanocli} transaction assemble --tx-body-file ${txBodyFile} --witness-file ${txWitnessFile} --out-file ${txFile}
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
        echo -e "Assembled ... \e[32mDONE\e[0m\n";

else

        echo -e "\e[0mSign the unsigned transaction body with the \e[32m${fromAddr}.skey\e[0m: \e[32m ${txFile}\e[0m"
        echo
        ${cardanocli} transaction sign --tx-body-file ${txBodyFile} --signing-key-file ${fromAddr}.skey ${magicparam} --out-file ${txFile}
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

fi

echo -ne "\e[90m"
dispFile=$(cat ${txFile}); if ${cropTxOutput} && [[ ${#dispFile} -gt 4000 ]]; then echo "${dispFile:0:4000} ... (cropped)"; else echo "${dispFile}"; fi
echo

#Do a txSize Check to not exceed the max. txSize value
cborHex=$(jq -r .cborHex < ${txFile})
txSize=$(( ${#cborHex} / 2 ))
maxTxSize=$(jq -r .maxTxSize <<< ${protocolParametersJSON})
if [[ ${txSize} -le ${maxTxSize} ]]; then echo -e "\e[0mTransaction-Size: ${txSize} bytes (max. ${maxTxSize})\n"
                                     else echo -e "\n\e[35mError - ${txSize} bytes Transaction-Size is too big! The maximum is currently ${maxTxSize} bytes.\e[0m\n"; exit 1; fi



#If you wanna skip the Prompt, set the environment variable ENV_SKIP_PROMPT to "YES" - be careful!!!
#if ask "\e[33mDoes this look good for you, continue ?" N; then
if [ "${ENV_SKIP_PROMPT}" == "YES" ] || ask "\n\e[33mDoes this look good for you, continue ?" N; then

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



