const fs = require("fs");
const blake2 = require('blake2');
const cbor = require("cbor");
const CardanoWasm = require("@emurgo/cardano-serialization-lib-nodejs")

//Use the secretKey from the test.policy.skey file
const skey_json = JSON.parse(fs.readFileSync("./test.policy.skey"));
const secretKey = skey_json.cborHex.substring(4); //cut off the leading "5820" from the cborHex
const pk = CardanoWasm.PrivateKey.from_normal_bytes(Buffer.from(secretKey, "hex"));


async function main() {

    //Use the demo json file for comparision
    const data = JSON.parse(fs.readFileSync("./4dbf3aed7353c0901ee73b6deaef027c9f75a5f102c6346727cfe826746f6b656e72656774657374.json"));

    //1. Generate the Hash for the subject itself
    const subjectHash = cborAndHash(data.subject);

    for (var itemKey in data) {

        if (itemKey == "subject" || itemKey == "policy") //only process for any other itemKey than subject and policy
            continue;

        const item = data[itemKey];

	console.log("\n---\n");

	//2. Generate the Hash of the property name
        const propertyNameHash = cborAndHash(itemKey);
	console.log("    Entry: " + itemKey)

	//3. Generate the Hash of the property value (decode the base64 encoded logo entry first if needed)
        if (itemKey != "logo") { var propertyValueHash = cborAndHash(item.value); console.log("    Value: " + item.value);} // not a logo
			  else { var propertyValueHash = cborAndHash(Buffer.from(item.value,'base64')); console.log("    Value: {base64}");} // entry is a base64 enc logo

	//4. Generate the Hash of the sequenceNumber (unsigned int)
        const sequenceNumberHash = cborAndHash(item.sequenceNumber);

	//5. Concate Hash 1-4 together
        const content2Hash = subjectHash + propertyNameHash + propertyValueHash + sequenceNumberHash;

	//6. Hash it again
	const finalHash =  getHash(content2Hash);

	//7. Sign the finalHash
        const signed = sign(finalHash);
	//console.log(signed);
	console.log("   Target: " + item.signatures[0].signature); //the Signature-Target to compare with
	console.log("Signature: " + signed.signature);
	console.log("publicKey: " + signed.publicKey);
	console.log();

    }
}

function cborAndHash(content) { //encodes the given content into a cbor hex string and hashes it
    const cbHex = cbor.encode(content).toString('hex')
    return getHash(cbHex)
}

function getHash(content) { //hashes a given hex-string content with blake2b_256 (digestLength 32)
    const h = blake2.createHash("blake2b", { digestLength: 32 });
    h.update(Buffer.from(content, "hex"));
    return h.digest("hex")
}

function sign(content) { //signs the given content hex-string with the secretKey(privateKey)
    const signedBytes = pk.sign(Buffer.from(content, "hex")).to_bytes();
    const signed = Buffer.from(signedBytes).toString("hex");
    return {
        "signature": signed,
        "publicKey": Buffer.from(pk.to_public().as_bytes()).toString('hex')
    }
}

main();



