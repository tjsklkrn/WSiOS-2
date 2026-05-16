"use strict";

/**
 * services/pineconeService.js
 *
 * Pinecone vector search service using integrated inference (text-based queries).
 * The Pinecone index is configured with a built-in embedding model so the server
 * never calls an external AI API — raw text is sent and Pinecone handles embedding
 * internally.
 *
 * Exports:
 *   buildEmbeddingText(sku)       — builds the canonical text string for a SKU
 *   queryForCart(cartProductIds)  — queries Pinecone for each cart product and
 *                                   returns merged recommendation candidates
 *
 * Requirements: 7.2, 7.3, 7.4, 7.5
 */

const { Pinecone } = require("@pinecone-database/pinecone");
const { skusMap, parseArrayString } = require("./productGraph");

// ---------------------------------------------------------------------------
// 1. Pinecone client initialization
// ---------------------------------------------------------------------------

const pc = new Pinecone({ apiKey: process.env.PINECONE_API_KEY });
const pineconeIndex = pc.index(process.env.PINECONE_INDEX_NAME);

const NAMESPACE = "ws-products";

// ---------------------------------------------------------------------------
// 2. buildEmbeddingText — canonical text representation of a SKU
// ---------------------------------------------------------------------------

/**
 * Builds the embedding text string for a SKU using the same format as the
 * seed script so that query vectors are comparable to stored vectors.
 *
 * Format:
 *   "{name} | brand: {brand} | productType: {productType} | material: {material} | collection: {collection}"
 *
 * Array-valued properties (e.g. "[he-pantry, he-fridge]") are joined with
 * spaces after parsing (e.g. "he-pantry he-fridge").
 *
 * @param {object} sku — a SKU object from skus.json
 * @returns {string}
 */
function buildEmbeddingText(sku) {
  const brand = parseArrayString(sku.properties.brand).join(" ");
  const productType = parseArrayString(sku.properties.productType).join(" ");
  const material = parseArrayString(sku.properties.material).join(" ");
  const collection = parseArrayString(sku.properties.collection).join(" ");

  return `${sku.name} | brand: ${brand} | productType: ${productType} | material: ${material} | collection: ${collection}`;
}

// ---------------------------------------------------------------------------
// 3. queryForCart — fan-out query across all cart products
// ---------------------------------------------------------------------------

/**
 * Queries Pinecone for each product in the cart using integrated inference
 * (text-based query — no external embedding API required).
 *
 * For each productId:
 *   1. Look up the SKU in skusMap; skip with a warning if not found.
 *   2. Build the embedding text string.
 *   3. Call pineconeIndex.searchRecords with the text query.
 *   4. Collect hits, excluding the queried product itself (self-exclusion).
 *
 * @param {Set<string>|string[]} cartProductIds — product IDs currently in the cart
 * @returns {Promise<Array<{ productId: string, score: number, source: "pinecone" }>>}
 */
async function queryForCart(cartProductIds) {
  const results = [];

  for (const productId of cartProductIds) {
    const sku = skusMap.get(productId);
    if (!sku) {
      console.warn(`[pineconeService] No SKU found for productId: ${productId} — skipping`);
      continue;
    }

    const queryText = buildEmbeddingText(sku);

    let response;
    try {
      response = await pineconeIndex.searchRecords({
        query: { inputs: { text: queryText }, topK: 10 },
        namespace: NAMESPACE,
      });
    } catch (err) {
      console.error(`[pineconeService] Pinecone query failed for productId ${productId}:`, err.message);
      continue;
    }

    const hits = (response && response.result && response.result.hits) || [];
    for (const hit of hits) {
      if (hit._id !== productId) {
        results.push({ productId: hit._id, score: hit._score, source: "pinecone" });
      }
    }
  }

  return results;
}

// ---------------------------------------------------------------------------
// Exports
// ---------------------------------------------------------------------------

module.exports = {
  buildEmbeddingText,
  queryForCart,
};
