#!/bin/bash
unset magicparam network addrformat

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
catalyst_toolbox_bin="./catalyst-toolbox"	#Path to your catalyst-toolbox binary you wanna use. If your binary is present in the Path just set it to "catalyst-toolbox" without the "./" infront
voter_registration_bin="./voter-registration"	#Path to your voter-registration binary you wanna use. If your binary is present in the Path just set it to "voter-registration" without the "./" infront
cardanosigner="./cardano-signer"		#Path to your cardano-signer binary you wanna use. If your binary is present in the Path just set it to "cardano-signer" without the "./" infront
cardanoaddress="./cardano-address"		#Path to your cardano-address binary you wanna use. If your binary is present in the Path just set it to "cardano-address" without the "./" infront


#--------- Only needed if you wanna use a hardware key (Ledger/Trezor) too, please read the instructions on the github repo README :-)
cardanohwcli="cardano-hw-cli"      #Path to your cardano-hw-cli binary you wanna use. If your binary is present in the Path just set it to "cardano-hw-cli" without the "./" infront


#--------- Only needed if you wanna generate the right format for the NativeAsset Metadata Registry
cardanometa="./token-metadata-creator" #Path to your token-metadata-creator binary you wanna use. If present in the Path just set it to "token-metadata-creator" without the "./" infront

#--------- Only needed if you wanna change the BlockChain from the Mainnet to a Testnet Chain Setup, uncomment the network you wanna use by removing the leading #
#          Using a preconfigured network name automatically loads and sets the magicparam, addrformat and byronToShelleyEpochs parameters, also API-URLs, etc.

#network="Mainnet" 	#Mainnet (Default)
#network="PreProd" 	#PreProd Testnet (new default Testnet)
#network="Preview"	#Preview Testnet (new fast Testnet)
#network="Legacy"	#Legacy TestChain (formally known as Public-Testnet)
#network="GuildNet"	#GuildNet Testnet

#--------- You can of course specify your own values by setting a new network=, magicparam=, addrformat= and byronToShelleyEpochs= parameter :-)
#network="new-devchain"; magicparam="--testnet-magic 11111"; addrformat="--testnet-magic 11111"; byronToShelleyEpochs=6 #Custom Chain settings



#--------- some other stuff -----
showVersionInfo="yes"		#yes/no to show the version info and script mode on every script call
queryTokenRegistry="yes"	#yes/no to query each native asset/token on the token registry server live
cropTxOutput="yes"		#yes/no to crop the unsigned/signed txfile outputs on transactions to a max. of 4000chars











































##############################################################################################################################
#
# 'DONT EDIT BELOW THIS LINE !!!'
#
##############################################################################################################################


#-------------------------------------------------------
#DisplayMajorErrorMessage
majorError() {
echo -e "\e[97m\n" > $(tty)
echo -e "         _ ._  _ , _ ._\n        (_ ' ( \`  )_  .__)\n      ( (  (    )   \`)  ) _)\n     (__ (_   (_ . _) _) ,__)\n         \`~~\`\\ ' . /\`~~\`\n              ;   ;\n              /   \\ \n_____________/_ __ \\___________________________________________\n" > $(tty)
echo -e "\e[35m${1}\n\nIf you think all is right at your side, please check the GitHub repo if there\nis a newer version/bugfix available, thx: https://github.com/gitmachtl/scripts\e[0m\n" > $(tty); exit 1;
}
#-------------------------------------------------------

#API Endpoints and Network-Settings for the various chains

network=${network:-mainnet} #sets the default network to mainnet, if not set otherwise
unset _magicparam _addrformat _byronToShelleyEpochs _tokenMetaServer _transactionExplorer _koiosAPI _adahandlePolicyID

#Load and overwrite variables via env files if present
scriptDir=$(dirname "$0" 2> /dev/null)
if [[ -f "${scriptDir}/common.inc" ]]; then source "${scriptDir}/common.inc"; fi
if [[ -f "$HOME/.common.inc" ]]; then source "$HOME/.common.inc"; fi
if [[ -f "common.inc" ]]; then source "common.inc"; fi

#Set the list of preconfigured networknames
networknames="mainnet, preprod, preview, legacy, vasildev"

#Check if there are testnet parameters set but network is still "mainnet"
if [[ "${magicparam}${addrformat}" == *"testnet"* && "${network,,}" == "mainnet" ]]; then majorError "Mainnet selected, but magicparam(${magicparam})/addrformat(${addrformat}) have testnet settings!\n\nPlease select the right chain in the '00_common.sh', '${scriptDir}/common.inc', '$HOME/.common.inc' or './common.inc' file by setting the value for the parameter network to one of the preconfiged networknames:\n${networknames}\n\nThere is no need anymore, to set the parameters magicparam/addrformat/byronToShelleyEpochs for the preconfigured networks. Its enough to specify it for example with: network=\"preprod\"\nOf course you can still set them and also set a custom networkname like: network=\"vasil-dev\""; exit 1; fi


#Preload the variables, based on the "network" name
case "${network,,}" in

	"mainnet" )
		network="Mainnet"	#nicer name for info-display
		_magicparam="--mainnet"	#MagicParameter Extension --mainnet / --testnet-magic xxx
		_addrformat="--mainnet"	#Addressformat for the address generation, normally the same as magicparam
		_byronToShelleyEpochs=208	#The number of Byron Epochs before the Chain forks to Shelley-Era
		_tokenMetaServer="https://tokens.cardano.org/metadata/"		#Token Metadata API URLs -> autoresolve into ${tokenMetaServer}/
		_transactionExplorer="https://cardanoscan.io/transaction/" 	#URLS for the Transaction-Explorers -> autoresolve into ${transactionExplorer}/
		_koiosAPI="https://api.koios.rest/api/v0"	#Koios-API URLs -> autoresolve into ${koiosAPI}
		_adahandlePolicyID="f0ff48bbb7bbe9d59a40f1ce90e9e9d0ff5002ec48f232b49ca0fb9a"	#PolicyIDs for the adaHandles -> autoresolve into ${adahandlePolicyID}
		;;


	"legacy"|"testnet" )
		network="Legacy"
		_magicparam="--testnet-magic 1097911063"
		_addrformat="--testnet-magic 1097911063"
		_byronToShelleyEpochs=74
		_tokenMetaServer="https://metadata.cardano-testnet.iohkdev.io/metadata"
		_transactionExplorer="https://testnet.cexplorer.io/tx"
		_koiosAPI=
		_adahandlePolicyID="8d18d786e92776c824607fd8e193ec535c79dc61ea2405ddf3b09fe3"
		;;


	"preprod"|"pre-prod" )
		network="PreProd"
		_magicparam="--testnet-magic 1"
		_addrformat="--testnet-magic 1"
		_byronToShelleyEpochs=4
		_tokenMetaServer="https://metadata.cardano-testnet.iohkdev.io/metadata"
		_transactionExplorer="https://testnet.cardanoscan.io/transaction"
		_koiosAPI="https://preprod.koios.rest/api/v0"
		_adahandlePolicyID="f0ff48bbb7bbe9d59a40f1ce90e9e9d0ff5002ec48f232b49ca0fb9a"	#PolicyIDs for the adaHandles -> autoresolve into ${adahandlePolicyID}
		;;


	"preview"|"pre-view" )
		network="Preview"
		_magicparam="--testnet-magic 2"
		_addrformat="--testnet-magic 2"
		_byronToShelleyEpochs=0
		_tokenMetaServer="https://metadata.cardano-testnet.iohkdev.io/metadata"
		_transactionExplorer="https://preview.cexplorer.io/tx"
		_koiosAPI="https://preview.koios.rest/api/v0"
		_adahandlePolicyID="f0ff48bbb7bbe9d59a40f1ce90e9e9d0ff5002ec48f232b49ca0fb9a"	#PolicyIDs for the adaHandles -> autoresolve into ${adahandlePolicyID}
		;;


	"guildnet"|"guild-net" )
		network="GuildNet"
		_magicparam="--testnet-magic 141"
		_addrformat="--testnet-magic 141"
		_byronToShelleyEpochs=2
		_tokenMetaServer="https://metadata.cardano-testnet.iohkdev.io/metadata"
		_transactionExplorer=
		_koiosAPI="https://guild.koios.rest/api/v0"
		_adahandlePolicyID="f0ff48bbb7bbe9d59a40f1ce90e9e9d0ff5002ec48f232b49ca0fb9a"	#PolicyIDs for the adaHandles -> autoresolve into ${adahandlePolicyID}
		;;

esac


#Assign the values to the used variables if not defined before with an other value
magicparam=${magicparam:-"${_magicparam}"}
addrformat=${addrformat:-"${_addrformat}"}
byronToShelleyEpochs=${byronToShelleyEpochs:-"${_byronToShelleyEpochs}"}
tokenMetaServer=${tokenMetaServer:-"${_tokenMetaServer}"}
transactionExplorer=${transactionExplorer:-"${_transactionExplorer}"}
koiosAPI=${koiosAPI:-"${_koiosAPI}"}
adahandlePolicyID=${adahandlePolicyID:-"${_adahandlePolicyID}"}


#Check about the / at the end of the URLs
if [[ "${tokenMetaServer: -1}" == "/" ]]; then tokenMetaServer=${tokenMetaServer%?}; fi #make sure the last char is not a /
if [[ "${koiosAPI: -1}" == "/" ]]; then koiosAPI=${koiosAPI%?}; fi #make sure the last char is not a /
if [[ "${transactionExplorer: -1}" == "/" ]]; then transactionExplorer=${transactionExplorer%?}; fi #make sure the last char is not a /


#Check about the needed chain params
if [[ "${magicparam}" == "" || ${addrformat} == "" ||  ${byronToShelleyEpochs} == "" ]]; then majorError "The 'magicparam', 'addrformat' or 'byronToShelleyEpochs' is not set!\nOr maybe you have set the wrong parameter network=\"${network}\" ?\nList of preconfigured network-names: ${networknames}"; exit 1; fi

#Don't allow to overwrite the needed Versions, so we set it after the overwrite part
minNodeVersion="1.35.4"  #minimum allowed node version for this script-collection version
maxNodeVersion="9.99.9"  #maximum allowed node version, 9.99.9 = no limit so far
minLedgerCardanoAppVersion="4.1.2"  #minimum version for the cardano-app on the Ledger HW-Wallet
minTrezorCardanoAppVersion="2.5.2"  #minimum version for the firmware on the Trezor HW-Wallet
minHardwareCliVersion="1.12.0" #minimum version for the cardano-hw-cli

#Set the CARDANO_NODE_SOCKET_PATH for all cardano-cli operations
export CARDANO_NODE_SOCKET_PATH=${socket}

#Set the bc linebreak to a big number so we can work with really biiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiig numbers
export BC_LINE_LENGTH=1000

#Setting online/offline variables and offlineFile default value, versionInfo, tokenRegistryquery, tx output cropping to boolean values
if [[ "${offlineMode^^}" == "YES" ]]; then offlineMode=true; onlineMode=false; else offlineMode=false; onlineMode=true; fi
if [[ "${offlineFile}" == "" ]]; then offlineFile="./offlineTransfer.json"; fi
if [[ "${showVersionInfo^^}" == "NO" ]]; then showVersionInfo=false; else showVersionInfo=true; fi
if [[ "${queryTokenRegistry^^}" == "NO" ]]; then queryTokenRegistry=false; else queryTokenRegistry=true; fi
if [[ "${cropTxOutput^^}" == "NO" ]]; then cropTxOutput=false; else cropTxOutput=true; fi


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
				else majorError "Path ERROR - Path to the 'bech32' binary is not correct or 'bech32' binaryfile is missing!\nYou can find it here: https://github.com/input-output-hk/bech32/releases/latest\nThis is needed to calculate the correct Bech32-Assetformat like 'asset1ee0u29k4xwauf0r7w8g30klgraxw0y4rz2t7xs'."; exit 1; fi
fi

#Display current Mode (online or offline)
if ${showVersionInfo}; then
				if ${offlineMode}; then
							echo -ne "\t\tScripts-Mode: \e[32moffline\e[0m";
						   else
							echo -ne "\t\tScripts-Mode: \e[36monline\e[0m";
							if [ ! -e "${socket}" ]; then echo -ne "\n\n\e[35mWarning: Node-Socket does not exist !\e[0m"; fi
				fi

				if [[ "${magicparam}" == *"mainnet"* ]]; then
					echo -ne "\t\t\e[32mMainnet\e[0m";
				else
					echo -ne "\t\t\e[91mTestnet: ${network} (magic $(echo ${magicparam} | awk {'print $2'}))\e[0m";
				fi

echo
echo
fi

#-------------------------------------------------------------
#Check path to genesis files
if [[ ! -f "${genesisfile}" ]]; then majorError "Path ERROR - Path to the shelley genesis file '${genesisfile}' is wrong or the file is missing!"; exit 1; fi
if [[ ! -f "${genesisfile_byron}" ]]; then majorError "Path ERROR - Path to the byron genesis file '${genesisfile_byron}' is wrong or the file is missing!"; exit 1; fi



#-------------------------------------------------------------
#Check if curl, jq, bc and xxd is installed
if ! exists curl; then echo -e "\e[33mYou need the little tool 'curl', its needed to fetch online data !\n\nInstall it on Ubuntu/Debian like:\n\e[97msudo apt update && sudo apt -y install curl\n\n\e[33mThx! :-)\e[0m\n"; exit 2; fi
if ! exists jq; then echo -e "\e[33mYou need the little tool 'jq', its needed to do the json processing !\n\nInstall it on Ubuntu/Debian like:\n\e[97msudo apt update && sudo apt -y install jq\n\n\e[33mThx! :-)\e[0m\n"; exit 2; fi
if ! exists bc; then echo -e "\e[33mYou need the little tool 'bc', its needed to do larger number calculations !\n\nInstall it on Ubuntu/Debian like:\n\e[97msudo apt update && sudo apt -y install bc\n\n\e[33mThx! :-)\e[0m\n"; exit 2; fi
if ! exists xxd; then echo -e "\e[33mYou need the little tool 'xxd', its needed to convert hex strings !\n\nInstall it on Ubuntu/Debian like:\n\e[97msudo apt update && sudo apt -y install xxd\n\n\e[33mThx! :-)\e[0m\n"; exit 2; fi


#-------------------------------------------------------------
#Searching for the temp directory (used for transactions files)
tempDir=$(dirname $(mktemp -ut tmp.XXXX))




#-------------------------------------------------------
#AddressType check
check_address() {
tmp=$(${cardanocli} address info --address $1 2> /dev/null)
if [[ $? -ne 0 ]]; then echo -e "\e[35mERROR - Unknown address format for address: $1 !\e[0m"; exit 1; fi
era=$(jq -r .era <<< ${tmp} 2> /dev/null)
if [[ "${era^^}" == "BYRON" ]]; then echo -e "\e[33mINFO - Byron addresses are only supported as a destination address!\e[0m\n"; fi
}

get_addressType() {
${cardanocli} address info --address $1 2> /dev/null | jq -r .type
}

get_addressEra() {
${cardanocli} address info --address $1 2> /dev/null | jq -r .era
}

addrTypePayment="payment"
addrTypeStake="stake"

#-------------------------------------------------------
#AdaHandle Format check (exits with true or false)
checkAdaHandleFormat() {
	#AdaHandles with optional SubHandles
	if [[ "${1,,}" =~ ^\$[a-z0-9_.-]{1,15}(@[a-z0-9_.-]{1,15})?$ ]]; then true; else false; fi
}


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
#Subroutine for password interaction
ask_pass() {
 	local pass #pass variable only lives within this function
	echo -ne "${1}: " > $(tty) #redirect to the tty output
	IFS= read -s pass #read in the password but don't show it
	local hidden=$(sed 's/./*/g' <<< ${pass})
	echo -ne "${hidden}" > $(tty) #show stars for the chars
	echo -n "${pass}" #pass the password to the calling instance
	unset pass #unset the variable
}
#-------------------------------------------------------




#-------------------------------------------------------
#Subroutines to set read/write flags for important files
file_lock()
{
if [ -f "$1" ]; then chmod 400 "$1"; fi
}

file_unlock()
{
if [ -f "$1" ]; then chmod 600 "$1"; fi
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
			local currentTip=$(${cardanocli} query tip ${magicparam} 2> /dev/null | jq -r .slot 2> /dev/null);  #only "slot" instead of "slotNo" since 1.26.0

			#if the return is blank (bug in the cli), then retry 2 times. if failing again, exit with a majorError
			if [[ "${currentTip}" == "" ]]; then local currentTip=$(${cardanocli} query tip ${magicparam} 2> /dev/null | jq -r .slot 2> /dev/null);
				if [[ "${currentTip}" == "" ]]; then local currentTip=$(${cardanocli} query tip ${magicparam} 2> /dev/null | jq -r .slot 2> /dev/null);
					if [[ "${currentTip}" == "" ]]; then majorError "query tip return from cardano-cli failed"; exit 1; fi
				fi
			fi
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
echo $(( $(get_currentTip) + 100000 )) #100000 so a little over a day to have time to collect witnesses and transmit the transaction
}
#-------------------------------------------------------

#-------------------------------------------------------
#Subroutines to check the syncState of the node
get_currentSync()
{
if ${onlineMode}; then
			local currentSync=$(${cardanocli} query tip ${magicparam} 2> /dev/null | jq -r .syncProgress 2> /dev/null);

			#if the return is blank (bug in the cli), then retry 2 times. if failing again, exit with a majorError
			if [[ "${currentSync}" == "" ]]; then local currentSyncp=$(${cardanocli} query tip ${magicparam} 2> /dev/null | jq -r .syncProgress 2> /dev/null);
				if [[ "${currentSync}" == "" ]]; then local currentTip=$(${cardanocli} query tip ${magicparam} 2> /dev/null | jq -r .syncProgress 2> /dev/null);
					if [[ "${currentSync}" == "" ]]; then majorError "query tip return from cardano-cli failed"; exit 1; fi
				fi
			fi

			if [[ ${currentSync} == "100.00" ]]; then echo "synced"; else echo "unsynced"; fi

		  else
			echo "offline"
fi
}
#-------------------------------------------------------



#-------------------------------------------------------
#Displays an Errormessage if parameter is not 0
checkError()
{
if [[ $1 -ne 0 ]]; then echo -e "\n\n\e[35mERROR (Code $1) !\e[0m\n"; exit $1; fi
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
local tmpEra=$(${cardanocli} query tip ${magicparam} 2> /dev/null | jq -r ".era | select (.!=null)" 2> /dev/null)
if [[ ! "${tmpEra}" == "" ]]; then tmpEra=${tmpEra,,}; else tmpEra="auto"; fi
echo "${tmpEra}"; return 0; #return era in lowercase
}
##Set nodeEra parameter ( --byron-era, --shelley-era, --allegra-era, --mary-era, --alonzo-era, --babbage-era or empty)
if ${onlineMode}; then tmpEra=$(get_NodeEra); else tmpEra=$(jq -r ".protocol.era" 2> /dev/null < ${offlineFile}); fi
if [[ ! "${tmpEra}" == "auto" ]]; then nodeEraParam="--${tmpEra}-era"; else nodeEraParam=""; fi

#Temporary fix to lock the transaction build-raw to alonzo era for
#Hardware-Wallet operations. Babbage-Era is not yet supported, so we will lock this for now
#if [[ "${nodeEraParam}" == "" ]] || [[ "${nodeEraParam}" == "--babbage-era" ]]; then nodeEraParam="--alonzo-era"; fi


#-------------------------------------------------------



#-------------------------------------------------------
#Converts a raw UTXO query output into the new UTXO JSON style since 1.26.0, but with stringnumbers
#Building the JSON structure from scratch, way faster than using jq for it
generate_UTXO()  #Parameter1=RawUTXO, Parameter2=Address
{

  #Convert given bech32 address into a base16(hex) address, not needed in theses scripts, but to make a true 1:1 copy of the normal UTXO JSON output
  #local utxoAddress=$(${cardanocli} address info --address ${2} 2> /dev/null | jq -r .base16); if [[ $? -ne 0 ]]; then local utxoAddress=${2}; fi
  local utxoAddress=${2}
  local utxoJSON="{" #start with a blank JSON skeleton and an open {

  while IFS= read -r line; do
  IFS=' ' read -ra utxo_entry <<< "${line}" # utxo_entry array holds entire utxo string

  local utxoHashIndex="${utxo_entry[0]}#${utxo_entry[1]}"

  #There are lovelaces on the UTXO -> check if the name is "lovelace" or if there are just 3 arguments
  if [[ "${utxo_entry[3]}" == "lovelace" ]] || [[ ${#utxo_entry[@]} -eq 3 ]]; then
                                                local idx=5; #normal indexstart for the next checks
                                                local utxoAmountLovelaces=${utxo_entry[2]};
                                              else
                                                local idx=2; #earlier indexstart, because no lovelaces present
                                                local utxoAmountLovelaces=0;
  fi

  #Build the entry for each UtxoHashIndex, start with the hash and the entry for the address and the lovelaces
  local utxoJSON+="\"${utxoHashIndex}\": { \"address\": \"${utxoAddress}\", \"value\": { \"lovelace\": \"${utxoAmountLovelaces}\""

  #value part is open
  local value_open=true

  local idxCompare=$(( ${idx} - 1 ))
  local old_asset_policy=""
  local policy_open=false

  #Add the Token entries if tokens available, also check for data (script) entries
  if [[ ${#utxo_entry[@]} -gt ${idxCompare} ]]; then # contains tokens

    while [[ ${#utxo_entry[@]} -gt ${idx} ]]; do  #check if there are more entries, and the amount is a number
      local next_entry=${utxo_entry[${idx}]}

      #if the next entry is a number -> process asset/tokendata
      if [[ "${next_entry}" =~ ^[0-9]+$ ]]; then
              local asset_amount=${next_entry}
              local asset_hash_name="${utxo_entry[$((idx+1))]}"
              IFS='.' read -ra asset <<< "${asset_hash_name}"
              local asset_policy=${asset[0]}

	      #Open up a policy if it is a different one
	      if [[ "${asset_policy}" != "${old_asset_policy}" ]]; then #open up a new policy
			if ${policy_open}; then local utxoJSON="${utxoJSON%?}}"; fi #close the previous policy first and remove the last , from the last assetname entry of the previous policy
			local utxoJSON+=", \"${asset_policy}\": {"
			local policy_open=true
			local old_asset_policy=${asset_policy}
	      fi

              local asset_name=${asset[1]}
              #Add the Entry of the Token
	      local utxoJSON+="\"${asset_name}\": \"${asset_amount}\"," # the  , will be deleted when the policy part closes
              local idx=$(( ${idx} + 3 ))

     #if its a data entry, add the datumhash key-field to the json output
     elif [[ "${next_entry}" == "TxOutDatumHash" ]] && [[ "${utxo_entry[$((idx+1))]}" == *"Data"* ]]; then
	      if ${policy_open}; then local utxoJSON="${utxoJSON%?}}"; local policy_open=false; fi #close the previous policy first and remove the last , from the last assetname entry of the previous policy
	      if ${value_open}; then local utxoJSON+="}"; local value_open=false; fi #close the open value part
              local data_entry_hash=${utxo_entry[$((idx+2))]}
	      #Add the Entry for the data(datumhash)
              local utxoJSON+=",\"datumhash\": \"${data_entry_hash//\"/}\""
              local idx=$(( ${idx} + 4 ))

     #stop the decoding if an entry related to a "Datum" is found that is not the "TxOutDatumHash" from above, can be extended in the future if needed
     elif [[ "${next_entry^^}" == *"DATUM"* ]]; then break

     else
              local idx=$(( ${idx} + 1 ))  #go to the next entry of the array
     fi
    done
  fi

  #close policy if still open
  if ${policy_open}; then local utxoJSON="${utxoJSON%?}}"; fi #close the previous policy first and remove the last char "," from the last assetname entry of the previous policy

  #close value part if still open
  if ${value_open}; then local utxoJSON+="}"; fi #close the open value part

  #close the utxo part
  local utxoJSON+="},"  #the last char "," will be deleted at the end

done < <(printf "${1}\n" | tail -n +3) #read in from parameter 1 (raw utxo) but cut first two lines

  #close the whole json but delete the last char "," before that. do it only if there are entries present (length>1), else return an empty json
  if [[ ${#utxoJSON} -gt 1 ]]; then echo "${utxoJSON%?}}"; else echo "{}"; fi;

}
#-------------------------------------------------------



#-------------------------------------------------------
#Cuts out all UTXOs in a mary style UTXO JSON that are not the given UTXO hash ($2)
#The given UTXO hash can be multiple UTXO hashes with the or separator | for egrep
filterFor_UTXO_old()
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
#Cuts out all UTXOs in a mary style UTXO JSON that are not the given UTXO hash ($2)
#The given UTXO hash can be multiple UTXO hashes with the separator |
filterFor_UTXO()
{
local inJSON=${1}
local searchUTXO=${2}
local outJSON="{}"

IFS='|' read -ra searchUTXOs <<< "${searchUTXO}" #split the given utxos on the | separator
local noOfSearchUTXOs=${#searchUTXOs[@]}
for (( tmpCnt=0; tmpCnt<${noOfSearchUTXOs}; tmpCnt++ ))
do
	local utxoHashIndex=${searchUTXOs[${tmpCnt}]} #the current hashindex
	local sourceUTXO=$(jq -r .\"${utxoHashIndex}\" <<< ${inJSON}) #the hashindex of the source json
	if [[ "${sourceUTXO}" != "null" ]]; then local outJSON=$( jq ". += { \"${utxoHashIndex}\": ${sourceUTXO} }" <<< ${outJSON}); fi
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

#echo -n "${tmp_policyID}${tmp_assetName}" | xxd -r -ps | b2sum -l 160 -b | cut -d' ' -f 1 | ${bech32_bin} asset
echo -n "${tmp_policyID}${tmp_assetName}" | xxd -r -ps | b2sum -l 160 -b | awk {'print $1'} | ${bech32_bin} asset
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
#Convert HEX assetName into ASCII assetName. If possible return ".assetName" else return just the HEX assetName without a leading point'.'
convert_assetNameHEX2ASCII_ifpossible() {
if [[ "${1}" =~ ^(..){0,}00(.+)?$ ]]; then echo -n "${1}"; #if the given hexstring contains a nullbyte -> return the hexstring
else
     local tmpAssetName=$(echo -n "${1}" | xxd -r -ps)
     if [[ "${tmpAssetName}" == "${tmpAssetName//[^[:alnum:]]/}" ]]; then echo -n ".${tmpAssetName}"; else echo -n "${1}"; fi
fi
}
#-------------------------------------------------------


#-------------------------------------------------------
#Calculate the minimum UTXO value that has to be sent depending on the assets and the minUTXO protocol-parameters
calc_minOutUTXOcli() {
        #${1} = protocol-parameters(json format) content
        #${2} = tx-out string

local protocolParam=${1}
###local multiAsset=$(echo ${2} | cut -d'+' -f 3-) #split at the + marks and only keep assets
tmp=$(${cardanocli} transaction calculate-min-required-utxo ${nodeEraParam} --protocol-params-file <(echo "${protocolParam}") --tx-out "${2}" 2> /dev/null)

if [[ $? -ne 0 ]]; then echo -e "\e[35mERROR - Can't calculate minValue for the given tx-out string: ${2} !\e[0m"; exit 1; fi
echo ${tmp} | cut -d' ' -f 2 #Output is "Lovelace xxxxxx", so return the second part
}


#-------------------------------------------------------
#Calculate the minimum UTXO value that has to be sent depending on the assets and the protocol-parameters
calc_minOutUTXO() {

        #${1} = protocol-parameters(json format) content
        #${2} = tx-out string

local protocolParam=${1}
IFS='+' read -ra asset_entry <<< "${2}" #split the tx-out string into address, lovelaces, assets (read it into asset_entry array)

#protocol version major
#7=babbage, 5+6=alonzo, 4=mary, 3=allegra, 2=shelley, 0+1=byron
local protocolVersionMajor=$(jq -r ".protocolVersion.major | select (.!=null)" <<< ${protocolParam})


### switch the method of the minOutUTXO calculation depending on the current era, starting with protocolVersionMajor>=7 (babbage)
if [[ ${protocolVersionMajor} -ge 7 ]]; then #7=Babbage and above, new since babbage: CIP-0055 -> minOutUTXO depends on the cbor bytes length

	#chain constants for babbage
	local constantOverhead=160 #constantOverhead=160 bytes set for babbage-era, 158 for mary/alonzo transactions in babbage era

	#Get the destination address in hex format as well as the amount of lovelaces
	#local toAddrHex=$(echo -n "${asset_entry[0]}" | ${bech32_bin} | tr -d '\n')   #this would only work for bech32-shelley addresses
	local toAddrHex=$(${cardanocli} address info --address ${asset_entry[0]} 2> /dev/null | jq -r .base16 | tr -d '\n') #this works for bech32-shelley and even base58-byron addresses
	local toLovelaces=${asset_entry[1]}

	if [[ ${#asset_entry[@]} -eq 2 ]]; then #only lovelaces, no assets


		case ${nodeEraParam,,} in

		*"babbage"* ) #Build the tx-out cbor in babbage-tx format with maps
		local cborStr="" #setup a clear new cbor string variable, will hold the tx-out cbor part
		local cborStr+=$(to_cbor "map" 2) #map 2
		local cborStr+=$(to_cbor "unsigned" 0) #unsigned 0
		local cborStr+=$(to_cbor "bytes" "${toAddrHex}") #toAddr in hex
		local cborStr+=$(to_cbor "unsigned" 1) #unsigned 1
		local cborStr+=$(to_cbor "unsigned" ${toLovelaces}) #amount of lovelaces
		;;

		* ) #Build the tx-out cbor in alonzo/shelley format with array
		local cborStr="" #setup a clear new cbor string variable, will hold the tx-out cbor part
		local cborStr+=$(to_cbor "array" 2) #array 2
		local cborStr+=$(to_cbor "bytes" "${toAddrHex}") #toAddr in hex
		local cborStr+=$(to_cbor "unsigned" ${toLovelaces}) #amount of lovelaces
		;;

		esac


	else #assets involved

		local idx=2
		local pidCollector=""    #holds the list of individual policyIDs
		local assetsCollector="" #holds the list of individual assetHases (policyID+assetName)

	        while [[ ${#asset_entry[@]} -gt ${idx} ]]; do #step thru all given assets

	          #separate assetamount from asset_hash(policyID.assetName)
	          IFS=' ' read -ra asset <<< "${asset_entry[${idx}]}"
	          local asset_amount=${asset[0]}
	          local asset_hash=${asset[1]}

	          #split asset_hash_name into policyID and assetName(hex)
	          local asset_hash_policy=${asset_hash:0:56}
	          local asset_hash_hexname=${asset_hash:57}

		  #collect the entries in individual lists to sort them later
		  local pidCollector+="${asset_hash_policy}\n"
		  local assetsCollector+="amount=${asset_amount} pid=${asset_hash_policy} name=${asset_hash_hexname}\n"

		  local idx=$(( ${idx} + 1 ))

		done

		#only keep unique pids and get the number of each individual pid, also get the number of total individual pids
		local pidCollector=$(echo -ne "${pidCollector}" | sort | uniq -c)
		local numPIDs=$(wc -l <<< "${pidCollector}")


		case ${nodeEraParam,,} in

		*"babbage"* ) #Build the tx-out cbor in babbage-tx format with maps

		local cborStr="" #setup a clear new cbor string variable, will hold the tx-out cbor part
		local cborStr+=$(to_cbor "map" 2) #map 2
		local cborStr+=$(to_cbor "unsigned" 0) #unsigned 0
		local cborStr+=$(to_cbor "bytes" "${toAddrHex}") #toAddr in hex
		local cborStr+=$(to_cbor "unsigned" 1) #unsigned 1
		;;

		* ) #Build the tx-out cbor in alonzo/shelley format with array
		local cborStr="" #setup a clear new cbor string variable, will hold the tx-out cbor part
		local cborStr+=$(to_cbor "array" 2) #array 2
		local cborStr+=$(to_cbor "bytes" "${toAddrHex}") #toAddr in hex
		;;

		esac

		local cborStr+=$(to_cbor "array" 2) #array 2 -> first entry value of lovelaces, second is maps of assets
		local cborStr+=$(to_cbor "unsigned" ${toLovelaces}) #amount of lovelaces

		local cborStr+=$(to_cbor "map" ${numPIDs}) #map x -> number of individual PIDs

		#process each individual pid
		while read pidLine ; do
			local numOfAssets=$(awk {'print $1'} <<< ${pidLine})
			local pidHash=$(awk {'print $2'} <<< ${pidLine})

			local cborStr+=$(to_cbor "bytes" "${pidHash}") #asset pid as byteArray
			local cborStr+=$(to_cbor "map" "${numOfAssets}") #map for number of asset with that pid

			#process each individual asset
			while read assetLine ; do
				local tmpAssetAmount=$(awk {'print $1'} <<< ${assetLine}); local tmpAssetAmount=${tmpAssetAmount:7}
				local tmpAssetHexName=$(awk {'print $3'} <<< ${assetLine}); local tmpAssetHexName=${tmpAssetHexName:5}

					local cborStr+=$(to_cbor "bytes" "${tmpAssetHexName}") #asset name as byteArray
					local cborStr+=$(to_cbor "unsigned" ${tmpAssetAmount}) #amount of this asset

			done < <(echo -e "${assetsCollector}" | grep "pid=${pidHash}")

		done <<< "${pidCollector}"

	fi #only lovelaces or lovelaces + assets

	#We need to get the CostPerByte. This is reported via the protocol-parameters in the utxoCostPerByte or utxoCostPerWord parameter
	local utxoCostPerByte=$(jq -r ".utxoCostPerByte | select (.!=null)" <<< ${protocolParam}); #babbage
	if [[ "${utxoCostPerByte}" == "" ]]; then #if the parameter is not present, use the utxoCostPerWord one. a word is 8 bytes
						local utxoCostPerWord=$(jq -r ".utxoCostPerWord | select (.!=null)" <<< ${protocolParam});
						local utxoCostPerByte=$(( ${utxoCostPerWord} / 8 ))
	fi

	#cborLength is length of cborStr / 2 because of the hexchars (2 chars -> 1 byte)
	minOutUTXO=$(( ( (${#cborStr} / 2) + ${constantOverhead} ) * ${utxoCostPerByte} ))
	echo ${minOutUTXO}
	exit #calculation for babbage is done, leave the function
fi

### if we are here, it was not a babbage style calculation, so lets do it for the other eras
### do the calculation for shelley, allegra, mary, alonzo

#chain constants, based on the specifications: https://hydra.iohk.io/build/5949624/download/1/shelley-ma.pdf
local k0=0                              #coinSize=0 in mary-era, 2 in alonzo-era
local k1=6
local k2=12                             #assetSize=12
local k3=28                             #pidSize=28
local k4=8                              #word=8 bytes
local utxoEntrySizeWithoutVal=27        #6+txOutLenNoVal(14)+txInLen(7)
local adaOnlyUTxOSize=$((${utxoEntrySizeWithoutVal} + ${k0}))

local minUTXOValue=$(jq -r ".minUTxOValue | select (.!=null)" <<< ${protocolParam}); #shelley, allegra, mary
local utxoCostPerWord=$(jq -r ".utxoCostPerWord | select (.!=null)" <<< ${protocolParam}); #alonzo

### switch the method of the minOutUTXO calculation depending on the current era
if [[ ${protocolVersionMajor} -ge 5 ]]; then #5+6=Alonzo, new since alonzo: the k0 parameter increases by 2 compared to the mary one
	adaOnlyUTxOSize=$(( adaOnlyUTxOSize + 2 )); #2 more starting with the alonzo era
	minUTXOValue=$(( ${utxoCostPerWord} * ${adaOnlyUTxOSize} ));
fi

### from here on, the calculation is the same for shelley, allegra, mary, alonzo

#preload it with the minUTXOValue from the parameters, will be overwritten at the end if costs are higher
local minOutUTXO=${minUTXOValue}

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
          local asset_hash_policy=${asset_hash:0:56}
          local asset_hash_hexname=${asset_hash:57}

	  #collect the entries in individual lists to sort them later
	  local pidCollector+="${asset_hash_policy}\n"
	  local assetsCollector+="${asset_hash_policy}${asset_hash_hexname}\n"
	  if [[ ! "${asset_hash_hexname}" == "" ]]; then local nameCollector+="${asset_hash_hexname}\n"; fi

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

       minOutUTXO=${minAda};

fi

echo ${minOutUTXO} #return the minOutUTXO value for the txOut-String with or without assets
}
#-------------------------------------------------------



#-------------------------------------------------------
#to_cbor function
#
# converts different majortypes and there values into a cborHexString
#
to_cbor() {

        # ${1} type: unsigned, negative, bytes, string, array, map, tag
        # ${2} value: unsigned int value or hexstring for bytes

        local type=${1}
        local value="${2}"

        # majortypes
        # unsigned      000x|xxxx       majortype 0	not limited, but above 18446744073709551615 (2^64), the numbers are represented via tag2 + bytearray
        # bytes         010x|xxxx       majortype 2     limited to max. 65535 here
        # array         100x|xxxx       majortype 4     limited to max. 65535 here
        # map           101x|xxxx       majortype 5     limited to max. 65535 here

	# extras - not used yet but implemented for the future
	# negative	001x|xxxx	majortype 1	not limited, but below -18446744073709551616 (-2^64 -1), the numbers are represented via tag3 + bytearray
	# string	011x|xxxx	majortype 3	limited to max. 65535 chars
        # tag           110x|xxxx       majortype 6     limited to max. 65535 here


case ${type} in

	#unsigned - input is an unsigned integer, range is selected via a bc query because bash can't handle big numbers
        unsigned )      if [[ $(bc <<< "${value} < 24") -eq 1 ]]; then printf -v cbor "%02x" $((10#${value})) #1byte total value below 24
                        elif [[ $(bc <<< "${value} < 256") -eq 1 ]]; then printf -v cbor "%04x" $((0x1800 + 10#${value})) #2bytes total: first 0x1800 + 1 lower byte value
                        elif [[ $(bc <<< "${value} < 65536") -eq 1 ]]; then printf -v cbor "%06x" $((0x190000 + 10#${value})) #3bytes total: first 0x190000 + 2 lowerbytes value
                        elif [[ $(bc <<< "${value} < 4294967296") -eq 1 ]]; then printf -v cbor "%10x" $((0x1A00000000 + 10#${value})) #5bytes total: 0x1A00000000 + 4 lower bytes value
                        elif [[ $(bc <<< "${value} < 18446744073709551616") -eq 1 ]]; then local tmp="00$(bc <<< "obase=16;ibase=10;${value}+498062089990157893632")"; cbor="${tmp: -18}" #9bytes total: first 0x1B0000000000000000 + 8 lower bytes value
			#if value does not fit into an 8byte unsigned integer, the cbor representation is tag2(pos.bignum)+bytearray of the value
			else local cbor=$(to_cbor "tag" 2); local tmp="00$(bc <<< "obase=16;ibase=10;${value}")"; tmp=${tmp: -$(( (${#tmp}-1)/2*2 ))}; local cbor+=$(to_cbor "bytes" ${tmp}) #fancy calc to get a leading zero in the hex array if needed
                        fi
                        ;;

	#bytestring - input is a hexstring
        bytes )         local bytesLength=$(( ${#value} / 2 ))  #bytesLength is length of value /2 because of hex encoding (2chars -> 1byte)
                        if [[ ${bytesLength} -lt 24 ]]; then printf -v cbor "%02x${value}" $((0x40 + 10#${bytesLength})) #1byte total 0x40 + lower part value & bytearrayitself
                        elif [[ ${bytesLength} -lt 256 ]]; then printf -v cbor "%04x${value}" $((0x5800 + 10#${bytesLength})) #2bytes total: first 0x4000 + 0x1800 + 1 lower byte value & bytearrayitself
                        elif [[ ${bytesLength} -lt 65536 ]]; then printf -v cbor "%06x${value}" $((0x590000 + 10#${bytesLength})) #3bytes total: first 0x400000 + 0x190000 + 2 lower bytes value & bytearrayitself
                        fi
                        ;;

	#array - input is an unsigned integer
        array )         if [[ ${value} -lt 24 ]]; then printf -v cbor "%02x" $((0x80 + 10#${value})) #1byte total 0x80 + lower part value
                        elif [[ ${value} -lt 256 ]]; then printf -v cbor "%04x" $((0x9800 + 10#${value})) #2bytes total: first 0x8000 + 0x1800 & 1 lower byte value
                        elif [[ ${value} -lt 65536 ]]; then printf -v cbor "%06x" $((0x990000 + 10#${value})) #3bytes total: first 0x800000 + 0x190000 & 2 lower bytes value
                        fi
                        ;;

	#map - input is an unsigned integer
        map )           if [[ ${value} -lt 24 ]]; then printf -v cbor "%02x" $((0xA0 + 10#${value})) #1byte total 0xA0 + lower part value
                        elif [[ ${value} -lt 256 ]]; then printf -v cbor "%04x" $((0xB800 + 10#${value})) #2bytes total: first 0xA000 + 0x1800 & 1 lower byte value
                        elif [[ ${value} -lt 65536 ]]; then printf -v cbor "%06x" $((0xB90000 + 10#${value})) #3bytes total: first 0xA00000 + 0x190000 & 2 lower bytes value
                        fi
                        ;;

	###
	### the following types are not used in these scripts yet, but added to have a more complete function for the future
	###

	#negative - input is a negative unsigned integer, range is selected via a bc query because bash can't handle big numbers
        negative )  local value=$(bc <<< "${value//-/} -1") #negative representation in cbor is the neg. number as a pos. number minus 1, so a -500 will be represented as a 499
			if [[ $(bc <<< "${value} < 24") -eq 1 ]]; then printf -v cbor "%02x" $((0x20 + 10#${value})) #1byte total 0x20 value below 24
                        elif [[ $(bc <<< "${value} < 256") -eq 1 ]]; then printf -v cbor "%04x" $((0x3800 + 10#${value})) #2bytes total: first 0x2000 + 0x1800 + 1 lower byte value
                        elif [[ $(bc <<< "${value} < 65536") -eq 1 ]]; then printf -v cbor "%06x" $((0x390000 + 10#${value})) #3bytes total: first 0x200000 + 0x190000 + 2 lowerbytes value
                        elif [[ $(bc <<< "${value} < 4294967296") -eq 1 ]]; then printf -v cbor "%10x" $((0x3A00000000 + 10#${value})) #5bytes total: 0x2000000000 + 0x1A00000000 + 4 lower bytes value
                        elif [[ $(bc <<< "${value} < 18446744073709551616") -eq 1 ]]; then local tmp="00$(bc <<< "obase=16;ibase=10;${value}+1088357900348863545344")"; cbor="${tmp: -18}" #9bytes total: first 0x3B0000000000000000 + 8 lower bytes value
			#if value does not fit into an 8byte unsigned integer, the cbor representation is tag3(neg.bignum)+bytearray of the value
			else local cbor=$(to_cbor "tag" 3); local tmp="00$(bc <<< "obase=16;ibase=10;${value}")"; tmp=${tmp: -$(( (${#tmp}-1)/2*2 ))}; local cbor+=$(to_cbor "bytes" ${tmp}) #fancy calc to get a leading zero in the hex array if needed
                        fi
                        ;;

	#tag - input is an unsigned integer
        tag )           if [[ ${value} -lt 24 ]]; then printf -v cbor "%02x" $((0xC0 + 10#${value})) #1byte total 0xC0 + lower part value
                        elif [[ ${value} -lt 256 ]]; then printf -v cbor "%04x" $((0xD800 + 10#${value})) #2bytes total: first 0xC000 + 0x1800 & 1 lower byte value
                        elif [[ ${value} -lt 65536 ]]; then printf -v cbor "%06x" $((0xD90000 + 10#${value})) #3bytes total: first 0xC00000 + 0x190000 & 2 lower bytes value
                        fi
                        ;;

	#textstring - input is a utf8-string
        string )        local value=$(echo -ne "${value}" | xxd -p -c 65536 | tr -d '\n') #convert the given string into a hexstring and process it further like a bytearray
			local bytesLength=$(( ${#value} / 2 ))  #bytesLength is length of value /2 because of hex encoding (2chars -> 1byte)
                        if [[ ${bytesLength} -lt 24 ]]; then printf -v cbor "%02x${value}" $((0x60 + 10#${bytesLength})) #1byte total 0x60 + lower part value & bytearrayitself
                        elif [[ ${bytesLength} -lt 256 ]]; then printf -v cbor "%04x${value}" $((0x7800 + 10#${bytesLength})) #2bytes total: first 0x6000 + 0x1800 + 1 lower byte value & bytearrayitself
                        elif [[ ${bytesLength} -lt 65536 ]]; then printf -v cbor "%06x${value}" $((0x790000 + 10#${bytesLength})) #3bytes total: first 0x600000 + 0x190000 + 2 lower bytes value & bytearrayitself
                        fi
                        ;;


esac

echo -n "${cbor^^}" #return the cbor in uppercase
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

local onlyForManu=${1^^}

if [[ "$(which ${cardanohwcli})" == "" ]]; then echo -e "\n\e[35mError - cardano-hw-cli binary not found, please install it first and set the path to it correct in the 00_common.sh, common.inc or $HOME/.common.inc !\e[0m\n"; exit 1; fi

versionHWCLI=$(${cardanohwcli} version 2> /dev/null |& head -n 1 |& awk {'print $6'})
versionCheck "${minHardwareCliVersion}" "${versionHWCLI}"
if [[ $? -ne 0 ]]; then majorError "Version ERROR - Please use a cardano-hw-cli version ${minHardwareCliVersion} or higher !\nYour version ${versionHWCLI} is no longer supported for security reasons or features, please upgrade - thx."; exit 1; fi

echo -ne "\e[33mPlease connect & unlock your Hardware-Wallet, open the Cardano-App on Ledger-Devices (abort with CTRL+C)\e[0m\n\n\033[2A\n"
local tmp=$(${cardanohwcli} device version 2> /dev/stdout)
local pointStr="....."
until [[ "${tmp}" == *"app version"* && ! "${tmp}" == *"undefined"* ]]; do

	if [[ "${tmp}" == *"General error"* ]]; then tmp="Cardano App not opened?"; fi

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

#Check if the function was set to be only available on a specified manufacturer hw wallet
if [ ! "${onlyForManu}" == "" ]  && [ ! "${onlyForManu}" == "${walletManu^^}" ]; then echo -e "\n\e[35mError - This function is NOT available on this type of Hardware-Wallet, only available on a ${onlyForManu} device at the moment!\e[0m\n"; exit 1; fi

case ${walletManu^^} in

	LEDGER ) #For Ledger Hardware-Wallets
		versionCheck "${minLedgerCardanoAppVersion}" "${versionApp}"
		if [[ $? -ne 0 ]]; then majorError "Version ERROR - Please use a Cardano App version ${minLedgerCardanoAppVersion} or higher on your LEDGER Hardware-Wallet!\nOlder versions like your current ${versionApp} are not supported, please upgrade - thx."; exit 1; fi
		echo -ne "\r\033[1A\e[0mCardano App Version \e[32m${versionApp}\e[0m (HW-Cli Version \e[32m${versionHWCLI}\e[0m) found on your \e[32m${walletManu}\e[0m device!\033[K\n\e[32mPlease approve the action on your Hardware-Wallet (abort with CTRL+C) \e[0m... \033[K"
		;;

        TREZOR ) #For Trezor Hardware-Wallets
                versionCheck "${minTrezorCardanoAppVersion}" "${versionApp}"
                if [[ $? -ne 0 ]]; then majorError "Version ERROR - Please use Firmware version ${minTrezorCardanoAppVersion} or higher on your TREZOR Hardware-Wallet!\nOlder versions like your current ${versionApp} are not supported, please upgrade - thx."; exit 1; fi
		echo -ne "\r\033[1A\e[0mFirmware-Version \e[32m${versionApp}\e[0m (HW-Cli Version \e[32m${versionHWCLI}\e[0m) found on your \e[32m${walletManu}\e[0m device!\033[K\n\e[32mPlease approve the action on your Hardware-Wallet (abort with CTRL+C) \e[0m... \033[K"
                ;;

	* ) #For any other Manuf.
		majorError "Only Ledger and Trezor Hardware-Wallets are supported at the moment!"; exit 1;
		;;
esac

}

#-------------------------------------------------------

#-------------------------------------------------------
#Convert the given lovelaces $1 into ada (divide by 1M)
convertToADA() {
#echo $(bc <<< "scale=6; ${1} / 1000000" | sed -e 's/^\./0./') #divide by 1M and add a leading zero if below 1 ada
printf "%'.6f" "${1}e-6" #return in ADA format (with 6 commas)
}


#-------------------------------------------------------
#Get the real bytelength of a given string (for UTF-8 byte check)
byteLength() {
    echo -n "${1}" | wc --bytes
}


#-------------------------------------------------------
#Autocorrection of the TxBody to be in canonical order for HW-Wallet transactions
autocorrect_TxBodyFile() {

local txBodyFile="${1}"
local txBodyTmpFile="${1}-corrected"

#check cardanohwcli presence and version
if [[ "$(which ${cardanohwcli})" == "" ]]; then echo -e "\n\e[35mError - cardano-hw-cli binary not found, please install it first and set the path to it correct in the 00_common.sh, common.inc or $HOME/.common.inc !\e[0m\n"; exit 1; fi
versionHWCLI=$(${cardanohwcli} version 2> /dev/null |& head -n 1 |& awk {'print $6'})
versionCheck "${minHardwareCliVersion}" "${versionHWCLI}"
if [[ $? -ne 0 ]]; then majorError "Version ERROR - Please use a cardano-hw-cli version ${minHardwareCliVersion} or higher !\nYour version ${versionHWCLI} is no longer supported for security reasons or features, please upgrade - thx."; exit 1; fi

#do the correction
#tmp=$(${cardanohwcli} transaction transform-raw --tx-body-file ${txBodyFile} --out-file ${txBodyTmpFile} 2> /dev/stdout) #old default format
tmp=$(${cardanohwcli} transaction transform --tx-file ${txBodyFile} --out-file ${txBodyTmpFile} 2> /dev/stdout) #new cddl format

if [[ $? -ne 0 ]]; then echo -e "\n${tmp}"; exit 1; fi
tmp_lastline=$(echo "${tmp}" | tail -n 1)
if [[ "${tmp_lastline^^}" =~ (ERROR) ]]; then echo -e "\n${tmp}"; exit 1; fi

#ok, no error occured to this point. copy the generated new TxBody file over the original one
mv ${txBodyTmpFile} ${txBodyFile}; if [[ $? -ne 0 ]]; then echo -e "\n\e[35mError: Could not write new TxBody File!"; exit 1; fi

#all went well, now return the lastline output
echo "${tmp_lastline}"; exit 0
}
#-------------------------------------------------------


#-------------------------------------------------------
#Autocorrection of the TxBody to be in canonical order for HW-Wallet transactions
#Also repairs a maybe broken AuxDataHash!
autocorrect_TxBodyFile_withAuxDataHashCorrection() {

local txBodyFile="${1}"
local txBodyTmpFile="${1}-corrected"
local auxHashStatus=""

#check cardanohwcli presence and version
if [[ "$(which ${cardanohwcli})" == "" ]]; then echo -e "\n\e[35mError - cardano-hw-cli binary not found, please install it first and set the path to it correct in the 00_common.sh, common.inc or $HOME/.common.inc !\e[0m\n"; exit 1; fi
versionHWCLI=$(${cardanohwcli} version 2> /dev/null |& head -n 1 |& awk {'print $6'})
versionCheck "${minHardwareCliVersion}" "${versionHWCLI}"
if [[ $? -ne 0 ]]; then majorError "Version ERROR - Please use a cardano-hw-cli version ${minHardwareCliVersion} or higher !\nYour version ${versionHWCLI} is no longer supported for security reasons or features, please upgrade - thx."; exit 1; fi

#search for the auxmetadata and generate the current aux hash from it as a verification.
#this is a fast simple solution by searching for the hexbytes f5d90103 as the mark of the auxdata beginning, there is no deep cbor analysis behind it
local currentAuxHash=$(cat ${txBodyFile} | sed -n "s/.*f5\(d90103.*\)\"/\1/p" | xxd -r -ps | b2sum -l 256 -b | awk {'print $1'}) #holds the expected auxhash
local currentAuxHash=$(cat ${txBodyFile} | sed -n "s/.*\($currentAuxHash\).*/\1/p") #holds the auxhash if it was found in the txcbor as a proof that the auxdata was found correctly

#do the correction
tmp=$(${cardanohwcli} transaction transform --tx-file ${txBodyFile} --out-file ${txBodyTmpFile} 2> /dev/stdout) #new cddl format
if [[ $? -ne 0 ]]; then echo -e "\n${tmp}"; exit 1; fi
tmp_lastline=$(echo "${tmp}" | tail -n 1)
if [[ "${tmp_lastline^^}" =~ (ERROR) ]]; then echo -e "\n${tmp}"; exit 1; fi

#generate the newAuxHash after the canonical order transformation
local newAuxHash=$(cat ${txBodyTmpFile} | sed -n 's/.*f5\(d90103.*\)\"/\1/p' | xxd -r -ps | b2sum -l 256 -b | awk {'print $1'})
if [[ "${currentAuxHash}" != "" && "${currentAuxHash}" != "${newAuxHash}" ]]; then #only do it when the currentAuxHash holds a hash (detection worked) and if the new one is different to the old one
	sed -i "s/${currentAuxHash}/${newAuxHash}/g" ${txBodyTmpFile}; if [ $? -ne 0 ]; then echo -e "\nCouldn't write temporary ${txBodyTmpFile} with a corrected AuxHash!"; exit 1; fi
	local auxHashStatus="\e[91m\nCorrected the AuxHash from '${currentAuxHash}' to '${newAuxHash}' too!"
fi

#ok, no error occured to this point. copy the generated new TxBody file over the original one
mv ${txBodyTmpFile} ${txBodyFile}; if [[ $? -ne 0 ]]; then echo -e "\n\e[35mError: Could not write new TxBody File!"; exit 1; fi

#all went well, now return the lastline output
echo "${tmp_lastline}${auxHashStatus}"; exit 0
}
#-------------------------------------------------------


#-------------------------------------------------------
#Show a rotating bar in asynchron mode during processing like utxo query
#Stop animation by sending a SIGINT to this child process
#
# ${1} = preText
function showProcessAnimation() {

local stopAnimation="false";
local idx=0;
#local animChar=("-" "\\" "|" "/");
#local animChar=("⎺" "\\" "⎽" "/");
local animChar=(">    " ">>   " ">>>  " " >>> " "  >>>" "   >>" "    >" "     ");
#local animChar=(">    " " >   " "  >  " "   > " "    >" "   < " "  <  " " <   ");

trap terminate SIGINT
terminate(){ stopAnimation="true"; }

until [[ ${stopAnimation} == "true" ]]; do
        idx=$(( (${idx}+1)%8 ))
        echo -ne "\r\e[0m${1}${animChar[$idx]} "
        sleep 0.2
done
}
#-------------------------------------------------------
stopProcessAnimation() {
pkill -SIGINT -P $$ && echo -ne "\r\033[K" #stop childprocess and delete the outputline
}
#-------------------------------------------------------



#-------------------------------------------------------
#checks if the given password $1 is a strong one
#min. 10 chars long, includes at least one uppercase, one lowercase, one special char
is_strong_password() {
    [[ "$1" =~ ^(.*[a-z]) ]] && [[ "$1" =~ ^(.*[A-Z]) ]] && [[ "$1" =~ ^(.*[0-9]) ]] && [[ "$1" =~ ^(.*[^a-zA-Z0-9]) ]] && [[ "$1" =~ ^(.){10,} ]] && echo "true"
}
#-------------------------------------------------------


#-------------------------------------------------------
#encrypt skey json data, will return a json with a
#modified 'description' field and encrypted 'encrHex' field
#
# ${1} = skeyJSON data
# ${2} = password
encrypt_skeyJSON() {

	local skeyJSON="${1}"
	local password="${2}"

	#check that the encryption/decryption tool gpg exists
	if ! exists gpg; then echo -e "\n\n\e[33mYou need the little tool 'gnupg', its needed to encrypt/decrypt the data !\n\nInstall it on Ubuntu/Debian like:\n\e[97msudo apt update && sudo apt -y install gnupg\n\n\e[33mThx! :-)\e[0m\n" > $(tty); exit 1; fi

	#check if the skeyJSON is already encrypted
	if [[ $(egrep "encrHex|Encrypted" <<< "${skeyJSON}" | wc -l) -ne 0 ]]; then echo "It is already encrypted!"; exit 1; fi

	#read data
	local skeyType=$(jq -r .type <<< ${skeyJSON}); if [[ $? -ne 0 ]]; then echo "Can't read the .type field!"; exit 1; fi
	if [[ "${skeyJSON}" != *"SigningKey"* ]]; then echo "Type field does not contain 'SigningKey' information!"; exit 1; fi
	local skeyDescription=$(jq -r .description <<< ${skeyJSON}); if [[ $? -ne 0 ]]; then echo "Can't read the .description field!"; exit 1; fi
	local skeyCBOR=$(jq -r .cborHex <<< ${skeyJSON}); if [[ $? -ne 0 ]]; then echo "Can't read the .cborHex field!"; exit 1; fi
	unset skeyJSON #not used after this line

	#encrypt
	local encrHex=$(gpg --symmetric --yes --batch --quiet --cipher-algo AES256 --passphrase "${password}" --log-file /dev/null <<< ${skeyCBOR} 2> /dev/null | xxd -ps -c 1000000)
	unset skeyCBOR #not used after this line
	unset password #not used after this line
	if [[ "${encrHex}" == "" ]]; then echo "Couldn't encrypt the data via gpg!"; exit 1; fi

	#return data and format it via jq (monochrome)
	echo -e "{ \"type\": \"${skeyType}\", \"description\": \"Encrypted ${skeyDescription}\", \"encrHex\": \"${encrHex}\" }" | jq -M .

}
#-------------------------------------------------------


#-------------------------------------------------------
#decrypt skey json data, will return a json with the
#original 'description' field and a decrypted 'cborHex' field
#
# ${1} = skeyJSON data
# ${2} = password
decrypt_skeyJSON() {

	local skeyJSON="${1}"
	local password="${2}"

	#check that the encryption/decryption tool gpg exists
	if ! exists gpg; then echo -e "\n\n\e[33mYou need the little tool 'gnupg', its needed to encrypt/decrypt the data !\n\nInstall it on Ubuntu/Debian like:\n\e[97msudo apt update && sudo apt -y install gnupg\n\n\e[33mThx! :-)\e[0m\n" > $(tty); exit 1; fi

	#check if the skeyJSON is already decrypted
	if [[ $(egrep "encrHex|Encrypted" <<< "${skeyJSON}" | wc -l) -eq 0 ]]; then echo "It is already decrypted!"; exit 1; fi

	#read data
	local skeyType=$(jq -r .type <<< ${skeyJSON}); if [[ $? -ne 0 ]]; then echo "Can't read the .type field!"; exit 1; fi
	if [[ "${skeyJSON}" != *"SigningKey"* ]]; then echo "Type field does not contain 'SigningKey' information!"; exit 1; fi
	local skeyDescription=$(jq -r .description <<< ${skeyJSON}); if [[ $? -ne 0 ]]; then echo "Can't read the .description field!"; exit 1; fi
	local skeyEncrHex=$(jq -r .encrHex <<< ${skeyJSON}); if [[ $? -ne 0 ]]; then echo "Can't read the .encrHex field!"; exit 1; fi
	unset skeyJSON #not used after this line

	#decrypt
	local cborHex=$(xxd -ps -r <<< ${skeyEncrHex} | gpg --decrypt --yes --batch --quiet --passphrase "${password}" --log-file /dev/null 2> /dev/null)
	unset skeyEncrHex #not used after this line
	unset password #not used after this line
	if [[ "${cborHex}" == "" ]]; then echo "Couldn't decrypt the data via gpg! Wrong password?"; exit 1; fi

	#return data and format it via jq (monochrome)
	echo -e "{ \"type\": \"${skeyType}\", \"description\": \"${skeyDescription//Encrypted /}\", \"cborHex\": \"${cborHex}\" }" | jq -M .
	unset cborHex

}
#-------------------------------------------------------


#-------------------------------------------------------
#read skey file and decrypt it if needed
#
#this function returns the skey json which will be used for example to sign transactions directly and not via a file read
#
# ${1} = skeyFILE
#
read_skeyFILE() {

	local skeyFILE="${1}"
	local cborHex=""

	local viaENV=""

	#check if the file exists
	if [ ! -f "${skeyFILE}" ]; then echo -e "\e[35mGiven SKEY-File does not exist!\e[0m\n\n"; exit 1; fi

	#check if the skeyJSON is already decrypted, if so, just return the content
	if [[ $(egrep "encrHex|Encrypted" < "${skeyFILE}" | wc -l) -eq 0 ]]; then echo -ne "\e[0mReading unencrypted file \e[32m${skeyFILE}\e[0m ... " > $(tty); cat "${skeyFILE}"; exit 0; fi

	#its encrypted, check that the encryption/decryption tool gpg exists
	if ! exists gpg; then echo -e "\n\n\e[33mYou need the little tool 'gnupg', its needed to encrypt/decrypt the data !\n\nInstall it on Ubuntu/Debian like:\n\e[97msudo apt update && sudo apt -y install gnupg\n\n\e[33mThx! :-)\e[0m\n" > $(tty); exit 1; fi

	#main loop to repeat the decryption until we have a cborHex
	while [[ "${cborHex}" == "" ]]; do

		#check if there is a passwort set in the ENV_DECRYPT_PASSWORD variable, if so, just do a short check and not prompt for a password

		if [[ "${ENV_DECRYPT_PASSWORD}" == "" ]]; then #prompt for a password
			#prompt for the password
		        local password=$(ask_pass "\e[33mEnter the Password to decrypt '${skeyFILE}' (empty to abort)")
		        if [[ ${password} == "" ]]; then echo -e "\e[35mAborted\e[0m\n\n"; exit 1; fi
		        while [[ $(is_strong_password "${password}") != "true" ]]; do
		                        echo -e "\n\e[35mThis is not a strong password, so it couldn't be the right one. Lets try it again...\e[0m\n" > $(tty)
				        local password=$(ask_pass "\e[33mEnter the Password to decrypt '${skeyFILE}' (empty to abort)")
		                        if [[ ${password} == "" ]]; then echo -e "\e[35mAborted\e[0m\n\n"; exit 1; fi
		        done

		else #password is present in the ENV_DECRYPT_PASSWORD variable

			#exit with an error if the password in the ENV_DECRYPT_PASSWORD is not a strong one
			if [[ $(is_strong_password "${ENV_DECRYPT_PASSWORD}") != "true" ]]; then echo -e "\n\e[35mThis is not a strong password via ENV_DECRYPT_PASSWORD... abort!\n\n"; exit 1; fi
			local password=${ENV_DECRYPT_PASSWORD}
			local viaENV="via ENV_DECRYPT_PASSWORD " #to extend the processing text

		fi

		#read data
		local skeyJSON=$(cat "${skeyFILE}")
		local skeyType=$(jq -r .type <<< ${skeyJSON}); if [[ $? -ne 0 ]]; then echo "Can't read the .type field!"; exit 1; fi
		if [[ "${skeyJSON}" != *"SigningKey"* ]]; then echo "Type field does not contain 'SigningKey' information!"; exit 1; fi
		local skeyDescription=$(jq -r .description <<< ${skeyJSON}); if [[ $? -ne 0 ]]; then echo "Can't read the .description field!"; exit 1; fi
		local skeyEncrHex=$(jq -r .encrHex <<< ${skeyJSON}); if [[ $? -ne 0 ]]; then echo "Can't read the .encrHex field!"; exit 1; fi
		unset skeyJSON #not used after this line

		#decrypt
		echo -ne "\r\033[K\e[0mDecrypting the file '\e[32m${skeyFILE}\e[0m' ${viaENV}... " > $(tty)
		local cborHex=$(xxd -ps -r <<< ${skeyEncrHex} 2> /dev/null | gpg --decrypt --yes --batch --quiet --passphrase "${password}" --log-file /dev/null 2> /dev/null)
		unset skeyEncrHex #not used after this line
		unset password #not used after this line
		if [[ "${cborHex}" == "" ]]; then
			if [[ "${ENV_DECRYPT_PASSWORD}" != "" ]]; then echo -e "\e[35mCouldn't decrypt the data via ENV_DECRYPT_PASSWORD! Wrong password?\e[0m"; exit 1; fi #if there was an error and password was from the ENV, exit with an error
			echo -e "\e[35mCouldn't decrypt the data! Wrong password?\e[0m" > $(tty);
 		fi

	done

	#we have cborHex content now, so the decryption worked

	#return data in json format, remove the added "Encrypted " in the description field on the fly
	printf "{ \"type\": \"${skeyType}\", \"description\": \"${skeyDescription//Encrypted /}\", \"cborHex\": \"${cborHex}\" }"
	unset cborHex

}
#-------------------------------------------------------



