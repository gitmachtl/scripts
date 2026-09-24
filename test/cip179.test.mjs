import test from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, readFile, writeFile, rm } from "node:fs/promises";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import {
  parseExactJson,
  fromDetailed,
  terminalText,
} from "../cardano/testnet/cip179-vote.mjs";
import { encodePayload } from "cip-179";

test("integer boundaries remain exact through parsing and detailed conversion", () => {
  const value = parseExactJson('{"int":9223372036854775807}');
  assert.equal(value.int, 9223372036854775807n);
  assert.equal(fromDetailed(value), 9223372036854775807n);
  assert.throws(() => fromDetailed({ int: 18446744073709551616n }));
  assert.throws(() => fromDetailed({ int: 1, string: "bad" }));
  assert.throws(() => fromDetailed({ bytes: "xx" }));
});
test("external terminal escapes and bidirectional controls are made visible", () => {
  assert.equal(terminalText("\x1b[2J\u202eTitle"), "\\u001b[2J\\u202eTitle");
});
const detailed = (value) =>
  typeof value === "bigint"
    ? { int: Number(value) }
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
test("merge rejects malformed entries and checks the intended vote binding without overwriting outputs", async () => {
  const dir = await mkdtemp(
    join(process.env.TMPDIR ?? ".test-artifacts", "cip179-"),
  );
  try {
    const input = join(dir, "response.json"),
      out = join(dir, "merged.json");
    const fixturePath = join(dir, "native.json");
    const built = spawnSync(
      process.execPath,
      ["test/native-fixture.mjs", "test/fixtures/cli-single.json", fixturePath],
      {
        encoding: "utf8",
        env: { ...process.env, NODE_TEST_CONTEXT: undefined },
      },
    );
    assert.equal(built.status, 0, built.stderr);
    const txId = built.stdout;
    const native = JSON.parse(await readFile(fixturePath, "utf8"))[0];
    const response = {
      specVersion: 5,
      surveyRef: { txId: Buffer.from(txId, "hex"), index: 0 },
      role: 0,
      credential: { type: "key", keyHash: new Uint8Array(28).fill(0x22) },
      answers: {
        type: "public",
        answers: [{ type: "singleChoice", questionIndex: 0, optionIndex: 1 }],
      },
    };
    const sidecar = () =>
      JSON.stringify({
        17: detailed(
          encodePayload({ type: "responses", responses: [response] }),
        ),
        _cip179: { definitionCbor: native.cbor },
      });
    await writeFile(input, sidecar());
    const run = (...args) =>
      spawnSync(
        process.execPath,
        ["cardano/testnet/cip179-vote.mjs", ...args],
        {
          encoding: "utf8",
          env: { ...process.env, NODE_TEST_CONTEXT: undefined },
        },
      );
    const verified = run("verify", input, "0", "22".repeat(28), txId, "0");
    assert.equal(verified.status, 0, JSON.stringify(verified));
    assert.notEqual(
      run("verify", input, "1", "22".repeat(28), txId, "0").status,
      0,
    );
    assert.notEqual(
      run("verify", input, "0", "33".repeat(28), txId, "0").status,
      0,
    );
    assert.notEqual(
      run("verify", input, "0", "22".repeat(28), txId, "1").status,
      0,
    );
    assert.equal(run("merge", out, input).status, 0);
    const saved = await readFile(out, "utf8");
    assert.notEqual(run("merge", out, input).status, 0);
    assert.equal(await readFile(out, "utf8"), saved);
    response.answers.answers[0].optionIndex = 99;
    await writeFile(input, sidecar());
    assert.notEqual(
      run("merge", join(dir, "bad-option.json"), input).status,
      0,
    );
    await writeFile(input, '{"17":{"list":[{"int":1},{"list":[{"int":42}]}]}}');
    assert.notEqual(run("merge", join(dir, "bad.json"), input).status, 0);
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});
