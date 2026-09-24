import { readFileSync } from "node:fs";
globalThis.fetch = async (url) => {
  if (String(url) !== "https://fixture.invalid/tx_cbor")
    throw Error("Unexpected network request in offline test: " + url);
  return new Response(readFileSync(process.env.AUDIT_CLI_FIXTURE), {
    headers: { "Content-Type": "application/json" },
  });
};
