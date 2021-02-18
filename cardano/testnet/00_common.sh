#!/bin/bash

#Please set the following variables to your needs, you can overwrite them dynamically
#by placing a file with name "common.inc" in the calling directory or in "$HOME/.common.inc".
#It will be sourced into this file automatically if present and can overwrite the values below dynamically :-)

socket="db-mainnet/node.socket"

genesisfile="configuration-mainnet/mainnet-shelley-genesis.json"           #Shelley-Genesis path
genesisfile_byron="configuration-mainnet/mainnet-byron-genesis.json"       #Byron-Genesis path

cardanocli="./cardano-cli"	#Path to your cardano-cli you wanna use
cardanonode="./cardano-node"	#Path to your cardano-node you wanna use

magicparam="--mainnet"		#choose "--mainnet" for mainnet or for example "--testnet-magic 1097911063" for a testnet, 12 for allegra
addrformat="--mainnet" 		#choose "--mainnet" for mainnet address format or like "--testnet-magic 1097911063" for testnet address format, 12 for allegra

itn_jcli="./jcli" 		#only needed if you wanna include your itn witness for your pool-ticker


#--------- NEW --- you can now use a hardware key (Ledger/Trezor) too, please read the instructions on the github repo README :-)
cardanohwcli="cardano-hw-cli"      #Path to your cardano-hw-cli you wanna use


#--------- NEW --- you can work in offline mode now too, please read the instructions on the github repo README :-)
offlineMode="no" 		#change this to "yes" if you run theses scripts on a cold machine, it need a counterpart with set to "no" on a hot machine
offlineFile="./offlineTransfer.json" #path to the filename (JSON) that will be used to transfer the data between a hot and a cold machine


#--------- leave this next value until you have to change it for a testnet
byronToShelleyEpochs=208 #208 for the mainnet, 74 for the testnet, 1 for allegra-testnet


#--------- only for kes/opcert update and upload via scp -----
remoteServerAddr="remoteserver address or ip"                   #RemoteServer ip or dns name
remoteServerUser="remoteuser"                             	#RemoteServer userlogin via ssh keys
remoteServerSSHport="22"                                	#RemoteServer SSH port number
remoteServerDestDir="~/remoteuser/core-###NODENAME###/."        #Destination directory were to copy the files to
remoteServerPostCommand="~/remoteuser/restartCore.sh"      	#Command to execute via SSH after the file upload completed to restart the coreNode on the remoteServer


#--------- some other stuff -----
showVersionInfo="yes"	#yes/no to show the version info and script mode on every script call










##############################################################################################################################
#
# DONT EDIT BELOW THIS LINE
#
##############################################################################################################################

minNodeVersion="1.25.1"  #minimum allowed node version for this script-collection version
maxNodeVersion="9.99.9"  #maximum allowed node version, 9.99.9 = no limit so far
minLedgerCardanoAppVersion="2.1.0"  #minimum version for the cardano-app on the Ledger hardwarewallet
minTrezorCardanoAppVersion="2.3.5"  #minimum version for the cardano-app on the Trezor hardwarewallet
minHardwareCliVersion="1.1.3" #minimum version for the cardano-hw-cli

#Placeholder for a fixed subCommand
subCommand=""	#empty since 1.24.0, because the "shelley" subcommand moved to the mainlevel

#Overwrite variables via env file if present
scriptDir=$(dirname "$0" 2> /dev/null)
if [[ -f "${scriptDir}/common.inc" ]]; then source "${scriptDir}/common.inc"; fi
if [[ -f "$HOME/.common.inc" ]]; then source "$HOME/.common.inc"; fi
if [[ -f "common.inc" ]]; then source "common.inc"; fi

export CARDANO_NODE_SOCKET_PATH=${socket}

#Setting online/offline variables and offlineFile default value, versionInfo
if [[ "${offlineMode^^}" == "YES" ]]; then offlineMode=true; onlineMode=false; else offlineMode=false; onlineMode=true; fi
if [[ "${offlineFile}" == "" ]]; then offlineFile="./offlineTransfer.json"; fi
if [[ "${showVersionInfo^^}" == "NO" ]]; then showVersionInfo=false; else showVersionInfo=true; fi

#-------------------------------------------------------
#DisplayMajorErrorMessage
majorError() {
echo -e "\e[97m\n"
echo -e "         _ ._  _ , _ ._\n        (_ ' ( \`  )_  .__)\n      ( (  (    )   \`)  ) _)\n     (__ (_   (_ . _) _) ,__)\n         \`~~\`\\ ' . /\`~~\`\n              ;   ;\n              /   \\ \n_____________/_ __ \\___________________________________________\n"
echo -e "\e[35m${1}\n\nIf you think all is right at your side, please check the GitHub repo if there\nis a newer version/bugfix available, thx: https://github.com/gitmachtl/scripts\e[0m\n"; exit 1;
}
#-------------------------------------------------------

#-------------------------------------------------------------
#Do a cli and node version check
versionCheck() { printf '%s\n%s' "${1}" "${2}" | sort -C -V; } #$1=minimal_needed_version, $2=current_node_version

exists() {
 command -v "$1" >/dev/null 2>&1
}

#Check cardano-cli
if ! exists "${cardanocli}"; then majorError "Path ERROR - Path to cardano-cli is not correct or cardano-cli binaryfile is missing!"; exit 1; fi
versionCLI=$(${cardanocli} version 2> /dev/null |& head -n 1 |& awk {'print $2'})
versionCheck "${minNodeVersion}" "${versionCLI}"
if [[ $? -ne 0 ]]; then majorError "Version ERROR - Please use a cardano-node/cli version ${minNodeVersion} or higher !\nOld versions are not supported for security reasons, please upgrade - thx."; exit 1; fi
versionCheck "${versionCLI}" "${maxNodeVersion}"
if [[ $? -ne 0 ]]; then majorError "Version ERROR - Please use a cardano-node/cli version between ${minNodeVersion} and ${maxNodeVersion} !\nOther versions are not supported for compatibility issues, please check if newer scripts are available - thx."; exit 1; fi
if ${showVersionInfo}; then echo -ne "\n\e[0mVersion-Info: \e[32mcli ${versionCLI}\e[0m"; fi

#Check cardano-node only in online mode
if ${onlineMode}; then
	if ! exists "${cardanonode}"; then majorError "Path ERROR - Path to cardano-node is not correct or cardano-node binaryfile is missing!"; exit 1; fi
	versionNODE=$(${cardanonode} version 2> /dev/null |& head -n 1 |& awk {'print $2'})
	versionCheck "${minNodeVersion}" "${versionNODE}"
	if [[ $? -ne 0 ]]; then majorError "Version ERROR - Please use a cardano-node/cli version ${minNodeVersion} or higher !\nOld versions are not supported for security reasons, please upgrade - thx."; exit 1; fi
	versionCheck "${versionNODE}" "${maxNodeVersion}"
	if [[ $? -ne 0 ]]; then majorError "Version ERROR - Please use a cardano-node/cli version between ${minNodeVersion} and ${maxNodeVersion} !\nOther versions are not supported for compatibility issues, please check if newer scripts are available - thx."; exit 1; fi
	if ${showVersionInfo}; then echo -ne " / \e[32mnode ${versionNODE}\e[0m"; fi
fi

#Display current Mode (online or offline)
if ${showVersionInfo}; then
				if ${offlineMode}; then echo -e "\t\tScripts-Mode: \e[32moffline\e[0m\n"; else echo -e "\t\tScripts-Mode: \e[36monline\e[0m\n"; fi
fi

#Check path to genesis files
if [[ ! -f "${genesisfile}" ]]; then majorError "Path ERROR - Path to the shelley genesis file '${genesisfile}' is wrong or the file is missing!"; exit 1; fi
if [[ ! -f "${genesisfile_byron}" ]]; then majorError "Path ERROR - Path to the byron genesis file '${genesisfile_byron}' is wrong or the file is missing!"; exit 1; fi

#-------------------------------------------------------------


#Check if curl, jq and bc is installed
if ! exists curl; then
          echo -e "\nYou need the little tool 'curl' !\n"
          echo -e "Install it on Ubuntu/Debian like:\n\e[97msudo apt update && sudo apt -y install curl\e[0m\n"
          echo -e "Thx! :-)\n"
          exit 2
fi

if ! exists jq; then
          echo -e "\nYou need the little tool 'jq' !\n"
          echo -e "Install it On Ubuntu/Debian like:\n\e[97msudo apt update && sudo apt -y install jq\e[0m\n"
          echo -e "Thx! :-)\n"
          exit 2
fi

if ! exists bc; then
          echo -e "\nYou need the little tool 'bc' !\n"
          echo -e "Install it On Ubuntu/Debian like:\n\e[97msudo apt update && sudo apt -y install bc\e[0m\n"
          echo -e "Thx! :-)\n"
          exit 2
fi


#-------------------------------------------------------------
#Searching for the temp directory (used for transactions files)
tempDir=$(dirname $(mktemp tmp.XXXX -ut))


#Dummy Shelley Payment_Addr
dummyShelleyAddr="addr1vyde3cg6cccdzxf4szzpswgz53p8m3r4hu76j3zw0tagyvgdy3s4p"

#-------------------------------------------------------
#AddressType check
check_address() {
tmp=$(${cardanocli} ${subCommand} address info --address $1 2> /dev/null)
if [[ $? -ne 0 ]]; then echo -e "\e[35mERROR - Unknown address format for address: $1 !\e[0m"; exit 1; fi
}

get_addressType() {
${cardanocli} ${subCommand} address info --address $1 2> /dev/null | jq -r .type
}

get_addressEra() {
${cardanocli} ${subCommand} address info --address $1 2> /dev/null | jq -r .era
}

addrTypePayment="payment"
addrTypeStake="stake"


#-------------------------------------------------------------
#Subroutine for user interaction
ask() {
    local prompt default reply

    if [ "${2:-}" = "Y" ]; then
        prompt="Y/n"
        default=Y
    elif [ "${2:-}" = "N" ]; then
        prompt="y/N"
        default=N
    else
        prompt="y/n"
        default=
    fi

    while true; do

        # Ask the question (not using "read -p" as it uses stderr not stdout)
        echo -ne "$1 [$prompt] "

        # Read the answer (use /dev/tty in case stdin is redirected from somewhere else)
        read reply </dev/tty

        # Default?
        if [ -z "$reply" ]; then
            reply=$default
        fi

        # Check if the reply is valid
        case "$reply" in
            Y*|y*) return 0 ;;
            N*|n*) return 1 ;;
        esac

    done
}
#-------------------------------------------------------

#-------------------------------------------------------
#Subroutines to set read/write flags for important files
file_lock()
{
if [ -f "$1" ]; then chmod 400 $1; fi
}

file_unlock()
{
if [ -f "$1" ]; then chmod 600 $1; fi
}
#-------------------------------------------------------

#-------------------------------------------------------
#Subroutines to calculate current epoch from genesis.json offline
get_currentEpoch()
{
local startTimeGenesis=$(cat ${genesisfile} | jq -r .systemStart)
local startTimeSec=$(date --date=${startTimeGenesis} +%s)     #in seconds (UTC)
local currentTimeSec=$(date -u +%s)                           #in seconds (UTC)
local epochLength=$(cat ${genesisfile} | jq -r .epochLength)
local currentEPOCH=$(( (${currentTimeSec}-${startTimeSec}) / ${epochLength} ))  #returns a integer number, we like that
echo ${currentEPOCH}
}
#-------------------------------------------------------

#-------------------------------------------------------
#Subroutines to calculate time until next epoch from genesis.json offline
get_timeUntilNextEpoch()
{
local startTimeGenesis=$(cat ${genesisfile} | jq -r .systemStart)
local startTimeSec=$(date --date=${startTimeGenesis} +%s)     #in seconds (UTC)
local currentTimeSec=$(date -u +%s)                           #in seconds (UTC)
local epochLength=$(cat ${genesisfile} | jq -r .epochLength)
local currentEPOCH=$(( (${currentTimeSec}-${startTimeSec}) / ${epochLength} ))  #returns a integer number, we like that
local timeUntilNextEpoch=$(( ${epochLength} - (${currentTimeSec}-${startTimeSec}) + (${currentEPOCH}*${epochLength}) ))
echo ${timeUntilNextEpoch}
}
#-------------------------------------------------------


#-------------------------------------------------------
#Subroutines to calculate current slotHeight(tip) depending on online/offline mode
get_currentTip()
{
if ${onlineMode}; then
			local currentTip=$(${cardanocli} ${subCommand} query tip ${magicparam} | jq -r .slotNo);
		  else
			#Static
			local slotLength=$(cat ${genesisfile} | jq -r .slotLength)                    #In Secs
			local epochLength=$(cat ${genesisfile} | jq -r .epochLength)                  #In Secs
			local slotsPerKESPeriod=$(cat ${genesisfile} | jq -r .slotsPerKESPeriod)      #Number
			local startTimeByron=$(cat ${genesisfile_byron} | jq -r .startTime)           #In Secs(abs)
			local startTimeGenesis=$(cat ${genesisfile} | jq -r .systemStart)             #In Text
			local startTimeSec=$(date --date=${startTimeGenesis} +%s)                     #In Secs(abs)
			local transTimeEnd=$(( ${startTimeSec}+(${byronToShelleyEpochs}*${epochLength}) ))                    #In Secs(abs) End of the TransitionPhase
			local byronSlots=$(( (${startTimeSec}-${startTimeByron}) / 20 ))              #NumSlots between ByronChainStart and ShelleyGenesisStart(TransitionStart)
			local transSlots=$(( (${byronToShelleyEpochs}*${epochLength}) / 20 ))         #NumSlots in the TransitionPhase

			#Dynamic
			local currentTimeSec=$(date -u +%s)

			#Calculate current slot
			if [[ "${currentTimeSec}" -lt "${transTimeEnd}" ]];
			        then #In Transistion Phase between ShelleyGenesisStart and TransitionEnd
			        local currentTip=$(( ${byronSlots} + (${currentTimeSec}-${startTimeSec}) / 20 ))
			        else #After Transition Phase
			        local currentTip=$(( ${byronSlots} + ${transSlots} + ((${currentTimeSec}-${transTimeEnd}) / ${slotLength}) ))
			fi

		fi
echo ${currentTip}
}
#-------------------------------------------------------

#-------------------------------------------------------
#Subroutines to calculate current TTL
get_currentTTL()
{
echo $(( $(get_currentTip) + 100000 )) #changed from 10000 to 100000 so a little over a day to have time to collect witnesses if needed
}
#-------------------------------------------------------


#-------------------------------------------------------
#Displays an Errormessage if parameter is not 0
checkError()
{
if [[ $1 -ne 0 ]]; then echo -e "\n\n\e[35mERROR (Code $1) !\e[0m\n"; exit 1; fi
}
#-------------------------------------------------------

#-------------------------------------------------------
#TrimString
function trimString
{
    echo "$1" | sed -n '1h;1!H;${;g;s/^[ \t]*//g;s/[ \t]*$//g;p;}'
}
#-------------------------------------------------------

#-------------------------------------------------------
#Return the era the online node is in
get_NodeEra() {
#CheckEra
tmp=$(${cardanocli} query protocol-parameters --allegra-era ${magicparam} 2> /dev/null)
if [[ "$?" == 0 ]]; then echo "allegra"; return 0; fi
tmp=$(${cardanocli} query protocol-parameters --mary-era ${magicparam} 2> /dev/null)
if [[ "$?" == 0 ]]; then echo "mary"; return 0; fi
tmp=$(${cardanocli} query protocol-parameters --shelley-era ${magicparam} 2> /dev/null)
if [[ "$?" == 0 ]]; then echo "shelley"; return 0; fi
tmp=$(${cardanocli} query protocol-parameters --byron-era ${magicparam} 2> /dev/null)
if [[ "$?" == 0 ]]; then echo "byron"; return 0; fi
#None of the above
return 1
}
#Set nodeEra parameter (--shelley-era, --allegra-era, --mary-era, --byron-era or empty)
if ${onlineMode}; then tmpEra=$(get_NodeEra); else tmpEra=$(jq -r ".protocol.era" 2> /dev/null < ${offlineFile}); fi
if [[ ! "${tmpEra}" == "" ]]; then nodeEraParam="--${tmpEra}-era"; else nodeEraParam=""; fi
#-------------------------------------------------------


#-------------------------------------------------------
#Converts a raw UTXO query output into a Allegra style UTXO JSON with stringnumbers
generate_UTXO()  #Parameter1=RawUTXO, Parameter2=Address
{

local utxoJSON="{}" #start with a blank JSON skeleton
local utxoAddress=${2}

  while IFS= read -r line; do
  IFS=' ' read -ra utxo_entry <<< "${line}" # utxo_entry array holds entire utxo string
  local utxoHashIndex="${utxo_entry[0]}#${utxo_entry[1]}"
  local utxoAmountLovelaces=${utxo_entry[2]}

  #Build the entry for each UtxoHashIndex
  local utxoJSON=$( jq ".\"${utxoHashIndex}\".amount = [ \"${utxoAmountLovelaces}\", [] ]" <<< ${utxoJSON})
  local utxoJSON=$( jq ".\"${utxoHashIndex}\".address = \"${utxoAddress}\"" <<< ${utxoJSON})

  #Add the Token entries if tokens available
  if [[ ${#utxo_entry[@]} -gt 4 ]]; then # contains tokens
    idx=5
    while [[ ${#utxo_entry[@]} -gt ${idx} ]]; do
      local asset_amount=${utxo_entry[${idx}]}
      local asset_hash_name="${utxo_entry[$((idx+1))]}"
      IFS='.' read -ra asset <<< "${asset_hash_name}"
      local asset_policy=${asset[0]}
      local asset_name=${asset[1]}

      #Add the Entry of the Token
      local policyArrayIndex=$( jq ".\"${utxoHashIndex}\".amount[1][0] | index(\"${asset_policy}\")" <<< ${utxoJSON});
      if [[ "${policyArrayIndex}" == null ]]; then #If policy does not exist, generate first entry
	 local utxoJSON=$( jq ".\"${utxoHashIndex}\".amount[1] += [ [ \"${asset_policy}\", [ [ \"${asset_name}\",\"${asset_amount}\" ] ] ] ]" <<< ${utxoJSON})
                			      else
         local utxoJSON=$( jq ".\"${utxoHashIndex}\".amount[1][${policyArrayIndex}][1] += [ [ \"${asset_name}\",\"${asset_amount}\" ] ]" <<< ${utxoJSON})
      fi

      idx=$(( idx + 3 ))
    done
  fi
  echo
done < <(printf "${1}\n" | tail -n +3) #read in from parameter 1 (raw utxo) but cut first two lines
echo "${utxoJSON}"
}
#-------------------------------------------------------


#-------------------------------------------------------
#Converts a Shelley/Allegra style UTXO JSON into a Mary style JSON
convert_UTXO()
{
local inJSON=${1}
local outJSON=${inJSON}
local utxoEntryCnt=$(jq length <<< ${inJSON})
local tmpCnt=0
for (( tmpCnt=0; tmpCnt<${utxoEntryCnt}; tmpCnt++ ))
do
local utxoHashIndex=$(jq -r "keys[${tmpCnt}]" <<< ${inJSON})
local utxoAmount=$(jq -r ".\"${utxoHashIndex}\".amount" <<< ${inJSON})
local outJSON=$( jq ".\"${utxoHashIndex}\".amount = [ ${utxoAmount}, [] ]" <<< ${outJSON})
done
echo "${outJSON}"
}
#-------------------------------------------------------

#-------------------------------------------------------
#Cuts out all UTXOs in a mary style UTXO JSON that contains Assets
onlyLovelaces_UTXO()
{
local inJSON=${1}
local outJSON=${inJSON}
local utxoEntryCnt=$(jq length <<< ${inJSON})
local tmpCnt=0
for (( tmpCnt=0; tmpCnt<${utxoEntryCnt}; tmpCnt++ ))
do
local utxoHashIndex=$(jq -r "keys[${tmpCnt}]" <<< ${inJSON})
local utxoAmount=$(jq -r ".\"${utxoHashIndex}\".amount[0]" <<< ${inJSON})
local assetCnt=$(jq -r ".\"${utxoHashIndex}\".amount[1] | length" <<< ${inJSON})
if [[ ${assetCnt} -gt 0 ]]; then local outJSON=$( jq "del (.\"${utxoHashIndex}\")" <<< ${outJSON}); fi
done
echo "${outJSON}"
}
#-------------------------------------------------------

#-------------------------------------------------------
#Cuts out all UTXOs in a mary style UTXO JSON that does not contains Assets
onlyAssets_UTXO()
{
local inJSON=${1}
local outJSON=${inJSON}
local utxoEntryCnt=$(jq length <<< ${inJSON})
local tmpCnt=0
for (( tmpCnt=0; tmpCnt<${utxoEntryCnt}; tmpCnt++ ))
do
local utxoHashIndex=$(jq -r "keys[${tmpCnt}]" <<< ${inJSON})
local utxoAmount=$(jq -r ".\"${utxoHashIndex}\".amount[0]" <<< ${inJSON})
local assetCnt=$(jq -r ".\"${utxoHashIndex}\".amount[1] | length" <<< ${inJSON})
if [[ ${assetCnt} -eq 0 ]]; then local outJSON=$( jq "del (.\"${utxoHashIndex}\")" <<< ${outJSON}); fi
done
echo "${outJSON}"
}
#-------------------------------------------------------


#-------------------------------------------------------
#Calculate the minimum UTXO level that has to be sent depending on the assets and the minUTXO protocol-parameters
get_minOutUTXO() {
	#${1} = protocol-parameters(json format) content
	#${2} = total number of different assets
	#${3} = total number of different policyIDs

local minUTXOvalue=$(jq -r .minUTxOValue <<< ${1})

echo $(( ${minUTXOvalue} + (${2}*${minUTXOvalue}) ))	#poor calculation currently
}
#-------------------------------------------------------

#-------------------------------------------------------
#Show Informations about the content in the offlineJSON
showOfflineFileInfo() {
#Displays infos about the content in the offlineJSON
echo -e "\e[0mChecking Content of the offlineFile: \e[32m$(basename ${offlineFile})\e[0m"
echo

if [[ $(jq ".protocol.parameters | length" <<< ${offlineJSON}) -gt 0 ]]; then echo -ne "\e[0mProtocol-Parameters:\e[32m present\e[0m\t"; else echo -ne "\e[0mProtocol-Parameters:\e[35m missing\e[0m\t"; fi

if [[ ! "$(jq -r ".protocol.era" <<< ${offlineJSON})" == null ]]; then echo -e "\e[0m       Protocol-Era:\e[32m $(jq -r ".protocol.era" <<< ${offlineJSON})\e[0m"; else echo -e "\e[0m       Protocol-Era:\e[35m missing\e[0m"; fi

local historyCnt=$(jq -r ".history | length" <<< ${offlineJSON})
echo -e "\e[0m    History-Entries:\e[32m ${historyCnt}\e[0m";
if [[ ${historyCnt} -gt 0 ]]; then echo -e "\e[0m        Last-Action:\e[32m $(jq -r ".history[-1].action" <<< ${offlineJSON}) \e[90m($(jq -r ".history[-1].date" <<< ${offlineJSON}))\e[0m"; fi

if ${offlineMode}; then
			echo -ne "\e[0m    Online Versions:"
			local versionTmp=$(jq -r ".general.onlineCLI" <<< ${offlineJSON}); if [[ "${versionTmp}" == null ]]; then versionTmp="-.--.-"; fi; echo -ne "\e[32m cli ${versionTmp}\e[0m"
			local versionTmp=$(jq -r ".general.onlineNODE" <<< ${offlineJSON}); if [[ "${versionTmp}" == null ]]; then versionTmp="-.--.-"; fi; echo -e " /\e[32m node ${versionTmp}\e[0m"
		   else
			echo -ne "\e[0m   Offline Versions:"
			local versionTmp=$(jq -r ".general.offlineCLI" <<< ${offlineJSON}); if [[ "${versionTmp}" == null ]]; then versionTmp="-.--.-"; fi; echo -e "\e[32m cli ${versionTmp}\e[0m"
fi
echo
local addressCnt=$(jq -r ".address | length" <<< ${offlineJSON})
echo -e "\e[0m    Address-Entries:\e[32m ${addressCnt}\e[0m";
for (( tmpCnt=0; tmpCnt<${addressCnt}; tmpCnt++ ))
do
  local addressKey=$(jq -r ".address | keys[${tmpCnt}]" <<< ${offlineJSON})
  local addressName=$(jq -r ".address.\"${addressKey}\".name" <<< ${offlineJSON})
  local addressAmount=$(jq -r ".address.\"${addressKey}\".totalamount" <<< ${offlineJSON}) lovelaces
  addressAmount="$(convertToADA ${addressAmount}) ADA";
  local addressAssetsCnt=$(jq -r ".address.\"${addressKey}\".totalassetscnt" <<< ${offlineJSON})
  if [[ ${addressAssetsCnt} -gt 0 ]]; then addressAmount="${addressAmount} + ${addressAssetsCnt} Asset-Types"; fi
  local addressDate=$(jq -r ".address.\"${addressKey}\".date" <<< ${offlineJSON})
  local addressUsedAsPayment=$(jq -r ".address.\"${addressKey}\".used" <<< ${offlineJSON})
  local addressType=$(jq -r ".address.\"${addressKey}\".type" <<< ${offlineJSON})
  if [[ ${addressUsedAsPayment} == "yes" ]]; then
						addressUsed="used"; if [[ ${addressType} == ${addrTypePayment} ]]; then addressUsed="${addressUsed}, but can receive"; fi;
					     else
						addressUsed="";
					     fi
  echo -e "\n\e[90m\t[$((${tmpCnt}+1))]\t\e[0m${addressName} \e[90m(${addressAmount}, ${addressDate}) \e[35m${addressUsed}\e[0m\n\t   \t\e[90m${addressKey}\e[0m"
done
local filesCnt=$(jq -r ".files | length" <<< ${offlineJSON});
echo
echo -e "\e[0m     Files-Attached:\e[32m ${filesCnt}\e[0m"; if [[ ${filesCnt} -gt 0 ]]; then echo; fi
for (( tmpCnt=0; tmpCnt<${filesCnt}; tmpCnt++ ))
do
  local filePath=$(jq -r ".files | keys[${tmpCnt}]" <<< ${offlineJSON})
  local fileDate=$(jq -r ".files.\"${filePath}\".date" <<< ${offlineJSON})
  local fileSize=$(jq -r ".files.\"${filePath}\".size" <<< ${offlineJSON})
  echo -e "\e[90m\t[$((${tmpCnt}+1))]\t\e[0m${filePath} \e[90m(${fileSize} bytes, ${fileDate})\e[0m"
done
echo
local transactionsCnt=$(jq -r ".transactions | length" <<< ${offlineJSON})
echo -e "\e[0mTransactions in Cue:\e[32m ${transactionsCnt}\e[0m\n";
for (( tmpCnt=0; tmpCnt<${transactionsCnt}; tmpCnt++ ))
do
  local transactionType=$(jq -r ".transactions[${tmpCnt}].type" <<< ${offlineJSON})
  local transactionEra=$(jq -r ".transactions[${tmpCnt}].era" <<< ${offlineJSON})
  local transactionDate=$(jq -r ".transactions[${tmpCnt}].date" <<< ${offlineJSON})
  local transactionFromName=$(jq -r ".transactions[${tmpCnt}].fromAddr" <<< ${offlineJSON})
  local transactionFromAddr=$(jq -r ".transactions[${tmpCnt}].sendFromAddr" <<< ${offlineJSON})
  local transactionToName=$(jq -r ".transactions[${tmpCnt}].toAddr" <<< ${offlineJSON})
  local transactionToAddr=$(jq -r ".transactions[${tmpCnt}].sendToAddr" <<< ${offlineJSON})

  case ${transactionType} in
	Transaction|Asset-Minting|Asset-Burning )
			#Normal UTXO Transaction (lovelaces and/or tokens)
			echo -e "\e[90m\t[$((${tmpCnt}+1))]\t\e[0m${transactionType}[${transactionEra}] from '${transactionFromName}' to '${transactionToName}' \e[90m(${transactionDate})"
			echo -e "\t   \t\e[90mfrom ${transactionFromAddr}\n\t   \t\e[90mto ${transactionToAddr}\e[0m"
			;;

        Withdrawal )
                        #Rewards Withdrawal Transaction
			local transactionStakeName=$(jq -r ".transactions[${tmpCnt}].stakeAddr" <<< ${offlineJSON})
			local transactionStakeAddr=$(jq -r ".transactions[${tmpCnt}].stakingAddr" <<< ${offlineJSON})
                        echo -e "\e[90m\t[$((${tmpCnt}+1))]\t\e[0mRewards-Withdrawal[${transactionEra}] from '${transactionStakeName}' to '${transactionToName}', payment via '${transactionFromName}' \e[90m(${transactionDate})"
                        echo -e "\t   \t\e[90mfrom ${transactionStakeAddr}\n\t   \t\e[90mto ${transactionToAddr}\n\t   \t\e[90mpayment via ${transactionFromAddr}\e[0m"
                        ;;

        StakeKeyRegistration|StakeKeyDeRegistration )
                        #StakeKeyRegistration or Deregistration
                        local transactionStakeName=$(jq -r ".transactions[${tmpCnt}].stakeAddr" <<< ${offlineJSON})
                        echo -e "\e[90m\t[$((${tmpCnt}+1))]\t\e[0m${transactionType}[${transactionEra}] for '${transactionStakeName}', payment via '${transactionFromName}' \e[90m(${transactionDate})"
                        echo -e "\t   \t\e[90mpayment via ${transactionFromAddr}\e[0m"
                        ;;

        DelegationCertRegistration )
                        #Delegation Certificate Registration
                        local transactionDelegName=$(jq -r ".transactions[${tmpCnt}].delegName" <<< ${offlineJSON})
                        echo -e "\e[90m\t[$((${tmpCnt}+1))]\t\e[0m${transactionType}[${transactionEra}] for '${transactionDelegName}', payment via '${transactionFromName}' \e[90m(${transactionDate})"
                        echo -e "\t   \t\e[90mpayment via ${transactionFromAddr}\e[0m"
                        ;;

        PoolRegistration|PoolReRegistration|PoolRetirement )
                        #Delegation Certificate Registration
                        local poolMetaTicker=$(jq -r ".transactions[${tmpCnt}].poolMetaTicker" <<< ${offlineJSON})
                        echo -e "\e[90m\t[$((${tmpCnt}+1))]\t\e[0m${transactionType}[${transactionEra}] for Pool '${poolMetaTicker}', payment via '${transactionFromName}' \e[90m(${transactionDate})"
                        echo -e "\t   \t\e[90mpayment via ${transactionFromAddr}\e[0m"
                        ;;


	* )		#Unknown Transaction Type !?
			echo -e "\e[90m\t[$((${tmpCnt}+1))]\t\e[35mUnknown transaction type\e[0m" 
			;;
  esac

echo
done

}
#-------------------------------------------------------

#-------------------------------------------------------
#Read the current offlineFile into the offlineJSON variable
readOfflineFile() {
if [ -f "${offlineFile}" ]; then
                                offlineJSON=$(jq . ${offlineFile} 2> /dev/null)
                                if [[ $? -ne 0 ]]; then echo -e "\e[35mERROR - '$(basename ${offlineFile})' is not a valid JSON file, please generate a valid offlineJSON first in onlinemode.\e[0m\n"; exit 1; fi
                                if [[ $(trimString "${offlineJSON}") == "" ]]; then echo -e "\e[35mERROR - '$(basename ${offlineFile})' is not a valid JSON file, please generate a valid offlineJSON first in onlinemode.\e[0m\n"; exit 1; fi #nothing in the file
				if [[ ! $(jq ".protocol.parameters | length" <<< ${offlineJSON}) -gt 0 ]]; then echo -e "\e[35mERROR - '$(basename ${offlineFile})' contains no protocol parameters. Please generate a valid offlineJSON first in onlinemode.\e[0m\n"; exit 1; fi
                            fi
}
#-------------------------------------------------------

#-------------------------------------------------------
#Get the hardware-wallet ready, check the cardano-app version
start_HwWallet() {

if [[ "$(which ${cardanohwcli})" == "" ]]; then echo -e "\n\e[35mError - cardano-hw-cli binary not found, please install it first and set the path to it correct in the 00_common.sh, common.inc or $HOME/.common.inc !\e[0m\n"; exit 1; fi

versionHWCLI=$(${cardanohwcli} version 2> /dev/null |& head -n 1 |& awk {'print $6'})
versionCheck "${minHardwareCliVersion}" "${versionHWCLI}"
if [[ $? -ne 0 ]]; then majorError "Version ERROR - Please use a cardano-hw-cli version ${minHardwareCliVersion} or higher !\nOld versions are not supported for security reasons, please upgrade - thx."; exit 1; fi

echo -ne "\e[33mPlease connect & unlock your Hardware-Wallet, open the Cardano-App on Ledger-Devices (abort with CTRL+C)\e[0m\n\n\033[2A\n"
local tmp=$(${cardanohwcli} device version 2> /dev/stdout)
local pointStr="....."
until [[ "${tmp}" == *"app version"* && ! "${tmp}" == *"undefined"* ]]; do
	local tmpCnt=6
	while [[ ${tmpCnt} > 0 ]]; do
	tmpCnt=$(( ${tmpCnt} - 1 ))
	echo -ne "\r\e[35m${tmp:0:64} ...\e[0m - retry in ${tmpCnt} secs ${pointStr:${tmpCnt}}\033[K"
	sleep 1
	done
tmp=$(${cardanohwcli} device version 2> /dev/stdout)
done

local walletManu=$(echo "${tmp}" |& head -n 1 |& awk {'print $1'})
local versionApp=$(echo "${tmp}" |& head -n 1 |& awk {'print $4'})

case ${walletManu^^} in

	LEDGER ) #For Ledger Hardware-Wallets
		versionCheck "${minLedgerCardanoAppVersion}" "${versionApp}"
		if [[ $? -ne 0 ]]; then majorError "Version ERROR - Please use a Cardano App version ${minLedgerCardanoAppVersion} or higher on your ${walletManu} Hardware-Wallet!\nOlder versions like your current ${versionApp} are not supported, please upgrade - thx."; exit 1; fi
		;;

        TREZOR ) #For Trezor Hardware-Wallets
                versionCheck "${minTrezorCardanoAppVersion}" "${versionApp}"
                if [[ $? -ne 0 ]]; then majorError "Version ERROR - Please use Cardano App version ${minTrezorCardanoAppVersion} or higher on your ${walletManu} Hardware-Wallet!\nOlder versions like your current ${versionApp} are not supported, please upgrade - thx."; exit 1; fi
                ;;

	* ) #For any other Manuf.
		majorError "Only Ledger and Trezor Hardware-Wallets are supported at the moment!"; exit 1;
		;;
esac

echo -ne "\r\033[1A\e[0mCardano App Version \e[32m${versionApp}\e[0m found on your \e[32m${walletManu}\e[0m device!\033[K\n\e[32mPlease approve the action on your Hardware-Wallet (abort with CTRL+C) \e[0m... \033[K"
}

#-------------------------------------------------------

#-------------------------------------------------------
#Convert the given lovelaces $1 into ada (divide by 1M)
convertToADA() {
echo $(bc <<< "scale=6; ${1} / 1000000" | sed -e 's/^\./0./') #divide by 1M and add a leading zero if below 1 ada
}
