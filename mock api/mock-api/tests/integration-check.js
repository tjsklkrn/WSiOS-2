/**
 * integration-check.js
 *
 * End-to-end smoke test for all API endpoints.
 * Bypasses Firebase token verification by monkey-patching the middleware
 * so we can test the full cart/registry/recommendation pipeline without
 * a live Firebase project token.
 *
 * Run: node tests/integration-check.js
 */

"use strict";

require("dotenv").config();

// ── Patch firebaseAuth middleware BEFORE any route module is loaded ────────
// Stub out the middleware so it always sets req.firebaseUid and req.cartUserId
// without hitting Firebase, allowing full end-to-end testing locally.
const Module = require("module");
const originalLoad = Module._load;
Module._load = function (request, parent, isMain) {
  if (
    request.includes("firebaseAuth") ||
    (parent && parent.filename && parent.filename.includes("routes") && request.endsWith("firebaseAuth"))
  ) {
    // Return a stub middleware that always authenticates as test-uid-001
    return function stubFirebaseAuth(req, res, next) {
      req.firebaseUid = "test-uid-001";
      req.cartUserId  = "user_001";
      next();
    };
  }
  return originalLoad.apply(this, arguments);
};

// ── Now load the app ───────────────────────────────────────────────────────
const express = require("express");
const { buildGraph } = require("../services/productGraph");

buildGraph();

const app = express();
app.use(express.json());
app.use("/cart",     require("../routes/cart"));
app.use("/registry", require("../routes/registry"));
app.use("/search",   require("../routes/search"));
app.use((err, req, res, next) => {
  res.status(err.status || 500).json({ error: err.message, code: err.code });
});

const http = require("http");
const server = http.createServer(app);

// ── Helpers ────────────────────────────────────────────────────────────────

let pass = 0;
let fail = 0;

function assert(label, condition, detail = "") {
  if (condition) {
    console.log(`  ✔ ${label}`);
    pass++;
  } else {
    console.error(`  ✘ ${label}${detail ? " — " + detail : ""}`);
    fail++;
  }
}

function request(method, path, body, headers = {}) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: "127.0.0.1",
      port: 0,          // filled in after server.listen
      path,
      method,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer mock-token",
        ...headers,
      },
    };
    options.port = server.address().port;

    const req = http.request(options, (res) => {
      let data = "";
      res.on("data", (chunk) => (data += chunk));
      res.on("end", () => {
        try {
          resolve({ status: res.statusCode, body: JSON.parse(data) });
        } catch {
          resolve({ status: res.statusCode, body: data });
        }
      });
    });
    req.on("error", reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

// ── Test suites ────────────────────────────────────────────────────────────

async function testCartEndpoints() {
  console.log("\n── Cart Endpoints ──────────────────────────────────────────");

  // GET /cart — empty cart
  let r = await request("GET", "/cart");
  assert("GET /cart returns 200", r.status === 200);
  assert("GET /cart has items array", Array.isArray(r.body.items));
  assert("GET /cart has saveForLater array", Array.isArray(r.body.saveForLater));
  assert("GET /cart has totalPrice", typeof r.body.totalPrice === "number");
  assert("GET /cart has totalItems", typeof r.body.totalItems === "number");
  assert("GET /cart empty cart totalPrice=0", r.body.totalPrice === 0);

  // POST /cart/items — add ON_HAND product
  r = await request("POST", "/cart/items", { productId: "2453926", quantity: 1 });
  assert("POST /cart/items ON_HAND returns 200", r.status === 200);
  assert("POST /cart/items adds item to cart", r.body.items.length === 1);
  assert("POST /cart/items correct productId", r.body.items[0].productId === "2453926");
  assert("POST /cart/items totalPrice > 0", r.body.totalPrice > 0);
  assert("POST /cart/items totalItems = 1", r.body.totalItems === 1);
  assert("POST /cart/items backOrdered=false", r.body.items[0].backOrdered === false);

  // POST /cart/items — add BACK_ORDERED product
  r = await request("POST", "/cart/items", { productId: "8227593", quantity: 1 });
  assert("POST /cart/items BACK_ORDERED returns 200", r.status === 200);
  assert("POST /cart/items BACK_ORDERED in active items", r.body.items.some(i => i.productId === "8227593"));
  assert("POST /cart/items BACK_ORDERED has backOrdered=true", r.body.items.find(i => i.productId === "8227593")?.backOrdered === true);

  // POST /cart/items — add NLA product (should go to saveForLater)
  r = await request("POST", "/cart/items", { productId: "1341411", quantity: 1 });
  assert("POST /cart/items NLA returns 200", r.status === 200);
  assert("POST /cart/items NLA NOT in active items", !r.body.items.some(i => i.productId === "1341411"));
  assert("POST /cart/items NLA in saveForLater", r.body.saveForLater.some(i => i.productId === "1341411"));

  // POST /cart/items — unknown productId
  r = await request("POST", "/cart/items", { productId: "UNKNOWN_999", quantity: 1 });
  assert("POST /cart/items unknown productId returns 404", r.status === 404);
  assert("POST /cart/items unknown productId has PRODUCT_NOT_FOUND code", r.body.code === "PRODUCT_NOT_FOUND");

  // POST /cart/items — missing fields
  r = await request("POST", "/cart/items", { productId: "2453926" });
  assert("POST /cart/items missing quantity returns 400", r.status === 400);

  // GET /cart — verify state after adds
  r = await request("GET", "/cart");
  assert("GET /cart after adds has 2 active items", r.body.items.length === 2);
  assert("GET /cart after adds has 1 saveForLater", r.body.saveForLater.length === 1);

  // DELETE /cart/items/:productId
  r = await request("DELETE", "/cart/items/2453926");
  assert("DELETE /cart/items returns 200", r.status === 200);
  assert("DELETE /cart/items removes item", !r.body.items.some(i => i.productId === "2453926"));

  // DELETE /cart/items/:productId — not in cart
  r = await request("DELETE", "/cart/items/2453926");
  assert("DELETE /cart/items not-in-cart returns 404", r.status === 404);

  // POST /cart/save-for-later/:productId/notify — product in saveForLater
  r = await request("POST", "/cart/save-for-later/1341411/notify");
  assert("POST notify for saveForLater item returns 200", r.status === 200);
  assert("POST notify returns success:true", r.body.success === true);

  // POST /cart/save-for-later/:productId/notify — product NOT in saveForLater
  r = await request("POST", "/cart/save-for-later/2453926/notify");
  assert("POST notify for non-saveForLater item returns 404", r.status === 404);
  assert("POST notify returns NOT_IN_SAVE_FOR_LATER code", r.body.code === "NOT_IN_SAVE_FOR_LATER");
}

async function testBundleEndpoint() {
  console.log("\n── Bundle Detection ────────────────────────────────────────");

  // Add two Staub products (same collection: staub-cast-iron) to trigger a bundle
  await request("POST", "/cart/items", { productId: "2453926", quantity: 1 }); // Staub Dutch Oven
  await request("POST", "/cart/items", { productId: "181543",  quantity: 1 }); // Staub Skillet

  const r = await request("GET", "/cart/bundles");
  assert("GET /cart/bundles returns 200", r.status === 200);
  assert("GET /cart/bundles has bundles array", Array.isArray(r.body.bundles));
  assert("GET /cart/bundles detects at least 1 bundle", r.body.bundles.length >= 1);

  if (r.body.bundles.length > 0) {
    const bundle = r.body.bundles[0];
    assert("Bundle has productIds array", Array.isArray(bundle.productIds));
    assert("Bundle has sharedPropertyType", typeof bundle.sharedPropertyType === "string");
    assert("Bundle has sharedPropertyValue", typeof bundle.sharedPropertyValue === "string");
    assert("Bundle has discountLabel", typeof bundle.discountLabel === "string");
    assert("Bundle has valid registryCategory", typeof bundle.registryCategory === "string");
    const validCategories = ["Cookware","Bakeware","Cutlery & Knives","Electrics","Tabletop & Bar","Food & Entertaining","Storage & Organization"];
    assert("Bundle registryCategory is one of 7 valid values", validCategories.includes(bundle.registryCategory));
  }
}

async function testRecommendationsEndpoint() {
  console.log("\n── Recommendations ─────────────────────────────────────────");

  const r = await request("GET", "/cart/recommendations");
  assert("GET /cart/recommendations returns 200", r.status === 200);
  assert("GET /cart/recommendations has recommendations array", Array.isArray(r.body.recommendations));

  if (r.body.recommendations.length > 0) {
    const rec = r.body.recommendations[0];
    assert("Recommendation has productId", typeof rec.productId === "string");
    assert("Recommendation has score", typeof rec.score === "number");
    assert("Recommendation has source", typeof rec.source === "string");
    assert("Recommendation has name", typeof rec.name === "string");
    assert("Recommendation has price", typeof rec.price === "number");
    assert("Recommendation has imagePath", typeof rec.imagePath === "string");
    assert("Recommendation has availability", typeof rec.availability === "string");
    assert("Recommendations at most 5", r.body.recommendations.length <= 5);

    // Verify no cart items appear in recommendations
    const cartR = await request("GET", "/cart");
    const cartIds = new Set(cartR.body.items.map(i => i.productId));
    const noCartItemsInRecs = r.body.recommendations.every(rec => !cartIds.has(rec.productId));
    assert("No cart items appear in recommendations", noCartItemsInRecs);
  } else {
    console.log("  ℹ No recommendations returned (Pinecone not seeded — graph-only results expected)");
    assert("GET /cart/recommendations returns empty array gracefully", true);
  }
}

async function testRegistryEndpoints() {
  console.log("\n── Registry Endpoints ──────────────────────────────────────");

  // POST /registry — invalid eventType
  let r = await request("POST", "/registry", {
    firstName: "Jane", lastName: "Smith",
    eventType: "invalid", eventDate: "2025-09-15"
  });
  assert("POST /registry invalid eventType returns 400", r.status === 400);
  assert("POST /registry invalid eventType has INVALID_EVENT_TYPE code", r.body.code === "INVALID_EVENT_TYPE");

  // POST /registry — invalid eventDate
  r = await request("POST", "/registry", {
    firstName: "Jane", lastName: "Smith",
    eventType: "wedding", eventDate: "not-a-date"
  });
  assert("POST /registry invalid eventDate returns 400", r.status === 400);
  assert("POST /registry invalid eventDate has INVALID_EVENT_DATE code", r.body.code === "INVALID_EVENT_DATE");

  // POST /registry — valid (writes to Firestore)
  r = await request("POST", "/registry", {
    firstName: "Jane", lastName: "Smith",
    eventType: "wedding", eventDate: "2025-09-15",
    coRegistrantFirstName: "John", coRegistrantLastName: "Smith"
  });
  assert("POST /registry valid returns 201", r.status === 201);
  assert("POST /registry returns registryId", typeof r.body.registryId === "string");
  assert("POST /registry returns eventType", r.body.eventType === "wedding");
  assert("POST /registry returns items:[]", Array.isArray(r.body.items) && r.body.items.length === 0);
  assert("POST /registry does NOT expose ownerUid", r.body.ownerUid === undefined);

  const registryId = r.body.registryId;

  // GET /registry/search — by registryId
  r = await request("GET", `/registry/search?registryId=${registryId}`, null, { Authorization: "" });
  assert("GET /registry/search by registryId returns 200", r.status === 200);
  assert("GET /registry/search returns results array", Array.isArray(r.body.results));
  assert("GET /registry/search finds the registry", r.body.results.length === 1);
  assert("GET /registry/search result has no items array", r.body.results[0].items === undefined);

  // GET /registry/search — by name (case-insensitive)
  r = await request("GET", `/registry/search?firstName=JANE&lastName=SMITH`, null, { Authorization: "" });
  assert("GET /registry/search by name (uppercase) returns 200", r.status === 200);
  assert("GET /registry/search by name finds registry", r.body.results.length >= 1);

  // GET /registry/search — missing params
  r = await request("GET", `/registry/search`, null, { Authorization: "" });
  assert("GET /registry/search no params returns 400", r.status === 400);
  assert("GET /registry/search no params has MISSING_SEARCH_PARAMS code", r.body.code === "MISSING_SEARCH_PARAMS");

  // POST /registry/:id/items — unknown productId
  r = await request("POST", `/registry/${registryId}/items`, {
    productId: "UNKNOWN_999", quantity: 1, categoryId: "cookware"
  });
  assert("POST /registry/:id/items unknown productId returns 404", r.status === 404);

  // POST /registry/:id/items — invalid categoryId
  r = await request("POST", `/registry/${registryId}/items`, {
    productId: "2453926", quantity: 1, categoryId: "invalid-cat"
  });
  assert("POST /registry/:id/items invalid categoryId returns 400", r.status === 400);
  assert("POST /registry/:id/items invalid categoryId has INVALID_CATEGORY_ID code", r.body.code === "INVALID_CATEGORY_ID");

  // POST /registry/:id/items — valid add
  r = await request("POST", `/registry/${registryId}/items`, {
    productId: "2453926", quantity: 1, categoryId: "cookware"
  });
  assert("POST /registry/:id/items valid returns 200", r.status === 200);
  assert("POST /registry/:id/items has itemsByCategory", typeof r.body.itemsByCategory === "object");
  assert("POST /registry/:id/items item in cookware", Array.isArray(r.body.itemsByCategory.cookware));

  // POST /registry/:id/items — duplicate productId+categoryId increments quantity
  r = await request("POST", `/registry/${registryId}/items`, {
    productId: "2453926", quantity: 2, categoryId: "cookware"
  });
  assert("POST /registry/:id/items duplicate increments quantity", r.body.itemsByCategory.cookware[0].quantity === 3);

  // GET /registry/:id/items — public
  r = await request("GET", `/registry/${registryId}/items`, null, { Authorization: "" });
  assert("GET /registry/:id/items returns 200", r.status === 200);
  assert("GET /registry/:id/items has itemsByCategory", typeof r.body.itemsByCategory === "object");

  // GET /registry/:id/dashboard — public
  r = await request("GET", `/registry/${registryId}/dashboard`, null, { Authorization: "" });
  assert("GET /registry/:id/dashboard returns 200", r.status === 200);
  assert("GET /registry/:id/dashboard has totalItems", typeof r.body.totalItems === "number");
  assert("GET /registry/:id/dashboard has totalValue", typeof r.body.totalValue === "number");
  assert("GET /registry/:id/dashboard has byCategory array", Array.isArray(r.body.byCategory));
  assert("GET /registry/:id/dashboard totalItems = 3", r.body.totalItems === 3);

  // PATCH /registry/:id — update metadata
  r = await request("PATCH", `/registry/${registryId}`, { isPublic: false });
  assert("PATCH /registry/:id returns 200", r.status === 200);
  assert("PATCH /registry/:id updates isPublic", r.body.isPublic === false);

  // GET /registry/:id/dashboard — now private, should 404
  r = await request("GET", `/registry/${registryId}/dashboard`, null, { Authorization: "" });
  assert("GET /registry/:id/dashboard on private registry returns 404", r.status === 404);

  // PATCH back to public for cleanup
  await request("PATCH", `/registry/${registryId}`, { isPublic: true });

  // DELETE /registry/:id/items/:productId
  r = await request("DELETE", `/registry/${registryId}/items/2453926`);
  assert("DELETE /registry/:id/items/:productId returns 200", r.status === 200);
  assert("DELETE /registry/:id/items/:productId removes item", !r.body.itemsByCategory.cookware);

  // DELETE /registry/:id — cleanup
  r = await request("DELETE", `/registry/${registryId}`);
  assert("DELETE /registry/:id returns 200", r.status === 200);

  // Verify deleted
  r = await request("GET", `/registry/search?registryId=${registryId}`, null, { Authorization: "" });
  assert("GET /registry/search after delete returns 404", r.status === 404);
}

async function testRegistryGetAndPurchased() {
  console.log("\n── Registry GET/:id + Purchased Toggle ─────────────────────");

  // Create a registry with one item to test against
  let r = await request("POST", "/registry", {
    firstName: "Alice", lastName: "Wonder",
    eventType: "housewarming", eventDate: "2025-11-01",
    coRegistrantFirstName: "Bob", coRegistrantLastName: "Wonder"
  });
  assert("Setup: POST /registry returns 201", r.status === 201);
  const registryId = r.body.registryId;

  // Add an item
  await request("POST", `/registry/${registryId}/items`, {
    productId: "2453926", quantity: 2, categoryId: "cookware"
  });

  // ── GET /registry/:id ──────────────────────────────────────────────────

  // Public registry — should return metadata
  r = await request("GET", `/registry/${registryId}`, null, { Authorization: "" });
  assert("GET /registry/:id returns 200", r.status === 200);
  assert("GET /registry/:id has registryId", r.body.registryId === registryId);
  assert("GET /registry/:id has firstName", r.body.firstName === "Alice");
  assert("GET /registry/:id has lastName", r.body.lastName === "Wonder");
  assert("GET /registry/:id has eventType", r.body.eventType === "housewarming");
  assert("GET /registry/:id has eventDate", r.body.eventDate === "2025-11-01");
  assert("GET /registry/:id has isPublic", r.body.isPublic === true);
  assert("GET /registry/:id has createdAt", typeof r.body.createdAt === "string");
  assert("GET /registry/:id has coRegistrantFirstName", r.body.coRegistrantFirstName === "Bob");
  assert("GET /registry/:id does NOT expose ownerUid", r.body.ownerUid === undefined);
  assert("GET /registry/:id does NOT expose items array", r.body.items === undefined);

  // Make private — should 404
  await request("PATCH", `/registry/${registryId}`, { isPublic: false });
  r = await request("GET", `/registry/${registryId}`, null, { Authorization: "" });
  assert("GET /registry/:id private registry returns 404", r.status === 404);

  // Restore public
  await request("PATCH", `/registry/${registryId}`, { isPublic: true });

  // Non-existent registry — should 404
  r = await request("GET", `/registry/nonexistent-id-xyz`, null, { Authorization: "" });
  assert("GET /registry/:id non-existent returns 404", r.status === 404);

  // ── PATCH purchased toggle ─────────────────────────────────────────────

  // Mark as purchased — valid
  r = await request("PATCH", `/registry/${registryId}/items/2453926/purchased`,
    { purchased: true }, { Authorization: "" });
  assert("PATCH purchased returns 200", r.status === 200);
  assert("PATCH purchased sets purchased=true", r.body.purchased === true);
  assert("PATCH purchased updates item in response", r.body.itemsByCategory?.cookware?.[0]?.purchased === true);
  assert("PATCH purchased returns registryId", r.body.registryId === registryId);
  assert("PATCH purchased returns productId", r.body.productId === "2453926");

  // Verify dashboard reflects purchased count
  r = await request("GET", `/registry/${registryId}/dashboard`, null, { Authorization: "" });
  assert("Dashboard purchasedCount = 2 after toggle", r.body.purchasedCount === 2);
  assert("Dashboard remainingCount = 0 after toggle", r.body.remainingCount === 0);

  // Mark as unpurchased — toggle back
  r = await request("PATCH", `/registry/${registryId}/items/2453926/purchased`,
    { purchased: false }, { Authorization: "" });
  assert("PATCH purchased toggle back to false returns 200", r.status === 200);
  assert("PATCH purchased sets purchased=false", r.body.purchased === false);

  // Verify dashboard reflects unpurchased
  r = await request("GET", `/registry/${registryId}/dashboard`, null, { Authorization: "" });
  assert("Dashboard purchasedCount = 0 after untoggle", r.body.purchasedCount === 0);
  assert("Dashboard remainingCount = 2 after untoggle", r.body.remainingCount === 2);

  // Invalid body — not a boolean
  r = await request("PATCH", `/registry/${registryId}/items/2453926/purchased`,
    { purchased: "yes" }, { Authorization: "" });
  assert("PATCH purchased invalid body returns 400", r.status === 400);
  assert("PATCH purchased invalid body has INVALID_PURCHASED_VALUE code", r.body.code === "INVALID_PURCHASED_VALUE");

  // Missing purchased field
  r = await request("PATCH", `/registry/${registryId}/items/2453926/purchased`,
    {}, { Authorization: "" });
  assert("PATCH purchased missing field returns 400", r.status === 400);

  // Unknown productId
  r = await request("PATCH", `/registry/${registryId}/items/UNKNOWN_999/purchased`,
    { purchased: true }, { Authorization: "" });
  assert("PATCH purchased unknown productId returns 404", r.status === 404);

  // Unknown registryId
  r = await request("PATCH", `/registry/nonexistent-xyz/items/2453926/purchased`,
    { purchased: true }, { Authorization: "" });
  assert("PATCH purchased unknown registryId returns 404", r.status === 404);

  // Cleanup
  await request("DELETE", `/registry/${registryId}`);
}

async function testSearchEndpoint() {
  console.log("\n── Semantic Search (Pinecone) ──────────────────────────────");

  // Missing query param
  let r = await request("GET", "/search", null, { Authorization: "" });
  assert("GET /search missing q returns 400", r.status === 400);
  assert("GET /search missing q has MISSING_QUERY code", r.body.code === "MISSING_QUERY");

  // Keyword search
  r = await request("GET", "/search?q=cast+iron+cookware", null, { Authorization: "" });
  assert("GET /search keyword query returns 200", r.status === 200);
  assert("GET /search has results array", Array.isArray(r.body.results));
  assert("GET /search has source field", typeof r.body.source === "string");
  assert("GET /search returns at most 5 results by default", r.body.results.length <= 5);

  if (r.body.results.length > 0) {
    const top = r.body.results[0];
    assert("Search result has productId", typeof top.productId === "string");
    assert("Search result has name", typeof top.name === "string");
    assert("Search result has price", typeof top.price === "number");
    assert("Search result has imagePath", typeof top.imagePath === "string");
    assert("Search result has availability", typeof top.availability === "string");
    assert("Search result has score", typeof top.score === "number");
    assert("Search 'cast iron' top result is Dutch Oven or Skillet",
      top.productId === "2453926" || top.productId === "181543");
  }

  // Natural language query
  r = await request("GET", "/search?q=gift+for+a+chef", null, { Authorization: "" });
  assert("GET /search natural language returns 200", r.status === 200);
  assert("GET /search natural language has results", r.body.results.length > 0);

  // topK param
  r = await request("GET", "/search?q=cookware&topK=3", null, { Authorization: "" });
  assert("GET /search topK=3 returns at most 3 results", r.body.results.length <= 3);

  // topK clamped to max 10
  r = await request("GET", "/search?q=cookware&topK=99", null, { Authorization: "" });
  assert("GET /search topK=99 clamped to max 10", r.body.results.length <= 10);

  // Results are sorted by score descending
  r = await request("GET", "/search?q=dutch+oven", null, { Authorization: "" });
  if (r.body.results.length > 1) {
    const scores = r.body.results.map(x => x.score);
    const isSorted = scores.every((s, i) => i === 0 || s <= scores[i - 1]);
    assert("GET /search results sorted by score descending", isSorted);
  }
}

// ── Main ───────────────────────────────────────────────────────────────────

async function main() {
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const port = server.address().port;
  console.log(`\nIntegration test server on port ${port}`);

  try {
    await testCartEndpoints();
    await testBundleEndpoint();
    await testRecommendationsEndpoint();
    await testRegistryEndpoints();
    await testRegistryGetAndPurchased();
    await testSearchEndpoint();
  } catch (err) {
    console.error("\nUnhandled error during tests:", err);
    fail++;
  }

  server.close();

  console.log(`\n${"─".repeat(55)}`);
  console.log(`Results: ${pass} passed, ${fail} failed`);
  if (fail > 0) {
    console.error("Some checks FAILED.");
    process.exit(1);
  } else {
    console.log("All checks PASSED ✔");
  }
}

main();
