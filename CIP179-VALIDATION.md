# CIP-179 public-response validation

Install the locked graph with `npm ci` under Node 22.12 or newer. Run:

```sh
npm run test:cip179
python3 test/cip179_cli_test.py
```

The three Node tests and 21 Python cases exercise the real helper, six built-in
question types, omitted versus explicitly empty answers, full int64 values,
terminal escaping, cancellation, exclusive output creation, merge validation,
voter/survey binding, and the host scripts' anchor and CIP-20 message blocks.
Python tests need Bash, jq and a Unix PTY. All generated fixtures stay in ignored
`.test-artifacts/`. Provider responses and node operations are simulated.

Both network helpers decode `/tx_cbor` using native ledger types and check the
transaction ID and auxiliary-data hash. A sidecar contains label 17 and a local
`_cip179.definitionCbor` binding. `verify` checks it against the VoteFile's saved
survey and voter, and `merge` revalidates answers against the embedded definition.
Only label 17 is emitted into transaction metadata. Existing unbound sidecars
must be regenerated. Existing output files are never overwritten.

The CLI supports public key-credential DRep, SPO and CC responses to built-in
questions. It does not independently establish owner proof, cancellation,
registration or finalization. Native metadata integrity is not a substitute for
those checks. Custom and sealed responses are unsupported. The existing voting
workflow supplies the governance vote needed for mechanism B; offline tests do
not demonstrate ledger acceptance, hardware-wallet support or live Koios support.

CIP-169 deposit/return-account checks apply when that extension is present in a
linked anchor. A CIP-108/CIP-179 link without CIP-169 remains valid input.
