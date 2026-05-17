"use strict";

/**
 * services/mcpOrchestrator.js
 *
 * Parallel fan-out orchestrator combining graph traversal + Pinecone vector
 * search with five quality improvements:
 *
 *   1. FREQUENTLY_BOUGHT_TOGETHER edges (weight 5) in domain-rules.json
 *   2. Price band filtering  — deprioritise items >3× or <0.1× avg cart value
 *   3. Recency weighting     — most-recently-added cart item's neighbours ×1.5
 *   4. Availability boosting — ON_HAND beats BACK_ORDERED at equal score
 *   5. Category diversity    — at most 2 results per productType
 */

const { getGraph, skusMap, parseArrayString } = require("./productGraph");
const { queryForCart } = require("./pineconeService");
const { getCoPurchaseCandidates } = require("./coPurchaseService");

// ---------------------------------------------------------------------------
// 1. traverseForRecommendations
// ---------------------------------------------------------------------------

function traverseForRecommendations(cartItems, graph) {
  // Build a recency map: most-recently-added item gets the highest multiplier.
  // cartItems is ordered oldest-first (append order), so last item = most recent.
  const recencyMultiplier = new Map();
  cartItems.forEach((item, idx) => {
    // Linear scale: oldest = 1.0, newest = 1.5
    const factor = 1.0 + (idx / Math.max(cartItems.length - 1, 1)) * 0.5;
    recencyMultiplier.set(item.productId, factor);
  });

  const cartProductIds = new Set(cartItems.map((i) => i.productId));

  // bestByProduct: productId → { score, context }
  const bestByProduct = new Map();

  for (const item of cartItems) {
    const nodeId    = `prod_${item.productId}`;
    const neighbors = graph.adjacency.get(nodeId);
    if (!neighbors) continue;

    const recency = recencyMultiplier.get(item.productId) ?? 1.0;

    for (const edge of neighbors) {
      const neighborNode = graph.nodes.get(edge.neighborId);
      if (!neighborNode || neighborNode.type !== "Product") continue;

      const productId = edge.neighborId.startsWith("prod_")
        ? edge.neighborId.slice(5)
        : edge.neighborId;

      const adjustedScore = edge.weight * recency;
      const existing = bestByProduct.get(productId);
      if (!existing || adjustedScore > existing.score) {
        bestByProduct.set(productId, { score: adjustedScore, context: edge.context });
      }
    }
  }

  return Array.from(bestByProduct.entries()).map(([productId, { score, context }]) => ({
    productId,
    score,
    source: "graph",
    context,
  }));
}

// ---------------------------------------------------------------------------
// 2. mergeCandidates
// ---------------------------------------------------------------------------

function mergeCandidates(graphCandidates, pineconeCandidates, cartProductIds) {
  const cartSet =
    cartProductIds instanceof Set ? cartProductIds : new Set(cartProductIds);

  const scoreMap = new Map();

  for (const c of graphCandidates) {
    scoreMap.set(c.productId, { score: c.score, source: "graph", context: c.context ?? null });
  }

  for (const c of pineconeCandidates) {
    const normalizedScore = c.score * 4;
    if (scoreMap.has(c.productId)) {
      const existing = scoreMap.get(c.productId);
      if (existing.source !== "graph" && normalizedScore > existing.score) {
        scoreMap.set(c.productId, { score: normalizedScore, source: "pinecone", context: null });
      }
    } else {
      scoreMap.set(c.productId, { score: normalizedScore, source: "pinecone", context: null });
    }
  }

  const merged = [];
  for (const [productId, entry] of scoreMap.entries()) {
    if (cartSet.has(productId)) continue;
    merged.push({ productId, score: entry.score, source: entry.source, context: entry.context });
  }

  merged.sort((a, b) => b.score - a.score);
  return merged.slice(0, 5);
}

// ---------------------------------------------------------------------------
// 3. Post-merge quality passes
// ---------------------------------------------------------------------------

/**
 * Price band filter — soft-deprioritise candidates outside the cart's price range.
 * Items >3× or <0.1× the average cart item price get their score halved.
 */
function applyPriceBandFilter(candidates, cartItems) {
  if (cartItems.length === 0) return candidates;

  const avgCartPrice =
    cartItems.reduce((sum, item) => {
      const sku = skusMap.get(item.productId);
      return sum + (sku ? sku.price.sellingPrice : 0);
    }, 0) / cartItems.length;

  return candidates.map((c) => {
    const sku = skusMap.get(c.productId);
    if (!sku) return c;
    const price = sku.price.sellingPrice;
    const ratio = price / avgCartPrice;
    if (ratio > 3 || ratio < 0.1) {
      return { ...c, score: c.score * 0.5 };
    }
    return c;
  });
}

/**
 * Availability boost — ON_HAND items beat BACK_ORDERED at equal score.
 * Adds a tiny tiebreaker (+0.01) so ON_HAND floats above BACK_ORDERED.
 */
function applyAvailabilityBoost(candidates) {
  return candidates.map((c) => {
    const sku = skusMap.get(c.productId);
    if (sku && sku.availability === "ON_HAND") {
      return { ...c, score: c.score + 0.01 };
    }
    return c;
  });
}

/**
 * Category diversity — at most 2 results per productType.
 * Keeps the highest-scoring items first, then enforces the cap.
 */
function applyCategoryDiversity(candidates, maxPerCategory = 2) {
  const countByType = new Map();
  const result = [];

  for (const c of candidates) {
    const sku = skusMap.get(c.productId);
    const productTypes = sku
      ? parseArrayString(sku.properties.productType)
      : ["unknown"];
    const primaryType = productTypes[0] || "unknown";

    const count = countByType.get(primaryType) ?? 0;
    if (count < maxPerCategory) {
      result.push(c);
      countByType.set(primaryType, count + 1);
    }
  }

  return result;
}

// ---------------------------------------------------------------------------
// 4. getRecommendations
// ---------------------------------------------------------------------------

async function getRecommendations(cartItems) {
  const graph = getGraph();
  const cartProductIds = new Set(cartItems.map((i) => i.productId));

  // Fan out: graph (sync) + Pinecone (async, 1000ms timeout) + collaborative filtering (async)
  const graphPromise = Promise.resolve(traverseForRecommendations(cartItems, graph));

  const timeoutPromise = new Promise((resolve) => setTimeout(() => resolve([]), 1000));
  const pineconePromise = queryForCart(cartProductIds).catch((err) => {
    console.warn("[mcpOrchestrator] Pinecone degraded:", err.message);
    return [];
  });

  // Collaborative filtering — real co-purchase data from Firestore
  // Gracefully returns [] if Firestore is unavailable or no data yet
  const collaborativePromise = getCoPurchaseCandidates(cartProductIds).catch((err) => {
    console.warn("[mcpOrchestrator] Collaborative filtering degraded:", err.message);
    return [];
  });

  const [graphCandidates, pineconeCandidates, collaborativeCandidates] = await Promise.all([
    graphPromise,
    Promise.race([pineconePromise, timeoutPromise]),
    collaborativePromise,
  ]);

  // Merge: collaborative candidates go first (real purchase signal wins)
  // then graph candidates, then Pinecone
  let candidates = mergeCandidates(
    [...collaborativeCandidates, ...graphCandidates],
    pineconeCandidates,
    cartProductIds
  );

  // Ground against Product Graph
  candidates = candidates.filter((c) => graph.nodes.has(`prod_${c.productId}`));

  // Quality passes
  candidates = applyPriceBandFilter(candidates, cartItems);
  candidates = applyAvailabilityBoost(candidates);
  candidates.sort((a, b) => b.score - a.score);
  candidates = applyCategoryDiversity(candidates);

  // Attach metadata
  return candidates.slice(0, 5).map((c) => {
    const sku = skusMap.get(c.productId);
    return {
      productId:    c.productId,
      score:        Math.round(c.score * 1000) / 1000,
      source:       c.source,
      context:      c.context,
      name:         sku ? sku.name : null,
      price:        sku ? sku.price.sellingPrice : null,
      imagePath:    sku ? sku.media.images[0].path : null,
      availability: sku ? sku.availability : null,
    };
  });
}

// ---------------------------------------------------------------------------
// Exports
// ---------------------------------------------------------------------------

module.exports = {
  traverseForRecommendations: (cartProductIds, graph) => {
    // Backwards-compatible shim for tests that pass a Set/array of IDs
    const items = cartProductIds instanceof Set
      ? Array.from(cartProductIds).map((id) => ({ productId: id }))
      : Array.isArray(cartProductIds)
        ? cartProductIds.map((id) => (typeof id === "string" ? { productId: id } : id))
        : [];
    return traverseForRecommendations(items, graph);
  },
  mergeCandidates,
  getRecommendations,
};
