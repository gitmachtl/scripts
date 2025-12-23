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

if [[ $# -eq 1 && ! $1 == "" ]]; then addrName="$(dirname $1)/$(basename $(basename $1 .addr) .staking)"; addrName=${addrName/#.\//}; else echo "ERROR - Usage: $0 <AddressName>"; exit 2; fi

#Checks for needed files
if [ ! -f "${addrName}.staking.addr" ]; then echo -e "\n\e[35mERROR - \"${addrName}.staking.addr\" does not exist! Maybe a typo?\n\e[0m"; exit 1; fi

#read the content of the provided address file
stakingAddr=$(cat ${addrName}.staking.addr)

#What type of Address is it? Stake?
typeOfAddr=$(get_addressType "${stakingAddr}")
if [[ ${typeOfAddr} != ${addrTypeStake} ]]; then #not a stake address
	echo -e "\n\e[35mERROR - \"${addrName}.staking.addr\" with the content \"${stakingAddr}\" is not a valid stake address!\n\e[0m";
	exit 1
fi

	echo -e "\e[0mChecking Status of Stake-Address\e[32m ${addrName}.staking.addr\e[0m: ${stakingAddr}"
	echo

        echo -e "\e[0mAddress-Type / Era:\e[32m $(get_addressType "${stakingAddr}")\e[0m / \e[32m$(get_addressEra "${stakingAddr}")\e[0m"
        echo

        #Get rewards state data for the address. When in online mode of course from the node and the chain, in light mode via koios, in offlinemode from the transferFile
	case ${workMode} in

		"online")	showProcessAnimation "Query-StakeAddress-Info: " &
				rewardsJSON=$(${cardanocli} ${cliEra} query stake-address-info --address ${stakingAddr} 2> /dev/null )
				if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${rewardsJSON}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
				rewardsJSON=$(jq -rc . <<< "${rewardsJSON}")
				;;

		"light")	showProcessAnimation "Query-StakeAddress-Info-LightMode: " &
				rewardsJSON=$(queryLight_stakeAddressInfo "${stakingAddr}")
				if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${rewardsJSON}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
				;;

		"offline")      readOfflineFile;        #Reads the offlinefile into the offlineJSON variable
				rewardsJSON=$(jq -r ".address.\"${stakingAddr}\".rewardsJSON" <<< ${offlineJSON} 2> /dev/null)
                                if [[ "${rewardsJSON}" == null ]]; then echo -e "\e[35mAddress not included in the offline transferFile, please include it first online!\e[0m\n"; exit; fi
				;;

        esac

        { 	read rewardsEntryCnt;
		read delegationPoolID;
		read keyDepositFee;
		read rewardsAmount;
		read drepDelegation;
		read govActionDepositsCnt;
		read govActionDeposits; } <<< $(jq -r 'length,
						 "\(.[0].stakeDelegation.stakePoolBech32)",
						 .[0].stakeRegistrationDeposit,
						 .[0].rewardAccountBalance,
						 "\(.[0].voteDelegation)" // "notSet",
						 (.[0].govActionDeposits | length),
						 "\(.[0].govActionDeposits)"' <<< ${rewardsJSON})

        if [[ ${rewardsEntryCnt} == 0 ]]; then echo -e "${iconNo} \e[91mStaking Address is not on the chain, register it first !\e[0m\n"; exit 1;
        else echo -e "${iconYes} \e[0mStaking Address is \e[32mregistered\e[0m on the chain with a deposit of \e[32m${keyDepositFee}\e[0m lovelaces :-)\n";
        fi

        #Checking about rewards on the stake address
        if [[ ${rewardsAmount} == 0 ]]; then echo -e "${iconNo} \e[0mRewards: \e[91mNo rewards found :-(\e[0m\n";
        else
		echo -e "${iconYes} \e[0mRewards available: \e[32m$(convertToADA ${rewardsAmount}) ADA / ${rewardsAmount} lovelaces\e[0m\n"
        fi

        #If delegated to a pool, show the current pool ID
        if [[ ! ${delegationPoolID} == null ]]; then
		echo -e "${iconYes} \e[0mAccount is delegated to a Pool with ID: \e[32m${delegationPoolID}\e[0m";

                if [[ ${onlineMode} == true && ${koiosAPI} != "" ]]; then

                        #query poolinfo via poolid on koios
                        errorcnt=0; error=-1;
                        showProcessAnimation "Query Pool-Info via Koios: " &
                        while [[ ${errorcnt} -lt 5 && ${error} -ne 0 ]]; do #try a maximum of 5 times to request the information
                                error=0
			        response=$(curl -sL -m 30 -X POST -w "---spo-scripts---%{http_code}" "${koiosAPI}/pool_info" -H "${koiosAuthorizationHeader}" -H "Accept: application/json" -H "Content-Type: application/json" -d "{\"_pool_bech32_ids\":[\"${delegationPoolID}\"]}" 2> /dev/null)
                                if [[ $? -ne 0 ]]; then error=1; sleep 1; fi; #if there is an error, wait for a second and repeat
                                errorcnt=$(( ${errorcnt} + 1 ))
                        done
                        stopProcessAnimation;

                        #if no error occured, split the response string into JSON content and the HTTP-ResponseCode
                        if [[ ${error} -eq 0 && "${response}" =~ (.*)---spo-scripts---([0-9]*)* ]]; then

                                responseJSON="${BASH_REMATCH[1]}"
                                responseCode="${BASH_REMATCH[2]}"

                                #if the responseCode is 200 (OK) and the received json only contains one entry in the array (will also not be 1 if not a valid json)
                                if [[ ${responseCode} -eq 200 && $(jq ". | length" 2> /dev/null <<< ${responseJSON}) -eq 1 ]]; then
		                        { read poolNameInfo; read poolTickerInfo; read poolStatusInfo; } <<< $(jq -r ".[0].meta_json.name // \"-\", .[0].meta_json.ticker // \"-\", .[0].pool_status // \"-\"" 2> /dev/null <<< ${responseJSON})
                                        echo -e "\e[0m   Info about the Pool: \e[32m${poolNameInfo} (${poolTickerInfo})\e[0m"
                                        echo -e "\e[0m                Status: \e[32m${poolStatusInfo}\e[0m"
					unset poolNameInfo poolTickerInfo poolStatusInfo
                                fi #responseCode & jsoncheck

                        fi #error & response
                        unset errorcnt error

                fi #onlineMode & koiosAPI

		else

		echo -e "${iconNo} \e[0mAccount is not delegated to a Pool";

	fi

	echo

	#Show the current status of the voteDelegation. drepDelegation is in CIP129 format
	case ${drepDelegation} in

		"alwaysNoConfidence")
			#always-no-confidence
			echo -e "${iconYes} \e[0mVoting-Power of Staking Address is currently set to: \e[94mALWAYS NO CONFIDENCE\e[0m";
			;;

		"alwaysAbstain")
			#always-abstain
			echo -e "${iconYes} \e[0mVoting-Power of Staking Address is currently set to: \e[94mALWAYS ABSTAIN\e[0m";
			;;

		"notSet"|"null")
			#no votingpower delegated
			echo -e "${iconNo} \e[0mVoting-Power of Staking Address is not delegated to a DRep\e[0m";
			;;

		*)
			#delegated to a drep/drepscript
			{ read drepId; read drepIdHash;} <<< $(jq -r "(.cip129Bech32 // null), (.keyHash // .scriptHash // null)" <<< ${drepDelegation} 2> /dev/null );
			echo -e "${iconYes} \e[0mVoting-Power of Staking Address is delegated to the following DRep/Script:\e[0m";
			echo -e "\e[0m    CIP129 DRep-ID: \e[33m${drepId}\e[0m";
			drepIdLegacy=$(convert_actionCIP1292Bech "${drepId}");
			echo -e "\e[0m    Legacy DRep-ID: \e[32m${drepIdLegacy}\e[0m";
			echo -e "\e[0m         DRep-HASH:\e[94m ${drepIdHash}\e[0m";
			;;

	esac

        echo

        if [[ ${govActionDepositsCnt} -gt 0 ]]; then
        	echo -e "\e[0m👀 Staking Address is used in the following \e[32m${govActionDepositsCnt}\e[0m governance action(s):";
		readarray -t govActionUtxosArray <<< $(jq -r 'to_entries[] | "\(.key)"' <<< ${govActionDeposits} 2> /dev/null)
		readarray -t govActionDepositArray <<< $(jq -r 'to_entries[] | "\(.value)"' <<< ${govActionDeposits} 2> /dev/null)

		for (( tmpCnt=0; tmpCnt<${govActionDepositsCnt}; tmpCnt++ ))
		do
			govActionID=${govActionUtxosArray[${tmpCnt}]}
			govActionDeposit=$(convertToADA ${govActionDepositArray[${tmpCnt}]})
			echo -e "\e[0m   \e[94m$(convert_actionUTXO2Bech ${govActionID})\e[0m ► \e[32m${govActionDeposit} ADA\e[0m deposit"

		done
		echo

	elif [[ ${workMode} == "online" && ${koiosAPI} != "" ]]; then #do a double check that there is really no governance actions deposit open
		showProcessAnimation "Do a Double-Check about Governance actions via koios: " &
		rewardsJSON=$(queryLight_stakeAddressInfo "${stakingAddr}")
		if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${rewardsJSON}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
		unset govActionDepositsCnt govActionDeposits;
		{ read govActionDepositsCnt; read govActionDeposits; } <<< $(jq -r '(.[0].govActionDeposits | length), "\(.[0].govActionDeposits)"' <<< ${rewardsJSON} 2> /dev/null)

	        if [[ ${govActionDepositsCnt} -gt 0 ]]; then
	        	echo -e "\e[0m👀 Staking Address is used in the following \e[32m${govActionDepositsCnt}\e[0m governance action(s):";
			unset govActionUtxosArray govActionDepositArray
			readarray -t govActionUtxosArray <<< $(jq -r 'to_entries[] | "\(.key)"' <<< ${govActionDeposits} 2> /dev/null)
			readarray -t govActionDepositArray <<< $(jq -r 'to_entries[] | "\(.value)"' <<< ${govActionDeposits} 2> /dev/null)

			for (( tmpCnt=0; tmpCnt<${govActionDepositsCnt}; tmpCnt++ ))
			do
				govActionID=${govActionUtxosArray[${tmpCnt}]}
				govActionDeposit=$(convertToADA ${govActionDepositArray[${tmpCnt}]})
				echo -e "\e[0m   \e[94m$(convert_actionUTXO2Bech ${govActionID})\e[0m ► \e[32m${govActionDeposit} ADA\e[0m deposit"

			done
			echo
		fi

        fi

	abort=0
        if [[ ${rewardsAmount} -gt 0 ]]; then echo -e "\e[33mStake account still holds \e[0m$(convertToADA ${rewardsAmount}) ADA\e[33m of rewards.\nYou need to claim them first via script 01_claimRewards.sh !\e[0m\n"; abort=1; fi
        if [[ ${govActionDepositsCnt} -gt 0 ]]; then echo -e "\e[33mStake account still gets refunds from governance actions, you have to wait until those are finished!\e[0m\n"; abort=1; fi
	if [[ ${abort} -eq 1 ]]; then exit 1; fi


#generate the certificate depending on the era with/without the --key-reg-deposit-amt parameter
case ${cliEra} in

	"babbage"|"alonzo"|"mary"|"allegra"|"shelley")
		echo -e "\e[0mGenerate Retirement-Certificate in ${cliEra} format ...\e[0m\n"
		deregCert=$(${cardanocli} ${cliEra} stake-address deregistration-certificate --stake-address "${stakingAddr}" --out-file /dev/stdout 2> /dev/null)
		;;

	*) #conway and later
		echo -e "\e[0mGenerate Retirement-Certificate with the used deposit fee:\e[32m ${keyDepositFee} lovelaces\e[0m\n"
		deregCert=$(${cardanocli} ${cliEra} stake-address deregistration-certificate --stake-address "${stakingAddr}" --key-reg-deposit-amt "${keyDepositFee}" --out-file /dev/stdout 2> /dev/null)
		;;

esac
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
file_unlock "${addrName}.staking.dereg-cert"
echo -e "${deregCert}" > "${addrName}.staking.dereg-cert" 2> /dev/null
if [ $? -ne 0 ]; then echo -e "\n\e[35mERROR - Could not write out the certificate file ${addrName}.staking.dereg-cert !\n\e[0m"; exit 1; fi
file_lock "${addrName}.staking.dereg-cert"
unset deregCert

echo -e "\e[0mStake Address Retirement-Certificate built:\e[32m ${addrName}.staking.dereg-cert \e[90m"
cat "${addrName}.staking.dereg-cert"

echo -e "\e[0m"

echo -e "\e[33mPlease use script 08b now to submit the Retirement-Certificate!\e[0m"
echo


