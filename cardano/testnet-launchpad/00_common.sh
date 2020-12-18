#!/bin/bash

#Please set the following variables to your needs, you can overwrite them dynamically
#by placing a file with name "common.inc" in the calling directory or in "$HOME/.common.inc".
#It will be sourced into this file automatically if present and can overwrite the values below dynamically :-)

socket="db-mainnet/node.socket"

genesisfile="configuration-mainnet/mainnet-shelley-genesis.json"           #Shelley-Genesis path
genesisfile_byron="configuration-mainnet/mainnet-byron-genesis.json"       #Byron-Genesis path

cardanocli="./cardano-cli"	#Path to your cardano-cli you wanna use
cardanonode="./cardano-node"	#Path to your cardano-node you wanna use

magicparam="--mainnet"	#choose "--mainnet" for mainnet or for example "--testnet-magic 1097911063" for a testnet, 12 for allegra
addrformat="--mainnet" #choose "--mainnet" for mainnet address format or like "--testnet-magic 1097911063" for testnet address format, 12 for allegra

itn_jcli="./jcli" #only needed if you wanna include your itn witness for your pool-ticker

#--------- leave this next value until you have to change it for a testnet
byronToShelleyEpochs=208 #208 for the mainnet, 74 for the testnet, 1 for allegra-testnet

#--------- only for kes/opcert update and upload via scp -----
remoteServerAddr="remoteserver address or ip"                       #RemoteServer ip or dns name
remoteServerUser="remoteuser"                             #RemoteServer userlogin via ssh keys
remoteServerSSHport="22"                                #RemoteServer SSH port number
remoteServerDestDir="~/remoteuser/core-###NODENAME###/."           #Destination directory were to copy the files to
remoteServerPostCommand="~/remoteuser/restartCore.sh"      #Command to execute via SSH after the file upload completed to restart the coreNode on the remoteServer


##############################################################################################################################
#
# DONT EDIT BELOW THIS LINE
#
##############################################################################################################################

minNodeVersion="1.24.2"  #minimum allowed node version for this script-collection version
maxNodeVersion="9.99.9"  #maximum allowed node version, 9.99.9 = no limit so far

#Placeholder for a fixed subCommand
subCommand=""	#empty since 1.24.0, because the "shelley" subcommand moved to the mainlevel

#Overwrite variables via env file if present
if [[ -f "$HOME/.common.inc" ]]; then source "$HOME/.common.inc"; fi
if [[ -f "common.inc" ]]; then source "common.inc"; fi

export CARDANO_NODE_SOCKET_PATH=${socket}

#-------------------------------------------------------
#DisplayMajorErrorMessage
majorError() {
echo -e "\e[97m\n"
echo -e "         _ ._  _ , _ ._\n        (_ ' ( \`  )_  .__)\n      ( (  (    )   \`)  ) _)\n     (__ (_   (_ . _) _) ,__)\n         \`~~\`\\ ' . /\`~~\`\n              ;   ;\n              /   \\ \n_____________/_ __ \\___________________________________________\n"
echo -e "\e[35m${1}\nIf you think all is right at your side, please check the GitHub repo if there\nis a newer version/bugfix available, thx: https://github.com/gitmachtl/scripts\e[0m\n"; exit 1;
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
versionToCheck=$(${cardanocli} version 2> /dev/null |& head -n 1 |& awk {'print $2'})
versionCheck "${minNodeVersion}" "${versionToCheck}"
if [[ $? -ne 0 ]]; then majorError "Version ERROR - Please use a cardano-node/cli version ${minNodeVersion} or higher !\nOld versions are not supported for security reasons, please upgrade - thx."; exit 1; fi
versionCheck "${versionToCheck}" "${maxNodeVersion}"
if [[ $? -ne 0 ]]; then majorError "Version ERROR - Please use a cardano-node/cli version between ${minNodeVersion} and ${maxNodeVersion} !\nOther versions are not supported for compatibility issues, please check if newer scripts are available - thx."; exit 1; fi
echo -ne "\n\e[0mVersion-Info: \e[32mcli ${versionToCheck}\e[0m / "

#Check cardano-node
if ! exists "${cardanonode}"; then majorError "Path ERROR - Path to cardano-node is not correct or cardano-node binaryfile is missing!"; exit 1; fi
versionToCheck=$(${cardanonode} version 2> /dev/null |& head -n 1 |& awk {'print $2'})
versionCheck "${minNodeVersion}" "${versionToCheck}"
if [[ $? -ne 0 ]]; then majorError "Version ERROR - Please use a cardano-node/cli version ${minNodeVersion} or higher !\nOld versions are not supported for security reasons, please upgrade - thx."; exit 1; fi
versionCheck "${versionToCheck}" "${maxNodeVersion}"
if [[ $? -ne 0 ]]; then majorError "Version ERROR - Please use a cardano-node/cli version between ${minNodeVersion} and ${maxNodeVersion} !\nOther versions are not supported for compatibility issues, please check if newer scripts are available - thx."; exit 1; fi
echo -e "\e[32mnode ${versionToCheck}\e[0m\n"

#Check path to genesis files
if [[ ! -f "${genesisfile}" ]]; then majorError "Path ERROR - Path to the shelley genesis file is wrong or the file is missing!"; exit 1; fi
if [[ ! -f "${genesisfile_byron}" ]]; then majorError "Path ERROR - Path to the byron genesis file is wrong or the file is missing!"; exit 1; fi

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
#Subroutines to calculate current slotHeight(tip)
get_currentTip()
{
local currentTip=$(${cardanocli} ${subCommand} query tip ${magicparam} | jq -r .slotNo)
echo ${currentTip}
}
#-------------------------------------------------------

#-------------------------------------------------------
#Subroutines to calculate current TTL
get_currentTTL()
{
echo $(( $(get_currentTip) + 10000 ))
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
tmpEra=$(get_NodeEra)
if [[ ! "${tmpEra}" == "" ]]; then nodeEraParam="--${tmpEra}-era"; else nodeEraParam=""; fi
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
#Calculate the minimum UTXO level that has to be sent depending on the assets and the minUTXO protocol-parameters
get_minOutUTXO() {
	#${1} = protocol-parameters.json content
	#${2} = total number of different assets
	#${3} = total number of different policyIDs

local minUTXOvalue=$(jq -r .minUTxOValue <<< ${1})

echo $(( ${minUTXOvalue} + (${2}*${minUTXOvalue}) ))	#poor calculation currently
}
#-------------------------------------------------------
