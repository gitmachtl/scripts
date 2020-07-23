#!/bin/bash

# Script is brought to you by ATADA_Stakepool, Telegram @atada_stakepool

#load variables from common.sh
#       socket          Path to the node.socket (also exports socket to CARDANO_NODE_SOCKET_PATH)
#       genesisfile     Path to the genesis.json
#       magicparam      TestnetMagic parameter
#       cardanocli      Path to the cardano-cli executable
#       cardanonode     Path to the cardano-node executable
. "$(dirname "$0")"/00_common.sh

case $# in
  3 ) addrName="$1";
      itnPrivateKey="$2";
      itnVerificationKey="$3";;
  * ) cat >&2 <<EOF
Usage:  $(basename $0) <StakeAddressName>  <ITN Private/Secret Key HASH>  <ITN Verification/Public Key HASH>
EOF
  exit 1;; esac

#warnings
if [ -f "${addrName}.staking.vkey" ]; then echo -e "\e[35mWARNING - ${addrName}.staking.vkey already present, delete it or use another name !\e[0m"; exit 2; fi
if [ -f "${addrName}.staking.skey" ]; then echo -e "\e[35mWARNING - ${addrName}.staking.skey already present, delete it or use another name !\e[0m"; exit 2; fi
if [ -f "${addrName}.staking.addr" ]; then echo -e "\e[35mWARNING - ${addrName}.staking.addr already present, delete it or use another name !\e[0m"; exit 2; fi

#convert itn key to stake skey/vkey
echo "${itnPrivateKey}" > ${tempDir}/itn.key; itnKeyFile="${tempDir}/itn.key";
${cardanocli} shelley key convert-itn-key --itn-signing-key-file ${itnKeyFile} --out-file ${addrName}.staking.skey

echo "${itnVerificationKey}" > ${tempDir}/itn.key; itnKeyFile="${tempDir}/itn.key";
${cardanocli} shelley key convert-itn-key --itn-verification-key-file ${itnKeyFile} --out-file ${addrName}.staking.vkey

rm ${itnKeyFile}

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
${cardanocli} shelley stake-address build --staking-verification-key-file ${addrName}.staking.vkey ${magicparam} > ${addrName}.staking.addr
file_lock ${addrName}.staking.addr

echo -e "\e[0mStaking(Rewards)-Address built: \e[32m ${addrName}.staking.addr \e[90m"
cat ${addrName}.staking.addr
echo

echo -e "\e[0m\n"

