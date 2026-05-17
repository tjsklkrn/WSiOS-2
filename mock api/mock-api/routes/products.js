"use strict";

const express = require("express");
const router = express.Router();

const { Pinecone } = require("@pinecone-database/pinecone");
const { skusMap } = require("../services/productGraph");
const { getCoPurchaseCandidates } = require("../services/coPurchaseService");

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

/**
 * GET /products/:productId/frequently-bought
 *
 * Hybrid recommendation endpoint that fetches co-purchase relations (collaborative filtering)
 * from Firestore, and falls back to Pinecone semantic search using the product's name
 * if there is insufficient co-purchase history.
 */
router.get("/:productId/frequently-bought", async (req, res, next) => {
  try {
    const { productId } = req.params;
    
    // Resolve the current product to get its name for fallback semantic search
    const currentSku = skusMap.get(productId);
    if (!currentSku) {
      return res.status(404).json({
        error: `Product with ID ${productId} not found in catalog`,
        code: "PRODUCT_NOT_FOUND",
      });
    }

    const productName = currentSku.name;

    // 1. Fetch co-purchase candidates from Firestore
    let coPurchaseCandidates = [];
    try {
      coPurchaseCandidates = await getCoPurchaseCandidates([productId]);
    } catch (err) {
      console.warn(`[products/frequently-bought] Collaborative filtering failed:`, err.message);
    }

    // Sort by score descending
    coPurchaseCandidates.sort((a, b) => b.score - a.score);

    // Map co-purchase candidates to full product detail models
    const results = coPurchaseCandidates
      .map((c) => {
        const sku = skusMap.get(c.productId);
        if (!sku) return null;
        return {
          productId: c.productId,
          name: sku.name,
          price: sku.price.sellingPrice,
          imagePath: sku.media.images[0].path,
          availability: sku.availability,
          score: c.score,
          source: "collaborative",
        };
      })
      .filter(Boolean);

    // 2. Fallback: If we have fewer than 3 recommendations, query Pinecone using semantic search
    if (results.length < 3) {
      const neededCount = 5 - results.length;
      let hits = [];
      try {
        const response = await getPineconeIndex().searchRecords({
          query: { topK: 10, inputs: { text: productName } },
          namespace: NAMESPACE,
        });
        hits = (response && response.result && response.result.hits) || [];
      } catch (err) {
        console.error("[products/frequently-bought] Fallback Pinecone query failed:", err.message);
      }

      // Add semantic hits to recommendations
      for (const hit of hits) {
        if (results.length >= 5) break;

        // Don't recommend the target product itself
        if (hit._id === productId) continue;

        // Skip duplicates (products already in results)
        if (results.some((r) => r.productId === hit._id)) continue;

        const sku = skusMap.get(hit._id);
        if (!sku) continue;

        results.push({
          productId: hit._id,
          name: sku.name,
          price: sku.price.sellingPrice,
          imagePath: sku.media.images[0].path,
          availability: sku.availability,
          score: hit._score * 4, // scale to match graph/co-purchase score space
          source: "semantic_fallback",
        });
      }
    }

    return res.json({ results });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
