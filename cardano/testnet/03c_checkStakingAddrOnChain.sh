#!/bin/bash

# Script is brought to you by ATADA Stakepool, Telegram @atada_stakepool

#load variables and functions from common.sh
. "$(dirname "$0")"/00_common.sh

#Check the commandline parameter
if [[ $# -eq 1 && ! $1 == "" ]]; then addrName="$(dirname $1)/$(basename $(basename $1 .addr) .staking)"; addrName=${addrName/#.\//}; else echo "ERROR - Usage: $0 <AdressName or HASH>"; exit 2; fi

#Check can only be done in online mode
if ${offlineMode}; then echo -e "\e[35mYou have to be in ONLINE or LIGHT mode to do this!\e[0m\n"; exit 1; fi

#Check if Address file doesn not exists, make a dummy one in the temp directory and fill in the given parameter as the hash address
if [ ! -f "${addrName}.staking.addr" ]; then echo "$(basename ${addrName})" > ${tempDir}/tempAddr.staking.addr; addrName="${tempDir}/tempAddr"; fi

checkAddr=$(cat ${addrName}.staking.addr)

typeOfAddr=$(get_addressType "${checkAddr}")

#What type of Address is it? Stake?
if [[ ${typeOfAddr} == ${addrTypeStake} ]]; then  #Staking Address

        echo -e "\e[0mChecking current ChainStatus of Stake-Address: \e[32m${checkAddr}\e[0m"
        echo

        #Get rewards state data for the address. When in online mode of course from the node and the chain, in light mode via koios
        case ${workMode} in

                "online")       showProcessAnimation "Query-StakeAddress-Info: " &
                                rewardsJSON=$(${cardanocli} ${cliEra} query stake-address-info --address ${checkAddr} 2> /dev/stdout)
                                if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${rewardsJSON}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
                                rewardsJSON=$(jq -rc . <<< "${rewardsJSON}")
                                ;;

                "light")        showProcessAnimation "Query-StakeAddress-Info-LightMode: " &
                                rewardsJSON=$(queryLight_stakeAddressInfo "${checkAddr}")
                                if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${rewardsJSON}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
                                ;;

        esac

	{ read rewardsEntryCnt; read delegationPoolID; read keyDepositFee; read rewardsAmount; } <<< $(jq -r "length, .[0].delegation // .[0].stakeDelegation, .[0].delegationDeposit, .[0].rewardAccountBalance" <<< ${rewardsJSON})

        rewardsEntryCnt=$(jq -r 'length' <<< ${rewardsJSON})

        #Checking about the content
        if [[ ${rewardsEntryCnt} == 0 ]]; then #not registered yet
                echo -e "\e[33mStaking Address is NOT on the chain, register it first with script 03b ...\e[0m\n";
                else #already registered

                        echo -e "\e[0mStaking Address is \e[32mregistered\e[0m on the chain with a deposit of \e[32m${keyDepositFee}\e[0m lovelaces !\n"

                        #If delegated to a pool, show the current pool ID
                        if [[ ! ${delegationPoolID} == null ]]; then

                                echo -e "Account is delegated to a Pool with ID: \e[32m${delegationPoolID}\e[0m";

		                if [[ ${onlineMode} == true && ${koiosAPI} != "" ]]; then

		                        #query poolinfo via poolid on koios
		                        errorcnt=0; error=-1;
		                        showProcessAnimation "Query Pool-Info via Koios: " &
		                        while [[ ${errorcnt} -lt 5 && ${error} -ne 0 ]]; do #try a maximum of 5 times to request the information
		                                error=0
					        response=$(curl -sL -m 30 -X POST -w "---spo-scripts---%{http_code}" "${koiosAPI}/pool_info" -H "Accept: application/json" -H "Content-Type: application/json" -d "{\"_pool_bech32_ids\":[\"${delegationPoolID}\"]}" 2> /dev/null)
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
                        fi

                        exit #because already registered
        fi ## ${rewardsEntryCnt} == 0


else #unsupported address type

	echo -e "\e[35mAddress type unknown!\e[0m";

fi ## typeOfAddr
