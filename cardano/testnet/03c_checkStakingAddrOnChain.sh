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

        echo -e "\e[0mChecking current ChainStatus of Stake-Address: ${checkAddr}"
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

        rewardsEntryCnt=$(jq -r 'length' <<< ${rewardsJSON})

        #Checking about the content
        if [[ ${rewardsEntryCnt} == 0 ]]; then #not registered yet
                echo -e "\e[0mStaking Address is NOT on the chain, register it first with script 03b ...\e[0m\n";
                else #already registered
                        echo -e "\e[33mStaking Address is already registered on the chain !\e[0m\n"

                        delegationPoolID=$(jq -r ".[0].delegation" <<< ${rewardsJSON})

                        #If delegated to a pool, show the current pool ID
                        if [[ ! ${delegationPoolID} == null ]]; then
                                echo -e "   \tAccount is delegated to a Pool with ID: \e[32m${delegationPoolID}\e[0m";
                                #query poolinfo via poolid on koios
                                showProcessAnimation "Query Pool-Info via Koios: " &
                                response=$(curl -sL -m 10 -X POST "${koiosAPI}/pool_info" -H "Accept: application/json" -H "Content-Type: application/json" -d "{\"_pool_bech32_ids\":[\"${delegationPoolID}\"]}" 2> /dev/null)
                                stopProcessAnimation;
                                #check if the received json only contains one entry in the array (will also not be 1 if not a valid json)
                                if [[ $(jq ". | length" 2> /dev/null <<< ${response}) -eq 1 ]]; then
                                        poolName=$(jq -r ".[0].meta_json.name | select (.!=null)" 2> /dev/null <<< ${response})
                                        poolTicker=$(jq -r ".[0].meta_json.ticker | select (.!=null)" 2> /dev/null <<< ${response})
                                        poolStatus=$(jq -r ".[0].pool_status | select (.!=null)" 2> /dev/null <<< ${response})
                                        echo -e "   \t\e[0mInformation about the Pool: \e[32m${poolName} (${poolTicker})\e[0m"
                                        echo -e "   \t\e[0m                    Status: \e[32m${poolStatus}\e[0m"
                                        echo
                                fi
                        else
                                echo -e "   \tAccount is not delegated to a Pool !";
                        fi

                        exit #because already registered
        fi ## ${rewardsEntryCnt} == 0


else #unsupported address type

	echo -e "\e[35mAddress type unknown!\e[0m";

fi ## typeOfAddr

