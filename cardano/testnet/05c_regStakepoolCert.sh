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

Usage:  $(basename $0) <PoolNodeName> <PaymentAddrForRegistration>

	[Opt: force a registration "type: REG", force a re-registration "type: REREG"]
        [Opt: Message comment, starting with "msg: ...", | is the separator]
        [Opt: encrypted message mode "enc:basic". Currently only 'basic' mode is available.]
        [Opt: passphrase for encrypted message mode "pass:<passphrase>", the default passphrase is 'cardano' if not provided]

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

   $(basename $0) myPool myWallet
   -> Register the pool 'myPool' on Chain, Payment via the myWallet wallet

   $(basename $0) myPool myWallet "type: REREG"
   -> Same as above, but force a Re-Registration in case the pool.json was edited and the script is confused

   $(basename $0) myPool myWallet "msg: Pool Registration for pool xxx with wallet myWallet"
   -> Register the pool 'myPool' with the myWallet wallet and adding a Transaction-Message

EOF
exit 1;
fi

#At least 2 parameters were provided, use them
regPayName="$(dirname $2)/$(basename $2 .addr)"; regPayName=${regPayName/#.\//};
poolFile="$(dirname $1)/$(basename $(basename $1 .json) .pool)"; poolFile=${poolFile/#.\//};

#Setting default variables
metafileParameter=""; metafile=""; transactionMessage="{}"; enc=""; passphrase="cardano"; forceParam="" #Setting defaults

#Check all optional parameters about there types and set the corresponding variables
#Starting with the 3th parameter (index=2) up to the last parameter
paramCnt=$#;
allParameters=( "$@" )
for (( tmpCnt=2; tmpCnt<${paramCnt}; tmpCnt++ ))
 do
        paramValue=${allParameters[$tmpCnt]}
        #echo -n "${tmpCnt}: ${paramValue} -> "

        #Check if an additional metadata.json/.cbor was set as parameter (not a Message, not a UTXO#IDX, not empty, not a number)
        if [[ ! "${paramValue,,}" =~ ^msg:(.*)$ ]] && [[ ! "${paramValue,,}" =~ ^enc:(.*)$ ]] && [[ ! "${paramValue,,}" =~ ^pass:(.*)$ ]] && [[ ! "${paramValue,,}" =~ ^type:(.*)$ ]] && [[ ! "${paramValue}" =~ ^([[:xdigit:]]+#[[:digit:]]+(\|?)){1,}$ ]] && [[ ! ${paramValue} == "" ]] && [ -z "${paramValue##*[!0-9]*}" ]; then

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
             else echo -e "\n\e[35mERROR - The specified Metadata JSON/CBOR-File '${metafile}' does not exist. Fileextension must be '.json' or '.cbor' Please try again.\n\nAlso please check the correct syntax, there was a change in a recent version\nfor example to specify the registration-type is now done via \"type: REG\" or \"type: REREG\".\n\n\e[0m"; exit 1;
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

        #Check if its a registration type "type: REG" or "type: REREG"
        elif [[ "${paramValue,,}" =~ ^type:(.*)$ ]]; then #if the parameter starts with "type:" then set the variable
		forceParam=$(trimString "${paramValue:5}"); forceParam=${forceParam^^}
		if [[ "${forceParam}" != "REG" ]] && [[ "${forceParam}" != "REREG" ]]; then
			echo -e "\n\e[35mRegistartion-Type-ERROR: \"${forceParam}\" is not a supported type, please choose 'REG' or 'REREG'!\n\e[0m"; exit 1;
		fi

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

                echo "${tmp}" > ${transactionMessageMetadataFile}; metafileParameter="${metafileParameter}--metadata-json-file ${transactionMessageMetadataFile} "; metafileList="${metafileList}'${transactionMessageMetadataFile}' " #add it to the list of metadata.jsons to attach

        else
                echo -e "\n\e[35mERROR - Additional Transaction Message-Metafile is not valid:\n\n$${transactionMessage}\n\nPlease check your added Message-Paramters.\n\e[0m"; exit 1;
        fi

fi



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
elif [[ "${param}" == null ]]; then echo -e "ERROR - Parameter \"$1\" in ${poolFile}.pool.json does not exist.\n\nDid you run script '\e[33m./05a_genStakepoolCert.sh ${poolFile}\e[0m' again after you've edited the ${poolFile}.pool.json file?\nIf not, please rerun it to complete the json generation, thx!\n" >&2; exit 1;
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
poolIDbech=$(readJSONparam "poolIDbech"); if [[ ! $? == 0 ]]; then exit 1; fi
regProtectionKey=$(jq -r .regProtectionKey <<< ${poolJSON} 2> /dev/null); if [[ "${regProtectionKey}" == null ]]; then regProtectionKey=""; fi

#Checks for needed local files
if [ ! -f "${regCertFile}" ]; then echo -e "\n\e[35mERROR - \"${regCertFile}\" StakePool (Re)registration-Certificate does not exist or was already submitted before!\n\nPlease create it by running script:\e[0m 05a_genStakepoolCert.sh ${poolFile}\n"; exit 1; fi
if [ ! -f "${poolName}.node.vkey" ]; then echo -e "\n\e[35mERROR - \"${poolName}.node.vkey\" does not exist! Please create it first with script 04a.\e[0m"; exit 1; fi
if ! [[ -f "${poolName}.node.skey" || -f "${poolName}.node.hwsfile" ]]; then echo -e "\n\e[35mERROR - \"${poolName}.node.skey/hwsfile\" does not exist! Please create it first with script 04a.\e[0m"; exit 1; fi
if [ ! -f "${regPayName}.addr" ]; then echo -e "\n\e[35mERROR - \"${regPayName}.addr\" does not exist! Please create it first with script 03a or 02.\e[0m"; exit 1; fi
if [ ! -f "${regPayName}.skey" ]; then echo -e "\n\e[35mERROR - \"${regPayName}.skey\" does not exist! Please create it first with script 03a or 02. No hardware-wallet allowed for poolRegistration payments! :-(\e[0m\n"; exit 1; fi


#Load regSubmitted value from the pool.json. If there is an entry, than do a Re-Registration (changes the Fee!)
regSubmitted=$(jq -r .regSubmitted <<< ${poolJSON} 2> /dev/null); if [[ "${regSubmitted}" == null ]]; then regSubmitted=""; fi

#SO, now only do the following stuff the first time when no witnesscollection exists -> starting a new poolregistration/poolderegistration. No change possible after witnesscollection opening
if [[ "${regWitnessID}" == "" ]]; then

	#Add the node witness and payment witness at first entries
	poolJSON=$(jq ".regWitness.witnesses.\"${poolName}.node\".witness = {}" <<< ${poolJSON});
	poolJSON=$(jq ".regWitness.witnesses.\"${regPayName}\".witness = {}" <<< ${poolJSON});

	#Force registration instead of re-registration via optional command line command "type: REG"
	#Force re-registration instead of registration via optional command line command "type: REREG"
	if [[ "${forceParam}" == "" ]]; then

		deregSubmitted=$(jq -r .deregSubmitted <<< ${poolJSON} 2> /dev/null); if [[ ! "${deregSubmitted}" == null ]]; then echo -e "\n\e[35mERROR - I'am confused, the pool was registered and retired before. Please specify if you wanna register or reregister the pool now with the optional parameter "type:REG" or "type:REREG" !\e[0m\n"; exit 1; fi

		#In Online-Mode check if the Pool is already registered on the chain, if so print an info that the method was forced to a REREG
		if ${onlineMode}; then

			case ${workMode} in

		                "online")

		                        #check that the node is fully synced, otherwise the opcertcounter query could return a false state
		                        if [[ $(get_currentSync) != "synced" ]]; then echo -e "\e[35mError - Node not fully synced !\e[0m\n"; exit 1; fi

		                        #check ledger-state via the local node
		                        showProcessAnimation "Query-Ledger-State: " &
		                        poolsInLedger=$(${cardanocli} ${cliEra} query stake-pools 2> /dev/null); if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\n\e[35mERROR - Could not query stake-pools from the chain.\e[0m\n"; exit 1; fi
		                        stopProcessAnimation;

		                        #now lets see how often the poolIDbech is listed: 0->Not on the chain, 1->On the chain, any other value -> ERROR
		                        poolInLedgerCnt=$(grep  "${poolIDbech}" <<< ${poolsInLedger} | wc -l)
					if [[ ${poolInLedgerCnt} -eq 1 ]]; then echo -e "Info via Local-Node: Pool-ID is already on the chain, continue with a Re-Registration\e[0m\n"; regSubmitted="xxx";
					elif [[ ${poolInLedgerCnt} -eq 0 ]]; then echo -e "Info via Local-Node: Pool-ID is not on the chain (yet), continue with a normal Registration\e[0m\n"; regSubmitted="";
					else echo -e "\e[35mERROR - The Pool-ID '${poolIDbech}' is more than once in the ledgers stake-pool list, this shouldn't be possible!\e[0m\n"; exit 1;
		                        fi
		                        ;;

		                "light")

					#query poolinfo via poolid on koios -> this is just to have a nice output about the pool we wanna delegate to. if koios is down or so, it doesn't matter in online(full) mode
					error=0
					if [[ "${koiosAPI}" != "" ]]; then

					        errorcnt=0
					        error=-1
					        showProcessAnimation "Query Pool-Info via Koios: " &
					        while [[ ${errorcnt} -lt 5 && ${error} -ne 0 ]]; do #try a maximum of 5 times to request the information via koios API
					                error=0
					                response=$(curl -sL -m 30 -X POST -w "---spo-scripts---%{http_code}" "${koiosAPI}/pool_info"  -H "${koiosAuthorizationHeader}" -H "Accept: application/json" -H "Content-Type: application/json" -d "{\"_pool_bech32_ids\":[\"${poolIDbech}\"]}" 2> /dev/null)
					                if [ $? -ne 0 ]; then error=1; fi;
					                errorcnt=$(( ${errorcnt} + 1 ))
					        done
					        stopProcessAnimation;
			                        if [[ ${error} -ne 0 ]]; then echo -e "\e[33mQuery of the Pool-Status via Koios-API failed, tried 5 times.\e[0m\n"; fi; #curl query failed

					        #Split the response string into JSON content and the HTTP-ResponseCode
					        if [[ "${response}" =~ (.*)---spo-scripts---([0-9]*)* ]]; then
					                responseJSON="${BASH_REMATCH[1]}"
					                responseCode="${BASH_REMATCH[2]}"
					        fi

					        if [[ ${error} -eq 0 && ${responseCode} -eq 200 ]]; then
					                #check if the received json only contains one entry in the array (will also not be 1 if not a valid json)
					                if [[ $(jq ". | length" 2> /dev/null <<< ${responseJSON}) -eq 1 ]]; then
					                        { read poolNameInfo; read poolTickerInfo; read poolStatusInfo; } <<< $(jq -r "(.[0].meta_json.name | select (.!=null)), (.[0].meta_json.ticker | select (.!=null)), (.[0].pool_status | select (.!=null))" 2> /dev/null <<< ${responseJSON})
					                        echo -e "\e[0mName (Ticker): \e[32m${poolNameInfo} (${poolTickerInfo})\e[0m"
					                        echo

					                        case "${poolStatusInfo^^}" in
					                                "REGISTERED")   echo -e "\e[0mInfo via Koios-API: \e[32mPool is REGISTERED on the chain, continue with a Re-Registration.\e[0m\n"; regSubmitted="xxx";;
					                                "RETIRED")      echo -e "\e[0mInfo via Koios-API: \e[33mPool was RETIRED and is currently NOT registered on the chain. Lets do a registration.\e[0m\n"; regSubmitted="";;
					                                "RETIRING")     retiringEpoch=$(jq -r ".[0].retiring_epoch | select (.!=null)" 2> /dev/null <<< ${responseJSON})
					                                                echo -e "\e[0mInfo via Koios-API: \e[36mPool will RETIRE in epoch ${retiringEpoch}, currently REGISTERED.\e[0m Continue with a Re-Registration.\e[0m\n"; regSubmitted="xxx";;
					                                *) echo -e "\e[0mInfo via Koios-API: Pool-Status is ${poolStatusInfo^^}\e[0m\n";;
					                        esac

					                else
					                        echo -e "\e[0mInfo via Koios-API: \e[33mPool is NOT registered on the chain, never was. Lets do a registration.\e[0m\n"; regSubmitted="";
					                fi
					        fi

					unset poolNameInfo poolTickerInfo poolStatusInfo responseJSON responseCode error errorcnt

					fi #koiosAPI!=""
		                        ;;

			esac #workmode

		fi #onlinemode

	elif [[ "${forceParam^^}" == "REG" ]]; then regSubmitted="";  	#force a new registration
	elif [[ "${forceParam^^}" == "REREG" ]]; then regSubmitted="xxx";	#force a re-registration
	fi

else #WitnessID and data already in the poolJSON
	storedRegPayName=$(jq -r .regWitness.regPayName <<< ${poolJSON}) #load data from already started witness collection

	if [[ ! "${forceParam}" == "" ]]; then #if a force parameter was given but there is already a witness in the poolJSON, exit with an error, not allowed, you have to start a new witness
                echo -e "\e[35mERROR - You already started a witness collection. If you wanna change the Registration-Type (reg or rereg) now,\nyou have to start all over again by running:\e[33m 05d_poolWitness.sh clear ${poolFile}\e[35m\n\nIf you just wanna complete your started poolRegistration run:\e[33m 05c_regStakepoolCert ${poolFile} ${storedRegPayName}\n\e[35mwithout the REG or REREG keyword. :-)\e[0m\n";
		exit 1;
	fi

	if [[ ! "${metafileParameter}" == "" ]]; then #if a metadatafile was given or a transaction message was added and there is already a witness in the poolJSON, exit with an error, not allowed, you have to start a new witness
                echo -e "\e[35mERROR - You already started a witness collection. If you wanna add metadata (JSON/CBOR/Messages) now,\nyou have to start all over again by running:\e[33m 05d_poolWitness.sh clear ${poolFile}\e[35m\n\nIf you just wanna complete your started poolRegistration run:\e[33m 05c_regStakepoolCert ${poolFile} ${storedRegPayName}\n\e[35mwithout the REG or REREG keyword. :-)\e[0m\n";
		exit 1;
	fi

fi

ownerCnt=$(jq -r '.poolOwner | length' <<< ${poolJSON})
certCnt=$(( ${ownerCnt} + 1 ))	#Total number of needed certificates: poolRegistrationCertificate and every poolOwnerDelegationCertificate
registrationCerts="--certificate ${regCertFile}" #list of all needed certificates: poolRegistrationCertificat and every poolOwnerDelegationCertificate
witnessCount=2	#Total number of needed witnesses: poolnode skey/hwsfile, registration payment skey/hwsfile + each owner witness + maybe rewards account witness

#Preload the hardwareWalletIncluded variable, if we provide the node cold key via a hw-wallet, than set the hardwareWalletIncluded=yes. Otherwise pretend no until a hw-owner is found.
if [ -f "${poolName}.node.hwsfile" ]; then hardwareWalletIncluded="yes"; else hardwareWalletIncluded="no"; fi

#Generate the PoolID so we can compare it with the ones in the delegation certificates
poolIDhex=$(${cardanocli} ${cliEra} stake-pool id --cold-verification-key-file ${poolName}.node.vkey --output-hex)
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

#Lets first count all needed witnesses and check about the delegation certificates
for (( tmpCnt=0; tmpCnt<${ownerCnt}; tmpCnt++ ))
do

	ownerName=$(jq -r .poolOwner[${tmpCnt}].ownerName <<< ${poolJSON})
	witnessCount=$(( ${witnessCount} + 1 )) #Every owner is of course also needed as witness
	if [ ! -f "${ownerName}.staking.vkey" ]; then echo -e "\e[35mERROR - \"${ownerName}.staking.vkey\" is missing! Check poolOwner/ownerName field in ${poolFile}.pool.json, or generate one with script 03a !\e[0m"; exit 1; fi
	if [[ "$(jq -r .description < ${ownerName}.staking.vkey)" == *"Hardware"* ]]; then hardwareWalletIncluded="yes"; fi
	if [ ! -f "${ownerName}.deleg.cert" ]; then echo -e "\e[35mERROR - \"${ownerName}.deleg.cert\" does not exist! Please create it first with script 05b.\e[0m"; exit 1; fi

	#Check each delegation certificate of the owners that they are really delegating to this pool id
	#Extracting infos directly from the delegation certificate
	delegCBOR=$(jq -r ".cborHex" < "${ownerName}.deleg.cert" 2> /dev/null)
	delegPoolID=${delegCBOR: -56}
	if [[ "${delegPoolID}" != "${poolIDhex}" ]]; then echo -e "\e[35mERROR - \"${ownerName}.deleg.cert\" is not delegating to this Pool-ID: \e[32m${poolIDhex}\n\e[35mIts currently set to delegate to a pool with Pool-ID: \e[32m${delegPoolID}\n\n\e[35mPlease correct it by running script 05b like: \e[33m05b_genDelegationCert.sh ${poolName} ${ownerName}\n\e[0m"; exit 1; fi

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
currentTip=$(get_currentTip); checkError "$?";
currentEPOCH=$(get_currentEpoch); checkError "$?";

if [[ "${regWitnessID}" == "" ]]; then #New witness collection
	ttl=$(( ${currentTip} + ${defTTL} ))
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


if [[ "${regSubmitted}" == "" ]]; then  #pool not registered before -> registration
	echo -e "\e[0mRegister new StakePool Certificate\e[32m ${regCertFile}\e[0m and Owner-Delegations with funds from Address\e[32m ${regPayName}.addr\e[0m:"
	echo
				  else	#pool was registered before -> re-registration
	echo -e "\e[0mRe-Register StakePool Certificate\e[32m ${regCertFile}\e[0m and Owner-Delegations with funds from Address\e[32m ${regPayName}.addr\e[0m:"
	echo
fi

if ${onlineMode}; then

	#Check if the regProtectionKey is correct, this is a service to not have any duplicated Tickers on the Chain. If you know how to code you can see that it is easy, just a little protection for Noobs
	echo -ne "\e[0m\x54\x69\x63\x6B\x65\x72\x20\x50\x72\x6F\x74\x65\x63\x74\x69\x6F\x6E\x20\x43\x68\x65\x63\x6B\x20\x66\x6F\x72\x20\x54\x69\x63\x6B\x65\x72\x20'\e[32m${poolMetaTicker}\e[0m': "
	checkResult=$(curl -L -m 20 -s $(echo -e "\x68\x74\x74\x70\x73\x3A\x2F\x2F\x6D\x79\x2D\x69\x70\x2E\x61\x74\x2F\x63\x68\x65\x63\x6B\x74\x69\x63\x6B\x65\x72\x3F\x74\x69\x63\x6B\x65\x72\x3D${poolMetaTicker}&key=${regProtectionKey}") );
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
	tmpMetadataJSON="${tempDir}/tmpmetadata.json"
	curl -sL "${poolMetaUrl}" --output "${tmpMetadataJSON}"
	if [[ $? -ne 0 ]]; then echo -e "\e[33mERROR, can't fetch the metadata file from the webserver!\e[0m\n"; exit 1; fi
	#Check the downloaded data that is a valid JSON file
	tmpCheckJSON=$(jq . "${tmpMetadataJSON}" 2> /dev/null)
	if [[ $? -ne 0 ]]; then echo -e "\e[33mERROR - Not a valid JSON file on the webserver!\e[0m\n"; exit 1; fi
	#Ok, downloaded file is a valid JSON file. So now look into the HASH
	onlineMetaHash=$(${cardanocli} ${cliEra} stake-pool metadata-hash --pool-metadata-file "${tmpMetadataJSON}")
	checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
	#Compare the HASH now, if they don't match up, output an ERROR message and exit
	if [[ ! "${poolMetaHash}" == "${onlineMetaHash}" ]]; then
		echo -e "\e[33mERROR - HASH mismatch!\n\nPlease make sure to upload your MetaData JSON file correctly to your webserver!\nPool-Registration aborted! :-(\e[0m\n";
	        echo -e "Your local \e[32m${poolFile}.metadata.json\e[0m with HASH \e[32m${poolMetaHash}\e[0m:\n"
		echo -e "--- BEGIN LOCAL FILE ---"
		cat "${poolFile}.metadata.json"
	        echo -e "--- END LOCAL FILE ---\n\n"
	        echo -e "Your remote file at \e[32m${poolMetaUrl}\e[0m with HASH \e[32m${onlineMetaHash}\e[0m:\n"
	        echo -e "--- BEGIN REMOTE FILE ---\e[35m"
	        cat "${tmpMetadataJSON}"
	        echo -e "\e[0m--- END REMOTE FILE ---"
		echo -e "\e[0m\n"
		exit 1;
	else echo -e "\e[32mOK\e[0m\n"; fi
	#Ok, HASH is the same, continue
	rm ${tmpMetadataJSON} 2> /dev/null

fi; #onlinemode

#Read ProtocolParameters
case ${workMode} in
        "online")       protocolParametersJSON=$(${cardanocli} ${cliEra} query protocol-parameters);; #onlinemode
        "light")        protocolParametersJSON=${lightModeParametersJSON};; #lightmode
        "offline")      readOfflineFile;
			protocolParametersJSON=$(jq ".protocol.parameters" <<< ${offlineJSON});; #offlinemode
esac
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
echo -e "\e[0m             Pledge:\e[32m ${poolPledge} \e[90mlovelaces \e[0m(\e[32m$(convertToADA ${poolPledge}) \e[90mADA\e[0m)"
echo -e "\e[0m               Cost:\e[32m ${poolCost} \e[90mlovelaces \e[0m(\e[32m$(convertToADA ${poolCost}) \e[90mADA\e[0m)"
poolMarginPct=$(bc <<< "${poolMargin} * 100" 2> /dev/null)
echo -e "\e[0m             Margin:\e[32m ${poolMargin} \e[0m(\e[32m${poolMarginPct}%\e[0m)"
echo
echo -e "\e[0m      Current EPOCH:\e[32m ${currentEPOCH}\e[0m"
echo -e "\e[0mCurrent Slot-Height:\e[32m ${currentTip}\e[0m (set TTL[invalid_hereafter] to ${ttl})"

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

        #Get UTX0 Data for the address. When in online mode of course from the node and the chain, in lightmode via API requests, in offlinemode from the transferFile
        case ${workMode} in
                "online")       #check that the node is fully synced, otherwise the query would mabye return a false state
                                if [[ $(get_currentSync) != "synced" ]]; then echo -e "\e[35mError - Node not fully synced or not running, please let your node sync to 100% first !\e[0m\n"; exit 1; fi
                                showProcessAnimation "Query-UTXO: " &
                                utxo=$(${cardanocli} ${cliEra} query utxo --output-text --address ${sendFromAddr} 2> /dev/stdout);
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
	if [[ ${txcnt} == 0 ]]; then echo -e "\e[35mNo funds on the Source Address!\e[0m\n"; exit; else echo -e "\e[32m${txcnt} UTXOs\e[0m found on the Source Address!\n"; fi

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

minOutUTXO=$(calc_minOutUTXO "${protocolParametersJSON}" "${sendToAddr}+1000000${assetsOutString}")

#------------------------------------------------------------------

#Generate Dummy-TxBody file for fee calculation
txBodyFile="${tempDir}/dummy.txbody"
rm ${txBodyFile} 2> /dev/null
${cardanocli} ${cliEra} transaction build-raw ${txInString} --tx-out "${sendToAddr}+${totalLovelaces}${assetsOutString}" --invalid-hereafter ${ttl} --fee 200000 ${metafileParameter} ${registrationCerts} --out-file ${txBodyFile}
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

#calculate the transaction fee. new parameters since cardano-cli 8.21.0
fee=$(${cardanocli} ${cliEra} transaction calculate-min-fee --output-text --tx-body-file ${txBodyFile} --protocol-params-file <(echo ${protocolParametersJSON}) --witness-count ${witnessCount} --reference-script-size 0 2> /dev/stdout)
if [ $? -ne 0 ]; then echo -e "\n\e[35m${fee}\e[0m\n"; exit 1; fi
fee=${fee%% *} #only get the first part of 'xxxxxx Lovelaces'

echo -e "\e[0mMinimum transfer Fee for ${txcnt}x TxIn & ${rxcnt}x TxOut & ${certCnt}x Certificate: \e[32m $(convertToADA ${fee}) ADA / ${fee} lovelaces \e[90m"

#Check if pool was registered before and calculate Fee for registration or set it to zero for re-registration
if [[ "${regSubmitted}" == "" ]]; then   #pool not registered before
				  poolDepositFee=$(jq -r .stakePoolDeposit <<< ${protocolParametersJSON})
				  echo -e "\e[0mPool Deposit Fee: \e[32m${poolDepositFee} lovelaces \e[90m"
				  minRegistrationFees=$(( ${poolDepositFee}+${fee} ))
				  registrationType="PoolRegistration"
				  echo
				  echo -e "\e[0mMinimum funds required for registration (Sum of fees): \e[32m $(convertToADA ${minRegistrationFees}) ADA / ${minRegistrationFees} lovelaces \e[90m"
				  echo
				  else   #pool was registered before -> reregistration -> no poolDepositFee
				  poolDepositFee=0
				  echo -e "\e[0mNo Pool Deposit Fee: \e[32mReRegistration (PoolUpdate) \e[90m"
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
${cardanocli} ${cliEra} transaction build-raw ${txInString} --tx-out "${sendToAddr}+${lovelacesToSend}${assetsOutString}" --invalid-hereafter ${ttl} --fee ${fee} ${metafileParameter} ${registrationCerts} --out-file ${txBodyFile}
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

dispFile=$(cat ${txBodyFile}); if ${cropTxOutput} && [[ ${#dispFile} -gt 4000 ]]; then echo "${dispFile:0:4000} ... (cropped)"; else echo "${dispFile}"; fi
echo

#If a hardware wallet is involved, do the autocorrection of the TxBody to make sure it is in canonical order for the assets
if [[ "${hardwareWalletIncluded}" == "yes" ]]; then
        echo -ne "\e[0mAutocorrect the TxBody for canonical order: "
        tmp=$(autocorrect_TxBodyFile "${txBodyFile}"); if [ $? -ne 0 ]; then echo -e "\e[35m${tmp}\e[0m\n\n"; exit 1; fi
        echo -e "\e[32m${tmp}\e[90m\n"

	dispFile=$(cat ${txBodyFile}); if ${cropTxOutput} && [[ ${#dispFile} -gt 4000 ]]; then echo "${dispFile:0:4000} ... (cropped)"; else echo "${dispFile}"; fi
	echo
fi

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
poolJSON=$(jq ".regWitness.metadataFilesList = \"${metafileList}\"" <<< ${poolJSON})

#Fill the witness count with the node-coldkey witness
if [ -f "${poolName}.node.skey" ]; then #key is a normal one

        #read the needed signing keys into ram
        skeyJSON=$(read_skeyFILE "${poolName}.node.skey"); if [ $? -ne 0 ]; then echo -e "\e[35m${skeyJSON}\e[0m\n"; exit 1; else echo -e "\e[32mOK\e[0m\n"; fi

	echo -ne "\e[0mAdding the pool node witness '\e[33m${poolName}.node.skey\e[0m' ... "
	tmpWitness=$(${cardanocli} ${cliEra} transaction witness --tx-body-file ${txBodyFile} --signing-key-file <(echo "${skeyJSON}") --out-file /dev/stdout)
	checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
	echo -e "\e[32mOK\n"

        #forget the signing keys
        unset skeyJSON

	poolJSON=$(jq ".regWitness.witnesses.\"${poolName}.node\".witness = ${tmpWitness}" <<< ${poolJSON}); #include the witnesses in the poolJSON if its a new collection

elif [ -f "${poolName}.node.hwsfile" ]; then #key is a hardware wallet

        if ! ask "\e[0mAdding the pool node witness from a local Hardware-Wallet key '\e[33m${poolName}\e[0m', continue?" Y; then echo; echo -e "\e[35mABORT - Witness Signing aborted...\e[0m"; echo; exit 2; fi

	tmpWitnessFile="${tempDir}/$(basename ${poolName}).tmp.witness"
	#this is currently only supported by ledger devices
        start_HwWallet "Ledger|Keystone"; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
        tmp=$(${cardanohwcli} transaction witness --tx-file ${txBodyFile} --hw-signing-file ${poolName}.node.hwsfile ${magicparam} --out-file ${tmpWitnessFile} 2> /dev/stdout)
        if [[ "${tmp^^}" =~ (ERROR|DISCONNECT) ]]; then echo -e "\e[35m${tmp}\e[0m\n"; exit 1; else echo -e "\e[32mDONE\e[0m"; fi
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
        tmpWitness=$(cat ${tmpWitnessFile})
	poolJSON=$(jq ".regWitness.witnesses.\"${poolName}.node\".witness = ${tmpWitness}" <<< ${poolJSON}); #include the witnesses in the poolJSON if its a new collection

else

	echo -e "\e[35mError - Node Cold Signing Key for \"${poolName}\" not found. No ${poolName}.node.skey/hwsfile file found !\e[0m\n"; exit 1;

fi

#Fill the witnesses with the local payment witness, must be a normal cli skey

	#read the needed signing keys into ram
        skeyJSON=$(read_skeyFILE "${regPayName}.skey"); if [ $? -ne 0 ]; then echo -e "\e[35m${skeyJSON}\e[0m\n"; exit 1; else echo -e "\e[32mOK\e[0m\n"; fi

	echo -ne "\e[0mAdding the payment witness from a local payment address '\e[33m${regPayName}.skey\e[0m' ... "
	tmpWitness=$(${cardanocli} ${cliEra} transaction witness --tx-body-file ${txBodyFile} --signing-key-file <(echo "${skeyJSON}") --out-file /dev/stdout)
	checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
	echo -e "\e[32mOK\n"

        #forget the signing keys
        unset skeyJSON

	poolJSON=$(jq ".regWitness.witnesses.\"${regPayName}\".witness = ${tmpWitness}" <<< ${poolJSON}); #include the witness in the poolJSON if its a new collection

#Fill the witnesses with the local owner accounts, if you wanna do this in multiple steps you should set ownerWitness: "external" in the pool.json
for (( tmpCnt=0; tmpCnt<${ownerCnt}; tmpCnt++ ))
do

  ownerName=$(jq -r .poolOwner[${tmpCnt}].ownerName <<< ${poolJSON})
  ownerWitness=$(jq -r .poolOwner[${tmpCnt}].ownerWitness <<< ${poolJSON});

  if [[ "${ownerWitness}" == null || "${ownerWitness}" == "" || "${ownerWitness^^}" == "LOCAL" ]]; then #local account process now

    if [[ $(jq ".regWitness.witnesses.\"${ownerName}.staking\".witness | length" <<< ${poolJSON}) == 0 ]]; then #only process witness if the entry in the witness collection is empty

	#Fill the witnesses with the local owner witness
	if [ -f "${ownerName}.staking.skey" ]; then #key is a normal one

	        #read the needed signing keys into ram
	        skeyJSON=$(read_skeyFILE "${ownerName}.staking.skey"); if [ $? -ne 0 ]; then echo -e "\e[35m${skeyJSON}\e[0m\n"; exit 1; else echo -e "\e[32mOK\e[0m\n"; fi

	        echo -ne "\e[0mAdding the owner witness from a local signing key '\e[33m${ownerName}.skey\e[0m' ... "
	        tmpWitness=$(${cardanocli} ${cliEra} transaction witness --tx-body-file ${txBodyFile} --signing-key-file <(echo "${skeyJSON}") --out-file /dev/stdout)
	        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
		echo -e "\e[32mOK\n"

	        #forget the signing keys
	        unset skeyJSON

	        poolJSON=$(jq ".regWitness.witnesses.\"${ownerName}.staking\".witness = ${tmpWitness}" <<< ${poolJSON}); #include the witnesses in the poolJSON

	elif [ -f "${ownerName}.staking.hwsfile" ]; then #key is a hardware wallet
	        tmpWitnessFile="${tempDir}/$(basename ${poolName}).tmp.witness"
		if ! ask "\e[0mAdding the owner witness from a local Hardware-Wallet key '\e[33m${ownerName}\e[0m', continue?" Y; then echo; echo -e "\e[35mABORT - Witness Signing aborted...\e[0m"; echo; exit 2; fi

		start_HwWallet; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
		tmp=$(${cardanohwcli} transaction witness --tx-file ${txBodyFile} --hw-signing-file ${ownerName}.staking.hwsfile ${magicparam} --out-file ${tmpWitnessFile} 2> /dev/stdout)

	        if [[ "${tmp^^}" =~ (ERROR|DISCONNECT) ]]; then echo -e "\e[35m${tmp}\e[0m\n"; exit 1; else echo -e "\e[32mDONE\e[0m"; fi
	        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

		tmpWitness=$(cat ${tmpWitnessFile})

	        poolJSON=$(jq ".regWitness.witnesses.\"${ownerName}.staking\".witness = ${tmpWitness}" <<< ${poolJSON}); #include the witnesses in the poolJSON

	else
	echo -e "\e[35mError - Owner Signing Key for \"${ownerName}\" not found. No ${ownerName}.staking.skey/hwsfile found !\e[0m\n"; exit 1;
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
# witness collection with the local files/hardware wallets was collected and written into the poolJSON
# we land here also if a witness was created before

regWitnessID=$(jq -r ".regWitness.id" <<< ${poolJSON})
regWitnessDate=$(date --date="@${regWitnessID}" -R)
regWitnessType=$(jq -r ".regWitness.type" <<< ${poolJSON})
regWitnessTxBody=$(jq -r ".regWitness.txBody" <<< ${poolJSON})
regWitnessHardwareWalletIncluded=$(jq -r ".regWitness.hardwareWalletIncluded" <<< ${poolJSON})
regWitnessPayAmount=$(jq -r ".regWitness.regPayAmount" <<< ${poolJSON})
regWitnessPayReturn=$(jq -r ".regWitness.regPayReturn" <<< ${poolJSON})
regWitnessMetadataFilesList=$(jq -r ".regWitness.metadataFilesList" <<< ${poolJSON})

echo
echo -e "Lovelaces you have to pay: \e[32m $(convertToADA ${regWitnessPayAmount}) ADA / ${regWitnessPayAmount} lovelaces\e[0m"
echo -e " Lovelaces to be returned: \e[32m $(convertToADA ${regWitnessPayReturn}) ADA / ${regWitnessPayReturn} lovelaces\e[0m"
echo
echo -e "\e[0mThis will be a: \e[32m${regWitnessType}\e[0m";
echo

#If there are metadata file(s) included, list them:
if [[ ! "${regWitnessMetadataFilesList}" == "" ]]; then echo -e "\e[0mIncluded Metadata-File(s):\e[32m ${regWitnessMetadataFilesList}\e[0m\n"; fi

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
        extWitness=$(jq . <<< "{ \"id\": ${regWitnessID}, \"date-created\": \"${regWitnessDate}\", \"ttl\": ${ttl}, \"type\": \"${regWitnessType}\", \"metadataFilesList\": \"${regWitnessMetadataFilesList}\", \"poolFile\": \"${poolFile}\", \"poolMetaTicker\": \"${poolMetaTicker}\", \"signing-name\": \"${witnessName}\", \"signing-vkey\": $(cat ${witnessName}.vkey), \"txBody\": ${regWitnessTxBody}, \"signedWitness\": {}, \"date-signed\": {} }")
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
txBodyFile="${tempDir}/$(basename ${poolName}).txbody"
echo "${regWitnessTxBody}" > ${txBodyFile}

echo -e "\e[0mAssemble the Transaction with the payment \e[32m${regPayName}.skey\e[0m, node\e[32m ${poolName}.node.skey/hwsfile\e[0m and all PoolOwner Witnesses: \e[32m ${txFile} \e[90m"
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

${cardanocli} ${cliEra} transaction assemble --tx-body-file ${txBodyFile} ${witnessString} --out-file ${txFile}
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

#Do temporary witness file cleanup
for (( tmpCnt=0; tmpCnt<${witnessCnt}; tmpCnt++ ))
do
  tmpWitnessFile="${tempDir}/$(basename ${poolName}).witness_${tmpCnt}.tx"
  rm -f ${tmpWitnessFile}
done

#Read out the POOL-ID
poolIDhex=$(${cardanocli} ${cliEra} stake-pool id --cold-verification-key-file ${poolName}.node.vkey --output-hex)	#New method since 1.23.0
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

poolIDbech=$(${cardanocli} ${cliEra} stake-pool id --cold-verification-key-file ${poolName}.node.vkey --output-bech32)      #New method since 1.23.0
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

echo -e "\e[0mPool-ID:\e[32m ${poolIDhex} / ${poolIDbech} \e[90m"
echo

#Show a warning to respect the pledge amount
if [[ ${poolPledge} -gt 0 ]]; then echo -e "\e[35mATTENTION - You're registered Pledge will be set to $(convertToADA ${poolPledge}) ADA, please respect it with the sum of all registered owner addresses!\e[0m\n"; fi

#Show a message about the registration type
echo -e "\e[0mThis will be a: \e[32m${regWitnessType}\e[0m\n";
offlineRegistrationType="${regWitnessType}"; #Just as Type info for the offline file, same as the regWitnessType

if ask "\e[33mDoes this look good for you? Do you have enough pledge in your owner account(s), continue and register on chain ?" N; then

        echo

        case ${workMode} in

	        "online")
				#onlinesubmit
			        echo -ne "\e[0mSubmitting the transaction via the node... "
			        ${cardanocli} ${cliEra} transaction submit --tx-file ${txFile}
			        #If no error, update the pool JSON file with the date and file the certFile was registered on the blockchain
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

                                #Show the TxID
                                txID=$(${cardanocli} ${cliEra} transaction txid --output-text --tx-file ${txFile}); echo -e "\e[0m TxID is: \e[32m${txID}\e[0m"
                                checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi;
                                if [[ "${transactionExplorer}" != "" ]]; then echo -e "\e[0mTracking: \e[32m${transactionExplorer}/${txID}\n\e[0m"; fi

				#Display information to manually register the OwnerDelegationCertificates on the chain if a hardware-wallet is involved. With only cli based staking keys, we can include all the delegation certificates in one transaction
				if [[ "${regWitnessHardwareWalletIncluded}" == "yes" ]]; then
				        echo -e "\n\e[33mThere is at least one Hardware-Wallet involved, so you have to register the DelegationCertificate for each Owner in additional transactions after the ${regWitnessType} !\e[0m\n"; fi
				;;


	        "light")
                                #lightmode submit
                                showProcessAnimation "Submit-Transaction-LightMode: " &
                                txID=$(submitLight "${txFile}");
			        #If no error, update the pool JSON file with the date and file the certFile was registered on the blockchain
			        if [[ $? -eq 0 ]]; then
					stopProcessAnimation;
				        file_unlock ${poolFile}.pool.json
				        newJSON=$(cat ${poolFile}.pool.json | jq ". += {regEpoch: \"${currentEPOCH}\"}" | jq ". += {regSubmitted: \"$(date -R)\"}" | jq "del (.regWitness)")
				        echo "${newJSON}" > ${poolFile}.pool.json
				        file_lock ${poolFile}.pool.json
	                                echo -e "\e[0mSubmit-Transaction-LightMode: \e[32mDONE\n"

					#Delete the just used RegistrationCertificat so it can't be submitted again as a mistake, build one again with 05a first
					file_unlock ${regCertFile}
					rm ${regCertFile}
			        else
					stopProcessAnimation;
				        echo -e "\n\n\e[35mERROR (Code $?) !\e[0m"; exit 1;
			        fi

                                echo
                                echo -e "\e[0mStakepool Info JSON:\e[32m ${poolFile}.pool.json \e[90m"
                                cat ${poolFile}.pool.json
                                echo

                                #Show the TxID
                                if [[ "${transactionExplorer}" != "" ]]; then echo -e "\e[0mTracking: \e[32m${transactionExplorer}/${txID}\n\e[0m"; fi

				#Display information to manually register the OwnerDelegationCertificates on the chain if a hardware-wallet is involved. With only cli based staking keys, we can include all the delegation certificates in one transaction
				if [[ "${regWitnessHardwareWalletIncluded}" == "yes" ]]; then
				        echo -e "\n\e[33mThere is at least one Hardware-Wallet involved, so you have to register the DelegationCertificate for each Owner in additional transactions after the ${regWitnessType} !\e[0m\n"; fi
				;;


	"offline")
				#offlinestore
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
				;;

	esac #workMode


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

