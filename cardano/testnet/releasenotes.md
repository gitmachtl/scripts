# SPO Scripts 17-12-2023

## 🔥 New Feature - LIGHT-Mode, running the SPO Scripts without a local node 🔥

This is an exciting new feature in the SPO Scripts. Before we had two operational modes, **Online-Mode** and **Offline-Mode**. Now we have an additional one, the **Light-Mode**. 

**So whats this Light-Mode?** If you switch the scripts into Light-Mode - see below how easy it is to do so - you have the advantage of being online with your machine, but you don't
need a running synced cardano-node. You can switch between Networks Mainnet, PreProd and PreView within seconds. 

This comes is handy if you just don't want to install and run a cardano-node, if you don't have the space for the database or if you just don't have the time to wait for a resync. 

All transactions are of course generated and signed locally, but the queries and the transmit is done via online APIs like Koios. <br>

### How do you switch between Online-, Light- and Offline-Mode?
  
Thats simple, you just change a single entry in the **00_common.sh**, **common.inc** or **$HOME/.common.inc** config-file:
![image](https://github.com/gitmachtl/scripts/assets/47434720/4c6cc57b-5489-4285-af62-2d8b0bbdbeab)

* **`workMode="online"`:** Scripts are working in Online-Mode aka Full-Mode. A locally running and synced cardano-node is needed.
* **`workMode="light"`:** Scripts are working in Light-Mode. No cardano-node needed.
* **`workMode="offline"`:** Scripts are working in isolation and completely offline. No cardano-node needed. 

Here is a simple example of a transaction in Light-Mode:
![image](https://github.com/gitmachtl/scripts/assets/47434720/4bfb186c-8955-4935-9bd0-58ff369e6c1f)

Notice the **new mode** is indicated via the `Mode: online(light)` in the header.

And we can of course check that the amount arrived, this has all been done in Light-Mode. There is no Mainnet Cardano-Node running on that machine 😄
![image](https://github.com/gitmachtl/scripts/assets/47434720/a972b2b4-742e-4742-b3df-0e28a6f240c2)

**You can do ALL OPERATIONS in Light-Mode now!** 💙 Currently supported Chains are Mainnet, PreProd and PreView. You can switch between chains in seconds, and if you put a
different `common.inc` file into your folders, you can run them all in parallel too. I also wanna thank Holger from Cardano24, because i am hosting
the Online-Version of the `Protocol-Parameters JSON` files on his distributed Server-Platform [uptime.live](https://uptime.live), thank you! The JSON files are updates every 10 mins to make them available in Light-Mode.

If you have an Online/Offline Workflow, you can use the Online machine in Light-Mode, and your Offline machine is still offline of course.

<br>&nbsp;<p>

## 🔥 New Feature - *$Sub-Handle* & *$Virtual-Handle* support for *$Adahandles* 🔥

Complete support for the upcoming **Sub**-Handle and **Virtual**-Handle release. All scripts than can use Adahandles for queries and destinations are upgraded to support these additional formats.
As always, the scripts doing a second lookup if the Handles are really on the UTXOs that the APIs report. For the Virtual-Handles the Scripts are doing an extra Koios request to checkout the Inline-Datum
content of the UTXO holding the Virtual-Handle. Virtual-Handles store the destination address within the Inline-Datum.

**Sub-Handles**
![image](https://github.com/gitmachtl/scripts/assets/47434720/bc033d01-f286-4a7c-b838-0edc5751437a)

As you can see this address also holds the Virtual-Handle `$virtual@hndl` which points to another address, we can query that too like below.

**Virtual-Handles**
![image](https://github.com/gitmachtl/scripts/assets/47434720/577b72c4-b965-4e7d-bfbe-7107fb75d132)

Also there has been an Update to show all the different types of Adahandles in the Query, like `ADA Handle` for the original CIP-25 one, `Ada Handle(Own)` for the new CIP68 ones. `Ada Handle(Ref)` and `Ada Handle(Virt)` for the newest formats.

<br>&nbsp;<p>

## Improvements to the Online-Mode (aka Full-Mode)

* Critical queries now always do a check if the local node is 100% synced with the chain before continuation.
  ![image](https://github.com/gitmachtl/scripts/assets/47434720/5be18960-333a-4401-8c6c-37a4bf874611)

<br>&nbsp;<p>

## Improvements to the Offline-Mode

* In Offline-Mode the header on each Script Call now shows your local machine time. This is really important if you are doing things like an OpCert-Update to generate the right KES period.
  So now you can do an easy check if the time on your Offline-Machine is correct
* NativeAsset Token-Registry Information also in Offline-Mode. To get the UTXO data of an address you wanna use in Offline-Mode you are using the command `./01_workOffline.sh add <walletname>`.
  This query - if enabled in the config - now also stores the Token-Registry information about NativeAssets on this address within the `offlineTransfer.json` file.

![image](https://github.com/gitmachtl/scripts/assets/47434720/c0e120b8-8da1-4841-ad3f-4b0d2f66bfb2)

<br>&nbsp;<p>

## General updates

* **The SPO Scripts are now fully Conway-Era compatible!** 🔥

* `01_claimRewards.sh, 01_queryAddress.sh` are now showing if the Stake-Address is delegated to a pool. If so it tries to show additional pool-informations like the Ticker, Description and the current Pool-Status
  ![image](https://github.com/gitmachtl/scripts/assets/47434720/c58dba18-839e-4ec4-822c-7d7ff52963fa)

* `03a_genStakingPaymentAddr.sh`: The generation of the Stake-Address registration certificate has been moved to be done within `03b_regStakingAddrCert.sh`. This is a change for **conway-era**, because we now have to check
  the StakeAdress-Registration Deposit-Fee also for the deregistration. The Deposit-Fee can change after a registration has been done, so with **conway-era** the used amount is now stored within the certificate itself.
  If the StakeAddress is already registered on chain, the Script will tell you that and if also delegated to a Pool, it wil try to show you additional informations.<br>
  <br>Already registered:
  ![image](https://github.com/gitmachtl/scripts/assets/47434720/0907c3e9-b359-420f-b95b-3304611f1c16)
  <br>New registration in conway-era:
  ![image](https://github.com/gitmachtl/scripts/assets/47434720/784fe982-fa0e-4c5c-98d3-81f7337d99e7)

* `03c_checkStakingAddrOnChain.sh` now also shows the used Deposit-Fee of a registered Stake-Address. If delegated to a pool, it tries to show additional Informations.
  ![image](https://github.com/gitmachtl/scripts/assets/47434720/92256d65-1d79-4481-8b8c-6c4fc97c9029)

* `04d_genNodeOpCert.sh` now directly ready out the `onDisKOpCertCount` from the via an own new CBOR-Decode function to provide checking information in Light-Mode.

* `04e_checkNodeOpCert.sh` now ready out the `onDiscOpCertCount` and the `onDiskKESSStart` values for checking in Online- and Light-Mode

* `05a_genStakepoolCert.sh` now shows the set poolPledge also in ADA and not only in lovecase. Shows minPoolCost now also in ADA and not only in lovelaces. Shows the poolMargin now in percentage and not as decimal value.

* `05c_regStakepoolCert.sh` now shows the set poolPledge also in ADA and not only in lovecase. Shows minPoolCost now also in ADA and not only in lovelaces. Shows the poolMargin now in percentage and not as decimal value.
  <br>A pool update/registration/retirement of course now also works in Light-Mode:
  ![image](https://github.com/gitmachtl/scripts/assets/47434720/7d402728-4b2b-4492-bbc1-eddcc6188552)
  If there are external Witnesses (MultiOwnerPool) and the registration is done with an attached Metadata-JSON/CBOR, that information is now also stored to be represented in the external witness file.
  
* `05e_checkPoolOnChain.sh` now gives you detailed informations about the current pool-status. You can of course also use a pool-id in bech or hex to query this information with this script.<br>
  <br>Registered:
  ![image](https://github.com/gitmachtl/scripts/assets/47434720/833a38ab-1689-4fa9-a886-15013593d4b9)
  <br>Retired:
  ![image](https://github.com/gitmachtl/scripts/assets/47434720/d45cb4d8-b8e0-40f4-8f85-cefc4d8273b6)
  <br>Was never registered on the chain:
  ![image](https://github.com/gitmachtl/scripts/assets/47434720/1cbb1100-94eb-4063-8f9a-445bb9c826f5)

* `06_regDelegationCert.sh` now checks the pool status you wanna send the delegation before continue with the transaction. If a pool is retired or was not registered on the chain(yet), such a transaction would let to an error.
  This precheck avoids this issue. In addition there is now a check that the Stake-Address is already registered on chain. Also, it now shows information about a current delegation and the planned delegation. The script directly reads out the delegation destination pool-id from the delegation certificate to show
  this information. <br>
  <br>Pool to delegate to not registered on chain(yet):
  ![image](https://github.com/gitmachtl/scripts/assets/47434720/532972f2-1030-4536-9721-22298255ef75)
  <br>Showing the old delegation and the new delegation:
  ![image](https://github.com/gitmachtl/scripts/assets/47434720/a03f0e42-2165-4f0e-a95a-7d053d6ea256)

* `08a_genStakingAddrRetireCert.sh`now checks if the Stake-Address is even registered before generating the Retirement-Certificate. Also now important, it checks the Deposit-Fee that was used to register the Stake-Address
  in first place. Because we need to use the exact Fee again to retire the Stake-Address. There is now also a check if the Stake-Address you wanna retire still holds rewards. If the Stake-Address still hold rewards, it will
  show you the amount and refuse to generate a Retirement certificate. In that case please first claim all your rewards via `01_claimRewards.sh` and after that retire the Stake-Address.<br>
  <br>Stake-Address not registered, so no need to deregister it:
  ![image](https://github.com/gitmachtl/scripts/assets/47434720/4fb6a392-9e6c-40c6-b456-01167847a702)
  <br>Stake-Address still holds rewards, we cannot retire it now:
  ![image](https://github.com/gitmachtl/scripts/assets/47434720/46d56ee2-9979-442e-8b3b-0efba18d419a)
  <br>Ok, Stake-Address was registered with a Deposit-Fee of 2000000 lovelaces, generate the Retirement-Certificate:
  ![image](https://github.com/gitmachtl/scripts/assets/47434720/a944a53e-bec9-4fd7-95aa-83a7548e1873)

* `08b_deregStakingAddrCert.sh`now again checks the current Stake-Address status on chain and a possible active delegation. Just to make sure you're retireing the right Stake-Address. It also now directly reads out the used
  Stake-Address Deposit-Fee to calculate the balance return correctly.
  ![image](https://github.com/gitmachtl/scripts/assets/47434720/06b1c0e3-170f-4160-85bf-e65d925cd5c7)

* Many additional updates here and there for better request handling via curl, better error checks, etc ...

## Please enjoy this huge update and especially the new Light-Mode 💙
