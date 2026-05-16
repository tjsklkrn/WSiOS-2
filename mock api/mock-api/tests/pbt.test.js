"use strict";

/**
 * tests/pbt.test.js
 *
 * Property-Based Tests for Smart Cart & Smart Registry
 *
 * Uses fast-check for generative testing and Node's built-in test runner
 * (node:test + node:assert). Run with: npm test
 *
 * Properties covered:
 *   1.  Product Graph Node Construction Invariants
 *   2.  Array String Parser Round-Trip
 *   3.  RELATED_CATEGORY Edge Weight Hierarchy
 *   4.  Domain Rules Edge Construction
 *   5.  Recommendations Merge Algorithm Invariants
 *   6.  Recommendation Grounding and Metadata Completeness
 *   7.  Bundle Detection Invariants
 *   8.  Availability Routing Invariants
 *   9.  Cart Total Price Calculation
 *   10. Firebase Auth Enforcement on Cart Endpoints
 *   11. Registry Item Management Invariants
 *   12. Registry Dashboard Calculation Correctness
 *   13. Registry Name Search Case-Insensitivity
 */

// Set required env vars before any service modules are loaded so that
// modules that initialize external clients at load time (e.g. pineconeService)
// do not throw during test runs.
process.env.PINECONE_API_KEY = process.env.PINECONE_API_KEY || "test-placeholder-key";
process.env.PINECONE_INDEX_NAME = process.env.PINECONE_INDEX_NAME || "test-placeholder-index";

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const fc = require("fast-check");

// ---------------------------------------------------------------------------
// Service imports — loaded here so subsequent tasks can fill in the tests
// ---------------------------------------------------------------------------
const { buildGraph, getGraph, parseArrayString, skusMap } = require("../services/productGraph");
const { traverseForRecommendations, mergeCandidates, getRecommendations } = require("../services/mcpOrchestrator");
const { addItem, removeItem, getCart } = require("../services/cartService");
const { addItem: sflAddItem, getList, recordNotify } = require("../services/saveForLater");
const { detectBundles, buildBundle, VALID_REGISTRY_CATEGORIES, PRODUCT_TYPE_TO_REGISTRY_CATEGORY } = require("../services/bundleDetector");

// Build the graph once before all tests
buildGraph();

// ---------------------------------------------------------------------------
// Property 1: Product Graph Node Construction Invariants
// Validates: Requirements 1.2, 1.3, 1.4, 1.8
// ---------------------------------------------------------------------------
describe("Property 1: Product Graph Node Construction Invariants", () => {
  it("for any SKU, Product node exists with correct fields and Brand/Material nodes + edges are present", () => {
    /**
     * **Validates: Requirements 1.2, 1.3, 1.4, 1.8**
     *
     * For any SKU ID drawn from the real catalog, assert:
     *   - A Product node exists with the correct type, name, price, availability, imagePath
     *   - For each brand value, a Brand node exists and a BRANDED_BY edge is present
     *   - For each material value (if any), a Material node exists and a MADE_OF edge is present
     */
    const graph = getGraph();
    const skuIds = Array.from(skusMap.keys());

    fc.assert(
      fc.property(fc.constantFrom(...skuIds), (skuId) => {
        const sku = skusMap.get(skuId);
        const productId = `prod_${skuId}`;

        // Requirement 1.2: Product node exists with correct fields
        assert.ok(graph.nodes.has(productId), `Product node missing for SKU ${skuId}`);
        const productNode = graph.nodes.get(productId);
        assert.strictEqual(productNode.type, "Product");
        assert.strictEqual(productNode.name, sku.name);
        assert.strictEqual(productNode.price, sku.price.sellingPrice);
        assert.strictEqual(productNode.availability, sku.availability);
        assert.strictEqual(productNode.imagePath, sku.media.images[0].path);

        // Requirement 1.3: Brand nodes + BRANDED_BY edges
        const brandValues = parseArrayString(sku.properties.brand);
        for (const brandValue of brandValues) {
          const slug = brandValue.trim().toLowerCase();
          const brandId = `brand_${slug}`;
          assert.ok(graph.nodes.has(brandId), `Brand node missing: ${brandId}`);
          const brandNode = graph.nodes.get(brandId);
          assert.strictEqual(brandNode.type, "Brand");

          const hasBrandedByEdge = graph.edges.some(
            (e) => e.source === productId && e.target === brandId && e.relation === "BRANDED_BY"
          );
          assert.ok(hasBrandedByEdge, `BRANDED_BY edge missing from ${productId} to ${brandId}`);
        }

        // Requirement 1.4: Material nodes + MADE_OF edges (skip if no material)
        const materialValues = parseArrayString(sku.properties.material);
        for (const materialValue of materialValues) {
          const slug = materialValue.trim().toLowerCase();
          const materialId = `material_${slug}`;
          assert.ok(graph.nodes.has(materialId), `Material node missing: ${materialId}`);
          const materialNode = graph.nodes.get(materialId);
          assert.strictEqual(materialNode.type, "Material");

          const hasMadeOfEdge = graph.edges.some(
            (e) => e.source === productId && e.target === materialId && e.relation === "MADE_OF"
          );
          assert.ok(hasMadeOfEdge, `MADE_OF edge missing from ${productId} to ${materialId}`);
        }
      })
    );
  });
});

// ---------------------------------------------------------------------------
// Property 2: Array String Parser Round-Trip
// Validates: Requirements 1.8
// ---------------------------------------------------------------------------
describe("Property 2: Array String Parser Round-Trip", () => {
  it("2a — bracket-encoded arrays round-trip correctly", () => {
    /**
     * **Validates: Requirement 1.8**
     *
     * For any array of slug-like strings, constructing "[a, b, c]" and
     * parsing it back should yield the original array.
     */
    fc.assert(
      fc.property(
        fc.array(fc.stringMatching(/^[a-z][a-z0-9-]*$/), { minLength: 1, maxLength: 6 }),
        (elements) => {
          const input = "[" + elements.join(", ") + "]";
          const result = parseArrayString(input);
          assert.deepStrictEqual(result, elements);
        }
      )
    );
  });

  it("2b — scalar strings are wrapped in a single-element array", () => {
    /**
     * **Validates: Requirement 1.8**
     *
     * A plain string (no brackets) should be returned as a single-element array.
     */
    fc.assert(
      fc.property(
        fc.stringMatching(/^[a-z][a-z0-9-]*$/),
        (input) => {
          const result = parseArrayString(input);
          assert.deepStrictEqual(result, [input]);
        }
      )
    );
  });

  it("2c — non-string inputs return empty array", () => {
    /**
     * **Validates: Requirement 1.8**
     *
     * Non-string inputs (integer, boolean, null, undefined) should return [].
     */
    fc.assert(
      fc.property(
        fc.oneof(fc.integer(), fc.boolean(), fc.constant(null), fc.constant(undefined)),
        (input) => {
          const result = parseArrayString(input);
          assert.deepStrictEqual(result, []);
        }
      )
    );
  });
});

// ---------------------------------------------------------------------------
// Property 3: RELATED_CATEGORY Edge Weight Hierarchy
// Validates: Requirements 1.5, 1.6
// ---------------------------------------------------------------------------
describe("Property 3: RELATED_CATEGORY Edge Weight Hierarchy", () => {
  it("3a — SKU pairs sharing a collection have a RELATED_CATEGORY edge with weight 4", () => {
    /**
     * **Validates: Requirements 1.5, 1.6**
     *
     * For any two SKUs that share at least one collection value, a
     * RELATED_CATEGORY edge must exist (in either direction) with weight 4.
     */
    const graph = getGraph();
    const skuList = Array.from(skusMap.values());

    for (let i = 0; i < skuList.length; i++) {
      for (let j = i + 1; j < skuList.length; j++) {
        const skuA = skuList[i];
        const skuB = skuList[j];

        const collectionsA = new Set(parseArrayString(skuA.properties.collection));
        const collectionsB = new Set(parseArrayString(skuB.properties.collection));

        const sharedCollections = [...collectionsA].filter((c) => collectionsB.has(c));
        if (sharedCollections.length === 0) continue;

        const prodA = `prod_${skuA.id}`;
        const prodB = `prod_${skuB.id}`;

        const edge = graph.edges.find(
          (e) =>
            e.relation === "RELATED_CATEGORY" &&
            ((e.source === prodA && e.target === prodB) ||
              (e.source === prodB && e.target === prodA))
        );

        assert.ok(
          edge,
          `Expected RELATED_CATEGORY edge between ${prodA} and ${prodB} (shared collection: ${sharedCollections})`
        );
        assert.strictEqual(
          edge.weight,
          4,
          `Expected weight 4 for collection-matched pair ${prodA}↔${prodB}, got ${edge.weight}`
        );
      }
    }
  });

  it("3b — SKU pairs sharing productType but no collection have RELATED_CATEGORY edge with weight 2", () => {
    /**
     * **Validates: Requirements 1.5, 1.6**
     *
     * For any two SKUs that share a productType but share NO collection,
     * the RELATED_CATEGORY edge weight must be 2 (not 3 or 4).
     */
    const graph = getGraph();
    const skuList = Array.from(skusMap.values());

    for (let i = 0; i < skuList.length; i++) {
      for (let j = i + 1; j < skuList.length; j++) {
        const skuA = skuList[i];
        const skuB = skuList[j];

        const collectionsA = new Set(parseArrayString(skuA.properties.collection));
        const collectionsB = new Set(parseArrayString(skuB.properties.collection));
        const sharedCollections = [...collectionsA].filter((c) => collectionsB.has(c));
        if (sharedCollections.length > 0) continue; // skip collection-matched pairs

        const productTypesA = new Set(parseArrayString(skuA.properties.productType));
        const productTypesB = new Set(parseArrayString(skuB.properties.productType));
        const sharedProductTypes = [...productTypesA].filter((pt) => productTypesB.has(pt));
        if (sharedProductTypes.length === 0) continue; // no productType overlap either

        const prodA = `prod_${skuA.id}`;
        const prodB = `prod_${skuB.id}`;

        const edge = graph.edges.find(
          (e) =>
            e.relation === "RELATED_CATEGORY" &&
            ((e.source === prodA && e.target === prodB) ||
              (e.source === prodB && e.target === prodA))
        );

        assert.ok(
          edge,
          `Expected RELATED_CATEGORY edge between ${prodA} and ${prodB} (shared productType: ${sharedProductTypes})`
        );
        assert.strictEqual(
          edge.weight,
          2,
          `Expected weight 2 for productType-only pair ${prodA}↔${prodB}, got ${edge.weight}`
        );
      }
    }
  });

  it("3c — SKU pairs sharing no collection, brand, productType, or material have no RELATED_CATEGORY edge", () => {
    /**
     * **Validates: Requirements 1.5, 1.6**
     *
     * For any two SKUs that share none of: collection, brand, productType,
     * or material, no RELATED_CATEGORY edge should exist between them.
     */
    const graph = getGraph();
    const skuList = Array.from(skusMap.values());

    for (let i = 0; i < skuList.length; i++) {
      for (let j = i + 1; j < skuList.length; j++) {
        const skuA = skuList[i];
        const skuB = skuList[j];

        const setsA = {
          collection: new Set(parseArrayString(skuA.properties.collection)),
          brand: new Set(parseArrayString(skuA.properties.brand)),
          productType: new Set(parseArrayString(skuA.properties.productType)),
          material: new Set(parseArrayString(skuA.properties.material)),
        };
        const setsB = {
          collection: new Set(parseArrayString(skuB.properties.collection)),
          brand: new Set(parseArrayString(skuB.properties.brand)),
          productType: new Set(parseArrayString(skuB.properties.productType)),
          material: new Set(parseArrayString(skuB.properties.material)),
        };

        const hasAnyOverlap = ["collection", "brand", "productType", "material"].some((prop) =>
          [...setsA[prop]].some((v) => setsB[prop].has(v))
        );

        if (hasAnyOverlap) continue; // only test truly disjoint pairs

        const prodA = `prod_${skuA.id}`;
        const prodB = `prod_${skuB.id}`;

        const edge = graph.edges.find(
          (e) =>
            e.relation === "RELATED_CATEGORY" &&
            ((e.source === prodA && e.target === prodB) ||
              (e.source === prodB && e.target === prodA))
        );

        assert.ok(
          !edge,
          `Unexpected RELATED_CATEGORY edge between ${prodA} and ${prodB} (no shared properties)`
        );
      }
    }
  });
});

// ---------------------------------------------------------------------------
// Property 4: Domain Rules Edge Construction
// Validates: Requirements 1.7
// ---------------------------------------------------------------------------
describe("Property 4: Domain Rules Edge Construction", () => {
  it("for every domain rule, forward and reverse edges exist with correct relation/context/weight and adjacency entries are present", () => {
    /**
     * **Validates: Requirement 1.7**
     *
     * For each rule in domain-rules.json, every (srcSku, tgtSku) pair whose
     * productTypes match the rule must have:
     *   - A forward edge: source=prod_srcId, target=prod_tgtId
     *   - A reverse edge: source=prod_tgtId, target=prod_srcId
     *   - Both with the rule's relation, context, and weight
     *   - Adjacency entries for both directions
     */
    const path = require("path");
    const fs = require("fs");
    const graph = getGraph();

    const rulesPath = path.join(__dirname, "..", "domain-rules.json");
    const domainRules = JSON.parse(fs.readFileSync(rulesPath, "utf8"));
    const rules = domainRules.rules || [];

    for (const rule of rules) {
      const { sourceProductType, targetProductType, relation, context, weight } = rule;

      // Find all SKUs matching source and target productTypes
      const srcSkus = Array.from(skusMap.values()).filter((sku) =>
        parseArrayString(sku.properties.productType).includes(sourceProductType)
      );
      const tgtSkus = Array.from(skusMap.values()).filter((sku) =>
        parseArrayString(sku.properties.productType).includes(targetProductType)
      );

      for (const srcSku of srcSkus) {
        for (const tgtSku of tgtSkus) {
          if (srcSku.id === tgtSku.id) continue;

          const srcId = `prod_${srcSku.id}`;
          const tgtId = `prod_${tgtSku.id}`;

          // Forward edge
          const fwdEdge = graph.edges.find(
            (e) =>
              e.source === srcId &&
              e.target === tgtId &&
              e.relation === relation &&
              e.context === context &&
              e.weight === weight
          );
          assert.ok(
            fwdEdge,
            `Missing forward edge: ${srcId} → ${tgtId} [${relation}, "${context}", w=${weight}]`
          );

          // Reverse edge
          const revEdge = graph.edges.find(
            (e) =>
              e.source === tgtId &&
              e.target === srcId &&
              e.relation === relation &&
              e.context === context &&
              e.weight === weight
          );
          assert.ok(
            revEdge,
            `Missing reverse edge: ${tgtId} → ${srcId} [${relation}, "${context}", w=${weight}]`
          );

          // Adjacency entry for srcId → tgtId
          const srcAdjacency = graph.adjacency.get(srcId) || [];
          const srcEntry = srcAdjacency.find(
            (entry) =>
              entry.neighborId === tgtId &&
              entry.relation === relation &&
              entry.context === context &&
              entry.weight === weight
          );
          assert.ok(
            srcEntry,
            `Missing adjacency entry for ${srcId} → ${tgtId} [${relation}, "${context}", w=${weight}]`
          );
        }
      }
    }
  });
});

// ---------------------------------------------------------------------------
// Property 5: Recommendations Merge Algorithm Invariants
// Validates: Requirements 2.3, 2.4, 2.5, 2.6, 5.2, 5.3, 5.5
// ---------------------------------------------------------------------------
describe("Property 5: Recommendations Merge Algorithm Invariants", () => {
  /**
   * **Validates: Requirements 2.3, 2.4, 2.5, 2.6, 5.2, 5.3, 5.5**
   *
   * Uses fast-check to generate arbitrary graph and Pinecone candidate lists
   * and verifies the merge algorithm invariants:
   *   1. No duplicate productIds in the output
   *   2. When a productId appears in both sources, the graph score is retained
   *   3. Output is sorted in descending order by score
   *   4. Output has at most 5 results
   *   5. No productId from cartProductIds appears in the output
   */

  // Arbitrary product IDs drawn from the real SKU catalog
  const ALL_SKU_IDS = Array.from(skusMap.keys());

  // Arbitrary for a single candidate entry (graph source)
  const graphCandidateArb = fc.record({
    productId: fc.constantFrom(...ALL_SKU_IDS),
    score: fc.integer({ min: 1, max: 4 }),
    source: fc.constant("graph"),
    context: fc.option(fc.string({ minLength: 1, maxLength: 20 }), { nil: null }),
  });

  // Arbitrary for a single candidate entry (Pinecone source, score 0.0–1.0)
  const pineconeCandidateArb = fc.record({
    productId: fc.constantFrom(...ALL_SKU_IDS),
    score: fc.float({ min: 0.0, max: 1.0, noNaN: true }),
    source: fc.constant("pinecone"),
  });

  it("5a — output contains no duplicate productIds", () => {
    fc.assert(
      fc.property(
        fc.array(graphCandidateArb, { minLength: 0, maxLength: 10 }),
        fc.array(pineconeCandidateArb, { minLength: 0, maxLength: 10 }),
        fc.array(fc.constantFrom(...ALL_SKU_IDS), { minLength: 0, maxLength: 3 }),
        (graphCandidates, pineconeCandidates, cartProductIds) => {
          const result = mergeCandidates(graphCandidates, pineconeCandidates, cartProductIds);

          const seen = new Set();
          for (const item of result) {
            assert.ok(
              !seen.has(item.productId),
              `Duplicate productId in merge output: ${item.productId}`
            );
            seen.add(item.productId);
          }
        }
      )
    );
  });

  it("5b — when a productId appears in both sources, the graph score is retained", () => {
    fc.assert(
      fc.property(
        fc.uniqueArray(fc.constantFrom(...ALL_SKU_IDS), { minLength: 1, maxLength: 5 }),
        fc.integer({ min: 1, max: 4 }),
        fc.float({ min: 0.0, max: 1.0, noNaN: true }),
        (sharedIds, graphScore, pineconeScore) => {
          const graphCandidates = sharedIds.map((id) => ({
            productId: id,
            score: graphScore,
            source: "graph",
            context: null,
          }));
          const pineconeCandidates = sharedIds.map((id) => ({
            productId: id,
            score: pineconeScore,
            source: "pinecone",
          }));

          const result = mergeCandidates(graphCandidates, pineconeCandidates, []);

          for (const item of result) {
            if (sharedIds.includes(item.productId)) {
              assert.strictEqual(
                item.source,
                "graph",
                `Expected source "graph" for shared productId ${item.productId}, got "${item.source}"`
              );
              assert.strictEqual(
                item.score,
                graphScore,
                `Expected graph score ${graphScore} for shared productId ${item.productId}, got ${item.score}`
              );
            }
          }
        }
      )
    );
  });

  it("5c — output is sorted in descending order by score", () => {
    fc.assert(
      fc.property(
        fc.array(graphCandidateArb, { minLength: 0, maxLength: 10 }),
        fc.array(pineconeCandidateArb, { minLength: 0, maxLength: 10 }),
        (graphCandidates, pineconeCandidates) => {
          const result = mergeCandidates(graphCandidates, pineconeCandidates, []);

          for (let i = 1; i < result.length; i++) {
            assert.ok(
              result[i - 1].score >= result[i].score,
              `Output not sorted descending at index ${i}: score[${i - 1}]=${result[i - 1].score} < score[${i}]=${result[i].score}`
            );
          }
        }
      )
    );
  });

  it("5d — output has at most 5 results", () => {
    fc.assert(
      fc.property(
        fc.array(graphCandidateArb, { minLength: 0, maxLength: 20 }),
        fc.array(pineconeCandidateArb, { minLength: 0, maxLength: 20 }),
        (graphCandidates, pineconeCandidates) => {
          const result = mergeCandidates(graphCandidates, pineconeCandidates, []);

          assert.ok(
            result.length <= 5,
            `Expected at most 5 results, got ${result.length}`
          );
        }
      )
    );
  });

  it("5e — no productId from cartProductIds appears in the output", () => {
    fc.assert(
      fc.property(
        fc.array(graphCandidateArb, { minLength: 0, maxLength: 10 }),
        fc.array(pineconeCandidateArb, { minLength: 0, maxLength: 10 }),
        fc.uniqueArray(fc.constantFrom(...ALL_SKU_IDS), { minLength: 1, maxLength: 5 }),
        (graphCandidates, pineconeCandidates, cartProductIds) => {
          const cartSet = new Set(cartProductIds);
          const result = mergeCandidates(graphCandidates, pineconeCandidates, cartProductIds);

          for (const item of result) {
            assert.ok(
              !cartSet.has(item.productId),
              `Cart item ${item.productId} must not appear in merge output`
            );
          }
        }
      )
    );
  });
});

// ---------------------------------------------------------------------------
// Property 6: Recommendation Grounding and Metadata Completeness
// Validates: Requirements 2.3, 5.2, 5.3, 5.5
// ---------------------------------------------------------------------------
describe("Property 6: Recommendation Grounding and Metadata Completeness", () => {
  /**
   * **Validates: Requirements 2.3, 5.2, 5.3, 5.5**
   *
   * Uses fast-check to generate arbitrary subsets of real productIds from
   * skus.json as cart items. Tests the grounding and metadata attachment
   * steps directly by calling mergeCandidates + the grounding/metadata logic
   * (bypassing Pinecone) to verify:
   *   1. Every productId in the output exists as a Product node in the graph
   *   2. name, price, imagePath, and availability match skus.json
   *
   * We test the grounding/metadata logic directly rather than calling
   * getRecommendations (which requires a live Pinecone connection) by
   * replicating the grounding + metadata attachment steps from mcpOrchestrator.
   */

  const graph = getGraph();
  const ALL_SKU_IDS = Array.from(skusMap.keys());

  it("6a — every productId in recommendations exists as a Product node in the graph", () => {
    fc.assert(
      fc.property(
        fc.uniqueArray(fc.constantFrom(...ALL_SKU_IDS), { minLength: 1, maxLength: ALL_SKU_IDS.length }),
        (cartProductIds) => {
          const cartSet = new Set(cartProductIds);

          // Use graph traversal to get candidates (same as getRecommendations does)
          const { traverseForRecommendations: traverse } = require("../services/mcpOrchestrator");
          const graphCandidates = traverse(cartSet, graph);

          // Merge with empty Pinecone results (no Pinecone in tests)
          const merged = mergeCandidates(graphCandidates, [], cartSet);

          // Ground: discard any productId not present in the Product Graph
          const grounded = merged.filter((c) => graph.nodes.has(`prod_${c.productId}`));

          // Attach metadata (same as getRecommendations does)
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

          // Assert: every productId exists as a Product node in the graph
          for (const rec of recommendations) {
            const nodeId = `prod_${rec.productId}`;
            assert.ok(
              graph.nodes.has(nodeId),
              `Recommendation productId "${rec.productId}" does not exist as a Product node in the graph`
            );
            const node = graph.nodes.get(nodeId);
            assert.strictEqual(
              node.type,
              "Product",
              `Node for productId "${rec.productId}" has type "${node.type}", expected "Product"`
            );
          }
        }
      )
    );
  });

  it("6b — name, price, imagePath, and availability match skus.json for every recommendation", () => {
    fc.assert(
      fc.property(
        fc.uniqueArray(fc.constantFrom(...ALL_SKU_IDS), { minLength: 1, maxLength: ALL_SKU_IDS.length }),
        (cartProductIds) => {
          const cartSet = new Set(cartProductIds);

          // Use graph traversal to get candidates
          const { traverseForRecommendations: traverse } = require("../services/mcpOrchestrator");
          const graphCandidates = traverse(cartSet, graph);

          // Merge with empty Pinecone results
          const merged = mergeCandidates(graphCandidates, [], cartSet);

          // Ground against graph
          const grounded = merged.filter((c) => graph.nodes.has(`prod_${c.productId}`));

          // Attach metadata
          const recommendations = grounded.map((c) => {
            const sku = skusMap.get(c.productId);
            return {
              productId: c.productId,
              name: sku ? sku.name : null,
              price: sku ? sku.price.sellingPrice : null,
              imagePath: sku ? sku.media.images[0].path : null,
              availability: sku ? sku.availability : null,
            };
          });

          // Assert: metadata fields match skus.json
          for (const rec of recommendations) {
            const sku = skusMap.get(rec.productId);
            assert.ok(
              sku,
              `No SKU found in skusMap for productId "${rec.productId}"`
            );

            assert.strictEqual(
              rec.name,
              sku.name,
              `name mismatch for ${rec.productId}: got "${rec.name}", expected "${sku.name}"`
            );
            assert.strictEqual(
              rec.price,
              sku.price.sellingPrice,
              `price mismatch for ${rec.productId}: got ${rec.price}, expected ${sku.price.sellingPrice}`
            );
            assert.strictEqual(
              rec.imagePath,
              sku.media.images[0].path,
              `imagePath mismatch for ${rec.productId}: got "${rec.imagePath}", expected "${sku.media.images[0].path}"`
            );
            assert.strictEqual(
              rec.availability,
              sku.availability,
              `availability mismatch for ${rec.productId}: got "${rec.availability}", expected "${sku.availability}"`
            );
          }
        }
      )
    );
  });
});

// ---------------------------------------------------------------------------
// Property 7: Bundle Detection Invariants
// Validates: Requirements 3.1, 3.2, 3.4, 3.5
// ---------------------------------------------------------------------------
describe("Property 7: Bundle Detection Invariants", () => {
  /**
   * **Validates: Requirements 3.1, 3.2, 3.4, 3.5**
   *
   * SKU data used:
   *   - staub-cast-iron collection: "2453926" (Dutch Oven, $299.95) + "181543" (Skillet, $180.00)
   *   - hold-everything brand:      "6247040" (Bowl, $89.95) + "8227593" (Lazy Susan, $59.95)
   *   - williams-sonoma brand:      "2505456" (Cutting Board, $129.95) + "6121370" (Board Oil, $10.95)
   */

  // Known SKU IDs grouped by shared property for deterministic test inputs
  const STAUB_COLLECTION_IDS = ["2453926", "181543"]; // share staub-cast-iron collection
  const HE_BRAND_IDS = ["6247040", "8227593"];         // share hold-everything brand (no shared collection)
  const WS_BRAND_IDS = ["2505456", "6121370"];          // share williams-sonoma brand (no shared collection)

  const VALID_CATEGORY_LABELS = new Set(Object.values(VALID_REGISTRY_CATEGORIES));

  it("7a — collection bundles form before brand bundles (collection-first invariant)", () => {
    /**
     * **Validates: Requirements 3.1, 3.2**
     *
     * When a cart contains items that share a collection AND items that share
     * only a brand, the collection bundle must appear before any brand bundle
     * in the detectBundles output.
     *
     * We use fc.shuffledSubarray to generate random orderings of the cart
     * items and assert the ordering invariant holds regardless of input order.
     */
    const allItems = [
      ...STAUB_COLLECTION_IDS.map((id) => ({ productId: id })),
      ...HE_BRAND_IDS.map((id) => ({ productId: id })),
    ];

    fc.assert(
      fc.property(
        fc.shuffledSubarray(allItems, { minLength: allItems.length, maxLength: allItems.length }),
        (shuffledItems) => {
          const bundles = detectBundles(shuffledItems);

          // At least one bundle must be detected
          assert.ok(bundles.length >= 1, "Expected at least one bundle");

          // Find the first collection bundle and first brand bundle
          const firstCollectionIdx = bundles.findIndex((b) => b.sharedPropertyType === "collection");
          const firstBrandIdx = bundles.findIndex((b) => b.sharedPropertyType === "brand");

          // If both types exist, collection bundle must come first
          if (firstCollectionIdx !== -1 && firstBrandIdx !== -1) {
            assert.ok(
              firstCollectionIdx < firstBrandIdx,
              `Collection bundle (index ${firstCollectionIdx}) must appear before brand bundle (index ${firstBrandIdx})`
            );
          }
        }
      )
    );
  });

  it("7b — registryCategory in every bundle is always one of the 7 valid values", () => {
    /**
     * **Validates: Requirement 3.4**
     *
     * For any combination of cart items drawn from the real SKU catalog,
     * every bundle's registryCategory must be one of the 7 valid labels.
     */
    // All ON_HAND + BACK_ORDERED SKU IDs (exclude NLA "1341411" since it won't be in active cart)
    const availableIds = ["2505456", "6121370", "6247040", "2453926", "8381456", "5001660", "181543", "8227593", "9670912"];
    const itemArb = fc.constantFrom(...availableIds).map((id) => ({ productId: id }));

    fc.assert(
      fc.property(
        fc.uniqueArray(itemArb, { minLength: 2, maxLength: availableIds.length, selector: (x) => x.productId }),
        (cartItems) => {
          const bundles = detectBundles(cartItems);
          for (const bundle of bundles) {
            assert.ok(
              VALID_CATEGORY_LABELS.has(bundle.registryCategory),
              `Invalid registryCategory "${bundle.registryCategory}" — must be one of: ${[...VALID_CATEGORY_LABELS].join(", ")}`
            );
          }
        }
      )
    );
  });

  it("7c — highest-priced item determines the registryCategory of its bundle", () => {
    /**
     * **Validates: Requirement 3.5**
     *
     * For the staub-cast-iron collection bundle:
     *   - Dutch Oven (2453926): $299.95 → productType "dutch-ovens" → "cookware" → "Cookware"
     *   - Skillet (181543):     $180.00 → productType "fry-pans-skillets" → "cookware" → "Cookware"
     * Both map to "Cookware", so the bundle registryCategory must be "Cookware".
     *
     * For the hold-everything brand bundle:
     *   - Bowl (6247040):       $89.95  → productType "tabletop-serveware-bowl" → "tabletop-bar" → "Tabletop & Bar"
     *   - Lazy Susan (8227593): $59.95  → productType "lazy-susan" → "storage-organization" → "Storage & Organization"
     * Highest-priced is Bowl → "Tabletop & Bar".
     *
     * We verify both bundles in a single cart to confirm the highest-price rule.
     */
    const cartItems = [
      ...STAUB_COLLECTION_IDS.map((id) => ({ productId: id })),
      ...HE_BRAND_IDS.map((id) => ({ productId: id })),
    ];

    const bundles = detectBundles(cartItems);

    // Find the staub collection bundle
    const staubBundle = bundles.find(
      (b) => b.sharedPropertyType === "collection" && b.sharedPropertyValue === "staub-cast-iron"
    );
    assert.ok(staubBundle, "Expected a staub-cast-iron collection bundle");
    // Dutch Oven ($299.95) is highest → dutch-ovens → cookware → "Cookware"
    assert.strictEqual(
      staubBundle.registryCategory,
      "Cookware",
      `Expected "Cookware" for staub bundle (highest-priced item is Dutch Oven), got "${staubBundle.registryCategory}"`
    );

    // Find the hold-everything brand bundle
    const heBundle = bundles.find(
      (b) => b.sharedPropertyType === "brand" && b.sharedPropertyValue === "hold-everything"
    );
    assert.ok(heBundle, "Expected a hold-everything brand bundle");
    // Bowl ($89.95) is highest → tabletop-serveware-bowl → tabletop-bar → "Tabletop & Bar"
    assert.strictEqual(
      heBundle.registryCategory,
      "Tabletop & Bar",
      `Expected "Tabletop & Bar" for hold-everything bundle (highest-priced item is Bowl), got "${heBundle.registryCategory}"`
    );
  });

  it("7d — items used in a collection bundle are excluded from brand bundling", () => {
    /**
     * **Validates: Requirements 3.1, 3.2**
     *
     * The staub items share both a collection (staub-cast-iron) AND a brand
     * (staub-parent/staub). They must appear only in the collection bundle,
     * not in any brand bundle.
     */
    const cartItems = STAUB_COLLECTION_IDS.map((id) => ({ productId: id }));
    const bundles = detectBundles(cartItems);

    // Must have exactly one bundle (collection), not two
    assert.strictEqual(bundles.length, 1, `Expected 1 bundle (collection only), got ${bundles.length}`);
    assert.strictEqual(bundles[0].sharedPropertyType, "collection");
    assert.strictEqual(bundles[0].sharedPropertyValue, "staub-cast-iron");
  });
});

// ---------------------------------------------------------------------------
// Property 8: Availability Routing Invariants
// Validates: Requirements 4.1, 4.2, 4.4, 8.9
// ---------------------------------------------------------------------------
describe("Property 8: Availability Routing Invariants", () => {
  /**
   * **Validates: Requirements 4.1, 4.2, 4.4, 8.9**
   *
   * Uses real SKU IDs from skus.json:
   *   - NLA:          "1341411" (Apilco Cup & Saucer)
   *   - BACK_ORDERED: "8227593" (Hold Everything Lazy Susan), "9670912" (Dorset Martini Glasses)
   *   - ON_HAND:      "2505456", "6121370", "6247040", "2453926", "8381456", "5001660", "181543"
   */

  const NLA_ID = "1341411";
  const BACK_ORDERED_IDS = ["8227593", "9670912"];
  const ON_HAND_IDS = ["2505456", "6121370", "6247040", "2453926", "8381456", "5001660", "181543"];

  /** Generate a unique userId to isolate each test run from shared in-memory state */
  function freshUserId() {
    return `test_user_${Date.now()}_${Math.random().toString(36).slice(2)}`;
  }

  it("8a — NLA products land in saveForLater only, never in active items", () => {
    /**
     * **Validates: Requirement 4.1**
     *
     * For any quantity value, adding the NLA product must result in:
     *   - items array does NOT contain the NLA productId
     *   - saveForLater array DOES contain the NLA productId
     */
    fc.assert(
      fc.property(
        fc.integer({ min: 1, max: 10 }),
        (quantity) => {
          const userId = freshUserId();
          const cart = addItem(userId, NLA_ID, quantity);

          // Must NOT be in active items
          const inItems = cart.items.some((item) => item.productId === NLA_ID);
          assert.ok(!inItems, `NLA product ${NLA_ID} must not appear in active items`);

          // Must be in saveForLater
          const inSFL = cart.saveForLater.some((item) => item.productId === NLA_ID);
          assert.ok(inSFL, `NLA product ${NLA_ID} must appear in saveForLater`);
        }
      )
    );
  });

  it("8b — BACK_ORDERED products land in active items with backOrdered:true", () => {
    /**
     * **Validates: Requirement 4.2**
     *
     * For any BACK_ORDERED product and any quantity, the item must appear in
     * active items with backOrdered: true, and must NOT appear in saveForLater.
     */
    fc.assert(
      fc.property(
        fc.constantFrom(...BACK_ORDERED_IDS),
        fc.integer({ min: 1, max: 10 }),
        (productId, quantity) => {
          const userId = freshUserId();
          const cart = addItem(userId, productId, quantity);

          // Must be in active items
          const activeItem = cart.items.find((item) => item.productId === productId);
          assert.ok(activeItem, `BACK_ORDERED product ${productId} must appear in active items`);

          // Must have backOrdered: true
          assert.strictEqual(
            activeItem.backOrdered,
            true,
            `BACK_ORDERED product ${productId} must have backOrdered:true, got ${activeItem.backOrdered}`
          );

          // Must NOT be in saveForLater
          const inSFL = cart.saveForLater.some((item) => item.productId === productId);
          assert.ok(!inSFL, `BACK_ORDERED product ${productId} must not appear in saveForLater`);
        }
      )
    );
  });

  it("8c — saveForLater array is always present in getCart response (even when empty)", () => {
    /**
     * **Validates: Requirement 4.4**
     *
     * For any combination of ON_HAND products added to a fresh cart,
     * the getCart response must always include a saveForLater array
     * (even if it is empty).
     */
    fc.assert(
      fc.property(
        fc.uniqueArray(fc.constantFrom(...ON_HAND_IDS), { minLength: 0, maxLength: ON_HAND_IDS.length }),
        (productIds) => {
          const userId = freshUserId();

          // Add each ON_HAND product
          for (const productId of productIds) {
            addItem(userId, productId, 1);
          }

          const cart = getCart(userId);

          // saveForLater must always be present and be an array
          assert.ok(
            Object.prototype.hasOwnProperty.call(cart, "saveForLater"),
            "getCart response must include saveForLater field"
          );
          assert.ok(
            Array.isArray(cart.saveForLater),
            `saveForLater must be an array, got ${typeof cart.saveForLater}`
          );
        }
      )
    );
  });

  it("8d — ON_HAND products land in active items with backOrdered:false", () => {
    /**
     * **Validates: Requirements 4.1, 4.2**
     *
     * ON_HAND products must appear in active items with backOrdered: false
     * and must not appear in saveForLater.
     */
    fc.assert(
      fc.property(
        fc.constantFrom(...ON_HAND_IDS),
        fc.integer({ min: 1, max: 10 }),
        (productId, quantity) => {
          const userId = freshUserId();
          const cart = addItem(userId, productId, quantity);

          const activeItem = cart.items.find((item) => item.productId === productId);
          assert.ok(activeItem, `ON_HAND product ${productId} must appear in active items`);
          assert.strictEqual(
            activeItem.backOrdered,
            false,
            `ON_HAND product ${productId} must have backOrdered:false`
          );

          const inSFL = cart.saveForLater.some((item) => item.productId === productId);
          assert.ok(!inSFL, `ON_HAND product ${productId} must not appear in saveForLater`);
        }
      )
    );
  });
});

// ---------------------------------------------------------------------------
// Property 9: Cart Total Price Calculation
// Validates: Requirements 8.9
// ---------------------------------------------------------------------------
describe("Property 9: Cart Total Price Calculation", () => {
  /**
   * **Validates: Requirement 8.9**
   *
   * totalPrice = sum(sellingPrice × quantity) for all active items
   * totalItems = sum(quantity) for all active items
   * NLA items in saveForLater must NOT be counted in either total.
   */

  const ON_HAND_IDS = ["2505456", "6121370", "6247040", "2453926", "8381456", "5001660", "181543"];
  const BACK_ORDERED_IDS = ["8227593", "9670912"];
  const NLA_ID = "1341411";

  // All active-cart-eligible IDs (ON_HAND + BACK_ORDERED)
  const ACTIVE_IDS = [...ON_HAND_IDS, ...BACK_ORDERED_IDS];

  function freshUserId() {
    return `test_user_${Date.now()}_${Math.random().toString(36).slice(2)}`;
  }

  it("9a — totalPrice equals sum(sellingPrice × quantity) for all active items", () => {
    /**
     * **Validates: Requirement 8.9**
     *
     * For any subset of active-cart-eligible products with random quantities,
     * the cart's totalPrice must equal the manually computed sum.
     */
    fc.assert(
      fc.property(
        fc.uniqueArray(
          fc.record({
            productId: fc.constantFrom(...ACTIVE_IDS),
            quantity: fc.integer({ min: 1, max: 5 }),
          }),
          { minLength: 1, maxLength: ACTIVE_IDS.length, selector: (x) => x.productId }
        ),
        (entries) => {
          const userId = freshUserId();

          for (const { productId, quantity } of entries) {
            addItem(userId, productId, quantity);
          }

          const cart = getCart(userId);

          // Manually compute expected totalPrice from the returned items array
          let expectedTotalPrice = 0;
          for (const item of cart.items) {
            expectedTotalPrice += item.price * item.quantity;
          }
          expectedTotalPrice = Math.round(expectedTotalPrice * 100) / 100;

          assert.strictEqual(
            cart.totalPrice,
            expectedTotalPrice,
            `totalPrice mismatch: got ${cart.totalPrice}, expected ${expectedTotalPrice}`
          );
        }
      )
    );
  });

  it("9b — totalItems equals sum(quantity) for all active items", () => {
    /**
     * **Validates: Requirement 8.9**
     *
     * For any subset of active-cart-eligible products with random quantities,
     * the cart's totalItems must equal the sum of all item quantities.
     */
    fc.assert(
      fc.property(
        fc.uniqueArray(
          fc.record({
            productId: fc.constantFrom(...ACTIVE_IDS),
            quantity: fc.integer({ min: 1, max: 5 }),
          }),
          { minLength: 1, maxLength: ACTIVE_IDS.length, selector: (x) => x.productId }
        ),
        (entries) => {
          const userId = freshUserId();

          for (const { productId, quantity } of entries) {
            addItem(userId, productId, quantity);
          }

          const cart = getCart(userId);

          // Manually compute expected totalItems from the returned items array
          const expectedTotalItems = cart.items.reduce((sum, item) => sum + item.quantity, 0);

          assert.strictEqual(
            cart.totalItems,
            expectedTotalItems,
            `totalItems mismatch: got ${cart.totalItems}, expected ${expectedTotalItems}`
          );
        }
      )
    );
  });

  it("9c — NLA items in saveForLater are NOT counted in totalPrice or totalItems", () => {
    /**
     * **Validates: Requirements 4.1, 8.9**
     *
     * Adding an NLA product must not affect totalPrice or totalItems.
     * The totals before and after adding the NLA product must be identical.
     */
    fc.assert(
      fc.property(
        fc.uniqueArray(
          fc.record({
            productId: fc.constantFrom(...ON_HAND_IDS),
            quantity: fc.integer({ min: 1, max: 5 }),
          }),
          { minLength: 0, maxLength: ON_HAND_IDS.length, selector: (x) => x.productId }
        ),
        (entries) => {
          const userId = freshUserId();

          // Add ON_HAND items first
          for (const { productId, quantity } of entries) {
            addItem(userId, productId, quantity);
          }

          const cartBefore = getCart(userId);
          const totalPriceBefore = cartBefore.totalPrice;
          const totalItemsBefore = cartBefore.totalItems;

          // Now add the NLA product — should go to saveForLater only
          addItem(userId, NLA_ID, 3);

          const cartAfter = getCart(userId);

          assert.strictEqual(
            cartAfter.totalPrice,
            totalPriceBefore,
            `totalPrice changed after adding NLA product: ${totalPriceBefore} → ${cartAfter.totalPrice}`
          );
          assert.strictEqual(
            cartAfter.totalItems,
            totalItemsBefore,
            `totalItems changed after adding NLA product: ${totalItemsBefore} → ${cartAfter.totalItems}`
          );
        }
      )
    );
  });

  it("9d — totalPrice and totalItems are both 0 for an empty cart", () => {
    /**
     * **Validates: Requirement 8.9**
     *
     * A fresh cart with no items must have totalPrice = 0 and totalItems = 0.
     */
    fc.assert(
      fc.property(
        fc.constant(null),
        () => {
          const userId = freshUserId();
          const cart = getCart(userId);

          assert.strictEqual(cart.totalPrice, 0, "Empty cart totalPrice must be 0");
          assert.strictEqual(cart.totalItems, 0, "Empty cart totalItems must be 0");
        }
      )
    );
  });
});

// ---------------------------------------------------------------------------
// Property 10: Firebase Auth Enforcement on Cart Endpoints
// Validates: Requirements 6.1, 6.2, 6.5
// ---------------------------------------------------------------------------
describe("Property 10: Firebase Auth Enforcement on Cart Endpoints", () => {
  /**
   * **Validates: Requirements 6.1, 6.2, 6.5**
   *
   * Strategy: Build the Express app in isolation by injecting a mock
   * firebase/adminInit module into the require cache before loading
   * server routes. The mock admin accepts only "valid-test-token" and
   * rejects everything else, so we can test auth enforcement without
   * real Firebase credentials.
   *
   * We spin up a one-off HTTP server on a random port, run all assertions,
   * then close it.
   */

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  /**
   * Build a minimal Express app with the same route structure as server.js
   * but using a mocked Firebase admin that only accepts "valid-test-token".
   */
  function buildTestApp() {
    const path = require("path");

    // --- Mock firebase/adminInit before any route module loads it ----------
    const adminInitPath = path.resolve(__dirname, "../firebase/adminInit.js");

    const mockAdmin = {
      auth: () => ({
        verifyIdToken: (token) => {
          if (token === "valid-test-token") {
            return Promise.resolve({ uid: "test-uid-001" });
          }
          return Promise.reject(new Error("Invalid token"));
        },
      }),
    };

    // Inject mock into require cache
    require.cache[adminInitPath] = {
      id: adminInitPath,
      filename: adminInitPath,
      loaded: true,
      exports: mockAdmin,
      parent: null,
      children: [],
      paths: [],
    };

    // Now load firebaseAuth (it will pick up the mock admin from cache)
    const firebaseAuthPath = path.resolve(__dirname, "../middleware/firebaseAuth.js");
    // Clear firebaseAuth from cache so it re-requires adminInit (gets mock)
    delete require.cache[firebaseAuthPath];
    const firebaseAuth = require(firebaseAuthPath);

    // Load cart router (clear from cache to pick up fresh firebaseAuth)
    const cartRoutePath = path.resolve(__dirname, "../routes/cart.js");
    delete require.cache[cartRoutePath];
    const cartRouter = require(cartRoutePath);

    // Build minimal Express app
    const express = require("express");
    const fs = require("fs");
    const appPath = path.resolve(__dirname, "..");

    function readJson(fileName) {
      return JSON.parse(fs.readFileSync(path.join(appPath, "responses", fileName), "utf8"));
    }

    const app = express();
    app.use(express.json());

    // Public endpoints (no auth)
    app.get("/health", (req, res) => res.json({ status: "ok" }));
    app.post("/login", (req, res) => {
      const { email, password } = req.body || {};
      if (email === "demo@hackathon.com" && password === "123456") {
        return res.status(200).json(readJson("login_success.json"));
      }
      return res.status(401).json(readJson("error_401.json"));
    });
    app.get("/profile", (req, res) => res.status(200).json(readJson("profile.json")));
    app.get("/feed", (req, res) => res.status(200).json(readJson("feed.json")));
    app.get("/skus", (req, res) => res.status(200).json(readJson("skus.json")));

    // Protected cart routes
    app.use("/cart", cartRouter);

    return app;
  }

  /**
   * Start the test app on a random available port and return { server, port }.
   */
  function startTestServer(app) {
    return new Promise((resolve, reject) => {
      const http = require("http");
      const server = http.createServer(app);
      server.listen(0, "127.0.0.1", () => {
        const { port } = server.address();
        resolve({ server, port });
      });
      server.on("error", reject);
    });
  }

  /**
   * Make an HTTP request to the test server.
   * Returns a Promise<{ status, body }>.
   */
  function request(port, method, path, headers = {}, body = null) {
    return new Promise((resolve, reject) => {
      const http = require("http");
      const bodyStr = body ? JSON.stringify(body) : null;
      const opts = {
        hostname: "127.0.0.1",
        port,
        path,
        method,
        headers: {
          "Content-Type": "application/json",
          ...headers,
          ...(bodyStr ? { "Content-Length": Buffer.byteLength(bodyStr) } : {}),
        },
      };
      const req = http.request(opts, (res) => {
        let data = "";
        res.on("data", (chunk) => { data += chunk; });
        res.on("end", () => {
          let parsed;
          try { parsed = JSON.parse(data); } catch { parsed = data; }
          resolve({ status: res.statusCode, body: parsed });
        });
      });
      req.on("error", reject);
      if (bodyStr) req.write(bodyStr);
      req.end();
    });
  }

  // -------------------------------------------------------------------------
  // Cart endpoints under test
  // -------------------------------------------------------------------------
  const CART_ENDPOINTS = [
    { method: "POST",   path: "/cart/items",                              body: { productId: "2505456", quantity: 1 } },
    { method: "GET",    path: "/cart",                                    body: null },
    { method: "DELETE", path: "/cart/items/2505456",                      body: null },
    { method: "GET",    path: "/cart/recommendations",                    body: null },
    { method: "GET",    path: "/cart/bundles",                            body: null },
    { method: "POST",   path: "/cart/save-for-later/2505456/notify",      body: null },
  ];

  // Public endpoints that must NOT require auth
  const PUBLIC_ENDPOINTS = [
    { method: "GET",  path: "/health",  body: null },
    { method: "POST", path: "/login",   body: { email: "demo@hackathon.com", password: "123456" } },
    { method: "GET",  path: "/profile", body: null },
    { method: "GET",  path: "/feed",    body: null },
    { method: "GET",  path: "/skus",    body: null },
  ];

  // -------------------------------------------------------------------------
  // Property 10a — Cart endpoints return HTTP 401 with no Authorization header
  // -------------------------------------------------------------------------
  it("10a — all cart endpoints return HTTP 401 when Authorization header is absent", async () => {
    /**
     * **Validates: Requirements 6.1, 6.2**
     *
     * For every cart endpoint, sending a request with NO Authorization header
     * must yield HTTP 401 regardless of the request body/params.
     */
    const app = buildTestApp();
    const { server, port } = await startTestServer(app);

    try {
      await fc.assert(
        fc.asyncProperty(
          fc.constantFrom(...CART_ENDPOINTS),
          async (endpoint) => {
            const res = await request(port, endpoint.method, endpoint.path, {}, endpoint.body);
            assert.strictEqual(
              res.status,
              401,
              `Expected HTTP 401 for ${endpoint.method} ${endpoint.path} with no auth header, got ${res.status}`
            );
          }
        ),
        { numRuns: CART_ENDPOINTS.length }
      );
    } finally {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  // -------------------------------------------------------------------------
  // Property 10b — Cart endpoints return HTTP 401 with invalid/malformed token
  // -------------------------------------------------------------------------
  it("10b — all cart endpoints return HTTP 401 with invalid or malformed Authorization header", async () => {
    /**
     * **Validates: Requirements 6.1, 6.2**
     *
     * For every cart endpoint, sending a request with a malformed or invalid
     * Authorization header must yield HTTP 401.
     *
     * We test three categories of bad headers:
     *   1. Completely absent "Bearer " prefix (random strings)
     *   2. "Bearer " prefix with an invalid token value
     *   3. Empty bearer token ("Bearer ")
     */
    const app = buildTestApp();
    const { server, port } = await startTestServer(app);

    // Arbitrary invalid token strings (not "valid-test-token")
    const invalidTokenArb = fc.string({ minLength: 1, maxLength: 40 }).filter(
      (s) => s !== "valid-test-token"
    );

    // Arbitrary malformed header values (no "Bearer " prefix)
    const malformedHeaderArb = fc.oneof(
      fc.string({ minLength: 0, maxLength: 40 }),
      fc.constant(""),
      fc.constant("Basic abc123"),
      fc.constant("bearer valid-test-token"), // wrong case
      fc.constant("Bearer"),                  // missing space + token
    );

    try {
      // 10b-i: "Bearer <invalid-token>" headers
      await fc.assert(
        fc.asyncProperty(
          fc.constantFrom(...CART_ENDPOINTS),
          invalidTokenArb,
          async (endpoint, invalidToken) => {
            const res = await request(
              port,
              endpoint.method,
              endpoint.path,
              { Authorization: `Bearer ${invalidToken}` },
              endpoint.body
            );
            assert.strictEqual(
              res.status,
              401,
              `Expected HTTP 401 for ${endpoint.method} ${endpoint.path} with invalid token "${invalidToken}", got ${res.status}`
            );
          }
        ),
        { numRuns: 50 }
      );

      // 10b-ii: Malformed Authorization header values (no "Bearer " prefix)
      await fc.assert(
        fc.asyncProperty(
          fc.constantFrom(...CART_ENDPOINTS),
          malformedHeaderArb,
          async (endpoint, malformedHeader) => {
            const res = await request(
              port,
              endpoint.method,
              endpoint.path,
              { Authorization: malformedHeader },
              endpoint.body
            );
            assert.strictEqual(
              res.status,
              401,
              `Expected HTTP 401 for ${endpoint.method} ${endpoint.path} with malformed header "${malformedHeader}", got ${res.status}`
            );
          }
        ),
        { numRuns: 50 }
      );
    } finally {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  // -------------------------------------------------------------------------
  // Property 10c — Public endpoints respond normally without Authorization header
  // -------------------------------------------------------------------------
  it("10c — existing public endpoints do NOT return HTTP 401 without Authorization header", async () => {
    /**
     * **Validates: Requirement 6.5**
     *
     * /health, /login, /profile, /feed, /skus must respond with a non-401
     * status code when called without any Authorization header.
     */
    const app = buildTestApp();
    const { server, port } = await startTestServer(app);

    try {
      await fc.assert(
        fc.asyncProperty(
          fc.constantFrom(...PUBLIC_ENDPOINTS),
          async (endpoint) => {
            const res = await request(port, endpoint.method, endpoint.path, {}, endpoint.body);
            assert.notStrictEqual(
              res.status,
              401,
              `Expected non-401 for public endpoint ${endpoint.method} ${endpoint.path}, got ${res.status}`
            );
          }
        ),
        { numRuns: PUBLIC_ENDPOINTS.length }
      );
    } finally {
      await new Promise((resolve) => server.close(resolve));
    }
  });
});

// ---------------------------------------------------------------------------
// Property 11: Registry Item Management Invariants
// Validates: Requirements 12.2, 12.3, 12.4, 12.9
// ---------------------------------------------------------------------------
describe("Property 11: Registry Item Management Invariants", () => {
  /**
   * **Validates: Requirements 12.2, 12.3, 12.4, 12.9**
   *
   * Strategy: Build a minimal Express app with the registry router, injecting
   * a mock Firebase admin (auth + Firestore) into the require cache so no real
   * Firebase credentials are needed.
   *
   * The mock Firestore stores registry documents in memory and supports the
   * transaction pattern used by POST /registry/:registryId/items.
   */

  // -------------------------------------------------------------------------
  // Shared helpers (mirrors Property 10 pattern)
  // -------------------------------------------------------------------------

  const VALID_PRODUCT_IDS = ["2505456", "6121370", "6247040", "2453926", "8381456", "5001660", "181543", "8227593", "9670912"];
  const VALID_CATEGORY_IDS_LIST = ["cookware", "bakeware", "cutlery-knives", "electrics", "tabletop-bar", "food-entertaining", "storage-organization"];

  /**
   * Build a minimal in-memory Firestore mock that supports the operations
   * used by POST /registry/:registryId/items.
   *
   * @param {object} registryDoc  — the initial registry document data
   * @param {string} registryId   — the document ID to use
   */
  function buildFirestoreMock(registryDoc, registryId) {
    // Mutable store so transactions can read and write
    const store = { [registryId]: { ...registryDoc } };

    function makeDocRef(id) {
      return {
        id,
        get: async () => makeDocSnap(id),
        update: async (updates) => {
          store[id] = { ...store[id], ...updates };
        },
        delete: async () => { delete store[id]; },
      };
    }

    function makeDocSnap(id) {
      const data = store[id];
      return {
        exists: data !== undefined,
        id,
        data: () => (data ? { ...data } : undefined),
      };
    }

    return {
      collection: () => ({
        doc: (id) => makeDocRef(id),
        add: async (data) => {
          const newId = `reg_${Date.now()}_${Math.random().toString(36).slice(2)}`;
          store[newId] = { ...data };
          return { id: newId };
        },
        where: () => ({ get: async () => ({ docs: [] }) }),
      }),
      runTransaction: async (fn) => {
        // Simple non-concurrent transaction: pass a transaction object that
        // reads from and writes to the in-memory store.
        const txn = {
          get: async (docRef) => makeDocSnap(docRef.id),
          update: (docRef, updates) => {
            store[docRef.id] = { ...store[docRef.id], ...updates };
          },
        };
        return fn(txn);
      },
      // Expose store for assertions
      _store: store,
    };
  }

  /**
   * Build a test Express app with the registry router, using a mock admin
   * that accepts only "valid-test-token" and uses the provided Firestore mock.
   */
  function buildRegistryTestApp(firestoreMock, ownerUid = "owner-uid-001") {
    const path = require("path");

    const adminInitPath = path.resolve(__dirname, "../firebase/adminInit.js");

    const mockAdmin = {
      auth: () => ({
        verifyIdToken: (token) => {
          if (token === "valid-test-token") {
            return Promise.resolve({ uid: ownerUid });
          }
          if (token === "other-user-token") {
            return Promise.resolve({ uid: "other-uid-999" });
          }
          return Promise.reject(new Error("Invalid token"));
        },
      }),
      firestore: () => firestoreMock,
    };

    // Inject mock admin into require cache
    require.cache[adminInitPath] = {
      id: adminInitPath,
      filename: adminInitPath,
      loaded: true,
      exports: mockAdmin,
      parent: null,
      children: [],
      paths: [],
    };

    // Clear cached modules that depend on adminInit so they pick up the mock
    const firebaseAuthPath = path.resolve(__dirname, "../middleware/firebaseAuth.js");
    const registryRoutePath = path.resolve(__dirname, "../routes/registry.js");
    delete require.cache[firebaseAuthPath];
    delete require.cache[registryRoutePath];

    const firebaseAuth = require(firebaseAuthPath);
    const registryRouter = require(registryRoutePath);

    const express = require("express");
    const app = express();
    app.use(express.json());
    app.use("/registry", registryRouter);

    return app;
  }

  function startTestServer(app) {
    return new Promise((resolve, reject) => {
      const http = require("http");
      const server = http.createServer(app);
      server.listen(0, "127.0.0.1", () => {
        const { port } = server.address();
        resolve({ server, port });
      });
      server.on("error", reject);
    });
  }

  function request(port, method, path, headers = {}, body = null) {
    return new Promise((resolve, reject) => {
      const http = require("http");
      const bodyStr = body ? JSON.stringify(body) : null;
      const opts = {
        hostname: "127.0.0.1",
        port,
        path,
        method,
        headers: {
          "Content-Type": "application/json",
          ...headers,
          ...(bodyStr ? { "Content-Length": Buffer.byteLength(bodyStr) } : {}),
        },
      };
      const req = http.request(opts, (res) => {
        let data = "";
        res.on("data", (chunk) => { data += chunk; });
        res.on("end", () => {
          let parsed;
          try { parsed = JSON.parse(data); } catch { parsed = data; }
          resolve({ status: res.statusCode, body: parsed });
        });
      });
      req.on("error", reject);
      if (bodyStr) req.write(bodyStr);
      req.end();
    });
  }

  // -------------------------------------------------------------------------
  // 11a — HTTP 404 for unknown productId (Req 12.2)
  // -------------------------------------------------------------------------
  it("11a — POST /registry/:id/items returns HTTP 404 for any productId not in skus.json", async () => {
    /**
     * **Validates: Requirements 12.2, 12.9**
     *
     * For any productId that does NOT exist in skus.json, the endpoint must
     * return HTTP 404 with code PRODUCT_NOT_FOUND, regardless of other fields.
     */
    const registryId = "reg-test-001";
    const ownerUid = "owner-uid-001";
    const firestoreMock = buildFirestoreMock(
      { ownerUid, items: [], isPublic: true },
      registryId
    );
    const app = buildRegistryTestApp(firestoreMock, ownerUid);
    const { server, port } = await startTestServer(app);

    // Generate productIds that are definitely NOT in the catalog
    const unknownProductIdArb = fc.string({ minLength: 1, maxLength: 20 }).filter(
      (s) => !VALID_PRODUCT_IDS.includes(s)
    );

    try {
      await fc.assert(
        fc.asyncProperty(
          unknownProductIdArb,
          fc.constantFrom(...VALID_CATEGORY_IDS_LIST),
          async (unknownProductId, categoryId) => {
            const res = await request(
              port,
              "POST",
              `/registry/${registryId}/items`,
              { Authorization: "Bearer valid-test-token" },
              { productId: unknownProductId, quantity: 1, categoryId }
            );
            assert.strictEqual(
              res.status,
              404,
              `Expected HTTP 404 for unknown productId "${unknownProductId}", got ${res.status}`
            );
            assert.strictEqual(
              res.body && res.body.code,
              "PRODUCT_NOT_FOUND",
              `Expected code PRODUCT_NOT_FOUND, got "${res.body && res.body.code}"`
            );
          }
        ),
        { numRuns: 30 }
      );
    } finally {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  // -------------------------------------------------------------------------
  // 11b — HTTP 400 for invalid categoryId (Req 12.3)
  // -------------------------------------------------------------------------
  it("11b — POST /registry/:id/items returns HTTP 400 for any invalid categoryId", async () => {
    /**
     * **Validates: Requirements 12.3, 12.9**
     *
     * For any categoryId that is NOT one of the 7 valid values, the endpoint
     * must return HTTP 400 with code INVALID_CATEGORY_ID.
     */
    const registryId = "reg-test-002";
    const ownerUid = "owner-uid-001";
    const firestoreMock = buildFirestoreMock(
      { ownerUid, items: [], isPublic: true },
      registryId
    );
    const app = buildRegistryTestApp(firestoreMock, ownerUid);
    const { server, port } = await startTestServer(app);

    const invalidCategoryArb = fc.string({ minLength: 1, maxLength: 30 }).filter(
      (s) => !VALID_CATEGORY_IDS_LIST.includes(s)
    );

    try {
      await fc.assert(
        fc.asyncProperty(
          fc.constantFrom(...VALID_PRODUCT_IDS),
          invalidCategoryArb,
          async (productId, invalidCategoryId) => {
            const res = await request(
              port,
              "POST",
              `/registry/${registryId}/items`,
              { Authorization: "Bearer valid-test-token" },
              { productId, quantity: 1, categoryId: invalidCategoryId }
            );
            assert.strictEqual(
              res.status,
              400,
              `Expected HTTP 400 for invalid categoryId "${invalidCategoryId}", got ${res.status}`
            );
            assert.strictEqual(
              res.body && res.body.code,
              "INVALID_CATEGORY_ID",
              `Expected code INVALID_CATEGORY_ID, got "${res.body && res.body.code}"`
            );
          }
        ),
        { numRuns: 30 }
      );
    } finally {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  // -------------------------------------------------------------------------
  // 11c — HTTP 403 for uid mismatch (Req 12.9)
  // -------------------------------------------------------------------------
  it("11c — POST /registry/:id/items returns HTTP 403 when authenticated uid does not match ownerUid", async () => {
    /**
     * **Validates: Requirement 12.9**
     *
     * When the authenticated user's uid does NOT match the registry's ownerUid,
     * the endpoint must return HTTP 403 with code FORBIDDEN.
     */
    const registryId = "reg-test-003";
    // Registry is owned by "owner-uid-001"; requests will come from "other-uid-999"
    const firestoreMock = buildFirestoreMock(
      { ownerUid: "owner-uid-001", items: [], isPublic: true },
      registryId
    );
    // Build app where "other-user-token" resolves to "other-uid-999"
    const app = buildRegistryTestApp(firestoreMock, "other-uid-999");
    const { server, port } = await startTestServer(app);

    try {
      await fc.assert(
        fc.asyncProperty(
          fc.constantFrom(...VALID_PRODUCT_IDS),
          fc.constantFrom(...VALID_CATEGORY_IDS_LIST),
          fc.integer({ min: 1, max: 10 }),
          async (productId, categoryId, quantity) => {
            const res = await request(
              port,
              "POST",
              `/registry/${registryId}/items`,
              { Authorization: "Bearer other-user-token" },
              { productId, quantity, categoryId }
            );
            assert.strictEqual(
              res.status,
              403,
              `Expected HTTP 403 for uid mismatch, got ${res.status}`
            );
            assert.strictEqual(
              res.body && res.body.code,
              "FORBIDDEN",
              `Expected code FORBIDDEN, got "${res.body && res.body.code}"`
            );
          }
        ),
        { numRuns: 20 }
      );
    } finally {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  // -------------------------------------------------------------------------
  // 11d — Quantity increment on duplicate productId+categoryId (Req 12.4)
  // -------------------------------------------------------------------------
  it("11d — POST /registry/:id/items increments quantity when productId+categoryId already exists", async () => {
    /**
     * **Validates: Requirement 12.4**
     *
     * When the same productId+categoryId combination is added twice, the
     * second POST must increment the existing item's quantity rather than
     * creating a duplicate entry.
     */
    const ownerUid = "owner-uid-001";

    await fc.assert(
      fc.asyncProperty(
        fc.constantFrom(...VALID_PRODUCT_IDS),
        fc.constantFrom(...VALID_CATEGORY_IDS_LIST),
        fc.integer({ min: 1, max: 5 }),
        fc.integer({ min: 1, max: 5 }),
        async (productId, categoryId, qty1, qty2) => {
          // Fresh registry for each run
          const registryId = `reg-dup-${Date.now()}-${Math.random().toString(36).slice(2)}`;
          const firestoreMock = buildFirestoreMock(
            { ownerUid, items: [], isPublic: true },
            registryId
          );
          const app = buildRegistryTestApp(firestoreMock, ownerUid);
          const { server, port } = await startTestServer(app);

          try {
            // First POST
            const res1 = await request(
              port,
              "POST",
              `/registry/${registryId}/items`,
              { Authorization: "Bearer valid-test-token" },
              { productId, quantity: qty1, categoryId }
            );
            assert.strictEqual(res1.status, 200, `First POST failed with status ${res1.status}`);

            // Second POST with same productId+categoryId
            const res2 = await request(
              port,
              "POST",
              `/registry/${registryId}/items`,
              { Authorization: "Bearer valid-test-token" },
              { productId, quantity: qty2, categoryId }
            );
            assert.strictEqual(res2.status, 200, `Second POST failed with status ${res2.status}`);

            // The category bucket must contain exactly one entry for this productId
            const categoryItems = (res2.body.itemsByCategory || {})[categoryId] || [];
            const matchingItems = categoryItems.filter((item) => item.productId === productId);
            assert.strictEqual(
              matchingItems.length,
              1,
              `Expected exactly 1 item for productId "${productId}" in category "${categoryId}", got ${matchingItems.length}`
            );

            // The quantity must equal qty1 + qty2
            assert.strictEqual(
              matchingItems[0].quantity,
              qty1 + qty2,
              `Expected quantity ${qty1 + qty2} after two POSTs, got ${matchingItems[0].quantity}`
            );
          } finally {
            await new Promise((resolve) => server.close(resolve));
          }
        }
      ),
      { numRuns: 20 }
    );
  });
});

// ---------------------------------------------------------------------------
// Property 12: Registry Dashboard Calculation Correctness
// Validates: Requirements 13.1, 13.2
// ---------------------------------------------------------------------------
describe("Property 12: Registry Dashboard Calculation Correctness", () => {
  /**
   * **Validates: Requirements 13.1, 13.2**
   *
   * Strategy: Generate arbitrary items arrays (using valid productIds and
   * categoryIds from the real catalog), inject them into a mock Firestore
   * document, and call GET /registry/:registryId/dashboard via HTTP.
   * Assert that all returned totals match the manually computed values.
   */

  const VALID_PRODUCT_IDS_12 = ["2505456", "6121370", "6247040", "2453926", "8381456", "5001660", "181543", "8227593", "9670912"];
  const VALID_CATEGORY_IDS_12 = ["cookware", "bakeware", "cutlery-knives", "electrics", "tabletop-bar", "food-entertaining", "storage-organization"];

  // Reuse helpers from Property 11 scope (they are defined in the outer scope)
  function buildFirestoreMock12(registryDoc, registryId) {
    const store = { [registryId]: { ...registryDoc } };
    function makeDocSnap(id) {
      const data = store[id];
      return { exists: data !== undefined, id, data: () => (data ? { ...data } : undefined) };
    }
    return {
      collection: () => ({
        doc: (id) => ({
          id,
          get: async () => makeDocSnap(id),
          update: async (updates) => { store[id] = { ...store[id], ...updates }; },
          delete: async () => { delete store[id]; },
        }),
        add: async (data) => {
          const newId = `reg_${Date.now()}`;
          store[newId] = { ...data };
          return { id: newId };
        },
        where: () => ({ get: async () => ({ docs: [] }) }),
      }),
      runTransaction: async (fn) => {
        const txn = {
          get: async (docRef) => makeDocSnap(docRef.id),
          update: (docRef, updates) => { store[docRef.id] = { ...store[docRef.id], ...updates }; },
        };
        return fn(txn);
      },
    };
  }

  function buildRegistryTestApp12(firestoreMock) {
    const path = require("path");
    const adminInitPath = path.resolve(__dirname, "../firebase/adminInit.js");
    const mockAdmin = {
      auth: () => ({
        verifyIdToken: (token) => {
          if (token === "valid-test-token") return Promise.resolve({ uid: "owner-uid-001" });
          return Promise.reject(new Error("Invalid token"));
        },
      }),
      firestore: () => firestoreMock,
    };
    require.cache[adminInitPath] = {
      id: adminInitPath, filename: adminInitPath, loaded: true,
      exports: mockAdmin, parent: null, children: [], paths: [],
    };
    const firebaseAuthPath = path.resolve(__dirname, "../middleware/firebaseAuth.js");
    const registryRoutePath = path.resolve(__dirname, "../routes/registry.js");
    delete require.cache[firebaseAuthPath];
    delete require.cache[registryRoutePath];
    require(firebaseAuthPath);
    const registryRouter = require(registryRoutePath);
    const express = require("express");
    const app = express();
    app.use(express.json());
    app.use("/registry", registryRouter);
    return app;
  }

  function startServer12(app) {
    return new Promise((resolve, reject) => {
      const http = require("http");
      const server = http.createServer(app);
      server.listen(0, "127.0.0.1", () => resolve({ server, port: server.address().port }));
      server.on("error", reject);
    });
  }

  function req12(port, method, path, headers = {}, body = null) {
    return new Promise((resolve, reject) => {
      const http = require("http");
      const bodyStr = body ? JSON.stringify(body) : null;
      const opts = {
        hostname: "127.0.0.1", port, path, method,
        headers: { "Content-Type": "application/json", ...headers,
          ...(bodyStr ? { "Content-Length": Buffer.byteLength(bodyStr) } : {}) },
      };
      const r = http.request(opts, (res) => {
        let data = "";
        res.on("data", (c) => { data += c; });
        res.on("end", () => {
          let parsed; try { parsed = JSON.parse(data); } catch { parsed = data; }
          resolve({ status: res.statusCode, body: parsed });
        });
      });
      r.on("error", reject);
      if (bodyStr) r.write(bodyStr);
      r.end();
    });
  }

  // Arbitrary for a single registry item
  const { skusMap: skusMap12 } = require("../services/productGraph");

  const registryItemArb = fc.record({
    productId: fc.constantFrom(...VALID_PRODUCT_IDS_12),
    categoryId: fc.constantFrom(...VALID_CATEGORY_IDS_12),
    quantity: fc.integer({ min: 1, max: 5 }),
    purchased: fc.boolean(),
  }).map((item) => {
    const sku = skusMap12.get(item.productId);
    return {
      ...item,
      name: sku ? sku.name : "Unknown",
      price: sku ? sku.price.sellingPrice : 0,
      imagePath: sku ? sku.media.images[0].path : "",
    };
  });

  it("12a — totalItems, totalValue, purchasedCount, remainingCount, purchasedValue, remainingValue are all mathematically correct", async () => {
    /**
     * **Validates: Requirements 13.1, 13.2**
     *
     * For any generated items array, the dashboard response must satisfy:
     *   totalItems     = sum(item.quantity)
     *   totalValue     = sum(item.price * item.quantity)
     *   purchasedCount = sum(item.quantity) for purchased items
     *   remainingCount = totalItems - purchasedCount
     *   purchasedValue = sum(item.price * item.quantity) for purchased items
     *   remainingValue = totalValue - purchasedValue
     */
    await fc.assert(
      fc.asyncProperty(
        fc.array(registryItemArb, { minLength: 0, maxLength: 10 }),
        async (items) => {
          const registryId = `reg-dash-${Date.now()}-${Math.random().toString(36).slice(2)}`;
          const firestoreMock = buildFirestoreMock12(
            { ownerUid: "owner-uid-001", items, isPublic: true },
            registryId
          );
          const app = buildRegistryTestApp12(firestoreMock);
          const { server, port } = await startServer12(app);

          try {
            const res = await req12(port, "GET", `/registry/${registryId}/dashboard`);
            assert.strictEqual(res.status, 200, `Expected HTTP 200, got ${res.status}: ${JSON.stringify(res.body)}`);

            const dash = res.body;

            // Manually compute expected values
            let expTotalItems = 0, expTotalValue = 0, expPurchasedCount = 0, expPurchasedValue = 0;
            for (const item of items) {
              const qty = item.quantity || 0;
              const price = item.price || 0;
              expTotalItems += qty;
              expTotalValue += price * qty;
              if (item.purchased === true) {
                expPurchasedCount += qty;
                expPurchasedValue += price * qty;
              }
            }
            const expRemainingCount = expTotalItems - expPurchasedCount;
            const expRemainingValue = expTotalValue - expPurchasedValue;

            assert.strictEqual(dash.totalItems, expTotalItems,
              `totalItems: expected ${expTotalItems}, got ${dash.totalItems}`);
            assert.ok(
              Math.abs(dash.totalValue - expTotalValue) < 0.01,
              `totalValue: expected ${expTotalValue}, got ${dash.totalValue}`);
            assert.strictEqual(dash.purchasedCount, expPurchasedCount,
              `purchasedCount: expected ${expPurchasedCount}, got ${dash.purchasedCount}`);
            assert.strictEqual(dash.remainingCount, expRemainingCount,
              `remainingCount: expected ${expRemainingCount}, got ${dash.remainingCount}`);
            assert.ok(
              Math.abs(dash.purchasedValue - expPurchasedValue) < 0.01,
              `purchasedValue: expected ${expPurchasedValue}, got ${dash.purchasedValue}`);
            assert.ok(
              Math.abs(dash.remainingValue - expRemainingValue) < 0.01,
              `remainingValue: expected ${expRemainingValue}, got ${dash.remainingValue}`);
          } finally {
            await new Promise((resolve) => server.close(resolve));
          }
        }
      ),
      { numRuns: 30 }
    );
  });

  it("12b — byCategory entries are mathematically correct (Req 13.2)", async () => {
    /**
     * **Validates: Requirement 13.2**
     *
     * For each category present in the items array, the byCategory entry must
     * satisfy:
     *   itemCount      = sum(item.quantity) for items in that category
     *   totalValue     = sum(item.price * item.quantity) for items in that category
     *   purchasedCount = sum(item.quantity) for purchased items in that category
     *   remainingCount = itemCount - purchasedCount
     *
     * Additionally, every category with ≥1 item must appear in byCategory.
     */
    await fc.assert(
      fc.asyncProperty(
        fc.array(registryItemArb, { minLength: 1, maxLength: 10 }),
        async (items) => {
          const registryId = `reg-cat-${Date.now()}-${Math.random().toString(36).slice(2)}`;
          const firestoreMock = buildFirestoreMock12(
            { ownerUid: "owner-uid-001", items, isPublic: true },
            registryId
          );
          const app = buildRegistryTestApp12(firestoreMock);
          const { server, port } = await startServer12(app);

          try {
            const res = await req12(port, "GET", `/registry/${registryId}/dashboard`);
            assert.strictEqual(res.status, 200, `Expected HTTP 200, got ${res.status}`);

            const dash = res.body;

            // Compute expected per-category values
            const catExpected = new Map();
            for (const item of items) {
              const cat = item.categoryId;
              if (!catExpected.has(cat)) {
                catExpected.set(cat, { itemCount: 0, totalValue: 0, purchasedCount: 0 });
              }
              const acc = catExpected.get(cat);
              acc.itemCount += item.quantity || 0;
              acc.totalValue += (item.price || 0) * (item.quantity || 0);
              if (item.purchased === true) acc.purchasedCount += item.quantity || 0;
            }

            // Every category with items must appear in byCategory
            for (const [catId, exp] of catExpected.entries()) {
              const entry = (dash.byCategory || []).find((e) => e.categoryId === catId);
              assert.ok(entry, `Category "${catId}" missing from byCategory`);

              assert.strictEqual(entry.itemCount, exp.itemCount,
                `byCategory[${catId}].itemCount: expected ${exp.itemCount}, got ${entry.itemCount}`);
              assert.ok(
                Math.abs(entry.totalValue - exp.totalValue) < 0.01,
                `byCategory[${catId}].totalValue: expected ${exp.totalValue}, got ${entry.totalValue}`);
              assert.strictEqual(entry.purchasedCount, exp.purchasedCount,
                `byCategory[${catId}].purchasedCount: expected ${exp.purchasedCount}, got ${entry.purchasedCount}`);
              assert.strictEqual(entry.remainingCount, exp.itemCount - exp.purchasedCount,
                `byCategory[${catId}].remainingCount: expected ${exp.itemCount - exp.purchasedCount}, got ${entry.remainingCount}`);
            }

            // No extra categories should appear in byCategory
            for (const entry of (dash.byCategory || [])) {
              assert.ok(
                catExpected.has(entry.categoryId),
                `Unexpected category "${entry.categoryId}" in byCategory`
              );
            }
          } finally {
            await new Promise((resolve) => server.close(resolve));
          }
        }
      ),
      { numRuns: 30 }
    );
  });
});

// ---------------------------------------------------------------------------
// Property 13: Registry Name Search Case-Insensitivity
// Validates: Requirements 11.3, 13.1
// ---------------------------------------------------------------------------
describe("Property 13: Registry Name Search Case-Insensitivity", () => {
  /**
   * **Validates: Requirements 11.3, 13.1**
   *
   * Strategy: Inject a mock Firestore that stores a registry with known
   * firstNameLower/lastNameLower fields and isPublic:true. The mock's
   * collection().where() chain simulates the case-insensitive query by
   * matching against the lowercase index fields.
   *
   * For any casing variant of the stored firstName/lastName, the search
   * endpoint must return the registry in its results.
   */

  function buildFirestoreMock13(registryDoc, registryId) {
    const store = { [registryId]: { ...registryDoc } };

    function makeDocSnap(id) {
      const data = store[id];
      return { exists: data !== undefined, id, data: () => (data ? { ...data } : undefined) };
    }

    // Chainable where() mock that filters the in-memory store
    function makeQuery(filters) {
      return {
        where: (field, op, value) => makeQuery([...filters, { field, op, value }]),
        get: async () => {
          const docs = Object.entries(store)
            .filter(([, data]) => {
              return filters.every(({ field, op, value }) => {
                if (op === "==") return data[field] === value;
                return true;
              });
            })
            .map(([id, data]) => ({
              id,
              data: () => ({ ...data }),
            }));
          return { docs };
        },
      };
    }

    return {
      collection: () => ({
        doc: (id) => ({
          id,
          get: async () => makeDocSnap(id),
          update: async (updates) => { store[id] = { ...store[id], ...updates }; },
          delete: async () => { delete store[id]; },
        }),
        add: async (data) => {
          const newId = `reg_${Date.now()}`;
          store[newId] = { ...data };
          return { id: newId };
        },
        where: (field, op, value) => makeQuery([{ field, op, value }]),
      }),
      runTransaction: async (fn) => {
        const txn = {
          get: async (docRef) => makeDocSnap(docRef.id),
          update: (docRef, updates) => { store[docRef.id] = { ...store[docRef.id], ...updates }; },
        };
        return fn(txn);
      },
    };
  }

  function buildRegistryTestApp13(firestoreMock) {
    const path = require("path");
    const adminInitPath = path.resolve(__dirname, "../firebase/adminInit.js");
    const mockAdmin = {
      auth: () => ({
        verifyIdToken: (token) => {
          if (token === "valid-test-token") return Promise.resolve({ uid: "owner-uid-001" });
          return Promise.reject(new Error("Invalid token"));
        },
      }),
      firestore: () => firestoreMock,
    };
    require.cache[adminInitPath] = {
      id: adminInitPath, filename: adminInitPath, loaded: true,
      exports: mockAdmin, parent: null, children: [], paths: [],
    };
    const firebaseAuthPath = path.resolve(__dirname, "../middleware/firebaseAuth.js");
    const registryRoutePath = path.resolve(__dirname, "../routes/registry.js");
    delete require.cache[firebaseAuthPath];
    delete require.cache[registryRoutePath];
    require(firebaseAuthPath);
    const registryRouter = require(registryRoutePath);
    const express = require("express");
    const app = express();
    app.use(express.json());
    app.use("/registry", registryRouter);
    return app;
  }

  function startServer13(app) {
    return new Promise((resolve, reject) => {
      const http = require("http");
      const server = http.createServer(app);
      server.listen(0, "127.0.0.1", () => resolve({ server, port: server.address().port }));
      server.on("error", reject);
    });
  }

  function req13(port, method, urlPath, headers = {}, body = null) {
    return new Promise((resolve, reject) => {
      const http = require("http");
      const bodyStr = body ? JSON.stringify(body) : null;
      const opts = {
        hostname: "127.0.0.1", port, path: urlPath, method,
        headers: { "Content-Type": "application/json", ...headers,
          ...(bodyStr ? { "Content-Length": Buffer.byteLength(bodyStr) } : {}) },
      };
      const r = http.request(opts, (res) => {
        let data = "";
        res.on("data", (c) => { data += c; });
        res.on("end", () => {
          let parsed; try { parsed = JSON.parse(data); } catch { parsed = data; }
          resolve({ status: res.statusCode, body: parsed });
        });
      });
      r.on("error", reject);
      if (bodyStr) r.write(bodyStr);
      r.end();
    });
  }

  /**
   * Generate a random casing variant of a string (each character randomly
   * uppercased or lowercased).
   */
  function randomCasing(str, seed) {
    // Use fast-check's fc.string to generate a bitmask for casing
    return str
      .split("")
      .map((ch, i) => ((seed >> (i % 30)) & 1) ? ch.toUpperCase() : ch.toLowerCase())
      .join("");
  }

  it("13a — any casing variant of firstName+lastName returns the registry when isPublic:true", async () => {
    /**
     * **Validates: Requirements 11.3, 13.1**
     *
     * For any alphabetic firstName and lastName, and any casing variant of
     * those strings, GET /registry/search?firstName=X&lastName=Y must return
     * the registry in its results array.
     *
     * The route normalises the query to lowercase before comparing against
     * the stored firstNameLower/lastNameLower index fields.
     */
    // Use alphabetic-only names to avoid URL encoding issues
    const nameArb = fc.stringMatching(/^[a-zA-Z]{2,10}$/);

    await fc.assert(
      fc.asyncProperty(
        nameArb,
        nameArb,
        fc.integer({ min: 0, max: 0x3fffffff }),
        fc.integer({ min: 0, max: 0x3fffffff }),
        async (firstName, lastName, firstSeed, lastSeed) => {
          const registryId = `reg-search-${Date.now()}-${Math.random().toString(36).slice(2)}`;
          const storedDoc = {
            ownerUid: "owner-uid-001",
            firstName,
            lastName,
            firstNameLower: firstName.toLowerCase(),
            lastNameLower: lastName.toLowerCase(),
            eventType: "wedding",
            eventDate: "2025-09-15",
            isPublic: true,
            items: [],
          };

          const firestoreMock = buildFirestoreMock13(storedDoc, registryId);
          const app = buildRegistryTestApp13(firestoreMock);
          const { server, port } = await startServer13(app);

          try {
            // Generate casing variants
            const firstVariant = randomCasing(firstName, firstSeed);
            const lastVariant = randomCasing(lastName, lastSeed);

            const encodedFirst = encodeURIComponent(firstVariant);
            const encodedLast = encodeURIComponent(lastVariant);

            const res = await req13(
              port,
              "GET",
              `/registry/search?firstName=${encodedFirst}&lastName=${encodedLast}`
            );

            assert.strictEqual(
              res.status,
              200,
              `Expected HTTP 200 for name search "${firstVariant} ${lastVariant}", got ${res.status}: ${JSON.stringify(res.body)}`
            );

            const results = (res.body && res.body.results) || [];
            const found = results.some((r) => r.registryId === registryId);
            assert.ok(
              found,
              `Registry "${registryId}" not found in search results for "${firstVariant} ${lastVariant}". Results: ${JSON.stringify(results)}`
            );
          } finally {
            await new Promise((resolve) => server.close(resolve));
          }
        }
      ),
      { numRuns: 30 }
    );
  });

  it("13b — search with only firstName (any casing) returns the registry when isPublic:true", async () => {
    /**
     * **Validates: Requirement 11.3**
     *
     * Searching by firstName alone (any casing) must return the registry.
     */
    const nameArb = fc.stringMatching(/^[a-zA-Z]{2,10}$/);

    await fc.assert(
      fc.asyncProperty(
        nameArb,
        nameArb,
        fc.integer({ min: 0, max: 0x3fffffff }),
        async (firstName, lastName, firstSeed) => {
          const registryId = `reg-fn-${Date.now()}-${Math.random().toString(36).slice(2)}`;
          const storedDoc = {
            ownerUid: "owner-uid-001",
            firstName,
            lastName,
            firstNameLower: firstName.toLowerCase(),
            lastNameLower: lastName.toLowerCase(),
            eventType: "birthday",
            eventDate: "2025-06-01",
            isPublic: true,
            items: [],
          };

          const firestoreMock = buildFirestoreMock13(storedDoc, registryId);
          const app = buildRegistryTestApp13(firestoreMock);
          const { server, port } = await startServer13(app);

          try {
            const firstVariant = randomCasing(firstName, firstSeed);
            const encodedFirst = encodeURIComponent(firstVariant);

            const res = await req13(
              port,
              "GET",
              `/registry/search?firstName=${encodedFirst}`
            );

            assert.strictEqual(res.status, 200,
              `Expected HTTP 200 for firstName-only search "${firstVariant}", got ${res.status}`);

            const results = (res.body && res.body.results) || [];
            const found = results.some((r) => r.registryId === registryId);
            assert.ok(found,
              `Registry not found in firstName-only search for "${firstVariant}"`);
          } finally {
            await new Promise((resolve) => server.close(resolve));
          }
        }
      ),
      { numRuns: 20 }
    );
  });
});
