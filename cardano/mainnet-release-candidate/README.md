# Description - Useful setup scripts 

## First of all, you don't need them all! [Examples](#examples) are at the bottom of this page :-)

:bulb: **FOR USE WITH CARDANO-NODE & CARDANO-CLI: tags/1.16.0 !**

Theses scripts here should help you to start, i made them for myself, not for a bullet proof public use. Just to make things easier for myself while learning all the commands and steps to bring up the stakepool node. So, don't be mad at me if something is not working. CLI calls are different almost daily currently. Some scripts are using **jq** so make sure you have it installed ```(sudo apt install jq)```

Contacts: Telegram - [@atada_stakepool](https://t.me/atada_stakepool), Twitter - [@ATADA_Stakepool](https://twitter.com/ATADA_Stakepool), Homepage - https://stakepool.at https://at-ada.net

If you can't hold back and wanna give me a little Tip, here's my MainNet Ada Address, thx! :-)
```DdzFFzCqrhsyR1YeYAK47tFH7GSuw2hnuZsqGtTgSbmae9sqLjCm8b6vNvYHK7ZVFmDA9GRXA2ZJXy2dWEK7Wej5i9LXJMZvjtKawknc```

### Filenames used

I use the following naming scheme for the files:<br>
``` 
Simple "enterprise" address to only receive/send funds (no staking possible with these type of addresses):
name.addr, name.vkey, name.skey

Payment(Base)/Staking address combo:
name.payment.addr, name.payment.skey/vkey, name.deleg.cert
name.staking.addr, name.staking.skey/vkey, name.staking.cert/dereg-cert

Node/Pool files:
poolname.node.skey/vkey, poolname.node.counter, poolname.pool.cert/dereg-cert, poolname.pool.json, poolname.metadata.json
poolname.vrf.skey/vkey
poolname.kes-xxx.skey/vkey, poolname.node-xxx.opcert (xxx increments with each KES generation = poolname.kes.counter)
poolname.kes.counter, poolname.kes-expire.json
```

The *.addr files contains the address in the format "addr1vyjz4gde3aqw7e2vgg6ftdu687pcnpyzal8ax37cjukq5fg3ng25m" for example.
If you have an address and you wanna use it just do a simple:
```echo "addr1vyjz4gde3aqw7e2vgg6ftdu687pcnpyzal8ax37cjukq5fg3ng25m" > myaddress.addr```

> :bulb: **The examples below are using the scripts in the same directory, so they are listed with a leading ./**<br>
**If you have the scripts copied to an other directory reachable via the PATH environment variable, than call the scripts WITHOUT the leading ./ !**


### Directory Structure

There is no directory structure, the current design is FLAT. So all Examples below are generating/using files within the same directory. This should be fine for the most of you. If you're fine with this, skip this section and check the [Scriptfile Syntax](#scriptfiles-syntax) below.<p>However, if you wanna use directories there is a way: 
* **Method-1:** Making a directory for a complete set: (all wallet and poolfiles in one directory)
1. Put the scripts in a directory that is in your PATH environment variable, so you can call the scripts from everywhere.
1. Make a directory whereever you like
1. Call the scripts from within this directory, all files will be generated/used in this directory<p>
* **Method-2:** Using subdirectories from a base directory:
1. Put the scripts in a directory that is in your PATH environment variable, so you can call the scripts from everywhere.
1. Make a directory that is your BASE directory like /home/user/cardano
1. Go into this directory ```cd /home/user/cardano``` and make other subdirectories like ```mkdir mywallets``` and ```mkdir mypools```
1. **Call the scripts now only from this BASE directory** and give the names to the scripts **WITH** the directory in a relative way like (examples):
   <br>```03a_genStakingPaymentAddr.sh mywallets/allmyada``` this will generate your StakeAddressCombo with name allmyada in the mywallets subdirectory
   <br>```05b_genDelegationCert.sh mypools/superpool mywallets/allmyada``` this will generate the DelegationCertificate for your StakeAddress allmyada to your Pool named superpool.
   So, just use always the directory name infront to reference it on the commandline parameters. And keep in mind, you have to do it always from your choosen BASE directory. Because files like the poolname.pool.json are refering also to the subdirectories. And YES, you need a name like superpool or allmyada for it, don't call the scripts without them.<br>
   :bulb: Don't call the scripts with directories like ../xyz or /xyz/abc, it will not work at the moment. Call them from the choosen BASE directory without a leading . or .. Thx!

### File autolock

For a security reason, all important generated files are automatically locked against deleting/overwriting them by accident! Only the scripts will unlock/lock some of them automatically. If you wanna edit/delete a file by hand like editing the name.pool.json simply do a:<br>
```
chmod 600 poolname.pool.json
nano poolname.pool.json
chmod 400 poolname.pool.json
```

## Scriptfiles Syntax

* **00_common.sh:** set your variables in there for your config, will be used by the scripts.<br>
  :bulb: You can also use it to set the CARDANO_NODE_SOCKET_PATH environment variable by just calling ```source ./00_common.sh```

* **01_queryAddress.sh:** checks the amount of lovelaces on an address with autoselection about a UTXO query on enterprise & payment(base) addresses or a rewards query for stake addresses
<br>```./01_queryAddress.sh <name or hash>``` **NEW** you can use the HASH of an address too now.
<br>```./01_queryAddress.sh addr1``` shows the lovelaces from addr1.addr
<br>```./01_queryAddress.sh owner.staking``` shows the current rewards on the owner.staking.addr
<br>```./01_queryAddress.sh addr1vyjz4gde3aqw7e2vgg6ftdu687pcnpyzal8ax37cjukq5fg3ng25m``` shows the lovelaces on this given Bech32 address
<br>```./01_queryAddress.sh stake1u9w60cpjg0xnp6uje8v3plcsmmrlv3vndcz0t2lgjma0segm2x9gk``` shows the rewards on this given Bech32 address

* **01_sendLovelaces.sh:** sends a given amount of lovelaces or ALL lovelaces from one address to another, uses always all UTXOs of the source address
<br>```./01_sendLovelaces.sh <fromAddr> <toAddrName or hash> <lovelaces>``` **NEW** you can now send to an HASH address too
<br>```./01_sendLovelaces.sh addr1 addr2 1000000``` to send 1000000 lovelaces from addr1.addr to addr2.addr
<br>```./01_sendLovelaces.sh addr1 addr2 ALL``` to send ALL funds from addr1.addr to addr2.addr, nothing left in addr1
<br>```./01_sendLovelaces.sh addr1 addr1vyjz4gde3aqw7e2vgg6ftdu687pcnpyzal8ax37cjukq5fg3ng25m ALL``` send ALL funds from addr1.addr to the given Bech32 address

* **01_claimRewards.sh:** claims all rewards from the given stake address and sends it to a receiver address
<br>```./01_claimRewards.sh <nameOfStakeAddr> <toAddr> [optional <feePaymentAddr>]```
<br>```./01_claimRewards.sh owner.staking owner.payment``` sends the rewards from owner.staking.addr to the owner.payment.addr. The transaction fees will also be paid from the owner.payment.addr
<br>```./01_claimRewards.sh owner.staking myrewards myfunds``` sends the rewards from owner.staking.addr to the myrewards.addr. The transaction fees will be paid from the myfunds.addr

* **02_genPaymentAddrOnly.sh:** generates an "enterprise" address with the given name for just transfering funds
<br>```./02_genPaymentAddrOnly.sh <name>```
<br>```./02_genPaymentAddrOnly.sh addr1``` will generate the files addr1.addr, addr1.skey, addr1.vkey<br>

* **03a_genStakingPaymentAddr.sh:** generates the base/payment address & staking address combo with the given name and also the stake address registration certificate
<br>```./03a_genStakingPaymentAddr.sh <name>```
<br>```./03a_genStakingPaymentAddr.sh owner``` will generate the files owner.payment.addr, owner.payment.skey, owner.payment.vkey, owner.staking.addr, owner.staking.skey, owner.staking.vkey, owner.staking.cert<br>

* **03b_regStakingAddrCert.sh:** register the staking address on the blockchain with the certificate from 03a.
<br>```./03b_regStakingAddrCert.sh <nameOfStakeAddr> <nameOfPaymentAddr>```
<br>```./03b_regStakingAddrCert.sh owner.staking addr1``` will register the staking addr owner.staking using the owner.staking.cert with funds from addr1 on the blockchain. you could of course also use the owner.payment address here for funding.<br>

* **03c_checkStakingAddrOnChain.sh:** check the blockchain about the staking address
<br>```./03c_checkStakingAddrOnChain.sh <name>```
<br>```./03c_checkStakingAddrOnChain.sh owner``` will check if the address in owner.staking.addr is currently registered on the blockchain

* **04a_genNodeKeys.sh:** generates the poolname.node.vkey and poolname.node.skey cold keys and resets the poolname.node.counter file
<br>```./04a_genNodeKeys.sh <poolname>```
<br>```./04a_genNodeKeys.sh mypool```

* **04b_genVRFKeys.sh:** generates the poolname.vrf.vkey/skey files
<br>```./04b_genVRFKeys.sh <poolname>```
<br>```./04b_genVRFKeys.sh mypool```

* **04c_genKESKeys.sh:** generates a new pair of poolname.kes-xxx.vkey/skey files, and updates the poolname.kes.counter file. every time you generate a new keypair the number(xxx) autoincrements. To renew your kes/opcert before the keys of your node expires just rerun 04c and 04d!
<br>```./04c_genKESKeys.sh <poolname>```
<br>```./04c_genKESKeys.sh mypool```

* **04d_genNodeOpCert.sh:** calculates the current KES period from the genesis.json and issues a new poolname.node-xxx.opcert certificate. it also generates the poolname.kes-expire.json file which contains the valid start KES-Period and also contains infos when the generated kes-keys will expire. to renew your kes/opcert before the keys of your node expires just rerun 04c and 04d! after that, update the files on your stakepool server and restart the coreNode
<br>```./04d_genNodeOpCert.sh <poolname>```
<br>```./04d_genNodeOpCert.sh mypool```

* **05a_genStakepoolCert.sh:** generates the certificate poolname.pool.cert to (re)register a stakepool on the blockchain
  <br>```./05a_genStakepoolCert.sh <PoolNodeName>``` will generate the certificate poolname.pool.cert from poolname.pool.json file<br>
  The script requires a json file for the values of PoolNodeName, OwnerStakeAddressName(s), RewardsStakeAddressName (can be the same as the OwnerStakeAddressName), pledge, poolCost & poolMargin(0.01-1.00) and PoolMetaData. This script will also generate the poolname.metadata.json file for the upload to your webserver:
  <br>**Sample mypool.pool.json**
  ```console
   {
      "poolName": "mypool",
      "poolOwner": [
         {
         "ownerName": "owner"
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
      "---": "--- DO NOT EDIT BELOW THIS LINE ---"
    }
   ```
   :bulb:   **If the json file does not exist with that name, the script will generate one for you, so you can easily edit it.**<br>

   poolName is the name of your poolFiles from steps 04a-04d, poolOwner is an array of all the ownerStake from steps 03, poolRewards is the name of the stakeaddress getting the pool rewards (can be the same as poolOwner account), poolPledge in lovelaces, poolCost per epoch in lovelaces, poolMargin in 0.00-1.00 (0-100%).<br>
   poolRelays is an array of your IPv4/IPv6 or DNS named public pool relays. Currently the types DNS, IP, IP4, IPv4, IP6 and IPv6 are supported. Examples of multiple relays can be found [HERE](#using-multiple-relays-in-your-poolnamepooljson) <br> MetaName/Description/Ticker/Homepage is your Metadata for your Pool. The script generates the poolname.metadata.json for you. In poolMetaUrl you must specify your location of the file later on your webserver (you have to upload it to this location).<br>After the edit, rerun the script with the name again.<br>
   > :bulb:   **Update Pool values (re-registration):** If you have already registered a stakepool on the chain and want to change some parameters, simply [change](#file-autolock) them in the json file and rerun the script again. The 05c_regStakepoolCert.sh script will later do a re-registration instead of a new registration for you.

* **05b_genDelegationCert.sh:** generates the delegation certificate name.deleg.cert to delegate a stakeAddress to a Pool poolname.node.vkey. As pool owner you have to delegate to your own pool, this is registered as pledged stake on your pool.
<br>```./05b_genDelegationCert.sh <PoolNodeName> <DelegatorStakeAddressName>```
<br>```./05b_genDelegationCert.sh mypool owner``` this will delegate the Stake in the PaymentAddress of the Payment/Stake combo with name owner to the pool mypool

* **05c_regStakepoolCert.sh:** (re)register your **poolname.pool.cert certificate** and also the **owner name.deleg.cert certificate** with funds from the given name.addr on the blockchain. it also updates the pool-ID and the registration date in the poolname.pool.json
<br>```./05c_regStakepoolCert.sh <PoolNodeName> <PaymentAddrForRegistration> [optional REG / REREG keyword]```
<br>```./05c_regStakepoolCert.sh mypool owner.payment``` this will register your pool mypool with the cert and json generated with script 05a on the blockchain. Owner.payment.addr will pay for the fees.<br>
If the pool was registered before (when there is a **regSubmitted** value in the name.pool.json file), the script will automatically do a re-registration instead of a registration. The difference is that you don't have to pay additional fees for a re-registration.<br>
  > :bulb: If something went wrong with the original pool registration, you can force the script to redo a normal registration by adding the keyword REG on the commandline like ```./05c_regStakepoolCert.sh mypool mywallet REG```<br>
Also you can force the script to do a re-registration by adding the keyword REREG on the command line like ```./05c_regStakepoolCert.sh mypool mywallet REREG```

* ~~**05d_checkPoolOnChain.sh:** checks the ledger-state about a given pool name -> poolname.pool.json
<br>```./05d_checkPoolOnChain.sh <PoolNodeName>```
<br>```./05d_checkPoolOnChain.sh mypool``` checks if the pool mypool is registered on the blockchain~~

* **06_regDelegationCert.sh:** register a simple delegation (from 05b) name.deleg.cert 
<br>```./06_regDelegationCert.sh <delegatorName> <nameOfPaymentAddr>```
<br>```./06_regDelegationCert.sh someone someone.payment``` this will register the delegation certificate someone.deleg.cert for the stake-address someone.staking.addr on the blockchain. The transaction fees will be paid from someone.payment.addr.

* **07a_genStakepoolRetireCert.sh:** generates the de-registration certificate poolname.pool.dereg-cert to retire a stakepool from the blockchain
  <br>```./07a_genStakepoolRetireCert.sh <PoolNodeName> [optional retire EPOCH]```
  <br>```./07a_genStakepoolRetireCert.sh mypool``` generates the mypool.pool.dereg-cert to retire the pool in the NEXT epoch
  <br>```./07a_genStakepoolRetireCert.sh mypool 253``` generates the poolname.pool.dereg-cert to retire the pool in epoch 253<br>
  The script requires a poolname.pool.json file with values for at least the PoolNodeName & OwnerStakeAddressName. It is the same json file we're already using since script 05a, so a total pool history json file.<br>
  **If the json file does not exist with that name, the script will generate one for you, so you can easily edit it.**<br>
   poolName is the name of your poolFiles from steps 04a-04d, poolOwner is the name of the StakeOwner from steps 03

* **07b_deregStakepoolCert.sh:** de-register (retire) your pool with the **poolname.pool.dereg-cert certificate** with funds from name.payment.addr from the blockchain. it also updates the de-registration date in the poolname.pool.json
<br>```./07b_deregStakepoolCert.sh <PoolNodeName> <PaymentAddrForDeRegistration>```
<br>```./07b_deregStakepoolCert.sh mypool mywallet``` this will retire your pool mypool with the cert generated with script 07a from the blockchain. The transactions fees will be paid from the mywallet.addr account.<br>

* **08a_genStakingAddrRetireCert.sh:** generates the de-registration certificate name.staking.dereg-cert to retire a stake-address form the blockchain
  <br>```./08a_genStakingAddrRetireCert.sh <name>```
  <br>```./08a_genStakingAddrRetireCert.sh owner``` generates the owner.staking.dereg-cert to retire the owner.staking.addr
  
* **08b_deregStakingAddrCert.sh:** re-register (retire) you stake-address with the **name.staking.dereg-cert certificate** with funds from name.payment.add from the blockchain.
  <br>```./08b_deregStakingAddrCert.sh <nameOfStakeAddr> <nameOfPaymentAddr>```
  <br>```./08b_deregStakingAddrCert.sh owner.staking owner.payment``` this will retire your owner staking address with the cert generated with script 08a from the blockchain.


### poolname.pool.json

The json file could end up like this one after the pool was registered and also later de-registered.<br>In the future we can add values like poolTicker, poolRelays & poolHomepage for example.
```console
{
  "poolName": "mypool",
  "poolOwner": [
         {
         "ownerName": "owner"
         }
         {
         "ownerName": "otherowner2"
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

# Examples

## Generating a normal address, register a stake address, register a stake pool

Lets say we wanna make ourself a normal address to send/receive ada, we want this to be nicknamed mywallet.
Than we want to make ourself a pool owner stake address with the nickname owner, also we want to register a pool with the nickname mypool. The nickname is only to keep the files on the harddisc in order, nickname is not a ticker!

1. First, we need a running node. After that make your adjustments in the 00_common.sh script so the variables are pointing to the right files and source it (```source ./00_common.sh```)
1. Generate a simple address to receive some ADA ```./02_genPaymentAddrOnly.sh mywallet```
1. Transfer some ADA to that new address mywallet.addr
1. Check that you received it using ```./01_queryAddress.sh mywallet```
1. Generate the owner stake/payment combo with ```./03a_genStakingPaymentAddr.sh owner```
1. Send yourself over some funds to that new address owner.payment.addr to pay for the registration fees
<br>```./01_sendLovelaces.sh mywallet owner.payment 10000000```<br>
If you wanna send over all funds from your mywallet call the script like
<br>```./01_sendLovelaces.sh mywallet owner.payment ALL```
1. Check that you received it using ```./01_queryAddress.sh owner.payment```
1. Register the owner stakeaddress on the blockchain ```./03b_regStakingAddrCert.sh owner.staking owner.payment```
1. (Optional: you can verify that your stakeaddress in now on the blockchain by running<br>```./03c_checkStakingAddrOnChain.sh owner``` if you don't see it, wait a little and retry)
1. Generate the keys for your coreNode
   1. ```./04a_genNodeKeys.sh mypool```
   1. ```./04b_genVRFKeys.sh mypool```
   1. ```./04c_genKESKeys.sh mypool```
   1. ```./04d_genNodeOpCert.sh mypool```
1. Now you have all the key files to start your coreNode with them
1. Make sure you have enough funds on your owner.payment.addr to pay the pool registration fee in the next steps. Make sure to make your fund big enough to stay above the pledge that we will set in the next step.
1. Generate your stakepool certificate
   1. ```./05a_genStakepoolCert.sh mypool```<br>will generate a prefilled mypool.pool.json file for you, edit it
   1. We want 200k ADA pledge, 10k ADA costs per epoch and 8% pool margin so let us set these and the Metadata values in the json file like
   ```console
   {
      "poolName": "mypool",
      "poolOwner": [
         {
         "ownerName": "owner"
         }
      ],
      "poolRewards": "owner",
      "poolPledge": "200000000000",
      "poolCost": "10000000000",
      "poolMargin": "0.08"
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
      "---": "--- DO NOT EDIT BELOW THIS LINE ---"
   }
   ```
   1. Run ```./05a_genStakepoolCert.sh mypool``` again with the saved json file, this will generate the mypool.pool.cert file
1. Delegate to your own pool as owner -> pledge ```./05b_genDelegationCert.sh mypool owner``` this will generate the owner.deleg.cert
1. :bulb: **Upload** the generated ```mypool.metadata.json``` file **onto your webserver** so that it is reachable via the URL you specified in the poolMetaUrl entry! Otherwise the next step will abort with an error.
1. Register your stakepool on the blockchain ```./05c_regStakepoolCert.sh mypool owner.payment```    
~~1. (Optional: you can verify that your stakepool is now on the blockchain by running ```./05d_checkPoolOnChain.sh mypool```<br>If you dont see it, wait a little and retry)~~

Done.

## Generating & register a stake address, just delegating to a stakepool

Lets say we wanna create a payment(base)/stake address combo with the nickname delegator and we wanna delegate the funds in the payment(base) address of that to the pool yourpool. (You'll need the yourpool.node.vkey for that.)

1. First, we need a running node. After that make your adjustments in the 00_common.sh script so the variables are pointing to the right files.
1. Generate the delegator stake/payment combo with ```./03a_genStakingPaymentAddr.sh delegator```
1. Send over some funds to that new address delegator.payment.addr to pay for the registration fees and to stake that also later
1. Register the delegator stakeaddress on the blockchain ```./03b_regStakingAddrCert.sh delegator.staking delegator.payment```<br>Other example: ```./03b_regStakingAddrCert.sh delegator.staking mywallet``` Here you would use the funds in mywallet to pay for the fees.
1. (Optional: you can verify that your stakeaddress in now on the blockchain by running<br>```./03c_checkStakingAddrOnChain.sh delegator``` if you don't see it instantly, wait a little and retry the same command)
1. Generate the delegation certificate delegator.deleg.cert with ```./05b_genDelegationCert.sh yourpool delegator```
1. Register the delegation certificate now on the blockchain with funds from delegator.payment.addr<br>```./06_regDelegationCert.sh delegator delegator.payment```

Done.

## Update stakepool parameters on the blockchain

If you wanna update you pledge, costs, owners or metadata on a registered stakepool just do the following

1. [Unlock](#file-autolock) the existing mypool.pool.json file and edit it. Only edit the poolOwnerAccount/poolRewardsAccount/poolPledge/poolCost/poolMargin and poolMetaXXX values, save it.
1. Run ```./05a_genStakepoolCert.sh mypool``` to generate a new mypool.pool.cert file from it
1. :bulb: **Upload** the new ```mypool.metadata.json``` file **onto your webserver** so that it is reachable via the URL you specified in the poolMetaUrl entry! Otherwise the next step will abort with an error.
1. (Optional create delegation certificates if you have added an owner or an extra rewards account with script 05b)
1. Re-Register your stakepool on the blockchain with ```./05c_regStakepoolCert.sh mypool owner.payment```<br>No delegation update needed.

Done.  

## Claiming rewards on the Shelley blockchain

I'am sure you wanna claim some of your rewards that you earned running your stakepool. So lets say you have rewards in your owner.staking address and you wanna claim it to the owner.payment address.

1. You can always check that you have rewards in your stakeaccount by running ```./01_queryAddress.sh owner.staking```
1. Now you can claim your rewards by running ```./01_claimRewards.sh owner.staking owner.payment```
   This will claim the rewards from the owner.staking account and sends it to the owner.payment address, also owner.payment will pay for the transaction fees. It is only possible to claim all rewards, not only a part of it.<br>
   :bulb: ATTENTION, claiming rewards costs transaction fees! So you have two choices for that: The destination address pays for the transaction fees, or you specify an additional account that pays for the transaction fees. You can find examples for that above at the script 01_claimRewards.sh description.

Done.  

### Claiming rewards from the ITN Testnet with only SK/PK keys

If you ran a stakepool on the ITN and you only have your owner SK and PK ed25519 keys you can claim your rewards like:

1. If you have ed25519 keys and not ed25519**e** keys you can skip to the next step. Otherwise you have to wait a a little longer to claim your rewards. ed25519e keys are currently not supported. But you still can check your balance if you wanna continue...
1. Convert your ITN keys into a Shelley Staking Address by running: 
   <br>```./0x_convertITNtoStakeAddress.sh <StakeAddressName> <Private_Key_HASH_ed25519>  <Public_Key_HASH_ed25519>```
   <br>```./0x_convertITNtoStakeAddress.sh myitnrewards  ed25519_sk1qq... ed25519_pk1u62x9...```
   <br>This will generate a new Shelley stakeaddress with the 3 files myitnrewards.staking.skey, myitnrewards.staking.vkey and myitnrewards.staking.addr
1. You can check now your rewards by running ```./01_queryAddress.sh myitnrewards.staking```
1. You can claim your rewards by running ```./01_claimRewards.sh myitnrewards.staking destinationaccount``` like a normal rewards claim procedure, example above!

Done.  



## Register a multiowner stake pool

It's similar to a single owner stake pool registration (example above). All owners must have a registered stake address on the blockchain first! Here is a 2 owner example ...

1. Generate the stakepool certificate
   1. ```./05a_genStakepoolCert.sh mypool```<br>will generate a prefilled mypool.pool.json file for you, edit it for multiowner usage and set your owners and also the rewards account. The rewards account is also a stake address (but not delegated to the pool!):
    ```console
   {
      "poolName": "mypool",
      "poolOwner": [
         {
         "ownerName": "owner-1"
         },
         {
         "ownerName": "owner-2"
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
1. Register your stakepool on the blockchain ```./05c_regStakepoolCert.sh mypool paymentaddress```    

Done.

## Using multiple relays in your poolname.pool.json

### Using two dns named relay entries

Your poolRelays array section in the json file should like similar to:

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



## Retire a stakepool from the blockchain

If you wanna retire your registered stakepool mypool, you have to do just a few things

1. Generate the retirement certificate for the stakepool mypool from data in mypool.pool.json<br>
   ```./07a_genStakepoolRetireCert.sh mypool``` this will retire the pool at the next epoch
1. De-Register your stakepool from the blockchain with ```./07b_deregStakepoolCert.sh mypool owner.payment```
1. You can check the current status of your onchain registration via the script 05d like<br>
   ```./05d_checkPoolOnChain.sh mypool```
 
Done.

## Retire a stakeaddress from the blockchain

If you wanna retire the staking address owner, you have to do just a few things

1. Generate the retirement certificate for the stake-address ```./08a_genStakingAddrRetireCert.sh owner```<br>this will generate the owner.staking.dereg-cert file
1. De-Register your stake-address from the blockchain with ```./08b_deregStakingAddrCert.sh owner.staking owner.payment```<br>you don't need to have funds on the owner.payment base address. you'll get the keyDepositFee back onto it!
1. You can check the current status of your onchain registration via the script 03c like<br>
   ```./03c_checkStakingAddrOnChain.sh owner```<br>If it doesn't go away directly, wait a little and retry this script.
 
Done.


