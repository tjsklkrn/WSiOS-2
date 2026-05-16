"use strict";

/**
 * routes/cart.js
 *
 * Express router for all /cart/* endpoints.
 * All routes are protected by the firebaseAuth middleware.
 *
 * Endpoints (Task 8.1):
 *   POST   /cart/items                        — add item to cart
 *   GET    /cart                              — get current cart state
 *   DELETE /cart/items/:productId             — remove item from cart
 *
 * Endpoints (Task 8.2 — added in next task):
 *   GET    /cart/recommendations              — get AI/graph recommendations
 *   GET    /cart/bundles                      — get detected bundles
 *   POST   /cart/save-for-later/:productId/notify — request back-in-stock notification
 *
 * Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7, 8.8, 8.9
 */

const express = require("express");
const router = express.Router();

const firebaseAuth = require("../middleware/firebaseAuth");
const cartService = require("../services/cartService");
const mcpOrchestrator = require("../services/mcpOrchestrator");
const bundleDetector = require("../services/bundleDetector");
const saveForLater = require("../services/saveForLater");

// ---------------------------------------------------------------------------
// Apply firebaseAuth middleware to ALL routes on this router (Requirement 6.1)
// ---------------------------------------------------------------------------
router.use(firebaseAuth);

// ---------------------------------------------------------------------------
// POST /cart/items — Add item to cart
// Requirements: 8.1, 8.3, 8.7, 8.8, 8.9
// ---------------------------------------------------------------------------

/**
 * POST /cart/items
 *
 * Body: { productId: string, quantity: number }
 *
 * Returns the updated cart state on success (HTTP 200).
 * Returns HTTP 400 if productId or quantity is missing.
 * Returns HTTP 404 with { error, code: "PRODUCT_NOT_FOUND" } if productId is unknown.
 */
router.post("/items", async (req, res, next) => {
  try {
    const { productId, quantity } = req.body;

    // Validate required fields (Requirement 8.7)
    if (!productId || quantity === undefined || quantity === null) {
      return res.status(400).json({
        error: "Missing required fields: productId and quantity are required",
      });
    }

    const parsedQuantity = Number(quantity);
    if (!Number.isInteger(parsedQuantity) || parsedQuantity < 1) {
      return res.status(400).json({
        error: "quantity must be a positive integer",
      });
    }

    const cart = cartService.addItem(req.cartUserId, productId, parsedQuantity);

    // Requirement 8.8: Content-Type: application/json (set by Express by default with res.json)
    return res.status(200).json(cart);
  } catch (err) {
    if (err.status === 404 && err.code === "PRODUCT_NOT_FOUND") {
      return res.status(404).json({ error: err.message, code: "PRODUCT_NOT_FOUND" });
    }
    next(err);
  }
});

// ---------------------------------------------------------------------------
// GET /cart — Get current cart state
// Requirements: 8.4, 8.8, 8.9
// ---------------------------------------------------------------------------

/**
 * GET /cart
 *
 * Returns the full cart state for the authenticated user.
 * Response includes totalPrice and totalItems (Requirement 8.9).
 */
router.get("/", async (req, res, next) => {
  try {
    const cart = cartService.getCart(req.cartUserId);

    // Requirement 8.8: Content-Type: application/json
    return res.status(200).json(cart);
  } catch (err) {
    next(err);
  }
});

// ---------------------------------------------------------------------------
// DELETE /cart/items/:productId — Remove item from cart
// Requirements: 8.3, 8.8, 8.9
// ---------------------------------------------------------------------------

/**
 * DELETE /cart/items/:productId
 *
 * Removes the specified product from the active cart.
 * Returns the updated cart state on success (HTTP 200).
 * Returns HTTP 404 if the productId is not in the cart.
 */
router.delete("/items/:productId", async (req, res, next) => {
  try {
    const { productId } = req.params;

    const cart = cartService.removeItem(req.cartUserId, productId);

    // Requirement 8.8: Content-Type: application/json
    return res.status(200).json(cart);
  } catch (err) {
    if (err.status === 404) {
      return res.status(404).json({ error: err.message, code: err.code || "PRODUCT_NOT_IN_CART" });
    }
    next(err);
  }
});

// ---------------------------------------------------------------------------
// GET /cart/recommendations — Get AI/graph product recommendations
// Requirements: 8.2, 8.5
// ---------------------------------------------------------------------------

/**
 * GET /cart/recommendations
 *
 * Returns product recommendations based on the current cart contents.
 * Fans out to the product graph (sync) and Pinecone (async, 1000ms timeout),
 * merges, grounds, and attaches metadata.
 *
 * Response: { recommendations: [...] }
 */
router.get("/recommendations", async (req, res, next) => {
  try {
    const { items } = cartService.getCart(req.cartUserId);
    const recommendations = await mcpOrchestrator.getRecommendations(items);
    return res.status(200).json({ recommendations });
  } catch (err) {
    next(err);
  }
});

// ---------------------------------------------------------------------------
// GET /cart/bundles — Get detected product bundles
// Requirements: 8.6
// ---------------------------------------------------------------------------

/**
 * GET /cart/bundles
 *
 * Detects collection-first then brand-cluster bundles from the active cart.
 *
 * Response: { bundles: [...] }  (empty array if no bundles detected)
 */
router.get("/bundles", async (req, res, next) => {
  try {
    const { items } = cartService.getCart(req.cartUserId);
    const bundles = bundleDetector.detectBundles(items);
    return res.status(200).json({ bundles: bundles || [] });
  } catch (err) {
    next(err);
  }
});

// ---------------------------------------------------------------------------
// POST /cart/save-for-later/:productId/notify — Request back-in-stock notification
// Requirements: 4.5, 4.6
// ---------------------------------------------------------------------------

/**
 * POST /cart/save-for-later/:productId/notify
 *
 * Records a re-engagement notification request for a product in the
 * save-for-later list.
 *
 * Returns HTTP 200 on success.
 * Returns HTTP 404 with { error, code: "NOT_IN_SAVE_FOR_LATER" } if the
 * product is not in the user's save-for-later list.
 */
router.post("/save-for-later/:productId/notify", async (req, res, next) => {
  try {
    const { productId } = req.params;
    saveForLater.recordNotify(req.cartUserId, productId);
    return res.status(200).json({ success: true, productId });
  } catch (err) {
    if (err.status === 404 && err.code === "NOT_IN_SAVE_FOR_LATER") {
      return res.status(404).json({ error: err.message, code: "NOT_IN_SAVE_FOR_LATER" });
    }
    next(err);
  }
});

module.exports = router;
