"use strict";

/**
 * services/productGraph.js
 *
 * Builds and exports an in-memory heterogeneous product relationship graph
 * from responses/skus.json. The graph is constructed once at startup and
 * frozen as a singleton.
 *
 * Exports:
 *   buildGraph()        — constructs and freezes the singleton graph
 *   getGraph()          — returns the singleton (throws if not yet built)
 *   skusMap             — Map<skuId, sku> for use by other services
 *   parseArrayString    — custom array-string parser for use by bundleDetector.js
 */

const path = require("path");
const fs = require("fs");

// ---------------------------------------------------------------------------
// 1. parseArrayString — custom parser for SKU array-encoded property strings
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
 * NOTE: Intentionally NOT JSON.parse — the bracket format uses unquoted
 * elements and is not valid JSON (Requirement 1.8).
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
// 2. Load skus.json at module load time
// ---------------------------------------------------------------------------

const SKUS_PATH = path.join(__dirname, "..", "responses", "skus.json");
const skusRaw = JSON.parse(fs.readFileSync(SKUS_PATH, "utf8"));

/** Map<skuId (string), sku object> — exported for use by other services */
const skusMap = new Map(skusRaw.map((sku) => [sku.id, sku]));

// ---------------------------------------------------------------------------
// 3. Graph singleton
// ---------------------------------------------------------------------------

/**
 * The graph structure:
 *   nodes     — Map<nodeId, node object>
 *   edges     — flat array of all edge objects
 *   adjacency — Map<productId, Array<{ neighborId, relation, weight, context }>>
 */
let _graph = null;

// ---------------------------------------------------------------------------
// 4. Internal helpers
// ---------------------------------------------------------------------------

/**
 * Converts a raw property value string into a URL-safe slug used as a node id
 * suffix. Lowercases and trims; the value is already slug-like in skus.json
 * (e.g. "williams-sonoma", "enameled-cast-iron") so no further transformation
 * is needed beyond trimming.
 *
 * @param {string} value
 * @returns {string}
 */
function toSlug(value) {
  return value.trim().toLowerCase();
}

/**
 * Adds an entry to the adjacency index for a product node.
 *
 * @param {Map} adjacency
 * @param {string} productId
 * @param {{ neighborId: string, relation: string, weight: number, context: string|null }} entry
 */
function addAdjacency(adjacency, productId, entry) {
  if (!adjacency.has(productId)) {
    adjacency.set(productId, []);
  }
  adjacency.get(productId).push(entry);
}

// ---------------------------------------------------------------------------
// 5. buildGraph — constructs the singleton
// ---------------------------------------------------------------------------

/**
 * Constructs the product relationship graph from skus.json and freezes it.
 * Idempotent — subsequent calls return the already-built singleton.
 *
 * Phase 1 (this task, 3.1): Product, Brand, Material nodes + BRANDED_BY / MADE_OF edges
 * Phase 2 (task 3.2):       RELATED_CATEGORY edges
 * Phase 3 (task 3.3):       COMPLEMENTARY_USAGE / MAINTAINED_BY edges from domain-rules.json
 *
 * @returns {{ nodes: Map, edges: Array, adjacency: Map }}
 */
function buildGraph() {
  if (_graph) return _graph;

  const nodes = new Map();
  const edges = [];
  const adjacency = new Map();

  // -------------------------------------------------------------------------
  // Phase 1: Product nodes + Brand/Material nodes + BRANDED_BY / MADE_OF edges
  // -------------------------------------------------------------------------

  for (const sku of skusRaw) {
    // -- Product node (Requirement 1.2) --
    const productId = `prod_${sku.id}`;
    const productNode = {
      id: productId,
      type: "Product",
      name: sku.name,
      price: sku.price.sellingPrice,
      availability: sku.availability,
      imagePath: sku.media.images[0].path,
    };
    nodes.set(productId, productNode);

    // Ensure adjacency list exists for this product
    if (!adjacency.has(productId)) {
      adjacency.set(productId, []);
    }

    // -- Brand nodes + BRANDED_BY edges (Requirement 1.3) --
    const brandValues = parseArrayString(sku.properties.brand);
    for (const brandValue of brandValues) {
      const slug = toSlug(brandValue);
      const brandId = `brand_${slug}`;

      if (!nodes.has(brandId)) {
        nodes.set(brandId, {
          id: brandId,
          type: "Brand",
          label: slug,
        });
      }

      const brandedByEdge = {
        source: productId,
        target: brandId,
        relation: "BRANDED_BY",
        weight: 0,
        context: null,
      };
      edges.push(brandedByEdge);

      addAdjacency(adjacency, productId, {
        neighborId: brandId,
        relation: "BRANDED_BY",
        weight: 0,
        context: null,
      });
    }

    // -- Material nodes + MADE_OF edges (Requirement 1.4) --
    const materialValues = parseArrayString(sku.properties.material);
    for (const materialValue of materialValues) {
      const slug = toSlug(materialValue);
      const materialId = `material_${slug}`;

      if (!nodes.has(materialId)) {
        nodes.set(materialId, {
          id: materialId,
          type: "Material",
          label: slug,
        });
      }

      const madeOfEdge = {
        source: productId,
        target: materialId,
        relation: "MADE_OF",
        weight: 0,
        context: null,
      };
      edges.push(madeOfEdge);

      addAdjacency(adjacency, productId, {
        neighborId: materialId,
        relation: "MADE_OF",
        weight: 0,
        context: null,
      });
    }
  }

  // -------------------------------------------------------------------------
  // Phase 2 (task 3.2): RELATED_CATEGORY edges — placeholder hook
  // Will be implemented in task 3.2.
  // -------------------------------------------------------------------------
  _buildRelatedCategoryEdges(nodes, edges, adjacency);

  // -------------------------------------------------------------------------
  // Phase 3 (task 3.3): Domain-rules edges — placeholder hook
  // Will be implemented in task 3.3.
  // -------------------------------------------------------------------------
  _buildDomainRulesEdges(nodes, edges, adjacency);

  // -------------------------------------------------------------------------
  // Freeze and store singleton (Requirement 1.9)
  // -------------------------------------------------------------------------
  _graph = Object.freeze({ nodes, edges, adjacency });
  return _graph;
}

// ---------------------------------------------------------------------------
// 6. Phase 2 hook — RELATED_CATEGORY edges (implemented in task 3.2)
// ---------------------------------------------------------------------------

/**
 * Builds RELATED_CATEGORY edges between Product node pairs that share a
 * collection, brand, productType, or material value.
 *
 * Weight hierarchy (Requirement 1.6):
 *   collection  = 4  (highest priority)
 *   brand       = 3
 *   productType = 2
 *   material    = 1  (lowest priority)
 *
 * For each pair of Product nodes, the highest-priority shared property
 * determines the edge weight and context label. Only one RELATED_CATEGORY
 * edge is created per pair (the highest-priority match wins).
 *
 * @param {Map} nodes
 * @param {Array} edges
 * @param {Map} adjacency
 */
function _buildRelatedCategoryEdges(nodes, edges, adjacency) {
  // Collect all Product nodes
  const productNodes = [];
  for (const [, node] of nodes) {
    if (node.type === "Product") productNodes.push(node);
  }

  // Build lookup maps for each property tier
  // Each map: propertyValue → Set<productId>
  const collectionMap = new Map();  // weight 4
  const brandMap = new Map();       // weight 3
  const productTypeMap = new Map(); // weight 2
  const materialMap = new Map();    // weight 1

  for (const productNode of productNodes) {
    const sku = skusMap.get(productNode.id.slice(5)); // strip "prod_" prefix
    if (!sku) continue;

    const collections = parseArrayString(sku.properties.collection);
    for (const col of collections) {
      if (!collectionMap.has(col)) collectionMap.set(col, new Set());
      collectionMap.get(col).add(productNode.id);
    }

    const brands = parseArrayString(sku.properties.brand);
    for (const brand of brands) {
      if (!brandMap.has(brand)) brandMap.set(brand, new Set());
      brandMap.get(brand).add(productNode.id);
    }

    const productTypes = parseArrayString(sku.properties.productType);
    for (const pt of productTypes) {
      if (!productTypeMap.has(pt)) productTypeMap.set(pt, new Set());
      productTypeMap.get(pt).add(productNode.id);
    }

    const materials = parseArrayString(sku.properties.material);
    for (const mat of materials) {
      if (!materialMap.has(mat)) materialMap.set(mat, new Set());
      materialMap.get(mat).add(productNode.id);
    }
  }

  // Track edges already added to avoid duplicates (keyed as "srcId|tgtId").
  // Since we process tiers in descending priority order, the first edge added
  // for a pair is always the highest-priority one.
  const addedEdges = new Set();

  /**
   * Adds a RELATED_CATEGORY edge in both directions if not already present.
   */
  function addRelatedCategoryEdge(srcId, tgtId, weight, context) {
    const key = `${srcId}|${tgtId}`;
    const reverseKey = `${tgtId}|${srcId}`;
    if (addedEdges.has(key) || addedEdges.has(reverseKey)) return;
    addedEdges.add(key);
    addedEdges.add(reverseKey);

    const fwdEdge = { source: srcId, target: tgtId, relation: "RELATED_CATEGORY", weight, context };
    const revEdge = { source: tgtId, target: srcId, relation: "RELATED_CATEGORY", weight, context };
    edges.push(fwdEdge, revEdge);

    addAdjacency(adjacency, srcId, { neighborId: tgtId, relation: "RELATED_CATEGORY", weight, context });
    addAdjacency(adjacency, tgtId, { neighborId: srcId, relation: "RELATED_CATEGORY", weight, context });
  }

  /**
   * Iterates all pairs within a property-value group and adds edges for
   * pairs not yet covered by a higher-priority tier.
   */
  function processPropertyTier(propertyMap, weight) {
    for (const [propertyValue, productIdSet] of propertyMap) {
      const ids = Array.from(productIdSet);
      for (let i = 0; i < ids.length; i++) {
        for (let j = i + 1; j < ids.length; j++) {
          addRelatedCategoryEdge(ids[i], ids[j], weight, propertyValue);
        }
      }
    }
  }

  // Process tiers in descending priority order so the highest-priority shared
  // property always wins for any given pair (Requirement 1.6).
  processPropertyTier(collectionMap, 4);  // collection  = 4
  processPropertyTier(brandMap, 3);       // brand       = 3
  processPropertyTier(productTypeMap, 2); // productType = 2
  processPropertyTier(materialMap, 1);    // material    = 1
}

// ---------------------------------------------------------------------------
// 7. Phase 3 hook — Domain-rules edges (implemented in task 3.3)
// ---------------------------------------------------------------------------

/**
 * Builds COMPLEMENTARY_USAGE and MAINTAINED_BY edges from domain-rules.json.
 *
 * This function is a stub — full implementation in task 3.3.
 *
 * @param {Map} nodes
 * @param {Array} edges
 * @param {Map} adjacency
 */
function _buildDomainRulesEdges(nodes, edges, adjacency) {
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
    const productTypes = parseArrayString(sku.properties.productType);
    for (const pt of productTypes) {
      if (!productTypeMap.has(pt)) productTypeMap.set(pt, []);
      productTypeMap.get(pt).push(node.id);
    }
  }

  for (const rule of rules) {
    const { sourceProductType, targetProductType, relation, context, weight } = rule;
    const sourceIds = productTypeMap.get(sourceProductType) || [];
    const targetIds = productTypeMap.get(targetProductType) || [];

    for (const srcId of sourceIds) {
      for (const tgtId of targetIds) {
        if (srcId === tgtId) continue;

        const fwdEdge = { source: srcId, target: tgtId, relation, weight, context };
        const revEdge = { source: tgtId, target: srcId, relation, weight, context };
        edges.push(fwdEdge, revEdge);

        addAdjacency(adjacency, srcId, { neighborId: tgtId, relation, weight, context });
        addAdjacency(adjacency, tgtId, { neighborId: srcId, relation, weight, context });
      }
    }
  }
}

// ---------------------------------------------------------------------------
// 8. getGraph — returns the singleton (throws if buildGraph not yet called)
// ---------------------------------------------------------------------------

/**
 * Returns the frozen graph singleton.
 * Throws if buildGraph() has not been called yet.
 *
 * @returns {{ nodes: Map, edges: Array, adjacency: Map }}
 */
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
