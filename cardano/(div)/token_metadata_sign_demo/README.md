## Token Metadata Registry - Demo Signing of the JSON entries

The little demo includes a signed json and an unsigned one. 

https://github.com/gitmachtl/scripts/tree/master/cardano/(div)/token_metadata_sign_demo

The signing is basically:

> Most everything is encoded as CBOR, then hashed with Blake2b_256.
> 
> 1. The first step is to grab a series of hashes
>    
>    1. hash subject
>       
>       * encode string as CBOR
>       * hash with Blake2b_256 algorithm
>    2. hash well-known property name
>       
>       * encode string as CBOR
>       * hash with Blake2b_256 algorithm
>    3. hash well-known property value (different properties have different representations before hashing)
>       
>       * policy:
>         
>         * encode string as CBOR
>         * hash with Blake2b_256 algorithm
>       * decimals
>         
>         * encode int as CBOR
>         * hash with Blake2b_256 algorithm
>       * name
>         
>         * encode string as CBOR
>         * hash with Blake2b_256 algorithm
>       * description
>         
>         * encode string as CBOR
>         * hash with Blake2b_256 algorithm
>       * logo
>         
>         * encode bytes as CBOR
>         * hash with Blake2b_256 algorithm
>       * url
>         
>         * encode string as CBOR
>         * hash with Blake2b_256 algorithm
>       * ticker
>         
>         * encode string as CBOR
>         * hash with Blake2b_256 algorithm
>    4. hash sequence number
>       
>       * encode word (unsigned int) as CBOR
>       * hash with Blake2b_256 algorithm
> 2. Form an attestation digest:
>    
>    * concatenate, in order:
>      
>      * [ bytes of subject hash (i)
>        , bytes of property name hash (ii)
>        , bytes of property value hash (iii)
>        , bytes of sequence number hash (iv)
>        ]
> 3. Sign the attestation digest with your private key.
> 4. Create JSON object:
> 
> ```
>   { "publicKey" = public key of private key used in last step, encoded as base16
>   , "signature" = signed attestation digest created in last step, encoded as base16
>   }
> ```
> 
> 5. Add this JSON object to the list of signatures

The output of the demo js looks like:

``` console
$ node token_metadata_sign_demo.js

---

    Entry: url
    Value: https://stakepool.at
   Target: 8d4244be28d7cd0f4f7e31cf54350356cfd1e7dc83a29ee43f8d4f69696f30bb6d5ef5f5a5032e2369b92e3572318960467f674ecc01fad1158eb2c958f52107
Signature: 8d4244be28d7cd0f4f7e31cf54350356cfd1e7dc83a29ee43f8d4f69696f30bb6d5ef5f5a5032e2369b92e3572318960467f674ecc01fad1158eb2c958f52107
publicKey: ca739639a1f79ec17ba57ff9d675f86e5a33af6697e90d405691f26c088bcf75


---

    Entry: name
    Value: token registry signing test
   Target: e09f9a0dcbbc6d60f016df8c70f84f44295cd7296d96546022e4612993221d0e2024509bac90834ba6ee605022b2ff93c32ffb5ee0e93f86818a94c61476b807
Signature: e09f9a0dcbbc6d60f016df8c70f84f44295cd7296d96546022e4612993221d0e2024509bac90834ba6ee605022b2ff93c32ffb5ee0e93f86818a94c61476b807
publicKey: ca739639a1f79ec17ba57ff9d675f86e5a33af6697e90d405691f26c088bcf75


---

    Entry: ticker
    Value: TOKEN
   Target: 4ef86936745189936379009da21a5a5b2b17571aa4a153e17d76f0ceb0166afee9a417ac0e18f8b4504c4270637c3ece9cd3335150976b61395d3a4a8626e305
Signature: 4ef86936745189936379009da21a5a5b2b17571aa4a153e17d76f0ceb0166afee9a417ac0e18f8b4504c4270637c3ece9cd3335150976b61395d3a4a8626e305
publicKey: ca739639a1f79ec17ba57ff9d675f86e5a33af6697e90d405691f26c088bcf75


---

    Entry: decimals
    Value: 6
   Target: a2b7b25067fb868f59e6faf9b4f1e210eb557f2c3fab6bab2d111702ad7af17faf6bf28ba3880ab2ce4833f3f98028e32adad4d99d2338bb0f7b10e863838a0f
Signature: a2b7b25067fb868f59e6faf9b4f1e210eb557f2c3fab6bab2d111702ad7af17faf6bf28ba3880ab2ce4833f3f98028e32adad4d99d2338bb0f7b10e863838a0f
publicKey: ca739639a1f79ec17ba57ff9d675f86e5a33af6697e90d405691f26c088bcf75


---

    Entry: logo
    Value: {base64}
   Target: df66df3994301fe774d0ff0b838f3df1a19025a8e7b5d2bffafa3be0cc3d7df10ccde371ca74200df2dde3d1fbebbe5902c141afa346a9a6652f3a2e8fba2607
Signature: df66df3994301fe774d0ff0b838f3df1a19025a8e7b5d2bffafa3be0cc3d7df10ccde371ca74200df2dde3d1fbebbe5902c141afa346a9a6652f3a2e8fba2607
publicKey: ca739639a1f79ec17ba57ff9d675f86e5a33af6697e90d405691f26c088bcf75


---

    Entry: description
    Value: This is a test for the token metadata registry signing
   Target: 9dc407bcb1ed7a75e0e3f53a435390112f6501774caae9ed1f02725bad00773a619f8c10f1d3d1d189458565bf45d3f580505a4ca5752f0e73649892615f3503
Signature: 9dc407bcb1ed7a75e0e3f53a435390112f6501774caae9ed1f02725bad00773a619f8c10f1d3d1d189458565bf45d3f580505a4ca5752f0e73649892615f3503
publicKey: ca739639a1f79ec17ba57ff9d675f86e5a33af6697e90d405691f26c088bcf75


```
