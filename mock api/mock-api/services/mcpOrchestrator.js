"use strict";

/**
 * services/mcpOrchestrator.js
 *
 * Parallel fan-out orchestrator that combines graph traversal and Pinecone
 * vector search to produce ranked, grounded product recommendations.
 *
 * Exports:
 *   traverseForRecommendations(cartProductIds, graph)
 *     — walks the adjacency index for each cart product and returns Product
 *       neighbor candidates (skips Brand/Material nodes)
 *
 *   mergeCandidates(graphCandidates, pineconeCandidates, cartProductIds)
 *     — merges two candidate lists; graph source always wins on duplicate;
 *       Pinecone scores normalized ×4; excludes cart items; top 5 descending
 *
 *   getRecommendations(cartItems)
 *     — fans out graph traversal (sync) and Pinecone query (async, 1000ms
 *       timeout) in parallel; merges; grounds against graph; attaches metadata
 *
 * Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 5.1, 5.2, 5.3, 5.4, 5.5
 */

const { getGraph, skusMap } = require("./productGraph");
const { queryForCart } = require("./pineconeService");

// ---------------------------------------------------------------------------
// 1. traverseForRecommendations
// ---------------------------------------------------------------------------

/**
 * Walks the adjacency index for each cart product and collects neighboring
 * Product nodes as recommendation candidates.
 *
 * Brand and Material nodes are skipped — only nodes with type === "Product"
 * are included in the output.
 *
 * The raw productId stored in the graph has a "prod_" prefix (e.g. "prod_2453926").
 * The returned productId strips that prefix so it matches the SKU id format
 * used by the rest of the system (e.g. "2453926").
 *
 * @param {Set<string>|string[]} cartProductIds — raw SKU ids (no "prod_" prefix)
 * @param {{ nodes: Map, edges: Array, adjacency: Map }} graph
 * @returns {Array<{ productId: string, score: number, source: "graph", context: string|null }>}
 */
function traverseForRecommendations(cartProductIds, graph) {
  const candidates = [];

  for (const rawId of cartProductIds) {
    const nodeId = `prod_${rawId}`;
    const neighbors = graph.adjacency.get(nodeId);
    if (!neighbors) continue;

    for (const edge of neighbors) {
      const neighborNode = graph.nodes.get(edge.neighborId);
      // Skip Brand and Material nodes — only collect Product neighbors
      if (!neighborNode || neighborNode.type !== "Product") continue;

      // Strip "prod_" prefix to return a plain SKU id
      const productId = edge.neighborId.startsWith("prod_")
        ? edge.neighborId.slice(5)
        : edge.neighborId;

      candidates.push({
        productId,
        score: edge.weight,
        source: "graph",
        context: edge.context,
      });
    }
  }

  return candidates;
}

// ---------------------------------------------------------------------------
// 2. mergeCandidates
// ---------------------------------------------------------------------------

/**
 * Merges graph and Pinecone candidate lists into a single ranked list.
 *
 * Merge rules (from design doc §6):
 *   - Graph candidates are inserted first; graph source always wins on duplicate.
 *   - Pinecone scores are normalized by ×4 before comparison (to bring the
 *     0.0–1.0 Pinecone range in line with the 1–4 graph weight range).
 *   - If a productId already exists with source "graph", the graph score is kept.
 *   - If a productId already exists with source "pinecone" and the new Pinecone
 *     score (×4) is higher, the entry is upgraded.
 *   - Products already in the cart are excluded from the output.
 *   - Results are sorted descending by score; top 5 are returned.
 *
 * @param {Array<{ productId: string, score: number, source: string, context?: string|null }>} graphCandidates
 * @param {Array<{ productId: string, score: number, source: string }>} pineconeCandidates
 * @param {Set<string>|string[]} cartProductIds — raw SKU ids to exclude
 * @returns {Array<{ productId: string, score: number, source: string }>}
 */
function mergeCandidates(graphCandidates, pineconeCandidates, cartProductIds) {
  const cartSet =
    cartProductIds instanceof Set
      ? cartProductIds
      : new Set(cartProductIds);

  // scoreMap: productId → { score, source, context }
  const scoreMap = new Map();

  // Insert graph candidates first — graph source always wins
  for (const candidate of graphCandidates) {
    scoreMap.set(candidate.productId, {
      score: candidate.score,
      source: "graph",
      context: candidate.context ?? null,
    });
  }

  // Merge Pinecone candidates with ×4 normalization
  for (const candidate of pineconeCandidates) {
    const normalizedScore = candidate.score * 4;

    if (scoreMap.has(candidate.productId)) {
      const existing = scoreMap.get(candidate.productId);
      // Only upgrade if existing source is NOT "graph" and new score is higher
      if (existing.source !== "graph" && normalizedScore > existing.score) {
        scoreMap.set(candidate.productId, {
          score: normalizedScore,
          source: "pinecone",
          context: null,
        });
      }
      // If existing source IS "graph", keep graph score (graph takes precedence)
    } else {
      scoreMap.set(candidate.productId, {
        score: normalizedScore,
        source: "pinecone",
        context: null,
      });
    }
  }

  // Exclude cart items, flatten, sort descending, return top 5
  const merged = [];
  for (const [productId, entry] of scoreMap.entries()) {
    if (cartSet.has(productId)) continue;
    merged.push({ productId, score: entry.score, source: entry.source, context: entry.context });
  }

  merged.sort((a, b) => b.score - a.score);
  return merged.slice(0, 5);
}

// ---------------------------------------------------------------------------
// 3. getRecommendations
// ---------------------------------------------------------------------------

/**
 * Main entry point for the recommendation pipeline.
 *
 * Steps:
 *   1. Extract cart product IDs from the cart items array.
 *   2. Fan out in parallel:
 *        - Graph traversal (sync, wrapped in Promise.resolve)
 *        - Pinecone query (async) with a 1000ms timeout via Promise.race
 *          (timeout resolves to [] so Pinecone failure degrades gracefully)
 *   3. Merge candidates using mergeCandidates().
 *   4. Ground: discard any productId not present in the Product Graph
 *      (checks graph.nodes.has("prod_" + c.productId)).
 *   5. Attach metadata from skusMap: name, price, imagePath, availability.
 *   6. Return the final recommendations array.
 *
 * @param {Array<{ productId: string, [key: string]: any }>} cartItems
 * @returns {Promise<Array<{
 *   productId: string,
 *   score: number,
 *   source: string,
 *   context: string|null,
 *   name: string,
 *   price: number,
 *   imagePath: string,
 *   availability: string
 * }>>}
 */
async function getRecommendations(cartItems) {
  const graph = getGraph();
  const cartProductIds = new Set(cartItems.map((i) => i.productId));

  // --- Fan out ---

  // Graph traversal is synchronous; wrap in Promise.resolve for Promise.all
  const graphPromise = Promise.resolve(
    traverseForRecommendations(cartProductIds, graph)
  );

  // Pinecone query with 1000ms timeout; any error or timeout resolves to []
  const timeoutPromise = new Promise((resolve) =>
    setTimeout(() => resolve([]), 1000)
  );

  const pineconePromise = queryForCart(cartProductIds).catch((err) => {
    console.warn("[mcpOrchestrator] Pinecone query failed, degrading gracefully:", err.message);
    return [];
  });

  const [graphCandidates, pineconeCandidates] = await Promise.all([
    graphPromise,
    Promise.race([pineconePromise, timeoutPromise]),
  ]);

  // --- Merge ---
  const merged = mergeCandidates(graphCandidates, pineconeCandidates, cartProductIds);

  // --- Ground against Product Graph ---
  const grounded = merged.filter((c) => graph.nodes.has(`prod_${c.productId}`));

  // --- Attach metadata from skusMap ---
  const recommendations = grounded.map((c) => {
    const sku = skusMap.get(c.productId);
    return {
      productId: c.productId,
      score: c.score,
      source: c.source,
      context: c.context,
      name: sku ? sku.name : null,
      price: sku ? sku.price.sellingPrice : null,
      imagePath: sku ? sku.media.images[0].path : null,
      availability: sku ? sku.availability : null,
    };
  });

  return recommendations;
}

// ---------------------------------------------------------------------------
// Exports
// ---------------------------------------------------------------------------

module.exports = {
  traverseForRecommendations,
  mergeCandidates,
  getRecommendations,
};
