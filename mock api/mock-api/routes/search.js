"use strict";

/**
 * routes/search.js
 *
 * GET /search?q=<text>
 *
 * Semantic product search powered by Pinecone integrated inference.
 * Accepts a free-text query (e.g. "something for pasta night", "gift for a chef",
 * "cast iron cookware") and returns ranked product results from the catalog.
 *
 * No auth required — public endpoint.
 *
 * Query params:
 *   q      {string}  required — the search query text
 *   topK   {number}  optional — max results to return (default 5, max 10)
 *
 * Response:
 *   { results: [ { productId, name, price, imagePath, availability, score } ] }
 */

const express = require("express");
const router = express.Router();

const { Pinecone } = require("@pinecone-database/pinecone");
const { skusMap } = require("../services/productGraph");

// Lazy-init Pinecone client so the route file can be required even if env vars
// are not set yet (e.g. during unit tests that don't exercise this route).
let _pineconeIndex = null;
function getPineconeIndex() {
  if (!_pineconeIndex) {
    const pc = new Pinecone({ apiKey: process.env.PINECONE_API_KEY });
    _pineconeIndex = pc.index(process.env.PINECONE_INDEX_NAME);
  }
  return _pineconeIndex;
}

const NAMESPACE = "ws-products";
const DEFAULT_TOP_K = 5;
const MAX_TOP_K = 10;

// ---------------------------------------------------------------------------
// GET /search
// ---------------------------------------------------------------------------

router.get("/", async (req, res, next) => {
  try {
    const query = (req.query.q || "").trim();

    if (!query) {
      return res.status(400).json({
        error: "Missing required query parameter: q",
        code: "MISSING_QUERY",
      });
    }

    // Parse and clamp topK
    let topK = parseInt(req.query.topK, 10) || DEFAULT_TOP_K;
    if (topK < 1) topK = 1;
    if (topK > MAX_TOP_K) topK = MAX_TOP_K;

    // Query Pinecone using integrated inference (text in → embeddings handled internally)
    let hits = [];
    try {
      const response = await getPineconeIndex().searchRecords({
        query: { topK, inputs: { text: query } },
        namespace: NAMESPACE,
      });
      hits = (response && response.result && response.result.hits) || [];
    } catch (err) {
      console.error("[search] Pinecone query failed:", err.message);
      // Graceful degradation — return empty results rather than a 500
      return res.json({ results: [], source: "pinecone_unavailable" });
    }

    // Attach full SKU metadata from skusMap and build response
    const results = hits
      .map((hit) => {
        const sku = skusMap.get(hit._id);
        if (!sku) return null; // guard against stale Pinecone entries
        return {
          productId: hit._id,
          name: sku.name,
          price: sku.price.sellingPrice,
          imagePath: sku.media.images[0].path,
          availability: sku.availability,
          score: hit._score,
        };
      })
      .filter(Boolean); // remove nulls

    return res.json({ results, source: "pinecone" });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
