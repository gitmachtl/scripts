#!/bin/bash

socket="db/node.socket"

genesisfile="config/mainnet_candidate-shelley-genesis.json"           #Shelley
genesisfile_byron="config/mainnet_candidate-byron-genesis.json"       #Byron

cardanocli="./cardano-cli"
cardanonode="./cardano-node"


#MainNetCandidate2  - 18.07.2020
nodeVersionNeeded="1.16.0"
magicparam="--testnet-magic 42"


#--------- only for kes/opcert update and upload via scp -----


remoteServerAddr="yourserver.com"                       #RemoteServer ip or dns name
remoteServerUser="username"                             #RemoteServer userlogin via ssh keys
remoteServerSSHport="22"                                #RemoteServer SSH port number
remoteServerDestDir="~/cardano/config-core/."           #Destination directory were to copy the files to
remoteServerPostCommand="~/cardano/restartCore.sh"      #Command to execute via SSH after the file upload completed to restart the coreNode on the remoteServer


##############################################################################################################################
#
# DONT EDIT BELOW THIS LINE
#
##############################################################################################################################

export CARDANO_NODE_SOCKET_PATH=${socket}


#-------------------------------------------------------------
#Do a cli and node version check
versionCheck=$(${cardanocli} --version | grep "${nodeVersionNeeded}" | wc -l)
if [[ ${versionCheck} -eq 0 ]]; then echo -e "\e[35mERROR - Please use Node and CLI Version ${nodeVersionNeeded} ! \e[0m"; exit 1; fi
versionCheck=$(${cardanonode} --version | grep "${nodeVersionNeeded}" | wc -l)
if [[ ${versionCheck} -eq 0 ]]; then echo -e "\e[35mERROR - Please use Node and CLI Version ${nodeVersionNeeded} ! \e[0m"; exit 1; fi


#-------------------------------------------------------------
#Searching for the temp directory (used for transactions files)
tempDir=$(dirname $(mktemp tmp.XXXX -ut))


#Dummy Shelley Payment_Addr
dummyShelleyAddr="addr1vyde3cg6cccdzxf4szzpswgz53p8m3r4hu76j3zw0tagyvgdy3s4p"

#AddressType check

check_address() {
tmp=$(${cardanocli} shelley address info --address $1 2> /dev/null)
if [[ $? -ne 0 ]]; then echo -e "\e[35mERROR - Unknown address format for address: $1 !\e[0m"; exit 1; fi
}

get_addressType() {
${cardanocli} shelley address info --address $1 | jq -r .type
}

get_addressEra() {
${cardanocli} shelley address info --address $1 | jq -r .era
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
local currentTip=$(${cardanocli} shelley query tip ${magicparam} | jq -r .slotNo)
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
if [[ $1 -ne 0 ]]; then echo -e "\n\n\e[35mERROR (Code $1) !\e[0m"; exit 1; fi
}
#-------------------------------------------------------

#-------------------------------------------------------
#TrimString
function trimString
{
    echo "$1" | sed -n '1h;1!H;${;g;s/^[ \t]*//g;s/[ \t]*$//g;p;}'
}
#-------------------------------------------------------
