// Offline transport fixture: synthesize native CBOR, never submit it.
import * as CSL from "@emurgo/cardano-serialization-lib-asmjs";
import { readFileSync, writeFileSync } from "node:fs";
import { parseExactJson } from "../cardano/testnet/cip179-vote.mjs";
import { koiosToMetadatum } from "./koios-fixture.mjs";
const [input, output] = process.argv.slice(2);
const rows = parseExactJson(readFileSync(input, "utf8"));
const m = koiosToMetadatum(rows[0].metadata["17"]);
const detailed = (value) =>
  typeof value === "bigint"
    ? { int: JSON.rawJSON(String(value)) }
    : typeof value === "string"
      ? { string: value }
      : value instanceof Uint8Array
        ? { bytes: Buffer.from(value).toString("hex") }
        : Array.isArray(value)
          ? { list: value.map(detailed) }
          : {
              map: [...value].map(([k, v]) => ({
                k: detailed(k),
                v: detailed(v),
              })),
            };
const metadata = CSL.GeneralTransactionMetadata.new();
metadata.insert(
  CSL.BigNum.from_str("17"),
  CSL.encode_json_str_to_metadatum(
    JSON.stringify(detailed(m)),
    CSL.MetadataJsonSchema.DetailedSchema,
  ),
);
const auxiliary = CSL.AuxiliaryData.new();
auxiliary.set_metadata(metadata);
const old = CSL.Transaction.from_hex(
  readFileSync(
    new URL("./fixtures/native-base.hex", import.meta.url),
    "utf8",
  ).trim(),
);
const body = old.body();
body.set_auxiliary_data_hash(CSL.hash_auxiliary_data(auxiliary));
const tx = CSL.Transaction.new(
  body,
  CSL.TransactionWitnessSet.new(),
  auxiliary,
);
const hash = CSL.FixedTransaction.from_hex(tx.to_hex())
  .transaction_hash()
  .to_hex();
writeFileSync(output, JSON.stringify([{ tx_hash: hash, cbor: tx.to_hex() }]));
process.stdout.write(hash);
