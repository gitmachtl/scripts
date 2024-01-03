#!/bin/bash

# Script is brought to you by ATADA Stakepool, Telegram @atada_stakepool

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

echo
echo -e "\e[0mChecking status of Stake Address:\e[32m ${stakingAddr}\e[0m"
echo

#Get stake address info. When in online mode of course from the node and the chain, in light mode via koios, in offlinemode from the transferFile
case ${workMode} in

	"online")       showProcessAnimation "Query-StakeAddress-Info: " &
			rewardsJSON=$(${cardanocli} ${cliEra} query stake-address-info --address ${stakingAddr} 2> /dev/null )
			if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${rewardsJSON}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
			rewardsJSON=$(jq -rc . <<< "${rewardsJSON}")
			;;

	"light")        showProcessAnimation "Query-StakeAddress-Info-LightMode: " &
			rewardsJSON=$(queryLight_stakeAddressInfo "${stakingAddr}")
			if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${rewardsJSON}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
			;;

	"offline")      readOfflineFile;        #Reads the offlinefile into the offlineJSON variable
			rewardsJSON=$(jq -r ".address.\"${stakingAddr}\".rewardsJSON" <<< ${offlineJSON} 2> /dev/null)
			if [[ "${rewardsJSON}" == null ]]; then echo -e "\e[35mAddress not included in the offline transferFile, please include it first online!\e[0m\n"; exit; fi
			;;

esac

#Check if the stake address is registered on the chain, if not, we don't need to unregister it
{ read rewardsEntryCnt; read delegationPoolID; read keyDepositFee; read rewardsAmount; } <<< $(jq -r "length, .[0].delegation // .[0].stakeDelegation, .[0].delegationDeposit, .[0].rewardAccountBalance" <<< ${rewardsJSON})

#Checking about the content
if [[ ${rewardsEntryCnt} == 0 ]]; then #not registered yet
	echo -e "\e[33mStaking Address is NOT on the chain, register it first with script 03b ...\e[0m\n";
	exit;

	else # registered

	echo -e "\e[0mStaking Address is \e[32mregistered\e[0m on the chain with a deposit fee:\e[32m ${keyDepositFee} lovelaces\e[0m\n"

	#If delegated to a pool, show the current pool ID
	if [[ ! ${delegationPoolID} == null ]]; then
		echo -e "Account is delegated to a Pool with ID: \e[32m${delegationPoolID}\e[0m";

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
                                        echo -e "   \t\e[0mInformation about the Pool: \e[32m${poolNameInfo} (${poolTickerInfo})\e[0m"
                                        echo -e "   \t\e[0m                    Status: \e[32m${poolStatusInfo}\e[0m"
                                        echo
					unset poolNameInfo poolTickerInfo poolStatusInfo
                                fi #responseCode & jsoncheck

                        fi #error & response
                        unset errorcnt error

                fi #onlineMode & koiosAPI

	else
		echo -e "\e[0mAccount is not delegated to a Pool !\n";
	fi ## ${delegationPoolID} == null

        if [[ ${rewardsAmount} == null || ${rewardsAmount} -ne 0 ]]; then echo -e "\e[33mStake account still holds \e[0m$(convertToADA ${rewardsAmount}) ADA\e[33m of rewards.\nYou need to claim them first via script 01_claimRewards.sh !\e[0m\n"; exit; fi

fi ## ${rewardsEntryCnt} == 0

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


