#!/bin/bash

socket="db/node.socket"

genesisfile="config/ff-genesis.json"

magicparam="--testnet-magic 42"

cardanocli="./cardano-cli"


#--------- only for kes/opcert update and upload via scp -----

remoteServerAddr="yourserver.com" 			#RemoteServer ip or dns name
remoteServerUser="username" 				#RemoteServer userlogin via ssh keys
remoteServerSSHport="22" 				#RemoteServer SSH port number
remoteServerDestDir="~/cardano/config-core/." 		#Destination directory were to copy the files to
remoteServerPostCommand="~/cardano/restartCore.sh"	#Command to execute via SSH after the file upload completed to restart the coreNode on the remoteServer





#--------- don't edit below here -----------------------------------------------------------------------------------------
#-------------------------------------------------------------------------------------------------------------------------
export CARDANO_NODE_SOCKET_PATH=${socket}
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


