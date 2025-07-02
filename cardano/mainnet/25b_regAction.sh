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

Usage:  $(basename $0) <Base/PaymentAddressName (paying for fees and action-deposit-value)>  <1 or more *.action files>

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

#exit with an information, that the script needs at least conway era
case ${cliEra} in
        "babbage"|"alonzo"|"mary"|"allegra"|"shelley")
                echo -e "\n\e[91mINFORMATION - The chain is not in conway era yet. This script will start to work once we forked into conway era. Please check back later!\n\e[0m"; exit;
                ;;
esac

#At least 2 parameters were provided, use them

#Parameter Count is 2 or more
fromAddr="$(dirname $1)/$(basename $1 .addr)"; fromAddr=${fromAddr/#.\//};

#Check if the payment wallet is a hw wallet. In that case, throw an error, because actions cannot be paid with hw wallets
if [[ -f "${fromAddr}.hwsfile" ]]; then echo -e "\n\e[91mERROR - Its not possible to register/sign an Action-Proposal with a Hardware-Wallet. Please use a regular CLI-Wallet for this, thx.\n\e[0m"; exit 1; fi

#Check presence of payment addr and skey/hwsfile
if [ ! -f "${fromAddr}.addr" ]; then echo -e "\n\e[91mERROR - \"${fromAddr}.addr\" does not exist! Please create it first with script 03a or 02.\e[0m"; exit 1; fi
if ! [[ -f "${fromAddr}.skey" ]]; then echo -e "\n\e[91mERROR - \"${fromAddr}.skey\" does not exist! Please create it first with script 03a or 02.\e[0m"; exit 1; fi


#--------------------------------------------------------

echo
echo -e "\e[0mRegister Action(s) with funds from Address\e[32m ${fromAddr}.addr\e[0m"
echo

#Setting default variables
metafileParameter=""; metafile=""; transactionMessage="{}"; enc=""; passphrase="cardano";
actionfileParameter=""; actionfileCounter=0; actionfileCollector=""; voteActionDepositTotal=0;

#Check all optional parameters about there types and set the corresponding variables
#Starting with the 2th parameter (index=1) up to the last parameter
paramCnt=$#;
allParameters=( "$@" )
for (( tmpCnt=1; tmpCnt<${paramCnt}; tmpCnt++ ))
 do
        paramValue=${allParameters[$tmpCnt]}
        #echo -n "${tmpCnt}: ${paramValue} -> "

        #Check if an additional metadata.json/.cbor was set as parameter (not a Message, not a UTXO#IDX, not empty, not a number)
        if [[ ! "${paramValue,,}" =~ ^msg:(.*)$ ]] && [[ ! "${paramValue,,}" =~ ^enc:(.*)$ ]] && [[ ! "${paramValue,,}" =~ ^pass:(.*)$ ]] && [[ ! "${paramValue,,}" =~ ^utxolimit:(.*)$ ]] && [[ ! "${paramValue,,}" =~ ^onlyutxowithasset:(.*)$ ]] && [[ ! "${paramValue,,}" =~ ^skiputxowithasset:(.*)$ ]] && [[ ! "${paramValue}" =~ ^([[:xdigit:]]+#[[:digit:]]+(\|?)){1,}$ ]] && [[ ! ${paramValue} == "" ]] && [ -z "${paramValue##*[!0-9]*}" ]; then

	     metafile=${paramValue}; metafileExt=${metafile##*.}
             if [[ -f "${metafile}" && "${metafileExt^^}" == "JSON" ]]; then #its a json file
                #Do a simple basic check if the metadatum is in the 0..65535 range
                metadatum=$(jq -r "keys_unsorted[0]" "${metafile}" 2> /dev/null)
                if [[ $? -ne 0 ]]; then echo -e "\n\e[91mERROR - '${metafile}' is not a valid JSON file!\n\e[0m"; exit 1; fi
                #Check if it is null, a number, lower then zero, higher then 65535, otherwise exit with an error
   		if [ "${metadatum}" == null ] || [ -z "${metadatum##*[!0-9]*}" ] || [ "${metadatum}" -lt 0 ] || [ "${metadatum}" -gt 65535 ]; then
			echo -e "\n\e[91mERROR - MetaDatum Value '${metadatum}' in '${metafile}' must be in the range of 0..65535!\n\e[0m"; exit 1; fi
                metafileParameter+="--metadata-json-file ${metafile} "; metafileList+="'${metafile}' "

             elif [[ -f "${metafile}" && "${metafileExt^^}" == "CBOR" ]]; then #its a cbor file
                metafileParameter+="--metadata-cbor-file ${metafile} "; metafileList+="'${metafile}' "

             elif [[ -f "${metafile}" && "${metafileExt^^}" == "ACTION" ]]; then #its an action file

		#Read in the action file
		actionJSON=$(${cardanocli} ${cliEra} governance action view --output-json --action-file "${metafile}" 2> /dev/null)
                if [[ $? -ne 0 ]]; then echo -e "\n\e[91mERROR - Could not read in Action-File '${metafile}' !\n\e[0m"; exit 1; fi
		echo -e "\e[0mReading Action-File: \e[32m${metafile}\e[0m"


		#Typical ActionFile view content for an info action
		#{
		#  "anchor": {
		#    "dataHash": "85ef3207d3e342c32040aa6bef7c60afa524f181a18f51c5791d6da2aa7ecae0",
		#    "url": "https://www.test/test.json"
		#  },
		#  "deposit": 123456789,
		#  "governance action": {
		#    "tag": "InfoAction"
		#  },
		#  "return address": {
		#    "credential": {
		#      "keyHash": "c13582aec9a44fcc6d984be003c5058c660e1d2ff1370fd8b49ba73f"
		#    },
		#    "network": "Testnet"
		#  }
		#}

		#Treasury Withdrawal
		#  "governance action": {
		#    "contents": [
		#      [
		#        [
		#          {
		#            "credential": {
		#              "keyHash": "468bfb1fc096297a108bfdfb3bd6aa7eb4182f378bbe0241fd50c18c"
		#            },
		#            "network": "Testnet"
		#          },
		#          623
		#        ]
		#      ],
		#      null
		#    ],
		#    "tag": "TreasuryWithdrawals"

		#No confidence
		#  "governance action": {
		#    "contents": {
 		#     "govActionIx": 0,
		#      "txId": "6bff8515060c08e9cae4d4e203a4d8b2e876848aae8c4e896acda7202d3ac679"
		#    },
		#    "tag": "NoConfidence"
 		# },

		#New Constitution
		#  "governance action": {
		#    "contents": [
		#      { //or null if no previous constitution
		#        "govActionIx": 0,
		#        "txId": "6bff8515060c08e9cae4d4e203a4d8b2e876848aae8c4e896acda7202d3ac679"
		#      },
		#      {
		#        "anchor": {
		#          "dataHash": "b4fba3c5a430634f2e5e7007b33be02562efbcd036c0cf3dbb9d9dbdf418ef27",
		#          "url": "https://my-ip.at/test/atada.metadata.json"
		#        }
		#      }
		#    ],
		#    "tag": "NewConstitution"


		#Hardfork
		#   "governance action": {
		#     "contents": [
		#            {
		#                "govActionIx": 0,
		#                "txId": "3ade1c4b1c492ff2b7195203c88e6ea4fc3bf50787bec17f3d4478a789147f16"
		#            },
		#            {
		#                "major": 10,
		#                "minor": 25
		#            }
		#        ],
		#        "tag": "HardForkInitiation"


                #Read the values of the action file
                { read voteActionTag;
		  read voteActionContents;
                  read voteActionDeposit;
                  read voteActionAnchorHASH;
                  read voteActionAnchorURL;
                  read voteActionReturnKeyHash;
                  read voteActionReturnNetwork;
                } <<< $(jq -r '."governance action".tag // "-", "\(."governance action".contents)" // "-", .deposit // -1, .anchor.dataHash // "-", .anchor.url // "-", ."return address".credential.keyHash // "-", ."return address".network' <<< "${actionJSON}")

		voteActionContents=$(jq -r "." <<< "${voteActionContents}") #convert it to nice json format

		echo -e "\e[0m         Action-Tag: \e[94m${voteActionTag}\e[0m"

		#Show action-url and hash
		if [[ "${voteActionAnchorURL}" != "-" && "${voteActionAnchorHASH}" != "-" ]]; then
			echo -e "\e[0m         Anchor-URL: \e[94m${voteActionAnchorURL}\n\e[0m        Anchor-Hash: \e[94m${voteActionAnchorHASH}\e[0m"
		fi

		#Show deposit value
		if [[ ${voteActionDeposit} != "-1" ]]; then
			voteActionDeposit=$((${voteActionDeposit}+0))
			echo -e "\e[0m      Deposit-Value: \e[94m$(convertToADA ${voteActionDeposit}) ADA\e[0m"
			else
			echo -e "\n\e[91mERROR - There is no deposit value in the Action-File, can't proceed without that value.\n\e[0m"; exit 1;
		fi

		#Show deposit return stakeaddress
		case "${voteActionReturnNetwork,,}" in
			"mainnet")	voteActionReturnAddr=$(${bech32_bin} "stake" <<< "e1${voteActionReturnKeyHash}" 2> /dev/null);
			                if [[ $? -ne 0 ]]; then echo -e "\n\e[91mERROR - Could not get Deposit-Return Stake-Address from Return-KeyHash '${voteActionReturnKeyHash}' !\n\e[0m"; exit 1; fi
					;;

			"testnet")	voteActionReturnAddr=$(${bech32_bin} "stake_test" <<< "e0${voteActionReturnKeyHash}" 2> /dev/null);
			                if [[ $? -ne 0 ]]; then echo -e "\n\e[91mERROR - Could not get Deposit-Return Stake-Address from Return-KeyHash '${voteActionReturnKeyHash}' !\n\e[0m"; exit 1; fi
					;;

			*)		echo -e "\n\e[91mERROR - Unknown network type ${voteActionReturnNetwork} for the Deposit-Return KeyHash !\n\e[0m"; exit 1;
					;;

		esac
		echo -e "\e[0m Deposit-ReturnAddr: \e[33m${voteActionReturnAddr}\e[0m"
		echo

		#Check that the Deposit-ReturnAddr is registered on the network
		case ${workMode} in
	                "online")       showProcessAnimation "Query-StakeAddress-Info: " &
	                                rewardsJSON=$(${cardanocli} ${cliEra} query stake-address-info --address ${voteActionReturnAddr} 2> /dev/stdout)
	                                if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[91mERROR - ${rewardsJSON}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
	                                ;;

	                "light")        showProcessAnimation "Query-StakeAddress-Info-LightMode: " &
	                                rewardsJSON=$(queryLight_stakeAddressInfo "${voteActionReturnAddr}")
	                                if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[91mERROR - ${rewardsJSON}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
	                                ;;
	        esac
	        rewardsEntryCnt=$(jq -r 'length' <<< ${rewardsJSON})
	        if [[ ${rewardsEntryCnt} == 0 ]]; then #not registered yet
	                echo -e "\n\e[91mERROR - Deposit-Return Address '${voteActionReturnAddr}'\nis NOT registered on the chain! Register it first with script 03b ...\e[0m\n"; exit 1;
		fi


		#Show additional informations depending on the action-type/tag
		case "${voteActionTag,,}" in

			"treasurywithdrawals")

				{ read fundsReceivingAmount; read fundsReceivingStakeAddrHash; } <<< $(jq -r '.[0][0][1], .[0][0][0].credential.keyHash' <<< "${voteActionContents}")
		                echo -e "  Withdrawal-Amount: \e[32m$(convertToADA ${fundsReceivingAmount}) ADA / ${fundsReceivingAmount} lovelaces\e[0m"
		                #Show withdrawal payout stakeaddress
		                case "${voteActionReturnNetwork,,}" in
		                        "mainnet")      fundsReceivingStakeAddr=$(${bech32_bin} "stake" <<< "e1${fundsReceivingStakeAddrHash}" 2> /dev/null);
		                                        if [[ $? -ne 0 ]]; then echo -e "\n\e[91mERROR - Could not get Withdrawal-Payout Stake-Address from KeyHash '${fundsReceivingStakeAddrHash}' !\n\e[0m"; exit 1; fi
		                                        ;;
		                        "testnet")      fundsReceivingStakeAddr=$(${bech32_bin} "stake_test" <<< "e0${fundsReceivingStakeAddrHash}" 2> /dev/null);
		                                        if [[ $? -ne 0 ]]; then echo -e "\n\e[91mERROR - Could not get Withdrawal-Payout Stake-Address from KeyHash '${fundsReceivingStakeAddrHash}' !\n\e[0m"; exit 1; fi
		                                        ;;
		                esac
				echo -e "    Withdrawal-Addr: \e[32m${fundsReceivingStakeAddr}\e[0m"
				;;

			"noconfidence")
		                #Show referencing Action-Id
				{ read prevActionUTXO; read prevActionIDX; } <<< $(jq -r '.txId // "-", .govActionIx // "-"' <<< "${voteActionContents}")
				if [[ ${#prevActionUTXO} -gt 1 ]]; then
			        	echo -e "Reference-Action-ID: \e[32m${prevActionUTXO}#${prevActionIDX}\e[0m"
					else
			        	echo -e "Reference-Action-ID: \e[32m(none)\e[0m"
				fi
				;;

			"newconstitution")
		                #Show referencing Action-Id and Constitution-URL/HASH
				{ read prevActionUTXO; read prevActionIDX; read constitutionURL; read constitutionHASH;} <<< $(jq -r '.[0].txId // "-", .[0].govActionIx // "-", .[1].anchor.url // "-", .[1].anchor.dataHash // "-"' <<< "${voteActionContents}")
				if [[ ${#prevActionUTXO} -gt 1 ]]; then
			        	echo -e "Reference-Action-ID: \e[32m${prevActionUTXO}#${prevActionIDX}\e[0m"
					else
			        	echo -e "Reference-Action-ID: \e[32m(none)\e[0m"
				fi
				echo -e "\e[0m   Constitution-URL: \e[32m${constitutionURL}\n\e[0m  Constitution-Hash: \e[32m${constitutionHASH}\e[0m"
				;;

			"hardforkinitiation")
		                #Show referencing Action-Id and Hardfork-Major/Minor-Version
				{ read prevActionUTXO; read prevActionIDX; read forkMajorVer; read forkMinorVer;} <<< $(jq -r '.[0].txId // "-", .[0].govActionIx // "-", .[1].major // "-", .[1].minor // "-"' <<< "${voteActionContents}")
				if [[ ${#prevActionUTXO} -gt 1 ]]; then
			        	echo -e "Reference-Action-ID: \e[32m${prevActionUTXO}#${prevActionIDX}\e[0m"
					else
			        	echo -e "Reference-Action-ID: \e[32m(none)\e[0m"
				fi
				echo
				echo -e "\e[0mFork to\e[32m Protocol-Version \e[0m► \e[94m${forkMajorVer}.${forkMinorVer}\e[0m"
				;;

			"parameterchange")
				#Show referencing Actio-Id and the content of the parameterchange json section
				{ read prevActionUTXO; read prevActionIDX; read changeParameters;} <<< $(jq -r '.[0].txId // "-", .[0].govActionIx // "-", "\(.[1])" // "{}"' 2> /dev/null <<< "${voteActionContents}")
				if [[ ${#prevActionUTXO} -gt 1 ]]; then
			        	echo -e "Reference-Action-ID: \e[32m${prevActionUTXO}#${prevActionIDX}\e[0m"
					else
			        	echo -e "Reference-Action-ID: \e[32m(none)\e[0m"
				fi

				changeParameterRender=$(jq -r 'to_entries[] | "\\e[0m   Change parameter:\\e[32m \(.key) \\e[0m► \\e[94m\(.value)\\e[0m"' <<< ${changeParameters} 2> /dev/null)
				echo
				echo -e "${changeParameterRender}"
				;;

			"updatecommittee")
				#Show referencing Actio-Id and the hashes that are added/removed, also the new threshold
				{ read prevActionUTXO; read prevActionIDX; read committeeThreshold; } <<< $(jq -r '.[0].txId // "-", .[0].govActionIx // "-", "\(.[3])" // "-"' 2> /dev/null <<< "${voteActionContents}")
				if [[ ${#prevActionUTXO} -gt 1 ]]; then
			        	echo -e "Reference-Action-ID: \e[32m${prevActionUTXO}#${prevActionIDX}\e[0m"
					else
			        	echo -e "Reference-Action-ID: \e[32m(none)\e[0m"
				fi
				echo
				committeeThresholdType=$(jq -r "type" <<< ${committeeThreshold} 2> /dev/null)
				case ${committeeThresholdType} in
					"object")
						{ read numerator; read denominator; } <<< $(jq -r '.numerator // "-", .denominator // "-"' <<< ${committeeThreshold})
						echo -e "\e[0mSet\e[32m threshold \e[0m► \e[94m${numerator} out of ${denominator} ($(bc <<< "scale=0; (${numerator}*100/${denominator})/1")%)\e[0m"
						;;

						"number")
						echo -e "\e[0mSet\e[32m threshold \e[0m► \e[94m$(bc <<< "scale=0; (${committeeThreshold}*100)/1")%\e[0m"
						;;
				esac
				addHashesRender=$(jq -r '.[2] // {} | to_entries[] | "\\e[0mAdding\\e[32m \(.key)-\(.value)" | split("-") | "\(.[0]) \\e[0m► \\e[94m\(.[1])\\e[0m (max term epoch \(.[2]))"' <<< ${voteActionContents} 2> /dev/null)
				remHashesRender=$(jq -r '.[1][] // [] | to_entries[] | "\\e[0mRemove\\e[32m \(.key) \\e[0m◄ \\e[91m\(.value)\\e[0m"' <<< ${voteActionContents} 2> /dev/null)
				echo -e "${addHashesRender}"
				echo -e "${remHashesRender}"
				;;

		esac

                #Check that the same Action-File was not added before.
                if [[ "${actionfileCollector}" == *"${metafile}"* ]]; then echo -e "\n\e[91mERROR - The Action-File '${metafile}' is more than once in the parameters list!\n\e[0m"; exit 1; fi
                actionfileCollector+="'${metafile}' " #add the current Action-File to the collector

                actionfileParameter+="--proposal-file ${metafile} ";
		actionfileCounter=$((${actionfileCounter}+1));
		voteActionDepositTotal=$((${voteActionDepositTotal}+${voteActionDeposit}))

		echo -e "\n\e[90m------------\e[0m\n"

	     else echo -e "\n\e[91mERROR - The specified File JSON/CBOR/ACTION-File '${metafile}' does not exist. Fileextension must be '.json', '.cbor' or '.action'. Please try again.\n\e[0m"; exit 1;
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
                                                if [ $? -ne 0 ]; then echo -e "\n\e[91mMessage-Adding-ERROR: \"${tmpMessage}\" contain invalid chars for a JSON!\n\e[0m"; exit 1; fi
                        else echo -e "\n\e[91mMessage-Adding-ERROR: \"${tmpMessage}\" is too long, max. 64 bytes allowed, yours is $(byteLength "${tmpMessage}") bytes long!\n\e[0m"; exit 1;
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

echo -e "\e[0mTotal Deposit-Value: \e[33m$(convertToADA ${voteActionDepositTotal}) ADA\e[0m"
echo


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
			echo -e "\n\e[91mERROR - The given encryption mode '${encryption,,}' is not on the supported list of encryption methods. Only 'basic' from CIP-0083 is currently supported\n\n\e[0m"; exit 1;
		fi

		echo "${tmp}" > ${transactionMessageMetadataFile}; metafileParameter="${metafileParameter}--metadata-json-file ${transactionMessageMetadataFile} "; #add it to the list of metadata.jsons to attach

	else
		echo -e "\n\e[91mERROR - Additional Transaction Message-Metafile is not valid:\n\n$${transactionMessage}\n\nPlease check your added Message-Paramters.\n\e[0m"; exit 1;
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
	echo -e "\n\e[91mERROR - The current era on the chain does not support submitting governance actions. Needs conway-era and above!\n\e[0m"; exit 1; fi

#get live values
currentTip=$(get_currentTip); checkError "$?";
defTTL=25000 #normally 100000 for mainnet, but with the faster testnets the max. TTL is 25920 instead (the formula is 3*k/f where k is the security parameter and f is the active slot coefficient). otherwise we have plutus script issues.
ttl=$(( ${currentTip} + ${defTTL} ))

echo -e "Current Slot-Height:\e[32m ${currentTip}\e[0m (setting TTL[invalid_hereafter] to ${ttl})"

#adaToSend + fees + actionDeposit will be taken out of the sendFromUTXO and sent back to the same Address

rxcnt="1"               #transmit to one destination addr. all utxos will be sent back to the fromAddr

sendFromAddr=$(cat ${fromAddr}.addr); check_address "${sendFromAddr}"; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi;
sendToAddr=${sendFromAddr}

echo
echo -e "Pay fees and Action-Deposit from Address\e[32m ${fromAddr}.addr\e[0m: ${sendFromAddr}"
echo

#------------------------------------------------
#
# Checking UTXO Data of the source address and gathering data about total lovelaces and total assets
#

        #Get UTX0 Data for the address. When in online mode of course from the node and the chain, in lightmode via API requests, in offlinemode from the transferFile
        case ${workMode} in
                "online")	#check that the node is fully synced, otherwise the query would mabye return a false state
				if [[ $(get_currentSync) != "synced" ]]; then echo -e "\e[91mError - Node not fully synced or not running, please let your node sync to 100% first !\e[0m\n"; exit 1; fi
				showProcessAnimation "Query-UTXO: " &
				utxo=$(${cardanocli} ${cliEra} query utxo --output-text --address ${sendFromAddr} 2> /dev/stdout);
				if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[91mERROR - ${utxo}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
                                showProcessAnimation "Convert-UTXO: " &
                                utxoJSON=$(generate_UTXO "${utxo}" "${sendFromAddr}"); stopProcessAnimation;
                                ;;

                "light")	showProcessAnimation "Query-UTXO-LightMode: " &
				utxo=$(queryLight_UTXO "${sendFromAddr}");
				if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[91mERROR - ${utxo}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
                                showProcessAnimation "Convert-UTXO: " &
                                utxoJSON=$(generate_UTXO "${utxo}" "${sendFromAddr}"); stopProcessAnimation;
                                ;;

                "offline")      readOfflineFile;        #Reads the offlinefile into the offlineJSON variable
                                utxoJSON=$(jq -r ".address.\"${sendFromAddr}\".utxoJSON" <<< ${offlineJSON} 2> /dev/null)
                                if [[ "${utxoJSON}" == null ]]; then echo -e "\e[91mPayment-Address not included in the offline transferFile, please include it first online!\e[0m\n"; exit 1; fi
                                ;;
        esac

	txcnt=$(jq length <<< ${utxoJSON}) #Get number of UTXO entries (Hash#Idx), this is also the number of --tx-in for the transaction
	if [[ ${txcnt} == 0 ]]; then echo -e "\e[91mNo funds on the Source Address!\e[0m\n"; exit 1; else echo -e "\e[32m${txcnt} UTXOs\e[0m found on the Source Address!\n"; fi

	#Calculating the total amount of lovelaces in all utxos on this address
        #totalLovelaces=$(jq '[.[].amount[0]] | add' <<< ${utxoJSON})

	totalLovelaces=0
        totalAssetsJSON="{}"; 	#Building a total JSON with the different assetstypes "policyIdHash.name", amount and name
        totalPolicyIDsJSON="{}"; #Holds the different PolicyIDs as values "policyIDHash", length is the amount of different policyIDs
	assetsOutString="";	#This will hold the String to append on the --tx-out if assets present or it will be empty

	collateralUTXO="";	#Holds the first possible collateral utxo
	collateralAmount=0;	#Holds the amount from the possible collateral utxo (lovelaces)

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

	#get the index of a possible collateral utxo
	if [[ "${collateralUTXO}" == "" && ${assetsEntryCnt} -eq 0 && $(bc <<< "${utxoAmount}>=5000000") -eq 1 && $(bc <<< "${utxoAmount}<=10000000") -eq 1 ]]; then collateralUTXO=${utxoHashIndex}; collateralAmount=${utxoAmount}; fi

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
	txInString+="--tx-in ${utxoHashIndex} "

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

#Dummy-TxBody file for fee calculation
txBodyFile="${tempDir}/dummy.txbody"; rm ${txBodyFile} 2> /dev/null
rm ${txBodyFile} 2> /dev/null


case "${voteActionTag,,}" in

	"treasurywithdrawals"|"parameterchange")	#transaction needs a guardrailsscript and execution units costs calculation

		#Check that the guardrails-script.plutus file is present
		if [ ! -f "${guardrailsScriptFile}" ]; then echo -e "\n\e[91mERROR - \"${guardrailsScriptFile}\" does not exist! Download it first and/or set the correct path in the 00_common.sh/common.inc config-file.\e[0m\n"; exit 1; fi

		#Show the choosen collateral UTXO
		if [[ "${collateralUTXO}" != "" ]]; then
			echo -e "\e[0mChoosen UTXO for the Collateral:\e[32m ${collateralUTXO} ($(convertToADA ${collateralAmount}) ADA)\e[0m\n";
		else
			echo -e "\e[33mSORRY - Could not find a valid Collateral UTXO. Please send yourself 5-10 ADA to this address\nso a collateral UTXO can be picked, thx!\e[0m\n"; exit 1;
		fi

		#Remove the collateralUTXO from the list of input utxos
		txInString=$(sed "s/--tx-in ${collateralUTXO}//g" <<< ${txInString})

		#Subtract the lovelaces on the collateralUTXO from the totalLovelaces on the output
		totalLovelaces=$(bc <<< "${totalLovelaces} - ${collateralAmount}" )

		#Decrease the amount of tx-in-counts by 1 (collateral utxo does not count)
		txcnt=$(( ${txcnt} - 1 ))

                #Generate Dummy-TxBody file for plutus script cost calculation, use a dummy cost of (0,0) for now
                ${cardanocli} ${cliEra} transaction build-raw \
                        ${txInString} \
                        --tx-in-collateral "${collateralUTXO}" \
                        --tx-out "${sendToAddr}+${totalLovelaces}${assetsOutString}" \
                        --proposal-script-file "${guardrailsScriptFile}" \
                        --proposal-redeemer-value {} \
                        --proposal-execution-units "(0,0)" \
                        --protocol-params-file <(echo ${protocolParametersJSON}) \
                        --invalid-hereafter ${ttl} \
                        --fee 200000 ${metafileParameter} ${actionfileParameter} --out-file ${txBodyFile} 2> /dev/stdout
		checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

		#Calculate the real plutus script execution costs from the Dummy-TxBody
		case ${workMode} in
		        "online")       #onlinemode
					execUnitsJSON=$(${cardanocli} ${cliEra} transaction calculate-plutus-script-cost online --tx-file ${txBodyFile} --out-file /dev/stdout 2> /dev/stdout)
					if [ $? -ne 0 ]; then echo -e "\n\e[35mERROR - ${execUnitsJSON}\e[0m\n"; exit 1; fi
					constitutionScriptHash=$(${cardanocli} ${cliEra} query constitution 2> /dev/stdout | jq -r ".script" 2> /dev/null)
					checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
					;;

		        "light"|"offline") #lightmode and offlinemode
					eraHistoryJSON=$(jq ".eraHistory // {}" <<< ${protocolParametersJSON})
					if [[ "${eraHistoryJSON}" == "{}" ]]; then echo -e "\e[91mSORRY, something went wrong. There is no 'eraHistory' present in the protocol-parameters file used in Light-Mode.\e[0m\n"; exit; fi
					constitutionScriptHash=$(jq -r ".constitution.script // {}" <<< ${protocolParametersJSON})
					if [[ "${constitutionJSON}" == "{}" ]]; then echo -e "\e[91mSORRY, something went wrong. There is no 'constitution' present in the protocol-parameters file used in Light-Mode.\e[0m\n"; exit; fi
					execUnitsJSON=$(${cardanocli} ${cliEra} transaction calculate-plutus-script-cost offline \
						--unsafe-extend-safe-zone \
						--genesis-file ${genesisfile_byron} \
						--era-history-file <(echo ${eraHistoryJSON}) \
						--protocol-params-file <(echo ${protocolParametersJSON}) \
						--utxo-file <(sed -e 's/": "\([0-9]\+\)"/": \1/g' <<< ${utxoJSON}) \
						--tx-file ${txBodyFile} \
						--out-file /dev/stdout 2> /dev/stdout)
					if [ $? -ne 0 ]; then echo -e "\n\e[35mERROR - ${execUnitsJSON}\e[0m\n"; exit 1; fi
					;;
		esac

		echo -e "\e[0mExecution Units/Costs for the Guardrails-Script: \e[32m${guardrailsScriptFile}\e[90m";
		jq -rM <<< "${execUnitsJSON}" 2> /dev/null
		echo -e "\e[0m";
		execUnitCosts=$(jq -r '"(\(.[0].executionUnits.steps), \(.[0].executionUnits.memory))"' <<< "${execUnitsJSON}" 2> /dev/null)

		#Check that the script hash in the constitution is the same as in the local guardrailsscript
		localGuardrailsScriptHash=$(jq -r ".[0].scriptHash" <<< ${execUnitsJSON} 2> /dev/null)
		if [[ "${localGuardrailsScriptHash}" != "${constitutionScriptHash}" ]]; then echo -e "\e[91mERROR, your local Guardrails-Script with Hash '${localGuardrailsScriptHash}' is different than the currently ScriptHash in the Constitution '${constitutionScriptHash}'.\nAre you sure you are using the right guardrails-script.plutus file?\e[0m\n"; exit; fi

                #Generate Dummy-TxBody file for fee calculation now with the real plutus script costs
                ${cardanocli} ${cliEra} transaction build-raw \
                        ${txInString} \
                        --tx-in-collateral "${collateralUTXO}" \
                        --tx-out "${sendToAddr}+${totalLovelaces}${assetsOutString}" \
                        --proposal-script-file "${guardrailsScriptFile}" \
                        --proposal-redeemer-value {} \
                        --proposal-execution-units "${execUnitCosts}" \
                        --protocol-params-file <(echo ${protocolParametersJSON}) \
                        --invalid-hereafter ${ttl} \
                        --fee 200000 ${metafileParameter} ${actionfileParameter} --out-file ${txBodyFile} 2> /dev/stdout
		checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

		#calculate the transaction fee. new parameters since cardano-cli 8.21.0
		fee=$(${cardanocli} ${cliEra} transaction calculate-min-fee --output-text \
			--tx-body-file ${txBodyFile} \
			--protocol-params-file <(echo ${protocolParametersJSON}) \
			--witness-count 2 \
			--reference-script-size 0 2> /dev/stdout)
		checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

		if [ $? -ne 0 ]; then echo -e "\n\e[35m${fee}\e[0m\n"; exit 1; fi
		fee=${fee%% *} #only get the first part of 'xxxxxx Lovelaces'
		echo -e "\e[0mMimimum transfer Fee for ${txcnt}x TxIn & ${rxcnt}x TxOut & Guardrails-Script: \e[32m $(convertToADA ${fee}) ADA / ${fee} lovelaces \e[90m"
		echo
		;;

	*) #all other transactions
		#Generate Dummy-TxBody file for fee calculation
		${cardanocli} ${cliEra} transaction build-raw ${txInString} --tx-out "${sendToAddr}+${totalLovelaces}${assetsOutString}" --invalid-hereafter ${ttl} --fee 200000 ${metafileParameter} ${actionfileParameter} --out-file ${txBodyFile}
		checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
		#calculate the transaction fee. new parameters since cardano-cli 8.21.0
		fee=$(${cardanocli} ${cliEra} transaction calculate-min-fee --output-text --tx-body-file ${txBodyFile} --protocol-params-file <(echo ${protocolParametersJSON}) --witness-count 1 --reference-script-size 0 2> /dev/stdout)
		if [ $? -ne 0 ]; then echo -e "\n\e[35m${fee}\e[0m\n"; exit 1; fi
		fee=${fee%% *} #only get the first part of 'xxxxxx Lovelaces'
		echo -e "\e[0mMimimum transfer Fee for ${txcnt}x TxIn & ${rxcnt}x TxOut: \e[32m $(convertToADA ${fee}) ADA / ${fee} lovelaces \e[90m"
		echo
		;;

esac

minRegistrationFund=$(( ${fee}+${minOutUTXO}+${voteActionDepositTotal} ))

echo
echo -e "\e[0mMimimum funds required for registration (Sum of fees + ActionDeposit): \e[32m $(convertToADA ${minRegistrationFund}) ADA / ${minRegistrationFund} lovelaces \e[90m"
echo
echo -e "\e[0mTotal Deposit-Value: \e[33m$(convertToADA ${voteActionDepositTotal}) ADA\e[0m"
echo

#calculate new balance for destination address
lovelacesToSend=$(( ${totalLovelaces}-${fee}-${voteActionDepositTotal} ))

echo -e "\e[0mLovelaces that will be returned to payment Address (UTXO-Sum minus fees minus ActionDeposit): \e[32m $(convertToADA ${lovelacesToSend}) ADA / ${lovelacesToSend} lovelaces \e[90m (min. required ${minOutUTXO} lovelaces)"
echo

#Checking about minimum funds in the UTX0
if [[ ${lovelacesToSend} -lt ${minOutUTXO} ]]; then echo -e "\e[91mNot enough funds on the source Addr! Minimum UTXO value is ${minOutUTXO} lovelaces.\e[0m"; exit; fi

txBodyFile="${tempDir}/$(basename ${fromAddr}).txbody"
txWitnessFile="${tempDir}/$(basename ${fromAddr}).txwitness"; rm ${txWitnessFile} 2> /dev/null	#witness for the payment signing
txFile="${tempDir}/$(basename ${fromAddr}).tx"

echo -e "\e[0mBuilding the unsigned transaction body: \e[32m ${txBodyFile} \e[90m"
echo

#Building unsigned transaction body
rm ${txBodyFile} 2> /dev/null

case "${voteActionTag,,}" in

	"treasurywithdrawals"|"parameterchange")	#transaction needs a guardrailsscript

		#Build the transaction with a local plutus reference script
                ${cardanocli} ${cliEra} transaction build-raw \
                        ${txInString} \
                        --tx-in-collateral "${collateralUTXO}" \
                        --tx-out "${sendToAddr}+${lovelacesToSend}${assetsOutString}" \
                        --proposal-script-file "${guardrailsScriptFile}" \
                        --proposal-redeemer-value {} \
                        --proposal-execution-units "${execUnitCosts}" \
                        --protocol-params-file <(echo ${protocolParametersJSON}) \
                        --invalid-hereafter ${ttl} \
                        --fee ${fee} ${metafileParameter} ${actionfileParameter} --out-file ${txBodyFile}
		checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
		;;


	*) #all other kinds of actions
		${cardanocli} ${cliEra} transaction build-raw \
			${txInString} \
			--tx-out "${sendToAddr}+${lovelacesToSend}${assetsOutString}" \
			--invalid-hereafter ${ttl} \
			--fee ${fee} ${metafileParameter} ${actionfileParameter} --out-file ${txBodyFile}
		checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
		;;

esac

dispFile=$(cat ${txBodyFile}); if ${cropTxOutput} && [[ ${#dispFile} -gt 4000 ]]; then echo "${dispFile:0:4000} ... (cropped)"; else echo "${dispFile}"; fi
echo

#If payment address is a hardware wallet, use the cardano-hw-cli for the signing
if [[ -f "${fromAddr}.hwsfile" ]]; then

        echo -ne "\e[0mAutocorrect the TxBody for canonical order: "
        tmp=$(autocorrect_TxBodyFile "${txBodyFile}"); if [ $? -ne 0 ]; then echo -e "\e[91m${tmp}\e[0m\n\n"; exit 1; fi
        echo -e "\e[32m${tmp}\e[90m\n"

        dispFile=$(cat ${txBodyFile}); if ${cropTxOutput} && [[ ${#dispFile} -gt 4000 ]]; then echo "${dispFile:0:4000} ... (cropped)"; else echo "${dispFile}"; fi
        echo

        echo -e "\e[0mSign (Witness+Assemble) the unsigned transaction body with the \e[32m${fromAddr}.hwsfile\e[0m: \e[32m ${txFile}\e[0m"
        echo

        #lets check if its a base payment address, in that case we also need to add the staking.hwsfile to not have a strange hw gui output
        hwWalletReturnStr=""
        stakeFromAddr="$(dirname ${fromAddr})/$(basename ${fromAddr} .payment).staking"
        if [[ -f "${stakeFromAddr}.hwsfile" ]]; then hwWalletReturnStr="--change-output-key-file ${fromAddr}.hwsfile --change-output-key-file ${stakeFromAddr}.hwsfile"; fi

        #Witness and Assemble the TxFile
        start_HwWallet; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
        tmp=$(${cardanohwcli} transaction witness --tx-file ${txBodyFile} --hw-signing-file ${fromAddr}.hwsfile ${hwWalletReturnStr} ${magicparam} --out-file ${txWitnessFile} 2> /dev/stdout)
        if [[ "${tmp^^}" =~ (ERROR|DISCONNECT) ]]; then echo -e "\e[91m${tmp}\e[0m\n"; exit 1; else echo -ne "\e[0mWitnessed ... "; fi
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

        ${cardanocli} ${cliEra} transaction assemble --tx-body-file ${txBodyFile} --witness-file ${txWitnessFile} --out-file ${txFile}
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
        echo -e "Assembled ... \e[32mDONE\e[0m\n";

else

        #read the needed signing keys into ram and sign the transaction
        skeyJSON=$(read_skeyFILE "${fromAddr}.skey"); if [ $? -ne 0 ]; then echo -e "\e[91m${skeyJSON}\e[0m\n"; exit 1; else echo -e "\e[32mOK\e[0m\n"; fi

        echo -e "\e[0mSign the unsigned transaction body with the \e[32m${fromAddr}.skey\e[0m: \e[32m ${txFile}\e[0m"
        echo

        ${cardanocli} ${cliEra} transaction sign --tx-body-file ${txBodyFile} --signing-key-file <(echo "${skeyJSON}") --out-file ${txFile}
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

        #forget the signing keys
        unset skeyJSON

fi

echo -ne "\e[90m"
dispFile=$(cat ${txFile}); if ${cropTxOutput} && [[ ${#dispFile} -gt 4000 ]]; then echo "${dispFile:0:4000} ... (cropped)"; else echo "${dispFile}"; fi
echo

#Do a txSize Check to not exceed the max. txSize value
cborHex=$(jq -r .cborHex < ${txFile})
txSize=$(( ${#cborHex} / 2 ))
maxTxSize=$(jq -r .maxTxSize <<< ${protocolParametersJSON})
if [[ ${txSize} -le ${maxTxSize} ]]; then echo -e "\e[0mTransaction-Size: ${txSize} bytes (max. ${maxTxSize})\n"
                                     else echo -e "\n\e[91mError - ${txSize} bytes Transaction-Size is too big! The maximum is currently ${maxTxSize} bytes.\e[0m\n"; exit 1; fi

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

                                #Get the TxID
                                txID=$(${cardanocli} ${cliEra} transaction txid --output-text --tx-file ${txFile});
                                checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi;

				echo -e "\e[0mYour Action-ID(s):\n"
				for (( tmpCnt=0; tmpCnt<${actionfileCounter}; tmpCnt++ ))
				do
					echo -e "\t\e[0mCIP129: \e[32m$(convert_actionUTXO2Bech ${txID}#${tmpCnt})\e[0m"
					echo -e "\t\e[0mLegacy: \e[32m${txID}#${tmpCnt}\e[0m"
				done
				echo

                                if [[ "${transactionExplorer}" != "" ]]; then echo -e "\e[0mTracking: \e[32m${transactionExplorer}/${txID}\n\e[0m"; fi
                                ;;

        "light")
                                #lightmode submit
                                showProcessAnimation "Submit-Transaction-LightMode: " &
                                txID=$(submitLight "${txFile}");
                                if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[91mERROR - ${txID}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
                                echo -e "\e[0mSubmit-Transaction-LightMode: \e[32mDONE\n"

				echo -e "\e[0mYour Action-ID(s):\n"
				for (( tmpCnt=0; tmpCnt<${actionfileCounter}; tmpCnt++ ))
				do
					echo -e "\t\e[0mCIP129: \e[32m$(convert_actionUTXO2Bech ${txID}#${tmpCnt})\e[0m"
					echo -e "\t\e[0mLegacy: \e[32m${txID}#${tmpCnt}\e[0m"
				done
				echo

                                if [[ "${transactionExplorer}" != "" ]]; then echo -e "\e[0mTracking: \e[32m${transactionExplorer}/${txID}\n\e[0m"; fi
                                ;;


        "offline")
                                #offlinestore
                                #Get the TxID
                                txID=$(${cardanocli} ${cliEra} transaction txid --output-text --tx-file ${txFile});
                                checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi;

				echo -e "\e[0mYour Action-ID(s) will be:\n"
				for (( tmpCnt=0; tmpCnt<${actionfileCounter}; tmpCnt++ ))
				do
					echo -e "\t\e[0mCIP129: \e[32m$(convert_actionUTXO2Bech ${txID}#${tmpCnt})\e[0m"
					echo -e "\t\e[0mLegacy: \e[32m${txID}#${tmpCnt}\e[0m"
				done
				echo

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
                                offlineJSON=$( jq ".history += [ { date: \"$(date -R)\", action: \"signed utxo-transaction from '${fromAddr}' to '${fromAddr}'\" } ]" <<< ${offlineJSON})
                                offlineJSON=$( jq ".general += {offlineCLI: \"${versionCLI}\" }" <<< ${offlineJSON})
                                echo "${offlineJSON}" > ${offlineFile}
                                #Readback the tx content and compare it to the current one
                                readback=$(cat ${offlineFile} | jq -r ".transactions[-1].txJSON")
                                if [[ "${txFileJSON}" == "${readback}" ]]; then
                                                        showOfflineFileInfo;
                                                        echo -e "\e[33mTransaction txJSON has been stored in the '$(basename ${offlineFile})'.\nYou can now transfer it to your online machine for execution.\e[0m\n";
                                                 else
                                                        echo -e "\e[91mERROR - Could not verify the written data in the '$(basename ${offlineFile})'. Retry again or generate a new '$(basename ${offlineFile})'.\e[0m\n";
                                fi
                                ;;

        esac


fi

echo -e "\e[0m\n"
