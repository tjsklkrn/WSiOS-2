"use strict";

/**
 * routes/registry.js
 *
 * All /registry/* route handlers for the Smart Registry feature.
 *
 * Endpoints implemented here (task 9.1):
 *   POST /registry          — create a new registry (auth required)
 *   GET  /registry/search   — search registries by id or name (public)
 *
 * Endpoints added in task 9.2:
 *   GET    /registry/:registryId/items
 *   POST   /registry/:registryId/items
 *   PATCH  /registry/:registryId/items/:productId
 *   DELETE /registry/:registryId/items/:productId
 *
 * Endpoints added in task 9.3:
 *   GET    /registry/:registryId/dashboard
 *   DELETE /registry/:registryId
 *   PATCH  /registry/:registryId
 */

const express = require("express");
const router = express.Router();

const admin = require("../firebase/adminInit");
const db = admin.firestore();

const firebaseAuth = require("../middleware/firebaseAuth");
const { skusMap } = require("../services/productGraph");

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const VALID_EVENT_TYPES = new Set(["wedding", "housewarming", "birthday", "anniversary"]);

const VALID_CATEGORY_IDS = new Set([
  "cookware", "bakeware", "cutlery-knives", "electrics",
  "tabletop-bar", "food-entertaining", "storage-organization"
]);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Returns true if the given string is a valid ISO 8601 date string
 * (e.g. "2025-09-15" or "2025-09-15T10:00:00Z").
 *
 * @param {string} value
 * @returns {boolean}
 */
function isValidISODate(value) {
  if (typeof value !== "string" || !value.trim()) return false;
  const d = new Date(value);
  return !isNaN(d.getTime());
}

/**
 * Groups a flat items array into an object keyed by categoryId.
 *
 * @param {Array<object>} items
 * @returns {{ [categoryId: string]: Array<object> }}
 */
function groupItemsByCategory(items) {
  const result = {};
  for (const item of items) {
    const cat = item.categoryId;
    if (!result[cat]) result[cat] = [];
    result[cat].push(item);
  }
  return result;
}

/**
 * Formats a Firestore document snapshot into registry metadata.
 * Intentionally excludes the `items` array and `ownerUid`.
 *
 * @param {FirebaseFirestore.DocumentSnapshot} doc
 * @returns {object}
 */
function formatRegistryMetadata(doc) {
  const d = doc.data();
  return {
    registryId: doc.id,
    firstName: d.firstName,
    lastName: d.lastName,
    eventType: d.eventType,
    eventDate: d.eventDate,
    ...(d.coRegistrantFirstName && { coRegistrantFirstName: d.coRegistrantFirstName }),
    ...(d.coRegistrantLastName  && { coRegistrantLastName:  d.coRegistrantLastName  }),
  };
}

// ---------------------------------------------------------------------------
// POST /registry — create a new registry (auth required)
// ---------------------------------------------------------------------------

router.post("/", firebaseAuth, async (req, res, next) => {
  try {
    const {
      firstName,
      lastName,
      eventType,
      eventDate,
      coRegistrantFirstName,
      coRegistrantLastName,
    } = req.body || {};

    // Validate eventType
    if (!eventType || !VALID_EVENT_TYPES.has(eventType)) {
      return res.status(400).json({
        error: "eventType must be one of: wedding, housewarming, birthday, anniversary",
        code: "INVALID_EVENT_TYPE",
      });
    }

    // Validate eventDate
    if (!isValidISODate(eventDate)) {
      return res.status(400).json({
        error: "eventDate must be a valid ISO 8601 date string",
        code: "INVALID_EVENT_DATE",
      });
    }

    // Build Firestore document
    const doc = {
      ownerUid: req.firebaseUid,
      firstName: firstName || "",
      lastName: lastName || "",
      firstNameLower: (firstName || "").toLowerCase(),
      lastNameLower: (lastName || "").toLowerCase(),
      eventType,
      eventDate,
      isPublic: true,
      createdAt: new Date().toISOString(),
      items: [],
    };

    // Include co-registrant fields only if provided
    if (coRegistrantFirstName) doc.coRegistrantFirstName = coRegistrantFirstName;
    if (coRegistrantLastName)  doc.coRegistrantLastName  = coRegistrantLastName;

    // Write to Firestore
    const docRef = await db.collection("registries").add(doc);

    // Build response — exclude ownerUid, include registryId
    const { ownerUid, firstNameLower, lastNameLower, ...publicFields } = doc;
    const responseBody = {
      registryId: docRef.id,
      ...publicFields,
    };

    return res.status(201).json(responseBody);
  } catch (err) {
    next(err);
  }
});

// ---------------------------------------------------------------------------
// GET /registry/search — search registries by id or name (public, no auth)
// NOTE: This route MUST be defined before /:registryId routes to avoid
//       Express matching "search" as a registryId parameter.
// ---------------------------------------------------------------------------

router.get("/search", async (req, res, next) => {
  try {
    const { registryId, firstName, lastName } = req.query;

    // Require at least registryId or one of firstName/lastName
    if (!registryId && !firstName && !lastName) {
      return res.status(400).json({
        error: "Provide registryId or at least one of firstName / lastName",
        code: "MISSING_SEARCH_PARAMS",
      });
    }

    // --- Search by registryId ---
    if (registryId) {
      const docSnap = await db.collection("registries").doc(registryId).get();
      if (!docSnap.exists || !docSnap.data().isPublic) {
        return res.status(404).json({ error: "Registry not found" });
      }
      return res.json({ results: [formatRegistryMetadata(docSnap)] });
    }

    // --- Name search (uses lowercase index fields + isPublic filter) ---
    let query = db.collection("registries").where("isPublic", "==", true);
    if (firstName) query = query.where("firstNameLower", "==", firstName.toLowerCase());
    if (lastName)  query = query.where("lastNameLower",  "==", lastName.toLowerCase());

    const snapshot = await query.get();
    const results = snapshot.docs.map(formatRegistryMetadata);
    return res.json({ results });
  } catch (err) {
    next(err);
  }
});

// ---------------------------------------------------------------------------
// GET /registry/:registryId — fetch full registry metadata (public)
// Returns all metadata fields (excluding ownerUid). 404 if private or not found.
// ---------------------------------------------------------------------------

router.get("/:registryId", async (req, res, next) => {
  try {
    const { registryId } = req.params;
    const docSnap = await db.collection("registries").doc(registryId).get();

    if (!docSnap.exists || !docSnap.data().isPublic) {
      return res.status(404).json({ error: "Registry not found" });
    }

    const d = docSnap.data();
    const responseBody = {
      registryId: docSnap.id,
      firstName:   d.firstName,
      lastName:    d.lastName,
      eventType:   d.eventType,
      eventDate:   d.eventDate,
      isPublic:    d.isPublic,
      createdAt:   d.createdAt,
      ...(d.coRegistrantFirstName && { coRegistrantFirstName: d.coRegistrantFirstName }),
      ...(d.coRegistrantLastName  && { coRegistrantLastName:  d.coRegistrantLastName  }),
    };

    return res.json(responseBody);
  } catch (err) {
    next(err);
  }
});

// ---------------------------------------------------------------------------
// GET /registry/:registryId/items — fetch all items grouped by category (public)
// ---------------------------------------------------------------------------

router.get("/:registryId/items", async (req, res, next) => {
  try {
    const { registryId } = req.params;
    const docSnap = await db.collection("registries").doc(registryId).get();

    if (!docSnap.exists) {
      return res.status(404).json({ error: "Registry not found" });
    }

    const data = docSnap.data();
    const items = data.items || [];

    return res.json({
      registryId,
      itemsByCategory: groupItemsByCategory(items),
    });
  } catch (err) {
    next(err);
  }
});

// ---------------------------------------------------------------------------
// POST /registry/:registryId/items — add an item to the registry (auth required)
// ---------------------------------------------------------------------------

router.post("/:registryId/items", firebaseAuth, async (req, res, next) => {
  try {
    const { registryId } = req.params;
    const { productId, quantity, categoryId } = req.body || {};

    // Validate productId exists in skusMap
    const sku = skusMap.get(productId);
    if (!sku) {
      return res.status(404).json({
        error: `Product not found: ${productId}`,
        code: "PRODUCT_NOT_FOUND",
      });
    }

    // Validate categoryId
    if (!categoryId || !VALID_CATEGORY_IDS.has(categoryId)) {
      return res.status(400).json({
        error: `categoryId must be one of: ${[...VALID_CATEGORY_IDS].join(", ")}`,
        code: "INVALID_CATEGORY_ID",
      });
    }

    const docRef = db.collection("registries").doc(registryId);

    let updatedItems;
    await db.runTransaction(async (t) => {
      const docSnap = await t.get(docRef);

      if (!docSnap.exists) {
        const err = new Error("Registry not found");
        err.statusCode = 404;
        throw err;
      }

      const data = docSnap.data();

      // Ownership check
      if (req.firebaseUid !== data.ownerUid) {
        const err = new Error("Forbidden");
        err.statusCode = 403;
        err.code = "FORBIDDEN";
        throw err;
      }

      const items = data.items ? [...data.items] : [];

      // Check for existing item with same productId AND same categoryId
      const existingIndex = items.findIndex(
        (item) => item.productId === productId && item.categoryId === categoryId
      );

      if (existingIndex !== -1) {
        // Increment quantity
        items[existingIndex] = {
          ...items[existingIndex],
          quantity: items[existingIndex].quantity + quantity,
        };
      } else {
        // Append new item
        items.push({
          productId,
          name: sku.name,
          price: sku.price.sellingPrice,
          imagePath: sku.media.images[0].path,
          quantity,
          categoryId,
          purchased: false,
        });
      }

      t.update(docRef, { items });
      updatedItems = items;
    });

    return res.json({
      registryId,
      itemsByCategory: groupItemsByCategory(updatedItems),
    });
  } catch (err) {
    if (err.statusCode === 404) {
      return res.status(404).json({ error: err.message });
    }
    if (err.statusCode === 403) {
      return res.status(403).json({ error: err.message, code: err.code });
    }
    next(err);
  }
});

// ---------------------------------------------------------------------------
// PATCH /registry/:registryId/items/:productId — update quantity or category (auth required)
// ---------------------------------------------------------------------------

router.patch("/:registryId/items/:productId", firebaseAuth, async (req, res, next) => {
  try {
    const { registryId, productId } = req.params;
    const { quantity, categoryId } = req.body || {};

    // Validate categoryId if provided
    if (categoryId !== undefined && !VALID_CATEGORY_IDS.has(categoryId)) {
      return res.status(400).json({
        error: `categoryId must be one of: ${[...VALID_CATEGORY_IDS].join(", ")}`,
        code: "INVALID_CATEGORY_ID",
      });
    }

    const docRef = db.collection("registries").doc(registryId);

    let updatedItems;
    await db.runTransaction(async (t) => {
      const docSnap = await t.get(docRef);

      if (!docSnap.exists) {
        const err = new Error("Registry not found");
        err.statusCode = 404;
        throw err;
      }

      const data = docSnap.data();

      // Ownership check
      if (req.firebaseUid !== data.ownerUid) {
        const err = new Error("Forbidden");
        err.statusCode = 403;
        err.code = "FORBIDDEN";
        throw err;
      }

      const items = data.items ? [...data.items] : [];

      // Find matching items
      const matchingIndices = items
        .map((item, idx) => (item.productId === productId ? idx : -1))
        .filter((idx) => idx !== -1);

      if (matchingIndices.length === 0) {
        const err = new Error(`Item not found: ${productId}`);
        err.statusCode = 404;
        throw err;
      }

      for (const idx of matchingIndices) {
        if (quantity !== undefined) {
          items[idx] = { ...items[idx], quantity };
        }
        if (categoryId !== undefined) {
          items[idx] = { ...items[idx], categoryId };
        }
      }

      t.update(docRef, { items });
      updatedItems = items;
    });

    return res.json({
      registryId,
      itemsByCategory: groupItemsByCategory(updatedItems),
    });
  } catch (err) {
    if (err.statusCode === 404) {
      return res.status(404).json({ error: err.message });
    }
    if (err.statusCode === 403) {
      return res.status(403).json({ error: err.message, code: err.code });
    }
    next(err);
  }
});

// ---------------------------------------------------------------------------
// DELETE /registry/:registryId/items/:productId — remove all entries for a product (auth required)
// ---------------------------------------------------------------------------

router.delete("/:registryId/items/:productId", firebaseAuth, async (req, res, next) => {
  try {
    const { registryId, productId } = req.params;

    const docRef = db.collection("registries").doc(registryId);

    let updatedItems;
    await db.runTransaction(async (t) => {
      const docSnap = await t.get(docRef);

      if (!docSnap.exists) {
        const err = new Error("Registry not found");
        err.statusCode = 404;
        throw err;
      }

      const data = docSnap.data();

      // Ownership check
      if (req.firebaseUid !== data.ownerUid) {
        const err = new Error("Forbidden");
        err.statusCode = 403;
        err.code = "FORBIDDEN";
        throw err;
      }

      const items = data.items || [];
      const filtered = items.filter((item) => item.productId !== productId);

      if (filtered.length === items.length) {
        // No items were removed
        const err = new Error(`Item not found: ${productId}`);
        err.statusCode = 404;
        throw err;
      }

      t.update(docRef, { items: filtered });
      updatedItems = filtered;
    });

    return res.json({
      registryId,
      itemsByCategory: groupItemsByCategory(updatedItems),
    });
  } catch (err) {
    if (err.statusCode === 404) {
      return res.status(404).json({ error: err.message });
    }
    if (err.statusCode === 403) {
      return res.status(403).json({ error: err.message, code: err.code });
    }
    next(err);
  }
});

// ---------------------------------------------------------------------------
// PATCH /registry/:registryId/items/:productId/purchased — toggle purchased flag
//
// Public endpoint — no auth required. A guest purchasing a gift calls this
// to mark the item as purchased so the registry owner sees it as fulfilled.
//
// Body: { purchased: boolean }
//
// Marks ALL entries for that productId (across all categories) as purchased/unpurchased.
// Uses a Firestore transaction for atomicity.
// Returns 404 if registry or product not found.
// ---------------------------------------------------------------------------

router.patch("/:registryId/items/:productId/purchased", async (req, res, next) => {
  try {
    const { registryId, productId } = req.params;
    const { purchased } = req.body || {};

    if (typeof purchased !== "boolean") {
      return res.status(400).json({
        error: "Body must include 'purchased' as a boolean",
        code: "INVALID_PURCHASED_VALUE",
      });
    }

    const docRef = db.collection("registries").doc(registryId);

    let updatedItems;
    await db.runTransaction(async (t) => {
      const docSnap = await t.get(docRef);

      if (!docSnap.exists) {
        const err = new Error("Registry not found");
        err.statusCode = 404;
        throw err;
      }

      const items = docSnap.data().items ? [...docSnap.data().items] : [];

      // Find all entries for this productId (may span multiple categories)
      const matchingIndices = items
        .map((item, idx) => (item.productId === productId ? idx : -1))
        .filter((idx) => idx !== -1);

      if (matchingIndices.length === 0) {
        const err = new Error(`Item not found in registry: ${productId}`);
        err.statusCode = 404;
        throw err;
      }

      for (const idx of matchingIndices) {
        items[idx] = { ...items[idx], purchased };
      }

      t.update(docRef, { items });
      updatedItems = items;
    });

    return res.json({
      registryId,
      productId,
      purchased,
      itemsByCategory: groupItemsByCategory(updatedItems),
    });
  } catch (err) {
    if (err.statusCode === 404) {
      return res.status(404).json({ error: err.message });
    }
    next(err);
  }
});

// ---------------------------------------------------------------------------
// Human-readable labels for registry categories (used by dashboard)
// ---------------------------------------------------------------------------

const VALID_REGISTRY_CATEGORIES = {
  "cookware":              "Cookware",
  "bakeware":              "Bakeware",
  "cutlery-knives":        "Cutlery & Knives",
  "electrics":             "Electrics",
  "tabletop-bar":          "Tabletop & Bar",
  "food-entertaining":     "Food & Entertaining",
  "storage-organization":  "Storage & Organization",
};

// ---------------------------------------------------------------------------
// GET /registry/:registryId/dashboard — public summary (no auth)
// ---------------------------------------------------------------------------

router.get("/:registryId/dashboard", async (req, res, next) => {
  try {
    const { registryId } = req.params;
    const docSnap = await db.collection("registries").doc(registryId).get();

    if (!docSnap.exists || !docSnap.data().isPublic) {
      return res.status(404).json({ error: "Registry not found" });
    }

    const items = docSnap.data().items || [];

    // Aggregate top-level totals
    let totalItems     = 0;
    let totalValue     = 0;
    let purchasedCount = 0;
    let purchasedValue = 0;

    // Per-category accumulators: categoryId → { itemCount, totalValue, purchasedCount }
    const catMap = new Map();

    for (const item of items) {
      const qty   = item.quantity  || 0;
      const price = item.price     || 0;
      const cat   = item.categoryId;

      totalItems += qty;
      totalValue += price * qty;

      if (item.purchased === true) {
        purchasedCount += qty;
        purchasedValue += price * qty;
      }

      if (cat) {
        if (!catMap.has(cat)) {
          catMap.set(cat, { itemCount: 0, totalValue: 0, purchasedCount: 0 });
        }
        const acc = catMap.get(cat);
        acc.itemCount      += qty;
        acc.totalValue     += price * qty;
        if (item.purchased === true) acc.purchasedCount += qty;
      }
    }

    const remainingCount = totalItems - purchasedCount;
    const remainingValue = totalValue - purchasedValue;

    const byCategory = [];
    for (const [categoryId, acc] of catMap.entries()) {
      byCategory.push({
        categoryId,
        categoryLabel:  VALID_REGISTRY_CATEGORIES[categoryId] || categoryId,
        itemCount:      acc.itemCount,
        totalValue:     acc.totalValue,
        purchasedCount: acc.purchasedCount,
        remainingCount: acc.itemCount - acc.purchasedCount,
      });
    }

    return res.json({
      registryId,
      totalItems,
      totalValue,
      purchasedCount,
      remainingCount,
      purchasedValue,
      remainingValue,
      byCategory,
    });
  } catch (err) {
    next(err);
  }
});

// ---------------------------------------------------------------------------
// DELETE /registry/:registryId — permanently delete a registry (auth required)
// ---------------------------------------------------------------------------

router.delete("/:registryId", firebaseAuth, async (req, res, next) => {
  try {
    const { registryId } = req.params;
    const docRef  = db.collection("registries").doc(registryId);
    const docSnap = await docRef.get();

    if (!docSnap.exists) {
      return res.status(404).json({ error: "Registry not found" });
    }

    if (req.firebaseUid !== docSnap.data().ownerUid) {
      return res.status(403).json({ error: "Forbidden", code: "FORBIDDEN" });
    }

    await docRef.delete();

    return res.json({ message: "Registry deleted successfully" });
  } catch (err) {
    next(err);
  }
});

// ---------------------------------------------------------------------------
// PATCH /registry/:registryId — update registry metadata (auth required)
// ---------------------------------------------------------------------------

router.patch("/:registryId", firebaseAuth, async (req, res, next) => {
  try {
    const { registryId } = req.params;
    const {
      isPublic,
      eventDate,
      coRegistrantFirstName,
      coRegistrantLastName,
    } = req.body || {};

    // Validate eventDate if provided
    if (eventDate !== undefined && !isValidISODate(eventDate)) {
      return res.status(400).json({
        error: "eventDate must be a valid ISO 8601 date string",
        code: "INVALID_EVENT_DATE",
      });
    }

    const docRef  = db.collection("registries").doc(registryId);
    const docSnap = await docRef.get();

    if (!docSnap.exists) {
      return res.status(404).json({ error: "Registry not found" });
    }

    const data = docSnap.data();

    if (req.firebaseUid !== data.ownerUid) {
      return res.status(403).json({ error: "Forbidden", code: "FORBIDDEN" });
    }

    // Build updates object — only include fields that were explicitly provided
    const updates = {};
    if (isPublic              !== undefined) updates.isPublic              = isPublic;
    if (eventDate             !== undefined) updates.eventDate             = eventDate;
    if (coRegistrantFirstName !== undefined) updates.coRegistrantFirstName = coRegistrantFirstName;
    if (coRegistrantLastName  !== undefined) updates.coRegistrantLastName  = coRegistrantLastName;

    await docRef.update(updates);

    // Return updated metadata (merge stored data with applied updates)
    const updated = { ...data, ...updates };

    const responseBody = {
      registryId,
      firstName:   updated.firstName,
      lastName:    updated.lastName,
      eventType:   updated.eventType,
      eventDate:   updated.eventDate,
      isPublic:    updated.isPublic,
      ...(updated.coRegistrantFirstName && { coRegistrantFirstName: updated.coRegistrantFirstName }),
      ...(updated.coRegistrantLastName  && { coRegistrantLastName:  updated.coRegistrantLastName  }),
    };

    return res.json(responseBody);
  } catch (err) {
    next(err);
  }
});

// ---------------------------------------------------------------------------
// Exports
// ---------------------------------------------------------------------------

module.exports = router;
