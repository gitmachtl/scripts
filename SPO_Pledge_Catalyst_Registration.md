
# How to register your operator pledge staking key for Catalyst Voting

<a href="https://github.com/gitmachtl/scripts/tree/master/cardano/mainnet"><img src="https://www.stakepool.at/pics/stakepool_operator_scripts.png" border=0></img></a><br>

I put this together, should work for you, it did for me. But of course, use the instructions at your own risk ... :-)

Best regards, Martin (ATADA/ATAD2 Stakepool Austria)

&nbsp;<br>

# The simple way using the SPO-Scripts

## How to vote with Funds (also Pledge) on Hardware-Wallets :new:

Important - you need the [cardano-hw-cli](https://github.com/vacuumlabs/cardano-hw-cli/releases) version **1.5.0** or above for that!

Software needed on the Hardware-Wallet:
* **Ledger NanoS or NanoX: Cardano-App 2.3.2** or newer
* **Trezor Model-T: Firmware 2.4.0** or newer

To **generate your Voting-Registration**, please use the **09a_catalystVote.sh script** from the MainNet Repo to do so, you can find a description of the 4 simple steps [here](https://github.com/gitmachtl/scripts/tree/master/cardano/mainnet#catalyst-voting-with-your-hw-wallet)

&nbsp;<br>

## How to vote with Funds (also Pledge) on CLI-Keys and HYBRID-Keys :new:

Important - you need the [voter-registration tool](https://github.com/input-output-hk/voting-tools/releases/latest) version **0.2.0.0** or above for that!

To **generate your Voting-Registration**, please use the **09a_catalystVote.sh script** from the MainNet Repo to do so, you can find a description of the 4 simple steps [here](https://github.com/gitmachtl/scripts/tree/master/cardano/mainnet#catalyst-voting-with-your-cli-keys-or-hybrid-keys)

&nbsp;<br>


# The step-by-step way on the CLI

## How to vote with Funds (also Pledge) on CLI-Keys

### First - Lets talk about security

Make sure you don't have any rewards sitting on your pledge staking key,
withdrawl them first to your pledge payment account or whereever you like.
The tool IOHK provides should not harm it in any way, its just a safety thing.
You need a running and fully synced node on the machine, also you will have
your pledge staking skey on that machine for the time of running the registration
tool. Each SPO have to decide if he is ok with that or not. Your pledge funds are
not at risk here, because you don't need your pledge payment skey for the registration.

### Generate your voting secret and public key

You need a **jcli** binary for that, you should already have this laying around, if not,
you can find the latest compiled release here:<br>
[https://github.com/input-output-hk/jormungandr/releases/latest](https://github.com/input-output-hk/jormungandr/releases/latest)

You can extract the file for your operating system like:
``` console
wget https://github.com/input-output-hk/jormungandr/releases/download/v0.9.3/jormungandr-0.9.3-x86_64-unknown-linux-gnu-generic.tar.gz
tar -xf jormungandr-0.9.3-x86_64-unknown-linux-gnu-generic.tar.gz
```

Now lets generate the two keyfiles:

``` console
./jcli key generate --type ed25519extended > catalyst-vote.skey
./jcli key to-public < catalyst-vote.skey > catalyst-vote.pkey
```

You have generated the secret- and the public-voting key, we use them now in the next steps.

⚠️ Make sure, that you have generated the skey as an ed25519**extended** key !

### Where will the voting rewards distributed to?

Thats an important one, the voting rewards will be distributed back onto a stake address as rewards. Like staking rewards !


### Generate the voting registration metadata

Make sure your environment variable **CARDANO_NODE_SOCKET_PATH** is pointing to a running fully synced 
cardano node (just a simple passive one is ok), for example:

``` console
export CARDANO_NODE_SOCKET_PATH=db-mainnet/node.socket
```

Lets generate the registration metadata in json format:

``` console
export NETWORK_ID="--mainnet"
export SLOT_TIP=$(cardano-cli query tip $NETWORK_ID | jq '.slot')

voter-registration \
    --rewards-address $(cat pledge.staking.addr) \
    --vote-public-key-file catalyst-vote.pkey \
    --stake-signing-key-file pledge.staking.skey \
    --slot-no $SLOT_TIP \
    --json > voting-registration-metadata.json
```

Both CBOR (--cbor) and JSON (--json) formats exist. We choose --json in this example.

### Submission of vote registration

Next, we need to add this transaction metadata to a transaction and submit it to the chain.

First we'll grab the protocol parameters:

``` console
cardano-cli query protocol-parameters \
    $NETWORK_ID \
    --out-file protocol.json
```

And find some funds to use:

We need a payment address, this should **NOT BE YOUR PLEDGE ADDRESS**! Just a simple
payment address to pay for the transaction, we call it **payment**. 


``` console
export PAYMENT_ADDR=$(cat payment.addr)

echo "UTxOs available:"
cardano-cli query utxo \
    $NETWORK_ID \
    --address $PAYMENT_ADDR
                           TxHash                                 TxIx        Amount
--------------------------------------------------------------------------------------
b9579d53f3fd77679874a2d1828e2cf40e31a8ee431b35ca9347375a56b6c39b     0        999821651 lovelace + TxOutDatumNone

```

Here we're just using the first TxHash and TxIx we find, you should choose an appropriate UTxO and TxIx.

``` console
export AMT=$(cardano-cli query utxo $NETWORK_ID --address $PAYMENT_ADDR | tail -n1 | awk '{print $3;}')
export UTXO=$(cardano-cli query utxo $NETWORK_ID --address $PAYMENT_ADDR | tail -n1 | awk '{print $1;}')
export UTXO_TXIX=$(cardano-cli query utxo $NETWORK_ID --address $PAYMENT_ADDR | tail -n1 | awk '{print $2;}')
echo "UTxO: $UTXO#$UTXO_TXIX"
```

Here we'll make draft transaction for the purposes of fee estimation. This transaction will simply send the entire UTxO value back to us, minus the fee. We don't need to send money anywhere else, we simply have to make a valid transaction with the metadata attached.

``` console
cardano-cli transaction build-raw \
    --tx-in $UTXO#$UTXO_TXIX \
    --tx-out $(cat payment.addr)+0 \
    --invalid-hereafter 0 \
    --fee 0 \
    --metadata-json-file voting-registration-metadata.json
    --out-file tx.draft \

export FEE=$(cardano-cli transaction calculate-min-fee \
    $NETWORK_ID \
    --tx-body-file tx.draft \
    --tx-in-count 1 \
    --tx-out-count 1 \
    --witness-count 1 \
    --protocol-params-file protocol.json | awk '{print $1;}')

export AMT_OUT=$(expr $AMT - $FEE)
```

Then we have to decide on a TTL for the transaction, and build the final transaction:

``` console
export TTL=$(expr $SLOT_TIP + 200)

cardano-cli transaction build-raw \
    --tx-in $UTXO#$UTXO_TXIX \
    --tx-out $PAYMENT_ADDR+$AMT_OUT \
    --invalid-hereafter $TTL \
    --fee $FEE \
    --metadata-json-file voting-registration-metadata.json
    --out-file tx.raw
```

Then we can sign the transaction:

``` console
cardano-cli transaction sign \
    --tx-body-file tx.raw \
    --signing-key-file payment.skey \
    $NETWORK_ID \
    --out-file tx.signed
```

And finally submit our transaction:

``` console
cardano-cli transaction submit \
    --tx-file tx.signed \
    $NETWORK_ID
```

We'll have to wait a little while for the transaction to be incorporated into the chain:

``` console
cardano-cli query utxo --address $(cat payment.addr) $NETWORK_ID
                           TxHash                                 TxIx        Amount
--------------------------------------------------------------------------------------
b9579d53f3fd77679874a2d1828e2cf40e31a8ee431b35ca9347375a56b6c39b     0        999821651 lovelace + TxOutDatumNone

cardano-cli query utxo --address $(cat payment.addr) $NETWORK_ID
                           TxHash                                 TxIx        Amount
--------------------------------------------------------------------------------------
4fbd6149f9cbbeb8f91b618ae3813bc451c22059c626637d3b343d3114cb92c5     0        999642026 lovelace + TxOutDatumNone
```

But once we've confirmed the transaction has entered the chain, we're registered!


### Generate the QR code for the Catalyst Voting App:

There is a handy little tool called **qr-code** available as part of `catalyst-toolbox` for that, you can find the compiled binary for your system here:<br>
[https://github.com/input-output-hk/catalyst-toolbox/releases/latest](https://github.com/input-output-hk/catalyst-toolbox/releases/latest)

Extract the downloaded archive for your operating system and copy out the binary to your prefered folder. We use again ~/cardano/ in our example:
``` console
wget https://github.com/input-output-hk/catalyst-toolbox/releases/download/v0.3.0/catalyst-toolbox-0.3.0-x86_64-unknown-linux-gnu.tar.gz
tar -xf catalyst-toolbox-0.3.0-x86_64-unknown-linux-gnu.tar.gz
cp $(find . -name catalyst-toolbox -executable -type f) ~/cardano/.
```

Now we have the tool to generate the qr code, and thats pretty simple. You have a few parameters:
```console
Usage of ./catalyst-toolbox qr-code:
  --input string
        path to file containing ed25519extended bech32 value
  --output string
        path to file to save qr code output, if not provided console output will be attempted
  --pin string
        Pin code. 4-digit number is used on Catalyst
  img
        Output as an image (Subcommand)
```
  
Or simply run `./catalyst-toolbox qr-code --help` for the newest version help.

In our example here we have generated the secret voting key as file called **catalyst-vote.skey**, and lets go with the
pincode *1234*. You can choose that and you will have to input it when using the Catalyst App to scan the QR code:

```console
./catalyst-toolbox qr-code --pin 1234 --input catalyst-vote.skey img
```

This will show you the QR code on screen and you can use it with the Catalyst Voting App. :-)

If you wanna save the QR code for later, you can save it as a PNG image too using the -output parameter like:
```console
./catalyst-toolbox qr-code --pin 1234 --input catalyst-vote.skey --output catalyst-qrcode.png img
```

This will generate the QR code as the file **catalyst-qrcode.png**

> If you wanna be 1000% sure that your QR code is correct, you can validate it again with this little tool here: [https://github.com/input-output-hk/vit-testing/tree/main/iapyx#readme](https://github.com/input-output-hk/vit-testing/tree/main/iapyx#readme) ➡️ iapyx-qr
  
## Happy voting !
