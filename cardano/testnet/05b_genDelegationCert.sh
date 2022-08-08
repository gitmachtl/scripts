#!/bin/bash

# Script is brought to you by ATADA Stakepool, Telegram @atada_stakepool

#load variables and functions from common.sh
. "$(dirname "$0")"/00_common.sh


case $# in
  2 ) delegateStakeAddr="$(dirname $2)/$(basename $2 .staking)"; delegateStakeAddr=${delegateStakeAddr/#.\//};
      toPoolNodeName="$(dirname $1)/$(basename $(basename $1 .json) .pool)"; toPoolNodeName=${toPoolNodeName/#.\//};
      toPoolID=${1,,};;
  * ) cat >&2 <<EOF
Usage:  $(basename $0) <PoolNodeName or PoolID-Hex or PoolID-Bech "pool1..."> <DelegatorStakeAddressName>
EOF
  exit 1;; esac

#Checks for needed files
if [ ! -f "${delegateStakeAddr}.staking.vkey" ]; then echo -e "\n\e[35mERROR - \"${delegateStakeAddr}.staking.vkey\" does not exist! Please create it first with script 03a.\e[0m"; exit 1; fi

#Check if the provided Pool-Identification is a Hex-PoolID(length56), a Bech32-PoolID(length56 and starting with pool1) or a Pool-VKEY-File
if [[ "${toPoolID//[![:xdigit:]]}" == "${toPoolID}" && ${#toPoolID} -eq 56 ]]; then #parameter is a hex-poolid

	echo -e "\e[0mCreate a delegation registration certificate for Delegator\e[32m ${delegateStakeAddr}.staking.vkey\e[0m \nto the Pool with Hex-ID\e[32m ${toPoolID}\e[90m:"
	echo
	file_unlock ${delegateStakeAddr}.deleg.cert
	${cardanocli} stake-address delegation-certificate --stake-verification-key-file ${delegateStakeAddr}.staking.vkey --stake-pool-id ${toPoolID} --out-file ${delegateStakeAddr}.deleg.cert
	checkError "$?"; if [ $? -ne 0 ]; then file_lock ${delegateStakeAddr}.deleg.cert; exit $?; fi
	file_lock ${delegateStakeAddr}.deleg.cert


elif [[ "${toPoolID:0:5}" == "pool1" && ${#toPoolID} -eq 56 ]]; then #parameter is most likely a bech32-poolid

	#lets do some further testing by converting the beche32 pool-id into a hex-pool-id
	tmp=$(${bech32_bin} 2> /dev/null <<< "${toPoolID}") #will have returncode 0 if the bech was valid
        if [ $? -ne 0 ]; then echo -e "\n\e[35mERROR - \"${toPoolID}\" is not a valid bech32 pool-id.\e[0m"; exit 1; fi

        echo -e "\e[0mCreate a delegation registration certificate for Delegator\e[32m ${delegateStakeAddr}.staking.vkey\e[0m \nto the Pool with Bech32-ID\e[32m ${toPoolID}\e[90m:"
        echo
        file_unlock ${delegateStakeAddr}.deleg.cert
        ${cardanocli} stake-address delegation-certificate --stake-verification-key-file ${delegateStakeAddr}.staking.vkey --stake-pool-id ${toPoolID} --out-file ${delegateStakeAddr}.deleg.cert
        checkError "$?"; if [ $? -ne 0 ]; then file_lock ${delegateStakeAddr}.deleg.cert; exit $?; fi
        file_lock ${delegateStakeAddr}.deleg.cert

elif [ -f "${toPoolNodeName}.node.vkey" ]; then #parameter is a pool verification key file

	echo -e "\e[0mCreate a delegation registration certificate for Delegator\e[32m ${delegateStakeAddr}.staking.vkey\e[0m \nto the Pool with the Key-File\e[32m ${toPoolNodeName}.node.vkey\e[90m:"
	echo
	file_unlock ${delegateStakeAddr}.deleg.cert
	${cardanocli} stake-address delegation-certificate --stake-verification-key-file ${delegateStakeAddr}.staking.vkey --cold-verification-key-file ${toPoolNodeName}.node.vkey --out-file ${delegateStakeAddr}.deleg.cert
	checkError "$?"; if [ $? -ne 0 ]; then file_lock ${delegateStakeAddr}.deleg.cert; exit $?; fi
	file_lock ${delegateStakeAddr}.deleg.cert

else
	echo -e "\n\e[35mERROR - \"${toPoolNodeName}.node.vkey\" does not exist, nor is \"${toPoolID}\" a valid pool-id!\e[0m"; exit 1
fi


echo -e "\e[0mDelegation registration certificate:\e[32m ${delegateStakeAddr}.deleg.cert \e[90m"
cat ${delegateStakeAddr}.deleg.cert
echo
echo -e "\e[0mCreated a delegation certificate which delegates funds from all stake addresses\nassociated with key \e[32m${delegateStakeAddr}.staking.vkey\e[0m to the pool-file / pool-id above.\e[0m"
echo

echo -e "\e[0m\n"
