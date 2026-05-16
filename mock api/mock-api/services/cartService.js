"use strict";

/**
 * services/cartService.js
 *
 * In-memory cart state management keyed by userId.
 *
 * Exports:
 *   addItem(userId, productId, quantity)  — add/increment item; routes NLA to save-for-later
 *   removeItem(userId, productId)         — remove item from active cart
 *   getCart(userId)                       — return full cart state
 *
 * Requirements: 4.1, 4.2, 4.3, 8.1, 8.3, 8.4, 8.9
 */

const { skusMap } = require("./productGraph");
const saveForLater = require("./saveForLater");

// ---------------------------------------------------------------------------
// In-memory cart store: Map<userId, Map<productId, cartItem>>
// ---------------------------------------------------------------------------

/**
 * @type {Map<string, Map<string, { productId: string, name: string, price: number, imagePath: string, quantity: number, availability: string, backOrdered: boolean }>>}
 */
const carts = new Map();

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/**
 * Returns the cart item map for a user, creating it if it doesn't exist.
 *
 * @param {string} userId
 * @returns {Map<string, object>}
 */
function getOrCreateCart(userId) {
  if (!carts.has(userId)) {
    carts.set(userId, new Map());
  }
  return carts.get(userId);
}

/**
 * Creates a structured error with a status code and error code.
 *
 * @param {string} message
 * @param {number} status
 * @param {string} code
 * @returns {Error}
 */
function createError(message, status, code) {
  const err = new Error(message);
  err.status = status;
  err.code = code;
  return err;
}

// ---------------------------------------------------------------------------
// addItem
// ---------------------------------------------------------------------------

/**
 * Adds a product to the user's cart, handling availability routing:
 *   - NLA        → delegated to saveForLater; not added to active cart
 *   - BACK_ORDERED → added to active cart with backOrdered: true
 *   - ON_HAND / other → added/incremented normally
 *
 * @param {string} userId
 * @param {string} productId
 * @param {number} quantity
 * @returns {{ userId: string, items: object[], saveForLater: object[], totalPrice: number, totalItems: number }}
 * @throws {Error} HTTP 404 if productId not found in skusMap
 */
function addItem(userId, productId, quantity) {
  // Look up SKU (Requirement 4.3 — read availability from skus.json at runtime)
  const sku = skusMap.get(productId);
  if (!sku) {
    throw createError("Product not found", 404, "PRODUCT_NOT_FOUND");
  }

  const availability = sku.availability;

  // NLA → route to save-for-later (Requirement 4.1)
  if (availability === "NLA") {
    saveForLater.addItem(userId, sku);
    return getCart(userId);
  }

  const cartItems = getOrCreateCart(userId);

  if (availability === "BACK_ORDERED") {
    // BACK_ORDERED → add to active cart with backOrdered: true (Requirement 4.2)
    if (cartItems.has(productId)) {
      cartItems.get(productId).quantity += quantity;
    } else {
      cartItems.set(productId, {
        productId,
        name: sku.name,
        price: sku.price.sellingPrice,
        imagePath: sku.media.images[0].path,
        quantity,
        availability,
        backOrdered: true,
      });
    }
  } else {
    // ON_HAND or any other status → add/increment normally
    if (cartItems.has(productId)) {
      cartItems.get(productId).quantity += quantity;
    } else {
      cartItems.set(productId, {
        productId,
        name: sku.name,
        price: sku.price.sellingPrice,
        imagePath: sku.media.images[0].path,
        quantity,
        availability,
        backOrdered: false,
      });
    }
  }

  return getCart(userId);
}

// ---------------------------------------------------------------------------
// removeItem
// ---------------------------------------------------------------------------

/**
 * Removes a product from the user's active cart.
 *
 * @param {string} userId
 * @param {string} productId
 * @returns {{ userId: string, items: object[], saveForLater: object[], totalPrice: number, totalItems: number }}
 * @throws {Error} HTTP 404 if productId is not in the active cart
 */
function removeItem(userId, productId) {
  const cartItems = getOrCreateCart(userId);

  if (!cartItems.has(productId)) {
    throw createError(
      `Product ${productId} is not in the cart`,
      404,
      "PRODUCT_NOT_IN_CART"
    );
  }

  cartItems.delete(productId);
  return getCart(userId);
}

// ---------------------------------------------------------------------------
// getCart
// ---------------------------------------------------------------------------

/**
 * Returns the full cart state for a user.
 *
 * Response shape (Requirement 8.9):
 * {
 *   userId,
 *   items: [{ productId, name, price, imagePath, quantity, availability, backOrdered }],
 *   saveForLater: [{ productId, name, price, imagePath, availability }],
 *   totalPrice,   // sum(sellingPrice × quantity) for active items
 *   totalItems    // sum(quantity) for active items
 * }
 *
 * @param {string} userId
 * @returns {{ userId: string, items: object[], saveForLater: object[], totalPrice: number, totalItems: number }}
 */
function getCart(userId) {
  const cartItems = getOrCreateCart(userId);

  const items = Array.from(cartItems.values());

  // Compute totals (Requirement 8.9)
  let totalPrice = 0;
  let totalItems = 0;
  for (const item of items) {
    totalPrice += item.price * item.quantity;
    totalItems += item.quantity;
  }

  // Round to 2 decimal places to avoid floating-point drift
  totalPrice = Math.round(totalPrice * 100) / 100;

  return {
    userId,
    items,
    saveForLater: saveForLater.getList(userId),
    totalPrice,
    totalItems,
  };
}

// ---------------------------------------------------------------------------
// Exports
// ---------------------------------------------------------------------------

module.exports = {
  addItem,
  removeItem,
  getCart,
};
