#!/bin/bash

#load variables from common.sh
#       socket          Path to the node.socket (also exports socket to CARDANO_NODE_SOCKET_PATH)
#       genesisfile     Path to the genesis.json
#       magicparam      TestnetMagic parameter
#	cardanocli	Path to the cardano-cli executable
#	cardanonode	Path to the cardano-node executable
#	remoteServerXXX Settings for the KES/OpCert update via SCP
. "$(dirname "$0")"/00_common.sh

if [[ ! $1 == "" ]]; then nodeName=$1; else echo "ERROR - Usage: $0 <PoolNodeName>"; exit 2; fi

#Generate a new KES Pair
./04c_genKESKeys.sh ${nodeName}

#Generate a new opcert
./04d_genNodeOpCert.sh ${nodeName}

#Get the latest version number
latestKESnumber=$(cat ${nodeName}.kes.counter)

#Copy them to a new filename in the upload folder with fixed names
mkdir -p ./upload
cp ./${nodeName}.kes-${latestKESnumber}.skey ./upload/${nodeName}.kes.skey	 #Copy latest KES key over to fixed name nodeName.kes.skey
cp ./${nodeName}.vrf.skey ./upload/${nodeName}.vrf.skey				 #Copy vrf key over to fixed name nodeName.vrf.skey
cp ./${nodeName}.node-${latestKESnumber}.opcert ./upload/${nodeName}.node.opcert #Copy latest opcert over to fixed name nodeName.node.opcert

echo -e "\e[0mUploading new files now ...\e[90m"
#Upload them to the CoreNode Server
scp -P ${remoteServerSSHport} ./upload/* ${remoteServerUser}@${remoteServerAddr}:${remoteServerDestDir}
echo -e "\e[0mDONE. Initiating coreNode restart ...\e[90m"

#Executing a coreNode restart on the server
ssh -p ${remoteServerSSHport} -tq ${remoteServerUser}@${remoteServerAddr} ${remoteServerPostCommand}
echo -e "\e[0mDONE. coreNode now running with the new Keys!"
echo




