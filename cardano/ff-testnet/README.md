# Description

Theses scripts here should help you to start, i made them for myself, not for a bullet proof public use. Just to make things easier for myself while learning all the commands and steps to bring up the stakepool node. So, don't be mad at me if something is not working. CLI calls are different almost daily currently.

Feel free to reach out to me on telegram @atada_stakepool

## File-Naming used

I use the following naming scheme for the files:<br>
``` 
Simple "enterprise" address:
name.addr, name.vkey, name.skey

Payment(Base)/Staking address combo:
name.payment.addr, name.payment.skey, name.payment.vkey, name.deleg.cert
name.staking.addr, name.staking.skey, name.staking.vkey, name.staking.cert

Node files:
name.node.vkey, name.node.skey, name.node.counter, name.pool.cert, name.pool.id
name.vrf.vkey, name.vrf.skey
name.kes-xxx.vkey, name.kes-xxx.skey, name.node-xxx.opcert (xxx increments with each KES generation)
name.kes.counter, name.kes.expire
```

The *.addr files contains the address in the format "61386ab8..." or "011d4e1cdcdb000ff11e9430..." for example.
If you have an address and you wanna use it just do a simple:
```echo "61386ab8..." > myaddress.addr```

## Scriptfiles short info

* **00_common.sh:** set your variables in there for your config, will be used by the scripts. you can also use it to set the CARDANO_NODE_SOCKET_PATH variable by just calling ```source ./00_common.sh```

* **01_queryAddress.sh:** checks the amount of lovelaces on an address
<br>```./01_queryAddress.sh <name>```
<br>```./01_queryAddress.sh addr1``` shows the lovelaces from addr1.addr

* **01_sendLovelaces.sh:** sends a given amount of lovelaces or ALL lovelaces from one address to another, uses always all UTXOs of the source address
<br>```./02_sendLovelaces.sh <fromAddr> <toAddr> <lovelaces>```
<br>```./02_sendLovelaces.sh addr1 addr2 1000000``` to send 1000000 lovelaces from addr1.addr to addr2.addr
<br>```./02_sendLovelaces.sh addr1 addr2 ALL``` to send ALL funds from addr1.addr to addr2.addr, nothing left in addr1

* **02_genPaymentAddrOnly.sh:** generates an "enterprise" address with the given name for just transfering funds
<br>```./02_genPaymentAddrOnly.sh <name>```
<br>```./02_genPaymentAddrOnly.sh addr1``` will generate the files addr1.addr, addr1.skey, addr1.vkey<br>

* **03a_genStakingPaymentAddr.sh:** generates the base/payment address & staking address combo with the given name and also the stake address registration certificate
<br>```./03a_genStakingPaymentAddr.sh <name>```
<br>```./03a_genStakingPaymentAddr.sh owner``` will generate the files owner.payment.addr, owner.payment.skey, owner.payment.vkey, owner.staking.addr, owner.staking.skey, owner.staking.vkey, owner.staking.cert<br>

* **03b_regStakingAddrCert.sh:** to register the staking address on the blockchain with the certificate
<br>```./03a_regStakingAddrCert.sh <nameOfStakeAddr> <nameOfPaymentAddr>```
<br>```./03a_regStakingAddrCert.sh owner.staking owner.payment``` will register the staking addr owner.staking using the owner.staking.cert with funds from owner.payment on the blockchain. this will also introduce the blockchain with your owner.payment address, so the chain knows the staking/base address relationship.<br>

* **04a_genNodeKeys.sh:** generates the name.node.vkey and name.node.skey cold keys and resets the name.node.counter file
<br>```./04a_genNodeKeys.sh <name>```
<br>```./04a_genNodeKeys.sh mypool```

* **04b_genVRFKeys.sh:** generates the name.vrf.vkey/skey files
<br>```./04b_genVRFKeys.sh <name>```
<br>```./04b_genVRFKeys.sh mypool```

* **04c_genKESKeys.sh:** generates a new pair of name.kes-xxx.vkey/skey files, and updates the name.kes.latest counter file. every time you generate a new keypair the number(xxx) autoincrements. to renew your kes/opcert before the keys of your node expires just rerun 04c and 04d!
<br>```./04c_genKESKeys.sh <name>```
<br>```./04c_genKESKeys.sh mypool```

* **04d_genNodeOpCert.sh:** calculates the current KES period from the genesis.json and issues a new name.node-xxx.opcert certificate.
it also generates the name.kes.expire file which contains the valid start KES-Period and also contains infos when the generated kes-keys will expire. to renew your kes/opcert before the keys of your node expires just rerun 04c and 04d! after that, update the file on your stakepool server and restart the coreNode
<br>```./04d_genNodeOpCert.sh <name>```
<br>```./04d_genNodeOpCert.sh mypool```

* **05a_genStakepoolCert.sh:** generates the certificate name.pool.cert to register a stakepool on the blockchain
<br>```./05a_genStakepoolCert.sh <PoolNodeName> <OwnerStakeAddressName> <pledge> <poolCost> <poolMargin 0.01-1.00>```
<br>```./05a_genStakepoolCert.sh mypool owner 250000000000 10000000000 0.08``` will generate a certificate mypool.pool.cert with the ownerStakeName owner 250000k ADA pledge set, costs per epoch 10k ADA and a poolMargin of 8% per epoch.

* **05b_genDelegationCert.sh:** generate the delegation certificate name.deleg.cert to delegate a stakeAddress to a Pool name.node.vkey. As pool owner you have to delegate to your own pool, this is registered as pledged stake on your pool.
<br>```./05b_genDelegationCert.sh <PoolNodeName> <DelegatorStakeAddressName>```
<br>```./05b_genDelegationCert.sh mypool owner``` this will delegate the Stake in the PaymentAddress of the Payment/Stake combo with name owner to the pool mypool

* **05c_regStakepoolCert.sh:** register your name.pool.cert certificate and also your name.deleg.cert certificate with funds from name.payment.addr on the blockchain. it also generates the name.pool.id file.
<br>```./05c_regStakepoolCert.sh <PoolNodeName> <OwnerStakeAddressName>```
<br>```./05c_regStakepoolCert.sh mypool owner``` this will register your pool mypool with the ownerStake owner on the blockchain

* **05d_checkPoolOnChain.sh:** checks the ledger-state about a given pool name -> name.pool.id
<br>```./05d_checkPoolOnChain.sh <PoolNodeName>```
<br>```./05d_checkPoolOnChain.sh mypool``` checks if the pool mypool is registered on the blockchain

# Example

## Generating a normal address, register a stake address, register a stake pool

Lets say we wanna make ourself a normal address to send/receive ada, we want this to be nicknamed mywallet.
Than we want to make ourself a pool owner stake address with the nickname owner, also we want to register a pool with the nickname mypool. The nickname is only to keep the files on the harddisc in order, nickname is not a ticker!

1. First, we need a running node. After that make your adjustments in the 00_common.sh script so the variables are pointing to the right files.
1. Generate a simple address to receive some ADA ```02_genPaymentAddrOnly.sh mywallet```
1. Transfer some ADA to that new address mywallet.addr
1. Check that you received it using ```01_queryAddress.sh mywallet```
1. Generate the owner stake/payment combo with ```03a_genStakingPaymentAddr.sh owner```
1. Send yourself over some funds to that new address owner.payment.addr to pay for the registration fees
1. Check that you received it using ```01_queryAddress.sh owner.payment```
1. Register the owner stakeaddress on the blockchain ```03b_regStakingAddrCert.sh owner.staking owner.payment```
1. Generate the keys for your coreNode
   1. ```04a_genNodeKeys.sh mypool```
   1. ```04b_genVRFKeys.sh mypool```
   1. ```04c_genKESKeys.sh mypool```
   1. ```04d_genNodeOpCert.sh mypool```
1. Now you have all the key files to start your coreNode with them
1. Make sure you have enought funds on your owner.payment.addr to pay the pool registration fee in the next steps. Make sure to make your fund big enought to stay above the pledge that we will set in the next step.
1. Generate your stakepool certificate with lets say 200k ADA pledge, 10k ADA costs per epoch and 10% pool margin
<br>```05a_genStakepoolCert.sh mypool owner 200000000000 10000000000 0.1```
1. Delegate to your own pool as owner -> pledge ```./05b_genDelegationCert.sh mypool owner```
1. Register your stakepool on the blockchain ```./05c_regStakepoolCert.sh mypool owner```    

Done.
