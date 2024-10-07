# Governance Scripts

This document describes the different governance scripts of the SPO-Scripts collection. How to use them with simply CLI keys and also HW-Wallets.

The governance scripts are divided into different topics, every topic has its own starting number:

### [DRep Key Operations](#drep-key-operations-1)
- [21a_genDRepKeys.sh](#1-generating-drep-key-options) -> Generate
- [21b_regDRepCert.sh](#2-register-or-update-drep-key-options) -> Register & Update
- [21c_checkDRepOnChain.sh](#3-check-drep-iddata-information) -> Check
- [21d_retDRepCert.sh](#4-retireremove-a-drep-key) -> Retire

### [VotingPower Delegation](#votingpower-delegation-1)
- [22a_genVoteDelegCert.sh](#1-generate-the-vote-delegation-certificate) -> Generate
- [22b_regVoteDelegCert.sh](#2-register-the-vote-delegation-certificate) -> Register
- [03c_checkStakingAddrOnChain.sh](#3-check-the-current-vote-power-delegation) -> Check

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
```
```js
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
```
```js
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
To generate a DRep-Key with name `myLedgerDrep` we can simply call script 21a like
```console
$ ./21a_genDRepKeys.sh myLedgerDrep hw
```
```js
Version-Info: cli 9.3.0.0 / node 9.1.0          Mode: online(full)      Era: conway     Testnet: SanchoNet (magic 4)

Generating HW-DRep Keys via Derivation-Path: 1852H/1815H/0H/3/0

Cardano App Version 7.1.3 (HW-Cli Version 1.16.0-rc.1) found on your Ledger device!
Please approve the action on your Hardware-Wallet (abort with CTRL+C) ... DONE

DRep-Verification-Key (Acc# 0, Idx# 0):  myLedgerDrep.drep.vkey
{
  "type": "DRepVerificationKey_ed25519",
  "description": "Hardware Delegate Representative Verification Key",
  "cborHex": "5820d119efdfb35a24eb8df3ecf0b82ae6859632d6bc2479da0ecd85d1d7bbd7d4d1"
}

DRep-HardwareSigning-File (Acc# 0, Idx# 0):  myLedgerDrep.drep.hwsfile
{
    "type": "DRepHWSigningFile_ed25519",
    "description": "Hardware Delegate Representative Signing File",
    "path": "1852H/1815H/0H/3/0",
    "cborXPubKeyHex": "5840d119efdfb35a24eb8df3ecf0b82ae6859632d6bc2479da0ecd85d1d7bbd7d4d1c7d994f5f5affa0391b47055a529db20ec02288b0e26b324d2aec1d2088c376e"
}
DRep-ID built:  myLedgerDrep.drep.id
drep1l50flvf7lxjtm5x8u3aw7zluqe0v5mz2exmp8psueusvktql43a

If you wanna register the DRep-ID now, please run the script 21b_regDRepCert.sh !
```

-----

### 2. Register or Update DRep-Key options
To register DRep-Keys on the chain we are using script 21b:
```console
$ ./21b_regDRepCert.sh

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

So make sure to upload your DRep-Metadata file to a public server before you run 21b! I converted the url to a short one.

Using the HW-Wallet with name `ledger` to pay for the registration and the **500 Ada DRep-Deposit-Fee**.

```console
$ ./21b_regDRepCert.sh myLedgerDrep ledger "url: "url: https://shorturl.at/rykvG"
```
```js
Version-Info: cli 9.3.0.0 / node 9.1.0          Mode: online(full)      Era: conway     Testnet: SanchoNet (magic 4)

Register DRep-ID using myLedgerDrep.drep.vkey with funds from Address ledger.payment.addr

New Anchor-URL(HASH): https://shorturl.at/rykvG (483e2e5fc077dd3e61c521e4b417fcaf881656a9af8f12cc36b418f98565ed76)

Checking Information about the DRep-ID: drep1l50flvf7lxjtm5x8u3aw7zluqe0v5mz2exmp8psueusvktql43a

DRep-ID is NOT on the chain, we will continue to register it ...

Generate Registration-Certificate with the currently set deposit fee: 500000000 lovelaces

DRep-ID Registration-Certificate built: myLedgerDrep.drep-reg.cert
{
    "type": "CertificateConway",
    "description": "DRep Key Registration Certificate",
    "cborHex": "84108200581cfd1e9fb13ef9a4bdd0c7e47aef0bfc065eca6c4ac9b613861ccf20cb1a1dcd650082781968747470733a2f2f73686f727475726c2e61742f72796b76475820483e2e5fc077dd3e61c521e4b417fcaf881656a9af8f12cc36b418f98565ed76"
}

Current Slot-Height: 38669396 (setting TTL[invalid_hereafter] to 38769396)

Pay fees from Address ledger.payment.addr: addr_test1qp6fwmz547h5gnmu6jvmmpge4tr9j2cnkg4e6kqh7rd9c5sr6gz4xgyf45hhs95f9ch0g2zfk76j0z8yrvlagwnwq88sq0cm9e

1 UTXOs found on the Source Address!

Hash#Index: 2a576b70283ee088eb61620089e203a7ee16cf8339d35dbf17af164cee19ba45#1  ADA: 231.466,728128 (231466728128 lovelaces)
-----------------------------------------------------------------------------------------------------
Total ADA on the Address:  231.466,728128 ADA / 231466728128 lovelaces

Mimimum transfer Fee for 1x TxIn & 1x TxOut & 1x Certificate:  0,174785 ADA / 174785 lovelaces

DRep-ID Deposit Fee:  500,000000 ADA / 500000000 lovelaces

Mimimum funds required for registration (Sum of fees):  501153155 lovelaces

Lovelaces that will be returned to payment Address (UTXO-Sum minus fees):  230.966,553343 ADA / 230966553343 lovelaces  (min. required 978370 lovelaces)

Building the unsigned transaction body with the myLedgerDrep.drep-reg.cert certificate:  /tmp/ledger.payment.txbody

{
    "type": "Unwitnessed Tx ConwayEra",
    "description": "Ledger Cddl Format",
    "cborHex": "84a500d90102818258202a576b70283ee088eb61620089e203a7ee16cf8339d35dbf17af164cee19ba450101818258390074976c54afaf444f7cd499bd8519aac6592b13b22b9d5817f0da5c5203d205532089ad2f7816892e2ef42849b7b52788e41b3fd43a6e01cf1b00000035c6adeaff021a0002aac1031a024f92f404d901028184108200581cfd1e9fb13ef9a4bdd0c7e47aef0bfc065eca6c4ac9b613861ccf20cb1a1dcd650082781968747470733a2f2f73686f727475726c2e61742f72796b76475820483e2e5fc077dd3e61c521e4b417fcaf881656a9af8f12cc36b418f98565ed76a0f5f6"
}

Autocorrect the TxBody for canonical order: Writing to file '/tmp/ledger.payment.txbody-corrected'.

{
    "type": "Unwitnessed Tx ConwayEra",
    "description": "Ledger Cddl Format",
    "cborHex": "84a500d90102818258202a576b70283ee088eb61620089e203a7ee16cf8339d35dbf17af164cee19ba450101818258390074976c54afaf444f7cd499bd8519aac6592b13b22b9d5817f0da5c5203d205532089ad2f7816892e2ef42849b7b52788e41b3fd43a6e01cf1b00000035c6adeaff021a0002aac1031a024f92f404d901028184108200581cfd1e9fb13ef9a4bdd0c7e47aef0bfc065eca6c4ac9b613861ccf20cb1a1dcd650082781968747470733a2f2f73686f727475726c2e61742f72796b76475820483e2e5fc077dd3e61c521e4b417fcaf881656a9af8f12cc36b418f98565ed76a0f5f6"
}

Sign (Witness+Assemble) the unsigned transaction body with the ledger.payment.hwsfile & myLedgerDrep.drep.hwsfile:  /tmp/ledger.payment.tx

Please connect & unlock your Hardware-Wallet, open the Cardano-App on Ledger-Devices (abort with CTRL+C)
...
```
You can see at the top, that the script shows the new Anchor-URL and the calculated Hash. The rest is the same as with a normal registration/update.

-----

## DRep-Metadata
We used a DRep-Metadata file above, this is only needed for a public DRep.

- Private DRep: There is typically no extra DRep-Metadata linked with the registration. Only information visable on chain is the DRep-ID itself.
- Public DRep: If you wanna be a public DRep and you wanna post additional Infos about yourself, DRep-Metadata in the form of a `JSON` file comes into play.
  The DRep-Metadata JSON File follows [CIP-119](https://cips.cardano.org/cip/CIP-0119) which builds on [CIP-100](https://cips.cardano.org/cip/CIP-0100)

I have uploaded a dummy one for you in the `testnet` folder of the repo, check it out -> https://github.com/gitmachtl/scripts/tree/master/cardano/testnet

P.S.: There is still a discussion going on about what fields in the Metadata file are required/allowed/disallowed.

-----

### 3. Check DRep-ID/Data Information
To get information on DRep-Keys/IDs we use script 21c:
```console
$ ./21c_checkDRepOnChain.sh

Version-Info: cli 9.3.0.0 / node 9.1.0          Mode: online(full)      Era: conway     Testnet: SanchoNet (magic 4)

Usage:  21c_checkDRepOnChain.sh <DRep-Name | DRepID-Hex | DRepID-Bech "drep1.../drep_script1...">
```
Syntax is super easy, just give it a DRep-Name (of a local made file), a DRep-ID in hex or bech format.

Example:
```console
$ ./21c_checkDRepOnChain.sh myDrep
```
```js
Version-Info: cli 9.3.0.0 / node 9.1.0          Mode: online(full)      Era: conway     Testnet: SanchoNet (magic 4)

Using Cardano-Signer Version: 1.18.0

Checking DRep-Information on Chain - Resolve given Info into DRep-ID:

Convert from Verification-Key-File myDrep.drep.vkey ... OK

Regular DRep-ID: drep19zhgxz7ay7hrs2zfgw59na4x52neldxn7098pynxjgq05k8s2n6
 CIP129 DRep-ID: drep1yg52aqctm5n6uwpgf9p6sk0k563208a560eu5uyjv6fqp7scrkyjt
      DRep-HASH: 28ae830bdd27ae38284943a859f6a6a2a79fb4d3f3ca7092669200fa

    DRep-Status: ✅ registered on the chain!

 Deposit-Amount: 500,000000 ADA
   Expire-Epoch: 467
  Current-Epoch: 447
   DRep-KeyType: keyHash
     Anchor-URL: https://raw.githubusercontent.com/gitmachtl/cardano-related-stuff/master/MartinLang_DRep.json
    Anchor-HASH: 0d7b90948320a9d5bfebc158bc674996df8dd65daab27a0c373b6750d1aa7246
Delegated-Stake: 0,000000 ADA

      Query-URL: https://raw.githubusercontent.com/gitmachtl/cardano-related-stuff/master/MartinLang_DRep.json
  Anchor-Status: ✅ File-Content-HASH is ok
    Anchor-Data: ✅ JSONLD structure is ok

      Signature: ✅ Martin Lang
```

```console
$ ./21c_checkDRepOnChain.sh drep1mkmnzmtlflcadyyy7g6ju3sn9ppcrut5wn73x00mfwmw642g5qy
```
```js
Version-Info: cli 9.3.0.0 / node 9.1.0          Mode: online(full)      Era: conway     Testnet: SanchoNet (magic 4)

Using Cardano-Signer Version: 1.18.0

Checking DRep-Information on Chain - Resolve given Info into DRep-ID:

Check if given Bech-ID is valid ... OK

Regular DRep-ID: drep1mkmnzmtlflcadyyy7g6ju3sn9ppcrut5wn73x00mfwmw642g5qy
 CIP129 DRep-ID: drep1ytwmwvtd0a8lr45ssner2tjxzv5y8q03w3606yeald9mdmgmwecja
      DRep-HASH: ddb7316d7f4ff1d69084f2352e4613284381f17474fd133dfb4bb6ed

    DRep-Status: ❌ NOT registered on the chain!
```

-----

### 4. Retire/Remove a DRep-Key
To retire a DRep-Key and claim back the DRep-Deposit-Fee we are using script 21d:
```console
$ ./21d_retDRepCert.sh

Version-Info: cli 9.3.0.0 / node 9.1.0          Mode: online(full)      Era: conway     Testnet: SanchoNet (magic 4)


Usage:  21d_retDRepCert.sh <DRep-Name> <Base/PaymentAddressName (paying for the retirement fees)>

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

   21d_retDRepCert.sh myDRep myWallet.payment
   -> Retires the DRep-ID of myDRep (myDRep.drep.*) on Chain, Payment via the myWallet.payment wallet

   21d_retDRepCert.sh myDRep myWallet.payment "msg: DRep-ID Retirement, paid via myWallet"
   -> Retire the DRep-ID of myDREP (myDRep.drep.*) on Chain, Payment via the myWallet.payment wallet, Adding a Transaction-Message
```

### Retire a CLI DRep-Key
Lets retire the DRep-Key `myDrep` which we created and registered above.
```console
$ ./21d_retDRepCert.sh myDrep funds
```
```js
Version-Info: cli 9.3.0.0 / node 9.1.0          Mode: online(full)      Era: conway     Testnet: SanchoNet (magic 4)

Retire DRep-ID using myDrep.drep.vkey with funds from Address funds.addr

Checking Information about the DRep-ID: drep19zhgxz7ay7hrs2zfgw59na4x52neldxn7098pynxjgq05k8s2n6

DRep-ID is registered on the chain with a deposit of 500000000 lovelaces
Registered Anchor-URL(HASH): https://raw.githubusercontent.com/gitmachtl/cardano-related-stuff/master/MartinLang_DRep.json (0d7b90948320a9d5bfebc158bc674996df8dd65daab27a0c373b6750d1aa7246)

Generate Retirement-Certificate with the currently set deposit amount: 500000000 lovelaces

DRep-ID Retirement-Certificate built: myDrep.drep-ret.cert
{
    "type": "CertificateConway",
    "description": "DRep Retirement Certificate",
    "cborHex": "83118200581c28ae830bdd27ae38284943a859f6a6a2a79fb4d3f3ca7092669200fa1a1dcd6500"
}

Current Slot-Height: 38670782 (setting TTL[invalid_hereafter] to 38770782)

Pay fees from Address funds.addr: addr_test1vpfwv0ezc5g8a4mkku8hhy3y3vp92t7s3ul8g778g5yegsgalc6gc

1 UTXOs found on the Source Address!

Hash#Index: 051009233fc35d9b9729784785210e991277d8b60932dc3b7c154aff4f4719d6#0  ADA: 99.508,959914 (99508959914 lovelaces)
-----------------------------------------------------------------------------------------------------
Total ADA on the Address:  99.508,959914 ADA / 99508959914 lovelaces

Mimimum transfer Fee for 1x TxIn & 1x TxOut & 1x Certificate:  0,170825 ADA / 170825 lovelaces

DRep-ID Deposit Amount:  500000000 lovelaces

Mimimum funds required for de-registration:  0,857690 ADA / 857690 lovelaces

Lovelaces that will be returned to payment Address (UTXO-Sum minus fees plus DRepDepositAmount):  100.008,789089 ADA / 100008789089 lovelaces  (min. required 857690 lovelaces)

Building the unsigned transaction body with the myDrep.drep-ret.cert certificate:  /tmp/funds.txbody

{
    "type": "Unwitnessed Tx ConwayEra",
    "description": "Ledger Cddl Format",
    "cborHex": "84a500d9010281825820051009233fc35d9b9729784785210e991277d8b60932dc3b7c154aff4f4719d600018182581d6052e63f22c5107ed776b70f7b92248b02552fd08f3e747bc7450994411b0000001748fd0461021a00029b49031a024f985e04d901028183118200581c28ae830bdd27ae38284943a859f6a6a2a79fb4d3f3ca7092669200fa1a1dcd6500a0f5f6"
}

Reading unencrypted file funds.skey ... OK

Reading unencrypted file myDrep.drep.skey ... OK

Sign the unsigned transaction body with the funds.skey & myDrep.drep.skey:  /tmp/funds.tx

{
    "type": "Witnessed Tx ConwayEra",
    "description": "Ledger Cddl Format",
    "cborHex": "84a500d9010281825820051009233fc35d9b9729784785210e991277d8b60932dc3b7c154aff4f4719d600018182581d6052e63f22c5107ed776b70f7b92248b02552fd08f3e747bc7450994411b0000001748fd0461021a00029b49031a024f985e04d901028183118200581c28ae830bdd27ae38284943a859f6a6a2a79fb4d3f3ca7092669200fa1a1dcd6500a100d9010282825820fe4a2e5abb2d87227b5f84eeea50d8ab25250e8ba2af487c9a13595289363e0f58408b80e04652dfd743b3b881a869a7c49aea45a4d960f1f953d993f250736f4b232908bfcc4b71ead83ac74934c9a31f612cf7cec1a18d858adcb97259bff6350a825820742d8af3543349b5b18f3cba28f23b2d6e465b9c136c42e1fae6b2390f565427584014c2b3f00e0657cde9f2cd10866a16775b692c551fe28550941270fafed0468e9357c2d6787f5fd162d8b0a430c48b8c459579c00808cc11ffbca90f45ae7002f5f6"
}

Transaction-Size: 352 bytes (max. 16384)

Does this look good for you, continue ? [y/N]
DONE

 TxID is: f2733d070a56a706ccc53362a582a6ff79d54135a772be8f95d6cb89059e096a
```

Thats it, the DRep-Key is retired again and the 500 Ada Deposit-Fee was paid back to the `funds` cli wallet.

For Hardware-Wallets its all the same, will not include an extra example here.

<br>&nbsp;<br>

-----

## VotingPower Delegation

### 1. Generate the Vote-Delegation-Certificate

To delegate VotingPower to a DRep of our own or a public one, we have to transmit a VotingPower Delegation-Certificate on the chain. This is especially important for Rewards-Staking-Addresses. Because if the Rewards-Staking-Address is not delegated to a DRep - or to AlwaysAbstain or AlwaysNoConfidence - than its not possible to claim rewards.

So, lets generate a Vote-Delegation-Certificate with script 22a:
```console
$ ./22a_genVoteDelegCert.sh

Version-Info: cli 9.4.1.0 / node 9.2.1          Mode: online(full)      Era: conway     Testnet: SanchoNet (magic 4)

Usage:  22a_genVoteDelegCert.sh <DRep-Name | DRepID-Hex | DRepID-Bech "drep1..." | always-abstain | always-no-confidence> <StakeAddressName>
```
As you can see, the usage is pretty simple. 
* First parameter is the DRep-ID/Name we wanna delegate to. OR, you can choose one of the predefined `always-abstain` or `always-no-confidence` options.
* Second parameter is the Name of the StakingAddress, like `rewards` for the  `rewards.staking.addr/vkey/skey` file.

Lets delegate a `test` staking account to the `myLightDrep` drep we created above:
```console
$ ./22a_genVoteDelegCert.sh myLightDrep test
```
```js
Version-Info: cli 9.4.1.0 / node 9.2.1          Mode: online(full)      Era: conway     Testnet: SanchoNet (magic 4)

Create a Vote-Delegation Certificate for Delegator test.staking.vkey
to the DRep with the Key-File myLightDrep.drep.vkey

Which resolves to the DRep-ID: drep15l5z8j6xwnf05f4j0hhfk9vxr2kvq9srxg476he7hlgwyf8ekgj

Vote-Delegation Certificate: test.vote-deleg.cert
{
    "type": "CertificateConway",
    "description": "Vote Delegation Certificate",
    "cborHex": "83098200581cd75b3718e7e7afb82ea77e9be6ffb98ebbf4cfc0f84f450d7a07ab4a8200581ca7e823cb4674d2fa26b27dee9b15861aacc01603322bed5f3ebfd0e2"
}

Created a Vote-Delegation Certificate which delegates the voting power from all stake addresses
associated with key test.staking.vkey to the DRep-File / DRep-ID / STATUS above.

If you wanna submit the Certificate now, please run the script 22b_regVoteDelegCert.sh !
```
The certificate was generated, its stored as `test.vote-deleg.cert` file. Next step is to register it on the chain.

-----

### 2. Register the Vote-Delegation-Certificate

To register the Vote-Delegation-Certificate on chain you simply have to run script 22b:
```console
$ ./22b_regVoteDelegCert.sh

Version-Info: cli 9.4.1.0 / node 9.2.1          Mode: online(full)      Era: conway     Testnet: SanchoNet (magic 4)


Usage:  22b_regVoteDelegCert.sh <StakeAddressName> <Base/PaymentAddressName (paying for the registration fees)>

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

   22b_regVoteDelegCert.sh owner owner.payment
   -> Register the Vote-Delegation Certificate for 'owner', the wallet 'owner.payment' is paying for the transaction

   22b_regVoteDelegCert.sh owner owner.payment "msg: Vote-Delegation of owner to DRep xxx"
   -> Same as above, but with an additional transaction message to keep track of your transactions
```

Here are the needed parameters, rest is optional:
* First parameter is the Staking-File-Name like `test` for `test.staking.addr/vkey/skey`
* Second parameter is a CLI-Payment wallet

So lets register the Vote-Delegation-Certificate for the `test` staking account on chain by using the `funds` wallet:
```console
$ ./22b_regVoteDelegCert.sh test funds
```
```js
Version-Info: cli 9.4.1.0 / node 9.2.1          Mode: online(full)      Era: conway     Testnet: SanchoNet (magic 4)

Register Vote-Delegation Certificate test.vote-deleg.cert with funds from Address funds.addr:

Delegating Voting-Power of test to DRep with Hash: a7e823cb4674d2fa26b27dee9b15861aacc01603322bed5f3ebfd0e2

Which resolves to the Bech-DRepID: drep15l5z8j6xwnf05f4j0hhfk9vxr2kvq9srxg476he7hlgwyf8ekgj
               CIP129 Bech-DRepID: drep1y2n7sg7tge6d973xkf77axc4scd2esqkqvezhm2l86lapcsq5a6zx

Checking current ChainStatus about the DRep-ID: drep15l5z8j6xwnf05f4j0hhfk9vxr2kvq9srxg476he7hlgwyf8ekgj

DRep-ID is registered on the chain, we continue ...

Checking OnChain-Status for the Stake-Address: stake_test1urt4kdcculn6lwpw5alfhehlhx8thax0cruy73gd0gr6kjs29vef7

Account's Voting-Power is not delegated to a DRep or set to a fixed status yet - so lets change this :-)

Current Slot-Height: 41509543 (setting TTL[invalid_hereafter] to 41609543)

Pay fees from Address funds.addr: addr_test1vpfwv0ezc5g8a4mkku8hhy3y3vp92t7s3ul8g778g5yegsgalc6gc

1 UTXOs found on the Source Address!

Hash#Index: 326bb7136f7d92808841dd7764d9fe76c4c249e3768c685ede12699c72ecb6e0#0  ADA: 48.980,957811 (48980957811 lovelaces)
-----------------------------------------------------------------------------------------------------
Total ADA on the Address:  48.980,957811 ADA / 48980957811 lovelaces


Minimum transfer Fee for 1x TxIn & 1x TxOut & 1x Certificate:  0,172013 ADA / 172013 lovelaces

Minimum funds required for registration (Sum of fees):  0,172013 ADA / 172013 lovelaces

Lovelaces that will be returned to payment Address (UTXO-Sum minus fees):  48.980,785798 ADA / 48980785798 lovelaces  (min. required 857690 lovelaces)


Building the unsigned transaction body with Delegation Certificate test.vote-deleg.cert certificates:  /tmp/funds.txbody

{
    "type": "Unwitnessed Tx ConwayEra",
    "description": "Ledger Cddl Format",
    "cborHex": "84a500d9010281825820326bb7136f7d92808841dd7764d9fe76c4c249e3768c685ede12699c72ecb6e000018182581d6052e63f22c5107ed776b70f7b92248b02552fd08f3e747bc7450994411b0000000b677b7a86021a00029fed031a027ae94704d901028183098200581cd75b3718e7e7afb82ea77e9be6ffb98ebbf4cfc0f84f450d7a07ab4a8200581ca7e823cb4674d2fa26b27dee9b15861aacc01603322bed5f3ebfd0e2a0f5f6"
}

Reading unencrypted file funds.skey ... OK

Reading unencrypted file test.staking.skey ... OK

Sign the unsigned transaction body with the funds.skey & test.staking.skey:  /tmp/funds.tx

{
    "type": "Witnessed Tx ConwayEra",
    "description": "Ledger Cddl Format",
    "cborHex": "84a500d9010281825820326bb7136f7d92808841dd7764d9fe76c4c249e3768c685ede12699c72ecb6e000018182581d6052e63f22c5107ed776b70f7b92248b02552fd08f3e747bc7450994411b0000000b677b7a86021a00029fed031a027ae94704d901028183098200581cd75b3718e7e7afb82ea77e9be6ffb98ebbf4cfc0f84f450d7a07ab4a8200581ca7e823cb4674d2fa26b27dee9b15861aacc01603322bed5f3ebfd0e2a100d9010282825820742d8af3543349b5b18f3cba28f23b2d6e465b9c136c42e1fae6b2390f5654275840f967426b303d89a42f0db6a51fa85e63eb4914c9583c9897ab20061d505f4e7ab19612a9a9373ddd85002e45f0ff9b91453f6305fadadf36ffc22a8e4d730c0a825820293ca68cd5651f6d483c9c27fc83cbc5616177ecd9df55e30a46a97dc76213a1584017ae98c314a0b7576d0a92c9084ddf9330241c91bf2549c7ef1891aa6fec801019136d61f240af0e7f05241765c2e2580942ea4dd92f4917404c8278c6a1460af5f6"
}

Transaction-Size: 379 bytes (max. 16384)

Does this look good for you ? [y/N] y

Submitting the transaction via the node... Transaction successfully submitted.
DONE

 TxID is: 200b1265d8b8b6c5b87888ed78badde98a613ad38f674e026a139f239504585c
```

As you can see in the output, the script 22b is doing
* Displaying the DRep-ID in the CIP105 and new CIP129 format
* Checking the chain about the registration status of the DRep. In case the DRep is not registered, the script would abort
* Checking the status of the Staking Account on chain. If the Account is not registered, the script would abort
* Checking the current Vote-Delegation status of the Staking Account. In this case there is no previous delegation, but if there is one, the script will show the currently delegated DRep.
* Getting the UTXO Information of the Payment Wallet
* Submits the Transaction on chain

The Vote-Delegation-Certificate was registed on chain.

-----

### 3. Check the current Vote-Power-Delegation

To check the current status of the voting power delegation, we can simply use the well know StakeAddress check script 03c:
```console
$ ./03c_checkStakingAddrOnChain.sh test
```
```js
Version-Info: cli 9.4.1.0 / node 9.2.1          Mode: online(full)      Era: conway     Testnet: SanchoNet (magic 4)

Checking current ChainStatus of Stake-Address: stake_test1urt4kdcculn6lwpw5alfhehlhx8thax0cruy73gd0gr6kjs29vef7

Staking Address is registered on the chain with a deposit of 2000000 lovelaces !

Account is not delegated to a Pool !

Voting-Power of Staking Address is delegated to DRepID(HASH): drep15l5z8j6xwnf05f4j0hhfk9vxr2kvq9srxg476he7hlgwyf8ekgj (a7e823cb4674d2fa26b27dee9b15861aacc01603322bed5f3ebfd0e2)
```
Here we can see, that the Staking Address is correctly Vote-Delegated to the DRep with the ID `drep15l5z8j6xwnf05f4j0hhfk9vxr2kvq9srxg476he7hlgwyf8ekgj`, which is our `myLightDrep` DRep.
