export function koiosToMetadatum(value, depth = 0) {
  if (depth > 64) throw new Error("Koios metadata nesting exceeds 64 levels");
  if (value === null || typeof value === "boolean") {
    throw new Error(
      "Koios returned a value that Cardano metadata cannot represent",
    );
  }
  if (typeof value === "bigint") return value;
  if (typeof value === "number") {
    if (!Number.isSafeInteger(value))
      throw new Error("Unsafe Koios metadata integer");
    return BigInt(value);
  }
  if (typeof value === "string") {
    return /^0x(?:[0-9a-fA-F]{2})*$/.test(value)
      ? Uint8Array.from(Buffer.from(value.slice(2), "hex"))
      : value;
  }
  if (Array.isArray(value))
    return value.map((item) => koiosToMetadatum(item, depth + 1));
  return new Map(
    Object.entries(value).map(([key, item]) => [
      /^-?\d+$/.test(key) ? BigInt(key) : key,
      koiosToMetadatum(item, depth + 1),
    ]),
  );
}
