"use strict";

/**
 * services/productGraph.js
 *
 * Builds and exports an in-memory heterogeneous product relationship graph
 * from responses/skus.json. The graph is constructed once at startup and
 * frozen as a singleton.
 *
 * Fixes applied:
 *   1. _buildDomainRulesEdges now deduplicates using a sorted-pair Set so
 *      no duplicate edges are created for the same product pair + relation.
 *   2. traverseForRecommendations (in mcpOrchestrator) receives clean data
 *      because adjacency entries are now deduplicated at insertion time.
 *   3. pineconeService is lazy-initialized (handled in pineconeService.js).
 *
 * Exports:
 *   buildGraph()        — constructs and freezes the singleton graph
 *   getGraph()          — returns the singleton (throws if not yet built)
 *   skusMap             — Map<skuId, sku> for use by other services
 *   parseArrayString    — custom array-string parser for use by bundleDetector.js
 */

const path = require("path");
const fs   = require("fs");

// ---------------------------------------------------------------------------
// 1. parseArrayString
// ---------------------------------------------------------------------------

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
// 2. Load skus.json at module load time
// ---------------------------------------------------------------------------

const SKUS_PATH = path.join(__dirname, "..", "responses", "skus.json");
const skusRaw   = JSON.parse(fs.readFileSync(SKUS_PATH, "utf8"));

/** Map<skuId (string), sku object> */
const skusMap = new Map(skusRaw.map((sku) => [sku.id, sku]));

// ---------------------------------------------------------------------------
// 3. Graph singleton
// ---------------------------------------------------------------------------

let _graph = null;

// ---------------------------------------------------------------------------
// 4. Internal helpers
// ---------------------------------------------------------------------------

function toSlug(value) {
  return value.trim().toLowerCase();
}

function addAdjacency(adjacency, productId, entry) {
  if (!adjacency.has(productId)) {
    adjacency.set(productId, []);
  }
  adjacency.get(productId).push(entry);
}

// ---------------------------------------------------------------------------
// 5. buildGraph
// ---------------------------------------------------------------------------

function buildGraph() {
  if (_graph) return _graph;

  const nodes     = new Map();
  const edges     = [];
  const adjacency = new Map();

  // ── Phase 1: Product / Brand / Material nodes + BRANDED_BY / MADE_OF ────

  for (const sku of skusRaw) {
    const productId   = `prod_${sku.id}`;
    const productNode = {
      id:           productId,
      type:         "Product",
      name:         sku.name,
      price:        sku.price.sellingPrice,
      availability: sku.availability,
      imagePath:    sku.media.images[0].path,
    };
    nodes.set(productId, productNode);

    if (!adjacency.has(productId)) adjacency.set(productId, []);

    // Brand nodes + BRANDED_BY
    for (const brandValue of parseArrayString(sku.properties.brand)) {
      const brandId = `brand_${toSlug(brandValue)}`;
      if (!nodes.has(brandId)) {
        nodes.set(brandId, { id: brandId, type: "Brand", label: toSlug(brandValue) });
      }
      edges.push({ source: productId, target: brandId, relation: "BRANDED_BY", weight: 0, context: null });
      addAdjacency(adjacency, productId, { neighborId: brandId, relation: "BRANDED_BY", weight: 0, context: null });
    }

    // Material nodes + MADE_OF
    for (const materialValue of parseArrayString(sku.properties.material)) {
      if (!materialValue) continue;
      const materialId = `material_${toSlug(materialValue)}`;
      if (!nodes.has(materialId)) {
        nodes.set(materialId, { id: materialId, type: "Material", label: toSlug(materialValue) });
      }
      edges.push({ source: productId, target: materialId, relation: "MADE_OF", weight: 0, context: null });
      addAdjacency(adjacency, productId, { neighborId: materialId, relation: "MADE_OF", weight: 0, context: null });
    }
  }

  // ── Phase 2: RELATED_CATEGORY edges ──────────────────────────────────────
  const relatedCategoryPairs = _buildRelatedCategoryEdges(nodes, edges, adjacency);

  // ── Phase 3: Domain-rules edges ───────────────────────────────────────────
  _buildDomainRulesEdges(nodes, edges, adjacency, relatedCategoryPairs);

  _graph = Object.freeze({ nodes, edges, adjacency });
  return _graph;
}

// ---------------------------------------------------------------------------
// 6. _buildRelatedCategoryEdges
// ---------------------------------------------------------------------------

function _buildRelatedCategoryEdges(nodes, edges, adjacency) {
  const productNodes = [];
  for (const [, node] of nodes) {
    if (node.type === "Product") productNodes.push(node);
  }

  const collectionMap  = new Map(); // weight 4
  const brandMap       = new Map(); // weight 3
  const productTypeMap = new Map(); // weight 2
  const materialMap    = new Map(); // weight 1

  for (const productNode of productNodes) {
    const sku = skusMap.get(productNode.id.slice(5));
    if (!sku) continue;

    for (const col of parseArrayString(sku.properties.collection)) {
      if (!collectionMap.has(col)) collectionMap.set(col, new Set());
      collectionMap.get(col).add(productNode.id);
    }
    for (const brand of parseArrayString(sku.properties.brand)) {
      if (!brandMap.has(brand)) brandMap.set(brand, new Set());
      brandMap.get(brand).add(productNode.id);
    }
    for (const pt of parseArrayString(sku.properties.productType)) {
      if (!productTypeMap.has(pt)) productTypeMap.set(pt, new Set());
      productTypeMap.get(pt).add(productNode.id);
    }
    for (const mat of parseArrayString(sku.properties.material)) {
      if (!mat) continue;
      if (!materialMap.has(mat)) materialMap.set(mat, new Set());
      materialMap.get(mat).add(productNode.id);
    }
  }

  // Dedup set: sorted pair key → only the highest-priority tier wins
  const addedPairs = new Set();

  function addRelatedCategoryEdge(srcId, tgtId, weight, context) {
    // Use sorted pair so A|B and B|A share the same key
    const key = [srcId, tgtId].sort().join("|");
    if (addedPairs.has(key)) return;
    addedPairs.add(key);

    edges.push({ source: srcId, target: tgtId, relation: "RELATED_CATEGORY", weight, context });
    edges.push({ source: tgtId, target: srcId, relation: "RELATED_CATEGORY", weight, context });

    addAdjacency(adjacency, srcId, { neighborId: tgtId, relation: "RELATED_CATEGORY", weight, context });
    addAdjacency(adjacency, tgtId, { neighborId: srcId, relation: "RELATED_CATEGORY", weight, context });
  }

  function processTier(propertyMap, weight) {
    for (const [propertyValue, productIdSet] of propertyMap) {
      const ids = Array.from(productIdSet);
      for (let i = 0; i < ids.length; i++) {
        for (let j = i + 1; j < ids.length; j++) {
          addRelatedCategoryEdge(ids[i], ids[j], weight, propertyValue);
        }
      }
    }
  }

  // Process highest priority first — first write wins for any pair
  processTier(collectionMap,  4); // collection  = 4
  processTier(brandMap,       3); // brand       = 3
  processTier(productTypeMap, 2); // productType = 2
  processTier(materialMap,    1); // material    = 1

  // Return the dedup set so Phase 3 can respect it
  return addedPairs;
}

// ---------------------------------------------------------------------------
// 7. _buildDomainRulesEdges
// ---------------------------------------------------------------------------

function _buildDomainRulesEdges(nodes, edges, adjacency, relatedCategoryPairs = new Set()) {
  const rulesPath = path.join(__dirname, "..", "domain-rules.json");
  let domainRules;
  try {
    domainRules = JSON.parse(fs.readFileSync(rulesPath, "utf8"));
  } catch (err) {
    console.warn("[productGraph] Could not load domain-rules.json:", err.message);
    return;
  }

  const rules = domainRules.rules || [];

  // Build productType → [productId] lookup
  const productTypeMap = new Map();
  for (const [, node] of nodes) {
    if (node.type !== "Product") continue;
    const sku = skusMap.get(node.id.slice(5));
    if (!sku) continue;
    for (const pt of parseArrayString(sku.properties.productType)) {
      if (!productTypeMap.has(pt)) productTypeMap.set(pt, []);
      productTypeMap.get(pt).push(node.id);
    }
  }

  // Dedup set: sorted pair + relation — prevents duplicate edges
  const addedDomainEdges = new Set();

  for (const rule of rules) {
    const { sourceProductType, targetProductType, relation, context, weight } = rule;
    const sourceIds = productTypeMap.get(sourceProductType) || [];
    const targetIds = productTypeMap.get(targetProductType) || [];

    for (const srcId of sourceIds) {
      for (const tgtId of targetIds) {
        if (srcId === tgtId) continue;

        // If this is a RELATED_CATEGORY domain rule, skip pairs already
        // covered by Phase 2 (property-tier edges take priority)
        if (relation === "RELATED_CATEGORY") {
          const rcKey = [srcId, tgtId].sort().join("|");
          if (relatedCategoryPairs.has(rcKey)) continue;
        }

        const pairKey = [srcId, tgtId].sort().join("|") + "|" + relation;
        if (addedDomainEdges.has(pairKey)) continue;
        addedDomainEdges.add(pairKey);

        edges.push({ source: srcId, target: tgtId, relation, weight, context });
        edges.push({ source: tgtId, target: srcId, relation, weight, context });

        addAdjacency(adjacency, srcId, { neighborId: tgtId, relation, weight, context });
        addAdjacency(adjacency, tgtId, { neighborId: srcId, relation, weight, context });
      }
    }
  }
}

// ---------------------------------------------------------------------------
// 8. getGraph
// ---------------------------------------------------------------------------

function getGraph() {
  if (!_graph) {
    throw new Error(
      "[productGraph] Graph has not been built yet. Call buildGraph() at server startup."
    );
  }
  return _graph;
}

// ---------------------------------------------------------------------------
// Exports
// ---------------------------------------------------------------------------

module.exports = {
  buildGraph,
  getGraph,
  skusMap,
  parseArrayString,
};
