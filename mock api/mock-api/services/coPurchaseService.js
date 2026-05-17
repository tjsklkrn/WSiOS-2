"use strict";

/**
 * services/coPurchaseService.js
 *
 * Real collaborative filtering via Firestore co-purchase tracking.
 *
 * Every time a user checks out, every product pair in their cart is recorded
 * in the Firestore `coPurchases` collection with an incrementing count.
 * At recommendation time, the top co-purchased neighbours for each cart
 * product are fetched and fed into the merge pipeline as a third signal.
 *
 * Firestore document schema (collection: coPurchases):
 *   id:       sorted pair key, e.g. "2453926|6121370"
 *   productA: string  — lower of the two sorted IDs
 *   productB: string  — higher of the two sorted IDs
 *   count:    number  — total times this pair appeared in the same checkout
 *   lastSeen: string  — ISO timestamp of most recent co-purchase
 *
 * Exports:
 *   recordCoPurchases(cartItems)          — call on checkout
 *   getCoPurchaseCandidates(productIds)   — call during recommendation
 */

const admin = require("../firebase/adminInit");

// Lazy-initialize db so this module can be required without Firebase credentials
// (e.g. during unit tests that don't exercise Firestore paths)
let _db = null;
function getDb() {
  if (!_db) _db = admin.firestore();
  return _db;
}
const COLLECTION = "coPurchases";

// Minimum co-purchase count before a pair influences recommendations.
// Keeps noise out during cold-start (first few checkouts).
const MIN_COUNT_THRESHOLD = 1;

// Max score a collaborative signal can contribute (normalised from count).
// Capped at 4.5 so it sits just below FREQUENTLY_BOUGHT_TOGETHER (5) but
// above collection matches (4) once enough signal accumulates.
const MAX_COLLABORATIVE_SCORE = 4.5;

// Count at which the score reaches MAX_COLLABORATIVE_SCORE.
// e.g. 50 co-purchases → score 4.5
const COUNT_SATURATION = 50;

// ---------------------------------------------------------------------------
// recordCoPurchases — call this when a user checks out
// ---------------------------------------------------------------------------

/**
 * Records every product pair from the checkout cart into Firestore.
 * Uses a batch write so all increments are atomic.
 *
 * @param {Array<{ productId: string }>} cartItems
 * @returns {Promise<void>}
 */
async function recordCoPurchases(cartItems) {
  if (!cartItems || cartItems.length < 2) return;

  const ids = cartItems.map((i) => i.productId).filter(Boolean);
  if (ids.length < 2) return;

  const batch = db.batch();
  const now   = new Date().toISOString();

  for (let i = 0; i < ids.length; i++) {
    for (let j = i + 1; j < ids.length; j++) {
      // Sort so the pair key is always the same regardless of cart order
      const [a, b] = [ids[i], ids[j]].sort();
      const pairKey = `${a}|${b}`;
      const ref = db.collection(COLLECTION).doc(pairKey);

      batch.set(
        ref,
        {
          productA: a,
          productB: b,
          count:    admin.firestore.FieldValue.increment(1),
          lastSeen: now,
        },
        { merge: true }
      );
    }
  }

  await batch.commit();
  console.log(`[coPurchaseService] Recorded ${(ids.length * (ids.length - 1)) / 2} pairs for ${ids.length} items`);
}

// ---------------------------------------------------------------------------
// getCoPurchaseCandidates — call during recommendation
// ---------------------------------------------------------------------------

/**
 * For each product in the cart, fetches its top co-purchased neighbours
 * from Firestore and returns them as scored recommendation candidates.
 *
 * Score formula: min(MAX_COLLABORATIVE_SCORE, count / COUNT_SATURATION * MAX_COLLABORATIVE_SCORE)
 * This gives a score of 0→4.5 as count grows from 0→50+.
 *
 * @param {Set<string>|string[]} cartProductIds
 * @returns {Promise<Array<{ productId: string, score: number, source: "collaborative", context: string }>>}
 */
async function getCoPurchaseCandidates(cartProductIds) {
  const ids = cartProductIds instanceof Set
    ? Array.from(cartProductIds)
    : cartProductIds;

  if (!ids || ids.length === 0) return [];

  const results = [];
  const seen    = new Set(); // dedup across multiple cart products

  await Promise.all(
    ids.map(async (productId) => {
      // Query pairs where this product is productA
      const [snapA, snapB] = await Promise.all([
        db.collection(COLLECTION)
          .where("productA", "==", productId)
          .where("count", ">=", MIN_COUNT_THRESHOLD)
          .orderBy("count", "desc")
          .limit(5)
          .get(),
        db.collection(COLLECTION)
          .where("productB", "==", productId)
          .where("count", ">=", MIN_COUNT_THRESHOLD)
          .orderBy("count", "desc")
          .limit(5)
          .get(),
      ]);

      const docs = [...snapA.docs, ...snapB.docs];

      for (const doc of docs) {
        const data       = doc.data();
        const neighbourId = data.productA === productId ? data.productB : data.productA;

        // Skip if already in cart or already added from another cart product
        if (ids.includes(neighbourId)) continue;
        if (seen.has(neighbourId)) continue;
        seen.add(neighbourId);

        const score = Math.min(
          MAX_COLLABORATIVE_SCORE,
          (data.count / COUNT_SATURATION) * MAX_COLLABORATIVE_SCORE
        );

        results.push({
          productId: neighbourId,
          score,
          source:  "collaborative",
          context: "Frequently Bought Together",
        });
      }
    })
  );

  return results;
}

// ---------------------------------------------------------------------------
// Exports
// ---------------------------------------------------------------------------

module.exports = {
  recordCoPurchases,
  getCoPurchaseCandidates,
};
