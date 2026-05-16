"use strict";

/**
 * services/saveForLater.js
 *
 * Manages the save-for-later list for each user. Products with availability
 * "NLA" are automatically routed here by cartService.js instead of the active
 * cart (Requirement 4.1).
 *
 * Exports:
 *   addItem(userId, sku)              — add a product to the save-for-later list
 *   getList(userId)                   — return the save-for-later array for a user
 *   recordNotify(userId, productId)   — record a re-engagement notification request
 */

// ---------------------------------------------------------------------------
// In-memory state
// ---------------------------------------------------------------------------

/**
 * Map<userId, Array<saveForLaterItem>>
 *
 * Each item has the shape:
 *   {
 *     productId:    string,   // sku.id
 *     name:         string,   // sku.name
 *     price:        number,   // sku.price.sellingPrice
 *     imagePath:    string,   // sku.media.images[0].path
 *     availability: string    // sku.availability
 *   }
 */
const saveForLaterLists = new Map();

/**
 * In-memory log of notification requests.
 * Array<{ userId: string, productId: string, requestedAt: string }>
 */
const notifyLog = [];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Returns the save-for-later list for a user, initialising it to an empty
 * array if it does not yet exist.
 *
 * @param {string} userId
 * @returns {Array}
 */
function _getOrCreateList(userId) {
  if (!saveForLaterLists.has(userId)) {
    saveForLaterLists.set(userId, []);
  }
  return saveForLaterLists.get(userId);
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Adds a product to the user's save-for-later list.
 * If the product is already present (matched by productId), it is NOT added
 * again — idempotent (Requirement 4.4).
 *
 * @param {string} userId
 * @param {object} sku  — full SKU object from skus.json
 */
function addItem(userId, sku) {
  const list = _getOrCreateList(userId);

  // Idempotency check — do not add duplicates
  const alreadyPresent = list.some((item) => item.productId === sku.id);
  if (alreadyPresent) return;

  list.push({
    productId:    sku.id,
    name:         sku.name,
    price:        sku.price.sellingPrice,
    imagePath:    sku.media.images[0].path,
    availability: sku.availability,
  });
}

/**
 * Returns the save-for-later array for the given user.
 * Returns an empty array if the user has no save-for-later list yet
 * (Requirement 4.4).
 *
 * @param {string} userId
 * @returns {Array}
 */
function getList(userId) {
  return saveForLaterLists.get(userId) || [];
}

/**
 * Records a re-engagement notification request for a product in the
 * save-for-later list (Requirement 4.5, 4.6).
 *
 * Throws a 404 error if the product is not in the user's save-for-later list.
 *
 * @param {string} userId
 * @param {string} productId
 * @returns {{ success: true, productId: string }}
 */
function recordNotify(userId, productId) {
  const list = getList(userId);
  const inList = list.some((item) => item.productId === productId);

  if (!inList) {
    const err = new Error("Product not in save-for-later list");
    err.status = 404;
    err.code   = "NOT_IN_SAVE_FOR_LATER";
    throw err;
  }

  // Record the notification request in the in-memory log
  notifyLog.push({
    userId,
    productId,
    requestedAt: new Date().toISOString(),
  });

  return { success: true, productId };
}

// ---------------------------------------------------------------------------
// Exports
// ---------------------------------------------------------------------------

module.exports = {
  addItem,
  getList,
  recordNotify,
};
