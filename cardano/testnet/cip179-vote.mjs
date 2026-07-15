#!/usr/bin/env node

import { readFile, writeFile } from "node:fs/promises";
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
    throw new Error(`${label} must be ${bytes * 2} hexadecimal characters`);
  }
  return Uint8Array.from(Buffer.from(value, "hex"));
};

function koiosToMetadatum(value, depth = 0) {
  if (depth > 64) throw new Error("Koios metadata nesting exceeds 64 levels");
  if (value === null || typeof value === "boolean") {
    throw new Error("Koios returned a value that Cardano metadata cannot represent");
  }
  if (typeof value === "number") {
    if (!Number.isSafeInteger(value)) throw new Error("Unsafe Koios metadata integer");
    return BigInt(value);
  }
  if (typeof value === "string") {
    return /^0x(?:[0-9a-fA-F]{2})*$/.test(value)
      ? Uint8Array.from(Buffer.from(value.slice(2), "hex"))
      : value;
  }
  if (Array.isArray(value)) return value.map((item) => koiosToMetadatum(item, depth + 1));
  return new Map(
    Object.entries(value).map(([key, item]) => [
      /^-?\d+$/.test(key) ? BigInt(key) : key,
      koiosToMetadatum(item, depth + 1),
    ]),
  );
}

function detailed(value) {
  if (typeof value === "bigint") {
    if (value > BigInt(Number.MAX_SAFE_INTEGER) || value < BigInt(Number.MIN_SAFE_INTEGER)) {
      throw new Error(`cardano-cli JSON cannot safely represent integer ${value}`);
    }
    return { int: Number(value) };
  }
  if (typeof value === "string") return { string: value };
  if (value instanceof Uint8Array) return { bytes: hex(value) };
  if (Array.isArray(value)) return { list: value.map(detailed) };
  if (value instanceof Map) {
    return { map: [...value].map(([key, item]) => ({ k: detailed(key), v: detailed(item) })) };
  }
  throw new Error("Unsupported metadata value");
}

function metadataLabel(metadata, label) {
  if (Array.isArray(metadata)) {
    for (const item of metadata) {
      if (item && typeof item === "object") {
        if (Object.hasOwn(item, label)) return item[label];
        if (String(item.key ?? item.label) === label) return item.value ?? item.json;
      }
    }
    return undefined;
  }
  return metadata?.[label];
}

async function loadPackage() {
  if (Number(process.versions.node.split(".")[0]) < 20) {
    throw new Error("The optional CIP-179 voter requires Node.js 20 or newer");
  }
  try {
    return await import("cip-179");
  } catch (error) {
    throw new Error(
      `The optional CIP-179 voter needs Node.js 20+ and cip-179@0.2.0. Run 'npm install --no-save --no-package-lock cip-179@0.2.0' in the scripts directory. (${error.message})`,
    );
  }
}

async function fetchSurvey(txId, index, cip179) {
  const api = (process.env.CIP179_KOIOS_API || "https://api.koios.rest/api/v1").replace(/\/$/, "");
  const headers = { Accept: "application/json", "Content-Type": "application/json" };
  const auth = process.env.CIP179_KOIOS_AUTH || "";
  const separator = auth.indexOf(":");
  if (separator > 0) headers[auth.slice(0, separator).trim()] = auth.slice(separator + 1).trim();
  const response = await fetch(`${api}/tx_metadata?select=tx_hash,metadata`, {
    method: "POST",
    headers,
    body: JSON.stringify({ _tx_hashes: [txId] }),
    signal: AbortSignal.timeout(30_000),
  });
  if (!response.ok) throw new Error(`Koios tx_metadata request failed (${response.status})`);
  const rows = await response.json();
  const metadata = rows?.[0]?.json_metadata ?? rows?.[0]?.metadata;
  const raw = metadataLabel(metadata, "17");
  if (raw === undefined) throw new Error(`Transaction ${txId} has no metadata label 17`);
  const payload = cip179.decodePayload(koiosToMetadatum(raw));
  if (payload.type !== "definitions" || !payload.definitions[index]) {
    throw new Error(`CIP-179 survey definition ${txId}#${index} was not found`);
  }
  const survey = payload.definitions[index];
  const problems = cip179.validateDefinition(survey);
  if (problems.length) throw new Error(`Invalid survey: ${problems.join("; ")}`);
  return survey;
}

async function presentationFor(survey) {
  if (!survey.contentAnchor) return null;
  const uri = survey.contentAnchor.uri;
  const url = uri.startsWith("ipfs://") ? `https://ipfs.io/ipfs/${uri.slice(7)}` : uri;
  const response = await fetch(url, { signal: AbortSignal.timeout(30_000) });
  if (!response.ok) throw new Error(`Survey presentation request failed (${response.status})`);
  const bytes = new Uint8Array(await response.arrayBuffer());
  let blake2b;
  try {
    ({ blake2b } = await import("@noble/hashes/blake2.js"));
  } catch (error) {
    throw new Error(`Unable to verify the survey presentation hash (${error.message})`);
  }
  if (hex(blake2b(bytes, { dkLen: 32 })) !== hex(survey.contentAnchor.hash)) {
    throw new Error("Survey presentation hash does not match its content anchor");
  }
  try {
    return JSON.parse(new TextDecoder().decode(bytes));
  } catch {
    throw new Error("Survey presentation is not valid JSON");
  }
}

const optionCount = (options) =>
  options.type === "options" ? options.labels.length : options.count;

function displayQuestion(question, index, presentation) {
  const external = presentation?.questions?.[index] ?? {};
  const labels = question.options?.type === "options" ? question.options.labels : external.options;
  if (question.options && (!Array.isArray(labels) || labels.length !== optionCount(question.options) || labels.some((label) => typeof label !== "string"))) {
    throw new Error(`Question ${index + 1} is missing its externally anchored option labels`);
  }
  const prompt = question.prompt || external.prompt;
  if (typeof prompt !== "string" || !prompt) throw new Error(`Question ${index + 1} is missing its externally anchored prompt`);
  const ratingLabels =
    question.type === "rating" && question.scale.type === "labels"
      ? question.scale.labels
      : external.ratingLabels;
  if (ratingLabels !== undefined && (!Array.isArray(ratingLabels) || ratingLabels.some((label) => typeof label !== "string"))) {
    throw new Error(`Question ${index + 1} has invalid externally anchored rating labels`);
  }
  if (question.type === "rating" && question.scale.type === "count" && ratingLabels && ratingLabels.length !== question.scale.count) {
    throw new Error(`Question ${index + 1} has the wrong number of externally anchored rating labels`);
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
    return rating >= min && rating <= max && (!step || (rating - min) % step === 0n);
  }
  const count = scale.type === "count" ? scale.count : scale.labels.length;
  return rating >= 0n && rating < BigInt(count);
};

async function askQuestion(rl, question, index, view) {
  console.log(`\n${index + 1}. ${view.prompt}${question.required ? " (required)" : ""}`);
  view.labels?.forEach((label, option) => console.log(`   ${option + 1}) ${label}`));
  const abstain = question.required ? "" : " Press Enter to abstain.";
  for (;;) {
    let input;
    switch (question.type) {
      case "custom":
        throw new Error("Custom CIP-179 question methods are not supported by this CLI helper");
      case "singleChoice": {
        input = (await rl.question(`Choose one option.${abstain} `)).trim();
        if (!input && !question.required) return null;
        const selected = Number(input) - 1;
        if (Number.isInteger(selected) && selected >= 0 && selected < view.labels.length) {
          return { type: "singleChoice", questionIndex: index, optionIndex: selected };
        }
        break;
      }
      case "multiSelect": {
        input = (await rl.question(`Choose ${question.minSelections}-${question.maxSelections} options, comma-separated (use 'none' for an explicit empty selection).${abstain} `)).trim();
        if (!input && !question.required) return null;
        const selected = input.toLowerCase() === "none" ? [] : parseList(input);
        if (selected && unique(selected) && selected.every((item) => item >= 0 && item < view.labels.length) && selected.length >= question.minSelections && selected.length <= question.maxSelections) {
          return { type: "multiSelect", questionIndex: index, optionIndices: selected };
        }
        break;
      }
      case "ranking": {
        input = (await rl.question(`Rank ${question.minRanked}-${question.maxRanked} options from most to least preferred, comma-separated.${abstain} `)).trim();
        if (!input && !question.required) return null;
        const ranking = parseList(input);
        if (ranking && unique(ranking) && ranking.every((item) => item >= 0 && item < view.labels.length) && ranking.length >= question.minRanked && ranking.length <= question.maxRanked) {
          return { type: "ranking", questionIndex: index, ranking };
        }
        break;
      }
      case "numericRange": {
        const { min, max, step } = question.constraints;
        input = (await rl.question(`Enter an integer from ${min} to ${max}${step ? ` in steps of ${step}` : ""}.${abstain} `)).trim();
        if (!input && !question.required) return null;
        if (/^-?\d+$/.test(input)) {
          const value = BigInt(input);
          if (value >= min && value <= max && (!step || (value - min) % step === 0n)) {
            return { type: "numeric", questionIndex: index, value };
          }
        }
        break;
      }
      case "pointsAllocation": {
        input = (await rl.question(`Allocate exactly ${question.budget} points as option=points pairs (example: 1=5,2=5).${abstain} `)).trim();
        if (!input && !question.required) return null;
        const pairs = input.split(",").map((pair) => pair.trim().match(/^(\d+)\s*=\s*(\d+)$/));
        if (pairs.every(Boolean)) {
          const allocations = pairs.map((match) => ({ optionIndex: Number(match[1]) - 1, points: Number(match[2]) }));
          if (unique(allocations.map((item) => item.optionIndex)) && allocations.every((item) => item.optionIndex >= 0 && item.optionIndex < view.labels.length && Number.isSafeInteger(item.points)) && allocations.reduce((sum, item) => sum + BigInt(item.points), 0n) === BigInt(question.budget)) {
            return { type: "pointsAllocation", questionIndex: index, allocations };
          }
        }
        break;
      }
      case "rating": {
        const scale = question.scale;
        if (scale.type === "numeric") console.log(`   Rating scale: ${scale.constraints.min} to ${scale.constraints.max}${scale.constraints.step ? ` in steps of ${scale.constraints.step}` : ""}`);
        else if (scale.type === "count" && !view.ratingLabels) console.log(`   Rating scale: 1 to ${scale.count}`);
        else (scale.type === "labels" ? scale.labels : view.ratingLabels)?.forEach((label, rating) => console.log(`   Rating ${rating + 1}: ${label}`));
        input = (await rl.question(`Rate options as option=rating pairs.${question.requireAll ? " Every option must be rated." : ""}${abstain} `)).trim();
        if (!input && !question.required) return null;
        const pairs = input.split(",").map((pair) => pair.trim().match(/^(\d+)\s*=\s*(-?\d+)$/));
        if (pairs.every(Boolean)) {
          const ratings = pairs.map((match) => {
            let rating = BigInt(match[2]);
            if (scale.type !== "numeric") rating -= 1n;
            return { optionIndex: Number(match[1]) - 1, rating };
          });
          if (unique(ratings.map((item) => item.optionIndex)) && ratings.every((item) => item.optionIndex >= 0 && item.optionIndex < view.labels.length && ratingValid(item.rating, scale)) && (!question.requireAll || ratings.length === view.labels.length)) {
            return { type: "rating", questionIndex: index, ratings };
          }
        }
        break;
      }
    }
    console.log("That answer does not satisfy this question's constraints. Please try again.");
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
  if (!Number.isInteger(index) || index < 0 || index > 65535) throw new Error("Invalid survey index");
  if (![0, 1, 2].includes(role)) throw new Error("Only DRep, SPO, and CC voters are supported");
  if (!Number.isInteger(expiry) || expiry < 0) throw new Error("Invalid action expiry epoch");

  const cip179 = await loadPackage();
  const survey = await fetchSurvey(txId, index, cip179);
  if (survey.endEpoch !== expiry) throw new Error(`Survey ends in epoch ${survey.endEpoch}, but the action expires in epoch ${expiry}`);
  if (!survey.eligibleRoles.includes(role)) throw new Error("This survey is not open to this voter role");
  if (survey.submissionMode.type !== "public") throw new Error("Sealed CIP-179 surveys are not supported by this CLI helper");
  const presentation = await presentationFor(survey);
  const views = survey.questions.map((question, questionIndex) => displayQuestion(question, questionIndex, presentation));

  console.log(`\nCIP-179 survey: ${survey.title || presentation?.title || "Untitled survey"}`);
  if (survey.description || presentation?.description) console.log(survey.description || presentation.description);
  if (!process.stdin.isTTY) throw new Error("Interactive survey voting requires a terminal");
  const rl = createInterface({ input: process.stdin, output: process.stdout });
  try {
    const answers = [];
    for (let questionIndex = 0; questionIndex < survey.questions.length; questionIndex += 1) {
      const answer = await askQuestion(rl, survey.questions[questionIndex], questionIndex, views[questionIndex]);
      if (answer) answers.push(answer);
    }
    const confirmed = (await rl.question("\nCreate this CIP-179 survey response? (Y/n): ")).trim().toLowerCase();
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
    if (problems.length) throw new Error(`Invalid response: ${problems.join("; ")}`);
    const payload = cip179.encodePayload({ type: "responses", responses: [response] });
    await writeFile(output, `${JSON.stringify({ 17: detailed(payload) }, null, 2)}\n`, { flag: "wx" });
    console.log(`CIP-179 response metadata created: ${output}`);
  } finally {
    rl.close();
  }
}

async function merge(args) {
  if (args.length < 2) usage();
  const [output, ...inputs] = args;
  const responses = [];
  for (const input of inputs) {
    const document = JSON.parse(await readFile(input, "utf8"));
    const payload = document?.["17"]?.list;
    if (!Array.isArray(payload) || payload[0]?.int !== 1 || !Array.isArray(payload[1]?.list)) {
      throw new Error(`${input} is not CIP-179 detailed-schema response metadata`);
    }
    if (payload[1].list.length === 0) throw new Error(`${input} contains no CIP-179 responses`);
    responses.push(...payload[1].list);
  }
  await writeFile(output, `${JSON.stringify({ 17: { list: [{ int: 1 }, { list: responses }] } }, null, 2)}\n`);
}

try {
  const [command, ...args] = process.argv.slice(2);
  if (command === "respond") await respond(args);
  else if (command === "merge") await merge(args);
  else usage();
} catch (error) {
  console.error(`CIP-179: ${error.message}`);
  process.exit(1);
}
