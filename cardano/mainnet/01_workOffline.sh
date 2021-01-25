#!/bin/bash

# Script is brought to you by ATADA_Stakepool, Telegram @atada_stakepool

#load variables from common.sh
. "$(dirname "$0")"/00_common.sh

#Display usage instructions
showUsage() {
cat >&2 <<EOF
Usage:    $(basename $0) new                ... Resets the '$(basename ${offlineFile})' with only the current protocol-parameters in it
          $(basename $0) info               ... Displayes the Address and TX info in the '$(basename ${offlineFile})'

	  $(basename $0) add mywallet       ... Adds the UTXO info of mywallet.addr to the '$(basename ${offlineFile})'
          $(basename $0) add owner.staking  ... Adds the Rewards info of owner.staking to the '$(basename ${offlineFile})'

          $(basename $0) execute            ... Executes the first cued transaction in the '$(basename ${offlineFile})'
          $(basename $0) execute 3          ... Executes the third cued transaction in the '$(basename ${offlineFile})'

          $(basename $0) attach <filename>  ... This will attach a small file <filename> into the '$(basename ${offlineFile})'
          $(basename $0) extract            ... Extract the attached files in the '$(basename ${offlineFile})'

          $(basename $0) cleartx            ... Removes the cued transactions in the '$(basename ${offlineFile})'
          $(basename $0) clearhistory       ... Removes the history in the '$(basename ${offlineFile})'
          $(basename $0) clearfiles         ... Removes the attached files in the '$(basename ${offlineFile})'

EOF
}

#Check commandline parameters
if [[ $# -eq 0 ]]; then $(showUsage); exit 1; fi
case ${1} in
  cleartx|clearhistory|clearfiles|extract|info )
		action="${1}"
		;;

  new|execute )
		action="${1}";
		if ${offlineMode}; then echo -e "\e[35mYou have to be in ONLINE MODE to do this!\e[0m\n"; exit 1; fi
                if [[ $# -eq 2 ]]; then executeCue=${2}; else executeCue=1; fi
		;;

  add )
		action="${1}";
		if ${offlineMode}; then echo -e "\e[35mYou have to be in ONLINE MODE to do this!\e[0m\n"; exit 1; fi
		if [[ $# -eq 2 ]]; then addrName="$(dirname $2)/$(basename $2 .addr)"; addrName=${addrName/#.\//}; else echo -e "\e[35mMissing AddressName for the Address!\e[0m\n"; showUsage; exit 1; fi
		if [ ! -f "${addrName}.addr" ]; then echo -e "\e[35mNo ${addrName}.addr file found for the Address!\e[0m\n"; showUsage; exit 1; fi
		;;

  attach )
                action="${1}";
                if [[ $# -eq 2 ]]; then fileToAttach="${2}"; else echo -e "\e[35mMissing File to attach!\e[0m\n"; showUsage; exit 1; fi
                if [ ! -f "${fileToAttach}" ]; then echo -e "\e[35mNo ${fileToAttach} file found on that location!\e[0m\n"; showUsage; exit 1; fi
                ;;

  * ) 		showUsage; exit 1;
		;;
esac


#Read the current offlineFile
if [ -f "${offlineFile}" ]; then
				offlineJSON=$(jq . ${offlineFile} 2> /dev/null)
				if [[ $? -ne 0 ]]; then echo -e "\e[35mERROR - '$(basename ${offlineFile})' is not a valid JSON file, please delete it.\e[0m\n"; exit 1; fi
				if [[ $(trimString "${offlineJSON}") == "" ]]; then offlineJSON="{}"; fi #nothing in the file, make a new one
			    else
				offlineJSON="{}";
			    fi


case ${action} in
  cleartx )
		#Clear the history entries from the offlineJSON
		offlineJSON=$( jq "del (.transactions)" <<< ${offlineJSON})
		offlineJSON=$( jq ".history += [ { date: \"$(date -R)\", action: \"cleared all transactions\" } ]" <<< ${offlineJSON})
	        #Write the new offileFile content
	        echo "${offlineJSON}" > ${offlineFile}
		showOfflineFileInfo;
		echo -e "\e[33mTransactions in the '$(basename ${offlineFile})' have been cleared, you can start over.\e[0m\n";
		exit;
                ;;

  clearhistory )
		#Clear the history entries from the offlineJSON
                offlineJSON=$( jq "del (.history)" <<< ${offlineJSON})
                offlineJSON=$( jq ".history += [ { date: \"$(date -R)\", action: \"history cleared\" } ]" <<< ${offlineJSON})
                #Write the new offileFile content
                echo "${offlineJSON}" > ${offlineFile}
		showOfflineFileInfo;
                echo -e "\e[33mWho needs History in the '$(basename ${offlineFile})', cleared. :-)\e[0m\n";
                exit;
                ;;

  clearfiles )
                #Clear the files entries from the offlineJSON
                offlineJSON=$( jq "del (.files)" <<< ${offlineJSON})
                offlineJSON=$( jq ".history += [ { date: \"$(date -R)\", action: \"attached files cleared\" } ]" <<< ${offlineJSON})
                #Write the new offileFile content
                echo "${offlineJSON}" > ${offlineFile}
                showOfflineFileInfo;
                echo -e "\e[33mAll attached files within the '$(basename ${offlineFile})' were cleared. :-)\e[0m\n";
                exit;
                ;;

  new )
		#Build a fresh new offlineJSON with the current protocolParameters in it
		offlineJSON="{}";
		protocolParametersJSON=$(${cardanocli} ${subCommand} query protocol-parameters --cardano-mode ${magicparam} ${nodeEraParam})
		checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
		offlineJSON=$( jq ".general += {onlineCLI: \"${versionCLI}\" }" <<< ${offlineJSON})
		offlineJSON=$( jq ".general += {onlineNODE: \"${versionNODE}\" }" <<< ${offlineJSON})
		offlineJSON=$( jq ".protocol += {parameters: ${protocolParametersJSON} }" <<< ${offlineJSON})
		offlineJSON=$( jq ".protocol += {era: \"$(get_NodeEra)\" }" <<< ${offlineJSON})
                offlineJSON=$( jq ".history += [ { date: \"$(date -R)\", action: \"new file created\" } ]" <<< ${offlineJSON})
                #Write the new offileFile content
                echo "${offlineJSON}" > ${offlineFile}
		showOfflineFileInfo;
                echo -e "\e[33mThe '$(basename ${offlineFile})' has been set to a good looking and clean fresh state. :-)\e[0m\n";
                exit;
                ;;

  add )
		#Updating the current protocolParameters before doing other stuff later on
                protocolParametersJSON=$(${cardanocli} ${subCommand} query protocol-parameters --cardano-mode ${magicparam} ${nodeEraParam})
                checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
                offlineJSON=$( jq ".general += {onlineCLI: \"${versionCLI}\" }" <<< ${offlineJSON})
                offlineJSON=$( jq ".general += {onlineNODE: \"${versionNODE}\" }" <<< ${offlineJSON})
                offlineJSON=$( jq ".protocol += {parameters: ${protocolParametersJSON} }" <<< ${offlineJSON})
                offlineJSON=$( jq ".protocol += {era: \"$(get_NodeEra)\" }" <<< ${offlineJSON})
                ;;


  info )
		#Displays infos about the content in the offlineJSON
		showOfflineFileInfo;

		#Check if there are any files attached
		filesCnt=$(jq -r ".files | length" <<< ${offlineJSON});
		if [[ ${filesCnt} -gt 0 ]]; then echo -e "\e[33mThere are ${filesCnt} files attached in the '$(basename ${offlineFile})'. You can extract them by running the command: $(basename $0) extract\e[0m\n"; fi

		#Check the number of pending transactions
		transactionsCnt=$(jq -r ".transactions | length" <<< ${offlineJSON})
		if [[ ${transactionsCnt} -gt 0 ]]; then echo -e "\e[33mThere are ${transactionsCnt} pending transactions in the '$(basename ${offlineFile})'. You can submit them by running the command: $(basename $0) execute\e[0m\n"; fi
		exit;
		;;

  attach )
		#Attach a given File into the offlineJSON
                readOfflineFile;
                offlineJSON=$( jq ".files.\"${fileToAttach}\" += { date: \"$(date -R)\", size: \"$(du -b ${fileToAttach} | cut -f1)\", base64: \"$(base64 -w 0 ${fileToAttach})\" }" <<< ${offlineJSON});

                if [[ $? -eq 0 ]]; then
                                        offlineJSON=$( jq ".history += [ { date: \"$(date -R)\", action: \"attached file '${fileToAttach}'\" } ]" <<< ${offlineJSON})
                                        echo "${offlineJSON}" > ${offlineFile}
                			showOfflineFileInfo;
                			echo -e "\e[33mFile '${fileToAttach}' was attached into the '$(basename ${offlineFile})'. :-)\e[0m\n";
				   else
                                        echo -e "\e[35mERROR - Could not attach file '${fileToAttach}' to the '$(basename ${offlineFile})'. :-)\e[0m\n"; exit 1;
				   fi
                exit;
		;;

esac


###########################################
###
### action = add
###
###########################################
#
# START

if [[ "${action}" == "add" ]]; then

checkAddr=$(cat ${addrName}.addr)

typeOfAddr=$(get_addressType "${checkAddr}")

#What type of Address is it? Base&Enterprise or Stake
if [[ ${typeOfAddr} == ${addrTypePayment} ]]; then  #Enterprise and Base UTXO adresses

	echo -e "\e[0mChecking UTXOs of Address-File\e[32m ${addrName}.addr\e[0m: ${checkAddr}"
	echo

	echo -e "\e[0mAddress-Type / Era:\e[32m $(get_addressType "${checkAddr}")\e[0m / \e[32m$(get_addressEra "${checkAddr}")\e[0m"
	echo

	#Get UTX0 Data for the address
	utxoJSON=$(${cardanocli} ${subCommand} query utxo --address ${checkAddr} --cardano-mode ${magicparam} ${nodeEraParam} --out-file /dev/stdout); checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi;
	utxoEntryCnt=$(jq length <<< ${utxoJSON})
	if [[ ${utxoEntryCnt} == 0 ]]; then echo -e "\e[35mNo funds on the Address!\e[0m\n"; exit; else echo -e "\e[32m${utxoEntryCnt} UTXOs\e[0m found on the Address!"; fi
	echo

	#Convert UTXO into mary style if UTXO is shelley/allegra style
	if [[ ! "$(jq -r '[.[]][0].amount | type' <<< ${utxoJSON})" == "array" ]]; then utxoJSON=$(convert_UTXO "${utxoJSON}"); fi

	#Calculating the total amount of lovelaces in all utxos on this address
	totalLovelaces=$(jq '[.[].amount[0]] | add' <<< ${utxoJSON})

	totalAssetsJSON="{}"; #Building a total JSON with the different assetstypes "policyIdHash.name", amount and name
	totalPolicyIDsJSON="{}"; #Holds the different PolicyIDs as values "policyIDHash", length is the amount of different policyIDs

	#For each utxo entry, check the utxo#index and check if there are also any assets in that utxo#index
	#LEVEL 1 - different UTXOs
	for (( tmpCnt=0; tmpCnt<${utxoEntryCnt}; tmpCnt++ ))
	do
	utxoHashIndex=$(jq -r "keys_unsorted[${tmpCnt}]" <<< ${utxoJSON})
	utxoAmount=$(jq -r ".\"${utxoHashIndex}\".amount[0]" <<< ${utxoJSON})   #Lovelaces
	echo -e "Hash#Index: ${utxoHashIndex}\tAmount: ${utxoAmount}"
	assetsJSON=$(jq -r ".\"${utxoHashIndex}\".amount[1]" <<< ${utxoJSON})
	assetsEntryCnt=$(jq length <<< ${assetsJSON})
	if [[ ${assetsEntryCnt} -gt 0 ]]; then
			#LEVEL 2 - different policyIDs
			for (( tmpCnt2=0; tmpCnt2<${assetsEntryCnt}; tmpCnt2++ ))
		        do
		        assetHash=$(jq -r ".[${tmpCnt2}][0]" <<< ${assetsJSON})  #assetHash = policyID
			assetsNameCnt=$(jq ".[${tmpCnt2}][1] | length" <<< ${assetsJSON})
			totalPolicyIDsJSON=$( jq ". += {\"${assetHash}\": 1}" <<< ${totalPolicyIDsJSON})

				#LEVEL 3 - different names under the same policyID
				for (( tmpCnt3=0; tmpCnt3<${assetsNameCnt}; tmpCnt3++ ))
	                        do
                        	assetName=$(jq -r ".[${tmpCnt2}][1][${tmpCnt3}][0]" <<< ${assetsJSON})
                        	assetAmount=$(jq -r ".[${tmpCnt2}][1][${tmpCnt3}][1]" <<< ${assetsJSON})
				oldValue=$(jq -r ".\"${assetHash}.${assetName}\".amount" <<< ${totalAssetsJSON})
				newValue=$((${oldValue}+${assetAmount}))
				totalAssetsJSON=$( jq ". += {\"${assetHash}.${assetName}\":{amount: ${newValue}, name: \"${assetName}\"}}" <<< ${totalAssetsJSON})
        	                echo -e "\e[90m               PolID: ${assetHash}\tAmount: ${assetAmount} ${assetName}\e[0m"
				done
			done

	fi
	done
	echo -e "\e[0m-----------------------------------------------------------------------------------------------------"
	totalInADA=$(bc <<< "scale=6; ${totalLovelaces} / 1000000")
	echo -e "Total ADA on the Address:\e[32m  ${totalInADA} ADA / ${totalLovelaces} lovelaces \e[0m\n"

	totalPolicyIDsCnt=$(jq length <<< ${totalPolicyIDsJSON});

	totalAssetsCnt=$(jq length <<< ${totalAssetsJSON});
	if [[ ${totalAssetsCnt} -gt 0 ]]; then
			echo -e "\e[32m${totalAssetsCnt} Asset-Type(s) / ${totalPolicyIDsCnt} different PolicyIDs\e[0m found on the Address!\n"
			printf "\e[0m%-70s %16s %s\n" "PolicyID.Name:" "Total-Amount:" "Name:"
                        for (( tmpCnt=0; tmpCnt<${totalAssetsCnt}; tmpCnt++ ))
                        do
			assetHashName=$(jq -r "keys[${tmpCnt}]" <<< ${totalAssetsJSON})
                        assetAmount=$(jq -r ".\"${assetHashName}\".amount" <<< ${totalAssetsJSON})
			assetName=$(jq -r ".\"${assetHashName}\".name" <<< ${totalAssetsJSON})
			printf "\e[90m%-70s \e[32m%16s %s\e[0m\n" "${assetHashName}" "${assetAmount}" "${assetName}"
			done
        fi
	echo

	#Add this address to the offline.json file
	offlineJSON=$( jq ".address.\"${checkAddr}\" += {name: \"${addrName}\" }" <<< ${offlineJSON})
        offlineJSON=$( jq ".address.\"${checkAddr}\" += {totalamount: ${totalLovelaces} }" <<< ${offlineJSON})
        offlineJSON=$( jq ".address.\"${checkAddr}\" += {totalassetscnt: ${totalAssetsCnt} }" <<< ${offlineJSON})
        offlineJSON=$( jq ".address.\"${checkAddr}\" += {date: \"$(date -R)\" }" <<< ${offlineJSON})
        offlineJSON=$( jq ".address.\"${checkAddr}\" += {used: \"no\" }" <<< ${offlineJSON})
        offlineJSON=$( jq ".address.\"${checkAddr}\" += {type: \"${typeOfAddr}\" }" <<< ${offlineJSON})
        offlineJSON=$( jq ".address.\"${checkAddr}\" += {utxoJSON: ${utxoJSON} }" <<< ${offlineJSON})

        offlineJSON=$( jq ".history += [ { date: \"$(date -R)\", action: \"added utxo-info for '${addrName}'\" } ]" <<< ${offlineJSON})

	#Write the new offileFile content
	echo "${offlineJSON}" > ${offlineFile}

	#Readback the content and compare it to the current one
	utxoJSON=$(jq . <<< ${utxoJSON}) # bring it into the same format
        readback=$(cat ${offlineFile} | jq -r ".address.\"${checkAddr}\".utxoJSON")
        if [[ "${utxoJSON}" == "${readback}" ]]; then
							showOfflineFileInfo;
							echo -e "\e[33mLatest Information about this address was added to the '$(basename ${offlineFile})'.\nYou can now transfer it to your offline machine to work with it, or you can\nadd another address information to the file by re-running this script.\e[0m\n";
						 else
                                                        echo -e "\e[35mERROR - Could not verify the written data in the '$(basename ${offlineFile})'. Retry or delete the offlineFile and retry again.\e[0m\n";
	fi


elif [[ ${typeOfAddr} == ${addrTypeStake} ]]; then  #Staking Address

	echo -e "\e[0mChecking Rewards on Stake-Address-File\e[32m ${addrName}.addr\e[0m: ${checkAddr}"
	echo

        echo -e "\e[0mAddress-Type / Era:\e[32m $(get_addressType "${checkAddr}")\e[0m / \e[32m$(get_addressEra "${checkAddr}")\e[0m"
        echo

        rewardsJSON=$(${cardanocli} ${subCommand} query stake-address-info --address ${checkAddr} --cardano-mode ${magicparam} ${nodeEraParam} | jq -rc .)
        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

        rewardsEntryCnt=$(jq -r 'length' <<< ${rewardsJSON})

        if [[ ${rewardsEntryCnt} == 0 ]]; then echo -e "\e[35mStaking Address is not on the chain, register it first !\e[0m\n"; exit 1;
        else echo -e "\e[0mFound:\e[32m ${rewardsEntryCnt}\e[0m entries\n";
        fi

        rewardsSum=0

        for (( tmpCnt=0; tmpCnt<${rewardsEntryCnt}; tmpCnt++ ))
        do
        rewardsAmount=$(jq -r ".[${tmpCnt}].rewardAccountBalance" <<< ${rewardsJSON})
	rewardsAmountInADA=$(bc <<< "scale=6; ${rewardsAmount} / 1000000")

        delegationPoolID=$(jq -r ".[${tmpCnt}].delegation" <<< ${rewardsJSON})

        rewardsSum=$((${rewardsSum}+${rewardsAmount}))
	rewardsSumInADA=$(bc <<< "scale=6; ${rewardsSum} / 1000000")

        echo -ne "[$((${tmpCnt}+1))]\t"

        #Checking about rewards on the stake address
        if [[ ${rewardsAmount} == 0 ]]; then echo -e "\e[35mNo rewards found on the stake Addr !\e[0m";
        else echo -e "Entry Rewards: \e[33m${rewardsAmountInADA} ADA / ${rewardsAmount} lovelaces\e[0m"
        fi

        #If delegated to a pool, show the current pool ID
        if [[ ! ${delegationPoolID} == null ]]; then echo -e "   \tAccount is delegated to a Pool with ID: \e[32m${delegationPoolID}\e[0m"; fi

        echo

        done

        if [[ ${rewardsEntryCnt} -gt 1 ]]; then echo -e "   \t-----------------------------------------\n"; echo -e "   \tTotal Rewards: \e[33m${rewardsSumInADA} ADA / ${rewardsSum} lovelaces\e[0m\n"; fi

        #Add this address to the offline.json file
        offlineJSON=$( jq ".address.\"${checkAddr}\" += {name: \"${addrName}\" }" <<< ${offlineJSON})
        offlineJSON=$( jq ".address.\"${checkAddr}\" += {totalamount: ${rewardsSum} }" <<< ${offlineJSON})
        offlineJSON=$( jq ".address.\"${checkAddr}\" += {date: \"$(date -R)\" }" <<< ${offlineJSON})
        offlineJSON=$( jq ".address.\"${checkAddr}\" += {used: \"no\" }" <<< ${offlineJSON})
        offlineJSON=$( jq ".address.\"${checkAddr}\" += {type: \"${typeOfAddr}\" }" <<< ${offlineJSON})
        offlineJSON=$( jq ".address.\"${checkAddr}\" += {rewardsJSON: ${rewardsJSON} }" <<< ${offlineJSON})

        offlineJSON=$( jq ".history += [ { date: \"$(date -R)\", action: \"added stake address rewards-state for '${addrName}'\" } ]" <<< ${offlineJSON})

        #Write the new offileFile content
        echo "${offlineJSON}" > ${offlineFile}

        #Readback the content and compare it to the current one
        rewardsJSON=$(jq . <<< ${rewardsJSON}) # bring it into the same format
        readback=$(cat ${offlineFile} | jq -r ".address.\"${checkAddr}\".rewardsJSON")
        if [[ "${rewardsJSON}" == "${readback}" ]]; then
							showOfflineFileInfo;
							echo -e "\e[33mLatest Information about this address was added to the '$(basename ${offlineFile})'.\nYou can now transfer it to your offline machine to work with it, or you can\nadd another address information to the file by re-running this script.\e[0m\n";
                                                 else
                                                        echo -e "\e[35mERROR - Could not verify the written data in the offlineFile '${offlineFile}'. Retry or delete the offlineFile and retry again.\e[0m\n";
        fi


else #unsupported address type

	echo -e "\e[35mAddress type unknown!\e[0m"; exit 1;
fi

fi # END
#
###########################################
###
### action = add
###
###########################################


###########################################
###
### action = execute
###
###########################################
#
# START

if [[ "${action}" == "execute" ]]; then

#Show Information first
showOfflineFileInfo;

#Check the number of pending transactions
transactionsCnt=$(jq -r ".transactions | length" <<< ${offlineJSON})
if [[ ${transactionsCnt} -eq 0 ]]; then echo -e "\e[33mNo pending transactions found in the '$(basename ${offlineFile})'.\e[0m\n"; exit; fi

#Check that the online and offline cli version is the same
offlineVersionCLI=$(jq -r ".general.offlineCLI" <<< ${offlineJSON})
if [[ ! "${offlineVersionCLI}" == "${versionCLI}" ]]; then echo -e "\e[33mWARNING - Online(${versionCLI}) and Offline(${offlineVersionCLI}) CLI version mismatch!\e[0m\n"; fi

if [[ ${executeCue} -gt 0 && ${executeCue} -le ${transactionsCnt} ]]; then transactionCue=${executeCue}; else echo -e "\e[35mERROR - There is no cued transaction with ID=${executeCue} available!\e[0m\n"; exit 1; fi
transactionIdx=$(( ${transactionCue} - 1 ));

#Execute the first or given transaction in cue
echo "------------------"
echo
echo -e "\e[33mExecute Transaction in Cue [${transactionCue}]: "
echo

#Check that the protocol era is still the same
transactionEra=$(jq -r ".transactions[${transactionIdx}].era" <<< ${offlineJSON})
if [[ ! "${transactionEra}" == "$(get_NodeEra)" ]]; then echo -e "\e[35mERROR - Online($(get_NodeEra)) and Offline(${transactionEra}) Era mismatch!\e[0m\n"; exit 1; fi

transactionType=$(jq -r ".transactions[${transactionIdx}].type" <<< ${offlineJSON})
transactionDate=$(jq -r ".transactions[${transactionIdx}].date" <<< ${offlineJSON})
transactionFromName=$(jq -r ".transactions[${transactionIdx}].fromAddr" <<< ${offlineJSON})
transactionFromAddr=$(jq -r ".transactions[${transactionIdx}].sendFromAddr" <<< ${offlineJSON})
transactionToName=$(jq -r ".transactions[${transactionIdx}].toAddr" <<< ${offlineJSON})
transactionToAddr=$(jq -r ".transactions[${transactionIdx}].sendToAddr" <<< ${offlineJSON})
transactionTxJSON=$(jq -r ".transactions[${transactionIdx}].txJSON" <<< ${offlineJSON})

case ${transactionType} in
        Transaction|Asset-Minting|Asset-Burning )
                        #Normal UTXO Transaction (lovelaces and/or tokens)

			#Check that the UTXO on the paymentAddress (transactionFromAddr) has not changed
			utxoLiveJSON=$(${cardanocli} ${subCommand} query utxo --address ${transactionFromAddr} --cardano-mode ${magicparam} ${nodeEraParam} --out-file /dev/stdout); checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
			#Convert UTXO into mary style if UTXO is shelley/allegra style
			if [[ ! "$(jq -r '[.[]][0].amount | type' <<< ${utxoLiveJSON})" == "array" ]]; then utxoLiveJSON=$(convert_UTXO "${utxoLiveJSON}"); fi
			utxoLiveJSON=$(jq . <<< ${utxoLiveJSON})
			utxoOfflineJSON=$(jq -r ".address.\"${transactionFromAddr}\".utxoJSON" <<< ${offlineJSON})
		if [[ ! "${utxoLiveJSON}" == "${utxoOfflineJSON}" ]]; then echo -e "\e[35mERROR - The UTXO status between the offline capture and now has changed for the payment address '${transactionFromName}' !\e[0m\n"; exit 1; fi

			echo -e "\e[32m\t[${transactionCue}]\t\e[0m${transactionType}[${transactionEra}] from '${transactionFromName}' to '${transactionToName}' \e[90m(${transactionDate})\n\t   \t\e[90mfrom ${transactionFromAddr}\n\t   \t\e[90mto ${transactionToAddr}\e[0m"
			echo
			txID=$(${cardanocli} ${subCommand} transaction txid --tx-file <(echo ${transactionTxJSON}) )
			echo -e "\e[0mTxID will be: \e[32m${txID}\e[0m\n"

			if ask "\e[33mDoes this look good for you, continue ?" N; then
	                        ${cardanocli} ${subCommand} transaction submit --tx-file <(echo ${transactionTxJSON}) --cardano-mode ${magicparam}
	                        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
                                echo -e "\n\e[0mStatus: \e[36mDONE - Transaction submitted\n"
				if [[ ${magicparam} == "--mainnet" ]]; then echo -e "\e[0mTracking: \e[32mhttps://cardanoscan.io/transaction/${txID}\n"; fi
				echo
                                #Write the new offileFile content
				offlineJSON=$( jq ".address.\"${transactionFromAddr}\" += {used: \"yes\" }" <<< ${offlineJSON}) #mark payment address as used
				if [[ ! "$(jq -r .address.\"${transactionToAddr}\" <<< ${offlineJSON})" == null ]]; then offlineJSON=$( jq ".address.\"${transactionToAddr}\" += {used: \"yes\" }" <<< ${offlineJSON}); fi #mark destination address as used if present
                                offlineJSON=$( jq ".history += [ { date: \"$(date -R)\", action: \"tx submit ${txID} - utxo from '${transactionFromName}' to '${transactionToName}'\" } ]" <<< ${offlineJSON})
                                offlineJSON=$( jq "del (.transactions[${transactionIdx}])" <<< ${offlineJSON})
                                echo "${offlineJSON}" > ${offlineFile}
				showOfflineFileInfo;
				echo
        		fi
                        ;;


        Withdrawal )
                        #Rewards Withdrawal Transaction
                        transactionStakeName=$(jq -r ".transactions[${transactionIdx}].stakeAddr" <<< ${offlineJSON})
                        transactionStakeAddr=$(jq -r ".transactions[${transactionIdx}].stakingAddr" <<< ${offlineJSON})

                        #Check that the UTXO on the paymentAddress (transactionFromAddr) has not changed
                        utxoLiveJSON=$(${cardanocli} ${subCommand} query utxo --address ${transactionFromAddr} --cardano-mode ${magicparam} ${nodeEraParam} --out-file /dev/stdout); checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi;
                        #Convert UTXO into mary style if UTXO is shelley/allegra style
                        if [[ ! "$(jq -r '[.[]][0].amount | type' <<< ${utxoLiveJSON})" == "array" ]]; then utxoLiveJSON=$(convert_UTXO "${utxoLiveJSON}"); fi
                        utxoLiveJSON=$(jq . <<< ${utxoLiveJSON})
                        utxoOfflineJSON=$(jq -r ".address.\"${transactionFromAddr}\".utxoJSON" <<< ${offlineJSON})
			if [[ ! "${utxoLiveJSON}" == "${utxoOfflineJSON}" ]]; then echo -e "\e[35mERROR - The UTXO status between the offline capture and now has changed for the payment address '${transactionFromName}' !\e[0m\n"; exit 1; fi

			#Check that the RewardsState of the StakeAddress (transactionStakeAddr) has not changed
			rewardsLiveJSON=$(${cardanocli} ${subCommand} query stake-address-info --address ${transactionStakeAddr} --cardano-mode ${magicparam} ${nodeEraParam} | jq .); checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi;
                        rewardsOfflineJSON=$(jq -r ".address.\"${transactionStakeAddr}\".rewardsJSON" <<< ${offlineJSON})
			if [[ ! "${rewardsLiveJSON}" == "${rewardsOfflineJSON}" ]]; then echo -e "\e[35mERROR - The rewards state between the offline capture and now has changed for the stake address '${transactionStakeName}' !\e[0m\n"; exit 1; fi

                        echo -e "\e[32m\t[${transactionCue}]\t\e[0mRewards-Withdrawal[${transactionEra}] from '${transactionStakeName}' to '${transactionToName}', payment via '${transactionFromName}' \e[90m(${transactionDate})"
                        echo -e "\t   \t\e[90mfrom ${transactionStakeAddr}\n\t   \t\e[90mto ${transactionToAddr}\n\t   \t\e[90mpayment via ${transactionFromAddr}\e[0m"
                        echo
                        txID=$(${cardanocli} ${subCommand} transaction txid --tx-file <(echo ${transactionTxJSON}) )
                        echo -e "\e[0mTxID will be: \e[32m${txID}\e[0m\n"

                        if ask "\e[33mDoes this look good for you, continue ?" N; then
                                ${cardanocli} ${subCommand} transaction submit --tx-file <(echo ${transactionTxJSON}) --cardano-mode ${magicparam}
                                checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
                                echo -e "\n\e[0mStatus: \e[36mDONE - Transaction submitted\n"
                                if [[ ${magicparam} == "--mainnet" ]]; then echo -e "\e[0mTracking: \e[32mhttps://cardanoscan.io/transaction/${txID}\n"; fi
                                echo
                                #Write the new offileFile content
				offlineJSON=$( jq ".address.\"${transactionFromAddr}\" += {used: \"yes\" }" <<< ${offlineJSON})
				offlineJSON=$( jq ".address.\"${transactionStakeAddr}\" += {used: \"yes\" }" <<< ${offlineJSON})
				if [[ ! "$(jq -r .address.\"${transactionToAddr}\" <<< ${offlineJSON})" == null ]]; then offlineJSON=$( jq ".address.\"${transactionToAddr}\" += {used: \"yes\" }" <<< ${offlineJSON}); fi #mark destination address as used if present
                                offlineJSON=$( jq ".history += [ { date: \"$(date -R)\", action: \"tx submit ${txID} - withdrawal from '${transactionStakeName}' to '${transactionToName}'\" } ]" <<< ${offlineJSON})
                                offlineJSON=$( jq "del (.transactions[${transactionIdx}])" <<< ${offlineJSON})
                                echo "${offlineJSON}" > ${offlineFile}
                                showOfflineFileInfo;
                                echo
                        fi
			;;

        StakeKeyRegistration|StakeKeyDeRegistration )
                        #StakeKey Registration of De-Registration Transaction
                        transactionStakeName=$(jq -r ".transactions[${transactionIdx}].stakeAddr" <<< ${offlineJSON})

                        #Check that the UTXO on the paymentAddress (transactionFromAddr) has not changed
                        utxoLiveJSON=$(${cardanocli} ${subCommand} query utxo --address ${transactionFromAddr} --cardano-mode ${magicparam} ${nodeEraParam} --out-file /dev/stdout); checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi;
                        #Convert UTXO into mary style if UTXO is shelley/allegra style
                        if [[ ! "$(jq -r '[.[]][0].amount | type' <<< ${utxoLiveJSON})" == "array" ]]; then utxoLiveJSON=$(convert_UTXO "${utxoLiveJSON}"); fi
                        utxoLiveJSON=$(jq . <<< ${utxoLiveJSON})
                        utxoOfflineJSON=$(jq -r ".address.\"${transactionFromAddr}\".utxoJSON" <<< ${offlineJSON})
 		if [[ ! "${utxoLiveJSON}" == "${utxoOfflineJSON}" ]]; then echo -e "\e[35mERROR - The UTXO status between the offline capture and now has changed for the payment address '${transactionFromName}' !\e[0m\n"; exit 1; fi


                        echo -e "\e[90m\t[${transactionCue}]\t\e[0m${transactionType}[${transactionEra}] for '${transactionStakeName}', payment via '${transactionFromName}' \e[90m(${transactionDate})"
                        echo -e "\t   \t\e[90mpayment via ${transactionFromAddr}\e[0m"
                        echo
                        txID=$(${cardanocli} ${subCommand} transaction txid --tx-file <(echo ${transactionTxJSON}) )
                        echo -e "\e[0mTxID will be: \e[32m${txID}\e[0m\n"

                        if ask "\e[33mDoes this look good for you, continue ?" N; then
                                ${cardanocli} ${subCommand} transaction submit --tx-file <(echo ${transactionTxJSON}) --cardano-mode ${magicparam}
                                checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
                                echo -e "\n\e[0mStatus: \e[36mDONE - Transaction submitted\n"
                                if [[ ${magicparam} == "--mainnet" ]]; then echo -e "\e[0mTracking: \e[32mhttps://cardanoscan.io/transaction/${txID}\n"; fi
                                echo
                                #Write the new offileFile content
				offlineJSON=$( jq ".address.\"${transactionFromAddr}\" += {used: \"yes\" }" <<< ${offlineJSON})
                                offlineJSON=$( jq ".history += [ { date: \"$(date -R)\", action: \"tx submit ${txID} - ${transactionType} for '${transactionStakeName}', payment via '${transactionFromName}'\" } ]" <<< ${offlineJSON})
                                offlineJSON=$( jq "del (.transactions[${transactionIdx}])" <<< ${offlineJSON})
                                echo "${offlineJSON}" > ${offlineFile}
                                showOfflineFileInfo;
                                echo
                        fi
                        ;;


        DelegationCertRegistration )
                        #StakeKey Registration of De-Registration Transaction
                        transactionDelegName=$(jq -r ".transactions[${transactionIdx}].delegName" <<< ${offlineJSON})

                        #Check that the UTXO on the paymentAddress (transactionFromAddr) has not changed
                        utxoLiveJSON=$(${cardanocli} ${subCommand} query utxo --address ${transactionFromAddr} --cardano-mode ${magicparam} ${nodeEraParam} --out-file /dev/stdout); checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi;
                        #Convert UTXO into mary style if UTXO is shelley/allegra style
                        if [[ ! "$(jq -r '[.[]][0].amount | type' <<< ${utxoLiveJSON})" == "array" ]]; then utxoLiveJSON=$(convert_UTXO "${utxoLiveJSON}"); fi
                        utxoLiveJSON=$(jq . <<< ${utxoLiveJSON})
                        utxoOfflineJSON=$(jq -r ".address.\"${transactionFromAddr}\".utxoJSON" <<< ${offlineJSON})
	             	if [[ ! "${utxoLiveJSON}" == "${utxoOfflineJSON}" ]]; then echo -e "\e[35mERROR - The UTXO status between the offline capture and now has changed for the payment address '${transactionFromName}' !\e[0m\n"; exit 1; fi


                        echo -e "\e[90m\t[${transactionCue}]\t\e[0m${transactionType}[${transactionEra}] for '${transactionDelegName}', payment via '${transactionFromName}' \e[90m(${transactionDate})"
                        echo -e "\t   \t\e[90mpayment via ${transactionFromAddr}\e[0m"
                        echo
                        txID=$(${cardanocli} ${subCommand} transaction txid --tx-file <(echo ${transactionTxJSON}) )
                        echo -e "\e[0mTxID will be: \e[32m${txID}\e[0m\n"

                        if ask "\e[33mDoes this look good for you, continue ?" N; then
                                ${cardanocli} ${subCommand} transaction submit --tx-file <(echo ${transactionTxJSON}) --cardano-mode ${magicparam}
                                checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
                                echo -e "\n\e[0mStatus: \e[36mDONE - Transaction submitted\n"
                                if [[ ${magicparam} == "--mainnet" ]]; then echo -e "\e[0mTracking: \e[32mhttps://cardanoscan.io/transaction/${txID}\n"; fi
                                echo
                                #Write the new offileFile content
				offlineJSON=$( jq ".address.\"${transactionFromAddr}\" += {used: \"yes\" }" <<< ${offlineJSON})
                                offlineJSON=$( jq ".history += [ { date: \"$(date -R)\", action: \"tx submit ${txID} - ${transactionType} for '${transactionStakeName}', payment via '${transactionFromName}'\" } ]" <<< ${offlineJSON})
                                offlineJSON=$( jq "del (.transactions[${transactionIdx}])" <<< ${offlineJSON})
                                echo "${offlineJSON}" > ${offlineFile}
                                showOfflineFileInfo;
                                echo
                        fi
                        ;;


        PoolRegistration|PoolReRegistration )
                        #Pool Registration, Re-Registration
                        poolMetaTicker=$(jq -r ".transactions[${transactionIdx}].poolMetaTicker" <<< ${offlineJSON})
                        poolMetaUrl=$(jq -r ".transactions[${transactionIdx}].poolMetaUrl" <<< ${offlineJSON})
                        poolMetaHash=$(jq -r ".transactions[${transactionIdx}].poolMetaHash" <<< ${offlineJSON})
                        regProtectionKey=$(jq -r ".transactions[${transactionIdx}].regProtectionKey" <<< ${offlineJSON})

                        #Check that the UTXO on the paymentAddress (transactionFromAddr) has not changed
                        utxoLiveJSON=$(${cardanocli} ${subCommand} query utxo --address ${transactionFromAddr} --cardano-mode ${magicparam} ${nodeEraParam} --out-file /dev/stdout); checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi;
                        #Convert UTXO into mary style if UTXO is shelley/allegra style
                        if [[ ! "$(jq -r '[.[]][0].amount | type' <<< ${utxoLiveJSON})" == "array" ]]; then utxoLiveJSON=$(convert_UTXO "${utxoLiveJSON}"); fi
                        utxoLiveJSON=$(jq . <<< ${utxoLiveJSON})
                        utxoOfflineJSON=$(jq -r ".address.\"${transactionFromAddr}\".utxoJSON" <<< ${offlineJSON})
         	if [[ ! "${utxoLiveJSON}" == "${utxoOfflineJSON}" ]]; then echo -e "\e[35mERROR - The UTXO status between the offline capture and now has changed for the payment address '${transactionFromName}' !\e[0m\n"; exit 1; fi

                        echo -e "\e[90m\t[${transactionCue}]\t\e[0m${transactionType}[${transactionEra}] for Pool '${poolMetaTicker}', payment via '${transactionFromName}' \e[90m(${transactionDate})"
                        echo -e "\t   \t\e[90mpayment via ${transactionFromAddr}\e[0m"
                        echo

		        #Check if the regProtectionKey is correct, this is a service to not have any duplicated Tickers on the Chain. If you know how to code you can see that it is easy, just a little protection for Noobs
		        echo -ne "\e[0m\x54\x69\x63\x6B\x65\x72\x20\x50\x72\x6F\x74\x65\x63\x74\x69\x6F\x6E\x20\x43\x68\x65\x63\x6B\x20\x66\x6F\x72\x20\x54\x69\x63\x6B\x65\x72\x20'\e[32m${poolMetaTicker}\e[0m': "
		        checkResult=$(curl -m 5 -s $(echo -e "\x68\x74\x74\x70\x73\x3A\x2F\x2F\x6D\x79\x2D\x69\x70\x2E\x61\x74\x2F\x63\x68\x65\x63\x6B\x74\x69\x63\x6B\x65\x72\x3F\x74\x69\x63\x6B\x65\x72\x3D${poolMetaTicker}&key=${regProtectionKey}") );
		        if [[ $? -ne 0 ]]; then echo -e "\e[33m\x50\x72\x6F\x74\x65\x63\x74\x69\x6F\x6E\x20\x53\x65\x72\x76\x69\x63\x65\x20\x6F\x66\x66\x6C\x69\x6E\x65\e[0m";
		                           else
		                                if [[ ! "${checkResult}" == "OK" ]]; then
		                                                                echo -e "\e[35mFailed\e[0m";
		                                                                echo -e "\n\e[35mERROR - This Stakepool-Ticker '${poolMetaTicker}' is protected, your need the right registration-protection-key to interact with this Ticker!\n";
		                                                                echo -e "If you wanna protect your Ticker too, please reach out to @atada_stakepool on Telegram to get your unique ProtectionKey, Thx !\e[0m\n\n"; exit 1;
		                                                         else
		                                                                echo -e "\e[32mOK\e[0m";
		                                fi
		        fi
		        echo

		        #Metadata-JSON HASH PreCheck: Check and compare the online metadata.json file hash with
		        #the one in the currently pool.json file. If they match up, continue. Otherwise exit with an ERROR
		        #Fetch online metadata.json file from the pool webserver
		        echo -ne "\e[0mMetadata HASH Check, fetching the MetaData JSON file from \e[32m${poolMetaUrl}\e[0m: "
		        tmpMetadataJSON=$(curl -sL "${poolMetaUrl}" 2> /dev/null)
		        if [[ $? -ne 0 ]]; then echo -e "\e[35mERROR, can't fetch the metadata file from the webserver!\e[0m\n"; exit 1; fi
		        #Check the downloaded data that is a valid JSON file
		        tmpCheckJSON=$(echo "${tmpMetadataJSON}" | jq . 2> /dev/null)
		        if [[ $? -ne 0 ]]; then echo -e "\e[35mERROR - Not a valid JSON file on the webserver!\e[0m\n"; exit 1; fi
		        #Ok, downloaded file is a valid JSON file. So now look into the HASH
		        onlineMetaHash=$(${cardanocli} ${subCommand} stake-pool metadata-hash --pool-metadata-file <(echo "${tmpMetadataJSON}") )
		        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
		        #Compare the HASH now, if they don't match up, output an ERROR message and exit
		        if [[ ! "${poolMetaHash}" == "${onlineMetaHash}" ]]; then
		                echo -e "\e[35mERROR - HASH mismatch!\n\nPlease make sure to upload your MetaData JSON file correctly to your webserver!\nPool-Registration aborted! :-(\e[0m\n";
		                echo -e "\nYour remote file at \e[32m${poolMetaUrl}\e[0m with HASH \e[32m${onlineMetaHash}\e[0m:\n"
		                echo -e "--- BEGIN ---\e[33m"
		                echo "${tmpMetadataJSON}"
		                echo -e "\e[0m---  END  ---"
		                echo -e "\e[0m\n"
		                exit 1;
		        else echo -e "\e[32mOK\e[0m\n"; fi
		        #Ok, HASH is the same, continue

                        txID=$(${cardanocli} ${subCommand} transaction txid --tx-file <(echo ${transactionTxJSON}) )
                        echo -e "\e[0mTxID will be: \e[32m${txID}\e[0m\n"

                        if ask "\e[33mDoes this look good for you, continue ?" N; then
                                ${cardanocli} ${subCommand} transaction submit --tx-file <(echo ${transactionTxJSON}) --cardano-mode ${magicparam}
                                checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
                                echo -e "\n\e[0mStatus: \e[36mDONE - Transaction submitted\n"
                                if [[ ${magicparam} == "--mainnet" ]]; then echo -e "\e[0mTracking: \e[32mhttps://cardanoscan.io/transaction/${txID}\n"; fi
                                echo
                                #Write the new offileFile content
                                offlineJSON=$( jq ".address.\"${transactionFromAddr}\" += {used: \"yes\" }" <<< ${offlineJSON})
                                offlineJSON=$( jq ".history += [ { date: \"$(date -R)\", action: \"tx submit ${txID} - ${transactionType} for Pool '${poolMetaTicker}', payment via '${transactionFromName}'\" } ]" <<< ${offlineJSON})
                                offlineJSON=$( jq "del (.transactions[${transactionIdx}])" <<< ${offlineJSON})
                                echo "${offlineJSON}" > ${offlineFile}
                                showOfflineFileInfo;
                                echo
                        fi
                        ;;


        PoolRetirement )
                        #Pool Retirement
                        poolMetaTicker=$(jq -r ".transactions[${transactionIdx}].poolMetaTicker" <<< ${offlineJSON})

                        #Check that the UTXO on the paymentAddress (transactionFromAddr) has not changed
                        utxoLiveJSON=$(${cardanocli} ${subCommand} query utxo --address ${transactionFromAddr} --cardano-mode ${magicparam} ${nodeEraParam} --out-file /dev/stdout); checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi;
                        #Convert UTXO into mary style if UTXO is shelley/allegra style
                        if [[ ! "$(jq -r '[.[]][0].amount | type' <<< ${utxoLiveJSON})" == "array" ]]; then utxoLiveJSON=$(convert_UTXO "${utxoLiveJSON}"); fi
                        utxoLiveJSON=$(jq . <<< ${utxoLiveJSON})
                        utxoOfflineJSON=$(jq -r ".address.\"${transactionFromAddr}\".utxoJSON" <<< ${offlineJSON})
	                if [[ ! "${utxoLiveJSON}" == "${utxoOfflineJSON}" ]]; then echo -e "\e[35mERROR - The UTXO status between the offline capture and now has changed for the payment address '${transactionFromName}' !\e[0m\n"; exit 1; fi

                        echo -e "\e[90m\t[${transactionCue}]\t\e[0m${transactionType}[${transactionEra}] for Pool '${poolMetaTicker}', payment via '${transactionFromName}' \e[90m(${transactionDate})"
                        echo -e "\t   \t\e[90mpayment via ${transactionFromAddr}\e[0m"
                        echo
                        txID=$(${cardanocli} ${subCommand} transaction txid --tx-file <(echo ${transactionTxJSON}) )
                        echo -e "\e[0mTxID will be: \e[32m${txID}\e[0m\n"

                        if ask "\e[33mDoes this look good for you, continue ?" N; then
                                ${cardanocli} ${subCommand} transaction submit --tx-file <(echo ${transactionTxJSON}) --cardano-mode ${magicparam}
                                checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
                                echo -e "\n\e[0mStatus: \e[36mDONE - Transaction submitted\n"
                                if [[ ${magicparam} == "--mainnet" ]]; then echo -e "\e[0mTracking: \e[32mhttps://cardanoscan.io/transaction/${txID}\n"; fi
                                echo
                                #Write the new offileFile content
                                offlineJSON=$( jq ".address.\"${transactionFromAddr}\" += {used: \"yes\" }" <<< ${offlineJSON})
                                offlineJSON=$( jq ".history += [ { date: \"$(date -R)\", action: \"tx submit ${txID} - ${transactionType} for Pool '${poolMetaTicker}', payment via '${transactionFromName}'\" } ]" <<< ${offlineJSON})
                                offlineJSON=$( jq "del (.transactions[${transactionIdx}])" <<< ${offlineJSON})
                                echo "${offlineJSON}" > ${offlineFile}
                                showOfflineFileInfo;
                                echo
                                echo -e "\e[33mDon't de-register/delete your rewards staking account/address yet! You will receive the pool deposit fees on it!\n"
                                echo -e "\e[0m\n"
                        fi
                        ;;


        * )             #Unknown Transaction Type !?
                        echo -e "\n\e[90m\t[${transactionCue}]\t\e[35mUnknown transaction type\e[0m"
                        ;;
esac

#Check the number of pending transactions
transactionsCnt=$(jq -r ".transactions | length" <<< ${offlineJSON})
if [[ ${transactionsCnt} -gt 0 ]]; then echo -e "\e[33mThere are ${transactionsCnt} more pending transactions in the '$(basename ${offlineFile})'.\nYou can submit them by re-running the same command again.\e[0m\n"; exit; fi

echo
fi # END
#
###########################################
###
### action = execute
###
###########################################


###########################################
###
### action = extract
###
###########################################
#
# START

if [[ "${action}" == "extract" ]]; then

#Show Information first
showOfflineFileInfo;

#Check the number of files attached
filesCnt=$(jq -r ".files | length" <<< ${offlineJSON})
if [[ ${filesCnt} -eq 0 ]]; then echo -e "\e[33mNo attached files found in the '$(basename ${offlineFile})'.\e[0m\n"; exit; fi

echo "------------------"
echo
echo -e "\e[36mExtracting ${filesCnt} files from the '$(basename ${offlineFile})': \e[0m"
echo

offlineJSONtemp=${offlineJSON}	#make a temporary local copy of all the files entries, because we delete it directly in the main one

for (( tmpCnt=0; tmpCnt<${filesCnt}; tmpCnt++ ))
do

  filePath=$(jq -r ".files | keys[${tmpCnt}]" <<< ${offlineJSONtemp})
  fileDate=$(jq -r ".files.\"${filePath}\".date" <<< ${offlineJSONtemp})
  fileSize=$(jq -r ".files.\"${filePath}\".size" <<< ${offlineJSONtemp})
  echo -ne "\e[90m\t[$((${tmpCnt}+1))]\t\e[0m${filePath} \e[90m(${fileSize}, ${fileDate})\e[0m -> "

  fileBase64=$(jq -r ".files.\"${filePath}\".base64" <<< ${offlineJSONtemp})

  #Decode base64 and write the it to the filePath
  if [ -f "${filePath}" ]; then
	                        echo -e "\e[33mSkipped (File exists, delete it first if you wanna overwite it)\e[0m\n";
			   else
				mkdir -p $(dirname ${filePath}) #generate the output path if not already present
				base64 --decode <(echo "${fileBase64}") 2> /dev/null > ${filePath} #write the file into the path
				if [[ $? -eq 0 ]]; then
					echo -e "\e[32mExtracted\e[0m\n";
		                        #Write the new offileFile content
		                        offlineJSON=$( jq ".history += [ { date: \"$(date -R)\", action: \"extracted file '${filePath}'\" } ]" <<< ${offlineJSON})
		                        offlineJSON=$( jq "del (.files.\"${filePath}\")" <<< ${offlineJSON})
		                        echo "${offlineJSON}" > ${offlineFile}
			  			   else
				 	echo -e "\e[35mFailed (maybe some rights issues?)\e[0m\n";
				fi
  fi

done

#Check if there are any files attached
filesCnt=$(jq -r ".files | length" <<< ${offlineJSON});
if [[ ${filesCnt} -gt 0 ]]; then echo -e "\e[33mThere are still ${filesCnt} files attached in the '$(basename ${offlineFile})'.\nYou can extract them by running the command: $(basename $0) extract\e[0m\n"; exit; fi

echo
fi # END
#
###########################################
###
### action = execute
###
###########################################
