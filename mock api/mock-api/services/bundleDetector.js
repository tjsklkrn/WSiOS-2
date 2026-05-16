"use strict";

/**
 * services/bundleDetector.js
 *
 * Detects product bundles from cart items using a two-pass algorithm:
 *   1. Collection-first clustering — items sharing a collection value form bundles
 *   2. Brand clustering — remaining items sharing a brand value form bundles
 *
 * Exports:
 *   detectBundles(cartItems)  — returns array of bundle objects
 *   buildBundle(items, sharedPropertyType, sharedPropertyValue)  — constructs a single bundle
 *
 * Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7
 */

const { parseArrayString, skusMap } = require("./productGraph");

// ---------------------------------------------------------------------------
// Registry category maps
// ---------------------------------------------------------------------------

/**
 * Maps SKU productType values to registry category IDs.
 * Used to assign a registryCategory to each detected bundle based on the
 * highest-priced item's productType.
 */
const PRODUCT_TYPE_TO_REGISTRY_CATEGORY = {
  "dutch-ovens": "cookware",
  "fry-pans-skillets": "cookware",
  "cutting-boards-storage": "cookware",
  "coffee-maker": "electrics",
  "cups-and-saucers": "tabletop-bar",
  "bar-glasses-martini": "tabletop-bar",
  "tabletop-serveware-bowl": "tabletop-bar",
  "oil": "food-entertaining",
  "lazy-susan": "storage-organization",
  "cutting-board-oil": "storage-organization"
};

/**
 * The 7 valid registry category IDs and their display labels.
 */
const VALID_REGISTRY_CATEGORIES = {
  "cookware": "Cookware",
  "bakeware": "Bakeware",
  "cutlery-knives": "Cutlery & Knives",
  "electrics": "Electrics",
  "tabletop-bar": "Tabletop & Bar",
  "food-entertaining": "Food & Entertaining",
  "storage-organization": "Storage & Organization"
};

// ---------------------------------------------------------------------------
// buildBundle
// ---------------------------------------------------------------------------

/**
 * Constructs a bundle object from a group of cart items that share a common
 * property value (collection or brand).
 *
 * The registryCategory is determined by the productType of the highest-priced
 * item in the bundle. If the productType is not in PRODUCT_TYPE_TO_REGISTRY_CATEGORY,
 * it defaults to "cookware".
 *
 * @param {Array<{ productId: string }>} items  — cart items in the bundle
 * @param {"collection"|"brand"} sharedPropertyType
 * @param {string} sharedPropertyValue  — the shared collection or brand value
 * @returns {{
 *   productIds: string[],
 *   sharedPropertyType: string,
 *   sharedPropertyValue: string,
 *   discountLabel: string,
 *   registryCategory: string
 * }}
 */
function buildBundle(items, sharedPropertyType, sharedPropertyValue) {
  const productIds = items.map((i) => i.productId);

  // Find the highest-priced item to determine registryCategory
  const highestPricedItem = items.reduce((max, item) => {
    const itemSku = skusMap.get(item.productId);
    const maxSku = skusMap.get(max.productId);
    if (!itemSku) return max;
    if (!maxSku) return item;
    return itemSku.price.sellingPrice > maxSku.price.sellingPrice ? item : max;
  });

  const highestSku = skusMap.get(highestPricedItem.productId);
  const productType = highestSku
    ? parseArrayString(highestSku.properties.productType)[0]
    : null;

  const registryCategoryId =
    (productType && PRODUCT_TYPE_TO_REGISTRY_CATEGORY[productType]) || "cookware";

  const discountLabel =
    sharedPropertyType === "collection"
      ? `Bundle & Save — ${sharedPropertyValue}`
      : `Brand Bundle — ${sharedPropertyValue}`;

  return {
    productIds,
    sharedPropertyType,
    sharedPropertyValue,
    discountLabel,
    registryCategory: VALID_REGISTRY_CATEGORIES[registryCategoryId]
  };
}

// ---------------------------------------------------------------------------
// detectBundles
// ---------------------------------------------------------------------------

/**
 * Detects bundles in the current cart using a two-pass algorithm.
 *
 * Pass 1 — Collection clustering:
 *   Groups cart items by shared collection values (parsed via parseArrayString).
 *   Any collection with ≥2 items forms a bundle. Items used in a collection
 *   bundle are tracked in `usedInCollectionBundle` and excluded from Pass 2.
 *
 * Pass 2 — Brand clustering:
 *   Groups remaining items (not in any collection bundle) by shared brand values.
 *   Any brand with ≥2 items forms a bundle.
 *
 * Items whose SKU is not found in skusMap are silently skipped.
 *
 * @param {Array<{ productId: string }>} cartItems
 * @returns {Array<{
 *   productIds: string[],
 *   sharedPropertyType: string,
 *   sharedPropertyValue: string,
 *   discountLabel: string,
 *   registryCategory: string
 * }>}
 */
function detectBundles(cartItems) {
  const bundles = [];

  // -------------------------------------------------------------------------
  // Step 1: Collection-first clustering
  // -------------------------------------------------------------------------

  /** @type {Map<string, Array<{ productId: string }>>} */
  const collectionMap = new Map();

  for (const item of cartItems) {
    const sku = skusMap.get(item.productId);
    if (!sku) continue;

    const collections = parseArrayString(sku.properties.collection);
    for (const collection of collections) {
      if (!collectionMap.has(collection)) {
        collectionMap.set(collection, []);
      }
      collectionMap.get(collection).push(item);
    }
  }

  /** Tracks productIds already assigned to a collection bundle */
  const usedInCollectionBundle = new Set();

  for (const [collectionValue, items] of collectionMap) {
    if (items.length >= 2) {
      const bundle = buildBundle(items, "collection", collectionValue);
      bundles.push(bundle);
      for (const item of items) {
        usedInCollectionBundle.add(item.productId);
      }
    }
  }

  // -------------------------------------------------------------------------
  // Step 2: Brand clustering (only items NOT in a collection bundle)
  // -------------------------------------------------------------------------

  const remainingItems = cartItems.filter(
    (item) => !usedInCollectionBundle.has(item.productId)
  );

  /** @type {Map<string, Array<{ productId: string }>>} */
  const brandMap = new Map();

  for (const item of remainingItems) {
    const sku = skusMap.get(item.productId);
    if (!sku) continue;

    const brands = parseArrayString(sku.properties.brand);
    for (const brand of brands) {
      if (!brandMap.has(brand)) {
        brandMap.set(brand, []);
      }
      brandMap.get(brand).push(item);
    }
  }

  for (const [brandValue, items] of brandMap) {
    if (items.length >= 2) {
      const bundle = buildBundle(items, "brand", brandValue);
      bundles.push(bundle);
    }
  }

  return bundles;
}

// ---------------------------------------------------------------------------
// Exports
// ---------------------------------------------------------------------------

module.exports = {
  detectBundles,
  buildBundle,
  PRODUCT_TYPE_TO_REGISTRY_CATEGORY,
  VALID_REGISTRY_CATEGORIES
};
