# Description

## Files types uses

I use the following naming scheme for the files:<br>
``` name.payment.addr, name.payment.skey, name.payment.vkey
name.staking.addr, name.staking.skey, name.staking.vkey, name.staking.cert

name.node.vkey, name.node.skey, name.node.counter

name.vrf.vkey, name.vrf.skey

name.kes-xxx.vkey, name.kes-xxx.skey, name.node-xxx.opcert (xxx increments with each KES generation)
```

The *.addr files contains the address in the format "61386ab8..." or "011d4e1cdcdb000ff11e9430..." for example.

## Scriptfiles short info

* **00_common.sh:** set your variables in there for your config

* **01_queryAddress.sh:** checks the amount of lovelaces on an address<br>
```./01_queryAddress.sh addr1``` shows the lovelaces from addr1.addr

* **01_sendLovelaces.sh:** sends a given amount of lovelaces or ALL lovelaces from one address to another, uses always all UTXOs of the source address<br>
```./02_sendLovelaces.sh addr1 addr2 1000000``` to send 1000000 from addr1.addr to addr2.addr<br>
```./02_sendLovelaces.sh addr1 addr2 ALL``` to send ALL funds from addr1.addr to addr2.addr, nothing left in addr1

* **02_genPaymentAddrOnly.sh:** generates an "enterprise" address with the given name for just transfering funds<br>
```./02_genPaymentAddrOnly.sh addr1``` will generate the files addr1.addr, addr1.skey, addr1.vkey<br>

* **03a_genStakingPaymentAddr.sh:** generates the base/payment address & staking address combo with the given name and also the stake address registration certificate<br>
```./03a_genStakingPaymentAddr.sh owner``` will generate the files owner.payment.addr, owner.payment.skey, owner.payment.vkey, owner.staking.addr, owner.staking.skey, owner.staking.vkey, owner.staking.cert<br>

* **03b_regStakingAddrCert.sh:** to register the staking address on the blockchain with the certificate
```./03a_regStakingAddrCert.sh owner.staking owner.payment``` will register the staking addr owner.staking using the owner.staking.cert with funds from owner.payment on the blockchain. this will also introduce the blockchain with your owner.payment address, so the chain knows the staking/base address relationship is there.<br>
