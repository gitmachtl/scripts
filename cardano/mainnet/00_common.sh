#!/bin/bash

##############################################################################################################################
#
# MAIN CONFIG FILE:
#
# Please set the following variables to your needs, you can overwrite them dynamically
# by placing a file with name "common.inc" in the calling directory or in "$HOME/.common.inc".
# It will be sourced into this file automatically if present and can overwrite the values below dynamically :-)
#
##############################################################################################################################


#--------- Set the Path to your node socket file and to your genesis files here ---------
socket="db-mainnet/node.socket" #Path to your cardano-node socket for machines in online-mode. Another example would be "$HOME/cnode/sockets/node.socket"
genesisfile="configuration-mainnet/mainnet-shelley-genesis.json"           #Shelley-Genesis path, you can also use the placeholder $HOME to specify your home directory
genesisfile_byron="configuration-mainnet/mainnet-byron-genesis.json"       #Byron-Genesis path, you can also use the placeholder $HOME to specify your home directory


#--------- Set the Path to your main binaries here ---------
cardanocli="./cardano-cli"	#Path to your cardano-cli binary you wanna use. If your binary is present in the Path just set it to "cardano-cli" without the "./" infront
cardanonode="./cardano-node"	#Path to your cardano-node binary you wanna use. If your binary is present in the Path just set it to "cardano-node" without the "./" infront
bech32_bin="./bech32"		#Path to your bech32 binary you wanna use. If your binary is present in the Path just set it to "bech32" without the "./" infront


#--------- You can work in offline mode too, please read the instructions on the github repo README :-)
offlineMode="no" 			#change this to "yes" if you run these scripts on a cold machine, it need a counterpart with set to "no" on a hot machine
offlineFile="./offlineTransfer.json" 	#path to the filename (JSON) that will be used to transfer the data between a hot and a cold machine


#------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#--------- Only needed if you wanna do catalyst voting or if you wanna include your itn witness for your pool-ticker
jcli_bin="./jcli"               #Path to your jcli binary you wanna use. If your binary is present in the Path just set it to "jcli" without the "./" infront
vitkedqr_bin="./vit-kedqr"	#Path to your vit-kedqr binary you wanna use. If your binary is present in the Path just set it to "vit-kedqr" without the "./" infront


#--------- Only needed if you wanna use a hardware key (Ledger/Trezor) too, please read the instructions on the github repo README :-)
cardanohwcli="cardano-hw-cli"      #Path to your cardano-hw-cli binary you wanna use. If your binary is present in the Path just set it to "cardano-hw-cli" without the "./" infront


#--------- Only needed if you wanna generate the right format for the NativeAsset Metadata Registry
cardanometa="./token-metadata-creator" #Path to your token-metadata-creator binary you wanna use. If present in the Path just set it to "token-metadata-creator" without the "./" infront


#--------- Only needed for automated kes/opcert update and upload via scp -----
remoteServerAddr="remoteserver address or ip"                   #RemoteServer ip or dns name
remoteServerUser="remoteuser"                             	#RemoteServer userlogin via ssh keys
remoteServerSSHport="22"                                	#RemoteServer SSH port number
remoteServerDestDir="~/remoteuser/core-###NODENAME###/."        #Destination directory were to copy the files to
remoteServerPostCommand="~/remoteuser/restartCore.sh"      	#Command to execute via SSH after the file upload completed to restart the coreNode on the remoteServer


#--------- Only needed if you wanna change the BlockChain from the Mainnet to a Testnet Chain Setup
byronToShelleyEpochs=208 	#choose 208 for the mainnet, 74 for the public testnet
magicparam="--mainnet"          #choose "--mainnet" for mainnet or "--testnet-magic 1097911063" for the public testnet
addrformat="--mainnet"          #choose "--mainnet" for mainnet address format or "--testnet-magic 1097911063" for the testnet address format



#--------- some other stuff -----
showVersionInfo="yes"		#yes/no to show the version info and script mode on every script call
queryTokenRegistry="yes"	#yes/no to query each native asset/token on the token registry server live









##############################################################################################################################
#
# 'DONT EDIT BELOW THIS LINE !!!'
#
##############################################################################################################################

#Token Metadata API URLs  (will be autoresolved into the tokenMetaServer variable)
tokenMetaServer_mainnet="https://tokens.cardano.org/metadata/" #mainnet
tokenMetaServer_testnet="https://metadata.cardano-testnet.iohkdev.io/metadata/"	#public testnet

#URLS for the Transaction-Explorers
transactionExplorer_mainnet="https://cardanoscan.io/transaction/"
transactionExplorer_testnet="https://explorer.cardano-testnet.iohkdev.io/en/transaction?id="

#Pool-Importhelper Live-API-Helper
poolImportAPI="https://api.crypto2099.io/v1/pool/"

#Overwrite variables via env file if present
scriptDir=$(dirname "$0" 2> /dev/null)
if [[ -f "${scriptDir}/common.inc" ]]; then source "${scriptDir}/common.inc"; fi
if [[ -f "$HOME/.common.inc" ]]; then source "$HOME/.common.inc"; fi
if [[ -f "common.inc" ]]; then source "common.inc"; fi

#Don't allow to overwrite the needed Versions, so we set it after the overwrite part
minNodeVersion="1.26.2"  #minimum allowed node version for this script-collection version
maxNodeVersion="1.26.2"  #maximum allowed node version, 9.99.9 = no limit so far
minLedgerCardanoAppVersion="2.3.1"  #minimum version for the cardano-app on the Ledger hardwarewallet
minTrezorCardanoAppVersion="2.3.6"  #minimum version for the cardano-app on the Trezor hardwarewallet
minHardwareCliVersion="1.3.0" #minimum version for the cardano-hw-cli

#Set the CARDANO_NODE_SOCKET_PATH for all cardano-cli operations
export CARDANO_NODE_SOCKET_PATH=${socket}

#Set the bc linebreak to a big number so we can work with really biiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiig numbers
export BC_LINE_LENGTH=1000

#Setting online/offline variables and offlineFile default value, versionInfo
if [[ "${offlineMode^^}" == "YES" ]]; then offlineMode=true; onlineMode=false; else offlineMode=false; onlineMode=true; fi
if [[ "${offlineFile}" == "" ]]; then offlineFile="./offlineTransfer.json"; fi
if [[ "${showVersionInfo^^}" == "NO" ]]; then showVersionInfo=false; else showVersionInfo=true; fi
if [[ "${queryTokenRegistry^^}" == "NO" ]]; then queryTokenRegistry=false; else queryTokenRegistry=true; fi


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
if ! exists "${cardanocli}"; then majorError "Path ERROR - Path to cardano-cli is not correct or cardano-cli binaryfile is missing!\nYour current set path is: ${cardanocli}"; exit 1; fi
versionCLI=$(${cardanocli} version 2> /dev/null |& head -n 1 |& awk {'print $2'})
versionCheck "${minNodeVersion}" "${versionCLI}"
if [[ $? -ne 0 ]]; then majorError "Version ${versionCLI} ERROR - Please use a cardano-cli version ${minNodeVersion} or higher !\nOld versions are not supported for security reasons, please upgrade - thx."; exit 1; fi
versionCheck "${versionCLI}" "${maxNodeVersion}"
if [[ $? -ne 0 ]]; then majorError "Version ${versionCLI} ERROR - Please use a cardano-cli version between ${minNodeVersion} and ${maxNodeVersion} !\nOther versions are not supported for compatibility issues, please check if newer scripts are available - thx."; exit 1; fi
if ${showVersionInfo}; then echo -ne "\n\e[0mVersion-Info: \e[32mcli ${versionCLI}\e[0m"; fi

#Check cardano-node only in online mode
if ${onlineMode}; then
	if ! exists "${cardanonode}"; then majorError "Path ERROR - Path to cardano-node is not correct or cardano-node binaryfile is missing!\nYour current set path is: ${cardanocli}"; exit 1; fi
	versionNODE=$(${cardanonode} version 2> /dev/null |& head -n 1 |& awk {'print $2'})
	versionCheck "${minNodeVersion}" "${versionNODE}"
	if [[ $? -ne 0 ]]; then majorError "Version ${versionNODE} ERROR - Please use a cardano-node version ${minNodeVersion} or higher !\nOld versions are not supported for security reasons, please upgrade - thx."; exit 1; fi
	versionCheck "${versionNODE}" "${maxNodeVersion}"
	if [[ $? -ne 0 ]]; then majorError "Version ${versionNODE} ERROR - Please use a cardano-node version between ${minNodeVersion} and ${maxNodeVersion} !\nOther versions are not supported for compatibility issues, please check if newer scripts are available - thx."; exit 1; fi
	if ${showVersionInfo}; then echo -ne " / \e[32mnode ${versionNODE}\e[0m"; fi
fi

#Check bech32 tool if given path is ok, if not try to use the one in the scripts folder
if ! exists "${bech32_bin}"; then
				#Try the one in the scripts folder
				if [[ -f "${scriptDir}/bech32" ]]; then bech32_bin="${scriptDir}/bech32";
				else majorError "Path ERROR - Path to the 'bech32' binary is not correct or 'bech32' binaryfile is missing!\nYou can find it here: https://github.com/input-output-hk/bech32/releases/latest\nThis is needed to show the correct Bech32-Assetformat like 'asset1ee0u29k4xwauf0r7w8g30klgraxw0y4rz2t7xs'."; exit 1; fi
fi

#Display current Mode (online or offline)
if ${showVersionInfo}; then
				if ${offlineMode}; then
							echo -ne "\t\tScripts-Mode: \e[32moffline\e[0m";
						   else
							echo -ne "\t\tScripts-Mode: \e[36monline\e[0m";
							if [ ! -e "${socket}" ]; then echo -ne "\n\n\e[35mWarning: Node-Socket does not exist !\e[0m"; fi
				fi

				if [[ "${magicparam}" == *"testnet"* ]]; then echo -ne "\t\t\e[0mTestnet-Magic: \e[91m$(echo ${magicparam} | cut -d' ' -f 2) \e[0m"; fi

echo
echo
fi

#Check path to genesis files
if [[ ! -f "${genesisfile}" ]]; then majorError "Path ERROR - Path to the shelley genesis file '${genesisfile}' is wrong or the file is missing!"; exit 1; fi
if [[ ! -f "${genesisfile_byron}" ]]; then majorError "Path ERROR - Path to the byron genesis file '${genesisfile_byron}' is wrong or the file is missing!"; exit 1; fi

#-------------------------------------------------------------


#Check if curl, jq, bc and xxd is installed
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

if ! exists xxd; then
          echo -e "\nYou need the little tool 'xxd' !\n"
          echo -e "Install it On Ubuntu/Debian like:\n\e[97msudo apt update && sudo apt -y install xxd\e[0m\n"
          echo -e "Thx! :-)\n"
          exit 2
fi


#-------------------------------------------------------------
#Searching for the temp directory (used for transactions files)
tempDir=$(dirname $(mktemp tmp.XXXX -ut))


#-------------------------------------------------------------
#Setting Mainnet or Testnet Metadata Registry Server & transactionExplorer
if [[ "${magicparam}" == *"mainnet"* ]]; then #mainnet
					   	tokenMetaServer=${tokenMetaServer_mainnet};
						transactionExplorer=${transactionExplorer_mainnet};
					 else #testnet
						tokenMetaServer=${tokenMetaServer_testnet};
						transactionExplorer=${transactionExplorer_testnet};
fi
if [[ ! "${tokenMetaServer: -1}" == "/" ]]; then tokenMetaServer="${tokenMetaServer}/"; fi #make sure the last char is a /


#-------------------------------------------------------
#AddressType check
check_address() {
tmp=$(${cardanocli} address info --address $1 2> /dev/null)
if [[ $? -ne 0 ]]; then echo -e "\e[35mERROR - Unknown address format for address: $1 !\e[0m"; exit 1; fi
}

get_addressType() {
${cardanocli} address info --address $1 2> /dev/null | jq -r .type
}

get_addressEra() {
${cardanocli} address info --address $1 2> /dev/null | jq -r .era
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
			local currentTip=$(${cardanocli} query tip ${magicparam} | jq -r .slot);  #only "slot" instead of "slotNo" since 1.26.0
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
local tmpEra=$(${cardanocli} query tip ${magicparam} | jq -r ".era | select (.!=null)" 2> /dev/null)
if [[ ! "${tmpEra}" == "" ]]; then tmpEra=${tmpEra,,}; else tmpEra="auto"; fi
echo "${tmpEra}"; return 0; #return era in lowercase
}
##Set nodeEra parameter (--shelley-era, --allegra-era, --mary-era, --byron-era or empty)
if ${onlineMode}; then tmpEra=$(get_NodeEra); else tmpEra=$(jq -r ".protocol.era" 2> /dev/null < ${offlineFile}); fi
if [[ ! "${tmpEra}" == "auto" ]]; then nodeEraParam="--${tmpEra}-era"; else nodeEraParam=""; fi
#-------------------------------------------------------


#-------------------------------------------------------
#Converts a raw UTXO query output into the new UTXO JSON style since 1.26.0, but with stringnumbers
generate_UTXO()  #Parameter1=RawUTXO, Parameter2=Address
{

  #Convert given bech32 address into a base16(hex) address, not needed in theses scripts, but to make a true 1:1 copy of the normal UTXO JSON output
  local utxoAddress=$(${cardanocli} address info --address ${2} 2> /dev/null | jq -r .base16); if [[ $? -ne 0 ]]; then local utxoAddress=${2}; fi

  local utxoJSON="{}" #start with a blank JSON skeleton

  while IFS= read -r line; do
  IFS=' ' read -ra utxo_entry <<< "${line}" # utxo_entry array holds entire utxo string
  local utxoHashIndex="${utxo_entry[0]}#${utxo_entry[1]}"
  local utxoAmountLovelaces=${utxo_entry[2]}

  #Build the entry for each UtxoHashIndex
  local utxoJSON=$( jq ".\"${utxoHashIndex}\".address = \"${utxoAddress}\"" <<< ${utxoJSON})
  local utxoJSON=$( jq ".\"${utxoHashIndex}\".value.lovelace = \"${utxoAmountLovelaces}\"" <<< ${utxoJSON})

  #Add the Token entries if tokens available
  if [[ ${#utxo_entry[@]} -gt 4 ]]; then # contains tokens
    local idx=5
    while [[ ${#utxo_entry[@]} -gt ${idx} ]]; do
      local asset_amount=${utxo_entry[${idx}]}
      local asset_hash_name="${utxo_entry[$((idx+1))]}"
      IFS='.' read -ra asset <<< "${asset_hash_name}"
      local asset_policy=${asset[0]}
      local asset_name=${asset[1]}
      #Add the Entry of the Token
      local utxoJSON=$( jq ".\"${utxoHashIndex}\".value.\"${asset_policy}\" += { \"${asset_name}\": \"${asset_amount}\" }" <<< ${utxoJSON})
      local idx=$(( ${idx} + 3 ))
    done
  fi
  echo
done < <(printf "${1}\n" | tail -n +3) #read in from parameter 1 (raw utxo) but cut first two lines
echo "${utxoJSON}"
}
#-------------------------------------------------------

#-------------------------------------------------------
#Cuts out all UTXOs in a mary style UTXO JSON that are not the given UTXO hash ($2)
#The given UTXO hash can be multiple UTXO hashes with the or separator | for egrep
filterFor_UTXO()
{
local inJSON=${1}
local searchUTXO=${2}
local outJSON=${inJSON}
local utxoEntryCnt=$(jq length <<< ${inJSON})
local tmpCnt=0
for (( tmpCnt=0; tmpCnt<${utxoEntryCnt}; tmpCnt++ ))
do
local utxoHashIndex=$(jq -r "keys[${tmpCnt}]" <<< ${inJSON})
if [[ $(echo "${utxoHashIndex}" | egrep "${searchUTXO}" | wc -l) -eq 0 ]]; then local outJSON=$( jq "del (.\"${utxoHashIndex}\")" <<< ${outJSON}); fi
done
echo "${outJSON}"
}
#-------------------------------------------------------

#-------------------------------------------------------
#Convert PolicyID|assetName TokenName into Bech32 format "token1....."
convert_tokenName2BECH() {
        #${1} = policyID | assetName as a HEX String
	#${2} = assetName in ASCII or empty
local tmp_policyID=$(trimString "${1}") #make sure there are not spaces before and after
local tmp_assetName=$(trimString "${2}")
if [[ ! "${tmp_assetName}" == "" ]]; then local tmp_assetName=$(echo -n "${tmp_assetName}" | xxd -b -ps -c 80 | tr -d '\n'); fi

echo -n "${tmp_policyID}${tmp_assetName}" | xxd -r -ps | b2sum -l 160 -b | cut -d' ' -f 1 | ${bech32_bin} asset
}
#-------------------------------------------------------

#-------------------------------------------------------
#Convert ASCII assetName into HEX assetName
convert_assetNameASCII2HEX() {
echo -n "${1}" | xxd -b -ps -c 80 | tr -d '\n'
}
#-------------------------------------------------------

#-------------------------------------------------------
#Convert HEX assetName into ASCII assetName
convert_assetNameHEX2ASCII() {
echo -n "${1}" | xxd -r -ps
}
#-------------------------------------------------------


#-------------------------------------------------------
#Calculate the minimum UTXO value that has to be sent depending on the assets and the minUTXO protocol-parameters
calc_minOutUTXOnew() {
        #${1} = protocol-parameters(json format) content
        #${2} = tx-out string

local protocolParam=${1}
local multiAsset=$(echo ${2} | cut -d'+' -f 2-) #split at the + marks and only keep lovelaces+assets
tmp=$(${cardanocli} transaction calculate-min-value --protocol-params-file <(echo ${protocolParam}) --multi-asset "${multiAsset}" 2> /dev/null)
if [[ $? -ne 0 ]]; then echo -e "\e[35mERROR - Can't calculate minValue for the given tx-out string: ${2} !\e[0m"; exit 1; fi
echo ${tmp} | cut -d' ' -f 2 #Output is "Lovelace xxxxxx", so return the second part
}



#-------------------------------------------------------
#Calculate the minimum UTXO value that has to be sent depending on the assets and the minUTXO protocol-parameters
calc_minOutUTXO() {
        #${1} = protocol-parameters(json format) content
        #${2} = tx-out string

local minUTXOValue=$(jq -r .minUTxOValue <<< ${1})
local minOutUTXO=${minUTXOValue} #preload it with the minUTXOValue (1ADA), will be overwritten if costs are higher

#chain constants, based on the specifications: https://hydra.iohk.io/build/5949624/download/1/shelley-ma.pdf
local k0=0				#coinSize=0 in mary-era, 2 in alonzo-era
local k1=6
local k2=12				#assetSize=12
local k3=28				#pidSize=28
local k4=8				#word=8 bytes
local utxoEntrySizeWithoutVal=27 	#6+txOutLenNoVal(14)+txInLen(7)
local adaOnlyUTxOSize=$((${utxoEntrySizeWithoutVal} + ${k0}))

#split the tx-out string into the assets
IFS='+' read -ra asset_entry <<< "${2}"

if [[ ${#asset_entry[@]} -gt 2 ]]; then #contains assets, do calculations. otherwise leave it at the default value
        local idx=2
	local pidCollector=""    #holds the list of individual policyIDs
	local assetsCollector="" #holds the list of individual assetHases (policyID+assetName)
	local nameCollector=""   #holds the list of individual assetNames(hex format)

        while [[ ${#asset_entry[@]} -gt ${idx} ]]; do

          #separate assetamount from asset_hash(policyID.assetName)
          IFS=' ' read -ra asset <<< "${asset_entry[${idx}]}"
          local asset_hash=${asset[1]}

          #split asset_hash_name into policyID and assetName(hex)
          #later when we change the tx-out format to full hex format
          #this can be simplified into a stringsplit
          IFS='.' read -ra asset_split <<< "${asset_hash}"
          local asset_hash_policy=${asset_split[0]}
          local asset_hash_hexname=$(echo -n "${asset_split[1]}" | xxd -b -ps -c 80 | tr -d '\n')

	  #collect the entries in individual lists to sort them later
	  local pidCollector="${pidCollector}${asset_hash_policy}\n"
	  local assetsCollector="${assetsCollector}${asset_hash_policy}${asset_hash_hexname}\n"
	  if [[ ! "${asset_hash_hexname}" == "" ]]; then local nameCollector="${nameCollector}${asset_hash_hexname}\n"; fi

          local idx=$(( ${idx} + 1 ))
        done

       #get uniq entries
       local numPIDs=$(echo -ne "${pidCollector}" | sort | uniq | wc -l)
       local numAssets=$(echo -ne "${assetsCollector}" | sort | uniq | wc -l)

       #get sumAssetNameLengths
       local sumAssetNameLengths=$(( $(echo -ne "${nameCollector}" | sort | uniq | tr -d '\n' | wc -c) / 2 )) #divide consolidated hexstringlength by 2 because 2 hex chars -> 1 byte

       #calc the utxoWords
       local roundupBytesToWords=$(bc <<< "scale=0; ( ${numAssets}*${k2} + ${sumAssetNameLengths} + ${numPIDs}*${k3} + (${k4}-1) ) / ${k4}")
       local tokenBundleSize=$(( ${k1} + ${roundupBytesToWords} ))

       #calc minAda needed with assets
       local minAda=$(( $(bc <<< "scale=0; ${minUTXOValue} / ${adaOnlyUTxOSize}") * ( ${utxoEntrySizeWithoutVal} + ${tokenBundleSize} ) ))

       #if minAda is higher than the bottom minUTXOValue, set the output to the higher value (max function)
       if [[ ${minAda} -gt ${minUTXOValue} ]]; then minOutUTXO=${minAda}; fi
fi

echo ${minOutUTXO} #return the minOutUTXO value for the txOut-String with or without assets
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

local tokenMetaCnt=$(jq -r ".tokenMetaServer | length" <<< ${offlineJSON})
if [[ ${tokenMetaCnt} -gt 0 ]]; then echo -e "\e[0m  TokenMeta-Entries:\e[32m ${tokenMetaCnt}\e[0m"; fi

if ${offlineMode}; then
			echo -ne "\e[0m    Online Versions:"
			local versionTmp=$(jq -r ".general.onlineCLI" <<< ${offlineJSON}); if [[ "${versionTmp}" == null ]]; then versionTmp="-.--.-"; fi; echo -ne "\e[32m cli ${versionTmp}\e[0m"
			local versionTmp=$(jq -r ".general.onlineNODE" <<< ${offlineJSON}); if [[ "${versionTmp}" == null ]]; then versionTmp="-.--.-"; fi; echo -e " /\e[32m node ${versionTmp}\e[0m"
		   else
			echo -ne "\e[0m    Offline Version:"
			local versionTmp=$(jq -r ".general.offlineCLI" <<< ${offlineJSON}); if [[ "${versionTmp}" == null ]]; then versionTmp="-.--.-"; fi; echo -e "\e[32m cli ${versionTmp}\e[0m"
fi
echo
local addressCnt=$(jq -r ".address | length" <<< ${offlineJSON})
echo -e "\e[0m    Address-Entries:\e[32m ${addressCnt}\e[0m\t";

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
                            else
                                offileJSON=null
                                echo -e "\e[35mERROR - '$(basename ${offlineFile})' is not present, please generate a valid offlineJSON first in onlinemode.\e[0m\n"; exit 1;

fi
}
#-------------------------------------------------------

#-------------------------------------------------------
#Get the hardware-wallet ready, check the cardano-app version
start_HwWallet() {

if [[ "$(which ${cardanohwcli})" == "" ]]; then echo -e "\n\e[35mError - cardano-hw-cli binary not found, please install it first and set the path to it correct in the 00_common.sh, common.inc or $HOME/.common.inc !\e[0m\n"; exit 1; fi

versionHWCLI=$(${cardanohwcli} version 2> /dev/null |& head -n 1 |& awk {'print $6'})
versionCheck "${minHardwareCliVersion}" "${versionHWCLI}"
if [[ $? -ne 0 ]]; then majorError "Version ERROR - Please use a cardano-hw-cli version ${minHardwareCliVersion} or higher !\nYour version ${versionHWCLI} is no longer supported for security reasons or features, please upgrade - thx."; exit 1; fi

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


