# Catalyst Voting Registration via CLI tools - Fund10 

&nbsp;<br>

## Intro
<img src="https://projectcatalyst.org/large-thumbnail.png" width=50% align=right></img>
Starting with Catalyst Fund10, the on-chain registration format for Catalyst is using a new specification. This specification is described in [CIP36](https://github.com/cardano-foundation/CIPs/tree/master/CIP-0036) and it includes a few important changes.

The rewards payout address is now a regular **payment** (base or enterprise) address and not a stake address anymore! With Fund11 you will be able to delegate your Voting-Power to more than one Voting-Key. You can basically split your Voting-Power up to multiple Voting-Keys. Starting with Fund11 there will be a Web-based **Catalyst Voting Center** for dApp Wallets in parallel with the existing **Catalyst Voting App** for mobile devices.

**⚠ Attention using CIP36 for Fund10:**<br>
We can use this new format for Fund10, only restriction is to NOT split the Voting-Power to multiple Voting-Keys. So only a delegation with 100% Voting-Power is allowed. Also, the normal Catalyst Voting App will be used as usual, so you'll need a new QR-Code.

Below you will find a list of methods on how to do the registration in the new format. I have put this together to help you guys. Please report back any issues if you find some ... 🙂

Best regards, Martin (ATADA/ATAD2 Stakepool Austria)

&nbsp;<br>

## Quicklinks

* **[The simple way - Using the SPO-Scripts](#the-simple-way---using-the-spo-scripts-new)**: Doing it the quick way with the SPO-Scripts
* **[Step by step way on the CLI](#the-step-by-step-way-on-the-cli-new)**: Using cardano-signer and other tools for the registration.


<br>&nbsp;<br>

# The simple way - Using the SPO-Scripts :new:

<a href="https://github.com/gitmachtl/scripts/tree/master/cardano/mainnet"><img src="https://www.stakepool.at/pics/stakepool_operator_scripts.png" border=0 width=40% align=right></img></a><br>
If you are already using the SPO-Scripts, you're set to do it the simple way. If not, please copy/clone them from the [SPO-Scripts-Mainnet](https://github.com/gitmachtl/scripts/tree/master/cardano/mainnet) folder. All required executables/binaries are included in the repo. You still need your running cardano-node and cardano-cli of course. A detailed [README.md](https://github.com/gitmachtl/scripts/tree/master/cardano/mainnet#readme) about the feature and how to install/use the scripts can be found in the repo.

### Register funds of CLI-Keys, HYBRID-Keys or Hardware-Wallets

The SPO-Scripts repo contains the following binaries:
* [bech32](https://github.com/input-output-hk/bech32/releases/latest) v1.1.2
* [cardano-signer](https://github.com/gitmachtl/cardano-signer/releases/latest) v1.13.0
* [catalyst-toolbox](https://github.com/input-output-hk/catalyst-toolbox/releases/latest) v0.5.0

In case you wanna register funds from your **Hardware-Wallet**, please make sure to also install:
* [cardano-hw-cli](https://github.com/vacuumlabs/cardano-hw-cli/releases/tag/v1.12.0) **v1.12.0**
   and the Cardano-App on the HW-Wallet should be v5.0.1 for Ledger-HW-Wallets, and v2.6.0 for Trezor Model-T devices.<br>⚠ Please make sure to use those **exact versions**! In case there is a new release of the Cardano-App v6.0.3 via the Ledger-Live Desktop application, these documentation and the Voting-Script will get an update !<br>ℹ You can find further information [here](https://github.com/gitmachtl/scripts/tree/master/cardano/mainnet#how-to-prepare-your-system-before-using-a-hardware-wallet) on how to prepare your system to work with Hardware-Wallets.

<br>To **generate your Voting-Registration**, the **09a_catalystVoteF10.sh script** from the MainNet Repo is used, below are the 4 simple steps:
1. **[Generate a Voting-KeyPair](#1-generate-a-voting-keypair)**
2. **[Generate the VotingRegistration-Metadata-CBOR](#2-generate-the-votingregistration-metadata-cbor)**
3. **[Transmit the VotingRegistration-Metadata-CBOR file on chain](#3-transmit-the-votingregistration-metadata-cbor-file-on-the-chain)**
4. **[Generate the QR-Code for the Catalyst-Voting-App](#4-generate-the-qr-code-for-the-catalyst-voting-app)**

&nbsp;<br>


## 1. Generate a Voting-KeyPair

You need a Voting-KeyPair that gets the delegations of your "Voting-Power", these will be files saved as **name**.voting.skey/vkey/pkey. The Vote-Public-Key represents your Voting-Power on Catalyst. If you like, you can link your Voting-KeyPair with more than one Stake-Key to combine your "Voting-Power", but you need at least one such Voting-KeyPair. Also you can keep this Voting-KeyPair for future Votings, not needed to regenerate this again later. So lets create a Voting-Key with the name **myvote**.

<br><b>Steps:</b>
1. Run the following command to generate your Voting-KeyPair files and also a new Mnemonics to use it with a dApp Wallet:
``` console
./09a_catalystVoteF10.sh new cli myvote
```
2. Done

Files that have been created and derived from the CIP36 path `1694H/1815H/0H/0/0`:
* `myvote.voting.skey`: the vote secret key in json format `CIP36VoteExtendedSigningKey_ed25519`
* `myvote.voting.vkey`: the vote public key in json format `CIP36VoteVerificationKey_ed25519`
* `myvote.voting.pkey`: the vote public key in bech format, starting with `cvote_vk1...`
* `myvote.voting.mnemonics`: the 24-word mnemonics to use on a dApp enabled Wallet (like [eternl](https://eternl.io), [typhon](https://typhonwallet.io/)...)

💡Starting with Fund11, the voting will be available via the **Catalyst Voting Center** and transactions/signing confirmed via a dApp Wallet. For that you can generate the voting key on the CLI like above and use the generated Mnemonics.

&nbsp;<br>

## 2. Generate the VotingRegistration-Metadata-CBOR

You need to generate a VotingRegistration-Metadata CBOR file for each of your Stake-Keys your wanna vote with. In this step you must specify the following information:
* **Vote-Public-Key**: This can be the one from Step1 or an already existing Vote-Public-Key from somewhere else (f.e. exported from your dApp Wallet). The Vote-Public-Key will get the Voting-Power associated with the Stake-Key(s)
* **Stake-Account**: Thats a normal stake-file in SPO-Scripts format. It can be a CLI based `*.skey*` file, or a HW-Wallet based `*.hwsfile*` 😃
* **Reward-Payout-Account**: This can be one in the SPO-Scripts format, an Adahandle like `'$gitmachtl'` or a bech address like `addr1v9alunnka0sjm2px9ltwufrrj82yjy9qu45dpa7rze2h7agenhx54`

<br>Lets say we wanna vote with our Pool-Owner CLI-StakeAccount **cli-owner**, and we want to get the rewards back to the account **myrewards**.

<br><b>Steps:</b>
1. Run the following command to generate the VotingRegistration-Metadata CBOR file for your VotingKey-Account **myvote**.voting.vkey/pkey and your Stake-Account **cli-owner**.staking.skey:
``` console
./09a_catalystVoteF10.sh genmeta myvote cli-owner myrewards
```
2. Repeat the above step as often as you like to combine more Stake-Accounts into one Voting-Power (myvote)
3. Done

File that has been created:
* `cli-owner_230409185855.vote-registration.cbor`: contains the signed registration data in binary cbor format (230409185855 is just the current timestamp)

<br>Another example, lets say we wanna vote with our HW-Account on the Ledger-HW-Wallet **hw-wallet**, the rewards must also be paid back to the same HW-Wallet! The signing will be done on the HW-Wallet, so make sure to have it connected and the Cardano-App on the HW-Wallet is opened too.

<br><b>Steps:</b>
1. Run the following command to generate the VotingRegistration-Metadata CBOR file for your VotingKey-Account **myvote**.voting.vkey/pkey and your Stake-Account **hw-wallet**.staking.hwsfile. Rewards should be paid out to **hw-wallet**.payment.addr: 
``` console
./09a_catalystVoteF10.sh genmeta myvote hw-wallet hw-wallet.payment
```
2. Repeat the above step as often as you like to combine more Stake-Accounts into one Voting-Power (myvote)

File that has been created:
* `hw-wallet_230409185855.vote-registration.cbor`: contains the signed registration data in binary cbor format (230409185855 is just the current timestamp)

<br>Last example, lets say we wanna vote with a CLI-StakeAccount **acct4**, we want to delegate the Voting-Power to the Vote-Public-Key `cvote_vk1wntweq76kqy824ggzfhgtm9k0uydvu6zf09m2td58f2kune3ezws8jd2sw` and we want to get the rewards back to the address `addr1v9alunnka0sjm2px9ltwufrrj82yjy9qu45dpa7rze2h7agenhx54`.

<br><b>Steps:</b>
1. Run the following command to generate the VotingRegistration-Metadata CBOR file for your VotingKey-Account **myvote**.voting.vkey/pkey, your Stake-Account **acct4**.staking.skey and the rewards will be paid out to the address addr1v9alunnka0sjm2px9ltwufrrj82yjy9qu45dpa7rze2h7agenhx54:
``` console
./09a_catalystVoteF10.sh genmeta cvote_vk1wntweq76kqy824ggzfhgtm9k0uydvu6zf09m2td58f2kune3ezws8jd2sw acct4 addr1v9alunnka0sjm2px9ltwufrrj82yjy9qu45dpa7rze2h7agenhx54
```
2. Repeat the above step as often as you like to combine more Stake-Accounts into one Voting-Power (myvote)

File that has been created:
* `acct4_230409185855.vote-registration.cbor`: contains the signed registration data in binary cbor format (230409185855 is just the current timestamp)

&nbsp;<br>

## 3. Transmit the VotingRegistration-Metadata-CBOR file on the chain

The last thing you have to do to complete your VotingRegistration is to submit the generated VotingRegistration-Metadata CBOR file in a transaction on the chain. This can be any transaction like sending some lovelaces around, or sending some assets. The most simple command is to just send yourself the minimum amount of ADA (minUTXOValue) and include the CBOR file in that transaction. Lets say we wanna do this with a wallet-account with the name **mywallet**, you can also do this with a HW-Wallet account of course.

<br><b>Steps for transmitting the registration with minUTXOValue(min):</b>
1. Run the following command to transmit the generated VotingRegistration Metadata CBOR file (generated above) on the chain to complete the registration process:
``` console
./01_sendLovelaces.sh mywallet mywallet min cli-owner_230409185855.vote-registration.cbor
```
2. Done

The transaction can be made like any other transaction in **online** or in **offline** mode with the SPO-Scripts!

&nbsp;<br>

## 4. Generate the QR-Code for the Catalyst-Voting-App

You have successfully transmitted your voting registration onto the chain. To do the voting, we currently need a special QR-Code that you can scan with your Mobile-Phone and the Catalyst-Voting App to get access to your Voting-Power. Lets say we wanna use the Voting-Account from above in theses examples with the name **myvote** for that, and we wanna protect the Voting-App with the Pin-Code **8765**.

<br><b>Steps for creating the QR-Code:</b>
1. Run the following command to generate your CatalystApp-QR-Code for the Voting-Account **myvote**.voting.skey with the PinCode **8765**:
 ``` console
 ./09a_catalystVoteF10.sh qrcode myvote 8765
 ```
2. The QR-Code will be visable on the display. Also you can find a file **myvote**.catalyst-qrcode.png in the directory for later usage.
3. Scan the QR-Code with the latest version of the Catalyst-Voting-App on your mobile phone to get access to your Voting-Power
4. Done 

⚠ Your Voting-Power will be displayed in the Voting-App once the voting is open. 

⚠ With the Fund10 Voting Event, its only allowed to use CIP36 registration format with 100% Voting-Power delegation to a single VotingKey. So all the examples above are doing that. The description will be updated again for Fund11 to also give example on how to delegate your Voting-Power to multiple Vote-Public-Keys. But for now, please don't use that function for Fund10, thx!

<br>&nbsp;<br>

## (5. Query your Catalyst Voting-Key registration)

This step is optional and the current API is under development, but after you have transmitted your registration with Step-3, you can query the successful registration.

<br><b>Run the following command to verify your registration:</b>
1. Run the following command to verify your registration for the Voting-Account **myvote**.voting.skey:
 ``` console
 ./09a_catalystVoteF10.sh query myvote
 ```
2. Done 

You should now see your registered Voting-Power. If it does not show up yet, please let the Catalyst-API grap your registration first. This happens every few hours, so it could take some time.

ℹ️ You can also query the Voting-Key/Power for Keys in the bech format and hex format like:
 ``` console
 ./09a_catalystVoteF10.sh query cvote_vk1clzzuhduakxg9wvrdv5m9zfsr4c5qljthntuv3j78unez2dgkd0qya8rlp
 or
 ./09a_catalystVoteF10.sh query c7c42e5dbced8c82b9836b29b289301d71407e4bbcd7c6465e3f279129a8b35e
 ```

<br>&nbsp;<br>


# The step-by-step way on the CLI :new:

<img src="https://user-images.githubusercontent.com/47434720/190806957-114b1342-7392-4256-9c5b-c65fc0068659.png" width=40% align=right></img>
For those of you who wants to do it all in single steps on the CLI, please find below examples on how you can do so. Beside your running cardano-node with cardano-cli, please make sure to have the binaries listed below ready. Further down there is also an example on how to do a transaction on the cli, but i guess you know how to do a transaction on the CLI. 😄

## Required software/binaries

You will need the following software/binaries with the given minimal versions:
* [bech32](https://github.com/input-output-hk/bech32/releases/latest) v1.1.2
* [cardano-signer](https://github.com/gitmachtl/cardano-signer/releases/latest) v1.13.0
* [catalyst-toolbox](https://github.com/input-output-hk/catalyst-toolbox/releases/latest) v0.5.0

In case you wanna register funds from your **Hardware-Wallet**, please make sure to also install:
* [cardano-hw-cli](https://github.com/vacuumlabs/cardano-hw-cli/releases/tag/v1.12.0) **v1.12.0**
   and the Cardano-App on the HW-Wallet should be v5.0.1 for Ledger-HW-Wallets, and v2.6.0 for Trezor Model-T devices.<br>⚠ Please make sure to use those **exact versions**! In case there is a new release of the Cardano-App v6.0.3 via the Ledger-Live Desktop application, these documentation and the Voting-Script will get an update !<br>ℹ You can find further information [here](https://github.com/gitmachtl/scripts/tree/master/cardano/mainnet#how-to-prepare-your-system-before-using-a-hardware-wallet) on how to prepare your system to work with Hardware-Wallets.

<br>Below you will find the 4 easy steps:
1. **[Generate a Voting-KeyPair with Cardano-Signer](#1-generate-a-voting-keypair-with-cardano-signer)**
2. **[Generate the VotingRegistration-Metadata-CBOR](#2-generate-the-votingregistration-metadata-cbor-1)**
   1. **[For CLI-Keys](#2a-using-cardano-signer-for-signing-with-cli-keys)**
   1. **[For Hardware-Keys](#2b-using-cardano-hw-cli-for-signing-with-hardware-keys)**
3. **[Transmit the VotingRegistration-Metadata-CBOR file on the chain](#3-transmit-the-votingregistration-metadata-cbor-file-on-the-chain-1)**
4. **[Generate the QR-Code for the Catalyst-Voting-App](#4-generate-the-qr-code-for-the-catalyst-voting-app-1)**

&nbsp;<br>

## 1. Generate a Voting-KeyPair with Cardano-Signer

You need a Voting-KeyPair that gets the delegation(s) of your "Voting-Power", these will be files saved as **name**.voting.skey/vkey. The Vote-Public-Key represents your Voting-Power on Catalyst. If you like, you can link your Voting-KeyPair with more than one Stake-Key to combine your "Voting-Power", but you need at least one such Voting-KeyPair. Also you can keep this Voting-KeyPair for future Votings, not needed to regenerate this again later. 

Cardano-Signer offers you a variety of functions also for key generation, the options are:
```
Generate Cardano ed25519/ed25519-extended keys:

   Syntax: cardano-signer keygen
   Params: [--path "<derivationpath>"]                          optional derivation path in the format like "1852H/1815H/0H/0/0" or "1852'/1815'/0'/0/0"
                                                                or predefined names: --path payment, --path stake, --path cip36
           [--mnemonics "word1 word2 ... word24"]               optional mnemonic words to derive the key from (separate via space)
           [--cip36]                                            optional flag to generate CIP36 conform vote keys (also using path 1694H/1815H/0H/0/0)
           [--vote-purpose <unsigned_int>]                      optional vote-purpose (unsigned int) together with --cip36 flag, default: 0 (Catalyst)
           [--with-chain-code]                                  optional flag to generate a 128byte secretKey and 64byte publicKey with chain code
           [--json | --json-extended]                           optional flag to generate output in json/json-extended format
           [--out-file "<path_to_file>"]                        path to an output file, default: standard-output
           [--out-skey "<path_to_skey_file>"]                   path to an output skey-file
           [--out-vkey "<path_to_vkey_file>"]                   path to an output vkey-file
   Output: "secretKey + publicKey" or JSON-Format               default: hex-format
```

We only need a few parameters for now, so lets create a Voting-Key with the name **myvote**.

<br><b>Steps:</b>
1. Run the following command to generate your Voting-KeyPair files and also a JSON file with much more useful information: 
```console
cardano-signer keygen \
	--cip36 \
	--json-extended \
	--out-skey myvote.voting.skey \
	--out-vkey myvote.voting.vkey \
	--out-file myvote.voting.json
```
2. Done

Files that have been created and derived from the CIP36 path `1694H/1815H/0H/0/0`:
* `myvote.voting.skey`: the vote secret key in json format `CIP36VoteExtendedSigningKey_ed25519`
* `myvote.voting.vkey`: the vote public key in json format `CIP36VoteVerificationKey_ed25519`
* `myvote.voting.json`: extended information file in json format

Lets have a look on the content of the file `myvote.voting.json`:

``` json
{
  "workMode": "keygen-cip36",
  "path": "1694H/1815H/0H/0/0",
  "mnemonics": "meat animal shaft glass symbol wise betray rescue pledge mean satisfy opinion debate room broccoli quantum image whale alien warm history easily bracket crucial",
  "secretKey": "e8ee62fd8e3c891939004bc66a868db0736f64aab50669f5dc76aca752027b4ec170229463cdd8b43a537c8e7cf40195ce59a0fb67374fc5fb4486bf6d57a2be",
  "publicKey": "deade7caf3893af26b6b622009bffe58c5ca9d7b4cfb97349b250793ec534abf",
  "votePurpose": "Catalyst (0)",
  "secretKeyBech": "cvote_sk1arhx9lvw8jy3jwgqf0rx4p5dkpek7e92k5rxnawuw6k2w5sz0d8vzupzj33umk958ffhernu7sqetnje5rakwd60cha5fp4ld4t690sry93tl",
  "publicKeyBech": "cvote_vk1m6k70jhn3ya0y6mtvgsqn0l7trzu48tmfnaewdymy5re8mznf2lsx87lh2",
  "output": {
    "skey": {
      "type": "CIP36VoteExtendedSigningKey_ed25519",
      "description": "Catalyst Vote Signing Key",
      "cborHex": "5840e8ee62fd8e3c891939004bc66a868db0736f64aab50669f5dc76aca752027b4ec170229463cdd8b43a537c8e7cf40195ce59a0fb67374fc5fb4486bf6d57a2be"
    },
    "vkey": {
      "type": "CIP36VoteVerificationKey_ed25519",
      "description": "Catalyst Vote Verification Key",
      "cborHex": "5820deade7caf3893af26b6b622009bffe58c5ca9d7b4cfb97349b250793ec534abf"
    }
  }
}
```

As you can see, it contains additional informations such as the generated Mnemonics and also the Vote-Public-Key in Bech format `cvote_vk1...`

💡Starting with Fund11, the voting will be available via the **Catalyst Voting Center** and transactions/signing confirmed via a dApp Wallet. For that you can use the generated Mnemonics to link you CLI-Vote-Key with the dApp Wallet (restore from Mnemonics).

ℹ You can find a much more detailed description of the key-generation features of cardano-signer [here](https://github.com/gitmachtl/cardano-signer#keygeneration-mode)

<br>&nbsp;<br>

## 2. Generate the VotingRegistration-Metadata-CBOR

You need to generate a VotingRegistration-Metadata CBOR file for each of your Stake-Keys your wanna vote with. In this step you must specify the following information:
* **Vote-Public-Key**: This can be the one from Step1 or an already existing Vote-Public-Key from somewhere else (f.e. exported from your dApp Wallet). The Vote-Public-Key will get the Voting-Power associated with the Stake-Key(s)
* **Stake-Key**: Thats a normal Stake-key in `*.skey` cardano-cli format or `*.hwsfile` cardano-hw-cli format
* **Reward-Payout-Address**:  This is a normal base- or enterprise-address in bech format like `addr1...` 

Below you find two methods using cardano-signer for CLI-Keys and cardano-hw-cli for HW-Wallet-Keys

<br>&nbsp;<br>

### 2a. Using Cardano-Signer for signing with CLI-Keys

Lets say we wanna vote with our Pool-Owner CLI-Stake-Key **owner.stake.skey**, and we want to get the rewards back to the address **addr1v9alunnka0sjm2px9ltwufrrj82yjy9qu45dpa7rze2h7agenhx54**. 

Cardano-Signer offers you a variety of functions for CIP36 signing, the options are:
```
Sign a catalyst registration/delegation or deregistration in CIP-36 mode:

   Syntax: cardano-signer sign --cip36
   Params: [--vote-public-key "<path_to_file>|<hex>|<bech>"     public-key-file(s) or public hex/bech-key string(s) to delegate the votingpower to (single or multiple)
           --vote-weight <unsigned_int>]                        relative weight of each delegated votingpower, default: 100% for a single delegation
           --secret-key "<path_to_file>|<hex>|<bech>"           signing-key-file or a direct signing hex/bech-key string of the stake key (votingpower)
           --payment-address "<path_to_file>|<hex>|<bech>"      rewards payout address (address-file or a direct bech/hex format 'addr1..., addr_test1...')
           [--nonce <unsigned_int>]                             optional nonce value, if not provided the mainnet-slotHeight calculated from current machine-time will be used
           [--vote-purpose <unsigned_int>]                      optional parameter (unsigned int), default: 0 (catalyst)
           [--deregister]                                       optional flag to generate a deregistration (no --vote-public-key/--vote-weight/--payment-address needed
           [--testnet-magic [xxx]]                              optional flag to switch the address check to testnet-addresses, default: mainnet
           [--json | --json-extended]                           optional flag to generate output in json/json-extended format, default: cborHex(text)
           [--out-file "<path_to_file>"]                        path to an output file, default: standard-output
           [--out-cbor "<path_to_file>"]                        path to write a binary metadata.cbor file to
   Output: Registration-Metadata in JSON-, cborHex-, cborBinary-Format
```

But we only need a few parameters for now, so lets create the registration with the Voting-Key from step 1.

<br><b>Steps:</b>
1. Run the following command to generate the vote-registration.cbor CBOR file with minimal parameters
```console
cardano-signer sign --cip36 \
	--payment-address "addr1v9alunnka0sjm2px9ltwufrrj82yjy9qu45dpa7rze2h7agenhx54" \
	--vote-public-key myvote.voting.vkey \
	--secret-key owner.stake.skey \
	--out-cbor vote-registration.cbor
```
2. Done

File that has been created:
* `vote-registration.cbor`: contains the signed registration data in binary cbor format

In the example above we have used the minimal set of parameters to generate the correct data for Cardano-Mainnet. It defaults to vote-purpose = 0 (catalyst) and it also calculates the nonce from the current machine time. With CIP36 we also have the possibility to split the Voting-Power associated with a stake key to multiple Vote-Public-Keys. The above example only includes one Vote-Public-Key, so it defaults to 100% Voting-Power to the Vote-Public-Key. 

⚠ With the Fund10 Voting Event, its only allowed to use CIP36 registration format with 100% Voting-Power delegation to a single VotingKey. So all the examples above are doing that. The description will be updated again for Fund11 to also give example on how to delegate your Voting-Power to multiple Vote-Public-Keys. But for now, please don't use that function for Fund10, thx!

ℹ You can find a much more detailed description of the CIP36 signing feature of cardano-signer [here](https://github.com/gitmachtl/cardano-signer#cip-36-mode-catalyst-voting-registration--votingpower-delegation)

<br>&nbsp;<br>

### 2b. Using Cardano-HW-Cli for signing with Hardware-Keys

Lets say we wanna register our Hardware-Ledger-Key **hwstake.hwsfile**, and we want to get the rewards back to the address **addr1qp6fwmz547h5gnmu6jvmmpge4tr9j2cnkg4e6kqh7rd9c5sr6gz4xgyf45hhs95f9ch0g2zfk76j0z8yrvlagwnwq88sq0cm9e**, which is also on the Hardware Wallet.  We wanna use the vote-key that we generated in step 1. Make sure to have your HW-Wallet connected and ready.

<br><b>Steps:</b>
1. If you already have your `*.hwsfile` and other files generated via cardano-hw-cli, you can skip to step #2 , otherwise you can run this simple command to get your `hwstake.*` / `hwpayment.*` files: 
``` console
cardano-hw-cli address key-gen \
     --path 1852H/1815H/0H/2/0 \
     --verification-key-file hwstake.vkey \
     --hw-signing-file hwstake.hwsfile

cardano-hw-cli address key-gen \
     --path 1852H/1815H/0H/0/0 \
     --verification-key-file hwpayment.vkey \
     --hw-signing-file hwpayment.hwsfile
```

2. Get the current tip of the chain, we use it as the nonce value in step 3:
```console
#via cardano-cli
cardano-cli query tip --mainnet

#or via koios
curl -s -X GET "https://api.koios.rest/api/v0/tip"  -H "accept: application/json" | jq -r ".[0].abs_slot"
89501224
```

3. Run the following command to generate the vote-registration.cbor CBOR file, **use the nonce from step 2**.<br>
Make sure to use cardano-hw-cli version **1.12.0**! The newer version 1.13.0 is not compatible with the current Ledger-App 5.0.1!

``` console
cardano-hw-cli catalyst voting-key-registration-metadata --mainnet \
        --reward-address "addr1qp6fwmz547h5gnmu6jvmmpge4tr9j2cnkg4e6kqh7rd9c5sr6gz4xgyf45hhs95f9ch0g2zfk76j0z8yrvlagwnwq88sq0cm9e" \
        --reward-address-signing-key hwstake.hwsfile \
        --reward-address-signing-key hwpayment.hwsfile \
        --vote-public-key <(cat myvote.voting.vkey | jq -r .cborHex | cut -c 5- | bech32 "ed25519e_pk") \
        --stake-signing-key hwstake.hwsfile \
        --nonce 89501224 \
        --metadata-cbor-out-file vote-registration.cbor
```
4. Done

File that has been created:
* `vote-registration.cbor`: contains the signed registration data in binary cbor format

In the example above we have used the set of parameters to generate the correct data for Cardano-Mainnet. For Ledger HW-Wallets and the current cardano-app 5.0.1 we are limited to use a rewards payout address that is also on the same HW-Wallet than you're registering the stake key from. 

⚠ With the Fund10 Voting Event, its only allowed to use CIP36 registration format with 100% Voting-Power delegation to a single VotingKey. So all the examples above are doing that. The description will be updated again for Fund11 to also give example on how to delegate your Voting-Power to multiple Vote-Public-Keys. But for now, please don't use that function for Fund10, thx!

ℹ You can find a much more detailed description of the parameters for cardano-hw-cli [here](https://github.com/vacuumlabs/cardano-hw-cli/tree/develop/docs)

<br>&nbsp;<br>

## 3. Transmit the VotingRegistration-Metadata-CBOR file on the chain

The last thing you have to do to complete your VotingRegistration is to submit the generated VotingRegistration-Metadata CBOR file in a transaction on the chain. This can be any transaction like sending some lovelaces around, or sending some assets. Please find below an example on how to transmit a simple transaction:

Make sure your environment variable **CARDANO_NODE_SOCKET_PATH** is pointing to a running fully synced 
cardano node (just a simple passive one is ok), for example:

``` console
export CARDANO_NODE_SOCKET_PATH=db-mainnet/node.socket
```

Set the network and get the current chain-tip:

``` console
export NETWORK_ID="--mainnet"
export SLOT_TIP=$(cardano-cli query tip $NETWORK_ID | jq '.slot')
```

Next, we need to add this transaction metadata to a transaction and submit it to the chain.

First we'll grab the protocol parameters:

``` console
cardano-cli query protocol-parameters \
    $NETWORK_ID \
    --out-file protocol.json
```

And find some funds to use:

We need a payment address, this should **NOT BE YOUR PLEDGE ADDRESS**! Just a simple
payment address to pay for the transaction, we call it **payment** and the address is already stored in `payment.addr`:

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

Here we'll make a draft transaction for the purposes of fee estimation. This transaction will simply send the entire UTxO value back to us, minus the fee. We don't need to send money anywhere else, we simply have to make a valid transaction with the metadata attached.

``` console
cardano-cli transaction build-raw \
    --tx-in $UTXO#$UTXO_TXIX \
    --tx-out $(cat payment.addr)+0 \
    --invalid-hereafter 0 \
    --fee 0 \
    --metadata-cbor-file vote-registration.cbor \
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
    --metadata-cbor-file vote-registration.cbor \
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

<br>&nbsp;<br>

## 4. Generate the QR-Code for the Catalyst-Voting-App

You have successfully transmitted your voting registration onto the chain. To do the voting, we currently need a special QR-Code that you can scan with your Mobile-Phone and the Catalyst-Voting App to get access to your Voting-Power. Lets say we wanna use the Voting-Account from above in theses examples. We have stored the vote secret key in `myvote.voting.skey`, we wanna protect the QR-Code with the Pin-Code **8765**.

<br><b>Command for creating the QR-Code:</b>

There is a handy little tool called **qr-code** available as part of `catalyst-toolbox`for that. Run the following command to generate your CatalystApp-QR-Code from the `myvote.voting.skey` file with the PinCode **8765**:
 ``` console
 ./catalyst-toolbox qr-code encode \
     --pin 8765 \
     --input <(cat myvote.voting.skey | jq -r .cborHex | cut -c 5-132 | bech32 "ed25519e_sk") \
     img
 ```

This will show you the QR code on screen and you can use it with the Catalyst Voting App. :-)

If you wanna save the QR code for later, you can save it as a PNG image too using the -output parameter like:
 ``` console
 ./catalyst-toolbox qr-code encode \
     --pin 8765 \
     --input <(cat myvote.voting.skey | jq -r .cborHex | cut -c 5-132 | bech32 "ed25519e_sk") \
     --output myvote.qrcode.png \
     img
 ```

This will generate the QR code as the file **myvote.qrcode.png**

⚠ Your Voting-Power will be displayed in the Voting-App once the voting is open. 

⚠ With the Fund10 Voting Event, its only allowed to use CIP36 registration format with 100% Voting-Power delegation to a single VotingKey. So all the examples above are doing that. The description will be updated again for Fund11 to also give example on how to delegate your Voting-Power to multiple Vote-Public-Keys. But for now, please don't use that function for Fund10, thx!

<br>&nbsp;<br>

## Happy voting !
