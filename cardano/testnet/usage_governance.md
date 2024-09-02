# Governance Scripts

This document describes the different governance scripts of the SPO-Scripts collection. How to use them with simply CLI keys and also HW-Wallets.

The governance scripts are divided into different topics, every topic has its own starting number:

### DRep Key Operations
- 21a_genDRepKeys.sh
- 21b_regDRepCert.sh
- 21c_checkDRepOnChain.sh
- 21d_retDRepCert.sh

### VotingPower Delegation
- 22a_genVoteDelegCert.sh
- 22b_regVoteDelegCert.sh

### Constitutional Committee Key Operations
- 23a_genComColdKeys.sh
- 23b_genComHotKeys.sh
- 23c_regComAuthCert.sh
- 23d_checkComOnChain.sh
- 23e_retComColdKeys.sh

### Generate, Submit and Query of votes on Governance actions
- 24a_genVote.sh
- 24b_regVote.sh
- 24c_queryVote.sh

### Generate and Submit of Governance actions
- 25a_genAction.sh
- 25b_regAction.sh

-----

## DRep Key Operations

### Generating DRep-Key options
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



