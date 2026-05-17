"use strict";
require("dotenv").config({ path: require("path").join(__dirname, "..", ".env") });

const fs = require("fs");
const path = require("path");

const skus = JSON.parse(fs.readFileSync(path.join(__dirname, "..", "responses", "skus.json"), "utf8"));
const domainRules = JSON.parse(fs.readFileSync(path.join(__dirname, "..", "domain-rules.json"), "utf8"));

function parseArrayString(value) {
  if (typeof value !== "string") return [];
  const trimmed = value.trim();
  if (trimmed.startsWith("[") && trimmed.endsWith("]")) {
    return trimmed.slice(1, -1).split(",").map(s => s.trim()).filter(Boolean);
  }
  return [trimmed];
}

function slug(v) { return v.trim().toLowerCase(); }

const nodes = [];
const edges = [];
const addedEdgePairs = new Set();

// ── Product nodes ──────────────────────────────────────────────────────────
skus.forEach(sku => {
  nodes.push({
    id: "prod_" + sku.id,
    label: sku.shortName || sku.name,
    type: "Product",
    price: sku.price.sellingPrice,
    availability: sku.availability,
    imagePath: sku.media.images[0].path
  });
});

// ── Brand nodes + BRANDED_BY edges ────────────────────────────────────────
const brandNodes = new Map();
skus.forEach(sku => {
  parseArrayString(sku.properties.brand).forEach(b => {
    const id = "brand_" + slug(b);
    if (!brandNodes.has(id)) {
      brandNodes.set(id, { id, label: b, type: "Brand" });
    }
    edges.push({ source: "prod_" + sku.id, target: id, relation: "BRANDED_BY", weight: 0 });
  });
});
brandNodes.forEach(n => nodes.push(n));

// ── Material nodes + MADE_OF edges ────────────────────────────────────────
const materialNodes = new Map();
skus.forEach(sku => {
  parseArrayString(sku.properties.material).forEach(m => {
    if (!m) return;
    const id = "material_" + slug(m);
    if (!materialNodes.has(id)) {
      materialNodes.set(id, { id, label: m, type: "Material" });
    }
    edges.push({ source: "prod_" + sku.id, target: id, relation: "MADE_OF", weight: 0 });
  });
});
materialNodes.forEach(n => nodes.push(n));

// ── RELATED_CATEGORY edges (collection=4, brand=3, productType=2, material=1) ──
const collectionMap = new Map(), brandMap = new Map(), ptMap = new Map(), matMap = new Map();
skus.forEach(sku => {
  const pid = "prod_" + sku.id;
  parseArrayString(sku.properties.collection).forEach(c => {
    if (!c) return;
    if (!collectionMap.has(c)) collectionMap.set(c, []);
    collectionMap.get(c).push(pid);
  });
  parseArrayString(sku.properties.brand).forEach(b => {
    if (!brandMap.has(b)) brandMap.set(b, []);
    brandMap.get(b).push(pid);
  });
  parseArrayString(sku.properties.productType).forEach(pt => {
    if (!ptMap.has(pt)) ptMap.set(pt, []);
    ptMap.get(pt).push(pid);
  });
  parseArrayString(sku.properties.material).forEach(m => {
    if (!m) return;
    if (!matMap.has(m)) matMap.set(m, []);
    matMap.get(m).push(pid);
  });
});

function addRelatedEdge(a, b, weight, context) {
  const key = [a, b].sort().join("|") + "|RELATED_CATEGORY";
  if (addedEdgePairs.has(key)) return;
  addedEdgePairs.add(key);
  edges.push({ source: a, target: b, relation: "RELATED_CATEGORY", weight, context });
  edges.push({ source: b, target: a, relation: "RELATED_CATEGORY", weight, context });
}

function processTier(map, weight) {
  for (const [val, ids] of map) {
    for (let i = 0; i < ids.length; i++) {
      for (let j = i + 1; j < ids.length; j++) {
        addRelatedEdge(ids[i], ids[j], weight, val);
      }
    }
  }
}

processTier(collectionMap, 4);
processTier(brandMap, 3);
processTier(ptMap, 2);
processTier(matMap, 1);

// ── Domain rules edges ─────────────────────────────────────────────────────
const ptLookup = new Map();
skus.forEach(sku => {
  parseArrayString(sku.properties.productType).forEach(pt => {
    if (!ptLookup.has(pt)) ptLookup.set(pt, []);
    ptLookup.get(pt).push("prod_" + sku.id);
  });
});

domainRules.rules.forEach(rule => {
  const sources = ptLookup.get(rule.sourceProductType) || [];
  const targets = ptLookup.get(rule.targetProductType) || [];
  sources.forEach(src => {
    targets.forEach(tgt => {
      if (src === tgt) return;
      const key = [src, tgt].sort().join("|") + "|" + rule.relation;
      if (addedEdgePairs.has(key)) return;
      addedEdgePairs.add(key);
      edges.push({ source: src, target: tgt, relation: rule.relation, weight: rule.weight, context: rule.context });
      edges.push({ source: tgt, target: src, relation: rule.relation, weight: rule.weight, context: rule.context });
    });
  });
});

const graph = { nodes, edges };

// Stats
const products = nodes.filter(n => n.type === "Product");
const brands2  = nodes.filter(n => n.type === "Brand");
const mats     = nodes.filter(n => n.type === "Material");
const prodEdges = edges.filter(e => e.source.startsWith("prod_") && e.target.startsWith("prod_"));

console.error(`Nodes: ${nodes.length} (${products.length} products, ${brands2.length} brands, ${mats.length} materials)`);
console.error(`Edges: ${edges.length} (${prodEdges.length} product-to-product)`);

// Write to graph.json
const outPath = path.join(__dirname, "..", "responses", "graph.json");
fs.writeFileSync(outPath, JSON.stringify(graph, null, 2), "utf8");
console.error("Written to", outPath);
