#!/bin/bash

socket="db/node.socket"

genesisfile="config/ff-genesis.json"

magicparam="--testnet-magic 42"

cardanocli="./cardano-cli"

cardanonode="./cardano-node"


#--------- only for kes/opcert update and upload via scp -----

remoteServerAddr="yourserver.com" 			#RemoteServer ip or dns name
remoteServerUser="username" 				#RemoteServer userlogin via ssh keys
remoteServerSSHport="22" 				#RemoteServer SSH port number
remoteServerDestDir="~/cardano/config-core/." 		#Destination directory were to copy the files to
remoteServerPostCommand="~/cardano/restartCore.sh"	#Command to execute via SSH after the file upload completed to restart the coreNode on the remoteServer




#--------- don't edit below here -----------------------------------------------------------------------------------------
#-------------------------------------------------------------------------------------------------------------------------
export CARDANO_NODE_SOCKET_PATH=${socket}

#Searching the temp directory (used for transactions files), tempDir=/tmp for example
tempDir=$(dirname $(mktemp tmp.XXXX -ut))



#Dummy Shelley Payment_Addr
dummyShelleyAddr="addr_test1vpx40rml0k5yyx266xnwtgpzj9ndp9v3ava22jz5mlzcnvgcczpr3"

#AddressType check
get_addressType() {
${cardanocli} shelley address info --address $1 | grep "Type" | cut -d":" -f 2 | sed 's/ //'
}

get_addressEra() {
${cardanocli} shelley address info --address $1 | grep "Era" | cut -d":" -f 2 | sed 's/ //'
}

addrTypePayment="Payment address"
addrTypeStake="Stake address"



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
#Subroutines to calculate current epoch from genesis.json
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
#Subroutines to calculate time until next epoch from genesis.json
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
local currentTip=$(${cardanocli} shelley query tip ${magicparam} | awk 'match($0,/unSlotNo = [0-9]+/) {print substr($0, RSTART+11,RLENGTH-11)}')
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


