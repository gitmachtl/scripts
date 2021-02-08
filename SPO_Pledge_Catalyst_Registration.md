# How to register your operator pledge staking key for Catalyst Voting

<a href="https://github.com/gitmachtl/scripts/tree/master/cardano/mainnet"><img src="https://www.stakepool.at/pics/stakepool_operator_scripts.png" border=0></img></a><br>

I put this together, should work for you, it did for me. But of course, use the instructions at your own risk ... :-)

Best regards, Martin (ATADA/ATAD2 Stakepool Austria)

## First - Lets talk about security

Make sure you don't have any rewards sitting on your pledge staking key,
withdrawl them first to your pledge payment account or whereever you like.
The tool IOHK provides should not harm it in any way, its just a safety thing.
You need a running and fully synced node on the machine, also you will have
your pledge staking skey on that machine for the time of running the registration
tool. Each SPO have to decide if he is ok with that or not. Your pledge funds are
not at risk here, because you don't need your pledge payment skey for the registration.

## Generate your voting secret and public key

You need a **jcli** binary for that, you should already have this laying around, if not,
you can find the latest compiled release here:<br>
[https://github.com/input-output-hk/jormungandr/releases/latest](https://github.com/input-output-hk/jormungandr/releases/latest)

You can extract the file for your operating system like:
``` console
wget https://github.com/input-output-hk/jormungandr/releases/download/v0.9.3/jormungandr-0.9.3-x86_64-unknown-linux-gnu-generic.tar.gz
tar -xf jormungandr-0.9.3-x86_64-unknown-linux-gnu-generic.tar.gz
```

Now lets generate the two keyfiles:

```console
./jcli key generate --type ed25519extended > catalyst-vote.skey
./jcli key to-public < catalyst-vote.skey > catalyst-vote.pkey
```

You have generated the secret- and the public-voting key, we use them now in the next steps.

## Generate the signed voting registration

You need the **voter-registration** tool for this, you have to compile it like you 
compile your cardano-node.<p>

The tool is written in haskell, you compile it the same way as you do with your cardano node, should be
something similar to this:

:bulb: **Repo Link below was updated for Catalyst Fund3 !**

``` console
git clone https://github.com/input-output-hk/voting-tools
cd voter-registration-tool
echo -e "package cardano-crypto-praos\n  flags: -external-libsodium-vrf\n" > cabal.project.local
cabal update
cabal build all
```

To copy out the **voter-registration** binary you can use this command after the build to copy it to your
prefered directory. In this example the copy goes to the ~/cardano/ directory:
``` console
cp $(find . -name voter-registration -executable -type f) ~/cardano/.
```

Ok, now we have the tool to generate the signed transaction file. 

Make sure your environment variable **CARDANO_NODE_SOCKET_PATH** is pointing to a running fully synced 
cardano node (just a simple passive one is ok), for example:

``` console
export CARDANO_NODE_SOCKET_PATH=db-mainnet/node.socket
```

The registration tool needs some parameters to call:

``` console
./voter-registration  --payment-signing-key FILE 
                      --payment-address STRING 
                      --vote-public-key FILE 
                      --stake-signing-key FILE 
                      (--mainnet | --testnet-magic NATURAL)
                      [--time-to-live WORD64]
                      --out-file FILE
                      [--byron-era | --shelley-era | --allegra-era | --mary-era]
                      [--shelley-mode | --byron-mode
                      [--epoch-slots NATURAL] |
                      --cardano-mode [--epoch-slots NATURAL]]

```                      

So in our case we need a payment address, this should **NOT BE YOUR PLEDGE ADDRESS**! Just a simple
payment address to pay for the transaction, we call it **somepayment**. So we need the somepayment.skey,
also we need the somepayment address as text, or in the example below we read it out from the somepayment.addr 
file directly. Than you need of course your pledge.staking.skey you wanna register for Catalyst Voting.
Then we need the public voting key we generated in the steps above with jcli. You have to choose the network,
in this case we are on mainnet. The Time-To-Live parameter is not needed, but make sure to submit the signed 
transaction file as soon as possible after the creation. The last thing we need is the
path to the signed transaction output file, lets call it **vote-catalyst.tx**. So a complete call would be:

```console
./voter-registration  --payment-signing-key somepayment.skey \
                      --payment-address $(cat somepayment.addr) \
                      --vote-public-key catalyst-vote.pkey \
                      --stake-signing-key pledge.staking.skey \
                      --mainnet \
                      --mary-era
                      --cardano-mode
                      --out-file vote-registration.tx
```

If all went well, you should get an output similar to this:
```console
Vote public key used        (hex): 71ce673ef64baaaafb758b65df01b036665d4498256335e93e28b869568d9ed8
Stake public key used       (hex): 9be513df12b3fabe7c1b8c3f9bbbb968eb2168d5689bf981c2f7c35b11718b27
Vote registration signature (hex): 57267d94e5bae64fa236924b83ce7411fef10bd5d73aca7afabcd053cf2dc2e3621f7d253bf90933e2bc0bfb56146cf0a13925d9f96d6d06b0b798bc41d4000d
```

and also the **vote-registration.tx** file with a content similar to this:
```console
{
    "type": "TxSignedShelley",
    "description": "",
    "cborHex": "83a500828258205761bdc4fd016ee0d52ac759ae6c0e8e0943d4892474283866a07f9768e48fee00825820e6701be50c87d8d584985edd4cf39799e1445bd37907027c44d08c7da79ea23200018182583900fec5a902e307707b6ab3de38104918c0e33cf4c3408e6fcea4f0a199c13582aec9a44fcc6d984be003c5058c660e1d2ff1370fd8b49ba73f1b00001e0369444cd7021a0002c329031a00ce0fc70758202386abf617780a925495f38f23d7bc594920ff374f03f3d7517a4345e355b047a1008182582099d1d0c4cdc8a4b206066e9606c6c3729678bd7338a8eab9bffdffa39d3df9585840af346c11fe7a222008f5b1b50fbc23a0cbc3d783bf4461f21353e8b5eb664adadb34291197e039e467d2a68346921879d1212bd0d54245a9e110162ecae9190ba219ef64a201582071ce673ef64b4ac1fb758b65df01b036665d4498256335e93e28b869568d9ed80258209be513df12b3fabe7c1b8c3f9fab0968eb2168d5689bf981c2f7c35b11718b2719ef65a101584057267d94e5bae64fa236924b83ce7411fef10bd5d73aca7af8403053cf2dc2e3621f7d253bf90933e2bc0bfb56146cf0a13925d9f96d6d06b0b798bc41d4000d"
}
```

## Submit the registration on the chain

We have generated the signed registration transaction file **vote-registration.tx**, now lets submit it on the chain.
You can do this on the same machine, or on another machine by just running:

``` console
./cardano-cli transaction submit --cardano-mode --mainnet --tx-file vote-registration.tx
```
If you don't get any error outputs, your registration is now on the chain. So there is only one step left for your SPO
Pledge Voting experience...

## Generate the QR code for the Catalyst Voting App:

There is a handy little tool called **vit-kedqr** available for that, you can find the compiled binary for your system here:<br>
[https://github.com/input-output-hk/vit-kedqr/releases/latest](https://github.com/input-output-hk/vit-kedqr/releases/latest)

Extract the downloaded archive for your operating system and copy out the binary to your prefered folder. We use again ~/cardano/ in our example:
``` console
wget https://github.com/input-output-hk/vit-kedqr/releases/download/v0.0.1/vit-kedqr_Linux_x86_64.tar.gz
tar -xf vit-kedqr_Linux_x86_64.tar.gz
cp $(find . -name vit-kedqr -executable -type f) ~/cardano/.
```

Now we have the tool to generate the qr code, and thats pretty simple. You have a few parameters:
```console
Usage of ./vit-kedqr:
  -input string
        path to file containing ed25519extended bech32 value
  -output string
        path to file to save qr code output, if not provided console output will be attempted
  -pin string
        Pin code. 4-digit number is used on Catalyst
```

In our example here we have generated the secret voting key as file called **catalyst-vote.skey**, and lets go with the
pincode *1234*. You can choose that and you will have to input it when using the Catalyst App to scan the QR code:

```console
./vit-kedqr -pin 1234 -input catalyst-vote.skey
```

This will show you the QR code on screen and you can use it with the Catalyst Voting App. :-)

If you wanna save the QR code for later, you can save it as a PNG image too using the -output parameter like:
```console
./vit-kedqr -pin 1234 -input catalyst-vote.skey -output catalyst-qrcode.png
```

This will generate the QR code as the file **catalyst-qrcode.png**

## Happy voting !
