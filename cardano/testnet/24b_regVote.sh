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
if [ $# -lt 3 ]; then
cat >&2 <<EOF

Usage:  $(basename $0) <DRep-Name | Committee-Hot-Name | Pool-Name>  <Base/PaymentAddressName (paying for the registration fees)>  <1 or more *.vote files>

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

   $(basename $0) myDRep myWallet.payment myDrep_240317134558.drep.vote
   -> Register the given Vote (*.vote) on chain, Signing it with the myDRep secret key, Payment via the myWallet.payment wallet

   $(basename $0) myDRep myfunds mydrep_240317134558.drep.vote mydrep_240317135300.drep.vote "msg: My votings as a DRep, woohoo!"
   -> Register two Votes (*.vote) on chain, Signing it with the myDRep secret key, Payment via the myfunds wallet, Adding a Transaction-Message

EOF
exit 1;
fi

#At least 3 parameters were provided, use them


#Parameter Count is 3 or more
voterName="${1}"; voterName=${voterName%\.};
voterName="$(dirname ${voterName})/$(basename $(basename $(basename $(basename $(basename ${voterName} .drep) .cc-hot) .node) .skey) .hwsfile)"; voterName=${voterName/#.\//};
voterFile="$(dirname ${1})/$(basename ${1} .vkey)"; voterFile=${voterFile/#.\//}; voterFile=${voterFile%\.};

#Payment wallet
fromAddr="$(dirname $2)/$(basename $2 .addr)"; fromAddr=${fromAddr/#.\//};

#Check SKEY
if [ -f "${voterFile}.skey" ]; then #voterName was specified like xxx.drep, xxx.cc-hot or xxx.pool already

        voterSigningFile="${voterFile}.skey"
        case "${voterSigningFile}" in #check filename endings
                *".drep.skey")		voterType="DRep";;
                *".cc-hot.skey")	voterType="Committee-Hot";;
                *".node.skey")		voterType="Pool";;
                *)			echo -e "\n\e[35mERROR - Please specify a DRep/CC-Hot/Pool name like mydrep.drep, mycom.cc-hot or mypool.node \e[0m\n"; exit 1;;
        esac

#Check HWSFILE
elif [ -f "${voterFile}.hwsfile" ]; then #voterName was specified like xxx.drep, xxx.cc-hot or xxx.pool already

        voterSigningFile="${voterFile}.hwsfile"
        case "${voterSigningFile}" in #check filename endings
                *".drep.hwsfile")	voterType="Hardware DRep";;
                *".cc-hot.hwsfile")	voterType="Hardware Committee-Hot";;
                *".node.hwsfile")	voterType="Hardware Pool";;
                *)			echo -e "\n\e[35mERROR - Please specify a DRep/CC-Hot/Pool name like mydrep.drep, mycom.cc-hot or mypool.node \e[0m\n"; exit 1;;
        esac

#Check DREP SKEY
elif [ -f "${voterName}.drep.skey" ]; then #parameter is a DRep signing key file

        voterSigningFile="${voterName}.drep.skey"
        voterType="DRep"

#Check DREP HWSFILE
elif [ -f "${voterName}.drep.hwsfile" ]; then #parameter is a Hardware DRep signing key file

        voterSigningFile="${voterName}.drep.hwsfile"
        voterType="Hardware DRep"

#Check COMMITTEE_HOT SKEY
elif [ -f "${voterName}.cc-hot.skey" ]; then #parameter is a Committee-Hot signing key file

        voterSigningFile="${voterName}.cc-hot.skey"
        voterType="Committee-Hot"

#Check COMMITTEE_HOT HWSFILE
elif [ -f "${voterName}.cc-hot.hwsfile" ]; then #parameter is a Hardware Committee-Hot signing key file

        voterSigningFile="${voterName}.cc-hot.hwsfile"
        voterType="Hardware Committee-Hot"

#Check POOL SKEY
elif [ -f "${voterName}.node.skey" ]; then #parameter is a Pool signing key file

        voterSigningFile="${voterName}.node.skey"
        voterType="Pool"

#Check POOL HWSFILE
elif [ -f "${voterName}.node.hwsfile" ]; then #parameter is a Hardware Pool signing key file

        voterSigningFile="${voterName}.node.hwsfile"
        voterType="Hardware Pool"

else

        echo -e "\n\e[35mERROR - \"${voterName}.drep/cc-hot/node.skey/hwsfile\" does not exist.\e[0m\n";
        exit 1

fi

#For payment
if [ ! -f "${fromAddr}.addr" ]; then echo -e "\n\e[35mERROR - \"${fromAddr}.addr\" does not exist! Please create it first with script 03a or 02.\e[0m"; exit 1; fi
if ! [[ -f "${fromAddr}.skey" || -f "${fromAddr}.hwsfile" ]]; then echo -e "\n\e[35mERROR - \"${fromAddr}.skey/hwsfile\" does not exist! Please create it first with script 03a or 02.\e[0m"; exit 1; fi


#--------------------------------------------------------

echo
echo -e "\e[0mRegister Vote(s) using ${voterType} SigningKey\e[32m ${voterSigningFile}\e[0m with funds from Address\e[32m ${fromAddr}.addr\e[0m"
echo


#Setting default variables
metafileParameter=""; metafile=""; transactionMessage="{}"; enc=""; passphrase="cardano";
votefileParameter=""; actionIdCollector=""; voterHashCollector=""; voteCounter=0;

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
                metafileParameter+="--metadata-json-file ${metafile} "; metafileList+="'${metafile}' "

             elif [[ -f "${metafile}" && "${metafileExt^^}" == "CBOR" ]]; then #its a cbor file
                metafileParameter+="--metadata-cbor-file ${metafile} "; metafileList+="'${metafile}' "

             elif [[ -f "${metafile}" && "${metafileExt^^}" == "VOTE" ]]; then #its a vote file

		#Read in the vote file
		voteJSON=$(${cardanocli} ${cliEra} governance vote view --output-json --vote-file "${metafile}" 2> /dev/null)
                if [[ $? -ne 0 ]]; then echo -e "\n\e[35mERROR - Could not read in Vote-File '${metafile}' !\n\e[0m"; exit 1; fi
		echo -e "\e[0mReading Vote-File: \e[32m${metafile}\e[0m"

                #Read the values of the voting file
                { read voteActionVoter;
                  read voteActionID;
                  read voteActionAnchorHASH;
                  read voteActionAnchorURL;
                  read voteActionAnswer;
                } <<< $(jq -r "to_entries | (.[0].key // \"-\", (.[0].value | to_entries | (.[0].key // \"-\", .[0].value.anchor.dataHash // \"-\", .[0].value.anchor.url // \"-\", .[0].value.decision // \"-\" )))" <<< "${voteJSON}")

		#Get voteType
		case ${voteActionVoter%%-*} in
			"committee") voteType="Committee";;
			"drep") voteType="DRep";;
			"stakepool") voteType="Pool";;
			*) voteType="Unknown";;
		esac
		echo -e "\e[0m             Type: \e[94m${voteType}\e[0m"
		if [[ ! "${voterType}" == *"${voteType}"* ]]; then echo -e "\n\e[95mERROR - The given signing key is from a '${voterType}' key. The one in the vote file\nis from type '${voteType}'. So this can't be the correct signing key or vote file.\e[0m\n"; exit 1; fi

		#Get voteHash
		voteHash=${voteActionVoter##*-}
		echo -e "\e[0m       Voter-HASH: \e[94m${voteHash}\e[0m"

		#Get action-id
		voteActionUTXO=${voteActionID:0:64}
		voteActionIdx=${voteActionID:65}
		echo -e "\e[0m     Action-Tx-ID: \e[94m${voteActionUTXO}\n\e[0m     Action-Index: \e[94m${voteActionIdx}\e[0m"

		#Get action-url and hash
		if [[ "${voteActionAnchorURL}" != "-" && "${voteActionAnchorHASH}" != "-" ]]; then
			echo -e "\e[0m       Anchor-URL: \e[94m${voteActionAnchorURL}\n\e[0m      Anchor-Hash: \e[94m${voteActionAnchorHASH}\e[0m"
		fi

		#Get vote answer NO, YES, ABSTAIN
		echo -en "\e[0m      Vote-Answer: ";
	        case ${voteActionAnswer} in
			"VoteYes")	echo -e "\e[102m\e[30m YES \e[0m";;
			"VoteNo")	echo -e "\e[101m\e[30m NO \e[0m";;
			"Abstain")	echo -e "\e[43m\e[30m ABSTAIN \e[0m";;
			*) 		echo -e "\e[95mUNKNOWN!\e[0m";;
		esac

		#Check that the voteHash is the same for all votes
		if [[ "${voterHashCollector}" == "" ]]; then voterHashCollector="${voteHash}";
		elif [[ "${voterHashCollector}" != "${voteHash}" ]]; then echo -e "\n\e[91mERROR - Please include only votes for the same Voter-Hash (same vote key)!\n\e[0m"; exit 1;
		fi

		#Check that the action-id was not included before. Only one vote-file for one action-id allowed.
		if [[ "${actionIdCollector}" == *"${voteActionUTXO}#${voteActionIdx}"* ]]; then echo -e "\n\e[91mERROR - The Action-ID '${voteActionUTXO}#${voteActionIdx}' was already included before.\nOnly one vote for one Action-ID allowed!\n\e[0m"; exit 1; fi
		actionIdCollector+="${voteActionUTXO}#${voteActionIdx} " #add the current action-id to the collector

		echo
                votefileParameter+="--vote-file ${metafile} ";
		voteCounter=$((${voteCounter}+1))

	     else echo -e "\n\e[35mERROR - The specified File JSON/CBOR/VOTE-File '${metafile}' does not exist. Fileextension must be '.json', '.cbor' or '.vote'. Please try again.\n\e[0m"; exit 1;
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

#Check if there is only one vote included if also a hardware wallet is used (limitation by the hardware wallet firmware)
if [[ ${voteCounter} -gt 1 ]] && [[ -f "${fromAddr}.hwsfile" || "${voterSigningFile}" == *".hwsfile" ]]; then echo -e "\n\e[91mPlease include only one vote-file in case a hardware-wallet is involved in the transaction.\nThis is a limitation of the hardware-wallet firmware!\n\e[0m"; exit 1; fi

#Check if there are transactionMessages, if so, save the messages to a xxx.transactionMessage.json temp-file and add it to the list. Encrypt it if enabled.
if [[ ! "${transactionMessage}" == "{}" ]]; then

        transactionMessageMetadataFile="${tempDir}/$(basename ${fromAddr}).transactionMessage.json";
        tmp=$( jq . <<< ${transactionMessage} 2> /dev/null)
        if [ $? -eq 0 ]; then #json is valid, so no bad chars found

		#Check if encryption is enabled, encrypt the msg part
		if [[ "${encryption,,}" == "basic" ]]; then
			#check openssl
			if ! exists openssl; then echo -e "\e[33mYou need 'openssl', its needed to encrypt the transaction messages !\n\nInstall it on Ubuntu/Debian like:\n\e[97msudo apt update && sudo apt -y install openssl\n\n\e[33mThx! :-)\e[0m\n"; exit 2; fi
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

#----------------------------------------------------

#Read ProtocolParameters
case ${workMode} in
        "online")       #onlinemode
			protocolParametersJSON=$(${cardanocli} ${cliEra} query protocol-parameters)
			;;

        "light")        #lightmode
			protocolParametersJSON=${lightModeParametersJSON}
			;;

        "offline")      ##offlinemode
			readOfflineFile;        #Reads the offlinefile into the offlineJSON variable
			protocolParametersJSON=$(jq ".protocol.parameters" <<< ${offlineJSON})
			;;
esac
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

#Do a check if we are at least in conway-era (protocol major 9 and above)
protocolVersionMajor=$(jq -r ".protocolVersion.major // -1" <<< ${protocolParametersJSON})
if [[ ${protocolVersionMajor} -lt 9 ]]; then
	echo -e "\n\e[35mERROR - The current era on the chain does not support submitting governance votes. Needs conway-era and above!\n\e[0m"; exit 1; fi

#get live values
currentTip=$(get_currentTip); checkError "$?";
ttl=$(( ${currentTip} + ${defTTL} ))

echo -e "Current Slot-Height:\e[32m ${currentTip}\e[0m (setting TTL[invalid_hereafter] to ${ttl})"

#adaToSend + fees will be taken out of the sendFromUTXO and sent back to the same Address

rxcnt="1"               #transmit to one destination addr. all utxos will be sent back to the fromAddr

sendFromAddr=$(cat ${fromAddr}.addr); check_address "${sendFromAddr}"; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi;
sendToAddr=${sendFromAddr}

echo
echo -e "Pay fees from Address\e[32m ${fromAddr}.addr\e[0m: ${sendFromAddr}"
echo

#------------------------------------------------
#
# Checking UTXO Data of the source address and gathering data about total lovelaces and total assets
#

        #Get UTX0 Data for the address. When in online mode of course from the node and the chain, in lightmode via API requests, in offlinemode from the transferFile
        case ${workMode} in
                "online")	#check that the node is fully synced, otherwise the query would mabye return a false state
				if [[ $(get_currentSync) != "synced" ]]; then echo -e "\e[35mError - Node not fully synced or not running, please let your node sync to 100% first !\e[0m\n"; exit 1; fi
				showProcessAnimation "Query-UTXO: " &
				utxo=$(${cardanocli} ${cliEra} query utxo --address ${sendFromAddr} 2> /dev/stdout);
				if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${utxo}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
                                showProcessAnimation "Convert-UTXO: " &
                                utxoJSON=$(generate_UTXO "${utxo}" "${sendFromAddr}"); stopProcessAnimation;
                                ;;

                "light")	showProcessAnimation "Query-UTXO-LightMode: " &
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


#----------------------------------------------------

#get values to register the staking address on the blockchain
minOutUTXO=$(calc_minOutUTXO "${protocolParametersJSON}" "${sendToAddr}+1000000${assetsOutString}")

#Generate Dummy-TxBody file for fee calculation
txBodyFile="${tempDir}/dummy.txbody"; rm ${txBodyFile} 2> /dev/null
rm ${txBodyFile} 2> /dev/null
${cardanocli} ${cliEra} transaction build-raw ${txInString} --tx-out "${sendToAddr}+${totalLovelaces}${assetsOutString}" --invalid-hereafter ${ttl} --fee 200000 ${metafileParameter} ${votefileParameter} --out-file ${txBodyFile}
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

#cardano-cli with new fee calculation since cli 8.21.0
fee=$(${cardanocli} ${cliEra} transaction calculate-min-fee --tx-body-file ${txBodyFile} --protocol-params-file <(echo ${protocolParametersJSON}) --witness-count 2 --reference-script-size 0 | awk '{ print $1 }')
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

echo -e "\e[0mMimimum transfer Fee for ${txcnt}x TxIn & ${rxcnt}x TxOut: \e[32m $(convertToADA ${fee}) ADA / ${fee} lovelaces \e[90m"
echo

minRegistrationFund=$(( ${fee}+${minOutUTXO} ))

echo
echo -e "\e[0mMimimum funds required for registration (Sum of fees): \e[32m ${minRegistrationFund} lovelaces \e[90m"
echo

#calculate new balance for destination address
lovelacesToSend=$(( ${totalLovelaces}-${fee} ))

echo -e "\e[0mLovelaces that will be returned to payment Address (UTXO-Sum minus fees): \e[32m $(convertToADA ${lovelacesToSend}) ADA / ${lovelacesToSend} lovelaces \e[90m (min. required ${minOutUTXO} lovelaces)"
echo

#Checking about minimum funds in the UTX0
if [[ ${lovelacesToSend} -lt ${minOutUTXO} ]]; then echo -e "\e[35mNot enough funds on the source Addr! Minimum UTXO value is ${minOutUTXO} lovelaces.\e[0m"; exit; fi

txBodyFile="${tempDir}/$(basename ${fromAddr}).txbody"
txWitnessVoterFile="${tempDir}/$(basename ${voterSigningFile}).vote_txwitness"; rm ${txWitnessFile} 2> /dev/null		#witness for the voter signing
txWitnessPaymentFile="${tempDir}/$(basename ${fromAddr}).pay_txwitness"; rm ${txWitnessFile2} 2> /dev/null	#witness for the payment signing
txFile="${tempDir}/$(basename ${fromAddr}).tx"

echo -e "\e[0mBuilding the unsigned transaction body: \e[32m ${txBodyFile} \e[90m"
echo

#Building unsigned transaction body
rm ${txBodyFile} 2> /dev/null
${cardanocli} ${cliEra} transaction build-raw ${txInString} --tx-out "${sendToAddr}+${lovelacesToSend}${assetsOutString}" --invalid-hereafter ${ttl} --fee ${fee} ${metafileParameter} ${votefileParameter} --out-file ${txBodyFile}
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

dispFile=$(cat ${txBodyFile}); if ${cropTxOutput} && [[ ${#dispFile} -gt 4000 ]]; then echo "${dispFile:0:4000} ... (cropped)"; else echo "${dispFile}"; fi
echo

#If a hardware wallet is involved, do the autocorrection of the TxBody to make sure it is in canonical order for the assets
if [[ -f "${fromAddr}.hwsfile" || "${voterSigningFile}" == *".hwsfile" ]]; then

#	#remove the tag(258) from the txBodyFile
#	sed -si 's/04d901028184/048184/g' "${txBodyFile}"

        echo -ne "\e[0mAutocorrect the TxBody for canonical order: "
        tmp=$(autocorrect_TxBodyFile "${txBodyFile}"); if [ $? -ne 0 ]; then echo -e "\e[35m${tmp}\e[0m\n\n"; exit 1; fi
        echo -e "\e[32m${tmp}\e[90m\n"

        dispFile=$(cat ${txBodyFile}); if ${cropTxOutput} && [[ ${#dispFile} -gt 4000 ]]; then echo "${dispFile:0:4000} ... (cropped)"; else echo "${dispFile}"; fi
        echo
fi

echo -e "\e[0mSign (Witness+Assemble) the Tx-Body with the \e[32m${voterSigningFile}\e[0m and \e[32m${fromAddr}.skey|hwsfile\e[0m: \e[32m${txFile}\e[0m"
echo

#Generate the witnesses based on the different combinations for the payment/voting key

#Payment and Voting via the HW-Wallet -> generate both witnesses at the same time
if [[ -f "${fromAddr}.hwsfile" && "${voterSigningFile}" == *".hwsfile" ]]; then

	#Check that the HW-Wallet signing key is the correct one for the voterHash -> calculate the hash from the cborXpubKeyHex
	hwVoterHash=$(jq -r ".cborXPubKeyHex" "${voterSigningFile}" | cut -c 5-69 | xxd -r -ps | b2sum -l 224 -b | cut -d' ' -f 1 2> /dev/null)
	if [[ "${hwVoterHash}" != "" && "${hwVoterHash}" != "${voterHashCollector}" ]]; then 
		echo -e "\n\e[91mERROR - This Voter-Signing-File (${voterSigningFile}) with Hash '${hwVoterHash}' is not the correct\none for the Voter-Hash '${voterHashCollector}' used in the Vote-File!\n\e[0m"; exit 1;
	fi

	echo -e "\e[33mYou are using a Hardware-Wallet for both the voting and payment. Make sure its the same Hardware-Wallet!\n\e[0m";

        if ! ask "\e[0mAdding the Payment- and Voter-Witness from a local Hardware-Wallet key '\e[33m${fromAddr}.hwsfile & ${voterSigningFile}\e[0m', continue?" Y; then echo; echo -e "\e[35mABORT - Witness Signing aborted...\e[0m"; echo; exit 2; fi
        start_HwWallet "Ledger"; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
        tmp=$(${cardanohwcli} transaction witness --tx-file ${txBodyFile} --hw-signing-file ${fromAddr}.hwsfile --hw-signing-file ${voterSigningFile} --change-output-key-file ${fromAddr}.hwsfile ${magicparam} --out-file ${txWitnessPaymentFile} --out-file ${txWitnessVoterFile} 2> /dev/stdout)
        if [[ "${tmp^^}" =~ (ERROR|DISCONNECT) ]]; then echo -e "\e[35m${tmp}\e[0m\n"; exit 1; else echo -e "\e[32mDONE\e[0m\n"; fi
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi


#Payment via CLI, Voting via HW-Wallet
elif [[ -f "${fromAddr}.skey" && "${voterSigningFile}" == *".hwsfile" ]]; then

	#Check that the HW-Wallet signing key is the correct one for the voterHash -> calculate the hash from the cborXpubKeyHex
	hwVoterHash=$(jq -r ".cborXPubKeyHex" "${voterSigningFile}" | cut -c 5-69 | xxd -r -ps | b2sum -l 224 -b | cut -d' ' -f 1 2> /dev/null)
	if [[ "${hwVoterHash}" != "" && "${hwVoterHash}" != "${voterHashCollector}" ]]; then 
		echo -e "\n\e[91mERROR - This Voter-Signing-File (${voterSigningFile}) with Hash '${hwVoterHash}' is not the correct\none for the Voter-Hash '${voterHashCollector}' used in the Vote-File!\n\e[0m"; exit 1;
	fi

        if ! ask "\e[0mAdding the Voter-Witness signing from a local Hardware-Wallet key '\e[33m${voterSigningFile}\e[0m', continue?" Y; then echo; echo -e "\e[35mABORT - Witness Signing aborted...\e[0m"; echo; exit 2; fi
        start_HwWallet "Ledger"; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
        tmp=$(${cardanohwcli} transaction witness --tx-file ${txBodyFile} --hw-signing-file ${voterSigningFile} --out-file ${txWitnessVoterFile} ${magicparam} 2> /dev/stdout)
        if [[ "${tmp^^}" =~ (ERROR|DISCONNECT) ]]; then echo -e "\e[35m${tmp}\e[0m\n"; exit 1; else echo -e "\e[32mDONE\e[0m\n"; fi
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

        #read the needed payment signing keys into ram
        skeyJSON=$(read_skeyFILE "${fromAddr}.skey"); if [ $? -ne 0 ]; then echo -e "\e[35m${skeyJSON}\e[0m\n"; exit 1; else echo -e "\e[32mOK\e[0m\n"; fi
        ${cardanocli} ${cliEra} transaction witness --tx-body-file ${txBodyFile} --signing-key-file <(echo "${skeyJSON}") --out-file ${txWitnessPaymentFile}
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
        #forget the signing keys
        unset skeyJSON


#Payment via CLI, Voting via CLI
elif [[ -f "${fromAddr}.skey" ]]; then  #generate the payment witness via the cli

	#Check that the CLI voting signing key is the correct one for the voterHash -> calculate the hash from
	cliVoterHash=$(${cardanocli} ${cliEra} key verification-key --signing-key-file "${voterSigningFile}" --verification-key-file /dev/stdout | jq -r ".cborHex" 2> /dev/null | cut -c 5-69 | xxd -r -ps | b2sum -l 224 -b | cut -d' ' -f 1 2> /dev/null)
	if [[ "${cliVoterHash}" != "" && "${cliVoterHash}" != "${voterHashCollector}" ]]; then
		echo -e "\n\e[91mERROR - This Voter-Signing-File (${voterSigningFile}) with Hash '${cliVoterHash}' is not the correct\none for the Voter-Hash '${voterHashCollector}' used in the Vote-File!\n\e[0m"; exit 1;
	fi

        #read the needed voting signing keys into ram
        skeyJSON=$(read_skeyFILE "${voterSigningFile}"); if [ $? -ne 0 ]; then echo -e "\e[35m${skeyJSON}\e[0m\n"; exit 1; else echo -e "\e[32mOK\e[0m\n"; fi
        ${cardanocli} ${cliEra} transaction witness --tx-body-file ${txBodyFile} --signing-key-file <(echo "${skeyJSON}") --out-file ${txWitnessVoterFile}
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
        #forget the signing keys
        unset skeyJSON

        #read the needed payment signing keys into ram
        skeyJSON=$(read_skeyFILE "${fromAddr}.skey"); if [ $? -ne 0 ]; then echo -e "\e[35m${skeyJSON}\e[0m\n"; exit 1; else echo -e "\e[32mOK\e[0m\n"; fi
        ${cardanocli} ${cliEra} transaction witness --tx-body-file ${txBodyFile} --signing-key-file <(echo "${skeyJSON}") --out-file ${txWitnessPaymentFile}
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
        #forget the signing keys
        unset skeyJSON


#Payment via HW-Wallet, Voting via CLI -> not allowed
else
	echo -e "\e[91mThis combination is not allowed! If a Hardware-Wallet is used for the payment, the vote-signing must also be done via the same Hardware-Wallet.\nYou can also use a normal cli wallet to pay for the vote-file registration on chain.\e[0m\n"; exit 1;
fi

#Assemble all witnesses into the final TxBody
rm ${txFile} 2> /dev/null
${cardanocli} ${cliEra} transaction assemble --tx-body-file ${txBodyFile} --witness-file ${txWitnessVoterFile} --witness-file ${txWitnessPaymentFile} --out-file ${txFile}
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
                                                                        type: \"Transaction\",
                                                                        era: \"$(jq -r .protocol.era <<< ${offlineJSON})\",
                                                                        fromAddr: \"${fromAddr}\",
                                                                        sendFromAddr: \"${sendFromAddr}\",
                                                                        toAddr: \"${fromAddr}\",
                                                                        sendToAddr: \"${sendToAddr}\",
                                                                        txJSON: ${txFileJSON} } ]" <<< ${offlineJSON})
                                #Write the new offileFile content
                                offlineJSON=$( jq ".history += [ { date: \"$(date -R)\", action: \"signed utxo-transaction from '${fromAddr}' to '${toAddr}'\" } ]" <<< ${offlineJSON})
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
