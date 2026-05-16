"use strict";

// Load .env from the parent directory (mock-api root)
require("dotenv").config({ path: require("path").join(__dirname, "..", ".env") });

/**
 * scripts/seedPinecone.js
 *
 * One-time script to upsert all SKUs into Pinecone using integrated inference.
 * Pinecone handles embedding generation internally — no external AI API required.
 *
 * Usage:
 *   PINECONE_API_KEY=<key> PINECONE_INDEX_NAME=<index> node scripts/seedPinecone.js
 *
 * Requirements: 7.1, 7.5
 */

const path = require("path");
const fs = require("fs");
const { Pinecone } = require("@pinecone-database/pinecone");

// ---------------------------------------------------------------------------
// parseArrayString — same logic as productGraph.js
// ---------------------------------------------------------------------------

/**
 * Parses a SKU property value that may be encoded as a bracket-delimited
 * comma-separated string (e.g. "[he-pantry, he-fridge]") or a plain scalar
 * string (e.g. "williams-sonoma").
 *
 * Rules:
 *   - Non-string input → []
 *   - "[a, b, c]" → ["a", "b", "c"]  (split on comma, trim each element)
 *   - "scalar"    → ["scalar"]
 *
 * @param {*} value
 * @returns {string[]}
 */
function parseArrayString(value) {
  if (typeof value !== "string") return [];
  const trimmed = value.trim();
  if (trimmed.startsWith("[") && trimmed.endsWith("]")) {
    return trimmed
      .slice(1, -1)
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean);
  }
  return [trimmed];
}

// ---------------------------------------------------------------------------
// buildEmbeddingText — constructs the text string for Pinecone integrated inference
// ---------------------------------------------------------------------------

/**
 * Builds the embedding text string for a SKU.
 * Format: "{name} | brand: {brand} | productType: {productType} | material: {material} | collection: {collection}"
 * Array-valued properties are joined with spaces.
 *
 * @param {Object} sku
 * @returns {string}
 */
function buildEmbeddingText(sku) {
  const props = sku.properties || {};

  const brand = parseArrayString(props.brand).join(" ");
  const productType = parseArrayString(props.productType).join(" ");
  const material = parseArrayString(props.material).join(" ");
  const collection = parseArrayString(props.collection).join(" ");

  return `${sku.name} | brand: ${brand} | productType: ${productType} | material: ${material} | collection: ${collection}`;
}

// ---------------------------------------------------------------------------
// Main seed function
// ---------------------------------------------------------------------------

async function seed() {
  // 1. Validate environment variables
  const apiKey = process.env.PINECONE_API_KEY;
  const indexName = process.env.PINECONE_INDEX_NAME;

  if (!apiKey) {
    console.error("[seedPinecone] ERROR: PINECONE_API_KEY environment variable is not set.");
    process.exit(1);
  }
  if (!indexName) {
    console.error("[seedPinecone] ERROR: PINECONE_INDEX_NAME environment variable is not set.");
    process.exit(1);
  }

  // 2. Load skus.json
  const skusPath = path.join(__dirname, "..", "responses", "skus.json");
  let skus;
  try {
    skus = JSON.parse(fs.readFileSync(skusPath, "utf8"));
    console.log(`[seedPinecone] Loaded ${skus.length} SKUs from ${skusPath}`);
  } catch (err) {
    console.error("[seedPinecone] ERROR: Failed to load skus.json:", err.message);
    process.exit(1);
  }

  // 3. Initialize Pinecone client
  const pinecone = new Pinecone({ apiKey });
  const index = pinecone.index(indexName);
  const namespace = "ws-products";

  console.log(`[seedPinecone] Using Pinecone index: "${indexName}", namespace: "${namespace}"`);

  // 4. Build records — metadata fields must be flat (string/number/boolean)
  const records = skus.map((sku) => {
    const embeddingText = buildEmbeddingText(sku);
    const props = sku.properties || {};

    return {
      _id: sku.id,
      text: embeddingText,
      productId: sku.id,
      name: sku.name,
      productType: parseArrayString(props.productType).join(" "),
      brand: parseArrayString(props.brand).join(" "),
    };
  });

  // 5. Upsert in batches of 10
  const BATCH_SIZE = 10;
  let totalUpserted = 0;

  for (let i = 0; i < records.length; i += BATCH_SIZE) {
    const batch = records.slice(i, i + BATCH_SIZE);
    const batchNum = Math.floor(i / BATCH_SIZE) + 1;
    const totalBatches = Math.ceil(records.length / BATCH_SIZE);

    try {
      await index.namespace(namespace).upsertRecords({ records: batch });
      totalUpserted += batch.length;
      console.log(
        `[seedPinecone] ✓ Batch ${batchNum}/${totalBatches} — upserted ${batch.length} records ` +
        `(IDs: ${batch.map((r) => r.id).join(", ")})`
      );
    } catch (err) {
      console.error(
        `[seedPinecone] ✗ Batch ${batchNum}/${totalBatches} — FAILED:`,
        err.message
      );
      console.error("[seedPinecone] Batch IDs:", batch.map((r) => r.id).join(", "));
    }
  }

  console.log(`[seedPinecone] Done. ${totalUpserted}/${records.length} records upserted to namespace "${namespace}".`);
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

seed().catch((err) => {
  console.error("[seedPinecone] Unexpected error:", err);
  process.exit(1);
});
