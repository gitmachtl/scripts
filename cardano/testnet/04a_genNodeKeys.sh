#!/bin/bash

# Script is brought to you by ATADA_Stakepool, Telegram @atada_stakepool

#load variables from common.sh
#       socket          Path to the node.socket (also exports socket to CARDANO_NODE_SOCKET_PATH)
#       genesisfile     Path to the genesis.json
#       magicparam      TestnetMagic parameter
#       cardanocli      Path to the cardano-cli executable
#       cardanonode     Path to the cardano-node executable
. "$(dirname "$0")"/00_common.sh

#Check command line parameter
if [ $# -lt 2 ] || [[ ! ${2^^} =~ ^(CLI|HW)$ ]]; then
cat >&2 <<EOF
ERROR - Usage: $(basename $0) <NodePoolName> <KeyType: cli | hw>

Examples:
$(basename $0) mypool cli   ... generates the node cold keys from standard CLI commands (was default before hw option)
$(basename $0) mypool hw    ... generates the node cold keys by using a Ledger/Trezor HW-Wallet

EOF
exit 1;
fi

nodeName=$1
keyType=$2;

#Check if there are already node cold files
if [ -f "${nodeName}.node.vkey" ]; then echo -e "\e[35mWARNING - ${nodeName}.node.vkey already present, delete it or use another name !\e[0m"; exit 2; fi
if [ -f "${nodeName}.node.skey" ]; then echo -e "\e[35mWARNING - ${nodeName}.node.skey already present, delete it or use another name !\e[0m"; exit 2; fi
if [ -f "${nodeName}.node.hwsfile" ]; then echo -e "\e[35mWARNING - ${nodeName}.node.hwsfile already present, delete it or use another name !\e[0m"; exit 2; fi
if [ -f "${nodeName}.node.counter" ]; then echo -e "\e[35mWARNING - ${nodeName}.node.counter already present, delete it or use another name !\e[0m"; exit 2; fi


if [[ ${keyType^^} == "CLI" ]]; then #Building it from the cli

	echo -e "\e[0mCreating Node Cold/Offline Keys (CLI)\e[32m ${nodeName}.node.vkey/skey\e[0m and Issue.Counter File\e[32m ${nodeName}.node.counter"
	echo

	${cardanocli} node key-gen --verification-key-file ${nodeName}.node.vkey --signing-key-file ${nodeName}.node.skey --operational-certificate-issue-counter ${nodeName}.node.counter
	checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
	file_lock ${nodeName}.node.vkey
	file_lock ${nodeName}.node.skey
	file_lock ${nodeName}.node.counter

	echo -e "\e[0mNode Cold Verification-Key:\e[32m ${nodeName}.node.vkey \e[90m"
	cat ${nodeName}.node.vkey
	echo
	echo -e "\e[0mNode Cold Signing-Key:\e[32m ${nodeName}.node.skey \e[90m"
	cat ${nodeName}.node.skey
	echo
	echo -e "\e[0mNode Operational-Certificate-Issue-Counter:\e[32m ${nodeName}.node.counter \e[90m"
	cat ${nodeName}.node.counter
	echo

else #Building it from HW-Keys

        echo -e "\e[0mCreating Node Cold/Offline Keys (HW)\e[32m ${nodeName}.node.vkey/hwsfile\e[0m and Issue.Counter File\e[32m ${nodeName}.node.counter"
        echo

        start_HwWallet; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
        tmp=$(${cardanohwcli} node key-gen --path 1853H/1815H/0H/0H --cold-verification-key-file ${nodeName}.node.vkey --hw-signing-file ${nodeName}.node.hwsfile --operational-certificate-issue-counter-file ${nodeName}.node.counter 2> /dev/stdout)
        if [[ "${tmp^^}" =~ (ERROR|DISCONNECT) ]]; then echo -e "\e[35m${tmp}\e[0m\n"; exit 1; else echo -e "\e[32mDONE\e[0m\n"; fi
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
        file_lock ${nodeName}.node.vkey
        file_lock ${nodeName}.node.hwsfile
        file_lock ${nodeName}.node.counter

        echo -e "\e[0mNode Cold Verification-Key:\e[32m ${nodeName}.node.vkey \e[90m"
        cat ${nodeName}.node.vkey
        echo
	echo
        echo -e "\e[0mNode Cold HardwareSigning-File:\e[32m ${nodeName}.node.hwsfile \e[90m"
        cat ${nodeName}.node.hwsfile
        echo
	echo
        echo -e "\e[0mNode Operational-Certificate-Issue-Counter:\e[32m ${nodeName}.node.counter \e[90m"
        cat ${nodeName}.node.counter
        echo

fi

echo -e "\e[0m\n"
