# StakePool Operator Scripts (SPOS) for Testnets

*Examples on how to use the scripts **ONLINE** and/or **OFFLINE**, with or without a **Ledger/Trezor-Wallet** can be found on this page :smiley:*

| | [cardano-cli](https://github.com/input-output-hk/cardano-node/releases/latest) | [cardano-node](https://github.com/input-output-hk/cardano-node/releases/latest) | [cardano-hw-cli](https://github.com/vacuumlabs/cardano-hw-cli/releases/latest) | Ledger Cardano-App | Trezor Firmware |
| :---  |   :---:     |    :---:     |     :---:      |     :---:      |     :---:      |
| *Required<br>version<br><sub>or higher</sub>* | <b>1.25.1</b><br><sub>**git checkout tags/1.25.1**</sub> | <b>1.25.1</b><br><sub>**git checkout tags/1.25.1**</sub> | <b>1.1.1</b><br><sub>**if you use hw-wallets** | <b>2.1.0</b><br><sub>**if you use hw-wallets** | <b>2.3.5</b><br><sub>**if you use hw-wallets** |

> *:bulb: PLEASE USE THE **CONFIG AND GENESIS FILES** FROM [**here**](https://hydra.iohk.io/job/Cardano/cardano-node/cardano-deployment/latest-finished/download/1/index.html), choose testnet, launchpad or staging*. 

&nbsp;<br>
### About

<img src="https://www.stakepool.at/pics/stakepool_operator_scripts.png" align="right" border=0>

Theses scripts here should help you to manage your StakePool via the CLI. As always use them at your own risk, but they should be errorfree. Scripts were made to make things easier while learning all the commands and steps to bring up the stakepool node. So, don't be mad at me if something is not working. CLI calls are different almost daily currently.<br>&nbsp;<br>
Some scripts are using **jq, curl & bc** so make sure you have it installed with a command like<br>```$ sudo apt update && sudo apt install -y jq curl bc```

&nbsp;<br>
**Contacts**: Telegram - [@atada_stakepool](https://t.me/atada_stakepool), Twitter - [@ATADA_Stakepool](https://twitter.com/ATADA_Stakepool), Homepage - https://stakepool.at 

If you can't hold back and wanna give me a little Tip, here's my MainNet Shelley Ada Address, thx! :-)
```addr1q9vlwp87xnzwywfamwf0xc33e0mqc9ncznm3x5xqnx4qtelejwuh8k0n08tw8vnncxs5e0kustmwenpgzx92ee9crhxqvprhql```

&nbsp;<br>&nbsp;<br> 
# Online-Mode vs. Offline-Mode

The scripts are capable to be used in [**Online**](#examples-in-online-mode)- and [**Offline**](#examples-in-offline-mode)-Mode (examples below). It depends on your setup, your needs and just how you wanna work. Doing transactions with pledge accounts in Online-Mode can be a security risk, also doing Stakepool-Registrations in pure Online-Mode can be risky. To enhance Security the scripts can be used on a Online-Machine and an Offline-Machine. You only have to **transfer one single file (offlineTransfer.json)** between the Machines. If you wanna use the Offline-Mode, your **Gateway-Script** to get Data In/Out of the offlineTransfer.json is the **01_workOffline.sh** Script. The **offlineTransfer.json** is your carry bag between the Machines.<br>

Why not always using Offline-Mode? You have to do transactions online, you have to check balances online. Also, there are plenty of usecases using small wallets without the need of the additional steps to do all offline everytime. Also if you're testing some things on Testnets, it would be a pain to always transfer files between the Hot- and the Cold-Machine. You choose how you wanna work... :smiley:<br>

<details>
   <summary><b>How do you switch between Online- and Offline-Mode? </b>:bookmark_tabs:</summary>
   
<br>Thats simple, you just change a single entry in the 00_common.sh, common.inc or $HOME/.common.inc config-file:
<br>```offlineMode="no"``` Scripts are working in Online-Mode
<br>```offlineMode="yes"``` Scripts are working in Offline-Mode

So on the Online-Machine you set the ```offlineMode="no"``` and on the Offline-Machine you set the ```offlineMode="yes"```.

</details>

<details>
   <summary><b>What do you need on the Online- and the Offline-Machine? </b>:bookmark_tabs:</summary>
   
<br>On the Online-Machine you need a running and fully synced cardano-node, the cardano-cli and also your ```*.addr``` files to query the current balance of them for the Offline-Machine. **You should not have any signing keys ```*.skey``` files of big wallets laying around!** Metadata-Files are fine, you need them anyway to transfer them to your Stakepool-Webserver, also they are public available, no security issue.

On the Offline-Machine you have your signing keys, thats the ```*.skey``` files, also you have your kes-keys, vrf-keys, opcerts, etc. on this Machine.
You need the cardano-cli on the Offline-Machine, same version as on the Online-Machine! You don't need the cardano-node, because you will never be online with that Machine!

You should keep your directory structure the same on both Machines.

</details>

<details>
   <summary><b>Best practice Advise for Stakepool Operators ... </b>:bookmark_tabs:</summary>
   
&nbsp;<br>
1. Work in Offline-Mode whenever you can, even when you use Hardware-Keys, your PoolNode-Cold-Keys should be on an Offline-Machine.
1. Use Hardware-Keys (Ledger/Trezor) for your Owner-Pledge-Funds! You can choose between Full-Hardware and Hybrid-Mode if you like (description below). Get a 2nd Hardware-Wallet as a backup for the first one, you can restore it with the same Seed-Phrase and they will work both in the same way. Store this 2nd one at another location!
1. Make yourself a few small Operator CLI-Wallets for the daily usage. There is absolutly no need to have your Owner-Pledge-Wallet/Key around all the time. You need at least three small wallets if you wanna do more than one transactions in a single "Online->Offline->Online" process.
1. If you don't have a Hardware-Wallet, make sure that you move away your ```owner.payment.skey``` completely onto a secure medium like an encrypted USB-Stick and put it in a safe. Store a copy of it in a 2nd secure place at another location. An Offline-Machine is pretty secure, but it can be compromised by a physical attack on it. So don't leave your ```owner.payment.skey``` even on your Offline-Machine.
1. Don't tell anybody - not even a good Telegram buddy - where your owner keys are or how your secure structure looks like, we have seen "Social Hacking" in the past. Just keep this information to yourself. 
1. If someone is hacking your stake keys thats annoying. If someone gets to your PoolNode-Cold-Keys thats even more annoying, but if someone gets to your Owner-Pledge-Fund keys, your funds are lost. So, take care of your keys! :smiley:

</details>

<details>
   <summary><b>How do you migrate your existing StakePool to HW-Wallet-Owner-Keys ... </b>:bookmark_tabs:</summary>

<br>You can find examples below in the Online- and Offline-Examples section. [Online-Migration-Example](#migrate-your-existing-stakepool-to-hw-wallet-owner-keys-ledgertrezor), [Offline-Migration-Example](#migrate-your-existing-stakepool-offline-to-hw-wallet-owner-keys-ledgertrezor)

</details>
&nbsp;<br>&nbsp;<br>

# How to Install/Copy the Scripts

Installation is simple, just copy them over or do a git clone so you can also do a quick update in the future.

<details>
   <summary><b>How to get the scripts on your Linux machine ... </b>:bookmark_tabs:<br></summary>
   
<br>You can just download the [ZIP-Archive](https://github.com/gitmachtl/scripts/archive/master.zip), unzip it in a directory of your choice and use the scripts directly in there.<br>
However, if you wanna make them usable in all directories you should make a fixed directory like **$HOME/stakepoolscripts** and add this directory to your global PATH environment:

**Make a fixed directory for the scripts and set the PATH**
```console
mkdir -p $HOME/stakepoolscripts/bin && cd $_
echo "export PATH=\"$PWD:\$PATH\"" >> $HOME/.profile
export PATH="$PWD:$PATH"
```
You have now made the folder 'stakepoolscripts' in your HOME directory, also you have set the PATH in the $HOME/.profile, so it would survive a reboot. The global PATH is set to the 'bin' subdirectory in your $HOME/stakepoolscripts directory. Whatever script is in there, thats the one thats active on the whole machine.<br>

**Git-Clone the Repository into your fixed directory**
``` console
git clone https://github.com/gitmachtl/scripts.git $HOME/stakepoolscripts
```

Now its time to **choose** if you wanna use the **Mainnet-Scripts or the Testnet-Scripts**. You have to copy the right ones into the 'bin' subdirectory of your $HOME/stakepoolscripts:

**Using the Mainnet-Scripts - Install or Update**
``` console
cd $HOME/stakepoolscripts
git fetch origin && git reset --hard origin/master
cp cardano/mainnet/* bin/
```
**Using the Testnet-Scripts - Install or Update**
``` console
cd $HOME/stakepoolscripts
git fetch origin && git reset --hard origin/master
cp cardano/testnet/* bin/
```

**DONE, you can now start to set the right config in your 00_common.sh or common.inc configuration file. Read the details below. :smiley:**
<br>&nbsp;<br>
</details>

<details>
   <summary><b>Checkout how to use the scripts with directories for wallets/pooldata... </b>:bookmark_tabs:<br></summary>

<br>There is no fixed directory structure, the current design is FLAT. So all Examples below are generating/using files within the same directory. This should be fine for the most of you. If you're fine with this, skip this section and check the [Scriptfile Syntax](#configuration-scriptfiles-syntax--filenames) above.<p>However, if you wanna use directories there is a way: 
* **Method-1:** Making a directory for a complete set: (all wallet and poolfiles in one directory)
1. Put the scripts in a directory that is in your PATH environment variable, so you can call the scripts from everywhere.
1. Make a directory whereever you like
1. Call the scripts from within this directory, all files will be generated/used in this directory<p>
* **Method-2:** Using subdirectories from a base directory:
1. Put the scripts in a directory that is in your PATH environment variable, so you can call the scripts from everywhere.
1. Make a directory that is your BASE directory like /home/user/cardano
1. Go into this directory ```cd /home/user/cardano``` and make other subdirectories like ```mkdir mywallets``` and ```mkdir mypools```
1. **Call the scripts now only from this BASE directory** and give the names to the scripts **WITH** the directory in a relative way like (examples):
   <br>```03a_genStakingPaymentAddr.sh mywallets/allmyada cli``` this will generate your StakeAddressCombo with name allmyada in the mywallets subdirectory
   <br>```05b_genDelegationCert.sh mypools/superpool mywallets/allmyada``` this will generate the DelegationCertificate for your StakeAddress allmyada to your Pool named superpool.
   So, just use always the directory name infront to reference it on the commandline parameters. And keep in mind, you have to do it always from your choosen BASE directory. Because files like the poolname.pool.json are refering also to the subdirectories. And YES, you need a name like superpool or allmyada for it, don't call the scripts without them.<br>
   :bulb: Don't call the scripts with directories like ../xyz or /xyz/abc, it will not work at the moment. Call them from the choosen BASE directory without a leading . or .. Thx!

</details>

&nbsp;<br>&nbsp;<br>
# Configuration, Scriptfiles Syntax & Filenames

Please make yourself familiar on how to call each script with the required parameters, there are plenty of examples in the description below or in the examples.

### Main-Configuration-File (00_common.sh) - Syntax for all the other ones

Checkout the configuration parameters in your 00_common.sh Main-Configuration file and the ScriptFile Syntax for the Scripts themselfs.

<details>
   <summary><b>Show the Main Configuration parameters and the full Syntax details for each script ... </b>:bookmark_tabs:<br></summary>

* **00_common.sh:** main config file (:warning:) for the environment itself! Set your variables in there for your config, will be used by the scripts.<br>
    
  | Important Parameters | Description | Example |
  | :---         |     :---      | :--- |
  | offlineMode | Switch for the scripts to work<br>in *Online*- or *Offline*-Mode | ```yes``` for Offline-Mode<br>```no``` for Online-Mode (Default) |
  | offlineFile | Path to the File used for the transfer<br>between the Online- and Offline-Machine | ```./offlineTransfer.json``` (Default) |
  | cardanocli | Path to your *cardano-cli* binary | ```./cardano-cli``` (Default)<br>```cardano-cli``` if in the global PATH |
  | cardanonode | Path to your *cardano-node* binary<br>(only for Online-Mode) | ```./cardano-node``` (Default)<br>```cardano-node``` if in the global PATH |
  | socket | Path to your running passive node<br>(only for Online-Mode) | ```db-mainnet/node.socket``` |
  | cardanohwcli | Path to your *cardano-hw-cli* binary<br>(only for HW-Wallet support) | ```cardano-hw-cli``` if in the global PATH (Default)|
  | genesisfile | Path to your *SHELLEY* genesis file | ```config-mainnet/mainnet-shelley-genesis.json``` |
  | genesisfile_byron | Path to your *BYRON* genesis file | ```config-mainnet/mainnet-byron-genesis.json``` |
    | magicparam<br>addrformat | Type of the Chain your using<br>and the Address-Format | ```--mainnet``` for mainnet<br>```--testnet-magic 1097911063``` for the testnet<br>```--testnet-magic 3``` for launchpad |
  | byronToShelleyEpochs | Number of Epochs between Byron<br>to Shelley Fork | ```208``` for mainnet (Default)<br>```74``` for the testnet<br>```2``` for launchpad |
  | itn_jcli | Path to your *jcli* binary<br>(only for ITN ticker proof) | ```./jcli``` (Default) |
   
    
  
  **Overwritting the default settings:** You can now place a file with name ```common.inc``` in the calling directory and it will be sourced by the 00_common.sh automatically. So you can overwrite the setting-variables dynamically if you want. Or if you wanna place it in a more permanent place, you can name it ```.common.inc``` and place it in the user home directory. The ```common.inc``` in a calling directory will overwrite the one in the home directory if present. <br>
  :bulb: You can also use it to set the CARDANO_NODE_SOCKET_PATH environment variable by just calling ```source ./00_common.sh```

&nbsp;<br>
* **01_workOffline.sh:** this is the script you're doing your **Online**->**Offline**->**Online**->**Offline** work with
<br>```./01_workOffline.sh <command> [additional data]``` 
<br>```./01_workOffline.sh new``` Resets the offlineTransfer.json with only the current protocol-parameters in it (OnlineMode only)
<br>```./01_workOffline.sh info``` Displayes the Address and TX info in the offlineTransfer.json<br>
<br>```./01_workOffline.sh add mywallet``` Adds the UTXO info of mywallet.addr to the offlineTransfer.json (OnlineMode only)
<br>```./01_workOffline.sh add owner.staking``` Adds the Rewards info of owner.staking to the offlineTransfer.json (OnlineMode only)<br>
<br>```./01_workOffline.sh execute``` Executes the first cued transaction in the offlineTransfer.json (OnlineMode only)
<br>```./01_workOffline.sh execute 3``` Executes the third cued transaction in the offlineTransfer.json (OnlineMode only)<br>
<br>```./01_workOffline.sh attach <filename>``` This will attach a small file (filename) into the offlineTransfer.json
<br>```./01_workOffline.sh extract``` Extract the attached files in the offlineTransfer.json<br>
<br>```./01_workOffline.sh cleartx``` Removes the cued transactions in the offlineTransfer.json
<br>```./01_workOffline.sh clearhistory``` Removes the history in the offlineTransfer.json
<br>```./01_workOffline.sh clearfiles``` Removes the attached files in the offlineTransfer.json

  The scripts uses per default (configurable) the file **offlineTransfer.json** to store the data in between the Machines.

&nbsp;<br>
* **01_queryAddress.sh:** checks the amount of lovelaces and tokens on an address with autoselection about a UTXO query on enterprise & payment(base) addresses or a rewards query for stake addresses
<br>```./01_queryAddress.sh <name or hash>``` **NEW** you can use the HASH of an address too now.
<br>```./01_queryAddress.sh addr1``` shows the lovelaces from addr1.addr
<br>```./01_queryAddress.sh owner.staking``` shows the current rewards on the owner.staking.addr
<br>```./01_queryAddress.sh addr1vyjz4gde3aqw7e2vgg6ftdu687pcnpyzal8ax37cjukq5fg3ng25m``` shows the lovelaces on this given Bech32 address
<br>```./01_queryAddress.sh stake1u9w60cpjg0xnp6uje8v3plcsmmrlv3vndcz0t2lgjma0segm2x9gk``` shows the rewards on this given Bech32 address

&nbsp;<br>
* **01_sendLovelaces.sh:** sends a given amount of lovelaces or ALL lovelaces or ALLFUNDS lovelaces+tokens from one address to another, uses always all UTXOs of the source address
<br>```./01_sendLovelaces.sh <fromAddr> <toAddrName or hash> <lovelaces>``` (you can send to an HASH address too)
<br>```./01_sendLovelaces.sh addr1 addr2 1000000``` to send 1000000 lovelaces from addr1.addr to addr2.addr
<br>```./01_sendLovelaces.sh addr1 addr2 ALL``` to send **ALL lovelaces** from addr1.addr to addr2.addr, Tokens on addr1.addr are preserved
<br>```./01_sendLovelaces.sh addr1 addr2 ALLFUNDS``` to send **ALL funds** from addr1.addr to addr2.addr **including Tokens** if present
<br>```./01_sendLovelaces.sh addr1 addr1vyjz4gde3aqw7e2vgg6ftdu687pcnpyzal8ax37cjukq5fg3ng25m ALL``` send ALL lovelaces from addr1.addr to the given Bech32 address

&nbsp;<br>
* **01_sendAssets.sh:** sends Assets(Tokens) and optional a given amount of lovelaces from one address to another
<br>```./01_sendAssets.sh <fromAddr> <toAddress|HASH> <PolicyID.Name|<PATHtoNAME>.asset> <AmountOfAssets|ALL> [Optional Amount of lovelaces to attach]```
<br>```./01_sendAssets.sh addr1 addr2 mypolicy.SUPERTOKEN 15```<br>to send 15 SUPERTOKEN from addr1.addr to addr2.addr with minimum lovelaces attached
<br>```./01_sendAssets.sh addr1 addr2 mypolicy.MEGATOKEN ALL 12000000```<br>to send **ALL** MEGATOKEN from addr1.addr to addr2.addr and also 12 ADA
<br>```./01_sendAssets.sh addr1 addr2 34250edd1e9836f5378702fbf9416b709bc140e04f668cc355208518.ATADAcoin 120```<br>to send 120 Tokens of Type 34250edd1e9836f5378702fbf9416b709bc140e04f668cc355208518.ATADAcoin from addr1.addr to addr2.addr. Using the PolicyID.TokenNameHASH allowes you to send out Tokens you've got from others. You own generated Tokens can be referenced by the AssetFile 'policyName.tokenName.asset' schema for a easier handling.

&nbsp;<br>
* **01_claimRewards.sh:** claims all rewards from the given stake address and sends it to a receiver address
<br>```./01_claimRewards.sh <nameOfStakeAddr> <toAddr> [optional <feePaymentAddr>]```
<br>```./01_claimRewards.sh owner.staking owner.payment``` sends the rewards from owner.staking.addr to the owner.payment.addr. The transaction fees will also be paid from the owner.payment.addr
<br>```./01_claimRewards.sh owner.staking myrewards myfunds``` sends the rewards from owner.staking.addr to the myrewards.addr. The transaction fees will be paid from the myfunds.addr

&nbsp;<br>
* **01_sendVoteMeta.sh:** modified sendLoveLaces script to simply send a voting json metadata file
<br>```./01_sendLovelaces.sh <fromAddr> <VoteFileName>```
<br>```./01_sendLovelaces.sh addr1 myvote``` to just send the myvote.json votingfile from funds on addr1.addr
<br>Also please check the Step-by-Step notes [HERE](#bulb-how-to-do-a-voting-for-spocra-in-a-simple-process)

&nbsp;<br>
* **02_genPaymentAddrOnly.sh:** generates an "enterprise" address with the given name for just transfering funds
<br>```./02_genPaymentAddrOnly.sh <name> <keymode: cli | hw>```
<br>```./02_genPaymentAddrOnly.sh addr1 cli``` will generate the CLI-based files addr1.addr, addr1.skey, addr1.vkey
<br>```./02_genPaymentAddrOnly.sh addr1 cli``` will generate the HardwareWallet-based files addr1.addr, addr1.hwsfiles, addr1.vkey<br>

&nbsp;<br>
* **03a_genStakingPaymentAddr.sh:** generates the base/payment address & staking address combo with the given name and also the stake address registration certificate
<br>```./03a_genStakingPaymentAddr.sh <name> <keymode: cli | hw | hybrid>```

   ```./03a_genStakingPaymentAddr.sh owner cli``` will generate CLI-based files owner.payment.addr, owner.payment.skey, owner.payment.vkey, owner.staking.addr, owner.staking.skey, owner.staking.vkey, owner.staking.cert

   ```./03a_genStakingPaymentAddr.sh owner hw``` will generate HardwareWallet-based files owner.payment.addr, owner.payment.hwsfile, owner.payment.vkey, owner.staking.addr, owner.staking.hwsfile, owner.staking.vkey, owner.staking.cert

   ```./03a_genStakingPaymentAddr.sh owner hybrid``` will generate HardwareWallet-based payment files owner.payment.addr, owner.payment.hwsfile, owner.payment.vkey and CLI-based staking files owner.staking.addr, owner.staking.hwsfile, owner.staking.vkey, owner.staking.cert

&nbsp;<br>
* **03b_regStakingAddrCert.sh:** register the staking address on the blockchain with the certificate from 03a.
<br>```./03b_regStakingAddrCert.sh <nameOfStakeAddr> <nameOfPaymentAddr>```
<br>```./03b_regStakingAddrCert.sh owner.staking addr1``` will register the staking addr owner.staking using the owner.staking.cert with funds from addr1 on the blockchain. you could of course also use the owner.payment address here for funding.<br>

&nbsp;<br>
* **03c_checkStakingAddrOnChain.sh:** check the blockchain about the staking address
<br>```./03c_checkStakingAddrOnChain.sh <name>```
<br>```./03c_checkStakingAddrOnChain.sh owner``` will check if the address in owner.staking.addr is currently registered on the blockchain

&nbsp;<br>
* **04a_genNodeKeys.sh:** generates the poolname.node.vkey and poolname.node.skey cold keys and resets the poolname.node.counter file
<br>```./04a_genNodeKeys.sh <poolname>```
<br>```./04a_genNodeKeys.sh mypool```

&nbsp;<br>
* **04b_genVRFKeys.sh:** generates the poolname.vrf.vkey/skey files
<br>```./04b_genVRFKeys.sh <poolname>```
<br>```./04b_genVRFKeys.sh mypool```

&nbsp;<br>
* **04c_genKESKeys.sh:** generates a new pair of poolname.kes-xxx.vkey/skey files, and updates the poolname.kes.counter file. every time you generate a new keypair the number(xxx) autoincrements. To renew your kes/opcert before the keys of your node expires just rerun 04c and 04d!
<br>```./04c_genKESKeys.sh <poolname>```
<br>```./04c_genKESKeys.sh mypool```

&nbsp;<br>
* **04d_genNodeOpCert.sh:** calculates the current KES period from the genesis.json and issues a new poolname.node-xxx.opcert certificate. it also generates the poolname.kes-expire.json file which contains the valid start KES-Period and also contains infos when the generated kes-keys will expire. to renew your kes/opcert before the keys of your node expires just rerun 04c and 04d! after that, update the files on your stakepool server and restart the coreNode
<br>```./04d_genNodeOpCert.sh <poolname>```
<br>```./04d_genNodeOpCert.sh mypool```

&nbsp;<br>
* **05a_genStakepoolCert.sh:** generates the certificate poolname.pool.cert to (re)register a stakepool on the blockchain
  <br>```./05a_genStakepoolCert.sh <PoolNodeName> [optional registration-protection key]``` will generate the certificate poolname.pool.cert from poolname.pool.json file<br>
  To register a protected Ticker you will have to provide the secret protection key as a second parameter to the script.<br>
  The script requires a json file for the values of PoolNodeName, OwnerStakeAddressName(s), RewardsStakeAddressName (can be the same as the OwnerStakeAddressName), pledge, poolCost & poolMargin(0.01-1.00) and PoolMetaData. This script will also generate the poolname.metadata.json file for the upload to your webserver. Learn more about the parameters in this config json [here](#pool-configuration-file-poolnamepooljson---config-file-for-each-pool):
  <br>**Sample mypool.pool.json**
  ```console
   {
      "poolName": "mypool",
      "poolOwner": [
         {
         "ownerName": "owner",
         "ownerWitness": "local"
         }
      ],
      "poolRewards": "owner",
      "poolPledge": "100000000000",
      "poolCost": "500000000",
      "poolMargin": "0.10",
      "poolRelays": [
         {
         "relayType": "ip or dns",
         "relayEntry": "x.x.x.x or the dns-name of your relay",
         "relayPort": "3001"
         }
      ],
      "poolMetaName": "This is my Pool",
      "poolMetaDescription": "This is the description of my Pool!",
      "poolMetaTicker": "POOL",
      "poolMetaHomepage": "https://mypool.com",
      "poolMetaUrl": "https://mypool.com/mypool.metadata.json",
      "poolExtendedMetaUrl": "",
      "---": "--- DO NOT EDIT BELOW THIS LINE ---"
    }
   ```
   :bulb:   **If the json file does not exist with that name, the script will generate one for you, so you can easily edit it.**<br>

   poolName is the name of your poolFiles from steps 04a-04d, poolOwner is an array of all the ownerStake from steps 03, poolRewards is the name of the stakeaddress getting the pool rewards (can be the same as poolOwner account), poolPledge in lovelaces, poolCost per epoch in lovelaces, poolMargin in 0.00-1.00 (0-100%).<br>
   poolRelays is an array of your IPv4/IPv6 or DNS named public pool relays. Currently the types DNS, IP, IP4, IPv4, IP6 and IPv6 are supported. Examples of multiple relays can be found [HERE](#using-multiple-relays-in-your-poolnamepooljson) <br> MetaName/Description/Ticker/Homepage is your Metadata for your Pool. The script generates the poolname.metadata.json for you. In poolMetaUrl you must specify your location of the file later on your webserver (you have to upload it to this location). <br>There is also the option to provide ITN-Witness data in an extended metadata json file. Please read some infos about that [here](#bulb-itn-witness-ticker-check-for-wallets)<br>After the edit, rerun the script with the name again.<br>
   > :bulb:   **Update Pool values (re-registration):** If you have already registered a stakepool on the chain and want to change some parameters, simply [change](#file-autolock-for-enhanced-security) them in the json file and rerun the script again. The 05c_regStakepoolCert.sh script will later do a re-registration instead of a new registration for you.

&nbsp;<br>
* **05b_genDelegationCert.sh:** generates the delegation certificate name.deleg.cert to delegate a stakeAddress to a Pool poolname.node.vkey. As pool owner you have to delegate to your own pool, this is registered as pledged stake on your pool.
<br>```./05b_genDelegationCert.sh <PoolNodeName> <DelegatorStakeAddressName>```
<br>```./05b_genDelegationCert.sh mypool owner``` this will delegate the Stake in the PaymentAddress of the Payment/Stake combo with name owner to the pool mypool

&nbsp;<br>
* **05c_regStakepoolCert.sh:** (re)register your **poolname.pool.cert certificate** and also the **owner name.deleg.cert certificate** with funds from the given name.addr on the blockchain. it also updates the pool-ID and the registration date in the poolname.pool.json
<br>```./05c_regStakepoolCert.sh <PoolNodeName> <PaymentAddrForRegistration> [optional REG / REREG keyword]```
<br>```./05c_regStakepoolCert.sh mypool owner.payment``` this will register your pool mypool with the cert and json generated with script 05a on the blockchain. Owner.payment.addr will pay for the fees.<br>
If the pool was registered before (when there is a **regSubmitted** value in the name.pool.json file), the script will automatically do a re-registration instead of a registration. The difference is that you don't have to pay additional fees for a re-registration.<br>
  > :bulb: If something went wrong with the original pool registration, you can force the script to redo a normal registration by adding the keyword REG on the commandline like ```./05c_regStakepoolCert.sh mypool mywallet REG```<br>
Also you can force the script to do a re-registration by adding the keyword REREG on the command line like ```./05c_regStakepoolCert.sh mypool mywallet REREG```

&nbsp;<br>
* **05d_poolWitness.sh:** gives you Status Information, also Signing, Adding and Clearing Witnesses for a PoolRegistration
  <br>```./05d_poolWitness.sh <command> [additional data]``` 
  <br>```05d_poolWitness.sh sign <witnessfile> <signingkey>``` signs the witnessFile with the given signingKey
  <br>```05d_poolWitness.sh sign mypool_ledger_128463691.witness ledger``` signs the witnessFile with the ledger.staking key

  ```05d_poolWitness.sh add <witnessfile> <poolFileName>``` adds a signed witnessFile to the waiting collection of the poolFileName
  <br>```05d_poolWitness.sh add mypool_ledger_128463691.witness mypool``` adds the signed witnessFile to the mypool.pool.json witness collection

  ```05d_poolWitness.sh clear <poolFileName>``` clears any witness collections in the poolFileName.pool.json
  <br>```05d_poolWitness.sh clear mypool``` clears all witnesses in mypool.pool.json for a fresh start

  ```05d_poolWitness.sh info <poolFileName>``` shows the current witness state in the poolFileName.pool.json
  <br>```05d_poolWitness.sh info mypool``` shows the current witness state in the mypool.pool.json to see if some are still missing

&nbsp;<br>
* **06_regDelegationCert.sh:** register a simple delegation (from 05b) name.deleg.cert 
<br>```./06_regDelegationCert.sh <delegatorName> <nameOfPaymentAddr>```
<br>```./06_regDelegationCert.sh someone someone.payment``` this will register the delegation certificate someone.deleg.cert for the stake-address someone.staking.addr on the blockchain. The transaction fees will be paid from someone.payment.addr.

&nbsp;<br>
* **07a_genStakepoolRetireCert.sh:** generates the de-registration certificate poolname.pool.dereg-cert to retire a stakepool from the blockchain
  <br>```./07a_genStakepoolRetireCert.sh <PoolNodeName> [optional retire EPOCH]```
  <br>```./07a_genStakepoolRetireCert.sh mypool``` generates the mypool.pool.dereg-cert to retire the pool in the NEXT epoch
  <br>```./07a_genStakepoolRetireCert.sh mypool 253``` generates the poolname.pool.dereg-cert to retire the pool in epoch 253<br>
  The script requires a poolname.pool.json file with values for at least the PoolNodeName & OwnerStakeAddressName. It is the same json file we're already using since script 05a, so a total pool history json file.<br>
  **If the json file does not exist with that name, the script will generate one for you, so you can easily edit it.**<br>
   poolName is the name of your poolFiles from steps 04a-04d, poolOwner is the name of the StakeOwner from steps 03

&nbsp;<br>
* **07b_deregStakepoolCert.sh:** de-register (retire) your pool with the **poolname.pool.dereg-cert certificate** with funds from name.payment.addr from the blockchain. it also updates the de-registration date in the poolname.pool.json
<br>```./07b_deregStakepoolCert.sh <PoolNodeName> <PaymentAddrForDeRegistration>```
<br>```./07b_deregStakepoolCert.sh mypool mywallet``` this will retire your pool mypool with the cert generated with script 07a from the blockchain. The transactions fees will be paid from the mywallet.addr account.<br>
  :bulb: Don't de-register your rewards/staking account yet, you will receive the pool deposit fee on it!<br>

&nbsp;<br>
* **08a_genStakingAddrRetireCert.sh:** generates the de-registration certificate name.staking.dereg-cert to retire a stake-address form the blockchain
  <br>```./08a_genStakingAddrRetireCert.sh <name>```
  <br>```./08a_genStakingAddrRetireCert.sh owner``` generates the owner.staking.dereg-cert to retire the owner.staking.addr
  
&nbsp;<br>
* **08b_deregStakingAddrCert.sh:** re-register (retire) you stake-address with the **name.staking.dereg-cert certificate** with funds from name.payment.add from the blockchain.
  <br>```./08b_deregStakingAddrCert.sh <nameOfStakeAddr> <nameOfPaymentAddr>```
  <br>```./08b_deregStakingAddrCert.sh owner.staking owner.payment``` this will retire your owner staking address with the cert generated with script 08a from the blockchain.

&nbsp;<br>
* **10_genPolicy.sh:** generate policy keys, signing script and id as files **name.policy.skey/vkey/script/id**. You need a policy for Token minting.
  <br>```./10_genPolicy.sh <PolicyName>```
  
  ```./10_genPolicy.sh mypolicy```<br>this will generate the policyfiles with name mypolicy.policy.skey, mypolicy.policy.vkey, mypolicy.policy.script & mypolicy.policy.id
  
  ```./10_genPolicy.sh assets/mypolicy2```<br>this will generate the policyfiles with name mypolicy2.policy.skey, mypolicy2.policy.vkey, mypolicy2.policy.script & mypolicy2.policy.id in the 'assets' subdirectory

&nbsp;<br>
* **11a_mintAsset.sh:** mint/generate new Assets(Token) on a given payment address with a policyName generated before. This updates the Token Status File **policyname.assetname.asset** for later usage when sending/burning Tokens.
  <br>```./11a_mintAsset.sh <PolicyName.AssetName> <AssetAmount to mint> <nameOfPaymentAddr> [optional Metadata JSON to include]```
  
  ```./11a_mintAsset.sh mypolicy.SUPERTOKEN 1000 mywallet```<br>this will mint 1000 new SUPERTOKEN with policy 'mypolicy' on the payment address mywallet.addr
  
  ```./11a_mintAsset.sh mypolicy.MEGATOKEN 30 owner.payment```<br>this will mint 30 new MEGATOKEN with policy 'mypolicy' on the payment address owner.payment.addr
  
  ```./11a_mintAsset.sh mypolicy.HYPERTOKEN 150 owner.payment mymetadata.json```<br>this will mint 150 new HYPERTOKEN with policy 'mypolicy' on the payment address owner.payment.addr and will also attach the mymetadata.json as metadata in the Minting-Transaction

&nbsp;<br>
* **11b_burnAsset.sh:** burnes Assets(Token) on a given payment address with a policyName you own the keys for. This updates the Token Status File **policyname.assetname.asset** for later usage when sending/burning Tokens.
  <br>```./11b_burnAsset.sh <PolicyName.AssetName> <AssetAmount to mint> <nameOfPaymentAddr> [optional Metadata JSON to include]```
  
  ```./11b_burnAsset.sh mypolicy.SUPERTOKEN 22 mywallet```<br>this will burn 22 SUPERTOKEN with policy 'mypolicy' on the payment address mywallet.addr
  
  ```./11b_burnAsset.sh mypolicy.MEGATOKEN 10 owner.payment```<br>this will burn 10 MEGATOKEN with policy 'mypolicy' on the payment address owner.payment.addr
  
  ```./11b_burnAsset.sh assets/mypolicy2.HYPERTOKEN 5 owner.payment```<br>this will burn 5 HYPERTOKEN with policy 'mypolicy2' from the subdirectory assets on the payment address owner.payment.addr, also it will send along the mymetadata.json in the Burning-Transaction

</details>

### Pool-Configuration-File (poolname.pool.json) - Config-File for each Pool

The **poolname.pool.json** file is your Config-Json to manage your individual Pool-Settings like owners, fees, costs. You don't have to create the base structure of this Config-Json, **the script 05a_genStakepoolCert.sh will generate a blank one for you** ...<br>
   
<details>
   <summary><b>Checkout how the Config-Json looks like and the parameters ... </b>:bookmark_tabs:<br></summary>

<br>**Sample mypool.pool.json**
  ```console
   {
      "poolName": "mypool",
      "poolOwner": [
         {
         "ownerName": "owner",
         "ownerWitness": "local"
         },
         {
         "ownerName": "ledgerowner",
         "ownerWitness": "local"
         }    
      ],
      "poolRewards": "owner",
      "poolPledge": "100000000000",
      "poolCost": "340000000",
      "poolMargin": "0.05",
      "poolRelays": [
         {
         "relayType": "dns",
         "relayEntry": "relay1.wakandapool.com",
         "relayPort": "3001"
         },
         {
         "relayType": "dns",
         "relayEntry": "relay2.wakandapool.com",
         "relayPort": "3001"
         }        
      ],
      "poolMetaName": "Wakanda Forever StakePool",
      "poolMetaDescription": "Don't fight with the black panther, our servers are powered by Vibranium!",
      "poolMetaTicker": "WKNDA",
      "poolMetaHomepage": "https://www.wakandapool.com",
      "poolMetaUrl": "https://www.wakandapool.com/mypool.metadata.json",
      "poolExtendedMetaUrl": "",
      "---": "--- DO NOT EDIT BELOW THIS LINE ---"
    }
   ```

| Parameter | Description | Example |
| :---         |     :---      | :--- |
| poolName | Reference to the fileName used on the hdd for the node files, so this is normally the same as the poolName.pool.json | mypool for mypool.node.vkey,mypool.node.skey ... |
| *poolOwner:* ownerName | The name of the pool owner(s) name, this is in line when you use for example the 03a_genStakingPaymentAddr.sh script with that name | owner |
| *poolOwner:* ownerWitness | The choosen method when the StakePool Registration will be signed:<br>**local:** means a direct sign when running the registration<br>**external:** means that you wanna collect the signed Witness later or with an external source. Take a look [here](#changes-to-the-operator-workflow-when-hardware-wallets-are-involved) to learn more about MultiWitnesses. | local or empty (default) |
| poolRewards | The name of the pool rewards account name, this is in line when you use for example the 03a script with that name. The rewards of your pool will land on that account. | owner |
| poolPledge | The amount of lovelaces (1 ADA = 1 Mio lovelaces) you're commiting to hold in your owner wallet(s) | 100000000000 (100 kADA) |
| poolCost | The amount of lovelaces (1 ADA = 1 Mio lovelaces) you're taking as a fee per epoch from the total rewards | 340000000 (340 ADA) |
| poolMargin | The amount in percentage you're taking from the total rewards:<br>0.00=0%, 0.10=10%, 1.00=100% | 0.05 (5%) |
| *poolRelays:* relayType | The type of relayEntry you wanna use:<br>**ip:** you provide the relayEntry as an IPv4 x.x.x.x<br>**ip6:** you provide the relayEntry as an IPv6 address<br>**dns:** you provide the relayEntry as a FQDN entry like relay1.wakandapool.com | dns (prefered) |
| *poolRelays:* relayEntry | The IP-Address or DNS-Name your relay is reachable to the public| relay1.wakandapool.com |
| *poolRelays:* relayPort | The public TCP-Port of your relay, this port must be opened to everyone so they can reach your relay node| 3001 (default) |
| poolMetaName | This is a longer Name for your StakePool, this will be shown in the Wallets like Daedalus or Yoroi.| Wakanda Forever StakePool |
| poolMetaDescription | This is a longer description for your StakePool, this will be shown in the Wallets like Daedalus or Yoroi.| ...tell your story... |
| poolMetaTicker | Thats the short name - also known as Ticker - for your StakePool, this will be shown in the Wallets like Daedalus or Yoroi.| WKNDA |
| poolMetaHomepage | This is a link to your StakePool-Homepage. As we are security oriented, this should be a https:// link.| `https://www.wakandapool.com` |
| poolMetaUrl | This is a link to your MetaFile of your StakePool, it contains all the MetaData above to be shown in the wallets. The scripts will automatically produce this file (f.e. mypool.metadata.json) for you, but you have to upload it yourself to your Homepage. As we are security oriented, this should be a https:// link.| <sub>`https://www.wakandapool.com/mypool.metadata.json`</sub> |
| poolExtendedMetaUrl | You don't need this entry for a working StakePool!<br>Like the one above, it contains all the special additional informations about your StakePool that cannot be stored in the normal MetaData file. Like your ITN Witness, or all the additions Adapools.org made. The scripts will automatically produce this file (f.e. mypool.extended-metadata.json) for you. Learn more about it [here](#itn-witness-ticker-check-for-wallets-and-extended-metadatajson-infos)| <sub>`https://www.wakandapool.com/mypool.metadata.json`</sub> |

**Don't ever edit the JSON below the line --- DO NOT EDIT BELOW THIS LINE ---**, the scripts will use and fill that space when you use them.

<br>Your Config-Json could end up like this one after the pool was registered and also later retired:
```console
{
  "poolName": "mypool",
  "poolOwner": [
         {
         "ownerName": "owner",
         "ownerWitness": "local"
         }
         {
         "ownerName": "otherowner2",
         "ownerWitness": "external"
         }
   ],
  "poolRewards": "owner",
  "poolPledge": "100000000000",
  "poolCost": "500000000",
  "poolMargin": "0.10",
  "poolRelays": [
         {
         "relayType": "dns",
         "relayEntry": "relay-1.mypool.com",
         "relayPort": "3001"
         },
         {
         "relayType": "dns",
         "relayEntry": "relay-2.mypool.com",
         "relayPort": "3001"
         }
  ],
  "poolMetaName": "This is my Pool",
  "poolMetaDescription": "This is the description of my Pool!",
  "poolMetaTicker": "POOL",
  "poolMetaHomepage": "https://mypool.com",
  "poolMetaUrl": "https://mypool.com/mypool.metadata.json",
  "poolExtendedMetaUrl": "",
  "---": "--- DO NOT EDIT BELOW THIS LINE ---",
  "poolMetaHash": "f792c672a350971266b5404f04ff3bd47deb1544bc411566a2f95c090c1202cf",
  "regCertCreated": "So Mai 31 14:38:53 CEST 2020",
  "regCertFile": "mypool.pool.cert",
  "poolID": "68c2d7335f542f2d8b961bf6de5d5fd046b912b671868b30b79c3e2219f7e51a",
  "regEpoch": "21",
  "regSubmitted": "So Mai 31 14:39:46 CEST 2020",
  "deregCertCreated": "Di Jun  2 17:13:39 CEST 2020",
  "deregCertFile": "mypool.pool.dereg-cert",
  "deregEpoch": "37",
  "deregSubmitted": "Di Jun  2 17:14:38 CEST 2020"
}
```

</details>


### Filenames used

<details>
   <summary><b>Show all used naming schemes like *.addr, *.skey, *.pool.json, ... </b>:bookmark_tabs:<br></summary>
   
<br>I use the following naming scheme for the files:<br>
``` 
Simple "enterprise" address to only receive/send funds (no staking possible with these type of addresses):
name.addr, name.vkey, name.skey

Payment(Base)/Staking address combo:
name.payment.addr, name.payment.skey/vkey, name.deleg.cert
name.staking.addr, name.staking.skey/vkey, name.staking.cert/dereg-cert

Node/Pool files:
poolname.node.skey/vkey, poolname.node.counter, poolname.pool.cert/dereg-cert, poolname.pool.json,
poolname.metadata.json, poolname.extended-metadata.json, poolname.additional-metadata.json
poolname.vrf.skey/vkey, poolname.pool.id, poolname.pool.id-bech
poolname.kes-xxx.skey/vkey, poolname.node-xxx.opcert (xxx increments with each KES generation = poolname.kes.counter)
poolname.kes.counter, poolname.kes-expire.json

ONLINE<->OFFLINE transfer files:
offlineTransfer.json

ITN witness files:
poolname.itn.skey/vkey
```

New for Hardware-Wallet (Ledger/Trezor) support:<br>
```
Hardware-SigningFile for simple "enterprise" address:
name.hwsfile (its like the .skey)

Hardware-SigningFile for Payment(Base)/Staking address combo:
name.payment.hwsfile, name.staking.hwsfile (its like the .skey)

Witness-Files for PoolRegistration or PoolReRegistration:
poolname_name_id.witness
```

New in Mary-Era:<br>
```
Policy files:
policyname.policy.skey/vkey, policyname.policy.script, policyname.policy.id

(Multi)Assets:
policyname.tokenname.asset
```

The *.addr files contains the address in the format "addr1vyjz4gde3aqw7e2vgg6ftdu687pcnpyzal8ax37cjukq5fg3ng25m" for example.
If you have an address and you wanna use it for later just do a simple:<br>
```echo "addr1vyjz4gde3aqw7e2vgg6ftdu687pcnpyzal8ax37cjukq5fg3ng25m" > myaddress.addr```

</details>

### File autolock for enhanced security

For a security reason, all important generated files are automatically locked against deleting/overwriting them by accident! Only the scripts will unlock/lock some of them automatically. If you wanna edit/delete a file by hand like editing the poolname.pool.json simply do a:<br>
```
chmod 600 poolname.pool.json
nano poolname.pool.json
chmod 400 poolname.pool.json
```

&nbsp;<br>&nbsp;<br>
# Working with Hardware-Wallets as an SPO

Please take a few minutes and take a look at the Sections here to find out how to prepare your system, what are the limitations when working with a Hardware-Wallet Ledger Nano S, Nano X or Trezor Model-T. If you need Multi-Witnesses and how to work with them if so ...

## Choose your preferred Key-Type for your Owner-Pledge-Account(s)

As an SPO you can choose how to handle your Owner Pledge Account(s). You can have them as CLI-based Payment&Stake keys, as HW-based Payment&Stake keys or you can have them as HYBRID keys with Hardware-Payment Protection via a HW-Wallet and Stake keys via normal CLI.

<details>
   <Summary><b>How to generate different Key-Types, Pros and Contras ... </b>:bookmark_tabs:<br></summary>

<br>Generating the different Key-Types is easy with the ```./03a_genStakingPaymentAddr.sh <name> <key-type>``` script. It takes two parameters:
* name: Thats the name you wanna use for the account/filename
* key-type: Here you can choose between the normal CLI keys, HW (Ledger/Trezor) keys and HYBRID keys.

| Key<br>Type | Payment/Spending<br>Key :key: | Staking/Rewards<br>Key :key: | Security<br>Level | Pros and Cons |
| :---: | :---: | :---: | :---: | :---: |
| CLI | via cli<br>(.skey) | via cli<br>(.skey) | medium | You can do everything, but you have<br>to keep your .skeys offline for enhanced security |
| HYBRID **&sup1;** | via HW-Wallet<br>(.hwsfile) | via cli<br>(.skey) | high | The pledge funds are protected via the Hardware-Wallet.<br>You can do Pool-Updates for MultiOwners without<br>any Hardware-Wallet attached. **&sup1;** |
| HW | via HW-Wallet<br>(.hwsfile) | via HW-Wallet<br>(.hwsfile) | highest | Pledge funds and Stake keys are secured<br>via the Hardware-Wallet. MultiOwnerPools have to sign<br>with each Hardware-Wallet for every PoolUpdate |

So you can see in this table there are Pros and Cons with the different types of Keys. You as the SPO have to choose how you wanna work.

:warning: **&sup1;**) The Hybrid-Mode is kind of a "comfort" mode for MultiOwnerPools, but you have to take the following in consideration: You have to use the generated payment(base) Address to fund with your Pledge, you will not see your Wallet delegated to your Pool if your plug the Hardware-Key into Daedalus-, Yoroi- or Adalite-Wallet. If you do a transaction out of it via one of the said wallets, you have to take everything out and send it back to the generated payment(base) Address. So, this mode is comfortable, it protects the Funds with the Hardware-Key, but you also must be a little careful. :smiley:

</details>

## Limitations to the PoolOperation when using Hardware-Wallets

<details>
   <summary><b>About Limitations, what can you do, what can't you do ...</b>:bookmark_tabs:<br></summary>
   
<br>So, there are many things you can do with your Hardware-Wallet as an SPO, but there are also many limitations because of security restrictions. I have tried to make this list below so you can see whats possible and whats not. If its not in this list, its not possible with a Hardware-Wallet for now:

| Action | Payment via CLI-Keys:key: | Payment via HW-Keys:key: (Ledger/Trezor) |
| :---         |     :---:      |     :---:     |
| Create a enterprise(payment only, no staking) address | :heavy_check_mark: | :heavy_check_mark: |
| Create a stakingaddress combo (base-payment & stake address) | :heavy_check_mark: | :heavy_check_mark: |
| Send ADA from the HW payment address | :x: | :heavy_check_mark: |
| Send, Mint or Burn Assets from the HW payment address | :x: | :x:<br>mary assets not supported yet |
| Claim Rewards from a CLI stake address | :heavy_check_mark: | :x: |
| Claim Rewards from then HW stake address, Paying with the HW payment address | :x: | :heavy_check_mark: |
| Claim Rewards from then HW stake address, Paying with a CLI payment address | :x:<br>(:heavy_check_mark: when HW keys are in hybrid mode*) | :x: |
| Register HW staking keys on the chain | :x: | :heavy_check_mark: |
| Register CLI staking keys on the chain | :heavy_check_mark: | :x: |
| Delegate HW staking keys to a stakepool | :x: | :heavy_check_mark: |
| Delegate CLI staking keys to a stakepool | :heavy_check_mark: | :x: |
| Register a stakepool with HW staking keys as an owner | :heavy_check_mark: | :x: |
| Register a stakepool with HW staking keys as an rewards-account | :heavy_check_mark: | :x: |
| Register a stakepool together with all the delegation certificates if only CLI owner keys are used | :heavy_check_mark: | :x: |
| Register a stakepool together with all the delegation certificates if a HW staking key is used as an rewards-account | :heavy_check_mark: | :x: |
| Register a stakepool together with all the delegation certificates if at least one owner is a HW staking key | :x:<br>(:heavy_check_mark: when HW keys are in hybrid mode*) | :x: |
| Retire HW staking keys from the chain | :x: | :heavy_check_mark: |
| Retire CLI staking keys from the chain | :heavy_check_mark: | :x: |
| Retire a a stakepool from the chain | :heavy_check_mark: | :x: |

Basically, you have to do all HW-Wallet related things directly with the hardware wallet.

*) You can overcome some of the issues by using a Hybrid-StakeAddress with the Hardware-Wallet. In that case you can work with the HW stake keys like with normal CLI keys, only the payment keys are protected via the HW Wallet (MultiOwner-ComfortMode). Creating such a Hybrid-StakingAddressCombo for a HW-Wallet is supported by the script ```./03a_genStakingPaymentAddr.sh <name> hybrid``` command. Check the different key-types [here](#choose-your-preferred-key-type-for-your-owner-pledge-accounts)

</details>

## How to prepare your system before using a Hardware-Wallet

We don't want to run the scripts as a superuser (sudo), so you should add some udev informations. Also for Trezor you have to install the Trezor Bridge.

<details>
   <summary><b>Prepare your system so you can use the Hardware-Wallet as a Non-SuperUser ...</b>:bookmark_tabs:<br></summary>

### Installing the cardano-hw-cli from Vacuumlabs

In addition to the normal cardano-cli and cardano-node from IOHK/IOG, we need the cardano-hw-cli binary.
You can find the GitHub-Repository here: https://github.com/vacuumlabs/cardano-hw-cli

Please follow the installation instructions on the website, its really simple to get the binary onto your system. You can install it via a .deb Package, from a .tar.gz or you can compile it yourself.

### Installing Ledger Nano S / Nano X

You can find a pretty good summary of how to add the udev rules to you system on this website: https://support.ledger.com/hc/en-us/articles/360019301813-Fix-USB-issues

But to make this here a one-stop i will include the udev rules also here. You have to set the username correct in this rulez, they are included in the lines with ```OWNER=<username>```, **replace it with your actual username!** So, please add the following file to your Debian/Ubuntu based Linux-System, Arch need other rulez:
   
   **/etc/udev/rules.d/20-hw1.rules**
   ``` console
   # HW.1 / Nano
SUBSYSTEMS=="usb", ATTRS{idVendor}=="2581", ATTRS{idProduct}=="1b7c|2b7c|3b7c|4b7c", TAG+="uaccess", TAG+="udev-acl", OWNER=<username>
# Blue
SUBSYSTEMS=="usb", ATTRS{idVendor}=="2c97", ATTRS{idProduct}=="0000|0000|0001|0002|0003|0004|0005|0006|0007|0008|0009|000a|000b|000c|000d|000e|000f|0010|0011|0012|0013|0014|0015|0016|0017|0018|0019|001a|001b|001c|001d|001e|001f", TAG+="uaccess", TAG+="udev-acl", OWNER=<username>
# Nano S
SUBSYSTEMS=="usb", ATTRS{idVendor}=="2c97", ATTRS{idProduct}=="0001|1000|1001|1002|1003|1004|1005|1006|1007|1008|1009|100a|100b|100c|100d|100e|100f|1010|1011|1012|1013|1014|1015|1016|1017|1018|1019|101a|101b|101c|101d|101e|101f", TAG+="uaccess", TAG+="udev-acl", OWNER=<username>
# Aramis
SUBSYSTEMS=="usb", ATTRS{idVendor}=="2c97", ATTRS{idProduct}=="0002|2000|2001|2002|2003|2004|2005|2006|2007|2008|2009|200a|200b|200c|200d|200e|200f|2010|2011|2012|2013|2014|2015|2016|2017|2018|2019|201a|201b|201c|201d|201e|201f", TAG+="uaccess", TAG+="udev-acl", OWNER=<username>
# HW2
SUBSYSTEMS=="usb", ATTRS{idVendor}=="2c97", ATTRS{idProduct}=="0003|3000|3001|3002|3003|3004|3005|3006|3007|3008|3009|300a|300b|300c|300d|300e|300f|3010|3011|3012|3013|3014|3015|3016|3017|3018|3019|301a|301b|301c|301d|301e|301f", TAG+="uaccess", TAG+="udev-acl", OWNER=<username>
# Nano X
SUBSYSTEMS=="usb", ATTRS{idVendor}=="2c97", ATTRS{idProduct}=="0004|4000|4001|4002|4003|4004|4005|4006|4007|4008|4009|400a|400b|400c|400d|400e|400f|4010|4011|4012|4013|4014|4015|4016|4017|4018|4019|401a|401b|401c|401d|401e|401f", TAG+="uaccess", TAG+="udev-acl", OWNER=<username>

KERNEL=="hidraw*", SUBSYSTEM=="hidraw", MODE="0660", GROUP="plugdev", ATTRS{idVendor}=="2c97"
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", MODE="0660", GROUP="plugdev", ATTRS{idVendor}=="2581"
   ```
After you have created this file in the /etc/udev/rules.d folder, please run the following commands to inform the system about it:
``` console
$ sudo udevadm trigger
$ sudo udevadm control --reload-rules
```
You should now be able to use your Ledger Nano S or Nano X device as the username you have set in the rules table without using sudo. :smiley:

### Installing Trezor Model-T

Installing the Trezor HW-Wallet is similar like to Trezor, but you also need to **install the Trezor Bridge** after you have added the udev rules.

**1. Set the udev Rules**

You can find the support page for the udev rules of the Trezor devices here: https://wiki.trezor.io/Udev_rules

But to make this here a one-stop i will include the udev rules also here. You have to set the username correct in this rulez, they are included in the lines with ```OWNER=<username>```, **replace it with your actual username!** So, please add the following file to your Debian/Ubuntu based Linux-System, Arch need other rulez:

   **/etc/udev/rules.d/51-trezor.rules**
   ```console
   # Trezor
SUBSYSTEM=="usb", ATTR{idVendor}=="534c", ATTR{idProduct}=="0001", MODE="0660", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl", SYMLINK+="trezor%n", OWNER=<username>
KERNEL=="hidraw*", ATTRS{idVendor}=="534c", ATTRS{idProduct}=="0001", MODE="0660", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl"

# Trezor v2
SUBSYSTEM=="usb", ATTR{idVendor}=="1209", ATTR{idProduct}=="53c0", MODE="0660", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl", SYMLINK+="trezor%n", OWNER=<username>
SUBSYSTEM=="usb", ATTR{idVendor}=="1209", ATTR{idProduct}=="53c1", MODE="0660", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl", SYMLINK+="trezor%n", OWNER=<username>
KERNEL=="hidraw*", ATTRS{idVendor}=="1209", ATTRS{idProduct}=="53c1", MODE="0660", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl"

   ```
After you have created this file in the /etc/udev/rules.d folder, please run the following commands to inform the system about it:
``` console
$ sudo udevadm trigger
$ sudo udevadm control --reload-rules
```

Now would be the time to unplug and reconnect your Trezor Model-T device.

**2. Install the Trezor-Bridge:**

This is the last step needed, you need to install the latest version of the Trezor-Bridge. You can find the latest version on the official TrezorBridge Github-Repo [here](https://github.com/trezor/webwallet-data/tree/master/bridge).

In time of writing, the latest released TrezorBridge version is 2.0.27, so lets grab that and install it:

``` console
$ sudo wget https://github.com/trezor/webwallet-data/raw/master/bridge/2.0.27/trezor-bridge_2.0.27_amd64.deb
$ sudo dpkg -i trezor-bridge_2.0.27_amd64.deb
```

You should now be able to use your Trezor Model-T device as the username you have set in the rules table without using sudo. You can check the status of the running TrezorBridge in the background by launching a browser and checking the Status-Page at [http://127.0.0.1:21325](http://127.0.0.1:21325) :smiley:

</details>

## Changes to the Operator-Workflow when Hardware-Wallets are involved

Many steps in the workflow are pretty much the same with or without a Hardware-Wallet involved. But there were changes needed to some steps and scripts calls. There are several Limitations what you can do with a HW-Wallet, you can find the list [here](#limitations-to-the-pooloperation-when-using-hardware-wallets).

<details>
   <Summary><b>Register a StakePool with Hardware-Wallet owners involved ... </b>:bookmark_tabs:<br></summary>

<br>One of the major changes comes when you have at least one owner in the StakePool with the stake key from a Hardware-Wallet. Before (when we had only one or more CLI-based stake keys as owners) the StakePool Registration was made with the script ```./05c_regStakepoolCert.sh``` alone, and that Registration included the StakePool Certificate itself and also ALL of the owner delegations to the pool. Thats not possible anymore with a Hardware-Wallet involved as an owner! Only the PoolRegistrationCertificate itself can be included in the Registration. You have to register each owner delegation after the pool Registration individually. (Still possible to do it in one step if a Hardware-Wallet is only used as the destination rewards address for a StakePool!)

So, how do we work now? The answer here is "Multi-Witnesses". Each signing key for the PoolRegistration must be a unique signed Witness now that we assemble together to form the PoolRegistration. These are the signed Witness of the NodeColdKeys, the signed Witness of the Registration payment address and of course all signed Witnesses of each owner.<br>

You can choose how you wanna handle the owner Witnesses via a **new entry** in the ```"poolOwner"``` list (*poolname.pool.json* config file) named **```"ownerWitness"```**, take a look here:

**mypool.pool.json:**
```console
   {
      "poolName": "mypool",
      "poolOwner": [
         {
         "ownerName": "owner-1",
         "ownerWitness": "local"
         },
         {
         "ownerName": "ledgerowner",
         "ownerWitness": "local"
         },
         {
         "ownerName": "owner-2",
         "ownerWitness": "external"
         }
      ],
      "poolRewards": "rewards-account",
      "poolPledge": "200000000000",
      "poolCost": "10000000000",
      "poolMargin": "0.08"
   ...
   ```
You can see two different examples, ```local``` and ```external```:

* **local** means that you have to sign the Witness directly when you call the ```./05c_regStakepoolCert.sh``` script. Thats the prefered method if you're the only owner of the pool and you have your Hardware-Wallet available to plug it into your machine.

* **external** means that you wanna sign this Witness separate in an additional step. This can be on the *same machine* or it can be on *another machine*. So this comes also in handy when you run a *MultiOwnerPool*, thats the method you collect the signed Witnesses from all the other owners.

> :warning: As i wrote above, when at least one pool owner is using a Hardware-Wallet stake key, the individual owner delegations are not included anymore automatically when running ```./05c_regStakepoolCert.sh```. Therefore **you have to transmit each pool delegation** for each owner one by one **after the pool Registration** via the script ```./06_regDelegationCert.sh```! If you're doing this on an Offline-Machine, make sure you have a few small CLI-based operator wallets laying around (smallwallet1, smallwallet2, smallwallet3,...) to directly pay for each delegation registration.<br>Also you can include all the unsigned Witness files in the **offlineTransfer.json** to bring it out of your Offline-Machine if you like. :smiley:

Read more about how to sign, transfer and assemble unsigned/signed Witnesses in the next Article.

</details>

<details>
   <Summary><b>How to work with Multi-Witnesses with/without Hardware-Wallet owners involved ... </b>:bookmark_tabs:<br></summary>

<br>As you have read in the previous article, we have to deal with Multi-Witnesses now for a PoolRegistration if Hardware-Wallets are involved as owners. You can also use Multi-Witnesses with normal CLI-based accounts if you like to work this way in a MultiPoolOwner environment. 

When you run ```./05c_regStakepoolCert.sh mypool smallwallet1``` and you have **external** Witnesses in your **poolname.pool.json** you will get out one, two or more **unsigned** Witness-Files in the naming scheme: ```<poolname>.<ownername>_<id>.witness```<br>
In Offline-Mode the script will ask you if you wanna include these files directly into the **offlineTransfer.json** to bring it over to the Online-Machine. You can decide about this for each Witness-File.

### Check about the Witness-Status in your current PoolRegistration process

If there are any **unsigned Witnesses** left open for your PoolRegistration, you can't complete the transaction. To handle all the Witness-Functions a new script was created with the name **```./05d_poolWitness.sh```** :smiley:

You can check the current status of your Witnesses for your pool **mypool** (example) by running: **```./05d_poolWitness info mypool```**

This will show you how many Witnesses included in your current PoolRegistration are READY **signed (green)** and which ones are MISSING **unsigned (magenta)** and must be signed now.<br>To do so you have the Witness-File we learned about a few lines above ```<poolname>.<ownername>_<id>.witness```. You can **sign a Witness-File** on the same machine, on your Online-Machine, on your Offline-Machine or send the file around the world and let it sign by a friend so he can send it back to you later. 

> :warning: You have a limited time window to complete all the Witnesses, this is set to 100.000 slots, so a little bit over 1 day !

### Sign an unsigned Witness-File

Lets say we have an unsigned Witness-File for the pool owner *ledgerowner* for the pool *mypool* and we wanna sign this now.

To sign the Witness-File with the corresponding signing key just run<br>**```./05d_poolWitness sign mypool.ledgerowner_1609258523.witness ledgerowner```**

If the stake key is a normal cli key it will sign it directly, if its a Ledger Hardware-Wallet (as the name suggests) you need to connect the Ledger now and execute the signing with it. When the **unsigned** Witness-File is **signed**, it will save the information about it back into the same Witness-File. Transfer it back to your original machine if you have moved it out somewhere to now **add** it back to your ongoing PoolRegistration. Read in the next chapter how to do so.

### Adding signed Witness-Files to your Pool Registration (Assemble Witnesses)

When you're finished signing all the pending Witness-Files its now time to **add** them back together into your ongoing Pool Registration.

You can check the current status of your Witnesses for your pool **mypool** (example) by running: **```./05d_poolWitness info mypool```**

To **add a signed Witness-File** into your current Pool Registration simply run: <br>**```./05d_poolWitness add mypool.ledgerowner_1609258523.witness mypool```**

The script will do a check if the Witness is correct and will add it to the Witness-Collection if so. Also you will see a status update about your currently included Witnesses. If there are some left or if they are now all complete (all Witness showing a green READY).

Run the command again for eachr **pending signed Witness-File** until you have added them all.

### Submit the final Pool Registration 

After you have included(add) all signed Witnesses back into the Pool Registration, you can finally execute the transaction by simply running the original command again like:<br>**```./05c_regStakepoolCert.sh mypool smallwallet1```**

If you're in Offline-Mode, the script will again ask you if you wanna include the transaction in the **offlineTransfer.json** to bring it to the Online-Machine. In Online-Mode the transaction will be execute directly on the chain.

DONE - Puuh :smiley:

> :warning: If you have created a new Pool or if you have added new owners, you have to register each Delegation now on the chain via script ```./06_regDelegationCert.sh```. This additional step is normally included in the ```./05c_regStakepoolCert.sh``` but cannot be used if an owner is a Hardware-Wallet !

> :warning: As long as you have an ongoing opened Pool Registration, you're not allowed to use your payment address for anything else, because the txBody is already made with the exact amounts of ADA for the transaction in & out !

### Abort an ongoing Pool Registration Witness-Collection

If you have made a mistake in the pool config, or if you just wanna start over again you have to clear all the Witness entries in the Witness-Collection of the ongoing Pool Registration.

To **clear all Witness-Entries** in the Pool Registration **to start fresh** simply run: **```./05d_poolWitness clear mypool```**

Yep, it was that simple.

</details>

<details>
   <summary><b>How do you migrate your existing StakePool to HW-Wallet-Owner-Keys ... </b>:bookmark_tabs:</summary>

<br>You can find examples below in the Online- and Offline-Examples section. [Online-Migration-Example](#migrate-your-existing-stakepool-to-hw-wallet-owner-keys-ledgertrezor), [Offline-Migration-Example](#migrate-your-existing-stakepool-offline-to-hw-wallet-owner-keys-ledgertrezor)

</details>

&nbsp;<br>&nbsp;<br>
# Examples in Online-Mode

> :bulb: **The examples below are using the scripts in the same directory, so they are listed with a leading ./**<br>
**If you have the scripts copied to an other directory reachable via the PATH environment variable, than call the scripts WITHOUT the leading ./ !**

The examples in here are for using the scripts in Online-Mode. Please get yourself familiar on how to use each single script, a detailed Syntax about each script can be found [here](#configuration-scriptfiles-syntax--filenames). Make sure you have a fully synced passive node running on your machine, make sure you have set the right parameters in the scirpts config file **00_common.sh**<br>
Working in [Offline-Mode](#examples-in-offline-mode) introduces another step before and ofter each example, so you should understand the Online-Mode first.

:bulb: Make sure your 00_common.sh is having the correct setup for your system!

## Generate some wallets for the daily operator work

So first you should create yourself a few small wallets for the daily Operator work, there is no need to use your big-owner-pledge-wallet for this every time. Lets say we wanna create three small wallets with the name smallwallet1, smallwallet2 and smallwallet3. And we wanna fund them via daedalus for example.

<details>
   <Summary><b>Show Example ... </b>:bookmark_tabs:<br></summary>
   
<br><b>Steps:</b>
1. Create three new payment-only wallets by running<br>```./02_genPaymentAddrOnly.sh smallwallet1 cli```<br>```./02_genPaymentAddrOnly.sh smallwallet2 cli```<br>```./02_genPaymentAddrOnly.sh smallwallet3 cli```
1. Fund the three wallets with some ADA from your existing Daedalus or Yoroi wallet. You can show the address and the current balance by running<br>
```./01_queryAddress.sh smallwallet1```<br>```./01_queryAddress.sh smallwallet2```<br>```./01_queryAddress.sh smallwallet3```

Theses are your **daily work** operator wallets, never ever use your pledge owner wallet for such works, don't do it, be safe.<br>
If you wanna do a pool registration (next step) make sure that you have **at least 505 ADA** on your *smallwallet1* account!

</details>

## Create the StakePool with CLI-Owner-Keys

We want to make ourself a pool owner stake address with the nickname owner, we want to register the pool with the name mypool. The name is only to keep the files on the harddisc in order, name is not a ticker!

<details>
   <Summary><b>Show Example ... </b>:bookmark_tabs:<br></summary>

<br><b>Steps:</b>
1. Make sure you have enough funds on your *smallwallet1* account we created before. You will need around **505 ADA to complete the process**. You can check the current balance by running ```./01_queryAddress.sh smallwallet1```
1. Generate the owner stake/payment combo with ```./03a_genStakingPaymentAddr.sh owner cli```
1. Register the owner stake key on the blockchain, **smallwallet1** will pay for this<br>```./03b_regStakingAddrCert.sh owner smallwallet1```
1. Wait a minute so the transaction and stake key registration is completed
1. Verify that your stake key in now on the blockchain by running<br>```./03c_checkStakingAddrOnChain.sh owner``` if you don't see it, wait a little and retry
1. Generate the keys for your coreNode
   1. ```./04a_genNodeKeys.sh mypool```
   1. ```./04b_genVRFKeys.sh mypool```
   1. ```./04c_genKESKeys.sh mypool```
   1. ```./04d_genNodeOpCert.sh mypool```
1. Now you have all the key files to start your coreNode with them: **mypool.vrf.skey, mypool.kes-000.skey, mypool.node-000.opcert**
1. Generate your stakepool certificate
   1. ```./05a_genStakepoolCert.sh mypool```<br>will generate a prefilled **mypool.pool.json** file for you, **edit it !**
   1. We want 200k ADA pledge, 500 ADA costs per epoch and 4% pool margin so let us set these and the Metadata values in the json file like
   ```console
   {
      "poolName": "mypool",
      "poolOwner": [
         {
         "ownerName": "owner",
         "ownerWitness": "local"
         }
      ],
      "poolRewards": "owner",
      "poolPledge": "200000000000",
      "poolCost": "500000000",
      "poolMargin": "0.04"
      "poolRelays": [
         {
         "relayType": "dns",
         "relayEntry": "relay.mypool.com",
         "relayPort": "3001"
         }
      ],
      "poolMetaName": "This is my Pool",
      "poolMetaDescription": "This is the description of my Pool!",
      "poolMetaTicker": "POOL",
      "poolMetaHomepage": "https://mypool.com",
      "poolMetaUrl": "https://mypool.com/mypool.metadata.json",
      "poolExtendedMetaUrl": "",
      "---": "--- DO NOT EDIT BELOW THIS LINE ---"
   }
   ```
1. Run ```./05a_genStakepoolCert.sh mypool``` again with the saved json file, this will generate the **mypool.pool.cert** file
1. Delegate to your own pool as owner -> **pledge** ```./05b_genDelegationCert.sh mypool owner``` this will generate the **owner.deleg.cert**
1. :bulb: **Upload** the generated ```mypool.metadata.json``` file **onto your webserver** so that it is reachable via the URL you specified in the poolMetaUrl entry! Otherwise the next step will abort with an error.
1. Register your stakepool on the blockchain ```./05c_regStakepoolCert.sh mypool smallwallet1```
1. Optionally you can verify that your delegation to your pool is ok by running<br>```./03c_checkStakingAddrOnChain.sh owner``` if you don't see it instantly, wait a little and retry the same command

:warning: Make sure you transfer enough ADA to your new **owner.payment.addr** so you respect the registered Pledge amount, otherwise you will not get any rewards for you or your delegators!

Done. :smiley:
</details>

## Create the StakePool with HW-Wallet-Owner-Keys (Ledger/Trezor)

We want to make ourself a pool owner stake address with the nickname ledgerowner by using a HW-Key, we want to register the pool with the poolname mypool. The poolname is only to keep the files on the harddisc in order, poolname is not a ticker!

<details>
   <Summary><b>Show Example ... </b>:bookmark_tabs:<br></summary>

<br><b>Steps:</b>
1. Make sure you have enough funds on your *smallwallet1* account we created before. You will need around **510 ADA to complete the process**. You can check the current balance by running ```./01_queryAddress.sh smallwallet1```
1. Generate the owner stake/payment combo with full Hardware-Keys ```./03a_genStakingPaymentAddr.sh ledgerowner hw```<br>
   See your options in the section [here](#choose-your-preferred-key-type-for-your-owner-pledge-accounts) to choose between CLI, HW and HYBRID keys.  
1. Send some funds from your *smallwallet1* to your new *ledgerowner.payment* address for the stake key and delegation registration, 5 ADA should be ok for this ```./01_sendLovelaces.sh smallwallet1 ledgerowner.payment 5000000```
1. Wait a minute so the transaction is completed   
1. Register the ledgerowner stake key on the blockchain, **the hw-wallet itself must pay for this**<br>```./03b_regStakingAddrCert.sh ledgerowner ledgerowner.payment```
1. Wait a minute so the transaction and stake key registration is completed
1. Verify that your stake key in now on the blockchain by running<br>```./03c_checkStakingAddrOnChain.sh ledgerowner``` if you don't see it, wait a little and retry
1. Generate the keys for your coreNode
   1. ```./04a_genNodeKeys.sh mypool```
   1. ```./04b_genVRFKeys.sh mypool```
   1. ```./04c_genKESKeys.sh mypool```
   1. ```./04d_genNodeOpCert.sh mypool```
1. Now you have all the key files to start your coreNode with them: **mypool.vrf.skey, mypool.kes-000.skey, mypool.node-000.opcert**
1. Generate your stakepool certificate
   1. ```./05a_genStakepoolCert.sh mypool```<br>will generate a prefilled **mypool.pool.json** file for you, **edit it !**
   1. We want 200k ADA pledge, 500 ADA costs per epoch and 4% pool margin so let us set these and the Metadata values in the json file like below. Also we want the 
ledgerowner as owner and also as rewards-account. We do the signing on the machine itself so ownerWitness can stay at 'local'. You can find out more about the ownerWitness parameter and how to work with Multi-Witnesses [here](#changes-to-the-operator-workflow-when-hardware-wallets-are-involved):
   ```console
   {
      "poolName": "mypool",
      "poolOwner": [
         {
         "ownerName": "ledgerowner",
         "ownerWitness": "local"
         }
      ],
      "poolRewards": "ledgerowner",
      "poolPledge": "200000000000",
      "poolCost": "500000000",
      "poolMargin": "0.04"
      "poolRelays": [
         {
         "relayType": "dns",
         "relayEntry": "relay.mypool.com",
         "relayPort": "3001"
         }
      ],
      "poolMetaName": "This is my Pool",
      "poolMetaDescription": "This is the description of my Pool!",
      "poolMetaTicker": "POOL",
      "poolMetaHomepage": "https://mypool.com",
      "poolMetaUrl": "https://mypool.com/mypool.metadata.json",
      "poolExtendedMetaUrl": "",
      "---": "--- DO NOT EDIT BELOW THIS LINE ---"
   }
   ```
1. Run ```./05a_genStakepoolCert.sh mypool``` again with the saved json file, this will generate the **mypool.pool.cert** file
1. Delegate to your own pool as owner -> **pledge** ```./05b_genDelegationCert.sh mypool ledgerowner``` this will generate the **ledgerowner.deleg.cert**
1. :bulb: **Upload** the generated ```mypool.metadata.json``` file **onto your webserver** so that it is reachable via the URL you specified in the poolMetaUrl entry! Otherwise the next step will abort with an error.
1. Register your stakepool on the blockchain, smallwallet1 will pay for the registration fees<br>```./05c_regStakepoolCert.sh mypool smallwallet1```
1. Wait a minute so the transaction and stakepool registration is completed
1. Send all owner delegations to the blockchain. :bulb: Notice! This is different than before when using only CLI-Owner-Keys, if any owner is a HW-Wallet than you have to send the individual delegations after the stakepool registration. You can read more about it [here](#changes-to-the-operator-workflow-when-hardware-wallets-are-involved).<br>We have only one owner so lets do this by running the following command, **the HW-Wallet itself must pay for this**<br>```./06_regDelegationCert.sh ledgerowner ledgerowner.payment```
1. Wait a minute so the transaction and delegation certificate is completed
1. Verify that your owner delegation to your pool is ok by running<br>```./03c_checkStakingAddrOnChain.sh ledgerowner``` if you don't see it instantly, wait a little and retry the same command

:warning: Make sure you transfer enough ADA to your new **ledgerowner.payment.addr** so you respect the registered Pledge amount, otherwise you will not get any rewards for you or your delegators!

Done. :smiley:
</details>

## Migrate your existing StakePool to HW-Wallet-Owner-Keys (Ledger/Trezor)

So this is an important one for many of you that already have registered a stakepool on Cardano before. Now is the time to upgrade your owner funds security to the next level by using HW-Wallet-Keys instead of CLI-Keys. In the example below we have an existing CLI-Owner with name **owner**, and we want to migrate that to the new owner with name **ledgerowner**. The poolname is mypool in this example, but you know the game, you have done it before.

<details>
   <Summary><b>Show Example ... </b>:bookmark_tabs:<br></summary>

<br><b>Steps:</b>
1. Make sure you have enough funds on your *smallwallet1* account we created before. You will need around **5 ADA to complete the process**. You can check the current balance by running ```./01_queryAddress.sh smallwallet1```
1. The poolOwner section in your mypool.pool.json file looks like this right now:
   ```console
   ...
      "poolName": "mypool",
      "poolOwner": [
         {
         "ownerName": "owner",
         "ownerWitness": "local"
         }
      ],
      "poolRewards": "owner",
      "poolPledge": "200000000000",
   ...
   ```
   Maybe you don't have the ownerWitness entry, but thats ok it will be added automatically or you can add it by yourself.
1. Generate the new owner stake/payment combo with full Hardware-Keys ```./03a_genStakingPaymentAddr.sh ledgerowner hw```<br>
   See your options in the section [here](#choose-your-preferred-key-type-for-your-owner-pledge-accounts) to choose between CLI, HW and HYBRID keys.  
1. Send some funds from your *smallwallet1* to your new *ledgerowner.payment* address for the stake key and delegation registration, 5 ADA should be ok for this ```./01_sendLovelaces.sh smallwallet1 ledgerowner.payment 5000000```
1. Wait a minute so the transaction is completed   
1. Register the ledgerowner stake key on the blockchain:<br>&nbsp;<br>
   * ```./03b_regStakingAddrCert.sh ledgerowner ledgerowner.payment``` if you have a Full-Hardware(**HW**) key (Step 3)<br>
  or
   * ```./03b_regStakingAddrCert.sh ledgerowner smallwallet1``` if you have a Hybrid-Hardware(**HYBRID**) key (Step 3)<br>&nbsp;
1. Wait a minute so the transaction and stake key registration is completed
1. Verify that your stake key in now on the blockchain by running<br>```./03c_checkStakingAddrOnChain.sh ledgerowner``` if you don't see it, wait a little and retry
1. [Unlock](#file-autolock-for-enhanced-security) the existing mypool.pool.json file and **add the new ledgerowner** to the list of owners, also we want that the new rewards account is also the new ledgerowner. Only edit the values above the "--- DO NOT EDIT BELOW THIS LINE ---" line, **EDIT IT** and **SAVE IT**:
   ```console
   ...
      "poolName": "mypool",
      "poolOwner": [
         {
         "ownerName": "owner",
         "ownerWitness": "local"
         },
         {
         "ownerName": "ledgerowner",
         "ownerWitness": "local"
         }
      ],
      "poolRewards": "ledgerowner",
      "poolPledge": "200000000000",
   ...
   ```
   We wanna do the signing on this machine so you can leave ownerWitness at 'local'. You can find out more about the ownerWitness parameter and how to work with Multi-Witnesses [here](#changes-to-the-operator-workflow-when-hardware-wallets-are-involved)
1. Run ```./05a_genStakepoolCert.sh mypool``` to generate the updated pool certificate **mypool.pool.cert**
1. Delegate the new **ledgerowner** to your own pool as owner -> **pledge** ```./05b_genDelegationCert.sh mypool ledgerowner``` this will generate the **ledgerowner.deleg.cert**
1. If you have changed also some Metadata, **upload** the newly generated ```mypool.metadata.json``` file **onto your webserver** so that it is reachable via the URL you specified in the poolMetaUrl entry! Otherwise the next step will abort with an error. If you have only updated the owners, skip it.
1. Re-Register your stakepool on the blockchain, smallwallet1 will pay for the registration fees. This will be only a pool update, so this will not cost you the initial 500 ADA, only a few fees.<br>```./05c_regStakepoolCert.sh mypool smallwallet1```
1. Wait a minute so the transaction and stakepool registration is completed
1. Send all new owner delegations to the blockchain. :bulb: Notice! This is different than before when using only CLI-Owner-Keys, if any owner is a HW-Wallet than you have to send the individual delegations after the stakepool registration. You can read more about it [here](#changes-to-the-operator-workflow-when-hardware-wallets-are-involved). We have only one new owner so lets do this by running the following command:<br>&nbsp;<br>
   * ```./06_regDelegationCert.sh ledgerowner ledgerowner.payment``` if you have a Full-Hardware(**HW**) key (Step 3)<br>
   or
   * ```./06_regDelegationCert.sh ledgerowner smallwallet1``` if you have a Hybrid-Hardware(**HYBRID**) key (Step 3)<br>&nbsp;
1. Wait a minute so the transaction and delegation certificate is completed
1. Verify that your new owner delegation to your pool is ok by running<br>```./03c_checkStakingAddrOnChain.sh ledgerowner``` if you don't see it instantly, wait a little and retry the same command

&nbsp;<br>
:warning: <b>Now WAIT! Wait for 2 epoch changes!</b> :warning: So if you're doing this in epoch n, wait until epoch n+2 before you continue!

&nbsp;<br>
Now two epochs later your new additional **ledgerowner** co-owner is fully active. Its now the time to **transfer your owner funds** from the old **owner** to the new **ledgerowner**. You can do this by running:<br>```./01_sendLovelaces.sh owner.payment ledgerowner.payment ALLFUNDS```<br>This will move over all lovelaces and even assets that are on your old owner.payment address to your new ledger.payment address.

Be aware, this little transaction needed some fees, so you maybe have to top up your ledgerowner.payment account with 1 ADA from another wallet to met your registered pledge again. Check your balance on your ledgerowner account by running ```./01_queryAddress.sh ledgerowner.payment```

&nbsp;<br>
:warning: <b>WAIT AGAIN! Wait for 2 epoch changes!</b> :warning: So if you're doing this in epoch n, wait until epoch n+2 before you continue! :warning:

&nbsp;<br>
Why waiting again? Well, **we** also **changed the rewards-account** when we added the new ledgerowner, this takes 4 epochs on the blockchain to get fully updated. So, until now **you have received the rewards** of the pool **to your old owner.staking account**. Please check you rewards now and do a withdrawal of them, an example can be found below.

&nbsp;<br>
**Done**, you have fully migrated to your new ledgerowner, congrats! :smiley:

> Optional: If you wanna get rid of your old owner entry (you can leave it in there) in your stakepool registration - do the following:
  <br>Do it like the steps above, re-edit your mypool.pool.json file and remove the entry of the old owner from the poolOwner list. Save the file, generate a new certificate by running script 05a. Register it on the chain again like above or like the example below "Update stakepool parameters on the blockchain". Now you have only your new ledgerowner in your pool registration. 

</details>

## Update StakePool Parameters on the blockchain

If you wanna update you pledge, costs, owners or metadata on a registered stakepool just do the following

<details>
   <Summary><b>Show Example ... </b>:bookmark_tabs:<br></summary>

<br><b>Steps:</b>
1. [Unlock](#file-autolock-for-enhanced-security) the existing mypool.pool.json file and edit it. Only edit the values above the "--- DO NOT EDIT BELOW THIS LINE ---" line, save it again. 
1. Run ```./05a_genStakepoolCert.sh mypool``` to generate a new mypool.pool.cert file from it
1. :bulb: **Upload** the new ```mypool.metadata.json``` file **onto your webserver** so that it is reachable via the URL you specified in the poolMetaUrl entry! Otherwise the next step will abort with an error.
1. (Optional create delegation certificates if you have added an owner or an extra rewards account with script 05b)
1. Re-Register your stakepool on the blockchain with ```./05c_regStakepoolCert.sh mypool owner.payment```<br>No delegation update needed.

Done.  
</details>

## Claiming rewards on the blockchain

I'am sure you wanna claim some of your rewards that you earned running your stakepool. So lets say you have rewards in your owner.staking address and you wanna claim it to the owner.payment address.

<details>
   <Summary><b>Show Example ... </b>:bookmark_tabs:<br></summary>

<br><b>Steps:</b>
1. Check that you have rewards in your stakeaccount by running ```./01_queryAddress.sh owner.staking```
1. Now you can claim your rewards by running ```./01_claimRewards.sh owner.staking owner.payment```
   This will claim the rewards from the owner.staking account and sends it to the owner.payment address, also owner.payment will pay for the transaction fees.<br>
   Or, you can claim your rewards by running ```./01_claimRewards.sh owner.staking owner.payment smallwallet1``` This will claim the rewards from the owner.staking account and sends it to the owner.payment address, the smallwallet1 will pay for the transaction fees. It is only possible to claim all rewards, not only a part of it.
   
:bulb: ATTENTION, claiming rewards costs transaction fees! So you have two choices for that: The destination address pays for the transaction fees, or you specify an additional account that pays for the transaction fees like in the 2nd method shown above.

Done.  

### Claiming rewards from the ITN Testnet with only SK/PK keys

If you ran a stakepool on the ITN and you only have your owner SK ed25519(e) and VK keys you can claim your rewards now

<br><b>Steps:</b>
1. Convert your ITN keys into a Shelley Staking Address by running: 
   <br>```./0x_convertITNtoStakeAddress.sh <StakeAddressName> <Private_ITN_Key_File>  <Public_ITN_Key_File>```
   <br>```./0x_convertITNtoStakeAddress.sh myitnrewards mypool.itn.skey mypool.itn.vkey```
   <br>This will generate a new Shelley stakeaddress with the 3 files myitnrewards.staking.skey, myitnrewards.staking.vkey and myitnrewards.staking.addr
1. You can check now your rewards by running ```./01_queryAddress.sh myitnrewards.staking```
1. You can claim your rewards by running ```./01_claimRewards.sh myitnrewards.staking destinationaccount``` like a normal rewards claim procedure, example above!

Done.  
</details>

## Rotate the KES-Keys and the opcert of the StakePool

From time to time you have to rotate the so called HOT-Keys on your BlockProducer Node, thats the KES-Keys and the OPCERT. Here is an example on how to rotate the keys for your mypool.

<details>
   <summary><b>Show Example ... </b>:bookmark_tabs:<br></summary>

<br><b>Steps:</b>
1. ```./04c_genKESKeys.sh mypool```
1. ```./04d_genNodeOpCert.sh mypool```

Thats it, upload the new keys to your BlockProducer Node. Rename them or set the new right config, restart the BlockProducer Node to load the new keys.

Done.  
</details>

## Generate & register a stake address, just delegate to a StakePool

Lets say we wanna create a payment(base)/stake address combo with the nickname delegator and we wanna delegate the funds in the payment(base) address of that to the pool yourpool. (You'll need the yourpool.node.vkey for that.)

<details>
   <Summary><b>Show Example ... </b>:bookmark_tabs:<br></summary>

<br><b>Steps:</b>
1. Generate the delegator stake/payment combo with ```./03a_genStakingPaymentAddr.sh delegator cli```
1. Send over some funds to that new address delegator.payment.addr to pay for the registration fees and to stake that also later
1. Register the delegator stakeaddress on the blockchain ```./03b_regStakingAddrCert.sh delegator.staking delegator.payment```<br>Other example: ```./03b_regStakingAddrCert.sh delegator.staking smallwallet1``` Here you would use the funds in *smallwallet1* to pay for the fees.
1. You can verify that your stakeaddress in now on the blockchain by running<br>```./03c_checkStakingAddrOnChain.sh delegator``` if you don't see it instantly, wait a little and retry the same command
1. Generate the delegation certificate delegator.deleg.cert with ```./05b_genDelegationCert.sh yourpool delegator```
1. Register the delegation certificate now on the blockchain with funds from delegator.payment.addr<br>```./06_regDelegationCert.sh delegator delegator.payment```
1. You can verify that your delegation to the pool is ok by running<br>```./03c_checkStakingAddrOnChain.sh delegator``` if you don't see it instantly, wait a little and retry the same command

Done.
</details>


## Register a Multiowner-StakePool

It's similar to a single owner stake pool registration (example above). All owners must have a registered stake address on the blockchain first! Here is a 2 owner example ...

<details>
   <summary><b>Show Example ... </b>:bookmark_tabs:<br></summary>

<br><b>Steps:</b>
1. Generate the stakepool certificate
   1. ```./05a_genStakepoolCert.sh mypool```<br>will generate a prefilled mypool.pool.json file for you, edit it for multiowner usage and set your owners and also the rewards account. The rewards account is also a stake address (but not delegated to the pool!):
    ```console
   {
      "poolName": "mypool",
      "poolOwner": [
         {
         "ownerName": "owner-1",
         "ownerWitness": "local"
         },
         {
         "ownerName": "owner-2",
         "ownerWitness": "local"
         }
      ],
      "poolRewards": "rewards-account",
      "poolPledge": "200000000000",
      "poolCost": "10000000000",
      "poolMargin": "0.08"
   ...
   ```
   1. Run ```./05a_genStakepoolCert.sh mypool``` again with the saved json file, this will generate the mypool.pool.cert file
1. Delegate all owners to the pool -> pledge
<br>```./05b_genDelegationCert.sh mypool owner-1``` this will generate the owner-1.deleg.cert
<br>```./05b_genDelegationCert.sh mypool owner-2``` this will generate the owner-2.deleg.cert
1. Register your stakepool on the blockchain ```./05c_regStakepoolCert.sh mypool smallwallet1```    
1. Optionally you can verify that your delegation to your pool is ok by running<br>```./03c_checkStakingAddrOnChain.sh owner-1``` and ```./03c_checkStakingAddrOnChain.sh owner-2``` if you don't see it instantly, wait a little and retry the same command

Done.
</details>

## How to mint/create Native Tokens

From the Mary-Era on, you can easily mint(generate) Native-Tokens by yourself, here you can find an example on how to do it.

<details>
   <Summary><b>Show Example ... </b>:bookmark_tabs:<br></summary>

<br>So lets say we wanna create 1000 new Tokens with the name **SUPERTOKEN** under the policy **mypolicy**. And we want that theses AssetFiles are stored in the *assets* subdirectory. These Tokens should be generated on the account **mywallet**.

<br><b>Steps:</b>
1. First you have to generate a policyName/ID. You can reuse the same policyName/ID to mint other Assets(Tokens) later again. If you already have the policy, skip to step 3
1. Run ```./10_genPolicy.sh assets/mypolicy``` to generate a new policy with name 'mypolicy' in the assets subdirectory (you can do it in the same directory too of course)
1. Run ```./11a_mintAsset.sh assets/mypolicy.SUPERTOKEN 1000 mywallet``` to mint 1000 new SUPERTOKEN on the wallet mywallet. If you want, you can also add a custom Metadata.json file to the Minting-Transaction as the 4th parameter. Full-Syntax description can be found [here](#main-configuration-file-00_commonsh---syntax-for-all-the-other-ones)

The AssetsFile ***assets/mypolicy.SUPERTOKEN.asset*** was also written/updated with the latest action. You can see the totally minted Token count in there too.

Done - You have mint (created) 1000 new SUPERTOKENs and they are now added to the mywallet address. You can now send them out into the world with the example below. :smiley:

</details>

## How to burn/destroy Native Tokens

If you wanna burn(destroy) some Native-Tokens, you can do it similar to the minting process. Here you can find an example on how to do it.

<details>
   <Summary><b>Show Example ... </b>:bookmark_tabs:<br></summary>

<br>Important, you can only burn Native-Tokes that you have the policy for. You cannot burn other Native-Tokens that were sent to your wallet address. So lets say we wanna burn 200 **SUPERTOKEN** that we created before under the policy **mypolicy**. The AssetFiles were stored in the *assets* subdirectory, and the address we wanna burn the Tokens from is the account **mywallet**.

<br><b>Steps:</b>
1. Run ```./11b_burnAsset.sh assets/mypolicy.SUPERTOKEN 200 mywallet``` to burn 200 SUPERTOKENs from the wallet mywallet. If you want, you can also add a custom Metadata.json file to the Burning-Transaction as the 4th parameter. Full-Syntax description can be found [here](#main-configuration-file-00_commonsh---syntax-for-all-the-other-ones)

The AssetsFile ***assets/mypolicy.SUPERTOKEN.asset*** was also written/updated with the latest action. You can see the totally minted Token count in there too.

Done - You have burned (destroyed) 200 SUPERTOKENs. You can send Native-Tokens with the example below. :smiley:

</details>


## How to send Native Tokens

This is as simply as sending lovelaces(ADA) from one wallet address to another address. Here you can find two examples on how to do it with self created Tokens and with Tokens you got from other ones.

<details>
   <Summary><b>Show Example ... </b>:bookmark_tabs:<br></summary>

<br>Lets say we wanna send 15 **SUPERTOKEN** that we created by our own before under the policy **mypolicy**. The AssetFiles were stored in the *assets* subdirectory. The Tokens are on the address **mywallet** and we wanna send them to the address in **yourwallet**.

<br><b>Steps:</b>
1. Run ```./01_sendAssets.sh mywallet yourwallet assets/mypolicy.SUPERTOKEN.asset 15``` to send 15 SUPERTOKENs from *mywallet* to *yourwallet*.

Done. :smiley:

As you can see, we referenced the Token via the AssetsFile ***assets/mypolicy.SUPERTOKEN.asset***. That was easy, wasn't it?

Lets now say we wanna send 36 **RANDOMCOIN**s that we got from another user. For that we have to reference it via the full PolicyID.Assetname scheme. In this example these RANDOMCOIN Tokens are on the address **mywallet** and we wanna send them to the address in **yourwallet**.

<br><b>Steps:</b>
1. Run ```./01_queryAddress.sh mywallet``` to show the content of the *mywallet* address
1. Select&Copy the Token you wanna send, in this example we wanna send the RANDOMCOINs.<br>
   So your selection could look like: ```34250edd1e9836f5378702fbf9416b709bc140e04f668cc355208518.RANDOMCOIN```<br>
   Paste it into the command Step 3.
1. Run ```./01_sendAssets.sh mywallet yourwallet 34250edd1e9836f5378702fbf9416b709bc140e04f668cc355208518.RANDOMCOIN 36``` to send 36 of theses RANDOMCOINs from *mywallet* to *yourwallet*.

Done. :smiley:

There are more options available to select the amount of the Tokens. You can find all the syntax for this 01_sendAssets.sh script [here](#main-configuration-file-00_commonsh---syntax-for-all-the-other-ones)

&nbsp;<br>
</details>



## Using multiple relays in your poolname.pool.json

You can mix'n'match multiple relay entries in your poolname.pool.json file, below are a few common examples.

<details>
   <summary><b>Show Example ... </b>:bookmark_tabs:<br></summary>

### Using two dns named relay entries

Your poolRelays array section in the json file should look similar to:

```console
  "poolRelays": [
         {
         "relayType": "dns",
         "relayEntry": "relay-1.mypool.com",
         "relayPort": "3001"
         },
         {
         "relayType": "dns",
         "relayEntry": "relay-2.mypool.com",
         "relayPort": "3001"
         }
  ],
```

### Using a mixed relay setup

Your poolRelays array section in the json file should like similar to:

```console
  "poolRelays": [
         {
         "relayType": "dns",
         "relayEntry": "relay.mypool.com",
         "relayPort": "3001"
         },
         {
         "relayType": "ip",
         "relayEntry": "287.10.10.1",
         "relayPort": "3001"
         }
  ],
```

### Using three ipv4 named relay entries

Your poolRelays array section in the json file should like similar to:

```console
  "poolRelays": [
         {
         "relayType": "ip",
         "relayEntry": "287.10.10.1",
         "relayPort": "3001"
         },
         {
         "relayType": "ip",
         "relayEntry": "287.10.0.1",
         "relayPort": "3002"
         },
         {
         "relayType": "ip",
         "relayEntry": "317.10.0.1",
         "relayPort": "3001"
         }
  ],
```
</details>


## Retire a StakePool from the blockchain

If you wanna retire your registered stakepool mypool, you have to do just a few things

<details>
   <summary><b>Show Example ... </b>:bookmark_tabs:<br></summary>

<br><b>Steps:</b>
1. Generate the retirement certificate for the stakepool mypool from data in mypool.pool.json<br>
   ```./07a_genStakepoolRetireCert.sh mypool``` this will retire the pool at the next epoch
1. De-Register your stakepool from the blockchain with ```./07b_deregStakepoolCert.sh mypool smallwallet1```
 
Done.
</details>

## Retire a stakeaddress from the blockchain

If you wanna retire the staking address owner, you have to do just a few things

<details>
   <Summary><b>Show Example ... </b>:bookmark_tabs:<br></summary>

<br><b>Steps:</b>
1. Generate the retirement certificate for the stake-address ```./08a_genStakingAddrRetireCert.sh owner```<br>this will generate the owner.staking.dereg-cert file
1. De-Register your stake-address from the blockchain with ```./08b_deregStakingAddrCert.sh owner.staking owner.payment```<br>you don't need to have funds on the owner.payment base address. you'll get the keyDepositFee back onto it!
1. You can check the current status of your onchain registration via the script 03c like<br>
   ```./03c_checkStakingAddrOnChain.sh owner```<br>If it doesn't go away directly, wait a little and retry this script.

:warning: Don't retire a stakeaddress if you were delegated to a blockproducing StakePool before, you will receive rewards for the next 2 epochs on that account. Retire it only afterwards!
   
 
Done.
</details>

## ITN-Witness Ticker check for wallets and Extended-Metadata.json Infos

<details>
   <summary><b> Explore how to use your ITN Ticker as Proof and also how to use extended-metadata.json </b>:bookmark_tabs:<br></summary>
   
There is now an implementation of the extended-metadata.json for the pooldata. This can hold any kind of additional data for the registered pool. We see some Ticker spoofing getting more and more, so new people are trying to take over the Ticker from the people that ran a stakepool in the ITN and built up there reputation. There is no real way to forbid a double ticker registration, however, the "spoofing" stakepoolticker can be shown in the Daedalus/Yoroi/Pegasus wallet as a "spoof", so people can see this is not the real pool. I support this in my scripts. To anticipate in this (it is not fixed yet) you will need a "**jcli**" binary on your machine with the right path set in ```00_common.sh```. Prepare two files in the pool directory:
<br>```<poolname>.itn.skey``` this textfile should hold your ITN secret/private key
<br>```<poolname>.itn.vkey``` this textfile should hold your ITN public/verification key
<br>also you would need to add an additional URL **poolExtendedMetaUrl** for the next extended metadata json file on your webserver to your ```<poolname>.pool.json``` file like:
```console
   .
   .
   .
   "poolMetaHomepage": "https://mypool.com",
   "poolMetaUrl": "https://mypool.com/mypool.metadata.json",
   "poolExtendedMetaUrl": "https://mypool.com/mypool.extended-metadata.json",
   "---": "--- DO NOT EDIT BELOW THIS LINE ---"
  }
``` 
When you now generate your pool certificate, not only your ```<poolname>.metadata.json``` will be created as always, but also the ```<poolname>.extended-metadata.json``` that is holding your ITN witness to proof your Ticker ownership from the ITN. Upload BOTH to your webserver! :-)

**Additional Feature:** If you wanna also include the extended-metadata format Adapools is currently using you can do so by providing additional metadata information in the file ```<poolname>.additional-metadata.json``` !<br>
You can find an example of the Adapools format [here](https://a.adapools.org/extended-example).<br>
So if you hold a file ```<poolname>.additional-metadata.json``` with additional data in the same folder, script 05a will also integrate this information into the ```<poolname>.extended-metadata.json``` :-)<br>

</details>

## How to do a voting for SPOCRA in a simple process

<details>
   <summary><b>Explore how to vote for SPOCRA </b>:bookmark_tabs:<br></summary>
   
We have created a simplified script to transmit a voting.json file on-chain. This version will currently be used to submit your vote on-chain for the SPOCRA voting.<br>A Step-by-Step Instruction on how to create the voting.json file can be found on Adam Dean's website -> [Step-by-Step Instruction](https://vote.crypto2099.io/SPOCRA-voting/).<br>
After you have generated your voting.json file you simply transmit it in a transaction on-chain with the script ```01_sendVoteMeta.sh``` like:<br> ```./01_sendVoteMeta.sh mywallet myvote```<br>This will for example transmit the myvote.json file (you name it without the .json) with funds from your wallet with the name mywallet.<br>
Thats it. :-)

</details>

&nbsp;<br>&nbsp;<br>
# Examples in Offline-Mode

The examples in here are for using the scripts in Offine-Mode. Please get yourself familiar first with the scripts in [Online-Mode](#examples-in-online-mode). Also a detailed Syntax about each script can be found [here](#configuration-scriptfiles-syntax--filenames). Working offline is like working online, all is working in Offline-Mode, theses are just a few examples. :smiley:<br>

:bulb: Make sure your 00_common.sh is having the correct setup for your system!

**Understand the workflow in Offline-Mode:**

* **Step 1 : On the Online-Machine**
  Query up2date information about your address balances, rewards, blockchain-parameters...<br>
  If you wanna pay offline from your mywallet1.addr, just add the information for that.
  If you wanna claim rewards from your mywallet.staking address and you wanna pay with your smallwallet1.addr for that, just add these two addresses to the information. You need to add the information of your addresses you wanna pay with or you wanna claim rewards from, nothing more.<br>
  Update the **offlineTransfer.json file with ./01_workOffline.sh** and send(:floppy_disk:) it over to the Offline-Machine.

* **Step 2 : On the Offline-Machine**
  Do your normal work with the scripts like sending lovelaces or tokens from address to address, updating your stakepool parameters, claiming your rewards, etc...<br>
  Sign the transactions on the Offline-Machine, they will be automatically stored in the offlineTransfer.json. If you wanna do multiple transactions at the same time, use a few small payment wallets for this, because you can only pay from one individual wallet in an offline transaction at the same time. So if you wanna claim your rewards and also update your pool parameters, use two small payment wallets for that.<br>All offline transactions and also updated files like your pool.metadata.json or pool.extended-metadata.json will be stored in the offlineTransfer.json if you say so.<br>
  When you're finished, send(:floppy_disk:) the offlineTransfer.json back to your Online-Machine.

* **Step 3 : On the Online-Machine**
  **Execute the offline signed transactions** and/or extract files from the offlineTransfer.json like your updated pool.metadata.json file for example with **./01_workOffline.sh**<br>
  You're done, if you wanna continue to do some work: Gather again the latest balance informations from the address you wanna work with and send the offlineTransfer.json back to your Offline-Machine. And so on...<br>
  The offlineTransfer.json is your little carry bag for your balance/rewards information, transactions and files. :-)

**Config-Settings on the Online- / Offline-Machine:**

* Online-Machine: Set the ```offlineMode="no"``` parameter in the 00_common.sh, common.inc or ~/.common.inc config file.<br>Make sure you have a running and fully synced cardano-node on this Machine. Also cardano-cli.

* Offline-Machine: Set the ```offlineMode="yes"``` parameter in the 00_common.sh, common.inc or ~/.common.inc config file.<br>You only need the cardano-cli on this Machine, no cardano-node binaries.


## Generate some wallets for the daily operator work

So first you should create yourself a few small wallets for the daily Operator work, there is no need to use your big-owner-pledge-wallet for this every time. Lets say we wanna create three small wallets with the name smallwallet1, smallwallet2 and smallwallet3. And we wanna fund them via daedalus for example.

<details>
   <summary><b>Show Example ... </b>:bookmark_tabs:<br></summary>

<br>**Online-Machine:**

1. Make a fresh version of the offlineTransfer.json by running ```./01_workOffline.sh new```

:floppy_disk: Transfer the offlineTransfer.json to the Offline-Machine.

**Offline-Machine:**

1. Create three new payment-only wallets by running<br>```./02_genPaymentAddrOnly.sh smallwallet1 cli```<br>```./02_genPaymentAddrOnly.sh smallwallet2 cli```<br>```./02_genPaymentAddrOnly.sh smallwallet3 cli```
1. Add the three new smallwallet1/2/3.addr files to your offlineTransfer.json<br>```./01_workOffline.sh attach smallwallet1.addr```<br>```./01_workOffline.sh attach smallwallet2.addr```<br>```./01_workOffline.sh attach smallwallet3.addr```

:floppy_disk: Transfer the offlineTransfer.json to the Online-Machine.

**Online-Machine:**

1. Extract the three included address files to the Online-Machine<br>```./01_workOffline.sh extract```

You have now successfully brought over the three files smallwallet1.addr, smallwallet2.addr and smallwallet3.addr to your Online-Machine. You can check the current balance on them like you did before running ```./01_queryAddress.sh smallwallet1```<br>
Ok, now fund those three small wallets via daedalus for example. Of course you can also do this from your big-owner-pledge-wallet offline via multiple steps, but we're just learning the steps together, so not overcomplicate the things. :-)<br>
You can of course use your already made and funded wallets for the following examples, we just need a starting point here.

</details>

## Create the StakePool offline with CLI-Owner-Keys

We want to make a pool owner stake address the nickname owner, also we want to register a pool with the nickname mypool. The nickname is only to keep the files on the harddisc in order, nickname is not a ticker! We use the smallwallet1&2 to pay for the different fees in this process. Make sure you have enough funds on smallwallet1 & smallwallet2 for this registration.

<details>
   <summary><b>Show Example ... </b>:bookmark_tabs:<br></summary>

<br>**Online-Machine:**

1. Add/Update the current UTXO balance for smallwallet1 in the offlineTransfer.json by running<br>```./01_workOffline.sh add smallwallet1``` (smallwallet1 will pay for the stake-address registration, 2 ADA + fees)
1. Add/Update the current UTXO balance for smallwallet2 in the offlineTransfer.json by running<br>```./01_workOffline.sh add smallwallet2``` (smallwallet2 will pay for the pool registration, 500 ADA + fees)

:floppy_disk: Transfer the offlineTransfer.json to the Offline-Machine.

**Offline-Machine:** (same steps like working online)

1. Generate the owner stake/payment combo with ```./03a_genStakingPaymentAddr.sh owner cli```
1. Attach the newly created payment and staking address into your offlineTransfer.json for later usage on the Online-Machine<br>```./01_workOffline.sh attach owner.payment.addr```<br>```./01_workOffline.sh attach owner.staking.addr```
1. Generate the owner stakeaddress registration transaction and pay the fees with smallwallet1<br>```./03b_regStakingAddrCert.sh owner.staking smallwallet1```
1. Generate the keys for your coreNode
   1. ```./04a_genNodeKeys.sh mypool```
   1. ```./04b_genVRFKeys.sh mypool```
   1. ```./04c_genKESKeys.sh mypool```
   1. ```./04d_genNodeOpCert.sh mypool```
1. Now you have all the key files to start your coreNode with them
1. Generate your stakepool certificate
   1. ```./05a_genStakepoolCert.sh mypool```<br>will generate a prefilled mypool.pool.json file for you, edit it
   1. We want 200k ADA pledge, 10k ADA costs per epoch and 4% pool margin so let us set these and the Metadata values in the json file like
   ```console
   {
      "poolName": "mypool",
      "poolOwner": [
         {
         "ownerName": "owner",
         "ownerWitness": "local"
         }
      ],
      "poolRewards": "owner",
      "poolPledge": "200000000000",
      "poolCost": "10000000000",
      "poolMargin": "0.04"
      "poolRelays": [
         {
         "relayType": "dns",
         "relayEntry": "relay.mypool.com",
         "relayPort": "3001"
         }
      ],
      "poolMetaName": "This is my Pool",
      "poolMetaDescription": "This is the description of my Pool!",
      "poolMetaTicker": "POOL",
      "poolMetaHomepage": "https://mypool.com",
      "poolMetaUrl": "https://mypool.com/mypool.metadata.json",
      "poolExtendedMetaUrl": "",
      "---": "--- DO NOT EDIT BELOW THIS LINE ---"
   }
   ```
   
   :bulb: You can find more details on the scripty-syntax [here](#configuration-scriptfiles-syntax--filenames)
   
1. Run ```./05a_genStakepoolCert.sh mypool``` again with the saved json file, this will generate the mypool.pool.cert file.<br>:bulb: If you wanna protect your TICKER a little more against others, contact me and you will get a unique TickerProtectionKey for your Ticker! If you already have one, run ```./05a_genStakepoolCert.sh <PoolNodeName> <your registration protection key>```<br>
1. Delegate to your own pool as owner -> pledge ```./05b_genDelegationCert.sh mypool owner``` this will generate the owner.deleg.cert
1. Generate the stakepool registration transaction and pay the fees with smallwallet2<br>```./05c_regStakepoolCert.sh mypool smallwallet2```<br>Let the script also autoinclude your new mypool.metadata.json file into the transferOffline.json    

:floppy_disk: Transfer the offlineTransfer.json to the Online-Machine.

**Online-Machine:**

1. Extract all the attached files (mypool.metadata.json, owner.payment.addr, owner.staking.addr) from the transferOffline.json<br>```./01_workOffline.sh extract```
1. Now would be the time to upload the mypool.metadata.json file to your webserver.
1. We submit the first cued transaction (stakekey registration) to the blockchain by running<br>```./01_workOffline.sh execute```
1. And now we submit the second cued transaction (stakepool registration) to the blockchain by running<br>```./01_workOffline.sh execute``` again

You can check the balance of your owner.payment and the rewards of owner.staking with the ```./01_queryAddress.sh``` script. Make sure to transfer enough ADA to your owner.payment account so you respect the registered pledge amount.

Done.
</details>

## Create the StakePool offline with HW-Wallet-Owner-Keys (Ledger/Trezor)

> Remark: This is a little advanced, but its the only way if you wanna do it completely offline.

We want to make ourself a pool owner stake address with the nickname ledgerowner by using a HW-Key, we want to register the pool with the poolname mypool. The poolname is only to keep the files on the harddisc in order, poolname is not a ticker!<br>
We use the smallwallet1 to pay for the different fees in this process. Make sure you have at least **510 ADA** on it.

<details>
   <summary><b>Show Example ... </b>:bookmark_tabs:<br></summary>

<br>**Online-Machine:**

1. Add/Update the current UTXO balance for smallwallet1 in the offlineTransfer.json by running<br>```./01_workOffline.sh add smallwallet1``` (smallwallet1 will source the new ledgerowner for the stake-address and delegation registration, **at least 510 ADA should be on that wallet**)

:floppy_disk: Transfer the offlineTransfer.json to the Offline-Machine.

**Offline-Machine:**

1. Make sure you have enough funds on your *smallwallet1* account we created before. You will need around **510 ADA to complete the process**. You can check the current balance by running ```./01_queryAddress.sh smallwallet1```
1. Generate the owner stake/payment combo with full Hardware-Keys ```./03a_genStakingPaymentAddr.sh ledgerowner hw```<br>
   See your options in the section [here](#choose-your-preferred-key-type-for-your-owner-pledge-accounts) to choose between CLI, HW and HYBRID keys.  
1. Make an offline transaction by sending some funds from your *smallwallet1* to your new *ledgerowner.payment* address for the stake key and delegation registration, 6 ADA should be ok for this ```./01_sendLovelaces.sh smallwallet1 ledgerowner.payment 6000000```
1. Add the new ledgerowner.payment.addr and ledgerowner.staking.addr to your offlineTransfer.json<br>```./01_workOffline.sh attach ledgerowner.payment.addr```<br>```./01_workOffline.sh attach ledgerowner.staking.addr```

:floppy_disk: Transfer the offlineTransfer.json to the Online-Machine.

**Online-Machine:**

1. Extract the attached files (ledgerowner.payment.addr, ledgerowner.staking.addr) from the transferOffline.json<br>```./01_workOffline.sh extract```
1. Execute the cued transaction (smallwallet1 to ledgerowner.payment) to the blockchain by running<br>```./01_workOffline.sh execute```
1. Wait a minute so the transaction is completed
1. Verify that you have now the 6 ADA on your ledgerowner.payment address<br>```./01_queryAddress ledgerowner.payment``` if you don't see it, wait a little and retry
1. Add/Update the new UTXO balance for ledgerowner.payment in the offlineTransfer.json by running<br>```./01_workOffline.sh add ledgerowner.payment``` (we need it to pay for the delegation cert next)
1. Add/Update the current UTXO balance for smallwallet1 in the offlineTransfer.json by running<br>```./01_workOffline.sh add smallwallet1``` (we need it to pay for the pool registration and you've just paid with it)


:floppy_disk: Transfer the offlineTransfer.json to the Offline-Machine.

**Offline-Machine:**

1. Generate the ledgerowner stake key registration on the blockchain, **the hw-wallet itself must pay for this**<br>```./03b_regStakingAddrCert.sh ledgerowner ledgerowner.payment```
1. Generate the keys for your coreNode
   1. ```./04a_genNodeKeys.sh mypool```
   1. ```./04b_genVRFKeys.sh mypool```
   1. ```./04c_genKESKeys.sh mypool```
   1. ```./04d_genNodeOpCert.sh mypool```
1. Now you have all the key files to start your coreNode with them: **mypool.vrf.skey, mypool.kes-000.skey, mypool.node-000.opcert**
1. You can include them also in the offlineTransfer.json to bring them over to your Online-Machine if you like by running<br>```./01_workOffline.sh attach mypool.vrf.skey```<br>```./01_workOffline.sh attach mypool.kes-000.skey```<br>```./01_workOffline.sh attach mypool.node-000.opcert```
1. Generate your stakepool certificate
   1. ```./05a_genStakepoolCert.sh mypool```<br>will generate a prefilled **mypool.pool.json** file for you, **edit it !**
   1. We want 200k ADA pledge, 500 ADA costs per epoch and 4% pool margin so let us set these and the Metadata values in the json file like below. Also we want the 
ledgerowner as owner and also as rewards-account. We do the signing on the machine itself so ownerWitness can stay at 'local'. You can find out more about the ownerWitness parameter and how to work with Multi-Witnesses [here](#changes-to-the-operator-workflow-when-hardware-wallets-are-involved):
   ```console
   {
      "poolName": "mypool",
      "poolOwner": [
         {
         "ownerName": "ledgerowner",
         "ownerWitness": "local"
         }
      ],
      "poolRewards": "ledgerowner",
      "poolPledge": "200000000000",
      "poolCost": "500000000",
      "poolMargin": "0.04"
      "poolRelays": [
         {
         "relayType": "dns",
         "relayEntry": "relay.mypool.com",
         "relayPort": "3001"
         }
      ],
      "poolMetaName": "This is my Pool",
      "poolMetaDescription": "This is the description of my Pool!",
      "poolMetaTicker": "POOL",
      "poolMetaHomepage": "https://mypool.com",
      "poolMetaUrl": "https://mypool.com/mypool.metadata.json",
      "poolExtendedMetaUrl": "",
      "---": "--- DO NOT EDIT BELOW THIS LINE ---"
   }
   ```
1. Run ```./05a_genStakepoolCert.sh mypool``` again with the saved json file, this will generate the **mypool.pool.cert** file
1. Delegate to your own pool as owner -> **pledge** ```./05b_genDelegationCert.sh mypool ledgerowner``` this will generate the **ledgerowner.deleg.cert**
1. Generate now the transaction for the the stakepool registration, smallwallet1 will pay for the registration fees<br>```./05c_regStakepoolCert.sh mypool smallwallet1```<br>Let the script also autoinclude your new mypool.metadata.json file into the transferOffline.json!

:floppy_disk: Transfer the offlineTransfer.json to the Online-Machine.

**Online-Machine:**

1. Extract the attached files (mypool.metadata.json, mypool.vrf.skey, mypool.kes-000.skey, mypool.node-000.opcert) from the transferOffline.json ```./01_workOffline.sh extract```
1. Now would be the time to **upload the mypool.metadata.json file to your webserver**, or the next steps will fail!
1. Execute the cued transaction (ledgerowner stakekey registration) on the blockchain by running<br>```./01_workOffline.sh execute```
1. Wait a minute so the transaction is completed
1. Verify that your stake key in now on the blockchain by running<br>```./03c_checkStakingAddrOnChain.sh ledgerowner``` if you don't see it, wait a little and retry
1. Execute the next cued transaction (stakepool registration) on the blockchain by running<br>```./01_workOffline.sh execute```
1. Wait a minute so the transaction is complete
1. Add/Update the current UTXO balance for ledgerowner.payment in the offlineTransfer.json by running<br>```./01_workOffline.sh add ledgerowner.payment``` (we need it to pay for the delegation next and you just paid with it)

:floppy_disk: Transfer the offlineTransfer.json to the Offline-Machine.

**Offline-Machine:**

1. Send all owner delegations to the blockchain. :bulb: Notice! This is different than before when using only CLI-Owner-Keys, if any owner is a HW-Wallet than you have to send the individual delegations after the stakepool registration. You can read more about it [here](#changes-to-the-operator-workflow-when-hardware-wallets-are-involved).<br>We have only one owner so lets do this by running the following command, **the HW-Wallet itself must pay for this**<br>```./06_regDelegationCert.sh ledgerowner ledgerowner.payment```

:floppy_disk: Transfer the offlineTransfer.json to the Online-Machine.

**Online-Machine:**

1. Execute the cued transaction (ledgerowner delegation registration) on the blockchain by running<br>```./01_workOffline.sh execute```
1. Wait a minute so the transaction is completed
1. Verify that your owner delegation to your pool is ok by running<br>```./03c_checkStakingAddrOnChain.sh ledgerowner``` if you don't see it instantly, wait a little and retry the same command

:warning: Transfer enough ADA to your new **ledgerowner.payment.addr** so you respect the registered Pledge amount, otherwise you will not get any rewards for you or your delegators!<br>You can always check the balance of your ledgerowner.payment by running ```./01_queryAddress.sh ledgerowner.payment``` on the Online-Machine.<br>You can check about rewards on the ledgerowner.staking by running ```./01_queryAddress.sh ledgerowner.staking```

**Done**, yes this is more work to do when you wanna do this in offline mode, but it is how it is. :smiley:

</details>

## Migrate your existing Stakepool offline to HW-Wallet-Owner-Keys (Ledger/Trezor)

So this is an important one for many of you that already have registered a stakepool on Cardano before. Now is the time to upgrade your owner funds security to the next level by using HW-Wallet-Keys instead of CLI-Keys. In the example below we have an existing CLI-Owner with name **owner**, and we want to migrate that to the new owner with name **ledgerowner**. <br>
We use the smallwallet1 to pay for the different fees in this process. Make sure you have at least **10 ADA** on it.

<details>
   <summary><b>Show Example ... </b>:bookmark_tabs:<br></summary>

<br>**Online-Machine:**

1. Add/Update the current UTXO balance for smallwallet1 in the offlineTransfer.json by running<br>```./01_workOffline.sh add smallwallet1``` (smallwallet1 will source the new ledgerowner for the stake-address and delegation registration, **at least 10 ADA should be on that wallet**)

:floppy_disk: Transfer the offlineTransfer.json to the Offline-Machine.

**Offline-Machine:**

1. Make sure you have enough funds on your *smallwallet1* account we created before. You will need around **10 ADA to complete the process**. You can check the current balance by running ```./01_queryAddress.sh smallwallet1```
1. Generate the new ledgerowner stake/payment combo with full Hardware-Keys ```./03a_genStakingPaymentAddr.sh ledgerowner hw```<br>
   See your options in the section [here](#choose-your-preferred-key-type-for-your-owner-pledge-accounts) to choose between CLI, HW and HYBRID keys.  
1. Make an offline transaction by sending some funds from your *smallwallet1* to your new *ledgerowner.payment* address for the stake key and delegation registration, 5 ADA should be ok for this ```./01_sendLovelaces.sh smallwallet1 ledgerowner.payment 5000000```
1. Add the new ledgerowner.payment.addr and ledgerowner.staking.addr to your offlineTransfer.json<br>```./01_workOffline.sh attach ledgerowner.payment.addr```<br>```./01_workOffline.sh attach ledgerowner.staking.addr```

:floppy_disk: Transfer the offlineTransfer.json to the Online-Machine.

**Online-Machine:**

1. Extract the attached files (ledgerowner.payment.addr, ledgerowner.staking.addr) from the transferOffline.json<br>```./01_workOffline.sh extract```
1. Execute the cued transaction (smallwallet1 to ledgerowner.payment) to the blockchain by running<br>```./01_workOffline.sh execute```
1. Wait a minute so the transaction is completed
1. Verify that you have now the 5 ADA on your ledgerowner.payment address<br>```./01_queryAddress ledgerowner.payment``` if you don't see it, wait a little and retry
1. Add/Update the new UTXO balance for ledgerowner.payment in the offlineTransfer.json by running<br>```./01_workOffline.sh add ledgerowner.payment``` (we need it to pay for the delegation cert next)
1. Add/Update the current UTXO balance for smallwallet1 in the offlineTransfer.json by running<br>```./01_workOffline.sh add smallwallet1``` (we need it to pay for the pool Re-Registration and you've just paid with it)


:floppy_disk: Transfer the offlineTransfer.json to the Offline-Machine.

**Offline-Machine:**

1. Generate the ledgerowner stake key registration on the blockchain, **the hw-wallet itself must pay for this**<br>```./03b_regStakingAddrCert.sh ledgerowner ledgerowner.payment```
1. The poolOwner section in your mypool.pool.json file looks like this right now:
   ```console
   ...
      "poolName": "mypool",
      "poolOwner": [
         {
         "ownerName": "owner",
         "ownerWitness": "local"
         }
      ],
      "poolRewards": "owner",
      "poolPledge": "200000000000",
   ...
   ```
   Maybe you don't have the ownerWitness entry, but thats ok it will be added automatically or you can add it by yourself.
1. [Unlock](#file-autolock-for-enhanced-security) the existing mypool.pool.json file and **add the new ledgerowner** to the list of owners, also we want that the new rewards account is also the new ledgerowner. Only edit the values above the "--- DO NOT EDIT BELOW THIS LINE ---" line, **EDIT IT** and **SAVE IT**:
   ```console
   ...
      "poolName": "mypool",
      "poolOwner": [
         {
         "ownerName": "owner",
         "ownerWitness": "local"
         },
         {
         "ownerName": "ledgerowner",
         "ownerWitness": "local"
         }
      ],
      "poolRewards": "ledgerowner",
      "poolPledge": "200000000000",
   ...
   ```
   We wanna do the signing on this machine so you can leave ownerWitness at 'local'. You can find out more about the ownerWitness parameter and how to work with Multi-Witnesses [here](#changes-to-the-operator-workflow-when-hardware-wallets-are-involved)
1. Run ```./05a_genStakepoolCert.sh mypool``` to generate the updated pool certificate **mypool.pool.cert**
1. Delegate to your own pool as owner -> **pledge** ```./05b_genDelegationCert.sh mypool ledgerowner``` this will generate the **ledgerowner.deleg.cert**
1. Generate now the transaction for the the stakepool registration, smallwallet1 will pay for the re-registration fees<br>```./05c_regStakepoolCert.sh mypool smallwallet1```<br>Let the script also autoinclude your new mypool.metadata.json file into the transferOffline.json if you have changed some Metadata!

:floppy_disk: Transfer the offlineTransfer.json to the Online-Machine.

**Online-Machine:**

1. Extract the maybe attached files (mypool.metadata.json) from the transferOffline.json ```./01_workOffline.sh extract```
1. If you have changed also some Metadata, **upload** the newly generated ```mypool.metadata.json``` file **onto your webserver** so that it is reachable via the URL you specified in the poolMetaUrl entry! Otherwise the next step will abort with an error. If you have only updated the owners, skip it.
1. Execute the cued transaction (ledgerowner stakekey registration) on the blockchain by running<br>```./01_workOffline.sh execute```
1. Wait a minute so the transaction is completed
1. Verify that your stake key in now on the blockchain by running<br>```./03c_checkStakingAddrOnChain.sh ledgerowner``` if you don't see it, wait a little and retry
1. Execute the next cued transaction (stakepool registration) on the blockchain by running<br>```./01_workOffline.sh execute```
1. Wait a minute so the transaction is complete
1. Add/Update the current UTXO balance for ledgerowner.payment in the offlineTransfer.json by running<br>```./01_workOffline.sh add ledgerowner.payment``` (we need it to pay for the delegation next and you just paid with it)

:floppy_disk: Transfer the offlineTransfer.json to the Offline-Machine.

**Offline-Machine:**

1. Send all owner delegations to the blockchain. :bulb: Notice! This is different than before when using only CLI-Owner-Keys, if any owner is a HW-Wallet than you have to send the individual delegations after the stakepool registration. You can read more about it [here](#changes-to-the-operator-workflow-when-hardware-wallets-are-involved).<br>We have only one new owner (ledgerowner) so lets do this by running the following command, **the HW-Wallet itself must pay for this**<br>```./06_regDelegationCert.sh ledgerowner ledgerowner.payment```

:floppy_disk: Transfer the offlineTransfer.json to the Online-Machine.

**Online-Machine:**

1. Execute the cued transaction (ledgerowner delegation registration) on the blockchain by running<br>```./01_workOffline.sh execute```
1. Wait a minute so the transaction is completed
1. Verify that your owner delegation to your pool is ok by running<br>```./03c_checkStakingAddrOnChain.sh ledgerowner``` if you don't see it instantly, wait a little and retry the same command

&nbsp;<br>
:warning: <b>Now WAIT! Wait for 2 epoch changes!</b> :warning: So if you're doing this in epoch n, wait until epoch n+2 before you continue!

&nbsp;<br>
Now two epochs later your new additional **ledgerowner** co-owner is fully active. Its now the time to **transfer your owner funds** from the old **owner** to the new **ledgerowner**. 

**Online-Machine:**

1. Add/Update the current UTXO balance for owner.payment (oldaccount) in the offlineTransfer.json by running<br>```./01_workOffline.sh add owner.payment```

:floppy_disk: Transfer the offlineTransfer.json to the Offline-Machine.

**Offline-Machine:**

1. You can now transfer all funds from the old owner-account 'owner' to the new pledge account 'ledgerowner' by running:<br>```./01_sendLovelaces.sh owner.payment ledgerowner.payment ALLFUNDS```<br>This will move over all lovelaces and even assets that are on your old owner.payment address to your new ledger.payment address.

Be aware, this little transaction needed some fees, so you maybe have to top up your ledgerowner.payment account later with 1 ADA from another wallet to met your registered pledge again!

:floppy_disk: Transfer the offlineTransfer.json to the Online-Machine.

**Online-Machine:**

1. Execute the cued transaction (owner.payment to ledgerowner.payment) on the blockchain by running<br>```./01_workOffline.sh execute```

&nbsp;<br>
:warning: <b>WAIT AGAIN! Wait for 2 epoch changes!</b> :warning: So if you're doing this in epoch n, wait until epoch n+2 before you continue! :warning:

&nbsp;<br>
Why waiting again? Well, **we** also **changed the rewards-account** when we added the new ledgerowner, this takes 4 epochs on the blockchain to get fully updated. So, until now **you have received the rewards** of the pool **to your old owner.staking account**. Please check you rewards now and do a withdrawal of them, an example can be found below.

&nbsp;<br>
**Done**, you have fully migrated to your new ledgerowner in Offline-Mode, congrats! :smiley:

> Optional: If you wanna get rid of your old owner entry (you can leave it in there) in your stakepool registration - do the following:
  <br>Do it like the steps above, re-edit your mypool.pool.json file and remove the entry of the old owner from the poolOwner list. Save the file, generate a new certificate by running script 05a. Register it on the chain again like above or like the example below "Update stakepool parameters on the blockchain in Offline-Mode". Now you have only your new ledgerowner in your pool registration. 

</details>

## Update stakepool parameters on the blockchain in Offline-Mode

Lets pretend you already have registered your stakepool 'mypool' in the past using theses scripts, now lets update some pool parameters like pledge, fees or the description for the stakepool(metadata). We use the smallwallet1 to pay for this update.

<details>
   <summary><b>Show Example ... </b>:bookmark_tabs:<br></summary>

<br>**Online-Machine:**

1. Add/Update the current UTXO balance for smallwallet1 in the offlineTransfer.json by running<br>```./01_workOffline.sh add smallwallet1```

:floppy_disk: Transfer the offlineTransfer.json to the Offline-Machine.

**Offline-Machine:** (same steps like working online)

1. [Unlock](#file-autolock-for-enhanced-security) the existing mypool.pool.json file and edit it. Only edit the values above the "--- DO NOT EDIT BELOW THIS LINE ---" line, save it again. 
1. Run ```./05a_genStakepoolCert.sh mypool``` to generate a new mypool.pool.cert, mypool.metadata.json file from it
1. (Optional create delegation certificates if you have added an owner or an extra rewards account with script 05b)
1. Generate the offline Re-Registration of your stakepool with ```./05c_regStakepoolCert.sh mypool smallwallet1```<br>Your transaction with your updated pool-certificate is now stored in the offlineTransfer.json. As you have noticed, the 05c script also asked you if it should include the (maybe new) metadata files also in the offlineTransfer.json. So you need only one file for the transfer, we can extract them on the Online-Machine.

:floppy_disk: Transfer the offlineTransfer.json to the Online-Machine.

**Online-Machine:**
1. If your metadata/extended-metadata.json has changed and is in the transferOffline.json, extract it via<br>```./01_workOffline.sh extract```
1. Now would be the time to upload the new metadata/extended-metadata.json files to your webserver. If they have not changed at all, skip this step of course.
1. Finally we submit the created offline transaction now to the blockchain by running<br>```./01_workOffline.sh execute```

Done.  
</details>

## Claiming rewards on the Shelley blockchain in Offline-Mode

I'am sure you wanna claim some of your rewards that you earned running your stakepool. So lets say you have rewards in your owner.staking address and you wanna claim it to the owner.payment address by paying with funds from smallwallet2.

<details>
   <summary><b>Show Example ... </b>:bookmark_tabs:<br></summary>

<br>**Online-Machine:**

Make sure you have your owner.staking.addr and smallwallet2.addr file on your Online-Machine, if not, copy it over from your Offline-Machine like a normal filecopy or use the attach->extract method we used in the example [here](#generate-some-wallets-for-the-daily-operator-work)

1. Add/Update the current UTXO balance for smallwallet2 in the offlineTransfer.json by running<br>```./01_workOffline.sh add smallwallet2```
1. Add/Update the current rewards state for owner.staking in the offlineTransfer.json by running<br>```./01_workOffline.sh add owner.staking```

Now we have the up2date information about the payment address smallwallet2 and also the current rewards state of owner.staking in the offlineTransfer.json.

:floppy_disk: Transfer the offlineTransfer.json to the Offline-Machine.

**Offline-Machine:** (same steps like working online)

1. You can claim your rewards by running ```./01_claimRewards.sh owner.staking owner.payment smallwallet2```
   This will claim the rewards from the owner.staking account and sends it to the owner.payment address, smallwallet2 will pay for the transaction fees.<br>
   :bulb: ATTENTION, claiming rewards costs transaction fees! So you have two choices for that: The destination address pays for the transaction fees, or you specify an additional account that pays for the transaction fees like we did now. You can find examples for that above at the script 01_claimRewards.sh description.

:floppy_disk: Transfer the offlineTransfer.json to the Online-Machine.

**Online-Machine:**
1. Execute the created offline rewards claim now on the blockchain by running<br>```./01_workOffline.sh execute```

Done.  

</details>

## Sending some funds from one address to another address in Offline-Mode

Lets say you wanna transfer 1000 Ada from your big-owner-payment-wallet owner.payment to a different address like smallwallet3 in this example.
Also you wanna transfer 20 ADA from smallwallet1 to smallwallet3 at the same time, only transfering the offlineTransfer.json once. 

<details>
   <summary><b>Show Example ... </b>:bookmark_tabs:<br></summary>

<br>**Online-Machine:**

Make sure you have your owner.payment.addr and smallwallet1.addr file on your Online-Machine, if not, copy it over from your Offline-Machine like a normal filecopy or use the attach->extract method we used in the example [here](#generate-some-wallets-for-the-daily-operator-work)

1. Add/Update the current UTXO balance for owner.payment in the offlineTransfer.json by running<br>```./01_workOffline.sh add owner.payment```
1. Add/Update the current UTXO balance for smallwallet1 in the offlineTransfer.json by running<br>```./01_workOffline.sh add smallwallet1```

:floppy_disk: Transfer the offlineTransfer.json to the Offline-Machine.

**Offline-Machine:** (same steps like working online)

1. Generate the transaction to transfer 1000000000 lovelaces from owner.payment to smallwallet3<br>```./01_sendLovelaces.sh owner.payment smallwallet3 1000000000```
1. Generate the transaction to transfer 20000000 lovelaces from smallwallet1 also smallwallet3<br>```./01_sendLovelaces.sh smallwallet1 smallwallet3 20000000```

:floppy_disk: Transfer the offlineTransfer.json to the Online-Machine.

**Online-Machine:**

1. Execute the first created offline transaction now on the blockchain by running<br>```./01_workOffline.sh execute```
1. Execute the second created offline transaction now on the blockchain by running<br>```./01_workOffline.sh execute``` again

Done.  

</details>

## How to mint/create Native Tokens in Offline-Mode

From the Mary-Era on, you can easily mint(generate) Native-Tokens by yourself, here you can find an example on how to do it.

<details>
   <Summary><b>Show Example ... </b>:bookmark_tabs:<br></summary>

<br>So lets say we wanna create 1000 new Tokens with the name **SUPERTOKEN** under the policy **mypolicy**. And we want that theses AssetFiles are stored in the *assets* subdirectory. These Tokens should be generated on the account **mywallet**.

**Online-Machine:**

1. Add/Update the current UTXO balance for mywallet in the offlineTransfer.json by running<br>```./01_workOffline.sh add mywallet```

:floppy_disk: Transfer the offlineTransfer.json to the Offline-Machine.

**Offline-Machine:** (same steps like working online)

1. First you have to generate a policyName/ID. You can reuse the same policyName/ID to mint other Assets(Tokens) later again. If you already have the policy, skip to step 3
1. Run ```./10_genPolicy.sh assets/mypolicy``` to generate a new policy with name 'mypolicy' in the assets subdirectory (you can do it in the same directory too of course)
1. Run ```./11a_mintAsset.sh assets/mypolicy.SUPERTOKEN 1000 mywallet``` to mint 1000 new SUPERTOKEN on the wallet mywallet. If you want, you can also add a custom Metadata.json file to the Minting-Transaction as the 4th parameter. Full-Syntax description can be found [here](#main-configuration-file-00_commonsh---syntax-for-all-the-other-ones)

The AssetsFile ***assets/mypolicy.SUPERTOKEN.asset*** was also written/updated with the latest action. You can see the totally minted Token count in there too.

:floppy_disk: Transfer the offlineTransfer.json to the Online-Machine.

**Online-Machine:**

1. Execute the created offline transaction now on the blockchain by running<br>```./01_workOffline.sh execute```

Done - You have mint (created) 1000 new SUPERTOKENs and they are now added to the mywallet address. You can now send them out into the world with the example below.

:smiley:

</details>

## How to burn/destroy Native Tokens in Offline-Mode

If you wanna burn(destroy) some Native-Tokens, you can do it similar to the minting process. Here you can find an example on how to do it.

<details>
   <Summary><b>Show Example ... </b>:bookmark_tabs:<br></summary>

<br>Important, you can only burn Native-Tokes that you have the policy for. You cannot burn other Native-Tokens that were sent to your wallet address. So lets say we wanna burn 200 **SUPERTOKEN** that we created before under the policy **mypolicy**. The AssetFiles were stored in the *assets* subdirectory, and the address we wanna burn the Tokens from is the account **mywallet**.

**Online-Machine:**

1. Add/Update the current UTXO balance for mywallet in the offlineTransfer.json by running<br>```./01_workOffline.sh add mywallet```

:floppy_disk: Transfer the offlineTransfer.json to the Offline-Machine.

**Offline-Machine:** (same steps like working online)

1. Run ```./11b_burnAsset.sh assets/mypolicy.SUPERTOKEN 200 mywallet``` to burn 200 SUPERTOKENs from the wallet mywallet. If you want, you can also add a custom Metadata.json file to the Burning-Transaction as the 4th parameter. Full-Syntax description can be found [here](#main-configuration-file-00_commonsh---syntax-for-all-the-other-ones)

The AssetsFile ***assets/mypolicy.SUPERTOKEN.asset*** was also written/updated with the latest action. You can see the totally minted Token count in there too.

:floppy_disk: Transfer the offlineTransfer.json to the Online-Machine.

**Online-Machine:**

1. Execute the created offline transaction now on the blockchain by running<br>```./01_workOffline.sh execute```

Done - You have burned (destroyed) 200 SUPERTOKENs. You can send Native-Tokens with the example below. :smiley:

</details>


## How to send Native Tokens in Offline-Mode

This is as simply as sending lovelaces(ADA) from one wallet address to another address. Here you can find two examples on how to do it with self created Tokens and with Tokens you got from other ones.

<details>
   <Summary><b>Show Example ... </b>:bookmark_tabs:<br></summary>

<br>Lets say we wanna send 15 **SUPERTOKEN** that we created by our own before under the policy **mypolicy**. The AssetFiles were stored in the *assets* subdirectory. The Tokens are on the address **mywallet** and we wanna send them to the address in **yourwallet**.

**Online-Machine:**

1. Add/Update the current UTXO balance for mywallet in the offlineTransfer.json by running<br>```./01_workOffline.sh add mywallet```

:floppy_disk: Transfer the offlineTransfer.json to the Offline-Machine.

**Offline-Machine:** (same steps like working online)

1. Run ```./01_sendAssets.sh mywallet yourwallet assets/mypolicy.SUPERTOKEN.asset 15``` to send 15 SUPERTOKENs from *mywallet* to *yourwallet*.

:floppy_disk: Transfer the offlineTransfer.json to the Online-Machine.

**Online-Machine:**

1. Execute the created offline transaction now on the blockchain by running<br>```./01_workOffline.sh execute```

Done. :smiley:

As you can see, we referenced the Token via the AssetsFile ***assets/mypolicy.SUPERTOKEN.asset***. That was easy, wasn't it?

Lets now say we wanna send 36 **RANDOMCOIN**s that we got from another user. For that we have to reference it via the full PolicyID.Assetname scheme. In this example these RANDOMCOIN Tokens are on the address **mywallet** and we wanna send them to the address in **yourwallet**.

**Online-Machine:**

1. Add/Update the current UTXO balance for mywallet in the offlineTransfer.json by running<br>```./01_workOffline.sh add mywallet```

:floppy_disk: Transfer the offlineTransfer.json to the Offline-Machine.

**Offline-Machine:** (same steps like working online)

1. Run ```./01_queryAddress.sh mywallet``` to show the content of the *mywallet* address
1. Select&Copy the Token you wanna send, in this example we wanna send the RANDOMCOINs.<br>
   So your selection could look like: ```34250edd1e9836f5378702fbf9416b709bc140e04f668cc355208518.RANDOMCOIN```<br>
   Paste it into the command Step 3.
1. Run ```./01_sendAssets.sh mywallet yourwallet 34250edd1e9836f5378702fbf9416b709bc140e04f668cc355208518.RANDOMCOIN 36``` to send 36 of theses RANDOMCOINs from *mywallet* to *yourwallet*.

:floppy_disk: Transfer the offlineTransfer.json to the Online-Machine.

**Online-Machine:**

1. Execute the created offline transaction now on the blockchain by running<br>```./01_workOffline.sh execute```

Done. :smiley:

There are more options available to select the amount of the Tokens. You can find all the syntax for this 01_sendAssets.sh script [here](#main-configuration-file-00_commonsh---syntax-for-all-the-other-ones)

&nbsp;<br>
</details>

# Conclusion

As you can see, its always the same procedure working in Offline-Mode:

1. Get the information about your payment/rewards addresses online using ./01_workOffline.sh
1. Transfer the offlineTransfer.json to the Offline-Machine
1. Do your normal operations on the Offline-Machine (only one payment from an individual payment address)
1. Transfer the offlineTransfer.json to the Online-Machine
1. Execute the operation online on the chain, and/or extract some included files too using ./01_workOffline.sh

If you have questions, feel free to contact me via telegram: @atada_stakepool

Best regards,
 Martin
