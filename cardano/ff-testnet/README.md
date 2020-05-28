# Description

## Files types uses

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
<br>```./01_queryAddress.sh addr1``` shows the lovelaces from addr1.addr

* **01_sendLovelaces.sh:** sends a given amount of lovelaces or ALL lovelaces from one address to another, uses always all UTXOs of the source address
<br>```./02_sendLovelaces.sh addr1 addr2 1000000``` to send 1000000 from addr1.addr to addr2.addr
<br>```./02_sendLovelaces.sh addr1 addr2 ALL``` to send ALL funds from addr1.addr to addr2.addr, nothing left in addr1

* **02_genPaymentAddrOnly.sh:** generates an "enterprise" address with the given name for just transfering funds
<br>```./02_genPaymentAddrOnly.sh addr1``` will generate the files addr1.addr, addr1.skey, addr1.vkey<br>

* **03a_genStakingPaymentAddr.sh:** generates the base/payment address & staking address combo with the given name and also the stake address registration certificate
<br>```./03a_genStakingPaymentAddr.sh owner``` will generate the files owner.payment.addr, owner.payment.skey, owner.payment.vkey, owner.staking.addr, owner.staking.skey, owner.staking.vkey, owner.staking.cert<br>

* **03b_regStakingAddrCert.sh:** to register the staking address on the blockchain with the certificate
<br>```./03a_regStakingAddrCert.sh owner.staking owner.payment``` will register the staking addr owner.staking using the owner.staking.cert with funds from owner.payment on the blockchain. this will also introduce the blockchain with your owner.payment address, so the chain knows the staking/base address relationship is there.<br>

* **04a_genNodeKeys.sh:** generates the name.node.vkey and name.node.skey cold keys and resets the name.node.counter file
<br>```./04a_genNodeKeys.sh name```

* **04b_genVRFKeys.sh:** generates the name.vrf.vkey/skey files
<br>```./04b_genVRFKeys.sh name```

* **04c_genKESKeys.sh:** generates a new pair of name.kes-xxx.vkey/skey files, and updates the name.kes.latest counter file. every time you generate a new keypair the number(xxx) autoincrements. to renew your kes/opcert before the keys of your node expires just rerun 04c and 04d!
<br>```./04c_genKESKeys.sh name```

* **04d_genNodeOpCert.sh:** calculates the current KES period from the genesis.json and issues a new name.node-xxx.opcert certificate.
it also generates the name.kes.expire file which contains the valid start KES-Period and also contains infos when the generated kes-keys will expire. to renew your kes/opcert before the keys of your node expires just rerun 04c and 04d! after that, update the file on your stakepool server and restart the coreNode
<br>```./04d_genNodeOpCert.sh name```

