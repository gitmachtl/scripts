# Governance Scripts

This document describes the different governance scripts of the SPO-Scripts collection. How to use them with simply CLI keys and also HW-Wallets.

The governance scripts are divided into different topics, every topic has its own starting number:

### [DRep Key Operations](#drep-key-operations-1)
- [21a_genDRepKeys.sh](#1-generating-drep-key-options) -> Generate
- [21b_regDRepCert.sh](#2-register-or-update-drep-key-options) -> Register & Update
- 21c_checkDRepOnChain.sh -> Check
- 21d_retDRepCert.sh -> Retire

### VotingPower Delegation
- 22a_genVoteDelegCert.sh -> Generate
- 22b_regVoteDelegCert.sh -> Register

### Constitutional Committee Key Operations
- 23a_genComColdKeys.sh -> Generate
- 23b_genComHotKeys.sh -> Generate
- 23c_regComAuthCert.sh -> Register
- 23d_checkComOnChain.sh -> Check
- 23e_retComColdKeys.sh -> Retire

### Generate, Submit and Query of votes on Governance actions
- 24a_genVote.sh -> Generate
- 24b_regVote.sh -> Register
- 24c_queryVote.sh -> Check

### Generate and Submit of Governance actions
- 25a_genAction.sh -> Generate
- 25b_regAction.sh -> Register

-----

## DRep Key Operations

### 1. Generating DRep-Key options
To generate DRep-Keys that you can use on the CLI, Light-Wallet or Hardware-Wallet, we use script 21a:
```console
Usage: 21a_genDRepKeys.sh <DRep-Name> <KeyType: cli | enc | hw | mnemonics>

Optional parameters:

   ["Idx: 0-2147483647"] Sets the IndexNo of the DerivationPath for HW-Keys and CLI-Mnemonics: 1852H/1815H/*H/3/<IndexNo> (default: 0)
   ["Acc: 0-2147483647"] Sets the AccountNo of the DerivationPath for HW-Keys and CLI-Mnemonics: 1852H/1815H/<AccountNo>H/3/* (default: 0)
   ["Mnemonics: 24-words-mnemonics"] To provide a given set of 24 mnemonic words to derive the CLI-Mnemonics keys, otherwise new ones will be generated.

Examples:
21a_genDRepKeys.sh drep cli             ... generates DRep keys (no mnemonic/passphrase support)
21a_genDRepKeys.sh drep enc             ... generates DRep keys + encrypted via a Password
21a_genDRepKeys.sh drep hw              ... generates DRep keys using Ledger/Trezor HW-Wallet (Normal-Path 1852H/1815H/<Acc>/3/<Idx>)
21a_genDRepKeys.sh drep mnemonics       ... generates DRep keys and also generate Mnemonics for LightWallet import possibilities

Examples with Mnemonics:
21a_genDRepKeys.sh drep2 mnemonics "mnemonics: word1 word2 ... word24"  ... generates DRep keys from the given 24 Mnemonic words (Path 1852H/1815H/<Acc>/3/<Idx>)
21a_genDRepKeys.sh drep2 mnemonics "acc:4" "idx:5"  ... generates DRep keys and new Mnemonics for the path 1852H/1815H/H4/3/5

Example with Hardware-Account/Index-Numbers:
21a_genDRepKeys.sh drep3 hw "acc:1"        ... generates DRep keys using Ledger/Trezor HW-Keys and SubAccount# 1, Index# 0
```

### Generating DRep-Keys for CLI only usage
Lets use the name `myDrep` for the example below.
```console
$ ./21a_genDRepKeys.sh myDrep cli

Version-Info: cli 9.3.0.0               Mode: online(light)     Era: conway     Testnet: SanchoNet (magic 4)

koiosAPI-ProjID: --- (Public-Tier) valid until 'no expire date'

DRep-Verification-Key:  myDrep.drep.vkey
{
    "type": "DRepVerificationKey_ed25519",
    "description": "Delegated Representative Verification Key",
    "cborHex": "5820fe4a2e5abb2d87227b5f84eeea50d8ab25250e8ba2af487c9a13595289363e0f"
}

DRep-Signing-Key:  myDrep.drep.skey
{
    "type": "DRepSigningKey_ed25519",
    "description": "Delegated Representative Signing Key",
    "cborHex": "5820be88feb8a6fcd0e0625bdf46920d2630a4f2ad0770f61d0245a9f1b265479315"
}

DRep-ID built:  myDrep.drep.id
drep19zhgxz7ay7hrs2zfgw59na4x52neldxn7098pynxjgq05k8s2n6

If you wanna register the DRep-ID now, please run the script 21b_regDRepCert.sh !
```

### Generating encrypted DRep-Keys for CLI only usage
Lets use the name `mySecureDRep` for the example below.
```console
$ ./21a_genDRepKeys.sh mySecureDrep enc

Version-Info: cli 9.3.0.0               Mode: online(light)     Era: conway     Testnet: SanchoNet (magic 4)

koiosAPI-ProjID: --- (Public-Tier) valid until 'no expire date'

DRep-Verification-Key:  mySecureDrep.drep.vkey
{
    "type": "DRepVerificationKey_ed25519",
    "description": "Delegated Representative Verification Key",
    "cborHex": "5820a005a1e659bc3ad1ccb475f7bdc623368879c5e029e448aff0f2bb4975654f42"
}

Please provide a strong password (min. 10 chars, uppercase, lowercase, specialchars) for the encryption ...

Enter a strong Password for the DRep-SKEY (empty to abort): ***********
Confirm the strong Password (empty to abort): ***********
Passwords match

Do you want to show the password for 5 seconds on screen to check it? [y/N]

Writing the file 'mySecureDrep.drep.skey' to disc ... OK

DRep-Signing-Key:  mySecureDrep.drep.skey
{
  "type": "DRepSigningKey_ed25519",
  "description": "Encrypted Delegated Representative Signing Key",
  "encrHex": "8c0d04090302d7c9033d5d7e1877ffd26f0128a0c3218e0ddfb83465c0548e3d50f0aed6a6ca347e9f5ceed166e6db2c16d6cfbed3a8050209782e377657c0b8e90f68988fc2e027276429f38f5d34349c2948fd8d70dc7f4eb3da99050b8b5d0930836f47c0406459cc4d91e19a2f30a4d2625610902db3f60a15a89c237059"
}

DRep-ID built:  mySecureDrep.drep.id
drep182jsxnd9trne52tm8rv5zxy9eqm7uph8eurjt909445t5c4wagr

If you wanna register the DRep-ID now, please run the script 21b_regDRepCert.sh !
```

### Generating DRep-Keys with Mnemonics for CLI and Light-Wallet usage
If you wanna be flexible and you wanna make sure that you can use your DRep-Key on the CLI and also be able to import it into a Light-Wallet, you can generate the key from Mnemonics or you can provide Mnemonics from your existing Light-Wallet to import them to the CLI.
```console
$ ./21a_genDRepKeys.sh myLightDrep mnemonics
```
```js
Version-Info: cli 9.3.0.0               Mode: online(light)     Era: conway     Testnet: SanchoNet (magic 4)

koiosAPI-ProjID: --- (Public-Tier) valid until 'no expire date'

Generating CLI DRep-Keys via Derivation-Path: 1852H/1815H/0H/3/0

Using Cardano-Signer Version: 1.18.0

Created Mnemonics: wash ginger craft eyebrow company lazy pilot yellow chapter napkin promote never emotion right develop stamp option excuse wave lobster want garlic arch typical
Mnemonics written to file: myLightDrep.drep.mnemonics

DRep-Verification-Key (Acc# 0, Idx# 0):  myLightDrep.drep.vkey
{
  "type": "DRepVerificationKey_ed25519",
  "description": "Delegate Representative Verification Key",
  "cborHex": "58209194a841a69974059a23e93582e12123edbf0c28146be739c44c3884be5d89de"
}

DRep-Signing-Key (Acc# 0, Idx# 0):  myLightDrep.drep.skey
{
  "type": "DRepExtendedSigningKey_ed25519_bip32",
  "description": "Delegate Representative Signing Key",
  "cborHex": "5880908d338e1cae38c14e930c0dd465aedd367a6a0e4c851b7ae4422d471431425e99da3491ad7cf6289b19c63e5163ce47fb1395a189516c47ef94854c4f62f23d9194a841a69974059a23e93582e12123edbf0c28146be739c44c3884be5d89de7a24b3feab1ce458e99e781e426589cb65b52a0a9cf40d57db17f0ee5cdebd33"
}

DRep-ID built:  myLightDrep.drep.id
drep15l5z8j6xwnf05f4j0hhfk9vxr2kvq9srxg476he7hlgwyf8ekgj

If you wanna register the DRep-ID now, please run the script 21b_regDRepCert.sh !
```
As you can see, this generated a DRep key named `myLightDrep` with a secret key for the CLI, but also with 24 Mnemonic words for later usage in a Light-Wallet

### Generating DRep-Key with a Hardware-Wallet
As easy as with the examples above, its the same with a Hardware-Wallet. Currently Ledger and Trezor wallets are supported via cardano-hw-cli.
To generate a DRep-Key with name `myHwDRep` we can simply call script 21a like
```console
##############################
##############################
##############################
```


### 2. Register or Update DRep-Key options
To register DRep-Keys on the chain you are using script 21b:
```console
$ ./21b_regDRepCert.sh
```
```js
Version-Info: cli 9.3.0.0               Mode: online(light)     Era: conway     Network: Mainnet

koiosAPI-ProjID: sposcripts (Free-Tier) valid until 'Mi 01 Jän 2025 21:56:02 CET'

Usage:  21b_regDRepCert.sh <DRep-Name> <Base/PaymentAddressName (paying for the registration fees)>

        [Opt: Anchor-URL, starting with "url: ..."], in Online-/Light-Mode the Hash will be calculated
        [Opt: Anchor-HASH, starting with "hash: ..."], to overwrite the Anchor-Hash in Offline-Mode
        [Opt: Message comment, starting with "msg: ...", | is the separator]
        [Opt: encrypted message mode "enc:basic". Currently only 'basic' mode is available.]
        [Opt: passphrase for encrypted message mode "pass:<passphrase>", the default passphrase if 'cardano' is not provided]

Optional parameters:

- If you wanna attach a Transaction-Message like a short comment, invoice-number, etc with the transaction:
   You can just add one or more Messages in quotes starting with "msg: ..." as a parameter. Max. 64chars / Message
   "msg: This is a short comment for the transaction" ... that would be a one-liner comment
   "msg: This is a the first comment line|and that is the second one" ... that would be a two-liner comment, | is the separator !

   If you also wanna encrypt it, set the encryption mode to basic by adding "enc: basic" to the parameters.
   To change the default passphrase 'cardano' to you own, add the passphrase via "pass:<passphrase>"

- If you wanna attach a Metadata JSON:
   You can add a Metadata.json (Auxilierydata) filename as a parameter to send it alone with the transaction.
   There will be a simple basic check that the transaction-metadata.json file is valid.

- If you wanna attach a Metadata CBOR:
   You can add a Metadata.cbor (Auxilierydata) filename as a parameter to send it along with the transaction.
   Catalyst-Voting for example is done via the voting_metadata.cbor file.

Examples:

   21b_regDRepCert.sh myDRep myWallet.payment
   -> Register the DRep-ID of myDRep (myDRep.drep.*) on Chain, Payment via the myWallet.payment wallet

   21b_regDRepCert.sh myDRep myWallet.payment "msg: DRep-ID Registration for myWallet"
   -> Register the DRep-ID of myDREP (myDRep.drep.*) on Chain, Payment via the myWallet.payment wallet, Adding a Transaction-Message
```

### Register/Update a DRep-Key with a CLI-Wallet
We created a new DRep before with the name `myDrep` lets register it on chain as a private DRep -> without a linked DRep-Metadata file/url.
Using the CLI-Wallet with name `funds` to pay for the registration and the **500 Ada DRep-Deposit-Fee**.
```console
$ ./21b_regDRepCert.sh myDrep funds
```
```js
Version-Info: cli 9.3.0.0 / node 9.1.0          Mode: online(full)      Era: conway     Testnet: SanchoNet (magic 4)

Register DRep-ID using myDrep.drep.vkey with funds from Address funds.addr

Checking Information about the DRep-ID: drep19zhgxz7ay7hrs2zfgw59na4x52neldxn7098pynxjgq05k8s2n6

DRep-ID is NOT on the chain, we will continue to register it ...

Generate Registration-Certificate with the currently set deposit fee: 500000000 lovelaces

DRep-ID Registration-Certificate built: myDrep.drep-reg.cert
{
    "type": "CertificateConway",
    "description": "DRep Key Registration Certificate",
    "cborHex": "84108200581c28ae830bdd27ae38284943a859f6a6a2a79fb4d3f3ca7092669200fa1a1dcd6500f6"
}

Current Slot-Height: 38666935 (setting TTL[invalid_hereafter] to 38766935)

Pay fees from Address funds.addr: addr_test1vpfwv0ezc5g8a4mkku8hhy3y3vp92t7s3ul8g778g5yegsgalc6gc

1 UTXOs found on the Source Address!

Hash#Index: 64eb0af820a6211662ba8fdd6bb6cf5e1b88d59f9353eda97096c729fc6392e8#0  ADA: 100.009,307108 (100009307108 lovelaces)
-----------------------------------------------------------------------------------------------------
Total ADA on the Address:  100.009,307108 ADA / 100009307108 lovelaces

Mimimum transfer Fee for 1x TxIn & 1x TxOut & 1x Certificate:  0,170869 ADA / 170869 lovelaces

DRep-ID Deposit Fee:  500,000000 ADA / 500000000 lovelaces

Mimimum funds required for registration (Sum of fees):  501028559 lovelaces

Lovelaces that will be returned to payment Address (UTXO-Sum minus fees):  99.509,136239 ADA / 99509136239 lovelaces  (min. required 857690 lovelaces)

Building the unsigned transaction body with the myDrep.drep-reg.cert certificate:  /tmp/funds.txbody

{
    "type": "Unwitnessed Tx ConwayEra",
    "description": "Ledger Cddl Format",
    "cborHex": "84a500d901028182582064eb0af820a6211662ba8fdd6bb6cf5e1b88d59f9353eda97096c729fc6392e800018182581d6052e63f22c5107ed776b70f7b92248b02552fd08f3e747bc7450994411b000000172b34eb6f021a00029b75031a024f895704d901028184108200581c28ae830bdd27ae38284943a859f6a6a2a79fb4d3f3ca7092669200fa1a1dcd6500f6a0f5f6"
}

Reading unencrypted file funds.skey ... OK

Reading unencrypted file myDrep.drep.skey ... OK

Sign the unsigned transaction body with the funds.skey & myDrep.drep.skey:  /tmp/funds.tx

{
    "type": "Witnessed Tx ConwayEra",
    "description": "Ledger Cddl Format",
    "cborHex": "84a500d901028182582064eb0af820a6211662ba8fdd6bb6cf5e1b88d59f9353eda97096c729fc6392e800018182581d6052e63f22c5107ed776b70f7b92248b02552fd08f3e747bc7450994411b000000172b34eb6f021a00029b75031a024f895704d901028184108200581c28ae830bdd27ae38284943a859f6a6a2a79fb4d3f3ca7092669200fa1a1dcd6500f6a100d9010282825820fe4a2e5abb2d87227b5f84eeea50d8ab25250e8ba2af487c9a13595289363e0f5840def143907102d15c47abccd0c5824d58fe17b96805b778d1fc5216972e36070b80eaabb073ae8768b6112f7d6c413b8de8cc3fc68987bdaabcdc887068aa0703825820742d8af3543349b5b18f3cba28f23b2d6e465b9c136c42e1fae6b2390f5654275840dfb9ee9605ab175b9c5c02c6941fbc20da9e8057c5d3ddffac8e32536624c2250b5abc9791b748bd259c0f73ae9f1422e522bb2e3365ec4734878cb6a51b2303f5f6"
}

Transaction-Size: 353 bytes (max. 16384)

Does this look good for you, continue ? [y/N]
DONE

 TxID is: e633128bb72a96bfd20ab029bf696a0b501de8b6dadaba7905aa60b9eb976c73
```
As you can see, above, the process was identified as a DRep-Registration. If you already registered a DRep, it will automatically switch to a DRep-Update process. The difference is that you only need to pay the 500 Ada Deposit-Fee once during the first registration.

### Register/Update a DRep-Key with a HW-Wallet
We created a new DRep before on a Ledger-HW-Wallet with the name `myLedgerDrep` lets register it on chain as a public DRep -> with a linked DRep-Metadata file/url.
The script 21b will try to download the given DRep-Metadata file to get the fileHash of it, which is also part of the registration.
So make sure to upload your DRep-Metadata file to a public server before you run 21b!
Using the HW-Wallet with name `ledger` to pay for the registration and the **500 Ada DRep-Deposit-Fee**.
```console
$ ./21b_regDRepCert.sh myLedgerDrep ledger "url: https://raw.githubusercontent.com/gitmachtl/scripts/master/cardano/testnet/dummy_drep_metadata.json"
```


## DRep-Metadata
We used a DRep-Metadata file above, this is only needed for a public DRep.
- Private DRep: There is typically no extra DRep-Metadata linked with the registration. Only information visable on chain is the DRep-ID itself.
- Public DRep: If you wanna be a public DRep and you wanna post additional Infos about yourself, DRep-Metadata in the form of a `JSON` file comes into play.
  The DRep-Metadata JSON File follows [CIP-119](https://cips.cardano.org/cip/CIP-0119) which builds on [CIP-100](https://cips.cardano.org/cip/CIP-0100)

