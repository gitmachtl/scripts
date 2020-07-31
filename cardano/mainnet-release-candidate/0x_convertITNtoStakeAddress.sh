#!/bin/bash

# Script is brought to you by ATADA_Stakepool, Telegram @atada_stakepool

#load variables from common.sh
#       socket          Path to the node.socket (also exports socket to CARDANO_NODE_SOCKET_PATH)
#       genesisfile     Path to the genesis.json
#       magicparam      TestnetMagic parameter
#       cardanocli      Path to the cardano-cli executable
#       cardanonode     Path to the cardano-node executable
. "$(dirname "$0")"/00_common.sh

#Only now for the ITN conversion
cardanocli=${cardanocli_itn}

case $# in
  3 ) addrName="$1";
      itnSKEYfile="$2";
      itnVKEYfile="$3";;
  * ) cat >&2 <<EOF
Usage:  $(basename $0) <StakeAddressName>  <ITN Private/Secret Key File>  <ITN Verification/Public Key File>
EOF
  exit 1;; esac

#warnings
if [ ! -f "${itnSKEYfile}" ]; then echo -e "\e[35mWARNING - ${itnSKEYfile} does not exist !\e[0m"; exit 2; fi
if [ ! -f "${itnVKEYfile}" ]; then echo -e "\e[35mWARNING - ${itnVKEYfile} does not exist !\e[0m"; exit 2; fi
if [ -f "${addrName}.staking.vkey" ]; then echo -e "\e[35mWARNING - ${addrName}.staking.vkey already present, delete it or use another name !\e[0m"; exit 2; fi
if [ -f "${addrName}.staking.skey" ]; then echo -e "\e[35mWARNING - ${addrName}.staking.skey already present, delete it or use another name !\e[0m"; exit 2; fi
if [ -f "${addrName}.staking.addr" ]; then echo -e "\e[35mWARNING - ${addrName}.staking.addr already present, delete it or use another name !\e[0m"; exit 2; fi

#convert itn key to stake skey/vkey
itnSkey=$(cat ${itnSKEYfile})
itnVkey=$(cat ${itnVKEYfile})

if [[ "${itnSkey:0:8}" == "ed25519e" ]]; then #extended key
						${cardanocli} shelley key convert-itn-extended-key --itn-signing-key-file ${itnSKEYfile} --out-file ${addrName}.staking.skey
elif [[ "${itnSkey:0:7}" == "ed25519" ]]; then #normal key
                                                ${cardanocli} shelley key convert-itn-key --itn-signing-key-file ${itnSKEYfile} --out-file ${addrName}.staking.skey
else echo -e "\e[35mWARNING - ${itnSkey} is an unknown key format. Only ed25519 and ed25519e keys are supported !\e[0m"; exit 2;
fi

${cardanocli} shelley key convert-itn-key --itn-verification-key-file ${itnVKEYfile} --out-file ${addrName}.staking.vkey

file_lock ${addrName}.staking.vkey
file_lock ${addrName}.staking.skey

echo
echo -e "\e[0mVerification(Rewards)-Staking-Key: \e[32m ${addrName}.staking.vkey \e[90m"
cat ${addrName}.staking.vkey
echo
echo -e "\e[0mSigning(Rewards)-Staking-Key: \e[32m ${addrName}.staking.skey \e[90m"
cat ${addrName}.staking.skey
echo

#Building a Staking Address
${cardanocli} shelley stake-address build --staking-verification-key-file ${addrName}.staking.vkey --mainnet > ${addrName}.staking.addr
file_lock ${addrName}.staking.addr

echo -e "\e[0mStaking(Rewards)-Address built: \e[32m ${addrName}.staking.addr \e[90m"
cat ${addrName}.staking.addr
echo

echo -e "\e[0m\n"

