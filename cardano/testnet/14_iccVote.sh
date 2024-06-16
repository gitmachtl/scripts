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

#Check command line parameter
if [ $# -lt 2 ]; then
cat >&2 <<EOF

Usage:  $(basename $0) <StakeAddressName> <vote-ballot-json-string>

Example:
	$(basename $0) myPledgeWallet '["cardanoAtlanticCouncil", "easternCardanoCouncil", "lloydDuhon"]'

EOF
exit 1;
fi

#At least 2 parameters were provided, use them
stakeAddr="$(dirname $1)/$(basename $1 .staking).staking"; stakeAddr=${stakeAddr/#.\//};
ballotJSON="${2}"

#Check about required files: Registration Certificate, Signing Key and Address of the payment Account
#For StakeKeyRegistration
if ! [[ -f "${stakeAddr}.skey" ]]; then echo -e "\n\e[35mERROR - \"${stakeAddr}.skey\" does not exist! Please create it first with script 03a.\n\e[0m"; exit 1; fi


#----------------------------------------------------

echo
echo -e "\e[0mGenerate Voting-TX-Data for StakeKey\e[32m ${stakeAddr}.skey\e[0m"
echo


# Get current timestamp in milliseconds
timeStamp=$(date +%s%3N)

# Create JSON object
metadataJSON=$(cat <<EOF
{
   "674": {
      "params": ${ballotJSON},
      "timestamp": $timeStamp
   }
}
EOF
)
metadataJSON=$( jq -r "." <<< ${metadataJSON} 2> /dev/null )
if [[ $? -ne 0 ]]; then echo -e "\n\e[35mERROR - The provided BallotVoteJSON Data ${ballotJSON} is not in valid JSON format.\n\e[0m"; exit 1; fi
metadataFile="${tempDir}/icc-vote.json"
echo -e "${metadataJSON}" > ${metadataFile}

echo -e "\e[0mUsing provided Ballot-JSON-Data\e[0m: \e[32m ${metadataFile}\e[90m"
cat ${metadataFile}
echo -e "\e[0m"

#Generate Dummy-TxBody file for fee calculation
dummytxin="646069e52678e8f121209cc38ab60a4197fd8f18dff960b607a27cbdefe2def7#1337"
txBodyFile="${tempDir}/dummy.txbody"; rm ${txBodyFile} 2> /dev/null
txFile="${tempDir}/dummy.tx"; rm ${txFile} 2> /dev/null

rm ${txBodyFile} 2> /dev/null
${cardanocli} ${cliEra} transaction build-raw ${txInString} --tx-in "${dummytxin}" --fee 0 --metadata-json-file "$metadataFile" --out-file ${txBodyFile}
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

skeyJSON=$(read_skeyFILE "${stakeAddr}.skey"); if [ $? -ne 0 ]; then echo -e "\e[35m${skeyJSON}\e[0m\n"; exit 1; else echo -e "\e[32mOK\e[0m\n"; fi

echo -e "\e[0mSign the unsigned transaction body with the \e[32m${stakeAddr}.skey\e[0m: \e[32m ${txFile}\e[0m"
echo

${cardanocli} ${cliEra} transaction sign --tx-body-file ${txBodyFile} --signing-key-file <(echo "${skeyJSON}") --out-file ${txFile}
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
#forget the signing keys
unset skeyJSON
echo -ne "\e[90m"
dispFile=$(cat ${txFile}); if ${cropTxOutput} && [[ ${#dispFile} -gt 4000 ]]; then echo "${dispFile:0:4000} ... (cropped)"; else echo "${dispFile}"; fi
echo -e "\e[0m"
echo

echo -e "\e[0mPlease copy&paste the following signed TX-Data into the Online-Form '\e[32mSigned transaction hex\e[0m':\n"
jq -r .cborHex "${txFile}"
echo
echo
echo -e "\e[33mMake sure to use your correct Base-Address/Pledge-Address for the Form-Field '\e[32mFull Cardano Address\e[33m'\e[0m"
echo
echo

