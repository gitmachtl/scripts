#!/bin/bash

# Script is brought to you by ATADA_Stakepool, Telegram @atada_stakepool

#load variables from common.sh
. "$(dirname "$0")"/00_common.sh

#Display usage instructions
showUsage() {
cat >&2 <<EOF
Usage: $(basename $0) new <voteKeyName>                       ... Generates a new VotingKeyPair with the given name
       $(basename $0) new myvote                              ... Generates a new VotingKeyPair myvote.voting.skey/pkey

       $(basename $0) qrcode <voteKeyName> <4-Digit-PinCode>  ... Shows the QR code for the Catalyst-App with the given 4-digit PinCode
       $(basename $0) qrcode myvote 1234                      ... Shows the QR code for the VotingKey 'myvote' and protects it with the PinCode '1234'

       $(basename $0) genmeta <voteKeyName> <stakeName-to-register> [Optional: <rewardsPayoutStakeAddr>]
	  ... Generates the Catalyst-Registration-Metadata(cbor) for the given name, stakeAccountName and optional different rewardsPayoutStakeAddr

       $(basename $0) genmeta myvote owner
	  ... Generates the Catalyst-Registration-Metadata(cbor) for the myvote VotingKey, amountToRegister via owner.staking,
	      RewardsPayout to the Address owner.staking.addr. With HW-Wallets, the RewardsPayout-Addr must be one of the HW-Wallet itself!

       $(basename $0) genmeta myvote owner myrewards
	  ... Generates the Catalyst-Registration-Metadata(cbor) for the myvote VotingKey, amountToRegister via owner.staking,
	      RewardsPayout to the Address myrewards.payment.addr. With HW-Wallets, the RewardsPayout-Addr must be one of the HW-Wallet itself!

EOF
}

#JCLI check
if ! exists "${jcli_bin}"; then
                                #Try the one in the scripts folder
                                if [[ -f "${scriptDir}/jcli" ]]; then jcli_bin="${scriptDir}/jcli";
                                else majorError "Path ERROR - Path to the 'jcli' binary is not correct or 'jcli' binaryfile is missing!\nYou can find it here: https://github.com/input-output-hk/jormungandr/releases \nThis is needed to generate the Voting Keys. Please check your 00_common.sh or common.inc settings."; exit 1; fi
fi
jcliCheck=$(${jcli_bin} --version 2> /dev/null)
if [[ $? -ne 0 ]]; then echo -e "\e[35mERROR - This script needs a working 'jcli' binary. Please make sure you have it present with with the right path in '00_common.sh' !\e[0m\n\n"; exit 1; fi
jcliVersion=$(echo ${jcliCheck} | cut -d' ' -f 2)

#VIT-KEDQR check
if ! exists "${vitkedqr_bin}"; then
                                #Try the one in the scripts folder
                                if [[ -f "${scriptDir}/vit-kedqr" ]]; then vitkedqr_bin="${scriptDir}/vit-kedqr";
                                else majorError "Path ERROR - Path to the 'vit-kedqr' binary is not correct or 'vit-kedqr' binaryfile is missing!\nYou can find it here: https://github.com/input-output-hk/vit-kedqr/releases/latest \nThis is needed to generate the QR code for the Catalyst-App. Please check your 00_common.sh or common.inc settings."; exit 1; fi
fi
vitkedqrCheck=$(${vitkedqr_bin} --version 2> /dev/null)
if [[ $? -ne 0 ]]; then echo -e "\e[35mERROR - This script needs a working 'vit-kedqr' binary. Please make sure you have it present with with the right path in '00_common.sh' !\e[0m\n\n"; exit 1; fi
vitkedqrVersion=$(echo ${vitkedqrCheck} | cut -d' ' -f 2)


################################################
# MAIN START
#
# Check commandline parameters
#
if [[ $# -eq 0 ]]; then $(showUsage); exit 1; fi
case ${1} in

  qrcode )
		action="${1}";
                if [[ $# -eq 3 ]]; then voteKeyName="${2}"; voteKeyName=${voteKeyName/#.\//}; pinCode="${3}"; else echo -e "\e[35mMissing parameters!\e[0m\n"; showUsage; exit 1; fi
		if [ ! -f "${voteKeyName}.voting.skey" ]; then echo -e "\e[35mError - ${voteKeyName}.voting.skey is missing, please generate it first with the subcommand 'new' !\e[0m\n"; showUsage; exit 1; fi
		if [ -z "${pinCode##*[!0-9]*}" ] || [ ${#pinCode} -lt 4 ] || [ ${pinCode} -lt 0 ] || [ ${pinCode} -gt 9999 ]; then echo -e "\e[35mError - The PinCode must be a 4-Digit-Number between 0000 and 9999 !\e[0m\n"; exit 1; fi
		if [ -f "${voteKeyName}.catalyst-qrcode.png" ]; then echo -e "\e[35mError - ${voteKeyName}.catalyst-qrcode.png already exists, please delete it first if you wanna overwrite it !\e[0m\n"; exit 1; fi
                echo -e "\e[0mVIT-KEDQR-Version: \e[32m${vitkedqrVersion}\e[0m"
                echo
                echo -e "\e[0mGenerating the Catalyst-APP QR Code for the Voting-Signing-Key: \e[32m${voteKeyName}.voting.skey\e[0m"
                echo
                echo -e "\e[0mYour Pin-Code for the Catalyst-APP: \e[32m${pinCode}\e[0m"
		echo

		tmp=$(${vitkedqr_bin} --pin ${pinCode} --input ${voteKeyName}.voting.skey --output ${voteKeyName}.catalyst-qrcode.png)
		checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
		file_lock ${voteKeyName}.voting.skey
		echo -e "\e[0mCatalyst-QR-Code: \e[32m ${voteKeyName}.catalyst-qrcode.png \e[0m"
		${vitkedqr_bin} --pin ${pinCode} --input ${voteKeyName}.voting.skey
		echo

		exit 0;
		;;

  new )
                action="${1}";
                if [[ $# -eq 2 ]]; then voteKeyName="${2}"; voteKeyName=${voteKeyName/#.\//}; else echo -e "\e[35mMissing parameters!\e[0m\n"; showUsage; exit 1; fi
		if [ -f "${voteKeyName}.voting.skey" ]; then echo -e "\e[35mError - ${voteKeyName}.voting.skey already exists, please delete it first if you wanna overwrite it !\e[0m\n"; exit 1; fi
		if [ -f "${voteKeyName}.voting.pkey" ]; then echo -e "\e[35mError - ${voteKeyName}.voting.pkey already exists, please delete it first if you wanna overwrite it !\e[0m\n"; exit 1; fi
                echo -e "\e[0mJCLI-Version: \e[32m${jcliVersion}\e[0m"
		echo
                echo -e "\e[0mGenerating a new Voting-KeyPair with the name: \e[32m${voteKeyName}\e[0m"
                echo

		tmp=$(${jcli_bin} key generate --type ed25519extended 2> /dev/null > ${voteKeyName}.voting.skey)
		checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
		file_lock ${voteKeyName}.voting.skey
		echo -e "\e[0mVoting-Signing-Key: \e[32m ${voteKeyName}.voting.skey \e[90m"
		cat ${voteKeyName}.voting.skey
		echo

                tmp=$(${jcli_bin} key to-public 2> /dev/null < ${voteKeyName}.voting.skey > ${voteKeyName}.voting.pkey)
                checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
                file_lock ${voteKeyName}.voting.pkey
                echo -e "\e[0mVoting-Public-Key: \e[32m ${voteKeyName}.voting.pkey \e[90m"
                cat ${voteKeyName}.voting.pkey
                echo
		exit 0;
                ;;

  genmeta )
                action="${1}";
		#Read the parameters
                if [[ $# -eq 3 ]]; then  #rewardsAccount is the same as the voting account
				voteKeyName="${2}"; voteKeyName=${voteKeyName/#.\//};
				stakeAddr="$(dirname $3)/$(basename $(basename $3 .addr) .staking).staking"; stakeAddr=${stakeAddr/#.\//};
				rewardsAddr=${stakeAddr}
                elif [[ $# -eq 4 ]]; then #rewardsAccount is a separate one account
				voteKeyName="${2}"; voteKeyName=${voteKeyName/#.\//};
				stakeAddr="$(dirname $3)/$(basename $(basename $3 .addr) .staking).staking"; stakeAddr=${stakeAddr/#.\//};
				rewardsAddr="$(dirname $4)/$(basename $(basename $4 .addr) .staking).staking"; rewardsAddr=${rewardsAddr/#.\//};
		else echo -e "\e[35mMissing parameters!\e[0m\n"; showUsage; exit 1; fi

                if [ ! -f "${voteKeyName}.voting.pkey" ]; then echo -e "\e[35mError - ${voteKeyName}.voting.pkey is missing, please generate it first with the subcommand 'new' !\e[0m\n"; showUsage; exit 1; fi
                if [ ! -f "${voteKeyName}.voting.skey" ]; then echo -e "\e[35mError - ${voteKeyName}.voting.skey is missing, please generate it first with the subcommand 'new' !\e[0m\n"; showUsage; exit 1; fi
		if ! [[ -f "${stakeAddr}.skey" || -f "${stakeAddr}.hwsfile" ]]; then echo -e "\n\e[35mERROR - \"${stakeAddr}.skey(hwsfile)\" Staking Signing Key or HardwareFile does not exist! Please create it first with script 03a.\e[0m"; exit 1; fi
		if ! [[ -f "${rewardsAddr}.skey" || -f "${rewardsAddr}.hwsfile" ]]; then echo -e "\n\e[35mERROR - \"${rewardsAddr}.skey(hwsfile)\" does not exist! Please create it first with script 03a or 02.\e[0m"; exit 1; fi
		if [ ! -f "${rewardsAddr}.addr" ]; then echo -e "\n\e[35mERROR - \"${rewardsAddr}.addr\" does not exist! Please create it first with script 03a.\e[0m"; exit 1; fi

		rewardsPayoutAddr=$(cat "${rewardsAddr}.addr" 2> /dev/null); checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

		#Check that the rewardsPayoutAddr is a valid StakeAddress
		typeOfAddr=$(get_addressType "${rewardsPayoutAddr}"); checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi;
		if [[ ! ${typeOfAddr} == ${addrTypeStake} ]]; then echo -e "\n\e[35mERROR - \"${rewardsAddr}.addr\" - ${rewardsPayoutAddr} is not a valid Stake-Address!\e[0m"; exit 1; fi

		stakingName=$(basename ${stakeAddr} .staking) #contains the name before the .staking.addr extension

		#Output filename for the Voting-Registration-CBOR-Metadata
		votingMetaFile="${voteKeyName}_${stakingName}.vote-metadata.cbor"
		if [ -f "${votingMetaFile}" ]; then echo -e "\e[35mError - ${votingMetaFile} already exists, please delete it first if you wanna overwrite it !\e[0m\n"; exit 1; fi

		currentTip=$(get_currentTip) #we use the current slotHeight as the nonce parameter

		#If the StakeAccount is a HW-Wallet, do it all via cardano-hw-cli
		if [ -f "${stakeAddr}.hwsfile" ]; then

			rewardsHwStakingFile="${rewardsAddr}.hwsfile"
			#Check that the rewardsPayout is done to a HW-Wallet key and not a CLI one
			if [ ! -f "${rewardsHwStakingFile}" ]; then echo -e "\n\e[35mERROR - Registering a HW-StakingKey must also have a RewardsStakeAccount on the same HW-Wallet, not a CLI-Stake-Address for the rewards.\e[0m"; exit 1; fi
#			auxiliaryParameter="--auxiliary-signing-key ${rewardsHwStakingFile}" #hw-cli v1.3.0

	                echo -e "\e[0mGenerating the Catalyst-Registration-MetadataFile(cbor): \e[32m${votingMetaFile}\e[0m"
	                echo
	                echo -e "\e[0mMetadata will be generated for the Voting-Key with the name: \e[32m${voteKeyName}\e[90m.voting.pkey\e[0m"
	                echo -e "\e[0mand the Public-Key: \e[32m$(cat ${voteKeyName}.voting.pkey)\e[0m"
			echo
	                echo -e "\e[0mHW-Wallet-StakeKey (Voting-Power) that will be used: \e[32m${stakeAddr}\e[90m.hwsfile\e[0m"
			echo

			#If in online mode, do a check it the Rewards-Address is registered on the chain
			if ${onlineMode}; then
			        echo -ne "\e[0mChecking current Chain-Status of the Rewards-Account: "

				rewardsAmount=$(${cardanocli} query stake-address-info --address ${rewardsPayoutAddr} ${magicparam} | jq -r "flatten | .[0].rewardAccountBalance")
				checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
			        if [[ ${rewardsAmount} == null ]]; then echo -e "\e[33mNOT REGISTERED\n\n\e[35mERROR - Staking Address is NOT registered on the chain, please register it first to use it as Rewards-Account for the Voting-Rewards !\e[0m\n"; exit 1;
								   else echo -e "\e[32mok\e[0m\n";
				fi
			fi

	                echo -e "\e[0mRewards will be paid out to Stake-Account: \e[32m${rewardsAddr}\e[90m.addr\e[0m"
	                echo -e "\e[0mwhich is address: \e[32m${rewardsPayoutAddr}\e[0m"
			echo
			echo -e "\e[0mNonce (current slotHeight): \e[32m${currentTip}\e[0m"
			echo

			start_HwWallet; checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
			tmp=$(${cardanohwcli} catalyst voting-key-registration-metadata ${magicparam} --vote-public-key ${voteKeyName}.voting.pkey --reward-address ${rewardsPayoutAddr} --stake-signing-key ${stakeAddr}.hwsfile --reward-address-signing-key ${rewardsHwStakingFile} --nonce ${currentTip} --metadata-cbor-out-file ${votingMetaFile} 2> /dev/stdout)
			if [[ "${tmp^^}" =~ (ERROR|DISCONNECT) ]]; then echo -e "\e[35m${tmp}\e[0m\n"; exit 1; else echo -e "\e[32mDONE\e[0m\n"; fi
			checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

			echo
	                if [ -f "${votingMetaFile}" ]; then echo -e "\e[0mThe Metadata-Registration-CBOR File \"\e[32m${votingMetaFile}\e[0m\" was generated. :-)\n\nYou can now submit it on the chain by including it in a transaction with Script: 01_sendLovelaces.sh\nExample:\e[33m 01_sendLovelaces.sh mywallet mywallet 1000000 ${votingMetaFile}\n\n\e[0m"
						       else echo -e "\e[35mError - Something went wrong while writing the \"${votingMetaFile}\" metadata file !\e[0m\n"; exit 1; fi


		else #Voting via voter-registration tool
			echo "Currently this script only supports the voting-meta-cbor generation for HW-Wallets"
		fi

                exit 0;
                ;;


  * ) 		showUsage; exit 1;
		;;
esac

