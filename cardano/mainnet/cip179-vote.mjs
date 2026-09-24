#!/usr/bin/env node

import { readFile, writeFile, link, unlink } from "node:fs/promises";
import { randomUUID } from "node:crypto";
import { dirname, join, resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { createInterface } from "node:readline/promises";

const usage = () => {
  console.error(
    "Usage: cip179-vote.mjs respond <tx-id> <index> <role> <credential-hex> <expiry-epoch> <output.json> | merge <output.json> <response.json>...",
  );
  process.exit(2);
};

const hex = (bytes) => Buffer.from(bytes).toString("hex");
const fromHex = (value, bytes, label) => {
  if (!new RegExp(`^[0-9a-fA-F]{${bytes * 2}}$`).test(value)) {
    throw new Error(
      `${terminalText(label)} must be ${bytes * 2} hexadecimal characters`,
    );
  }
  return Uint8Array.from(Buffer.from(value, "hex"));
};

function detailed(value) {
  if (typeof value === "bigint") {
    return { int: value };
  }
  if (typeof value === "string") return { string: value };
  if (value instanceof Uint8Array) return { bytes: hex(value) };
  if (Array.isArray(value)) return { list: value.map(detailed) };
  if (value instanceof Map) {
    return {
      map: [...value].map(([key, item]) => ({
        k: detailed(key),
        v: detailed(item),
      })),
    };
  }
  throw new Error("Unsupported metadata value");
}

// Node's source-aware JSON reviver preserves ledger integers without rounding.
export function parseExactJson(text) {
  return JSON.parse(text, (_key, value, context) => {
    if (typeof value !== "number") return value;
    if (!Number.isFinite(value) || !/^-?\d+$/.test(context.source))
      throw new Error("Metadata integers must be decimal integers");
    return Number.isSafeInteger(value) ? value : BigInt(context.source);
  });
}
const stringifyExact = (value) =>
  JSON.stringify(
    value,
    (_key, item) =>
      typeof item === "bigint" ? JSON.rawJSON(String(item)) : item,
    2,
  );

export const terminalText = (value) =>
  String(value).replace(
    /[\u0000-\u001f\u007f-\u009f\u202a-\u202e\u2066-\u2069]/g,
    (char) => `\\u${char.codePointAt(0).toString(16).padStart(4, "0")}`,
  );

async function writeExclusive(output, content) {
  const temporary = join(dirname(resolve(output)), `.cip179-${randomUUID()}`);
  try {
    await writeFile(temporary, content, { flag: "wx", mode: 0o600 });
    await link(temporary, output);
  } finally {
    await unlink(temporary).catch(() => {});
  }
}

async function boundedBytes(response, limit = 1_048_576) {
  if (!response.ok) throw new Error(`HTTP ${response.status}`);
  if (Number(response.headers.get("content-length")) > limit)
    throw new Error("Response too large");
  const reader = response.body?.getReader();
  if (!reader) throw new Error("Empty response body");
  const chunks = [];
  let length = 0;
  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      length += value.length;
      if (length > limit) throw new Error("Response too large");
      chunks.push(value);
    }
    return Buffer.concat(chunks, length);
  } finally {
    await reader.cancel();
  }
}

async function loadPackage() {
  const [major, minor] = process.versions.node.split(".").map(Number);
  if (major < 22 || (major === 22 && minor < 12))
    throw new Error(
      "The optional CIP-179 voter requires Node.js 22.12 or newer",
    );
  try {
    return await import("cip-179");
  } catch {
    throw new Error(
      "Install the optional helper dependencies with npm ci in this checkout's root (Node.js 22.12+)",
    );
  }
}

export async function decodeSurveyNative(cbor, txId) {
  const CSL = await import("@emurgo/cardano-serialization-lib-asmjs");
  const { blake2b } = await import("@noble/hashes/blake2.js");
  if (
    typeof cbor !== "string" ||
    !/^(?:[a-fA-F0-9]{2})+$/.test(cbor) ||
    cbor.length > 131072
  )
    throw new Error("Native transaction CBOR is missing or invalid");
  const tx = CSL.FixedTransaction.from_hex(cbor);
  if (!tx.is_valid() || tx.transaction_hash().to_hex() !== txId)
    throw new Error("Native transaction does not match the survey reference");
  const raw = tx.raw_auxiliary_data();
  if (
    !raw ||
    hex(blake2b(raw, { dkLen: 32 })) !==
      tx.body().auxiliary_data_hash()?.to_hex()
  )
    throw new Error("Native metadata hash mismatch");
  const metadata = tx
    .auxiliary_data()
    ?.metadata()
    ?.get(CSL.BigNum.from_str("17"));
  if (!metadata) throw new Error("Transaction has no metadata label 17");
  const decode = (value, depth = 0) => {
    if (depth > 64) throw new Error("Native metadata is too deeply nested");
    switch (value.kind()) {
      case CSL.TransactionMetadatumKind.Int:
        return BigInt(value.as_int().to_str());
      case CSL.TransactionMetadatumKind.Text:
        return value.as_text();
      case CSL.TransactionMetadatumKind.Bytes:
        return value.as_bytes();
      case CSL.TransactionMetadatumKind.MetadataList: {
        const list = value.as_list();
        return Array.from({ length: list.len() }, (_, i) =>
          decode(list.get(i), depth + 1),
        );
      }
      case CSL.TransactionMetadatumKind.MetadataMap: {
        const map = value.as_map(),
          keys = map.keys();
        return new Map(
          Array.from({ length: keys.len() }, (_, i) => [
            decode(keys.get(i), depth + 1),
            decode(map.get(keys.get(i)), depth + 1),
          ]),
        );
      }
      default:
        throw new Error("Unknown native metadata type");
    }
  };
  return decode(metadata);
}

async function fetchSurvey(txId, index, cip179) {
  const api = (
    process.env.CIP179_KOIOS_API || "https://api.koios.rest/api/v1"
  ).replace(/\/$/, "");
  const headers = {
    Accept: "application/json",
    "Content-Type": "application/json",
  };
  const auth = process.env.CIP179_KOIOS_AUTH || "";
  const separator = auth.indexOf(":");
  if (separator > 0)
    headers[auth.slice(0, separator).trim()] = auth.slice(separator + 1).trim();
  const response = await fetch(`${api}/tx_cbor`, {
    method: "POST",
    headers,
    body: JSON.stringify({ _tx_hashes: [txId] }),
    signal: AbortSignal.timeout(30_000),
  });
  const rows = JSON.parse((await boundedBytes(response)).toString("utf8"));
  const row = rows.find((item) => item.tx_hash === txId);
  const payload = cip179.decodePayload(
    await decodeSurveyNative(row?.cbor, txId),
  );
  if (payload.type !== "definitions" || !payload.definitions[index])
    throw new Error(`Survey definition ${txId}#${index} was not found`);
  const survey = payload.definitions[index];
  const problems = cip179.validateDefinition(survey);
  if (problems.length)
    throw new Error(`Invalid survey: ${problems.join("; ")}`);
  return { survey, definitionCbor: row.cbor };
}

async function presentationFor(survey) {
  if (!survey.contentAnchor) return null;
  const uri = survey.contentAnchor.uri;
  const url = uri.startsWith("ipfs://")
    ? `https://ipfs.io/ipfs/${uri.slice(7)}`
    : uri;
  if (!url.startsWith("https://"))
    throw new Error("Only HTTPS/IPFS presentations are supported");
  const response = await fetch(url, { signal: AbortSignal.timeout(30_000) });
  if (!response.ok)
    throw new Error(`Survey presentation request failed (${response.status})`);
  const bytes = new Uint8Array(await boundedBytes(response));
  let blake2b;
  try {
    ({ blake2b } = await import("@noble/hashes/blake2.js"));
  } catch (error) {
    throw new Error(
      `Unable to verify the survey presentation hash (${error.message})`,
    );
  }
  if (hex(blake2b(bytes, { dkLen: 32 })) !== hex(survey.contentAnchor.hash)) {
    throw new Error(
      "Survey presentation hash does not match its content anchor",
    );
  }
  try {
    const document = JSON.parse(
      new TextDecoder("utf-8", { fatal: true }).decode(bytes),
    );
    if (
      document?.specVersion !== 5 ||
      document?.kind !== "cardano-survey-presentation"
    )
      throw new Error("Not a v5 presentation");
    return document;
  } catch {
    throw new Error("Survey presentation is not valid JSON");
  }
}

const optionCount = (options) =>
  options.type === "options" ? options.labels.length : options.count;

function displayQuestion(question, index, presentation) {
  const external = presentation?.questions?.[index] ?? {};
  const labels =
    question.options?.type === "options"
      ? question.options.labels
      : external.options;
  if (
    question.options &&
    (!Array.isArray(labels) ||
      labels.length !== optionCount(question.options) ||
      labels.some((label) => typeof label !== "string"))
  ) {
    throw new Error(
      `Question ${index + 1} is missing its externally anchored option labels`,
    );
  }
  const prompt = question.prompt || external.prompt;
  if (typeof prompt !== "string" || !prompt)
    throw new Error(
      `Question ${index + 1} is missing its externally anchored prompt`,
    );
  const ratingLabels =
    question.type === "rating" && question.scale.type === "labels"
      ? question.scale.labels
      : external.ratingLabels;
  if (
    ratingLabels !== undefined &&
    (!Array.isArray(ratingLabels) ||
      ratingLabels.some((label) => typeof label !== "string"))
  ) {
    throw new Error(
      `Question ${index + 1} has invalid externally anchored rating labels`,
    );
  }
  if (
    question.type === "rating" &&
    question.scale.type === "count" &&
    ratingLabels &&
    ratingLabels.length !== question.scale.count
  ) {
    throw new Error(
      `Question ${index + 1} has the wrong number of externally anchored rating labels`,
    );
  }
  return { prompt, labels, ratingLabels };
}

const unique = (values) => new Set(values).size === values.length;
const parseList = (input) => {
  if (!/^\d+(\s*,\s*\d+)*$/.test(input)) return null;
  return input.split(",").map((value) => Number(value.trim()) - 1);
};
const ratingValid = (rating, scale) => {
  if (scale.type === "numeric") {
    const { min, max, step } = scale.constraints;
    return (
      rating >= min && rating <= max && (!step || (rating - min) % step === 0n)
    );
  }
  const count = scale.type === "count" ? scale.count : scale.labels.length;
  return rating >= 0n && rating < BigInt(count);
};

async function askQuestion(rl, question, index, view) {
  console.log(
    `\n${index + 1}. ${terminalText(view.prompt)}${question.required ? " (required)" : ""}`,
  );
  view.labels?.forEach((label, option) =>
    console.log(`   ${option + 1}) ${terminalText(label)}`),
  );
  const abstain = question.required ? "" : " Press Enter to abstain.";
  for (;;) {
    let input;
    switch (question.type) {
      case "custom":
        throw new Error(
          "Custom CIP-179 question methods are not supported by this CLI helper",
        );
      case "singleChoice": {
        input = (await rl.question(`Choose one option.${abstain} `)).trim();
        if (!input && !question.required) return null;
        const selected = Number(input) - 1;
        if (
          Number.isInteger(selected) &&
          selected >= 0 &&
          selected < view.labels.length
        ) {
          return {
            type: "singleChoice",
            questionIndex: index,
            optionIndex: selected,
          };
        }
        break;
      }
      case "multiSelect": {
        input = (
          await rl.question(
            `Choose ${question.minSelections}-${question.maxSelections} options, comma-separated (use 'none' for an explicit empty selection).${abstain} `,
          )
        ).trim();
        if (!input && !question.required) return null;
        const selected = input.toLowerCase() === "none" ? [] : parseList(input);
        if (
          selected &&
          unique(selected) &&
          selected.every((item) => item >= 0 && item < view.labels.length) &&
          selected.length >= question.minSelections &&
          selected.length <= question.maxSelections
        ) {
          return {
            type: "multiSelect",
            questionIndex: index,
            optionIndices: selected,
          };
        }
        break;
      }
      case "ranking": {
        input = (
          await rl.question(
            `Rank ${question.minRanked}-${question.maxRanked} options from most to least preferred, comma-separated.${abstain} `,
          )
        ).trim();
        if (!input && !question.required) return null;
        const ranking = parseList(input);
        if (
          ranking &&
          unique(ranking) &&
          ranking.every((item) => item >= 0 && item < view.labels.length) &&
          ranking.length >= question.minRanked &&
          ranking.length <= question.maxRanked
        ) {
          return { type: "ranking", questionIndex: index, ranking };
        }
        break;
      }
      case "numericRange": {
        const { min, max, step } = question.constraints;
        input = (
          await rl.question(
            `Enter an integer from ${min} to ${max}${step ? ` in steps of ${step}` : ""}.${abstain} `,
          )
        ).trim();
        if (!input && !question.required) return null;
        if (/^-?\d+$/.test(input)) {
          const value = BigInt(input);
          if (
            value >= min &&
            value <= max &&
            (!step || (value - min) % step === 0n)
          ) {
            return { type: "numeric", questionIndex: index, value };
          }
        }
        break;
      }
      case "pointsAllocation": {
        input = (
          await rl.question(
            `Allocate exactly ${question.budget} points as option=points pairs (example: 1=5,2=5).${abstain} `,
          )
        ).trim();
        if (!input && !question.required) return null;
        const pairs = input
          .split(",")
          .map((pair) => pair.trim().match(/^(\d+)\s*=\s*(\d+)$/));
        if (pairs.every(Boolean)) {
          const allocations = pairs.map((match) => ({
            optionIndex: Number(match[1]) - 1,
            points: Number(match[2]),
          }));
          if (
            unique(allocations.map((item) => item.optionIndex)) &&
            allocations.every(
              (item) =>
                item.optionIndex >= 0 &&
                item.optionIndex < view.labels.length &&
                Number.isSafeInteger(item.points),
            ) &&
            allocations.reduce((sum, item) => sum + BigInt(item.points), 0n) ===
              BigInt(question.budget)
          ) {
            return {
              type: "pointsAllocation",
              questionIndex: index,
              allocations,
            };
          }
        }
        break;
      }
      case "rating": {
        const scale = question.scale;
        if (scale.type === "numeric")
          console.log(
            `   Rating scale: ${scale.constraints.min} to ${scale.constraints.max}${scale.constraints.step ? ` in steps of ${scale.constraints.step}` : ""}`,
          );
        else if (scale.type === "count" && !view.ratingLabels)
          console.log(`   Rating scale: 1 to ${scale.count}`);
        else
          (scale.type === "labels" ? scale.labels : view.ratingLabels)?.forEach(
            (label, rating) =>
              console.log(`   Rating ${rating + 1}: ${terminalText(label)}`),
          );
        input = (
          await rl.question(
            `Rate options as option=rating pairs.${question.requireAll ? " Every option must be rated." : ""}${abstain} `,
          )
        ).trim();
        if (!input && !question.required) return null;
        const pairs = input
          .split(",")
          .map((pair) => pair.trim().match(/^(\d+)\s*=\s*(-?\d+)$/));
        if (pairs.every(Boolean)) {
          const ratings = pairs.map((match) => {
            let rating = BigInt(match[2]);
            if (scale.type !== "numeric") rating -= 1n;
            return { optionIndex: Number(match[1]) - 1, rating };
          });
          if (
            unique(ratings.map((item) => item.optionIndex)) &&
            ratings.every(
              (item) =>
                item.optionIndex >= 0 &&
                item.optionIndex < view.labels.length &&
                ratingValid(item.rating, scale),
            ) &&
            (!question.requireAll || ratings.length === view.labels.length)
          ) {
            return { type: "rating", questionIndex: index, ratings };
          }
        }
        break;
      }
    }
    console.log(
      "That answer does not satisfy this question's constraints. Please try again.",
    );
  }
}

async function respond(args) {
  if (args.length !== 6) usage();
  const [txIdRaw, indexRaw, roleRaw, credentialRaw, expiryRaw, output] = args;
  const txId = txIdRaw.toLowerCase();
  const surveyTxId = fromHex(txId, 32, "Survey transaction id");
  const credential = fromHex(credentialRaw, 28, "Voter credential");
  const index = Number(indexRaw);
  const role = Number(roleRaw);
  const expiry = Number(expiryRaw);
  if (!Number.isInteger(index) || index < 0 || index > 65535)
    throw new Error("Invalid survey index");
  if (![0, 1, 2].includes(role))
    throw new Error("Only DRep, SPO, and CC voters are supported");
  if (!Number.isInteger(expiry) || expiry < 0)
    throw new Error("Invalid action expiry epoch");

  const cip179 = await loadPackage();
  const { survey, definitionCbor } = await fetchSurvey(txId, index, cip179);
  if (survey.endEpoch !== expiry)
    throw new Error(
      `Survey ends in epoch ${survey.endEpoch}, but the action expires in epoch ${expiry}`,
    );
  if (!survey.eligibleRoles.includes(role))
    throw new Error("This survey is not open to this voter role");
  if (survey.submissionMode.type !== "public")
    throw new Error(
      "Sealed CIP-179 surveys are not supported by this CLI helper",
    );
  const presentation = await presentationFor(survey);
  if (
    survey.questions.length > 100 ||
    survey.questions.some((q) => q.options && optionCount(q.options) > 100)
  )
    throw new Error("This CLI supports at most 100 questions/options");
  console.log(
    "Survey shape checked. Owner proof, cancellation and role registration require independent chain validation.",
  );
  const views = survey.questions.map((question, questionIndex) =>
    displayQuestion(question, questionIndex, presentation),
  );

  console.log(
    `\nCIP-179 survey: ${terminalText(survey.title || presentation?.title || "Untitled survey")}`,
  );
  if (survey.description || presentation?.description)
    console.log(terminalText(survey.description || presentation.description));
  if (!process.stdin.isTTY)
    throw new Error("Interactive survey voting requires a terminal");
  const rl = createInterface({ input: process.stdin, output: process.stdout });
  try {
    const answers = [];
    for (
      let questionIndex = 0;
      questionIndex < survey.questions.length;
      questionIndex += 1
    ) {
      const answer = await askQuestion(
        rl,
        survey.questions[questionIndex],
        questionIndex,
        views[questionIndex],
      );
      if (answer) answers.push(answer);
    }
    if (answers.length === 0) {
      console.log("Survey response skipped: no questions answered.");
      process.exitCode = 10;
      return;
    }
    const confirmed = (
      await rl.question("\nCreate this CIP-179 survey response? (Y/n): ")
    )
      .trim()
      .toLowerCase();
    if (confirmed.startsWith("n")) {
      console.log("Survey response skipped.");
      process.exitCode = 10;
      return;
    }
    const response = {
      specVersion: cip179.SPEC_VERSION,
      surveyRef: { txId: surveyTxId, index },
      role,
      credential: { type: "key", keyHash: credential },
      answers: { type: "public", answers },
    };
    const problems = cip179.validateResponse(survey, response);
    if (problems.length)
      throw new Error(`Invalid response: ${problems.join("; ")}`);
    const payload = cip179.encodePayload({
      type: "responses",
      responses: [response],
    });
    await writeExclusive(
      output,
      `${stringifyExact({ 17: detailed(payload), _cip179: { definitionCbor } })}\n`,
    );
    console.log(`CIP-179 response metadata created: ${output}`);
  } finally {
    rl.close();
  }
}

export function fromDetailed(value, depth = 0) {
  if (
    depth > 64 ||
    !value ||
    typeof value !== "object" ||
    Array.isArray(value) ||
    Object.keys(value).length !== 1
  )
    throw new Error("Invalid detailed metadata");
  if (Object.hasOwn(value, "int")) {
    if (typeof value.int !== "bigint" && !Number.isSafeInteger(value.int))
      throw new Error("Invalid integer");
    const n = BigInt(value.int);
    if (n < -18446744073709551616n || n > 18446744073709551615n)
      throw new Error("Integer exceeds ledger range");
    return n;
  }
  if (typeof value.string === "string" && Buffer.byteLength(value.string) <= 64)
    return value.string;
  if (
    typeof value.bytes === "string" &&
    /^(?:[a-fA-F0-9]{2}){0,64}$/.test(value.bytes)
  )
    return Buffer.from(value.bytes, "hex");
  if (Array.isArray(value.list))
    return value.list.map((v) => fromDetailed(v, depth + 1));
  if (Array.isArray(value.map))
    return new Map(
      value.map.map((p) => {
        if (!p || Object.keys(p).sort().join() !== "k,v")
          throw new Error("Invalid map pair");
        return [fromDetailed(p.k, depth + 1), fromDetailed(p.v, depth + 1)];
      }),
    );
  throw new Error("Invalid detailed metadata value");
}

async function readResponses(input, cip179) {
  const text = await readFile(input, "utf8");
  if (Buffer.byteLength(text) > 1_048_576) throw new Error("Sidecar too large");
  const document = parseExactJson(text);
  if (
    !document ||
    Object.keys(document).some((key) => !["17", "_cip179"].includes(key)) ||
    typeof document._cip179?.definitionCbor !== "string"
  )
    throw new Error(
      "A bound response sidecar with native definition CBOR is required; regenerate the response",
    );
  const payload = cip179.decodePayload(fromDetailed(document["17"]));
  if (payload.type !== "responses" || payload.responses.length === 0)
    throw new Error("Expected nonempty response metadata");
  for (const response of payload.responses) {
    if (
      response.specVersion !== 5 ||
      ![0, 1, 2].includes(response.role) ||
      response.credential.type !== "key" ||
      response.answers.type !== "public" ||
      response.answers.answers.length === 0
    )
      throw new Error("Unsupported or empty response sidecar");
    const definitions = cip179.decodePayload(
      await decodeSurveyNative(
        document._cip179.definitionCbor,
        hex(response.surveyRef.txId),
      ),
    );
    const survey =
      definitions.type === "definitions"
        ? definitions.definitions[response.surveyRef.index]
        : null;
    if (!survey) throw new Error("Sidecar definition reference does not exist");
    const problems = [
      ...cip179.validateDefinition(survey),
      ...cip179.validateResponse(survey, response),
    ];
    if (problems.length)
      throw new Error(`Invalid sidecar response: ${problems.join("; ")}`);
  }
  return payload.responses;
}

async function verify(args) {
  if (args.length !== 5) usage();
  const [input, role, credential, txId, index] = args;
  const responses = await readResponses(input, await loadPackage());
  if (
    responses.length !== 1 ||
    responses.some(
      (r) =>
        r.role !== Number(role) ||
        hex(r.credential.keyHash) !== credential.toLowerCase() ||
        hex(r.surveyRef.txId) !== txId.toLowerCase() ||
        String(r.surveyRef.index) !== index,
    )
  )
    throw new Error(
      "Sidecar does not match the vote's recorded survey, role and credential; regenerate the vote",
    );
}

async function merge(args) {
  if (args.length < 2) usage();
  const [output, ...inputs] = args;
  const cip179 = await loadPackage();
  const responses = [];
  for (const input of inputs)
    responses.push(...(await readResponses(input, cip179)));
  const payload = cip179.encodePayload({ type: "responses", responses });
  await writeExclusive(
    output,
    `${stringifyExact({ 17: detailed(payload) })}\n`,
  );
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  try {
    const [command, ...args] = process.argv.slice(2);
    if (command === "respond") await respond(args);
    else if (command === "merge") await merge(args);
    else if (command === "verify") await verify(args);
    else usage();
  } catch (error) {
    console.error(`CIP-179: ${terminalText(error.message)}`);
    process.exitCode = 1;
  }
}
