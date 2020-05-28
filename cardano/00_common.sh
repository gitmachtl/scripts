#!/bin/bash

socket="db-ff/node.socket"
export CARDANO_NODE_SOCKET_PATH=${socket}

genesisfile="configuration-ff/genesis.json"

magicparam="--testnet-magic 42"

cardanocli="./cardano-cli"
cardanonode="./cardano-node"
