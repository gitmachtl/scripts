##!/bin/bash
unset magicparam network addrformat

##############################################################################################################################
#    _____ ____  ____     _____           _       __
#   / ___// __ \/ __ \   / ___/__________(_)___  / /______
#   \__ \/ /_/ / / / /   \__ \/ ___/ ___/ / __ \/ __/ ___/
#  ___/ / ____/ /_/ /   ___/ / /__/ /  / / /_/ / /_(__  )
# /____/_/    \____/   /____/\___/_/  /_/ .___/\__/____/
#                                    /_/
# MAIN CONFIG FILE:
#
# Please set the following variables to your needs, you can overwrite them dynamically
# by placing a file with name "common.inc" in the calling directory or in "$HOME/.common.inc".
# It will be sourced into this file automatically if present and can overwrite the values below dynamically :-)
#
##############################################################################################################################


#--------- Workmode: online, light, offline ---  please read the instructions on the github repo README :-)
workMode="online"	#change this to "online" if your machine is online and you run a local node with, this is also know as full-mode
			#change this to "light" if your machine is online but you don't run a local node (all requests are done via online APIs like koios, adahandle, etc.)
			#change this to "offline" if you run these scripts on a cold machine, needs a counterpart with is set to "online" or "light" on a hot machine


#--------- Set the Path to your main binaries here ---------
cardanocli="./cardano-cli"		#Path to your cardano-cli binary you wanna use. If your binary is present in the Path just set it to "cardano-cli" without the "./" infront
cardanosigner="./cardano-signer"	#Path to your cardano-signer binary you wanna use. If your binary is present in the Path just set it to "cardano-signer" without the "./" infront
bech32_bin="./bech32"			#Path to your bech32 binary you wanna use. If your binary is present in the Path just set it to "bech32" without the "./" infront



#------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#--------- Only needed if you run in online mode with a local node (aka FullMode)
cardanonode="./cardano-node"	#Path to your cardano-node binary you wanna use. If your binary is present in the Path just set it to "cardano-node" without the "./" infront
socket="db/node.socket" #Path to your cardano-node socket for machines in online-mode. Another example would be "$HOME/cnode/sockets/node.socket"


#--------- Only needed for offline mode and pool-operations ---------
genesisfile="$HOME/cardano/mainnet-shelley-genesis.json"           #Shelley-Genesis path, you can also use the placeholder $HOME to specify your home directory
genesisfile_byron="$HOME/cardano/mainnet-byron-genesis.json"       #Byron-Genesis path, you can also use the placeholder $HOME to specify your home directory


#--------- Only needed if you wanna use a hardware key (Ledger/Trezor) too, please read the instructions on the github repo README :-)
cardanohwcli="cardano-hw-cli"      #Path to your cardano-hw-cli binary you wanna use. If your binary is present in the Path just set it to "cardano-hw-cli" without the "./" infront


#--------- Only needed if you wanna do online/offline hot/cold machine transfers
offlineFile="./offlineTransfer.json" 	#path to the filename (JSON) that will be used to transfer the data between a hot and a cold machine


#--------- Only needed if you wanna do catalyst voting
catalyst_toolbox_bin="./catalyst-toolbox"	#Path to your catalyst-toolbox binary you wanna use. If your binary is present in the Path just set it to "catalyst-toolbox" without the "./" infront


#--------- Only needed if you wanna generate the right format for the NativeAsset Metadata Registry
cardanometa="./token-metadata-creator" #Path to your token-metadata-creator binary you wanna use. If present in the Path just set it to "token-metadata-creator" without the "./" infront


#--------- Only needed if you have a koios-API-Token for using the koios rest-API. Otherwise leave it blank so it will use the Public-Tier automatically
koiosApiToken=""


#--------- Only needed if you wanna change the BlockChain from the Mainnet to a Testnet Chain Setup, uncomment the network you wanna use by removing the leading #
#          Using a preconfigured network name automatically loads and sets the magicparam, addrformat and byronToShelleyEpochs parameters, also API-URLs, etc.

#network="Mainnet" 	#Mainnet (Default)
#network="PreProd" 	#PreProd Testnet (new default Testnet)
#network="Preview"	#Preview Testnet (new fast Testnet)
#network="Sancho"	#SanchoNet Testnet (new governance Testnet)
#network="Legacy"	#Legacy TestChain (formally known as Public-Testnet)
#network="GuildNet"	#GuildNet Testnet

#--------- You can of course specify your own values by setting a new network=, magicparam=, addrformat= and byronToShelleyEpochs= parameter :-)
#network="new-devchain"; magicparam="--testnet-magic 11111"; addrformat="--testnet-magic 11111"; byronToShelleyEpochs=6 #Custom Chain settings



#--------- some other stuff -----
showVersionInfo="yes"		#yes/no to show the version info and script mode on every script call
queryTokenRegistry="yes"	#yes/no to query each native asset/token on the token registry server live
cropTxOutput="yes"		#yes/no to crop the unsigned/signed txfile outputs on transactions to a max. of 4000chars











































##############################################################################################################################
#
# 'DONT EDIT BELOW THIS LINE !!!'
#
##############################################################################################################################


#-------------------------------------------------------
#DisplayMajorErrorMessage
majorError() {
echo -e "\e[97m\n" > $(tty)
echo -e "         _ ._  _ , _ ._\n        (_ ' ( \`  )_  .__)\n      ( (  (    )   \`)  ) _)\n     (__ (_   (_ . _) _) ,__)\n         \`~~\`\\ ' . /\`~~\`\n              ;   ;\n              /   \\ \n_____________/_ __ \\___________________________________________\n" > $(tty)
echo -e "\e[35m${1}\n\nIf you think all is right at your side, please check the GitHub repo if there\nis a newer version/bugfix available, thx: https://github.com/gitmachtl/scripts\e[0m\n" > $(tty); exit 1;
}
#-------------------------------------------------------


#API Endpoints and Network-Settings for the various chains

network=${network:-mainnet} #sets the default network to mainnet, if not set otherwise
unset _magicparam _addrformat _byronToShelleyEpochs _tokenMetaServer _transactionExplorer _koiosAPI _adahandlePolicyID _adahandleAPI _lightModeParametersURL

#Load and overwrite variables via env files if present
scriptDir=$(dirname "$0" 2> /dev/null)
if [[ -f "${scriptDir}/common.inc" ]]; then source "${scriptDir}/common.inc"; fi
if [[ -f "$HOME/.common.inc" ]]; then source "$HOME/.common.inc"; fi
if [[ -f "common.inc" ]]; then source "common.inc"; fi

#Also check about a lowercase "workmode" entry
workMode=${workmode:-"${workMode}"}

#Also check about a lowercase "koiosapitoken" entry
koiosApiToken=${koiosapitoken:-"${koiosApiToken}"}

#Set the list of preconfigured networknames
networknames="mainnet, preprod, preview, sancho"

#Check if there are testnet parameters set but network is still "mainnet"
if [[ "${magicparam}${addrformat}" == *"testnet"* && "${network,,}" == "mainnet" ]]; then majorError "Mainnet selected, but magicparam(${magicparam})/addrformat(${addrformat}) have testnet settings!\n\nPlease select the right chain in the '00_common.sh', '${scriptDir}/common.inc', '$HOME/.common.inc' or './common.inc' file by setting the value for the parameter network to one of the preconfiged networknames:\n${networknames}\n\nThere is no need anymore, to set the parameters magicparam/addrformat/byronToShelleyEpochs for the preconfigured networks. Its enough to specify it for example with: network=\"preprod\"\nOf course you can still set them and also set a custom networkname like: network=\"vasil-dev\""; exit 1; fi

#Preload the variables, based on the "network" name
case "${network,,}" in

	"mainnet" )
		network="Mainnet"		#nicer name for info-display
		_magicparam="--mainnet"		#MagicParameter Extension --mainnet / --testnet-magic xxx
		_addrformat="--mainnet"		#Addressformat for the address generation, normally the same as magicparam
		_byronToShelleyEpochs=208	#The number of Byron Epochs before the Chain forks to Shelley-Era
		_tokenMetaServer="https://tokens.cardano.org/metadata/"		#Token Metadata API URLs -> autoresolve into ${tokenMetaServer}/
		_transactionExplorer="https://cardanoscan.io/transaction/" 	#URLS for the Transaction-Explorers -> autoresolve into ${transactionExplorer}/
		_koiosAPI="https://api.koios.rest/api/v1"			#Koios-API URLs -> autoresolve into ${koiosAPI}
		_adahandlePolicyID="f0ff48bbb7bbe9d59a40f1ce90e9e9d0ff5002ec48f232b49ca0fb9a"	#PolicyIDs for the adaHandles -> autoresolve into ${adahandlePolicyID}
		_adahandleAPI="https://api.handle.me"				#Adahandle-API URLs -> autoresolve into ${adahandleAPI}
		_catalystAPI="https://api.testnet.projectcatalyst.io/api/v1"	#Catalyst-API URLs -> autoresolve into ${catalystAPI}
		_lightModeParametersURL="https://uptime.live/data/cardano/parms/mainnet-parameters.json"	#Parameters-JSON-File with current informations about cardano-cli version, tip, era, protocol-parameters
		;;


	"preprod"|"pre-prod" )
		network="PreProd"
		_magicparam="--testnet-magic 1"
		_addrformat="--testnet-magic 1"
		_byronToShelleyEpochs=4
		_tokenMetaServer="https://metadata.cardano-testnet.iohkdev.io/metadata"
		_transactionExplorer="https://preprod.cardanoscan.io/transaction"
		_koiosAPI="https://preprod.koios.rest/api/v1"
		_adahandlePolicyID="f0ff48bbb7bbe9d59a40f1ce90e9e9d0ff5002ec48f232b49ca0fb9a"	#PolicyIDs for the adaHandles -> autoresolve into ${adahandlePolicyID}
		_adahandleAPI="https://preprod.api.handle.me"		#Adahandle-API URLs -> autoresolve into ${adahandleAPI}
		_catalystAPI="https://api.testnet.projectcatalyst.io/api/v1"	#Catalyst-API URLs -> autoresolve into ${catalystAPI}
		_lightModeParametersURL="https://uptime.live/data/cardano/parms/preprod-parameters.json"	#Parameters-JSON-File with current informations about cardano-cli version, tip, era, protocol-parameters
		;;


	"preview"|"pre-view" )
		network="Preview"
		_magicparam="--testnet-magic 2"
		_addrformat="--testnet-magic 2"
		_byronToShelleyEpochs=0
		_tokenMetaServer="https://metadata.cardano-testnet.iohkdev.io/metadata"
		_transactionExplorer="https://preview.cardanoscan.io/transaction"
		_koiosAPI="https://preview.koios.rest/api/v1"
		_adahandlePolicyID="f0ff48bbb7bbe9d59a40f1ce90e9e9d0ff5002ec48f232b49ca0fb9a"	#PolicyIDs for the adaHandles -> autoresolve into ${adahandlePolicyID}
		_adahandleAPI="https://preview.api.handle.me"		#Adahandle-API URLs -> autoresolve into ${adahandleAPI}
		_catalystAPI=				#Catalyst-API URLs -> autoresolve into ${catalystAPI}
		_lightModeParametersURL="https://uptime.live/data/cardano/parms/preview-parameters.json"	#Parameters-JSON-File with current informations about cardano-cli version, tip, era, protocol-parameters
		;;


	"guildnet"|"guild-net" )
		network="GuildNet"
		_magicparam="--testnet-magic 141"
		_addrformat="--testnet-magic 141"
		_byronToShelleyEpochs=2
		_tokenMetaServer="https://metadata.cardano-testnet.iohkdev.io/metadata"
		_transactionExplorer=
		_koiosAPI="https://guild.koios.rest/api/v1"
		_adahandlePolicyID="f0ff48bbb7bbe9d59a40f1ce90e9e9d0ff5002ec48f232b49ca0fb9a"	#PolicyIDs for the adaHandles -> autoresolve into ${adahandlePolicyID}
		_adahandleAPI=
		_catalystAPI=				#Catalyst-API URLs -> autoresolve into ${catalystAPI}
		_lightModeParametersURL=		#Parameters-JSON-File with current informations about cardano-cli version, tip, era, protocol-parameters
		;;


	"sancho"|"sancho-net"|"sanchonet" )
		network="SanchoNet"
		_magicparam="--testnet-magic 4"
		_addrformat="--testnet-magic 4"
		_byronToShelleyEpochs=0
		_tokenMetaServer="https://metadata.cardano-testnet.iohkdev.io/metadata"
		_transactionExplorer=
		_koiosAPI="https://sancho.koios.rest/api/v1"
		_adahandlePolicyID="f0ff48bbb7bbe9d59a40f1ce90e9e9d0ff5002ec48f232b49ca0fb9a"	#PolicyIDs for the adaHandles -> autoresolve into ${adahandlePolicyID}
		_adahandleAPI=
		_catalystAPI=				#Catalyst-API URLs -> autoresolve into ${catalystAPI}
		_lightModeParametersURL="https://uptime.live/data/cardano/parms/sanchonet-parameters.json"	#Parameters-JSON-File with current informations about cardano-cli version, tip, era, protocol-parameters
		;;

	"privatetest" )
		network="PrivateNet"
		_magicparam="--testnet-magic 5"
		_addrformat="--testnet-magic 5"
		_byronToShelleyEpochs=0
		_tokenMetaServer="https://metadata.cardano-testnet.iohkdev.io/metadata"
		_transactionExplorer=
		_koiosAPI=
		_adahandlePolicyID="f0ff48bbb7bbe9d59a40f1ce90e9e9d0ff5002ec48f232b49ca0fb9a"	#PolicyIDs for the adaHandles -> autoresolve into ${adahandlePolicyID}
		_adahandleAPI=
		_catalystAPI=				#Catalyst-API URLs -> autoresolve into ${catalystAPI}
		_lightModeParametersURL=		#Parameters-JSON-File with current informations about cardano-cli version, tip, era, protocol-parameters
		;;


	"legacy"|"testnet" ) #Only for documentation purpose, network is inactive
		network="Legacy"
		_magicparam="--testnet-magic 1097911063"
		_addrformat="--testnet-magic 1097911063"
		_byronToShelleyEpochs=74
		_tokenMetaServer="https://metadata.cardano-testnet.iohkdev.io/metadata"
		_transactionExplorer=
		_koiosAPI=
		_adahandlePolicyID="8d18d786e92776c824607fd8e193ec535c79dc61ea2405ddf3b09fe3"
		_adahandleAPI=
		_catalystAPI=				#Catalyst-API URLs -> autoresolve into ${catalystAPI}
		_lightModeParametersURL=		#Parameters-JSON-File with current informations about cardano-cli version, tip, era, protocol-parameters
		;;

esac


#Assign the values to the used variables if not defined before with an other value
magicparam=${magicparam:-"${_magicparam}"}
addrformat=${addrformat:-"${_addrformat}"}
byronToShelleyEpochs=${byronToShelleyEpochs:-"${_byronToShelleyEpochs}"}
tokenMetaServer=${tokenMetaServer:-"${_tokenMetaServer}"}
transactionExplorer=${transactionExplorer:-"${_transactionExplorer}"}
koiosAPI=${koiosAPI:-"${_koiosAPI}"}
adahandlePolicyID=${adahandlePolicyID:-"${_adahandlePolicyID}"}
adahandleAPI=${adahandleAPI:-"${_adahandleAPI}"}
catalystAPI=${catalystAPI:-"${_catalystAPI}"}
lightModeParametersURL=${lightModeParametersURL:-"${_lightModeParametersURL}"}


#Check about the / at the end of the URLs
if [[ "${tokenMetaServer: -1}" == "/" ]]; then tokenMetaServer=${tokenMetaServer%?}; fi #make sure the last char is not a /
if [[ "${koiosAPI: -1}" == "/" ]]; then koiosAPI=${koiosAPI%?}; fi #make sure the last char is not a /
if [[ "${transactionExplorer: -1}" == "/" ]]; then transactionExplorer=${transactionExplorer%?}; fi #make sure the last char is not a /
if [[ "${catalystAPI: -1}" == "/" ]]; then catalystAPI=${catalystAPI%?}; fi #make sure the last char is not a /
if [[ "${adahandleAPI: -1}" == "/" ]]; then adahandleAPI=${adahandleAPI%?}; fi #make sure the last char is not a /


#Check about the needed chain params
if [[ "${magicparam}" == "" || ${addrformat} == "" ||  ${byronToShelleyEpochs} == "" ]]; then majorError "The 'magicparam', 'addrformat' or 'byronToShelleyEpochs' is not set!\nOr maybe you have set the wrong parameter network=\"${network}\" ?\nList of preconfigured network-names: ${networknames}"; exit 1; fi

#Don't allow to overwrite the needed Versions, so we set it after the overwrite part
minCliVersion="8.23.1"  		#minimum allowed cli version for this script-collection version
maxCliVersion="99.99.9"  		#maximum allowed cli version, 99.99.9 = no limit so far
minNodeVersion="8.11.0"  		#minimum allowed node version for this script-collection version
maxNodeVersion="99.99.9"  		#maximum allowed node version, 99.99.9 = no limit so far
minLedgerCardanoAppVersion="7.1.0"  	#minimum version for the cardano-app on the Ledger HW-Wallet
minTrezorCardanoAppVersion="2.6.5"  	#minimum version for the firmware on the Trezor HW-Wallet
minHardwareCliVersion="1.15.0" 		#minimum version for the cardano-hw-cli
minCardanoSignerVersion="1.16.0"	#minimum version for the cardano-signer binary
minCatalystToolboxVersion="0.5.0"	#minimum version for the catalyst-toolbox binary

#Defaults - Variables and Constants
defEra="" #Era for non era related cardano-cli commands
defTTL=100000 #Default seconds for transactions to be valid
addrTypePayment="payment"
addrTypeStake="stake"
lightModeParametersJSON="" #will be updated with the latest parameters json if scripts are running in light mode
koiosAuthorizationHeader="" #empty header for public tier koios curl requests

#Set the CARDANO_NODE_SOCKET_PATH for all cardano-cli operations which are interacting with a local node
export CARDANO_NODE_SOCKET_PATH=${socket}

#set the CARDANO_NODE_NETWORK_ID for all cardano-cli operations, the ${magicparam} stays active in the background
if [[ "${magicparam,,}" == *"mainnet"* ]]; then
	export CARDANO_NODE_NETWORK_ID="mainnet"; #set it to mainnet
	else
	export CARDANO_NODE_NETWORK_ID="${magicparam#* }"; #set it to the number behind the space (e.g. '--testnet-magic 1234' -> '1234'}
fi

#Set the bc linebreak to a big number so we can work with really biiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiig numbers
export BC_LINE_LENGTH=1000




#-------------------------------------------------------
#TrimString
function trimString
{
    echo "$1" | sed -n '1h;1!H;${;g;s/^[ \t]*//g;s/[ \t]*$//g;p;}'
}
#-------------------------------------------------------


#-------------------------------------------------------
#queryLight_protocolParameters function
#
# makes an online query via the hosted service to get the current protocolParameters file
# which also includes the used cardano-cli version, era, tip, lastupdate
#
queryLight_protocolParameters() {

	local queryData=${1,,}
        local errorcnt=0
        local error=-1
        while [[ ${errorcnt} -lt 5 && ${error} -ne 0 ]]; do #try a maximum of 5 times to request the information
		error=0
		response=$(curl --compressed -sL -m 30 -X GET -w "---spo-scripts---%{http_code}" -H "Cache-Control: no-cache, no-store" "${lightModeParametersURL}?rnd=$(date +%s 2> /dev/null)" 2> /dev/null)
		if [[ $? -ne 0 ]]; then error=1; sleep 1; fi; #if there is an error, wait for a second and repeat
                errorcnt=$(( ${errorcnt} + 1 ))
	done
	if [[ ${error} -ne 0 ]]; then echo -e "Query of the Light-Mode Protocol-Parameters-JSON via curl failed, tried 5 times."; exit 1; fi; #curl query failed

	#Split the response string into JSON content and the HTTP-ResponseCode
	if [[ "${response}" =~ (.*)---spo-scripts---([0-9]*)* ]]; then
		local responseJSON="${BASH_REMATCH[1]}"
		local responseCode="${BASH_REMATCH[2]}"
	else
		echo -e "Query of the Light-Mode Protocol-Paramters-JSON curl failed. Could not separate Content and ResponseCode."; exit 1; #curl query failed
	fi

	#Check the responseCode
	case ${responseCode} in
		"200" ) ;; #all good, continue
		* )     echo -e "Query of the Light-Mode Protocol-Parameters-JSON failed\nHTTP Request File: ${lightModeParametersURL}\nHTTP Response Code: ${responseCode}"; exit 1; #exit with a failure and the http response code
        esac;
	parametersJSON=$(jq -r . <<< "${responseJSON}" 2> /dev/null)
	if [[ $? -ne 0 ]]; then echo -e "Query of the Light-Mode Protocol-Parameters-JSON failed, not a JSON response."; exit 1; fi; #reponse is not a json file

	#return the response
	printf "${parametersJSON}"
	unset response error errorcnt parametersJSON

}
#-------------------------------------------------------


#-------------------------------------------------------
#queryLight_tip function
#
# makes an online query via koios API and returns the current tip
#
queryLight_tip() {

        local errorcnt=0
        local error=-1
        while [[ ${errorcnt} -lt 5 && ${error} -ne 0 ]]; do #try a maximum of 5 times to request the information via koios API
		error=0
		response=$(curl -sL -m 30 -X GET -w "---spo-scripts---%{http_code}" "${koiosAPI}/tip" -H "Accept: application/json" -H "Content-Type: application/json" -H "${koiosAuthorizationHeader}" 2> /dev/null)
		if [ $? -ne 0 ]; then error=1; fi;
                errorcnt=$(( ${errorcnt} + 1 ))
	done
	if [[ ${error} -ne 0 ]]; then echo -e "Query-Tip of the Koios-API via curl failed, tried 5 times."; exit 1; fi; #curl query failed

	#Split the response string into JSON content and the HTTP-ResponseCode
	if [[ "${response}" =~ (.*)---spo-scripts---([0-9]*)* ]]; then
		local responseJSON="${BASH_REMATCH[1]}"
		local responseCode="${BASH_REMATCH[2]}"
	else
		echo -e "Query of the Koios-API via curl failed. Could not separate Content and ResponseCode."; exit 1; #curl query failed
	fi

	#Check the responseCode
	case ${responseCode} in
		"200" ) ;; #all good, continue
		* )     echo -e "HTTP Response code: ${responseCode}"; exit 1; #exit with a failure and the http response code
        esac;
	tipRet=$(jq -r ".[0].abs_slot" <<< "${responseJSON}" 2> /dev/null)
	if [ $? -ne 0 ]; then echo -e "Query-Tip via Koios-API (${koiosAPI}) failed, not a JSON response."; exit 1; fi; #reponse is not a json file

	#return the tip
	printf "${tipRet}"
	unset tipRet response responseCode responseJSON error errorcnt

}
#-------------------------------------------------------

#-------------------------------------------------------
#queryLight_epoch function
#
# makes an online query via koios API and returns the current epoch
#
queryLight_epoch() {

        local errorcnt=0
        local error=-1
        while [[ ${errorcnt} -lt 5 && ${error} -ne 0 ]]; do #try a maximum of 5 times to request the information via koios API
		error=0
		response=$(curl -sL -m 30 -X GET -w "---spo-scripts---%{http_code}" "${koiosAPI}/tip" -H "Accept: application/json" -H "Content-Type: application/json" -H "${koiosAuthorizationHeader}" 2> /dev/null)
		if [ $? -ne 0 ]; then error=1; fi;
                errorcnt=$(( ${errorcnt} + 1 ))
	done
	if [[ ${error} -ne 0 ]]; then echo -e "Query-Epoch of the Koios-API via curl failed, tried 5 times."; exit 1; fi; #curl query failed

	#Split the response string into JSON content and the HTTP-ResponseCode
	if [[ "${response}" =~ (.*)---spo-scripts---([0-9]*)* ]]; then
		local responseJSON="${BASH_REMATCH[1]}"
		local responseCode="${BASH_REMATCH[2]}"
	else
		echo -e "Query of the Koios-API via curl failed. Could not separate Content and ResponseCode."; exit 1; #curl query failed
	fi

	#Check the responseCode
	case ${responseCode} in
		"200" ) ;; #all good, continue
		* )     echo -e "HTTP Response code: ${responseCode}"; exit 1; #exit with a failure and the http response code
        esac;
	epochRet=$(jq -r ".[0].epoch_no" <<< "${responseJSON}" 2> /dev/null)
	if [ $? -ne 0 ]; then echo -e "Query-Tip via Koios-API (${koiosAPI}) failed, not a JSON response."; exit 1; fi; #reponse is not a json file

	#return the tip
	printf "${epochRet}"
	unset epochRet response responseCode responseJSON error errorcnt

}
#-------------------------------------------------------

#-------------------------------------------------------
#Setting offlineFile default value, versionInfo, tokenRegistryquery, tx output cropping to boolean values
if [[ "${offlineFile}" == "" ]]; then offlineFile="./offlineTransfer.json"; fi
if [[ "${showVersionInfo^^}" == "NO" ]]; then showVersionInfo=false; else showVersionInfo=true; fi
if [[ "${queryTokenRegistry^^}" == "NO" ]]; then queryTokenRegistry=false; else queryTokenRegistry=true; fi
if [[ "${cropTxOutput^^}" == "NO" ]]; then cropTxOutput=false; else cropTxOutput=true; fi
#-------------------------------------------------------

#-------------------------------------------------------
versionCheck() { printf '%s\n%s' "${1}" "${2}" | sort -C -V; } #$1=minimal_needed_version, $2=current_node_version
#-------------------------------------------------------

#-------------------------------------------------------
exists() {
 command -v "$1" >/dev/null 2>&1
}
#-------------------------------------------------------

#-------------------------------------------------------
#Check cardano-cli
if ! exists "${cardanocli}"; then majorError "Path ERROR - Path to cardano-cli is not correct or cardano-cli binaryfile is missing!\nYour current set path is: ${cardanocli}"; exit 1; fi
versionCLI=$(${cardanocli} version 2> /dev/null |& head -n 1 |& awk {'print $2'})
versionCheck "${minCliVersion}" "${versionCLI}"
if [[ $? -ne 0 ]]; then majorError "Version ${versionCLI} ERROR - Please use a cardano-cli version ${minCliVersion} or higher !\nOlder versions are not supported for compatibility issues, please upgrade - thx."; exit 1; fi
versionCheck "${versionCLI}" "${maxCliVersion}"
if [[ $? -ne 0 ]]; then majorError "Version ${versionCLI} ERROR - Please use a cardano-cli version between ${minCliVersion} and ${maxCliVersion} !\nOther versions are not supported for compatibility issues, please check if newer scripts are available - thx."; exit 1; fi
#-------------------------------------------------------


#-------------------------------------------------------
#Set the workMode for the scripts and additional variables according to it
workMode=${workMode,,} #convert it to lowercase
case ${workMode} in
	"online")	#Online-Mode(Full-Mode) - The machine is online and a local running node is present
			onlineMode=true; fullMode=true; lightMode=false; offlineMode=false;
			;;

	"light")	#Light-Mode - The machine is online, but without a local node
			onlineMode=true; fullMode=false; lightMode=true; offlineMode=false;

			#Check if there are needed entries for the light mode
			if [[ "${lightModeParametersURL}" == "" || "${koiosAPI}" == "" ]]; then majorError "There is no Light-Mode available for this network!"; exit 1; fi

			#Get the latest lightModeParametersJSON so it does not need to be requested multiple times
			lightModeParametersJSON=$(queryLight_protocolParameters);
			if [[ $? -ne 0 ]]; then majorError "${lightModeParametersJSON}"; exit 1; fi

			#Read all values at once
			{ read lightModeParametersDate; read lightModeParametersMagic; read lightModeParametersVersionCLI; } <<< $(jq -r ".sposcriptsLightMode.lastUpdate, .sposcriptsLightMode.magic, .sposcriptsLightMode.versionCLI" 2> /dev/null <<< "${lightModeParametersJSON}")

			#Check if the lightModeParametersJSON is not older than a few hours
			lightModeParametersTimeDiff=$(( $(date -u +%s) - $(date --date="${lightModeParametersDate}" +%s) ))
			if [[ ${lightModeParametersTimeDiff} -gt 21600 ]]; then majorError "The time difference from your local time to the online Light-Mode-Parameters file\nis bigger than 6 hours! Its currently ${lightModeParametersTimeDiff} seconds.\nThis means that either your local time is off, or that the LightMode parameters-file hosting service is not up2date.\nIn that case, please retry a bit later and/or report the issue - thx!"; exit 1; fi

			#Check if the online lightModeParametersFile contains the same network magic
			if [[ "${lightModeParametersMagic}" != "${CARDANO_NODE_NETWORK_ID}" ]]; then majorError "The online version of the parameters-file has a network-magic ${lightModeParametersMagic},\nbut the scripts are locally configured for network-magic ${CARDANO_NODE_NETWORK_ID} !"; exit 1; fi

			#Check that the local CLI version is not lower than the lightModeParametersVersionCLI
			versionCheck "${lightModeParametersVersionCLI}" "${versionCLI}"
			if [[ $? -ne 0 ]]; then majorError "For working in LightMode, please use at least a local cardano-cli version ${lightModeParametersVersionCLI} or higher!\nYou are currently using version ${versionCLI}, please upgrade - thx."; exit 1; fi

			#Check about a provided koiosApiToken
			koiosApiToken=$(trimString "${koiosApiToken}") #remove spaces if present

			#Set the default koios tier
			koiosApiTier="Public-Tier" #the standard public tier
			koiosApiProjID="---" #no project id
			koiosApiExpireDate="no expire date" #no expire date
			koiosAuthorizationHeader="" #empty header for public tier koios curl requests

			#Check the koiosApiToken - which is JWT encoded. Decode it and read out the koios tier settings
			if [[ "${koiosApiToken}" != "" ]]; then
				result=$(jq -R 'split(".") | .[1] | @base64d | fromjson' <<< "${koiosApiToken}" 2> /dev/null)
				if [[ $? -ne 0 ]]; then majorError "The provided koiosApiToken '${koiosApiToken}'\nis not a valid one! Please recheck for typos, register a new one or leave the koiosApiToken="" entry empty."; exit 1; fi
				{ read koiosApiExpireDate; read koiosApiTier; read koiosApiProjID; } <<< $( jq -r ".exp // -1, .tier, .projID // \"---\"" <<< ${result} 2> /dev/null)
				if [[ ${koiosApiExpireDate} -gt 0 ]]; then koiosApiExpireDate=$(date --date="@${koiosApiExpireDate}"); fi #get the local expire date from the utc seconds since unix-time-start
				case ${koiosApiTier} in
					"1")	koiosApiTier="Free-Tier";;
					"2")	koiosApiTier="Pro-Tier";;
					"3")	koiosApiTier="Premium-Tier";;
					*)	koiosApiTier="Tier ${koiosApiTier}";;
				esac
				koiosAuthorizationHeader="authorization: Bearer ${koiosApiToken}" #additional header for koios curl requests with authentication
			fi
			;;


	"offline")	#Offline-Mode - The machine is offline (airgapped)
			onlineMode=false; fullMode=false; lightMode=false; offlineMode=true;
			;;

	*)		#Unknown workMode
			majorError "Unknown workMode '${workMode}'\n\nPlease set it to 'online', 'light' or 'offline'";
			exit 1;
esac
#-------------------------------------------------------

#-------------------------------------------------------
if ${showVersionInfo}; then echo -ne "\n\e[0mVersion-Info: \e[32mcli ${versionCLI}\e[0m"; fi
#-------------------------------------------------------

#-------------------------------------------------------
#Check cardano-node only in workMode="online" (FullMode)
if ${fullMode}; then
	if ! exists "${cardanonode}"; then majorError "Path ERROR - Path to cardano-node is not correct or cardano-node binaryfile is missing!\nYour current set path is: ${cardanonode}"; exit 1; fi
	versionNODE=$(${cardanonode} version 2> /dev/null |& head -n 1 |& awk {'print $2'})
	versionCheck "${minNodeVersion}" "${versionNODE}"
	if [[ $? -ne 0 ]]; then majorError "Version ${versionNODE} ERROR - Please use a cardano-node version ${minNodeVersion} or higher !\nOld versions are not supported for security reasons, please upgrade - thx."; exit 1; fi
	versionCheck "${versionNODE}" "${maxNodeVersion}"
	if [[ $? -ne 0 ]]; then majorError "Version ${versionNODE} ERROR - Please use a cardano-node version between ${minNodeVersion} and ${maxNodeVersion} !\nOther versions are not supported for compatibility issues, please check if newer scripts are available - thx."; exit 1; fi
	if ${showVersionInfo}; then echo -ne " / \e[32mnode ${versionNODE}\e[0m"; fi
fi
#-------------------------------------------------------


#-------------------------------------------------------
#Check bech32 tool if given path is ok, if not try to use the one in the scripts folder
if ! exists "${bech32_bin}"; then
				#Try the one in the scripts folder
				if [[ -f "${scriptDir}/bech32" ]]; then bech32_bin="${scriptDir}/bech32";
				else majorError "Path ERROR - Path to the 'bech32' binary is not correct or 'bech32' binaryfile is missing!\nYou can find it here: https://github.com/input-output-hk/bech32/releases/latest\nThis is needed to calculate the correct Bech32-Assetformat like 'asset1ee0u29k4xwauf0r7w8g30klgraxw0y4rz2t7xs'."; exit 1; fi
fi


#-------------------------------------------------------------
#Check if curl, jq, bc and xxd is installed
if ! exists curl; then echo -e "\e[33mYou need the little tool 'curl', its needed to fetch online data !\n\nInstall it on Ubuntu/Debian like:\n\e[97msudo apt update && sudo apt -y install curl\n\n\e[33mThx! :-)\e[0m\n"; exit 2; fi
if ! exists jq; then echo -e "\e[33mYou need the little tool 'jq', its needed to do the json processing !\n\nInstall it on Ubuntu/Debian like:\n\e[97msudo apt update && sudo apt -y install jq\n\n\e[33mThx! :-)\e[0m\n"; exit 2; fi
if ! exists bc; then echo -e "\e[33mYou need the little tool 'bc', its needed to do larger number calculations !\n\nInstall it on Ubuntu/Debian like:\n\e[97msudo apt update && sudo apt -y install bc\n\n\e[33mThx! :-)\e[0m\n"; exit 2; fi
if ! exists xxd; then echo -e "\e[33mYou need the little tool 'xxd', its needed to convert hex strings !\n\nInstall it on Ubuntu/Debian like:\n\e[97msudo apt update && sudo apt -y install xxd\n\n\e[33mThx! :-)\e[0m\n"; exit 2; fi


#-------------------------------------------------------------
#Searching for the temp directory (used for transactions files)
tempDir=$(dirname $(mktemp -ut tmp.XXXX))


#-------------------------------------------------------
#Return the era the chain is currently in
get_NodeEra() {
	case ${workMode} in
		"online")	local tmpEra=$(${cardanocli} query tip ${magicparam} 2> /dev/null | jq -r ".era | select (.!=null)" 2> /dev/null);;
		"offline")	local tmpEra=$(jq -r ".protocol.era" 2> /dev/null < ${offlineFile});;
		"light")	local tmpEra=$(jq -r ".sposcriptsLightMode.lastTip.era" 2> /dev/null <<< "${lightModeParametersJSON}");;
	esac
if [[ ! "${tmpEra}" == "" ]]; then tmpEra=${tmpEra,,}; else tmpEra="auto"; fi
echo "${tmpEra}"; return 0; #return era in lowercase
}

##Set nodeEra parameter ( --byron-era, --shelley-era, --allegra-era, --mary-era, --alonzo-era, --babbage-era or empty)
tmpEra=$(get_NodeEra);
if [[ ! "${tmpEra}" == "auto" ]]; then
	nodeEraParam="--${tmpEra}-era"; #for cli commands before 8.12.0
	cliEra="${tmpEra,,}" #new era selection parameter for cardano cli 8.12.0+
	else
	nodeEraParam="";
	cliEra="${defEra}";
fi

#Temporary fix to lock the transaction build-raw to alonzo era for
#Hardware-Wallet operations. Babbage-Era is not yet supported, so we will lock this for now
#if [[ "${nodeEraParam}" == "" ]] || [[ "${nodeEraParam}" == "--conway-era" ]]; then nodeEraParam="--babbage-era"; cliEra="babbage"; fi
#-------------------------------------------------------


#Display current Mode
if ${showVersionInfo}; then

				case ${workMode} in
					"online")	echo -ne "\t\tMode: \e[36monline(full)\e[0m";
							if [ ! -e "${socket}" ]; then echo -ne "\n\n\e[35mWarning: Node-Socket does not exist !\e[0m"; fi
							;;

					"light") 	echo -ne "\t\tMode: \e[93monline(light)\e[0m"
							;;

					"offline") 	echo -ne "\t\tMode: \e[32moffline\e[0m"
							;;
				esac

				if [[ "${cliEra}" != "${defEra}" ]]; then
							echo -ne "\tEra: \e[32m${cliEra}\e[0m";
						   else
							echo -ne "\tEra: \e[36mdefault\e[0m";
				fi

				if [[ "${magicparam}" == *"mainnet"* ]]; then
					echo -ne "\tNetwork: \e[32mMainnet\e[0m";
				else
					echo -ne "\tTestnet: \e[91m${network} (magic $(echo ${magicparam} | awk {'print $2'}))\e[0m";
				fi

echo
				if ${offlineMode}; then echo -e "\n\e[0mLocal-Time:\e[32m $(date)\e[0m (\e[33mverify correct offline-time\e[0m)"; fi #show the local time in offline mode as an extra information
				if ${lightMode}; then echo -e "\n\e[0mkoiosAPI-ProjID:\e[32m ${koiosApiProjID} (${koiosApiTier})\e[0m valid until '\e[32m${koiosApiExpireDate}\e[0m'"; fi #show koios api token info in light mode
echo
fi






#-------------------------------------------------------
#AddressType check
check_address() {
tmp=$(${cardanocli} address info --address $1 2> /dev/null)
if [[ $? -ne 0 ]]; then echo -e "\e[35mERROR - Unknown address format for address: $1 !\e[0m"; exit 1; fi
local era=$(jq -r .era <<< ${tmp} 2> /dev/null)
if [[ "${era^^}" == "BYRON" ]]; then echo -e "\e[33mINFO - Byron addresses are only supported as a destination address!\e[0m\n"; fi
}

get_addressType() {
${cardanocli} address info --address $1 2> /dev/null | jq -r .type
}

get_addressEra() {
${cardanocli} address info --address $1 2> /dev/null | jq -r .era
}


#-------------------------------------------------------
#AdaHandle Format checks (exits with true or false)
checkAdaRootHandleFormat() {
	#AdaHandles without SubHandles
	if [[ "${1,,}" =~ ^\$[a-z0-9_.-]{1,15}$ ]]; then true; else false; fi
}

checkAdaSubHandleFormat() {
	#AdaHandles with SubHandles
	if [[ "${1,,}" =~ ^\$[a-z0-9_.-]{1,15}@[a-z0-9_.-]{1,15}$ ]]; then true; else false; fi
}

checkAdaHandleFormat() {
	#All AdaHandles formats - root and sub/virtual ones
	if [[ "${1,,}" =~ ^\$[a-z0-9_.-]{1,15}(@[a-z0-9_.-]{1,15})?$ ]]; then true; else false; fi
}



#-------------------------------------------------------------
#Subroutine for user interaction
ask() {
    local prompt default reply

    if [ "${2:-}" = "Y" ]; then
        prompt="Y/n"
        default=Y
    elif [ "${2:-}" = "N" ]; then
        prompt="y/N"
        default=N
    else
        prompt="y/n"
        default=
    fi

    while true; do

        # Ask the question (not using "read -p" as it uses stderr not stdout)
        echo -ne "$1 [$prompt] "

        # Read the answer (use /dev/tty in case stdin is redirected from somewhere else)
        read reply </dev/tty

        # Default?
        if [ -z "$reply" ]; then
            reply=$default
        fi

        # Check if the reply is valid
        case "$reply" in
            Y*|y*) return 0 ;;
            N*|n*) return 1 ;;
        esac

    done
}
#-------------------------------------------------------


#-------------------------------------------------------
#Subroutine for password interaction
ask_pass() {
 	local pass #pass variable only lives within this function
	echo -ne "${1}: " > $(tty) #redirect to the tty output
	IFS= read -s pass #read in the password but don't show it
	local hidden=$(sed 's/./*/g' <<< ${pass})
	echo -ne "${hidden}" > $(tty) #show stars for the chars
	echo -n "${pass}" #pass the password to the calling instance
	unset pass #unset the variable
}
#-------------------------------------------------------


#-------------------------------------------------------
#Subroutines to set read/write flags for important files
file_lock()
{
if [ -f "$1" ]; then chmod 400 "$1"; fi
}

file_unlock()
{
if [ -f "$1" ]; then chmod 600 "$1"; fi
}
#-------------------------------------------------------


#-------------------------------------------------------
#Subroutines to calculate current slotHeight(tip) depending on online/light/offline mode
get_currentEpoch()
{
case ${workMode} in

        "online")       #Full-OnlineMode, query the local node
                        local currentEpoch=$(${cardanocli} query tip ${magicparam} 2> /dev/null | jq -r .epoch 2> /dev/null);

                        #if the return is blank (bug in the cli), then retry 2 times. if failing again, exit with a majorError
                        if [[ "${currentEpoch}" == "" ]]; then local currentEpoch=$(${cardanocli} query tip ${magicparam} 2> /dev/null | jq -r .epoch 2> /dev/null);
                                if [[ "${currentEpoch}" == "" ]]; then local currentEpoch=$(${cardanocli} query tip ${magicparam} 2> /dev/null | jq -r .epoch 2> /dev/null);
                                        if [[ "${currentEpoch}" == "" ]]; then majorError "query tip/epoch return from cardano-cli failed"; exit 1; fi
                                fi
                        fi
                        ;;

        "light")        #Light-Mode, query koios about the tip
                        currentEpoch=$(queryLight_epoch);
                        if [[ $? -ne 0 ]]; then majorError "${currentEpoch}"; exit 1; fi
                        ;;

        "offline")      #Offline-Mode, calculate the tip from the genesis file
                        #Static

			#Check path to genesis files
			if [[ ! -f "${genesisfile}" ]]; then majorError "Path ERROR - Path to the shelley genesis file '${genesisfile}' is wrong or the file is missing!"; exit 1; fi

			local startTimeGenesis; local epochLength;
			{ read startTimeGenesis; read epochLength; } <<< $( jq -r ".systemStart // \"null\", .epochLength // \"null\"" < ${genesisfile} 2> /dev/null)
			local startTimeSec=$(date --date=${startTimeGenesis} +%s)     #in seconds (UTC)
			local currentTimeSec=$(date -u +%s)                           #in seconds (UTC)
			local currentEpoch=$(( (${currentTimeSec}-${startTimeSec}) / ${epochLength} ))  #returns a integer number, we like that
                        ;;
esac

echo ${currentEpoch}
}
#-------------------------------------------------------


#-------------------------------------------------------
#Subroutines to calculate time until next epoch from genesis.json
get_timeUntilNextEpoch()
{

	#Check path to genesis files
	if [[ ! -f "${genesisfile}" ]]; then majorError "Path ERROR - Path to the shelley genesis file '${genesisfile}' is wrong or the file is missing!"; exit 1; fi

	local startTimeGenesis; local epochLength;
	{ read startTimeGenesis; read epochLength; } <<< $( jq -r ".systemStart // \"null\", .epochLength // \"null\"" < ${genesisfile} 2> /dev/null)
	local startTimeSec=$(date --date=${startTimeGenesis} +%s)     #in seconds (UTC)
	local currentTimeSec=$(date -u +%s)                           #in seconds (UTC)
	local currentEPOCH=$(( (${currentTimeSec}-${startTimeSec}) / ${epochLength} ))  #returns a integer number, we like that
	local timeUntilNextEpoch=$(( ${epochLength} - (${currentTimeSec}-${startTimeSec}) + (${currentEPOCH}*${epochLength}) ))
	echo ${timeUntilNextEpoch}

}
#-------------------------------------------------------


#-------------------------------------------------------
#Subroutines to calculate current slotHeight(tip) depending on online/light/offline mode
get_currentTip()
{
case ${workMode} in

	"online")	#Full-OnlineMode, query the local node
			local currentTip=$(${cardanocli} query tip ${magicparam} 2> /dev/null | jq -r .slot 2> /dev/null);  #only "slot" instead of "slotNo" since 1.26.0

			#if the return is blank (bug in the cli), then retry 2 times. if failing again, exit with a majorError
			if [[ "${currentTip}" == "" ]]; then local currentTip=$(${cardanocli} query tip ${magicparam} 2> /dev/null | jq -r .slot 2> /dev/null);
				if [[ "${currentTip}" == "" ]]; then local currentTip=$(${cardanocli} query tip ${magicparam} 2> /dev/null | jq -r .slot 2> /dev/null);
					if [[ "${currentTip}" == "" ]]; then majorError "query tip return from cardano-cli failed"; exit 1; fi
				fi
			fi
			;;

	"light")	#Light-Mode, query koios about the tip
			currentTip=$(queryLight_tip);
			if [[ $? -ne 0 ]]; then majorError "${currentTip}"; exit 1; fi
			;;

	"offline")	#Offline-Mode, calculate the tip from the genesis file
			#Static

                        if [[ ! -f "${genesisfile}" ]]; then majorError "Path ERROR - Path to the shelley genesis file '${genesisfile}' is wrong or the file is missing!"; exit 1; fi
                        if [[ ! -f "${genesisfile_byron}" ]]; then majorError "Path ERROR - Path to the byron genesis file '${genesisfile_byron}' is wrong or the file is missing!"; exit 1; fi

			local slotLength; 		#In Secs
			local epochLength;		#In Secs
			local slotsPerKESPeriod; 	#Number
			local startTimeGenesis;		#In Text
			{ read slotLength; read epochLength; read slotsPerKESPeriod; read startTimeGenesis; } <<< $(jq -r ".slotLength // \"null\", .epochLength // \"null\", .slotsPerKESPeriod // \"null\", .systemStart // \"null\"" < ${genesisfile} 2> /dev/null)
			local startTimeByron=$(jq -r .startTime < ${genesisfile_byron} 2> /dev/null)           #In Secs(abs)
			local startTimeSec=$(date --date=${startTimeGenesis} +%s)                     #In Secs(abs)
			local transTimeEnd=$(( ${startTimeSec}+(${byronToShelleyEpochs}*${epochLength}) ))                    #In Secs(abs) End of the TransitionPhase
			local byronSlots=$(( (${startTimeSec}-${startTimeByron}) / 20 ))              #NumSlots between ByronChainStart and ShelleyGenesisStart(TransitionStart)
			local transSlots=$(( (${byronToShelleyEpochs}*${epochLength}) / 20 ))         #NumSlots in the TransitionPhase

			#Dynamic
			local currentTimeSec=$(date -u +%s)

			#Calculate current slot
			if [[ "${currentTimeSec}" -lt "${transTimeEnd}" ]];
			        then #In Transistion Phase between ShelleyGenesisStart and TransitionEnd
			        local currentTip=$(( ${byronSlots} + (${currentTimeSec}-${startTimeSec}) / 20 ))
			        else #After Transition Phase
			        local currentTip=$(( ${byronSlots} + ${transSlots} + ((${currentTimeSec}-${transTimeEnd}) / ${slotLength}) ))
			fi
			;;

esac

echo ${currentTip}
}
#-------------------------------------------------------


#-------------------------------------------------------
#Subroutines to calculate current TTL - SHOULD NOT BE USED ANYMORE, DIRECTLY CALCULATE THE NEW TTL FROM THE CURRENT TIP IN EACH SCRIPT
get_currentTTL()
{
	currentTip=$(get_currentTip);
	if [[ $? -ne 0 ]]; then majorError "${currentTip}"; exit 1; fi
	echo $(( ${currentTip} + ${defTTL} )) #100000(defTTL) so a little over a day to have time to collect witnesses and transmit the transaction
}
#-------------------------------------------------------


#-------------------------------------------------------
#Subroutines to check the syncState of the node
get_currentSync()
{
case ${workMode} in

	"online")	#Full-OnlineMode, query the local node
			local currentSync=$(${cardanocli} query tip ${magicparam} 2> /dev/null | jq -r .syncProgress 2> /dev/null);

			#if the return is blank (bug in the cli), then retry 2 times. if failing again, exit with a majorError
			if [[ "${currentSync}" == "" ]]; then local currentSyncp=$(${cardanocli} query tip ${magicparam} 2> /dev/null | jq -r .syncProgress 2> /dev/null);
				if [[ "${currentSync}" == "" ]]; then local currentTip=$(${cardanocli} query tip ${magicparam} 2> /dev/null | jq -r .syncProgress 2> /dev/null);
					if [[ "${currentSync}" == "" ]]; then majorError "query tip return from cardano-cli failed"; exit 1; fi
				fi
			fi

			if [[ ${currentSync} == "100.00" ]]; then echo "synced"; else echo "unsynced"; fi
			;;

	"light")	#Light-Mode, query koios about the tip - we pretend that if koios api responds with a tip without an error, that the database is also synced
			local currentTip=$(queryLight_tip);
			if [[ $? -eq 0 ]]; then echo "synced"; else echo "unsynced"; fi
			;;

	"offline")	#Offline-Mode, calculate the tip from the genesis file
			echo "offline"
			;;
esac
}
#-------------------------------------------------------


#-------------------------------------------------------
#Displays an Errormessage if parameter is not 0
checkError()
{
if [[ $1 -ne 0 ]]; then echo -e "\n\n\e[35mERROR (Code $1) !\e[0m\n"; exit $1; fi
}
#-------------------------------------------------------


#-------------------------------------------------------
#Converts a raw UTXO query output into the new UTXO JSON style since 1.26.0, but with stringnumbers
#Building the JSON structure from scratch, way faster than using jq for it
generate_UTXO()  #Parameter1=RawUTXO, Parameter2=Address
{

  #Convert given bech32 address into a base16(hex) address, not needed in theses scripts, but to make a true 1:1 copy of the normal UTXO JSON output
  #local utxoAddress=$(${cardanocli} address info --address ${2} 2> /dev/null | jq -r .base16); if [[ $? -ne 0 ]]; then local utxoAddress=${2}; fi
  local utxoAddress=${2}
  local utxoJSON="{" #start with a blank JSON skeleton and an open {

  while IFS= read -r line; do
  IFS=' ' read -ra utxo_entry <<< "${line}" # utxo_entry array holds entire utxo string

  local utxoHashIndex="${utxo_entry[0]}#${utxo_entry[1]}"

  #There are lovelaces on the UTXO -> check if the name is "lovelace" or if there are just 3 arguments
  if [[ "${utxo_entry[3]}" == "lovelace" ]] || [[ ${#utxo_entry[@]} -eq 3 ]]; then
                                                local idx=5; #normal indexstart for the next checks
                                                local utxoAmountLovelaces=${utxo_entry[2]};
                                              else
                                                local idx=2; #earlier indexstart, because no lovelaces present
                                                local utxoAmountLovelaces=0;
  fi

  #Build the entry for each UtxoHashIndex, start with the hash and the entry for the address and the lovelaces
  local utxoJSON+="\"${utxoHashIndex}\": { \"address\": \"${utxoAddress}\", \"value\": { \"lovelace\": \"${utxoAmountLovelaces}\""

  #value part is open
  local value_open=true

  local idxCompare=$(( ${idx} - 1 ))
  local old_asset_policy=""
  local policy_open=false

  #Add the Token entries if tokens available, also check for data (script) entries
  if [[ ${#utxo_entry[@]} -gt ${idxCompare} ]]; then # contains tokens

    while [[ ${#utxo_entry[@]} -gt ${idx} ]]; do  #check if there are more entries, and the amount is a number
      local next_entry=${utxo_entry[${idx}]}

      #if the next entry is a number -> process asset/tokendata
      if [[ "${next_entry}" =~ ^[0-9]+$ ]]; then
              local asset_amount=${next_entry}
              local asset_hash_name="${utxo_entry[$((idx+1))]}"
              IFS='.' read -ra asset <<< "${asset_hash_name}"
              local asset_policy=${asset[0]}

	      #Open up a policy if it is a different one
	      if [[ "${asset_policy}" != "${old_asset_policy}" ]]; then #open up a new policy
			if ${policy_open}; then local utxoJSON="${utxoJSON%?}}"; fi #close the previous policy first and remove the last , from the last assetname entry of the previous policy
			local utxoJSON+=", \"${asset_policy}\": {"
			local policy_open=true
			local old_asset_policy=${asset_policy}
	      fi

              local asset_name=${asset[1]}
              #Add the Entry of the Token
	      local utxoJSON+="\"${asset_name}\": \"${asset_amount}\"," # the  , will be deleted when the policy part closes
              local idx=$(( ${idx} + 3 ))

     #if its a data entry, add the datumhash key-field to the json output
     elif [[ "${next_entry}" == "TxOutDatumHash" ]] && [[ "${utxo_entry[$((idx+1))]}" == *"Data"* ]]; then
	      if ${policy_open}; then local utxoJSON="${utxoJSON%?}}"; local policy_open=false; fi #close the previous policy first and remove the last , from the last assetname entry of the previous policy
	      if ${value_open}; then local utxoJSON+="}"; local value_open=false; fi #close the open value part
              local data_entry_hash=${utxo_entry[$((idx+2))]}
	      #Add the Entry for the data(datumhash)
              local utxoJSON+=",\"datumhash\": \"${data_entry_hash//\"/}\""
              local idx=$(( ${idx} + 4 ))

     #stop the decoding if an entry related to a "Datum" is found that is not the "TxOutDatumHash" from above, can be extended in the future if needed
     elif [[ "${next_entry^^}" == *"DATUM"* ]]; then break

     else
              local idx=$(( ${idx} + 1 ))  #go to the next entry of the array
     fi
    done
  fi

  #close policy if still open
  if ${policy_open}; then local utxoJSON="${utxoJSON%?}}"; fi #close the previous policy first and remove the last char "," from the last assetname entry of the previous policy

  #close value part if still open
  if ${value_open}; then local utxoJSON+="}"; fi #close the open value part

  #close the utxo part
  local utxoJSON+="},"  #the last char "," will be deleted at the end

done < <(printf "%s\n" "${1}" | tail -n +3) #read in from parameter 1 (raw utxo) but cut first two lines. printf must be used with format %s, otherwise utxo content like \000 would be automatically decoded.

  #close the whole json but delete the last char "," before that. do it only if there are entries present (length>1), else return an empty json
  if [[ ${#utxoJSON} -gt 1 ]]; then echo "${utxoJSON%?}}"; else echo "{}"; fi;

}
#-------------------------------------------------------


#-------------------------------------------------------
#Cuts out all UTXOs in a mary style UTXO JSON that are not the given UTXO hash ($2)
#The given UTXO hash can be multiple UTXO hashes with the or separator | for egrep
filterFor_UTXO_old()
{
local inJSON=${1}
local searchUTXO=${2}
local outJSON=${inJSON}
local utxoEntryCnt=$(jq length <<< ${inJSON})
local tmpCnt=0
for (( tmpCnt=0; tmpCnt<${utxoEntryCnt}; tmpCnt++ ))
do
local utxoHashIndex=$(jq -r "keys[${tmpCnt}]" <<< ${inJSON})
if [[ $(echo "${utxoHashIndex}" | egrep "${searchUTXO}" | wc -l) -eq 0 ]]; then local outJSON=$( jq "del (.\"${utxoHashIndex}\")" <<< ${outJSON}); fi
done
echo "${outJSON}"
}
#-------------------------------------------------------


#-------------------------------------------------------
#Cuts out all UTXOs in a mary style UTXO JSON that are not the given UTXO hash ($2)
#The given UTXO hash can be multiple UTXO hashes with the separator |
filterFor_UTXO()
{
local inJSON=${1}
local searchUTXO=${2}
local outJSON="{}"

IFS='|' read -ra searchUTXOs <<< "${searchUTXO}" #split the given utxos on the | separator
local noOfSearchUTXOs=${#searchUTXOs[@]}
for (( tmpCnt=0; tmpCnt<${noOfSearchUTXOs}; tmpCnt++ ))
do
	local utxoHashIndex=${searchUTXOs[${tmpCnt}]} #the current hashindex
	local sourceUTXO=$(jq -r .\"${utxoHashIndex}\" <<< ${inJSON}) #the hashindex of the source json
	if [[ "${sourceUTXO}" != "null" ]]; then local outJSON=$( jq ". += { \"${utxoHashIndex}\": ${sourceUTXO} }" <<< ${outJSON}); fi
done
echo "${outJSON}"
}
#-------------------------------------------------------


#-------------------------------------------------------
#Convert PolicyID|assetName TokenName into Bech32 format "token1....."
convert_tokenName2BECH() {
        #${1} = policyID | assetName as a HEX String
	#${2} = assetName in ASCII or empty
local tmp_policyID=$(trimString "${1}") #make sure there are not spaces before and after
local tmp_assetName=$(trimString "${2}")
if [[ ! "${tmp_assetName}" == "" ]]; then local tmp_assetName=$(echo -n "${tmp_assetName}" | xxd -b -ps -c 80 | tr -d '\n'); fi

#echo -n "${tmp_policyID}${tmp_assetName}" | xxd -r -ps | b2sum -l 160 -b | cut -d' ' -f 1 | ${bech32_bin} asset
echo -n "${tmp_policyID}${tmp_assetName}" | xxd -r -ps | b2sum -l 160 -b | awk {'print $1'} | ${bech32_bin} asset
}
#-------------------------------------------------------


#-------------------------------------------------------
#Convert ASCII assetName into HEX assetName
convert_assetNameASCII2HEX() {
echo -n "${1}" | xxd -b -ps -c 80 | tr -d '\n'
}
#-------------------------------------------------------


#-------------------------------------------------------
#Convert HEX assetName into ASCII assetName
convert_assetNameHEX2ASCII() {
echo -n "${1}" | xxd -r -ps
}
#-------------------------------------------------------


#-------------------------------------------------------
#Convert HEX assetName into ASCII assetName. If possible return ".assetName" else return just the HEX assetName without a leading point'.'
convert_assetNameHEX2ASCII_ifpossible() {
if [[ "${1}" =~ ^(..){0,}00(.+)?$ ]]; then echo -n "${1}"; #if the given hexstring contains a nullbyte -> return the hexstring
else
     local tmpAssetName=$(echo -n "${1}" | xxd -r -ps)
     if [[ "${tmpAssetName}" == "${tmpAssetName//[^[:alnum:]]/}" ]]; then echo -n ".${tmpAssetName}"; else echo -n "${1}"; fi
fi
}
#-------------------------------------------------------


#-------------------------------------------------------
#Calculate the minimum UTXO value that has to be sent depending on the assets and the minUTXO protocol-parameters
calc_minOutUTXOcli() {
        #${1} = protocol-parameters(json format) content
        #${2} = tx-out string

local allParameters=( "$@" )
local protocolParam=${allParameters[0]}
local txOut=${allParameters[1]}
###local multiAsset=$(echo ${2} | cut -d'+' -f 3-) #split at the + marks and only keep assets
tmp=$(${cardanocli} ${cliEra} transaction calculate-min-required-utxo --protocol-params-file <(echo "${protocolParam}") --tx-out "${txOut}" 2> /dev/stdout)

if [[ $? -ne 0 ]]; then echo -e "\e[35mERROR - Can't calculate minValue for the given tx-out string:\n${txOut}\n\nError: ${tmp}\e[0m" > /dev/stderr; exit 1; fi
echo ${tmp} | cut -d' ' -f 2 #Output is "Lovelace xxxxxx", so return the second part
}
#-------------------------------------------------------


#-------------------------------------------------------
#Calculate the minimum UTXO value that has to be sent depending on the assets and the protocol-parameters
calc_minOutUTXO() {

        #${1} = protocol-parameters(json format) content
        #${2} = tx-out string

local protocolParam=${1}
IFS='+' read -ra asset_entry <<< "${2}" #split the tx-out string into address, lovelaces, assets (read it into asset_entry array)

#protocol version major
#7=babbage, 5+6=alonzo, 4=mary, 3=allegra, 2=shelley, 0+1=byron
local protocolVersionMajor=$(jq -r ".protocolVersion.major | select (.!=null)" <<< ${protocolParam})


### switch the method of the minOutUTXO calculation depending on the current era, starting with protocolVersionMajor>=7 (babbage)
if [[ ${protocolVersionMajor} -ge 7 ]]; then #7=Babbage, 9+10=Conway ..., new since babbage: CIP-0055 -> minOutUTXO depends on the cbor bytes length

	#chain constants for babbage
	local constantOverhead=160 #constantOverhead=160 bytes set for babbage-era, 158 for mary/alonzo transactions in babbage era

	#Get the destination address in hex format as well as the amount of lovelaces
	#local toAddrHex=$(echo -n "${asset_entry[0]}" | ${bech32_bin} | tr -d '\n')   #this would only work for bech32-shelley addresses
	local toAddrHex=$(${cardanocli} address info --address ${asset_entry[0]} 2> /dev/null | jq -r .base16 | tr -d '\n') #this works for bech32-shelley and even base58-byron addresses
	local toLovelaces=${asset_entry[1]}

	if [[ ${#asset_entry[@]} -eq 2 ]]; then #only lovelaces, no assets

		case ${nodeEraParam,,} in

			*"babbage"* | *"conway"* ) #Build the tx-out cbor in babbage-tx format with maps
				local cborStr="" #setup a clear new cbor string variable, will hold the tx-out cbor part
				local cborStr+=$(to_cbor "map" 2) #map 2
				local cborStr+=$(to_cbor "unsigned" 0) #unsigned 0
				local cborStr+=$(to_cbor "bytes" "${toAddrHex}") #toAddr in hex
				local cborStr+=$(to_cbor "unsigned" 1) #unsigned 1
				local cborStr+=$(to_cbor "unsigned" ${toLovelaces}) #amount of lovelaces
				;;

			* ) #Build the tx-out cbor in alonzo/shelley format with array
				local cborStr="" #setup a clear new cbor string variable, will hold the tx-out cbor part
				local cborStr+=$(to_cbor "array" 2) #array 2
				local cborStr+=$(to_cbor "bytes" "${toAddrHex}") #toAddr in hex
				local cborStr+=$(to_cbor "unsigned" ${toLovelaces}) #amount of lovelaces
				;;

		esac


	else #assets involved

		local idx=2
		local pidCollector=""    #holds the list of individual policyIDs
		local assetsCollector="" #holds the list of individual assetHases (policyID+assetName)

	        while [[ ${#asset_entry[@]} -gt ${idx} ]]; do #step thru all given assets

	          #separate assetamount from asset_hash(policyID.assetName)
	          IFS=' ' read -ra asset <<< "${asset_entry[${idx}]}"
	          local asset_amount=${asset[0]}
	          local asset_hash=${asset[1]}

	          #split asset_hash_name into policyID and assetName(hex)
	          local asset_hash_policy=${asset_hash:0:56}
	          local asset_hash_hexname=${asset_hash:57}

		  #collect the entries in individual lists to sort them later
		  local pidCollector+="${asset_hash_policy}\n"
		  local assetsCollector+="amount=${asset_amount} pid=${asset_hash_policy} name=${asset_hash_hexname}\n"

		  local idx=$(( ${idx} + 1 ))

		done

		#only keep unique pids and get the number of each individual pid, also get the number of total individual pids
		local pidCollector=$(echo -ne "${pidCollector}" | sort | uniq -c)
		local numPIDs=$(wc -l <<< "${pidCollector}")


		case ${nodeEraParam,,} in

			*"babbage"* | *"conway"* ) #Build the tx-out cbor in babbage-tx format with maps

				local cborStr="" #setup a clear new cbor string variable, will hold the tx-out cbor part
				local cborStr+=$(to_cbor "map" 2) #map 2
				local cborStr+=$(to_cbor "unsigned" 0) #unsigned 0
				local cborStr+=$(to_cbor "bytes" "${toAddrHex}") #toAddr in hex
				local cborStr+=$(to_cbor "unsigned" 1) #unsigned 1
				;;

			* ) #Build the tx-out cbor in alonzo/shelley format with array
				local cborStr="" #setup a clear new cbor string variable, will hold the tx-out cbor part
				local cborStr+=$(to_cbor "array" 2) #array 2
				local cborStr+=$(to_cbor "bytes" "${toAddrHex}") #toAddr in hex
				;;

		esac

		local cborStr+=$(to_cbor "array" 2) #array 2 -> first entry value of lovelaces, second is maps of assets
		local cborStr+=$(to_cbor "unsigned" ${toLovelaces}) #amount of lovelaces

		local cborStr+=$(to_cbor "map" ${numPIDs}) #map x -> number of individual PIDs

		#process each individual pid
		while read pidLine ; do
			local numOfAssets=$(awk {'print $1'} <<< ${pidLine})
			local pidHash=$(awk {'print $2'} <<< ${pidLine})

			local cborStr+=$(to_cbor "bytes" "${pidHash}") #asset pid as byteArray
			local cborStr+=$(to_cbor "map" "${numOfAssets}") #map for number of asset with that pid

			#process each individual asset
			while read assetLine ; do
				local tmpAssetAmount=$(awk {'print $1'} <<< ${assetLine}); local tmpAssetAmount=${tmpAssetAmount:7}
				local tmpAssetHexName=$(awk {'print $3'} <<< ${assetLine}); local tmpAssetHexName=${tmpAssetHexName:5}

					local cborStr+=$(to_cbor "bytes" "${tmpAssetHexName}") #asset name as byteArray
					local cborStr+=$(to_cbor "unsigned" ${tmpAssetAmount}) #amount of this asset

			done < <(echo -e "${assetsCollector}" | grep "pid=${pidHash}")

		done <<< "${pidCollector}"

	fi #only lovelaces or lovelaces + assets

	#We need to get the CostPerByte. This is reported via the protocol-parameters in the utxoCostPerByte or utxoCostPerWord parameter
	local utxoCostPerByte=$(jq -r ".utxoCostPerByte // .coinsPerUTxOByte // \"\"" <<< ${protocolParam}); #babbage
	if [[ "${utxoCostPerByte}" == "" ]]; then #if the parameter is not present, use the utxoCostPerWord one. a word is 8 bytes
						local utxoCostPerWord=$(jq -r ".utxoCostPerWord // \"\"" <<< ${protocolParam});
						local utxoCostPerByte=$(( ${utxoCostPerWord} / 8 ))
	fi

	#cborLength is length of cborStr / 2 because of the hexchars (2 chars -> 1 byte)
	minOutUTXO=$(( ( (${#cborStr} / 2) + ${constantOverhead} ) * ${utxoCostPerByte} ))
	echo ${minOutUTXO}
	exit #calculation for babbage is done, leave the function
fi

### if we are here, it was not a babbage or conway style calculation, so lets do it for the other eras
### do the calculation for shelley, allegra, mary, alonzo

#chain constants, based on the specifications: https://hydra.iohk.io/build/5949624/download/1/shelley-ma.pdf
local k0=0                              #coinSize=0 in mary-era, 2 in alonzo-era
local k1=6
local k2=12                             #assetSize=12
local k3=28                             #pidSize=28
local k4=8                              #word=8 bytes
local utxoEntrySizeWithoutVal=27        #6+txOutLenNoVal(14)+txInLen(7)
local adaOnlyUTxOSize=$((${utxoEntrySizeWithoutVal} + ${k0}))

local minUTXOValue=$(jq -r ".minUTxOValue | select (.!=null)" <<< ${protocolParam}); #shelley, allegra, mary
local utxoCostPerWord=$(jq -r ".utxoCostPerWord | select (.!=null)" <<< ${protocolParam}); #alonzo

### switch the method of the minOutUTXO calculation depending on the current era
if [[ ${protocolVersionMajor} -ge 5 ]]; then #5+6=Alonzo, new since alonzo: the k0 parameter increases by 2 compared to the mary one
	adaOnlyUTxOSize=$(( adaOnlyUTxOSize + 2 )); #2 more starting with the alonzo era
	minUTXOValue=$(( ${utxoCostPerWord} * ${adaOnlyUTxOSize} ));
fi

### from here on, the calculation is the same for shelley, allegra, mary, alonzo

#preload it with the minUTXOValue from the parameters, will be overwritten at the end if costs are higher
local minOutUTXO=${minUTXOValue}

if [[ ${#asset_entry[@]} -gt 2 ]]; then #contains assets, do calculations. otherwise leave it at the default value
        local idx=2
	local pidCollector=""    #holds the list of individual policyIDs
	local assetsCollector="" #holds the list of individual assetHases (policyID+assetName)
	local nameCollector=""   #holds the list of individual assetNames(hex format)

        while [[ ${#asset_entry[@]} -gt ${idx} ]]; do

          #separate assetamount from asset_hash(policyID.assetName)
          IFS=' ' read -ra asset <<< "${asset_entry[${idx}]}"
          local asset_hash=${asset[1]}

          #split asset_hash_name into policyID and assetName(hex)
          local asset_hash_policy=${asset_hash:0:56}
          local asset_hash_hexname=${asset_hash:57}

	  #collect the entries in individual lists to sort them later
	  local pidCollector+="${asset_hash_policy}\n"
	  local assetsCollector+="${asset_hash_policy}${asset_hash_hexname}\n"
	  if [[ ! "${asset_hash_hexname}" == "" ]]; then local nameCollector+="${asset_hash_hexname}\n"; fi

          local idx=$(( ${idx} + 1 ))

        done

       #get uniq entries
       local numPIDs=$(echo -ne "${pidCollector}" | sort | uniq | wc -l)
       local numAssets=$(echo -ne "${assetsCollector}" | sort | uniq | wc -l)

       #get sumAssetNameLengths
       local sumAssetNameLengths=$(( $(echo -ne "${nameCollector}" | sort | uniq | tr -d '\n' | wc -c) / 2 )) #divide consolidated hexstringlength by 2 because 2 hex chars -> 1 byte

       #calc the utxoWords
       local roundupBytesToWords=$(bc <<< "scale=0; ( ${numAssets}*${k2} + ${sumAssetNameLengths} + ${numPIDs}*${k3} + (${k4}-1) ) / ${k4}")
       local tokenBundleSize=$(( ${k1} + ${roundupBytesToWords} ))

       #calc minAda needed with assets
       local minAda=$(( $(bc <<< "scale=0; ${minUTXOValue} / ${adaOnlyUTxOSize}") * ( ${utxoEntrySizeWithoutVal} + ${tokenBundleSize} ) ))

       #if minAda is higher than the bottom minUTXOValue, set the output to the higher value (max function)
       if [[ ${minAda} -gt ${minUTXOValue} ]]; then minOutUTXO=${minAda}; fi

       minOutUTXO=${minAda};

fi

echo ${minOutUTXO} #return the minOutUTXO value for the txOut-String with or without assets
}
#-------------------------------------------------------



#-------------------------------------------------------
#queryLight_UTXO function
#
# makes an online query via koios API and returns and output like a cli utxo query
#
queryLight_UTXO() { #${1} = address to query

	local addr=${1}
        local errorcnt=0
        local error=-1
        while [[ ${errorcnt} -lt 5 && ${error} -ne 0 ]]; do #try a maximum of 5 times to request the information via koios API
		error=0
		response=$(curl -sL -m 120 -X POST -w "---spo-scripts---%{http_code}" "${koiosAPI}/address_utxos?select=tx_hash,tx_index,value,asset_list" -H "${koiosAuthorizationHeader}" -H "Accept: application/json"  -H "Content-Type: application/json" -d "{\"_addresses\":[\"${addr}\"], \"_extended\": true}" 2> /dev/null)
		if [ $? -ne 0 ]; then error=1; fi;
                errorcnt=$(( ${errorcnt} + 1 ))
	done
	if [[ ${error} -ne 0 ]]; then echo -e "Query of the Koios-API via curl failed, tried 5 times."; exit 1; fi; #curl query failed

	if [[ "${response}" =~ (.*)---spo-scripts---([0-9]*)* ]]; then #split the response string into JSON content and the HTTP-ResponseCode
		local responseJSON="${BASH_REMATCH[1]}"
		local responseCode="${BASH_REMATCH[2]}"
	else
		echo -e "Query of the Koios-API via curl failed. Could not separate Content and ResponseCode."; exit 1; #curl query failed
	fi

	#Check the responseCode
	case ${responseCode} in
		"200" ) ;; #all good, continue
		"504" ) echo -e "HTTP Response code: ${responseCode} - Koios API took too long to query the request. You might use the normal 'online' mode instead."; exit 1;; #exit with a failure and the http response code
		* )     echo -e "HTTP Response code: ${responseCode}"; exit 1; #exit with a failure and the http response code
        esac;
	utxoRet=$(jq -r "(\"TxHash TxIx Amount<cr>---<cr>\"), ( . | sort_by(.tx_hash) | .[] | \"\(.tx_hash) \(.tx_index) \(.value) lovelace \", (.asset_list[] | \"+ \(.quantity) \(.policy_id).\(.asset_name) \"), \"<cr>\")" <<< "${responseJSON}" 2> /dev/null)
	if [ $? -ne 0 ]; then echo -e "Query via Koios-API (${koiosAPI}) failed, not a JSON response."; exit 1; fi; #reponse is not a json file
	utxoRet=$(tr -d '\n' <<< "${utxoRet}" | sed 's/<cr>/\n/g' | sed 's/\. / /g') #reformat the utxo output so it is like the cli output

	#return the utxo
	printf "${utxoRet}"
	unset utxoRet response responseCode responseJSON addr error errorcnt

}
#-------------------------------------------------------



#-------------------------------------------------------
#queryLight_stakeAddressInfo function
#
# makes an online query via koios API and returns and output like a cli stake-address-info query
#
queryLight_stakeAddressInfo() { #${1} = address to query

	local addr=${1}
        local errorcnt=0
        local error=-1
        while [[ ${errorcnt} -lt 5 && ${error} -ne 0 ]]; do #try a maximum of 5 times to request the information via koios API
		error=0
		response=$(curl -sL -m 30 -X POST -w "---spo-scripts---%{http_code}" "${koiosAPI}/account_info" -H "${koiosAuthorizationHeader}" -H "Accept: application/json" -H "Content-Type: application/json" -d "{\"_stake_addresses\":[\"${addr}\"]}" 2> /dev/null)
		if [ $? -ne 0 ]; then error=1; fi;
                errorcnt=$(( ${errorcnt} + 1 ))
	done
	if [[ ${error} -ne 0 ]]; then echo -e "Query of the Koios-API via curl failed, tried 5 times."; exit 1; fi; #curl query failed

	#Split the response string into JSON content and the HTTP-ResponseCode
	if [[ "${response}" =~ (.*)---spo-scripts---([0-9]*)* ]]; then
		local responseJSON="${BASH_REMATCH[1]}"
		local responseCode="${BASH_REMATCH[2]}"
	else
		echo -e "Query of the Koios-API via curl failed. Could not separate Content and ResponseCode."; exit 1; #curl query failed
	fi

	#Check the responseCode
	case ${responseCode} in
		"200" ) ;; #all good, continue
		* )     echo -e "HTTP Response code: ${responseCode}"; exit 1; #exit with a failure and the http response code
        esac;

	jsonRet=$(jq -r . <<< "${responseJSON}" 2> /dev/null)
	if [ $? -ne 0 ]; then echo -e "Query via Koios-API (${koiosAPI}) failed, not a JSON response."; exit 1; fi; #reponse is not a json file

	#check if the stakeAddress is registered, if not, return an empty array
	if [[ $(jq -r ".[0].status" <<< "${responseJSON}" 2> /dev/null) != "registered" ]]; then
		printf "[]"; #stakeAddress not registered on chain, return an empty array
		else
#		local delegation=$(jq -r ".[0].delegated_pool" <<< "${responseJSON}" 2> /dev/null)
#		local rewardAccountBalance=$(jq -r ".[0].rewards_available" <<< "${responseJSON}" 2> /dev/null)
		local delegation; local rewardAccountBalance; local delegationDeposit; #define local variables so we can read it in one go with the next jq command
		{ read delegation; read rewardAccountBalance; read delegationDeposit; } <<< $(jq -r ".[0].delegated_pool // \"null\", .[0].rewards_available // \"null\", .[0].deposit // \"null\"" <<< "${responseJSON}" 2> /dev/null)

		#deposit value, always 2000000 lovelaces until conway
#		local delegationDeposit=$(jq -r ".[0].deposit" <<< "${responseJSON}" 2> /dev/null)
		if [[ ${delegationDeposit} == null ]]; then delegationDeposit=2000000; fi

		jsonRet="[ { \"address\": \"${addr}\", \"stakeDelegation\": \"${delegation}\", \"delegationDeposit\": ${delegationDeposit}, \"rewardAccountBalance\": ${rewardAccountBalance} } ]" #compose a json like the cli output
		#return the composed json
		printf "${jsonRet}"
	fi

	unset jsonRet response responseCode responseJSON addr error errorcnt

}
#-------------------------------------------------------



#-------------------------------------------------------
#submitLight function
#
# submits a given TxFile via koios API and returns the corresponding txID
#
submitLight() { #${1} = path to txFile

	local txFile=${1}

	cborStr=$(jq -r ".cborHex" < "${txFile}" 2> /dev/null)
	if [ $? -ne 0 ]; then echo -e "Submit via Koios-API (${koiosAPI}) failed, could not read the 'cborHex' from '${txFile}'."; exit 1; fi; #jq readout failed

        local errorcnt=0
        local error=-1
        while [[ ${errorcnt} -lt 5 && ${error} -ne 0 ]]; do #try a maximum of 5 times to submit via koios API
		error=0
		response=$(xxd -p -r <<< "${cborStr}" | curl -sL -m 120 -X POST -w "---spo-scripts---%{http_code}" -H "${koiosAuthorizationHeader}" -H "Content-Type: application/cbor" --data-binary @- "${koiosAPI}/submittx" 2> /dev/null)
		if [ $? -ne 0 ]; then error=1; fi;
                errorcnt=$(( ${errorcnt} + 1 ))
	done
	if [[ ${error} -ne 0 ]]; then echo -e "Submit to the Koios-API via curl failed, tried 5 times."; exit 1; fi; #curl call failed

	if [[ "${response}" =~ (.*)---spo-scripts---([0-9]*)* ]]; then #split the response string into JSON content and the HTTP-ResponseCode
		local responseTxID="${BASH_REMATCH[1]}"
		local responseCode="${BASH_REMATCH[2]}"
	else
		echo -e "Submit to the Koios-API via curl failed. Could not separate Content and ResponseCode."; exit 1; #curl call failed
	fi

	#Check the responseCode
	case ${responseCode} in
		"202" ) ;; #all good, continue
		"400" ) echo -e "HTTP Response code: ${responseCode} - Koios API reported back an error:\n${responseTxID}\nMaybe you have to wait for the next block - please retry later.\nIf you have issues further on, please report back, thx!"; exit 1;; #exit with a failure and the http response code
		* )     echo -e "HTTP Response code: ${responseCode}"; exit 1; #exit with a failure and the http response code
        esac;

	local txID=${responseTxID//\"/} #remove any quote symbol

	#Check if the responseTxID is actually a valid one
	if [[ "${txID//[![:xdigit:]]}" != "${txID}" || ${#txID} -ne 64 ]]; then #returned txID is not a valid one
		echo -e "Submit via Koios-API (${koiosAPI}) failed, returned TxID is not a valid one.\nI've got back: ${responseTxID}"; exit 1;
	fi;

	#return the txID
	printf "${txID}"
	unset response responseCode responseTxID txID txFile error errorcnt

}
#-------------------------------------------------------



#-------------------------------------------------------
#resolveAdahandle function
#
# this function resolves a given adahandle (cip25, cip68, virtual) into a payment address
#
#	inputs
# 	${1} = name of the adahandle
# 	${2} = name of the variable that should be filled with the resolved address
#
#	outputs
# 	variable '${2}' will be filled with the resolved address
# 	variable 'utxo' will hold the utxo query of a resolved adahandle if possible, so no further query needed in the calling script
resolveAdahandle() {

	#Adahandles will only work in online or light mode, exit with an error if in offline mode
	if ${offlineMode}; then echo -e "\n\e[35mERROR - Adahandles are only supported in online & light mode.\n\e[0m"; exit 1; fi

	#If there is no koiosAPI available for this network, exit with an error
	if [[ "${koiosAPI}" == "" ]]; then echo -e "\n\e[35mERROR - Adahandles are not supported on this network yet.\n\e[0m"; exit 1; fi;

	local adahandle="${1,,}"	#lowercase the incoming adahandle
	local outputVar="${2}" 		#hold the name of the output variable
	local resolvedAddr=""

	#ROOT HANDLES
	#check if its an root adahandle (without a @ char) -> do a lookup for the CIP-25 asset format, if not found do a lookup for the CIP-68 format
	if checkAdaRootHandleFormat "${adahandle}"; then

		assetNameHex=$(convert_assetNameASCII2HEX ${adahandle:1})

		#query classic cip-25 adahandle asset holding address via koios
	        local errorcnt=0
	        local error=-1
		showProcessAnimation "Query Adahandle(CIP-25) into holding address: " &
	        while [[ ${errorcnt} -lt 5 && ${error} -ne 0 ]]; do #try a maximum of 5 times to request the information via koios API
			error=0
			response=$(curl -sL -m 30 -X GET -w "---spo-scripts---%{http_code}" "${koiosAPI}/asset_addresses?_asset_policy=${adahandlePolicyID}&_asset_name=${assetNameHex}" -H "${koiosAuthorizationHeader}" -H "Accept: application/json"  -H "Content-Type: application/json" 2> /dev/null)
			if [ $? -ne 0 ]; then error=1; fi;
	                errorcnt=$(( ${errorcnt} + 1 ))
		done
		stopProcessAnimation;
		if [[ ${error} -ne 0 ]]; then echo -e "\n\e[35mQuery of the Koios-API via curl failed, tried 5 times.\n\e[0m"; exit 1; fi; #curl query failed

		if [[ "${response}" =~ (.*)---spo-scripts---([0-9]*)* ]]; then #split the response string into JSON content and the HTTP-ResponseCode
			local responseJSON="${BASH_REMATCH[1]}"
			local responseCode="${BASH_REMATCH[2]}"
		else
			echo -e "Query of the Koios-API via curl failed. Could not separate Content and ResponseCode."; exit 1; #curl query failed
		fi

		#check the responseCode
		case ${responseCode} in
			"200" ) ;; #all good, continue
			* )     echo -e "\n\e[35mERROR - HTTP Response code: ${responseCode}\n\e[0m"; exit 1;; #exit with a failure and the http response code
	        esac;
		tmpCheck=$(jq -r . <<< "${responseJSON}" 2> /dev/null)
		if [ $? -ne 0 ]; then echo -e "\n\e[35mQuery via Koios-API (${koiosAPI}) failed, not a JSON response.\n\e[0m"; exit 1; fi; #reponse is not a json file

		#check if the received json only contains one entry in the array(=resolved), if not -> continue to check the cip-68 format
		if [[ $(jq ". | length" 2> /dev/null <<< ${responseJSON}) -ne 1 ]]; then

			assetNameHex="000de140${assetNameHex}"

			#query CIP-68 adahandle asset holding address via koios
			errorcnt=0;error=-1;
			showProcessAnimation "Query Adahandle(CIP-68) into holding address: " &
		        while [[ ${errorcnt} -lt 5 && ${error} -ne 0 ]]; do #try a maximum of 5 times to request the information via koios API
				error=0
				response=$(curl -sL -m 30 -X GET -w "---spo-scripts---%{http_code}" "${koiosAPI}/asset_addresses?_asset_policy=${adahandlePolicyID}&_asset_name=${assetNameHex}" -H "${koiosAuthorizationHeader}" -H "Accept: application/json"  -H "Content-Type: application/json" 2> /dev/null)
				if [ $? -ne 0 ]; then error=1; fi;
		                errorcnt=$(( ${errorcnt} + 1 ))
			done
			stopProcessAnimation;
			if [[ ${error} -ne 0 ]]; then echo -e "\n\e[35mERROR - Query of the Koios-API via curl failed, tried 5 times.\n\e[0m"; exit 1; fi; #curl query failed

			if [[ "${response}" =~ (.*)---spo-scripts---([0-9]*)* ]]; then #split the response string into JSON content and the HTTP-ResponseCode
				responseJSON="${BASH_REMATCH[1]}"
				responseCode="${BASH_REMATCH[2]}"
			else
				echo -e "Query of the Koios-API via curl failed. Could not separate Content and ResponseCode."; exit 1; #curl query failed
			fi

			#check the responseCode
			case ${responseCode} in
				"200" ) ;; #all good, continue
				* )     echo -e "\n\e[35mERROR - HTTP Response code: ${responseCode}\n\e[0m"; exit 1;; #exit with a failure and the http response code
		        esac;
			tmpCheck=$(jq -r . <<< "${responseJSON}" 2> /dev/null)
			if [ $? -ne 0 ]; then echo -e "\n\e[35mERROR - Query via Koios-API (${koiosAPI}) failed, not a JSON response.\n\e[0m"; exit 1; fi; #reponse is not a json file

			#check if the received json only contains one entry in the array
			if [[ $(jq ". | length" 2> /dev/null <<< ${responseJSON}) -ne 1 ]]; then echo -e "\n\e[33mCould not resolve Adahandle to an address.\n\e[0m"; exit 1; fi

		fi

		#we have a valid responseJSON from a CIP-25 or CIP-68 request
		resolvedAddr=$(jq -r ".[0].payment_address" <<< ${responseJSON} 2> /dev/null)

		#lets check if the resolved address is actually a valid payment address
		local typeOfAddr=$(get_addressType "${resolvedAddr}");
		if [[ ${typeOfAddr} != ${addrTypePayment} ]]; then echo -e "\n\e[35mERROR - Resolved address '${resolvedAddr}' is not a valid payment address.\n\e[0m"; exit 1; fi;

		#in fullmode -> check that the node is fully synced, otherwise the query would mabye return a false state
		if [[ ${fullMode} == true && $(get_currentSync) != "synced" ]]; then echo -e "\e[35mError - Node not fully synced or not running, please let your node sync to 100% first !\e[0m\n"; exit 1; fi

		#now lets verify that the adahandle native asset is actually on an utxo of that resolved address
		showProcessAnimation "Verify Adahandle is on resolved address: " &
		case ${workMode} in
			"online") 	utxo=$(${cardanocli} ${cliEra} query utxo --address ${resolvedAddr} 2> /dev/stdout);
					if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${utxo}\e[0m\n"; exit 1; else stopProcessAnimation; fi;;
			"light")  	utxo=$(queryLight_UTXO "${resolvedAddr}");
					if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${utxo}\e[0m\n"; exit 1; else stopProcessAnimation; fi;;
		esac

		#exit with an error if the adahandle is not on the address
		if [[ $(grep "${adahandlePolicyID}.${assetNameHex} " <<< ${utxo} | wc -l) -ne 1 ]]; then echo -e "\n\e[35mERROR - Resolved address '${resolvedAddr}' does not hold the \$adahandle '${adahandle}' !\n\e[0m"; exit 1; fi;

		#ok, we found it
		echo -e "\e[0mFound \$adahandle '${adahandle}' on Address:\e[32m ${resolvedAddr}\e[0m\n"


	#SUBHANDLES/VIRTUALHANDLES
	#check if its a sub-adahandle or a virtual-adahandle (with a @ char) -> do a lookup via the Adahandle-API, verify via utxo check or Koios
	elif checkAdaSubHandleFormat "${adahandle}"; then


					#query virtual subHandle via adahandleAPI
					if [[ "${adahandleAPI}" == "" ]]; then echo -e "\n\e[33mERROR - There is no Adahandle-API available for this network.\n\e[0m"; exit 1; fi

				        local errorcnt=0
				        local error=-1
					showProcessAnimation "Query sub/virtual Adahandle via the Adahandle-API (${adahandleAPI}): " &
				        while [[ ${errorcnt} -lt 5 && ${error} -ne 0 ]]; do #try a maximum of 5 times to request the information via koios API
						error=0
						response=$(curl -sL -m 30 -X GET -w "---spo-scripts---%{http_code}" "${adahandleAPI}/handles/${adahandle:1}"  -H "Accept: application/json"  -H "Content-Type: application/json" 2> /dev/null)
						if [ $? -ne 0 ]; then error=1; fi;
				                errorcnt=$(( ${errorcnt} + 1 ))
					done
					stopProcessAnimation;
					if [[ ${error} -ne 0 ]]; then echo -e "\n\e[35mQuery via Adahandle-API (${adahandleAPI}) failed, tried 5 times.\n\e[0m"; exit 1; fi; #curl query failed

					if [[ "${response}" =~ (.*)---spo-scripts---([0-9]*)* ]]; then #split the response string into JSON content and the HTTP-ResponseCode
						local responseJSON="${BASH_REMATCH[1]}"
						local responseCode="${BASH_REMATCH[2]}"
					else
						echo -e "Query via Adahandle-API via curl failed. Could not separate Content and ResponseCode."; exit 1; #curl query failed
					fi

					#Check the responseCode
					case ${responseCode} in
						"200" ) ;; #all good, continue
						"202" )	echo -e "\n\e[33mAdahandle was found, but the API sync is not on tip with the network status. Please try again later.\n\e[0m"; exit 1;;
						"404" )	echo -e "\n\e[33mAdahandle '${adahandleName}' was not found, cannot resolve it to an address.\n\e[0m"; exit 1;;
						* )	echo -e "\n\e[33m$(jq -r .message <<< ${responseJSON})\nAdahandle-API response code: ${responseCode}";
							echo -e "\nIf you think this is an issue, please report this via the SPO-Scripts Github-Repository https://github.com/gitmachtl/scripts\n\e[0m"; exit 1;;
					esac;

					#query was successful, get the address
                                        resolvedAddr=$(jq -r ".\"resolved_addresses\".ada" <<< ${responseJSON} 2> /dev/null)
					if [ $? -ne 0 ]; then echo -e "\n\e[35mERROR - The received data from the Adahandle-API is not a valid JSON.\n\e[0m"; exit 1; fi;

					#lets check if the resolved address is actually a valid payment address
                                        local typeOfAddr=$(get_addressType "${resolvedAddr}");
					if [[ ${typeOfAddr} != ${addrTypePayment} ]]; then echo -e "\n\e[35mERROR - Resolved address '${resolvedAddr}' is not a valid payment address.\n\e[0m"; exit 1; fi;

					#lets check the resolved address. if its a cip-68 subhandle (starting with hex 000de140) than it lives on an utxo which resolves to the address
					#if its a virtual subhandle (strting with hex 00000000) than the resolved address is within the inline_datum
					#check that the node is fully synced, otherwise the query would mabye return a false state
					assetNameHex=$(jq -r ".hex" <<< ${responseJSON});
					case "${assetNameHex}" in

						"000de140"* ) #its a cip-68 subhandle, lets verify it is actually on the resolved address

							#in fullmode -> check that the node is fully synced, otherwise the query would mabye return a false state
							if [[ ${fullMode} == true && $(get_currentSync) != "synced" ]]; then echo -e "\e[35mError - Node not fully synced or not running, please let your node sync to 100% first !\e[0m\n"; exit 1; fi

							#now lets verify that the adahandle native asset is actually on an utxo of that resolved address
		                                        showProcessAnimation "Verify Adahandle is on resolved address: " &
							case ${workMode} in
								"online") 	utxo=$(${cardanocli} ${cliEra} query utxo --address ${resolvedAddr} 2> /dev/stdout);
										if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${utxo}\e[0m\n"; exit 1; else stopProcessAnimation; fi;;
								"light")  	utxo=$(queryLight_UTXO "${resolvedAddr}");
										if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${utxo}\e[0m\n"; exit 1; else stopProcessAnimation; fi;;
							esac

							#exit with an error if the adahandle is not on the address
							if [[ $(grep "${adahandlePolicyID}.${assetNameHex} " <<< ${utxo} | wc -l) -ne 1 ]]; then echo -e "\n\e[35mERROR - Resolved address '${resolvedAddr}' does not hold the \$adahandle '${adahandle}' !\n\e[0m"; exit 1; fi;

							#ok, we found it
							echo -e "\e[0mFound \$subhandle '${adahandle}' on Address:\e[32m ${resolvedAddr}\e[0m\n"
							;;

						"00000000"* ) #its a virtual subhandle, lets check a second opinion by doing a koios api query too

		                                        #query cip-68 adahandle asset utxo, and check the inline_datum
							errorcnt=0;error=-1;
		                                        showProcessAnimation "Query Virtualhandle into holding address: " &
						        while [[ ${errorcnt} -lt 5 && ${error} -ne 0 ]]; do #try a maximum of 5 times to request the information via koios API
								error=0
								response=$(curl -sL -m 30 -X POST -w "---spo-scripts---%{http_code}" "${koiosAPI}/asset_utxos?select=inline_datum" -H "${koiosAuthorizationHeader}" -H "Accept: application/json"  -H "Content-Type: application/json" -d "{\"_asset_list\":[[\"${adahandlePolicyID}\",\"${assetNameHex}\"]],\"_extended\":true}" 2> /dev/null)
								if [ $? -ne 0 ]; then error=1; fi;
						                errorcnt=$(( ${errorcnt} + 1 ))
							done
							stopProcessAnimation;
							if [[ ${error} -ne 0 ]]; then echo -e "\n\e[35mERROR - Query of the Koios-API via curl failed, tried 5 times.\n\e[0m"; exit 1; fi; #curl query failed

							if [[ "${response}" =~ (.*)---spo-scripts---([0-9]*)* ]]; then #split the response string into JSON content and the HTTP-ResponseCode
								responseJSON="${BASH_REMATCH[1]}"
								responseCode="${BASH_REMATCH[2]}"
							else
								echo -e "Query of the Koios-API via curl failed. Could not separate Content and ResponseCode."; exit 1; #curl query failed
							fi

							#check the responseCode
							case ${responseCode} in
								"200" ) ;; #all good, continue
								* )     echo -e "\n\e[35mERROR - HTTP Response code: ${responseCode}\n\e[0m"; exit 1;; #exit with a failure and the http response code
						        esac;
							tmpCheck=$(jq -r . <<< "${responseJSON}" 2> /dev/null)
							if [ $? -ne 0 ]; then echo -e "\n\e[35mQuery via Koios-API (${koiosAPI}) failed, not a JSON response.\n\e[0m"; exit 1; fi; #reponse is not a json file

		                                        #check if the received json only contains one entry in the array (will also not be 1 if not a valid json)
		                                        if [[ $(jq ". | length" 2> /dev/null <<< ${responseJSON}) -ne 1 ]]; then echo -e "\n\e[33mCould not query Koios-API about 'asset_utxos'.\n\e[0m"; exit 1; fi

							#lets extract the resolved address from the inline_datum into resolvedAddrCheckHex
							local resolvedAddrCheckHex=$(jq -r ".[0].inline_datum.bytes" <<< ${responseJSON} | sed -n "s/.*7265736f6c7665645f616464726573736573.*\(436164615839.*\)/\1/p" | cut -c 13-126)

						        #get the bech address for mainnet/testnets
							if [[ "${magicparam}" == *"mainnet"* ]]; then local resolvedAddrCheck=$(${bech32_bin} "addr" <<< "${resolvedAddrCheckHex}" 2> /dev/null);
												 else local resolvedAddrCheck=$(${bech32_bin} "addr_test" <<< "${resolvedAddrCheckHex}" 2> /dev/null);
							fi

							#exit with an error if the adahandle is not on the address
							if [[ "${resolvedAddr}" != "${resolvedAddrCheck}" ]]; then
								echo -e "\n\e[35mERROR - Adahandle-API resolved address '${resolvedAddr}' does not\nmatch with Koios-API resolved address '${resolvedAddrCheck}' !\n\e[0m"; exit 1; fi;

							#ok, we found it
							echo -e "\e[0mThis \e[33mvirtual\e[0m \$adahandle '${adahandle}' resolves to Address:\e[32m ${resolvedAddr}\n\e[0m"
							;;


					esac

	else echo -e "\n\e[35mERROR - Thats strange, you should not have landed here with the Adahandle '${adahandle}'. Please report this issue, thx !\n\e[0m"; exit 1;

	fi #roothandle or subhandle


#RESOLVED - exit the function and give back the resolved address to the given variable name
printf -v ${outputVar} "%s" "${resolvedAddr}"

unset outputVar error errorcnt response responseCode responseJSON resolvedAddr resolvedAddrCheck resolvedAddrCheckHex typeOfAddr tmpCheck
}
#-------------------------------------------------------



#-------------------------------------------------------
#to_cbor function
#
# converts different majortypes and there values into a cborHexString
#
to_cbor() {

        # ${1} type: unsigned, negative, bytes, string, array, map, tag
        # ${2} value: unsigned int value or hexstring for bytes

        local type=${1}
        local value="${2}"

        # majortypes
        # unsigned      000x|xxxx       majortype 0	not limited, but above 18446744073709551615 (2^64), the numbers are represented via tag2 + bytearray
        # bytes         010x|xxxx       majortype 2     limited to max. 65535 here
        # array         100x|xxxx       majortype 4     limited to max. 65535 here
        # map           101x|xxxx       majortype 5     limited to max. 65535 here

	# extras - not used yet but implemented for the future
	# negative	001x|xxxx	majortype 1	not limited, but below -18446744073709551616 (-2^64 -1), the numbers are represented via tag3 + bytearray
	# string	011x|xxxx	majortype 3	limited to max. 65535 chars
        # tag           110x|xxxx       majortype 6     limited to max. 65535 here


case ${type} in

	#unsigned - input is an unsigned integer, range is selected via a bc query because bash can't handle big numbers
        unsigned )      if [[ $(bc <<< "${value} < 24") -eq 1 ]]; then printf -v cbor "%02x" $((10#${value})) #1byte total value below 24
                        elif [[ $(bc <<< "${value} < 256") -eq 1 ]]; then printf -v cbor "%04x" $((0x1800 + 10#${value})) #2bytes total: first 0x1800 + 1 lower byte value
                        elif [[ $(bc <<< "${value} < 65536") -eq 1 ]]; then printf -v cbor "%06x" $((0x190000 + 10#${value})) #3bytes total: first 0x190000 + 2 lowerbytes value
                        elif [[ $(bc <<< "${value} < 4294967296") -eq 1 ]]; then printf -v cbor "%10x" $((0x1A00000000 + 10#${value})) #5bytes total: 0x1A00000000 + 4 lower bytes value
                        elif [[ $(bc <<< "${value} < 18446744073709551616") -eq 1 ]]; then local tmp="00$(bc <<< "obase=16;ibase=10;${value}+498062089990157893632")"; cbor="${tmp: -18}" #9bytes total: first 0x1B0000000000000000 + 8 lower bytes value
			#if value does not fit into an 8byte unsigned integer, the cbor representation is tag2(pos.bignum)+bytearray of the value
			else local cbor=$(to_cbor "tag" 2); local tmp="00$(bc <<< "obase=16;ibase=10;${value}")"; tmp=${tmp: -$(( (${#tmp}-1)/2*2 ))}; local cbor+=$(to_cbor "bytes" ${tmp}) #fancy calc to get a leading zero in the hex array if needed
                        fi
                        ;;

	#bytestring - input is a hexstring
        bytes )         local bytesLength=$(( ${#value} / 2 ))  #bytesLength is length of value /2 because of hex encoding (2chars -> 1byte)
                        if [[ ${bytesLength} -lt 24 ]]; then printf -v cbor "%02x${value}" $((0x40 + 10#${bytesLength})) #1byte total 0x40 + lower part value & bytearrayitself
                        elif [[ ${bytesLength} -lt 256 ]]; then printf -v cbor "%04x${value}" $((0x5800 + 10#${bytesLength})) #2bytes total: first 0x4000 + 0x1800 + 1 lower byte value & bytearrayitself
                        elif [[ ${bytesLength} -lt 65536 ]]; then printf -v cbor "%06x${value}" $((0x590000 + 10#${bytesLength})) #3bytes total: first 0x400000 + 0x190000 + 2 lower bytes value & bytearrayitself
                        fi
                        ;;

	#array - input is an unsigned integer
        array )         if [[ ${value} -lt 24 ]]; then printf -v cbor "%02x" $((0x80 + 10#${value})) #1byte total 0x80 + lower part value
                        elif [[ ${value} -lt 256 ]]; then printf -v cbor "%04x" $((0x9800 + 10#${value})) #2bytes total: first 0x8000 + 0x1800 & 1 lower byte value
                        elif [[ ${value} -lt 65536 ]]; then printf -v cbor "%06x" $((0x990000 + 10#${value})) #3bytes total: first 0x800000 + 0x190000 & 2 lower bytes value
                        fi
                        ;;

	#map - input is an unsigned integer
        map )           if [[ ${value} -lt 24 ]]; then printf -v cbor "%02x" $((0xA0 + 10#${value})) #1byte total 0xA0 + lower part value
                        elif [[ ${value} -lt 256 ]]; then printf -v cbor "%04x" $((0xB800 + 10#${value})) #2bytes total: first 0xA000 + 0x1800 & 1 lower byte value
                        elif [[ ${value} -lt 65536 ]]; then printf -v cbor "%06x" $((0xB90000 + 10#${value})) #3bytes total: first 0xA00000 + 0x190000 & 2 lower bytes value
                        fi
                        ;;

	###
	### the following types are not used in these scripts yet, but added to have a more complete function for the future
	###

	#negative - input is a negative unsigned integer, range is selected via a bc query because bash can't handle big numbers
        negative )  local value=$(bc <<< "${value//-/} -1") #negative representation in cbor is the neg. number as a pos. number minus 1, so a -500 will be represented as a 499
			if [[ $(bc <<< "${value} < 24") -eq 1 ]]; then printf -v cbor "%02x" $((0x20 + 10#${value})) #1byte total 0x20 value below 24
                        elif [[ $(bc <<< "${value} < 256") -eq 1 ]]; then printf -v cbor "%04x" $((0x3800 + 10#${value})) #2bytes total: first 0x2000 + 0x1800 + 1 lower byte value
                        elif [[ $(bc <<< "${value} < 65536") -eq 1 ]]; then printf -v cbor "%06x" $((0x390000 + 10#${value})) #3bytes total: first 0x200000 + 0x190000 + 2 lowerbytes value
                        elif [[ $(bc <<< "${value} < 4294967296") -eq 1 ]]; then printf -v cbor "%10x" $((0x3A00000000 + 10#${value})) #5bytes total: 0x2000000000 + 0x1A00000000 + 4 lower bytes value
                        elif [[ $(bc <<< "${value} < 18446744073709551616") -eq 1 ]]; then local tmp="00$(bc <<< "obase=16;ibase=10;${value}+1088357900348863545344")"; cbor="${tmp: -18}" #9bytes total: first 0x3B0000000000000000 + 8 lower bytes value
			#if value does not fit into an 8byte unsigned integer, the cbor representation is tag3(neg.bignum)+bytearray of the value
			else local cbor=$(to_cbor "tag" 3); local tmp="00$(bc <<< "obase=16;ibase=10;${value}")"; tmp=${tmp: -$(( (${#tmp}-1)/2*2 ))}; local cbor+=$(to_cbor "bytes" ${tmp}) #fancy calc to get a leading zero in the hex array if needed
                        fi
                        ;;

	#tag - input is an unsigned integer
        tag )           if [[ ${value} -lt 24 ]]; then printf -v cbor "%02x" $((0xC0 + 10#${value})) #1byte total 0xC0 + lower part value
                        elif [[ ${value} -lt 256 ]]; then printf -v cbor "%04x" $((0xD800 + 10#${value})) #2bytes total: first 0xC000 + 0x1800 & 1 lower byte value
                        elif [[ ${value} -lt 65536 ]]; then printf -v cbor "%06x" $((0xD90000 + 10#${value})) #3bytes total: first 0xC00000 + 0x190000 & 2 lower bytes value
                        fi
                        ;;

	#textstring - input is a utf8-string
        string )        local value=$(echo -ne "${value}" | xxd -p -c 65536 | tr -d '\n') #convert the given string into a hexstring and process it further like a bytearray
			local bytesLength=$(( ${#value} / 2 ))  #bytesLength is length of value /2 because of hex encoding (2chars -> 1byte)
                        if [[ ${bytesLength} -lt 24 ]]; then printf -v cbor "%02x${value}" $((0x60 + 10#${bytesLength})) #1byte total 0x60 + lower part value & bytearrayitself
                        elif [[ ${bytesLength} -lt 256 ]]; then printf -v cbor "%04x${value}" $((0x7800 + 10#${bytesLength})) #2bytes total: first 0x6000 + 0x1800 + 1 lower byte value & bytearrayitself
                        elif [[ ${bytesLength} -lt 65536 ]]; then printf -v cbor "%06x${value}" $((0x790000 + 10#${bytesLength})) #3bytes total: first 0x600000 + 0x190000 + 2 lower bytes value & bytearrayitself
                        fi
                        ;;


esac

echo -n "${cbor^^}" #return the cbor in uppercase
}
#-------------------------------------------------------


#-------------------------------------------------------
#int_from_cbor function
#
# decodes an unsigned integer from a given cborHexString
# maximum supported number is a 8 byte long unsigned int
#
int_from_cbor() {

        # ${1} string: cbor encoded hex string starting at the integer position
	# ${2} count: optional number of entry count -> 0 = the number at that position, 1 = the next number, 2 = the number after the next number
	#
	local cborHexString="${1^^}" #convert the given string into an uppercase one
	local entryCnt="${2:- 0}" #number of interations left
	local value="${cborHexString:0:2}" #get the first two chars
	local charLen=0 #number of chars the current number used in the cborHexString


	if [[ "0x${value}" < "0x18" ]]; then printf -v intVal "%d" "0x${cborHexString:0:2}" 2> /dev/null; retCode=$?; charLen=2; #1byte total value below 0x18 (24dec)
	elif [[ "${value}" == "18" ]]; then printf -v intVal "%d" "0x${cborHexString:2:2}" 2> /dev/null; retCode=$?; charLen=4; #2bytes total: first 0x1800 + 1 lower byte value
	elif [[ "${value}" == "19" ]]; then printf -v intVal "%d" "0x${cborHexString:2:4}" 2> /dev/null; retCode=$?; charLen=6; #3bytes total: first 0x190000 + 2 lowerbytes value
	elif [[ "${value}" == "1A" ]]; then printf -v intVal "%d" "0x${cborHexString:2:8}" 2> /dev/null; retCode=$?; charLen=10; #5bytes total: 0x1A00000000 + 4 lower bytes value
	elif [[ "${value}" == "1B" ]]; then printf -v intVal "%d" "0x${cborHexString:2:16}" 2> /dev/null; retCode=$?; charLen=18; #9bytes total: first 0x1B0000000000000000 + 8 lower bytes value
	else local intVal=-1; retCode=1
	fi

	if [[ ${retCode} -eq 0 && ${entryCnt} -eq 0 ]]; then
		echo -n "${intVal}"; exit 0; #no further work to do, return the number
	elif [[ ${retCode} -eq 0 && ${entryCnt} -ne 0 ]]; then
		entryCnt=$(( ${entryCnt} -1 )); tmp=$(int_from_cbor "${cborHexString:${charLen} }" "${entryCnt}"); retCode=$?; echo -n "${tmp}"; exit ${retCode}; #itteration, go to the next number
	else
		 echo -n "${cborHexString}"; exit 1; #an error occured (not a int number), so lets exit with exit code 1 and return the leftover cbor string
	fi

}




#-------------------------------------------------------
#Show Informations about the content in the offlineJSON
showOfflineFileInfo() {
#Displays infos about the content in the offlineJSON
echo -e "\e[0mChecking Content of the offlineFile: \e[32m$(basename ${offlineFile})\e[0m"
echo

if [[ $(jq ".protocol.parameters | length" <<< ${offlineJSON}) -gt 0 ]]; then echo -ne "\e[0mProtocol-Parameters:\e[32m present\e[0m\t"; else echo -ne "\e[0mProtocol-Parameters:\e[35m missing\e[0m\t"; fi

if [[ ! "$(jq -r ".protocol.era" <<< ${offlineJSON})" == null ]]; then echo -e "\e[0m       Protocol-Era:\e[32m $(jq -r ".protocol.era" <<< ${offlineJSON})\e[0m"; else echo -e "\e[0m       Protocol-Era:\e[35m missing\e[0m"; fi

local historyCnt=$(jq -r ".history | length" <<< ${offlineJSON})
echo -e "\e[0m    History-Entries:\e[32m ${historyCnt}\e[0m";

if [[ ${historyCnt} -gt 0 ]]; then echo -e "\e[0m        Last-Action:\e[32m $(jq -r ".history[-1].action" <<< ${offlineJSON}) \e[90m($(jq -r ".history[-1].date" <<< ${offlineJSON}))\e[0m"; fi

local tokenMetaCnt=$(jq -r ".tokenMetaServer | length" <<< ${offlineJSON})
if [[ ${tokenMetaCnt} -gt 0 ]]; then echo -e "\e[0m  TokenMeta-Entries:\e[32m ${tokenMetaCnt}\e[0m"; fi

if ${offlineMode}; then
			echo -ne "\e[0m    Online Versions:"
			local versionTmp=$(jq -r ".general.onlineCLI" <<< ${offlineJSON}); if [[ "${versionTmp}" == null ]]; then versionTmp="-.--.-"; fi; echo -ne "\e[32m cli ${versionTmp}\e[0m"
			local versionTmp=$(jq -r ".general.onlineNODE" <<< ${offlineJSON}); if [[ "${versionTmp}" == null ]]; then versionTmp="-.--.-"; fi; echo -e " /\e[32m node ${versionTmp}\e[0m"
		   else
			echo -ne "\e[0m    Offline Version:"
			local versionTmp=$(jq -r ".general.offlineCLI" <<< ${offlineJSON}); if [[ "${versionTmp}" == null ]]; then versionTmp="-.--.-"; fi; echo -e "\e[32m cli ${versionTmp}\e[0m"
fi

#addresses
echo
local addressCnt=$(jq -r ".address | length" <<< ${offlineJSON})
echo -e "\e[0m    Address-Entries:\e[32m ${addressCnt}\e[0m\t";
for (( tmpCnt=0; tmpCnt<${addressCnt}; tmpCnt++ ))
do
  local addressKey=$(jq -r ".address | keys[${tmpCnt}]" <<< ${offlineJSON})
  local addressName=$(jq -r ".address.\"${addressKey}\".name" <<< ${offlineJSON})
  local addressAmount=$(jq -r ".address.\"${addressKey}\".totalamount" <<< ${offlineJSON}) lovelaces
  addressAmount="$(convertToADA ${addressAmount}) ADA";
  local addressAssetsCnt=$(jq -r ".address.\"${addressKey}\".totalassetscnt" <<< ${offlineJSON})
  if [[ ${addressAssetsCnt} -gt 0 ]]; then addressAmount="${addressAmount} + ${addressAssetsCnt} Asset-Types"; fi
  local addressDate=$(jq -r ".address.\"${addressKey}\".date" <<< ${offlineJSON})
  local addressUsedAsPayment=$(jq -r ".address.\"${addressKey}\".used" <<< ${offlineJSON})
  local addressType=$(jq -r ".address.\"${addressKey}\".type" <<< ${offlineJSON})
  if [[ ${addressUsedAsPayment} == "yes" ]]; then
						addressUsed="used"; if [[ ${addressType} == ${addrTypePayment} ]]; then addressUsed="${addressUsed}, but can receive"; fi;
					     else
						addressUsed="";
					     fi
  echo -e "\n\e[90m\t[$((${tmpCnt}+1))]\t\e[0m${addressName} \e[90m(${addressAmount}, ${addressDate}) \e[35m${addressUsed}\e[0m\n\t   \t\e[90m${addressKey}\e[0m"
done

#dreps
echo
local drepCnt=$(jq -r ".drep | length" <<< ${offlineJSON})
echo -e "\e[0m       DRep-Entries:\e[32m ${drepCnt}\e[0m\t";
for (( tmpCnt=0; tmpCnt<${drepCnt}; tmpCnt++ ))
do
  local Key=$(jq -r ".drep | keys[${tmpCnt}]" <<< ${offlineJSON})
  local drepName=$(jq -r ".drep.\"${Key}\".name" <<< ${offlineJSON})
  local drepDeposit=$(jq -r ".drep.\"${Key}\".deposit // \"\"" <<< ${offlineJSON})
  if [[ ${drepDeposit} != "" ]]; then drepDeposit="Deposit: $(convertToADA ${drepDeposit}) ADA"; else drepDeposit="not registered"; fi
  local drepDate=$(jq -r ".drep.\"${Key}\".date" <<< ${offlineJSON})
  echo -e "\n\e[90m\t[$((${tmpCnt}+1))]\t\e[0m${drepName} \e[90m(${drepDeposit}, ${drepDate})\e[0m\n\t   \t\e[90m${Key}\e[0m"
done

#files
echo
local filesCnt=$(jq -r ".files | length" <<< ${offlineJSON});
echo -e "\e[0m     Files-Attached:\e[32m ${filesCnt}\e[0m"; if [[ ${filesCnt} -gt 0 ]]; then echo; fi
for (( tmpCnt=0; tmpCnt<${filesCnt}; tmpCnt++ ))
do
  local filePath=$(jq -r ".files | keys[${tmpCnt}]" <<< ${offlineJSON})
  local fileDate=$(jq -r ".files.\"${filePath}\".date" <<< ${offlineJSON})
  local fileSize=$(jq -r ".files.\"${filePath}\".size" <<< ${offlineJSON})
  echo -e "\e[90m\t[$((${tmpCnt}+1))]\t\e[0m${filePath} \e[90m(${fileSize} bytes, ${fileDate})\e[0m"
done
echo
local transactionsCnt=$(jq -r ".transactions | length" <<< ${offlineJSON})
echo -e "\e[0mTransactions in Cue:\e[32m ${transactionsCnt}\e[0m\n";
for (( tmpCnt=0; tmpCnt<${transactionsCnt}; tmpCnt++ ))
do
  local transactionType=$(jq -r ".transactions[${tmpCnt}].type" <<< ${offlineJSON})
  local transactionEra=$(jq -r ".transactions[${tmpCnt}].era" <<< ${offlineJSON})
  local transactionDate=$(jq -r ".transactions[${tmpCnt}].date" <<< ${offlineJSON})
  local transactionFromName=$(jq -r ".transactions[${tmpCnt}].fromAddr" <<< ${offlineJSON})
  local transactionFromAddr=$(jq -r ".transactions[${tmpCnt}].sendFromAddr" <<< ${offlineJSON})
  local transactionToName=$(jq -r ".transactions[${tmpCnt}].toAddr" <<< ${offlineJSON})
  local transactionToAddr=$(jq -r ".transactions[${tmpCnt}].sendToAddr" <<< ${offlineJSON})

  case ${transactionType} in
	Transaction|Asset-Minting|Asset-Burning )
			#Normal UTXO Transaction (lovelaces and/or tokens)
			echo -e "\e[90m\t[$((${tmpCnt}+1))]\t\e[0m${transactionType}[${transactionEra}] from '${transactionFromName}' to '${transactionToName}' \e[90m(${transactionDate})"
			echo -e "\t   \t\e[90mfrom ${transactionFromAddr}\n\t   \t\e[90mto ${transactionToAddr}\e[0m"
			;;

        Withdrawal )
                        #Rewards Withdrawal Transaction
			local transactionStakeName=$(jq -r ".transactions[${tmpCnt}].stakeAddr" <<< ${offlineJSON})
			local transactionStakeAddr=$(jq -r ".transactions[${tmpCnt}].stakingAddr" <<< ${offlineJSON})
                        echo -e "\e[90m\t[$((${tmpCnt}+1))]\t\e[0mRewards-Withdrawal[${transactionEra}] from '${transactionStakeName}' to '${transactionToName}', payment via '${transactionFromName}' \e[90m(${transactionDate})"
                        echo -e "\t   \t\e[90mfrom ${transactionStakeAddr}\n\t   \t\e[90mto ${transactionToAddr}\n\t   \t\e[90mpayment via ${transactionFromAddr}\e[0m"
                        ;;

        StakeKeyRegistration|StakeKeyDeRegistration )
                        #StakeKeyRegistration or Deregistration
                        local transactionStakeName=$(jq -r ".transactions[${tmpCnt}].stakeAddr" <<< ${offlineJSON})
                        echo -e "\e[90m\t[$((${tmpCnt}+1))]\t\e[0m${transactionType}[${transactionEra}] for '${transactionStakeName}', payment via '${transactionFromName}' \e[90m(${transactionDate})"
                        echo -e "\t   \t\e[90mpayment via ${transactionFromAddr}\e[0m"
                        ;;

        DelegationCertRegistration|VoteDelegationCertRegistration )
                        #Delegation Certificate Registration
                        local transactionDelegName=$(jq -r ".transactions[${tmpCnt}].delegName" <<< ${offlineJSON})
                        echo -e "\e[90m\t[$((${tmpCnt}+1))]\t\e[0m${transactionType}[${transactionEra}] for '${transactionDelegName}', payment via '${transactionFromName}' \e[90m(${transactionDate})"
                        echo -e "\t   \t\e[90mpayment via ${transactionFromAddr}\e[0m"
                        ;;

        PoolRegistration|PoolReRegistration|PoolRetirement )
                        #Delegation Certificate Registration
                        local poolMetaTicker=$(jq -r ".transactions[${tmpCnt}].poolMetaTicker" <<< ${offlineJSON})
                        echo -e "\e[90m\t[$((${tmpCnt}+1))]\t\e[0m${transactionType}[${transactionEra}] for Pool '${poolMetaTicker}', payment via '${transactionFromName}' \e[90m(${transactionDate})"
                        echo -e "\t   \t\e[90mpayment via ${transactionFromAddr}\e[0m"
                        ;;

        DRepIDRegistration|DRepIDReRegistration|DRepIDRetirement )
                        #DRep ID Certificate Registration/Update/Deregistration
                        local transactionDRepName=$(jq -r ".transactions[${tmpCnt}].drepName" <<< ${offlineJSON})
                        echo -e "\e[90m\t[$((${tmpCnt}+1))]\t\e[0m${transactionType}[${transactionEra}] for '${transactionDRepName}', payment via '${transactionFromName}' \e[90m(${transactionDate})"
                        echo -e "\t   \t\e[90mpayment via ${transactionFromAddr}\e[0m"
                        ;;


	* )		#Unknown Transaction Type !?
			echo -e "\e[90m\t[$((${tmpCnt}+1))]\t\e[35mUnknown transaction type\e[0m"
			;;
  esac

echo
done

}
#-------------------------------------------------------

#-------------------------------------------------------
#Read the current offlineFile into the offlineJSON variable
readOfflineFile() {
if [ -f "${offlineFile}" ]; then
                                offlineJSON=$(jq . ${offlineFile} 2> /dev/null)
                                if [[ $? -ne 0 ]]; then echo -e "\e[35mERROR - '$(basename ${offlineFile})' is not a valid JSON file, please generate a valid offlineJSON first in onlinemode.\e[0m\n"; exit 1; fi
                                if [[ $(trimString "${offlineJSON}") == "" ]]; then echo -e "\e[35mERROR - '$(basename ${offlineFile})' is not a valid JSON file, please generate a valid offlineJSON first in onlinemode.\e[0m\n"; exit 1; fi #nothing in the file
				if [[ ! $(jq ".protocol.parameters | length" <<< ${offlineJSON}) -gt 0 ]]; then echo -e "\e[35mERROR - '$(basename ${offlineFile})' contains no protocol parameters. Please generate a valid offlineJSON first in onlinemode.\e[0m\n"; exit 1; fi
                            else
                                offileJSON=null
                                echo -e "\e[35mERROR - '$(basename ${offlineFile})' is not present, please generate a valid offlineJSON first in onlinemode.\nYou can do so by running \e[33m01_workOffline.sh new\e[0m\n"; exit 1;

fi
}
#-------------------------------------------------------

#-------------------------------------------------------
#Get the hardware-wallet ready, check the cardano-app version
start_HwWallet() {

local onlyForManu=${1^^} #If set, Paramter 1 can limit the function to be only available for the provided Manufacturer (LEDGER or TREZOR)
local minLedgerCardanoAppVersion=${2:-"${minLedgerCardanoAppVersion}"} #Parameter 2 can overwrite the minLedgerCardanoAppVersion
local minTrezorCardanoAppVersion=${3:-"${minTrezorCardanoAppVersion}"} #Parameter 3 can overwrite the minTrezorCardanoAppVersion

if [[ "$(which ${cardanohwcli})" == "" ]]; then echo -e "\n\e[35mError - cardano-hw-cli binary not found, please install it first and set the path to it correct in the 00_common.sh, common.inc or $HOME/.common.inc !\e[0m\n"; exit 1; fi

versionHWCLI=$(${cardanohwcli} version 2> /dev/null |& head -n 1 |& awk {'print $6'})
versionCheck "${minHardwareCliVersion}" "${versionHWCLI}"
if [[ $? -ne 0 ]]; then majorError "Version ERROR - Please use a cardano-hw-cli version ${minHardwareCliVersion} or higher !\nYour version ${versionHWCLI} is no longer supported for security reasons or features, please upgrade - thx."; exit 1; fi

echo -ne "\e[33mPlease connect & unlock your Hardware-Wallet, open the Cardano-App on Ledger-Devices (abort with CTRL+C)\e[0m\n\n\033[2A\n"
local tmp=$(${cardanohwcli} device version 2> /dev/stdout)
local pointStr="....."
until [[ "${tmp}" == *"app version"* && ! "${tmp}" == *"undefined"* ]]; do

	if [[ "${tmp}" == *"General error"* ]]; then tmp="Cardano App not opened?"; fi

	local tmpCnt=6
	while [[ ${tmpCnt} > 0 ]]; do
	tmpCnt=$(( ${tmpCnt} - 1 ))
	echo -ne "\r\e[35m${tmp:0:64} ...\e[0m - retry in ${tmpCnt} secs ${pointStr:${tmpCnt}}\033[K"
	sleep 1
	done
tmp=$(${cardanohwcli} device version 2> /dev/stdout)
done

#Get the current HW-Wallet Manufacturer and the used CardanoApp/Firmware version
local walletManu=$(echo "${tmp}" |& head -n 1 |& awk {'print $1'})
local versionApp=$(echo "${tmp}" |& head -n 1 |& awk {'print $4'})

#Check if the function was set to be only available on a specified manufacturer hw wallet
if [ ! "${onlyForManu}" == "" ]  && [ ! "${onlyForManu}" == "${walletManu^^}" ]; then echo -e "\n\e[35mError - This function is NOT available on this type of Hardware-Wallet, only available on a ${onlyForManu} device at the moment!\e[0m\n"; exit 1; fi

case ${walletManu^^} in

	LEDGER ) #For Ledger Hardware-Wallets
		versionCheck "${minLedgerCardanoAppVersion}" "${versionApp}"
		if [[ $? -ne 0 ]]; then echo -e "\n\n\e[35mVersion ERROR - Please use Cardano App version ${minLedgerCardanoAppVersion} or higher on your LEDGER Hardware-Wallet for this action!\nOlder versions like your current ${versionApp} do not support this function, please upgrade - thx.\n\n\e[33mInfo: If the needed Cardano-App Version is not available on the Ledger Live Application, you can enable the Experimental Features like:\n-> Settings -> Experimental Features -> My Ledger provider -> Enable it and set it to 4\nAfter that, you should see a newer version. Usage at own risk of course. :-)\e[0m\n"; exit 1; fi
		echo -ne "\r\033[1A\e[0mCardano App Version \e[32m${versionApp}\e[0m (HW-Cli Version \e[32m${versionHWCLI}\e[0m) found on your \e[32m${walletManu}\e[0m device!\033[K\n\e[32mPlease approve the action on your Hardware-Wallet (abort with CTRL+C) \e[0m... \033[K"
		;;

        TREZOR ) #For Trezor Hardware-Wallets
                versionCheck "${minTrezorCardanoAppVersion}" "${versionApp}"
		if [[ $? -ne 0 ]]; then echo -e "\n\n\e[35mVersion ERROR - Please use Firmware version ${minTrezorCardanoAppVersion} or higher on your TREZOR Hardware-Wallet for this action!\nOlder versions like your current ${versionApp} do not support this function, please upgrade - thx.\n\e[0m"; exit 1; fi
		echo -ne "\r\033[1A\e[0mFirmware-Version \e[32m${versionApp}\e[0m (HW-Cli Version \e[32m${versionHWCLI}\e[0m) found on your \e[32m${walletManu}\e[0m device!\033[K\n\e[32mPlease approve the action on your Hardware-Wallet (abort with CTRL+C) \e[0m... \033[K"
                ;;

	* ) #For any other Manuf.
		majorError "Only Ledger and Trezor Hardware-Wallets are supported at the moment!"; exit 1;
		;;
esac

}

#-------------------------------------------------------

#-------------------------------------------------------
#Convert the given lovelaces $1 into ada (divide by 1M)
convertToADA() {
#echo $(bc <<< "scale=6; ${1} / 1000000" | sed -e 's/^\./0./') #divide by 1M and add a leading zero if below 1 ada
printf "%'.6f" "${1}e-6" #return in ADA format (with 6 commas)
}


#-------------------------------------------------------
#Get the real bytelength of a given string (for UTF-8 byte check)
byteLength() {
    echo -n "${1}" | wc --bytes
}


#-------------------------------------------------------
#Autocorrection of the TxBody to be in canonical order for HW-Wallet transactions
autocorrect_TxBodyFile() {

local txBodyFile="${1}"
local txBodyTmpFile="${1}-corrected"

#check cardanohwcli presence and version
if [[ "$(which ${cardanohwcli})" == "" ]]; then echo -e "\n\e[35mError - cardano-hw-cli binary not found, please install it first and set the path to it correct in the 00_common.sh, common.inc or $HOME/.common.inc !\e[0m\n"; exit 1; fi
versionHWCLI=$(${cardanohwcli} version 2> /dev/null |& head -n 1 |& awk {'print $6'})
versionCheck "${minHardwareCliVersion}" "${versionHWCLI}"
if [[ $? -ne 0 ]]; then majorError "Version ERROR - Please use a cardano-hw-cli version ${minHardwareCliVersion} or higher !\nYour version ${versionHWCLI} is no longer supported for security reasons or features, please upgrade - thx."; exit 1; fi

#do the correction
#tmp=$(${cardanohwcli} transaction transform-raw --tx-body-file ${txBodyFile} --out-file ${txBodyTmpFile} 2> /dev/stdout) #old default format
tmp=$(${cardanohwcli} transaction transform --tx-file ${txBodyFile} --out-file ${txBodyTmpFile} 2> /dev/stdout) #new cddl format

if [[ $? -ne 0 ]]; then echo -e "\n${tmp}"; exit 1; fi
tmp_lastline=$(echo "${tmp}" | tail -n 1)
if [[ "${tmp_lastline^^}" =~ (ERROR) ]]; then echo -e "\n${tmp}"; exit 1; fi

#ok, no error occured to this point. copy the generated new TxBody file over the original one
mv ${txBodyTmpFile} ${txBodyFile}; if [[ $? -ne 0 ]]; then echo -e "\n\e[35mError: Could not write new TxBody File!"; exit 1; fi

#all went well, now return the lastline output
echo "${tmp_lastline}"; exit 0
}
#-------------------------------------------------------


#-------------------------------------------------------
#Autocorrection of the TxBody to be in canonical order for HW-Wallet transactions
#Also repairs a maybe broken AuxDataHash!
autocorrect_TxBodyFile_withAuxDataHashCorrection() {

local txBodyFile="${1}"
local txBodyTmpFile="${1}-corrected"
local auxHashStatus=""

#check cardanohwcli presence and version
if [[ "$(which ${cardanohwcli})" == "" ]]; then echo -e "\n\e[35mError - cardano-hw-cli binary not found, please install it first and set the path to it correct in the 00_common.sh, common.inc or $HOME/.common.inc !\e[0m\n"; exit 1; fi
versionHWCLI=$(${cardanohwcli} version 2> /dev/null |& head -n 1 |& awk {'print $6'})
versionCheck "${minHardwareCliVersion}" "${versionHWCLI}"
if [[ $? -ne 0 ]]; then majorError "Version ERROR - Please use a cardano-hw-cli version ${minHardwareCliVersion} or higher !\nYour version ${versionHWCLI} is no longer supported for security reasons or features, please upgrade - thx."; exit 1; fi

#search for the auxmetadata and generate the current aux hash from it as a verification.
#this is a fast simple solution by searching for the hexbytes f5d90103 as the mark of the auxdata beginning, there is no deep cbor analysis behind it
local currentAuxHash=$(cat ${txBodyFile} | sed -n "s/.*f5\(d90103.*\)\"/\1/p" | xxd -r -ps | b2sum -l 256 -b | awk {'print $1'}) #holds the expected auxhash
local currentAuxHash=$(cat ${txBodyFile} | sed -n "s/.*\($currentAuxHash\).*/\1/p") #holds the auxhash if it was found in the txcbor as a proof that the auxdata was found correctly

#do the correction
tmp=$(${cardanohwcli} transaction transform --tx-file ${txBodyFile} --out-file ${txBodyTmpFile} 2> /dev/stdout) #new cddl format
if [[ $? -ne 0 ]]; then echo -e "\n${tmp}"; exit 1; fi
tmp_lastline=$(echo "${tmp}" | tail -n 1)
if [[ "${tmp_lastline^^}" =~ (ERROR) ]]; then echo -e "\n${tmp}"; exit 1; fi

#generate the newAuxHash after the canonical order transformation
local newAuxHash=$(cat ${txBodyTmpFile} | sed -n 's/.*f5\(d90103.*\)\"/\1/p' | xxd -r -ps | b2sum -l 256 -b | awk {'print $1'})
if [[ "${currentAuxHash}" != "" && "${currentAuxHash}" != "${newAuxHash}" ]]; then #only do it when the currentAuxHash holds a hash (detection worked) and if the new one is different to the old one
	sed -i "s/${currentAuxHash}/${newAuxHash}/g" ${txBodyTmpFile}; if [ $? -ne 0 ]; then echo -e "\nCouldn't write temporary ${txBodyTmpFile} with a corrected AuxHash!"; exit 1; fi
	local auxHashStatus="\e[91m\nCorrected the AuxHash from '${currentAuxHash}' to '${newAuxHash}' too!"
fi

#ok, no error occured to this point. copy the generated new TxBody file over the original one
mv ${txBodyTmpFile} ${txBodyFile}; if [[ $? -ne 0 ]]; then echo -e "\n\e[35mError: Could not write new TxBody File!"; exit 1; fi

#all went well, now return the lastline output
echo "${tmp_lastline}${auxHashStatus}"; exit 0
}
#-------------------------------------------------------


#-------------------------------------------------------
#Show a rotating bar in asynchron mode during processing like utxo query
#Stop animation by sending a SIGINT to this child process
#
# ${1} = preText
function showProcessAnimation() {

local stopAnimation="false";
local idx=0;
#local animChar=("-" "\\" "|" "/");
#local animChar=("⎺" "\\" "⎽" "/");
local animChar=(">    " ">>   " ">>>  " " >>> " "  >>>" "   >>" "    >" "     ");
#local animChar=(">    " " >   " "  >  " "   > " "    >" "   < " "  <  " " <   ");

trap terminate SIGINT
terminate(){ stopAnimation="true"; }

until [[ ${stopAnimation} == "true" ]]; do
        idx=$(( (${idx}+1)%8 ))
        echo -ne "\r\e[0m${1}${animChar[$idx]} "
        sleep 0.2
done
}
#-------------------------------------------------------
stopProcessAnimation() {
pkill -SIGINT -P $$ && echo -ne "\r\033[K" #stop childprocess and delete the outputline
}
#-------------------------------------------------------



#-------------------------------------------------------
#checks if the given password $1 is a strong one
#min. 10 chars long, includes at least one uppercase, one lowercase, one special char
is_strong_password() {
    [[ "$1" =~ ^(.*[a-z]) ]] && [[ "$1" =~ ^(.*[A-Z]) ]] && [[ "$1" =~ ^(.*[0-9]) ]] && [[ "$1" =~ ^(.*[^a-zA-Z0-9]) ]] && [[ "$1" =~ ^(.){10,} ]] && echo "true"
}
#-------------------------------------------------------


#-------------------------------------------------------
#encrypt skey json data, will return a json with a
#modified 'description' field and encrypted 'encrHex' field
#
# ${1} = skeyJSON data
# ${2} = password
encrypt_skeyJSON() {

	local skeyJSON="${1}"
	local password="${2}"

	#check that the encryption/decryption tool gpg exists
	if ! exists gpg; then echo -e "\n\n\e[33mYou need the little tool 'gnupg', its needed to encrypt/decrypt the data !\n\nInstall it on Ubuntu/Debian like:\n\e[97msudo apt update && sudo apt -y install gnupg\n\n\e[33mThx! :-)\e[0m\n" > $(tty); exit 1; fi

	#check if the skeyJSON is already encrypted
	if [[ $(egrep "encrHex|Encrypted" <<< "${skeyJSON}" | wc -l) -ne 0 ]]; then echo "It is already encrypted!"; exit 1; fi

	#read data
	local skeyType=$(jq -r .type <<< ${skeyJSON}); if [[ $? -ne 0 ]]; then echo "Can't read the .type field!"; exit 1; fi
	if [[ "${skeyJSON}" != *"SigningKey"* ]]; then echo "Type field does not contain 'SigningKey' information!"; exit 1; fi
	local skeyDescription=$(jq -r .description <<< ${skeyJSON}); if [[ $? -ne 0 ]]; then echo "Can't read the .description field!"; exit 1; fi
	local skeyCBOR=$(jq -r .cborHex <<< ${skeyJSON}); if [[ $? -ne 0 ]]; then echo "Can't read the .cborHex field!"; exit 1; fi
	unset skeyJSON #not used after this line

	#encrypt
	local encrHex=$(gpg --symmetric --yes --batch --quiet --cipher-algo AES256 --passphrase "${password}" --log-file /dev/null <<< ${skeyCBOR} 2> /dev/null | xxd -ps -c 1000000)
	unset skeyCBOR #not used after this line
	unset password #not used after this line
	if [[ "${encrHex}" == "" ]]; then echo "Couldn't encrypt the data via gpg!"; exit 1; fi

	#return data and format it via jq (monochrome)
	echo -e "{ \"type\": \"${skeyType}\", \"description\": \"Encrypted ${skeyDescription}\", \"encrHex\": \"${encrHex}\" }" | jq -M .

}
#-------------------------------------------------------


#-------------------------------------------------------
#decrypt skey json data, will return a json with the
#original 'description' field and a decrypted 'cborHex' field
#
# ${1} = skeyJSON data
# ${2} = password
decrypt_skeyJSON() {

	local skeyJSON="${1}"
	local password="${2}"

	#check that the encryption/decryption tool gpg exists
	if ! exists gpg; then echo -e "\n\n\e[33mYou need the little tool 'gnupg', its needed to encrypt/decrypt the data !\n\nInstall it on Ubuntu/Debian like:\n\e[97msudo apt update && sudo apt -y install gnupg\n\n\e[33mThx! :-)\e[0m\n" > $(tty); exit 1; fi

	#check if the skeyJSON is already decrypted
	if [[ $(egrep "encrHex|Encrypted" <<< "${skeyJSON}" | wc -l) -eq 0 ]]; then echo "It is already decrypted!"; exit 1; fi

	#read data
	local skeyType=$(jq -r .type <<< ${skeyJSON}); if [[ $? -ne 0 ]]; then echo "Can't read the .type field!"; exit 1; fi
	if [[ "${skeyJSON}" != *"SigningKey"* ]]; then echo "Type field does not contain 'SigningKey' information!"; exit 1; fi
	local skeyDescription=$(jq -r .description <<< ${skeyJSON}); if [[ $? -ne 0 ]]; then echo "Can't read the .description field!"; exit 1; fi
	local skeyEncrHex=$(jq -r .encrHex <<< ${skeyJSON}); if [[ $? -ne 0 ]]; then echo "Can't read the .encrHex field!"; exit 1; fi
	unset skeyJSON #not used after this line

	#decrypt
	local cborHex=$(xxd -ps -r <<< ${skeyEncrHex} | gpg --decrypt --yes --batch --quiet --passphrase "${password}" --log-file /dev/null 2> /dev/null)
	unset skeyEncrHex #not used after this line
	unset password #not used after this line
	if [[ "${cborHex}" == "" ]]; then echo "Couldn't decrypt the data via gpg! Wrong password?"; exit 1; fi

	#return data and format it via jq (monochrome)
	echo -e "{ \"type\": \"${skeyType}\", \"description\": \"${skeyDescription//Encrypted /}\", \"cborHex\": \"${cborHex}\" }" | jq -M .
	unset cborHex

}
#-------------------------------------------------------


#-------------------------------------------------------
#read skey file and decrypt it if needed
#
#this function returns the skey json which will be used for example to sign transactions directly and not via a file read
#
# ${1} = skeyFILE
#
read_skeyFILE() {

	local skeyFILE="${1}"
	local cborHex=""

	local viaENV=""

	#check if the file exists
	if [ ! -f "${skeyFILE}" ]; then echo -e "\e[35mGiven SKEY-File does not exist!\e[0m\n\n"; exit 1; fi

	#check if the skeyJSON is already decrypted, if so, just return the content
	if [[ $(egrep "encrHex|Encrypted" < "${skeyFILE}" | wc -l) -eq 0 ]]; then echo -ne "\e[0mReading unencrypted file \e[32m${skeyFILE}\e[0m ... " > $(tty); cat "${skeyFILE}"; exit 0; fi

	#its encrypted, check that the encryption/decryption tool gpg exists
	if ! exists gpg; then echo -e "\n\n\e[33mYou need the little tool 'gnupg', its needed to encrypt/decrypt the data !\n\nInstall it on Ubuntu/Debian like:\n\e[97msudo apt update && sudo apt -y install gnupg\n\n\e[33mThx! :-)\e[0m\n" > $(tty); exit 1; fi

	#main loop to repeat the decryption until we have a cborHex
	while [[ "${cborHex}" == "" ]]; do

		#check if there is a passwort set in the ENV_DECRYPT_PASSWORD variable, if so, just do a short check and not prompt for a password

		if [[ "${ENV_DECRYPT_PASSWORD}" == "" ]]; then #prompt for a password
			#prompt for the password
		        local password=$(ask_pass "\e[33mEnter the Password to decrypt '${skeyFILE}' (empty to abort)")
		        if [[ ${password} == "" ]]; then echo -e "\e[35mAborted\e[0m\n\n"; exit 1; fi
		        while [[ $(is_strong_password "${password}") != "true" ]]; do
		                        echo -e "\n\e[35mThis is not a strong password, so it couldn't be the right one. Lets try it again...\e[0m\n" > $(tty)
				        local password=$(ask_pass "\e[33mEnter the Password to decrypt '${skeyFILE}' (empty to abort)")
		                        if [[ ${password} == "" ]]; then echo -e "\e[35mAborted\e[0m\n\n"; exit 1; fi
		        done

		else #password is present in the ENV_DECRYPT_PASSWORD variable

			#exit with an error if the password in the ENV_DECRYPT_PASSWORD is not a strong one
			if [[ $(is_strong_password "${ENV_DECRYPT_PASSWORD}") != "true" ]]; then echo -e "\n\e[35mThis is not a strong password via ENV_DECRYPT_PASSWORD... abort!\n\n"; exit 1; fi
			local password=${ENV_DECRYPT_PASSWORD}
			local viaENV="via ENV_DECRYPT_PASSWORD " #to extend the processing text

		fi

		#read data
		local skeyJSON=$(cat "${skeyFILE}")
		local skeyType=$(jq -r .type <<< ${skeyJSON}); if [[ $? -ne 0 ]]; then echo "Can't read the .type field!"; exit 1; fi
		if [[ "${skeyJSON}" != *"SigningKey"* ]]; then echo "Type field does not contain 'SigningKey' information!"; exit 1; fi
		local skeyDescription=$(jq -r .description <<< ${skeyJSON}); if [[ $? -ne 0 ]]; then echo "Can't read the .description field!"; exit 1; fi
		local skeyEncrHex=$(jq -r .encrHex <<< ${skeyJSON}); if [[ $? -ne 0 ]]; then echo "Can't read the .encrHex field!"; exit 1; fi
		unset skeyJSON #not used after this line

		#decrypt
		echo -ne "\r\033[K\e[0mDecrypting the file '\e[32m${skeyFILE}\e[0m' ${viaENV}... " > $(tty)
		local cborHex=$(xxd -ps -r <<< ${skeyEncrHex} 2> /dev/null | gpg --decrypt --yes --batch --quiet --passphrase "${password}" --log-file /dev/null 2> /dev/null)
		unset skeyEncrHex #not used after this line
		unset password #not used after this line
		if [[ "${cborHex}" == "" ]]; then
			if [[ "${ENV_DECRYPT_PASSWORD}" != "" ]]; then echo -e "\e[35mCouldn't decrypt the data via ENV_DECRYPT_PASSWORD! Wrong password?\e[0m"; exit 1; fi #if there was an error and password was from the ENV, exit with an error
			echo -e "\e[35mCouldn't decrypt the data! Wrong password?\e[0m" > $(tty);
 		fi

	done

	#we have cborHex content now, so the decryption worked

	#return data in json format, remove the added "Encrypted " in the description field on the fly
	printf "{ \"type\": \"${skeyType}\", \"description\": \"${skeyDescription//Encrypted /}\", \"cborHex\": \"${cborHex}\" }"
	unset cborHex

}
#-------------------------------------------------------



