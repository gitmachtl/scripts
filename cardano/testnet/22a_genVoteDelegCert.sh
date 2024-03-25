#!/bin/bash

############################################################
#    _____ ____  ____     _____           _       __
#   / ___// __ \/ __ \   / ___/__________(_)___  / /______
#   \__ \/ /_/ / / / /   \__ \/ ___/ ___/ / __ \/ __/ ___/
#  ___/ / ____/ /_/ /   ___/ / /__/ /  / / /_/ / /_(__  )
# /____/_/    \____/   /____/\___/_/  /_/ .___/\__/____/
#                                    /_/
#
# Scripts are brought to you by Martin L. (ATADA Stakepool)
# Telegram: @atada_stakepool   Github: github.com/gitmachtl
#
############################################################

#load variables and functions from common.sh
. "$(dirname "$0")"/00_common.sh


case $# in
  2 ) delegateStakeAddr="$(dirname $2)/$(basename $2 .staking)"; delegateStakeAddr=${delegateStakeAddr/#.\//};
      toDRepName="$(dirname $1)/$(basename $(basename $1 .id) .drep)"; toDRepName=${toDRepName/#.\//};
      toDRepID=${1,,};;
  * ) cat >&2 <<EOF
Usage:  $(basename $0) <DRep-Name | DRepID-Hex | DRepID-Bech "drep1..." | always-abstain | always-no-confidence> <StakeAddressName>
EOF
  exit 1;; esac

#Checks for needed files
if [ ! -f "${delegateStakeAddr}.staking.vkey" ]; then echo -e "\n\e[35mERROR - \"${delegateStakeAddr}.staking.vkey\" does not exist! Please create it first with script 03a.\e[0m"; exit 1; fi

#Check if the provided DRep-Identification is a Hex-DRepID(length56), a Bech32-DRepID(length56 and starting with drep1) or a DRep-VKEY-File
if [[ "${toDRepID//[![:xdigit:]]}" == "${toDRepID}" && ${#toDRepID} -eq 56 ]]; then #parameter is a hex-drepid

	echo -e "\e[0mCreate a Vote-Delegation Certificate for Delegator\e[32m ${delegateStakeAddr}.staking.vkey\e[0m \nto the DRep with Hex-ID\e[32m ${toDRepID}\e[0m"
	echo
	file_unlock ${delegateStakeAddr}.vote-deleg.cert
	${cardanocli} ${cliEra} stake-address vote-delegation-certificate --stake-verification-key-file ${delegateStakeAddr}.staking.vkey --drep-key-hash ${toDRepID} --out-file ${delegateStakeAddr}.vote-deleg.cert
	checkError "$?"; if [ $? -ne 0 ]; then file_lock ${delegateStakeAddr}.vote-deleg.cert; exit $?; fi
	file_lock ${delegateStakeAddr}.vote-deleg.cert


elif [[ "${toDRepID:0:5}" == "drep1" && ${#toDRepID} -eq 56 ]]; then #parameter is most likely a bech32-drepid

	#lets do some further testing by converting the beche32 DRep-id into a hex-DRep-id
	tmp=$(${bech32_bin} 2> /dev/null <<< "${toDRepID}") #will have returncode 0 if the bech was valid
        if [ $? -ne 0 ]; then echo -e "\n\e[35mERROR - \"${toDRepID}\" is not a valid bech32 DRep-id.\e[0m"; exit 1; fi

        echo -e "\e[0mCreate a Vote-Delegation Certificate for Delegator\e[32m ${delegateStakeAddr}.staking.vkey\e[0m \nto the DRep with Bech32-ID\e[32m ${toDRepID}\e[0m"
        echo
        file_unlock ${delegateStakeAddr}.vote-deleg.cert
	${cardanocli} ${cliEra} stake-address vote-delegation-certificate --stake-verification-key-file ${delegateStakeAddr}.staking.vkey --drep-key-hash ${toDRepID} --out-file ${delegateStakeAddr}.vote-deleg.cert
        checkError "$?"; if [ $? -ne 0 ]; then file_lock ${delegateStakeAddr}.vote-deleg.cert; exit $?; fi
        file_lock ${delegateStakeAddr}.vote-deleg.cert

elif [ -f "${toDRepName}.drep.vkey" ]; then #parameter is a DRep verification key file

	echo -e "\e[0mCreate a Vote-Delegation Certificate for Delegator\e[32m ${delegateStakeAddr}.staking.vkey\e[0m \nto the DRep with the Key-File\e[32m ${toDRepName}.drep.vkey\e[0m"
	echo

	#Get the drepID from the vkey file to just show it
	toDRepID=$(${cardanocli} ${cliEra} governance drep id --drep-verification-key-file "${toDRepName}.drep.vkey" --out-file /dev/stdout)
	checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
	echo -e "\e[0mWhich resolves to the DRep-ID:\e[32m ${toDRepID}\e[0m"
	echo

	file_unlock ${delegateStakeAddr}.vote-deleg.cert
	${cardanocli} ${cliEra} stake-address vote-delegation-certificate --stake-verification-key-file ${delegateStakeAddr}.staking.vkey --drep-verification-key-file "${toDRepName}.drep.vkey" --out-file ${delegateStakeAddr}.vote-deleg.cert
	checkError "$?"; if [ $? -ne 0 ]; then file_lock ${delegateStakeAddr}.vote-deleg.cert; exit $?; fi
	file_lock ${delegateStakeAddr}.vote-deleg.cert

elif [[ "${toDRepID}" == "always-abstain" ]]; then #parameter is ALWAYS-ABSTAIN

	echo -e "\e[0mCreate a Vote-Delegation Certificate for Delegator\e[32m ${delegateStakeAddr}.staking.vkey\e[0m \nsetting it to\e[33m ALWAYS ABSTAIN\e[0m"
	echo
	file_unlock ${delegateStakeAddr}.vote-deleg.cert
	${cardanocli} ${cliEra} stake-address vote-delegation-certificate --stake-verification-key-file ${delegateStakeAddr}.staking.vkey --always-abstain --out-file ${delegateStakeAddr}.vote-deleg.cert
	checkError "$?"; if [ $? -ne 0 ]; then file_lock ${delegateStakeAddr}.vote-deleg.cert; exit $?; fi
	file_lock ${delegateStakeAddr}.vote-deleg.cert

elif [[ "${toDRepID}" == "always-no-confidence" ]]; then #parameter is ALWAYS-NO-CONFIDENCE

	echo -e "\e[0mCreate a Vote-Delegation Certificate for Delegator\e[32m ${delegateStakeAddr}.staking.vkey\e[0m \nsetting it to\e[33m ALWAYS NO CONFIDENCE\e[0m"
	echo
	file_unlock ${delegateStakeAddr}.vote-deleg.cert
	${cardanocli} ${cliEra} stake-address vote-delegation-certificate --stake-verification-key-file ${delegateStakeAddr}.staking.vkey --always-no-confidence --out-file ${delegateStakeAddr}.vote-deleg.cert
	checkError "$?"; if [ $? -ne 0 ]; then file_lock ${delegateStakeAddr}.vote-deleg.cert; exit $?; fi
	file_lock ${delegateStakeAddr}.vote-deleg.cert

else
	echo -e "\n\e[35mERROR - \"${toDRepName}.node.vkey\" does not exist, nor is \"${toDRepID}\" a valid DRep-ID or a Command!\e[0m"; exit 1
fi


echo -e "\e[0mVote-Delegation Certificate:\e[32m ${delegateStakeAddr}.vote-deleg.cert \e[90m"
cat ${delegateStakeAddr}.vote-deleg.cert
echo
echo -e "\e[0mCreated a Vote-Delegation Certificate which delegates the voting power from all stake addresses\nassociated with key \e[32m${delegateStakeAddr}.staking.vkey\e[0m to the DRep-File / DRep-ID / STATUS above.\e[0m"
echo

echo
echo -e "\e[35mIf you wanna submit the Certificate now, please run the script 22b_regVoteDelegCert.sh !\e[0m"
echo

echo -e "\e[0m\n"
