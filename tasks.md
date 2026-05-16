# Implementation Plan: Smart Cart & Smart Registry

## Overview

Backend-only Node.js/Express implementation extending `mock api/mock-api/server.js`. The plan follows an 8-phase dependency order: Foundation → Product Graph → Cart Services → Pinecone + MCP → Cart Routes → Registry Routes → Server Integration → Property-Based Tests. All new files live under `mock api/mock-api/`.

---

## Tasks

- [ ] 1. Install npm dependencies and create domain-rules.json
  - [ ] 1.1 Install `firebase-admin` and `@pinecone-database/pinecone` packages
    - Run `npm install firebase-admin@^12.0.0 @pinecone-database/pinecone@^3.0.0` in `mock api/mock-api/`
    - Verify both packages appear in `package.json` dependencies
    - _Requirements: 6.1, 7.5, 14.3_

  - [ ] 1.2 Create `domain-rules.json` with all 6 functional domain rules
    - Create `mock api/mock-api/domain-rules.json`
    - Include all 6 rules from the design: `cutting-boards-storage → cutting-board-oil` (MAINTAINED_BY, weight 3), `dutch-ovens → fry-pans-skillets` (RELATED_CATEGORY, weight 4), `coffee-maker → cups-and-saucers` (COMPLEMENTARY_USAGE, weight 2), `dutch-ovens → cutting-boards-storage` (COMPLEMENTARY_USAGE, weight 2), `oil → dutch-ovens` (COMPLEMENTARY_USAGE, weight 2), `oil → fry-pans-skillets` (COMPLEMENTARY_USAGE, weight 2)
    - Each rule object must have: `sourceProductType`, `targetProductType`, `relation`, `context`, `weight`
    - _Requirements: 1.7_


- [ ] 2. Create Firebase Admin SDK initialization and auth middleware
  - [ ] 2.1 Create `firebase/adminInit.js` — Firebase Admin SDK singleton
    - Create `mock api/mock-api/firebase/adminInit.js`
    - Check `admin.apps.length` to prevent double-initialization
    - Support both `FIREBASE_SERVICE_ACCOUNT_JSON` (JSON string) and `FIREBASE_SERVICE_ACCOUNT_PATH` (file path) env vars; throw if neither is set
    - Pass `projectId: process.env.FIREBASE_PROJECT_ID` to `initializeApp`
    - Export the `admin` instance as the module default
    - _Requirements: 14.3_

  - [ ] 2.2 Create `middleware/firebaseAuth.js` — JWT validation middleware
    - Create `mock api/mock-api/middleware/firebaseAuth.js`
    - Import `adminInit.js`; call `admin.auth().verifyIdToken(token)` on the Bearer token
    - Return HTTP 401 `{ error: "Missing or malformed Authorization header" }` if `Authorization` header is absent or does not start with `"Bearer "`
    - Return HTTP 401 `{ error: "Invalid or expired Firebase token" }` on verification failure
    - On success, attach `req.firebaseUid = decoded.uid` and `req.cartUserId = "user_001"`
    - Export the middleware function
    - _Requirements: 6.1, 6.2, 6.3_


- [ ] 3. Create `services/productGraph.js` — in-memory product relationship graph
  - [ ] 3.1 Implement `parseArrayString(value)` utility and Product/Brand/Material node construction
    - Create `mock api/mock-api/services/productGraph.js`
    - Implement `parseArrayString(value)`: if value starts with `[` and ends with `]`, split on `,` and trim each element; otherwise return `[value.trim()]`; return `[]` for non-strings
    - Load `responses/skus.json` at module load time; build a `skusMap` (Map of `id → sku`)
    - For each SKU, create a Product node: `{ id: "prod_{sku.id}", type: "Product", name, price: sku.price.sellingPrice, availability: sku.availability, imagePath: sku.media.images[0].path }`
    - For each unique brand value (after `parseArrayString`), create a Brand node `{ id: "brand_{slug}", type: "Brand", label }` and a `BRANDED_BY` edge from the Product node
    - For each unique material value (after `parseArrayString`), create a Material node `{ id: "material_{slug}", type: "Material", label }` and a `MADE_OF` edge from the Product node
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.8_

  - [ ] 3.2 Implement RELATED_CATEGORY edge construction with weight hierarchy
    - After all nodes are created, iterate all Product node pairs
    - For each pair, compute the highest-priority shared property: collection = 4, brand = 3, productType = 2, material = 1 (use `parseArrayString` on each property)
    - If any shared property exists, create a `RELATED_CATEGORY` edge with the computed weight and a `context` label derived from the shared collection or productType cluster name
    - Add edges in both directions to the adjacency index
    - _Requirements: 1.5, 1.6_

  - [ ] 3.3 Implement COMPLEMENTARY_USAGE and MAINTAINED_BY edges from domain-rules.json
    - Load `domain-rules.json` at module load time
    - For each rule, find all Product nodes whose `productType` (after `parseArrayString`) matches `sourceProductType`, and all Product nodes matching `targetProductType`
    - Create directed edges with the rule's `relation`, `context`, and `weight`; add both directions to the adjacency index
    - Export `buildGraph()` (constructs and freezes the singleton) and `getGraph()` (returns the singleton); export `skusMap` for use by other services
    - _Requirements: 1.7, 1.9_

  - [ ]* 3.4 Write property tests for graph node construction (Properties 1–4)
    - **Property 1: Product Graph Node Construction Invariants** — for any SKU, verify Product/Brand/Material nodes and BRANDED_BY/MADE_OF edges exist with correct field values
    - **Property 2: Array String Parser Round-Trip** — for any `"[a, b, c]"` string, verify output matches manual split+trim; for scalar strings, verify single-element array
    - **Property 3: RELATED_CATEGORY Edge Weight Hierarchy** — for any two SKUs sharing collection or productType, verify edge weight is 4 for collection match, 2 for productType-only match
    - **Property 4: Domain Rules Edge Construction** — for any rule in domain-rules.json, verify directed edges exist between matching Product nodes with correct relation/context/weight
    - **Validates: Requirements 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 3.7**
    - _Requirements: 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8_


- [ ] 4. Checkpoint — Graph foundation complete
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 5. Create cart and save-for-later services
  - [ ] 5.1 Create `services/cartService.js` — in-memory cart state
    - Create `mock api/mock-api/services/cartService.js`
    - Maintain a `carts` Map keyed by `userId` (always `"user_001"` in practice)
    - Implement `addItem(userId, productId, quantity)`: look up SKU in `skusMap`; if not found throw a 404 error; if `availability === "NLA"` delegate to `saveForLater.addItem` and return cart state; if `availability === "BACK_ORDERED"` add to active items with `backOrdered: true`; otherwise add/increment normally
    - Implement `removeItem(userId, productId)`: remove from active items; return updated cart state
    - Implement `getCart(userId)`: return `{ userId, items, saveForLater, totalPrice, totalItems }` where `totalPrice = sum(sellingPrice × quantity)` for active items and `totalItems = sum(quantity)` for active items
    - _Requirements: 4.1, 4.2, 4.3, 8.1, 8.3, 8.4, 8.9_

  - [ ] 5.2 Create `services/saveForLater.js` — save-for-later list management
    - Create `mock api/mock-api/services/saveForLater.js`
    - Maintain a `saveForLaterLists` Map keyed by `userId`
    - Implement `addItem(userId, sku)`: add product to the save-for-later list if not already present
    - Implement `getList(userId)`: return the save-for-later array for the user
    - Implement `recordNotify(userId, productId)`: if `productId` is not in the save-for-later list, throw a 404 error with code `NOT_IN_SAVE_FOR_LATER`; otherwise record the notification request (in-memory log) and return success
    - _Requirements: 4.4, 4.5, 4.6_

  - [ ] 5.3 Create `services/bundleDetector.js` — collection-first then brand-cluster detection
    - Create `mock api/mock-api/services/bundleDetector.js`
    - Import `parseArrayString` from `productGraph.js` and `skusMap`
    - Implement `detectBundles(cartItems)`: Step 1 — collection clustering using `parseArrayString` on `sku.properties.collection`; any collection with ≥2 items forms a bundle; track `usedInCollectionBundle` set
    - Step 2 — brand clustering on remaining items (not in a collection bundle) using `parseArrayString` on `sku.properties.brand`; any brand with ≥2 items forms a bundle
    - Implement `buildBundle(items, sharedPropertyType, sharedPropertyValue)`: assign `registryCategory` from `PRODUCT_TYPE_TO_REGISTRY_CATEGORY` map using the highest-priced item's `productType`; build `discountLabel`; return bundle object per design schema
    - Include the full `PRODUCT_TYPE_TO_REGISTRY_CATEGORY` and `VALID_REGISTRY_CATEGORIES` maps from the design document
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7_

  - [ ]* 5.4 Write property tests for cart services (Properties 7, 8, 9)
    - **Property 7: Bundle Detection Invariants** — verify collection bundles form before brand bundles, registryCategory is always one of 7 valid values, highest-priced item determines category
    - **Property 8: Availability Routing Invariants** — verify NLA products land in saveForLater only, BACK_ORDERED products land in items with backOrdered:true, saveForLater array always present
    - **Property 9: Cart Total Price Calculation** — verify totalPrice = sum(sellingPrice × quantity) and totalItems = sum(quantity) for any cart state
    - **Validates: Requirements 3.1, 3.2, 3.4, 3.5, 4.1, 4.2, 4.4, 8.9**
    - _Requirements: 3.1, 3.2, 3.4, 3.5, 4.1, 4.2, 4.4, 8.9_


- [ ] 6. Create Pinecone service and seed script
  - [ ] 6.1 Create `scripts/seedPinecone.js` — one-time Pinecone upsert script
    - Create `mock api/mock-api/scripts/seedPinecone.js`
    - Load `responses/skus.json`; for each SKU build the embedding text string: `"{name} | brand: {brand} | productType: {productType} | material: {material} | collection: {collection}"` (join array-valued properties with spaces after `parseArrayString`)
    - Initialize Pinecone client using `PINECONE_API_KEY` env var; get index by `PINECONE_INDEX_NAME`
    - Upsert records in batches of 10 using integrated inference text upsert: `{ id: sku.id, text: embeddingText, metadata: { productId, name, productType, brand } }`
    - Target namespace `"ws-products"`; log success/failure per batch
    - _Requirements: 7.1, 7.5_

  - [ ] 6.2 Create `services/pineconeService.js` — text-based query using integrated inference
    - Create `mock api/mock-api/services/pineconeService.js`
    - Initialize Pinecone client from `PINECONE_API_KEY`; get index from `PINECONE_INDEX_NAME`; use namespace `"ws-products"`
    - Implement `buildEmbeddingText(sku)`: same text format as seed script
    - Implement `queryForCart(cartProductIds)`: for each productId in the set, look up SKU from `skusMap`; if not found log a warning and skip; call `pineconeIndex.searchRecords({ query: { inputs: { text: queryText }, topK: 10 }, namespace: "ws-products" })`; collect hits excluding self; return `[{ productId: hit._id, score: hit._score, source: "pinecone" }]`
    - Export `queryForCart`
    - _Requirements: 7.2, 7.3, 7.4, 7.5_

  - [ ] 6.3 Create `services/mcpOrchestrator.js` — parallel fan-out, merge, ground, attach metadata
    - Create `mock api/mock-api/services/mcpOrchestrator.js`
    - Import `getGraph` from `productGraph.js`, `queryForCart` from `pineconeService.js`, `skusMap` from `productGraph.js`
    - Implement `traverseForRecommendations(cartProductIds, graph)`: for each cart product, walk the adjacency index; collect neighbor Product nodes (skip Brand/Material nodes); return `[{ productId, score: edge.weight, source: "graph", context: edge.context }]`
    - Implement `mergeCandidates(graphCandidates, pineconeCandidates, cartProductIds)`: build `scoreMap`; graph source always wins on duplicate; normalize Pinecone scores by ×4; exclude cart items; sort descending; return top 5
    - Implement `getRecommendations(cartItems)`: fan out graph traversal (sync) and Pinecone query (async) using `Promise.all` + `Promise.race` with 1000ms timeout; merge; ground against graph nodes (`graph.nodes.has("prod_" + c.productId)`); attach metadata from `skusMap`; return recommendations array
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 5.1, 5.2, 5.3, 5.4, 5.5_

  - [ ]* 6.4 Write property tests for merge algorithm and grounding (Properties 5, 6)
    - **Property 5: Recommendations Merge Algorithm Invariants** — verify no duplicate productIds, graph score retained when both sources present, sorted descending, at most 5 results, no cart items in output
    - **Property 6: Recommendation Grounding and Metadata Completeness** — verify every returned productId exists in the Product Graph, and name/price/imagePath/availability match skus.json
    - **Validates: Requirements 2.3, 2.4, 2.5, 2.6, 5.2, 5.3, 5.5**
    - _Requirements: 2.3, 2.4, 2.5, 2.6, 5.2, 5.3, 5.5_


- [ ] 7. Checkpoint — Services complete
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 8. Create `routes/cart.js` — all cart route handlers
  - [ ] 8.1 Implement cart state endpoints: POST /cart/items, GET /cart, DELETE /cart/items/:productId
    - Create `mock api/mock-api/routes/cart.js`
    - Apply `firebaseAuth` middleware to the router (all routes protected)
    - `POST /cart/items`: validate `productId` and `quantity` in body; call `cartService.addItem(req.cartUserId, productId, quantity)`; return updated cart state; return HTTP 404 with `{ error, code: "PRODUCT_NOT_FOUND" }` if productId unknown
    - `GET /cart`: call `cartService.getCart(req.cartUserId)`; return cart state JSON
    - `DELETE /cart/items/:productId`: call `cartService.removeItem(req.cartUserId, req.params.productId)`; return updated cart state; HTTP 404 if productId not in cart
    - All responses include `Content-Type: application/json`; all include `totalPrice` and `totalItems`
    - _Requirements: 8.1, 8.3, 8.4, 8.7, 8.8, 8.9_

  - [ ] 8.2 Implement recommendation, bundle, and save-for-later endpoints
    - `GET /cart/recommendations`: get active cart items; call `mcpOrchestrator.getRecommendations(items)`; return `{ recommendations: [...] }`
    - `GET /cart/bundles`: get active cart items; call `bundleDetector.detectBundles(items)`; return `{ bundles: [...] }` (empty array if none)
    - `POST /cart/save-for-later/:productId/notify`: call `saveForLater.recordNotify(req.cartUserId, req.params.productId)`; return HTTP 200 on success; HTTP 404 with `{ error, code: "NOT_IN_SAVE_FOR_LATER" }` if product not in save-for-later list
    - Export the Express router
    - _Requirements: 8.2, 8.5, 8.6, 4.5, 4.6_

  - [ ]* 8.3 Write property test for Firebase auth enforcement (Property 10)
    - **Property 10: Firebase Auth Enforcement on Cart Endpoints** — verify all cart endpoints return HTTP 401 when Authorization header is absent or token is invalid; verify existing /login, /profile, /feed, /skus endpoints respond normally without Authorization header
    - **Validates: Requirements 6.1, 6.2, 6.5**
    - _Requirements: 6.1, 6.2, 6.5_


- [ ] 9. Create `routes/registry.js` — all registry route handlers
  - [ ] 9.1 Implement registry creation and search endpoints
    - Create `mock api/mock-api/routes/registry.js`
    - Import `adminInit.js` to get the `admin` instance; get `db = admin.firestore()`
    - `POST /registry` (auth required via `firebaseAuth`): validate `eventType` is one of `wedding|housewarming|birthday|anniversary` (HTTP 400, code `INVALID_EVENT_TYPE` if not); validate `eventDate` is a valid ISO 8601 date string (HTTP 400, code `INVALID_EVENT_DATE` if not); build document with `ownerUid: req.firebaseUid`, `firstNameLower`, `lastNameLower`, `createdAt`, `items: []`, `isPublic: true`; write to Firestore `registries` collection; return HTTP 201 with created document (excluding `ownerUid`)
    - `GET /registry/search` (public, no auth): require at least `registryId` or one of `firstName`/`lastName` (HTTP 400, code `MISSING_SEARCH_PARAMS` if neither); if `registryId` provided, fetch doc and return HTTP 404 if not found or `isPublic: false`; if name search, query using `firstNameLower`/`lastNameLower` fields; return `{ results: [...] }` with metadata only (no items array)
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7, 10.8, 11.1, 11.2, 11.3, 11.4, 11.5, 11.6, 11.7_

  - [ ] 9.2 Implement registry item management endpoints
    - `GET /registry/:registryId/items` (public): fetch registry doc; return items grouped by `categoryId` as `{ registryId, itemsByCategory: { [categoryId]: [...items] } }`; HTTP 404 if not found
    - `POST /registry/:registryId/items` (auth + ownerUid check): validate `productId` exists in `skusMap` (HTTP 404, code `PRODUCT_NOT_FOUND`); validate `categoryId` is one of 7 valid IDs (HTTP 400, code `INVALID_CATEGORY_ID`); if product+category combo already exists, increment quantity atomically via Firestore transaction; otherwise append new item; return updated items
    - `PATCH /registry/:registryId/items/:productId` (auth + ownerUid check): update `quantity` or move to new `categoryId`; use Firestore transaction; return updated items
    - `DELETE /registry/:registryId/items/:productId` (auth + ownerUid check): remove all entries for that `productId` from the items array atomically; return updated items
    - For all write endpoints: verify `req.firebaseUid === registry.ownerUid`; return HTTP 403 with code `FORBIDDEN` on mismatch
    - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5, 12.6, 12.7, 12.8, 12.9, 12.10, 14.4_

  - [ ] 9.3 Implement registry dashboard, delete, and metadata update endpoints
    - `GET /registry/:registryId/dashboard` (public): fetch registry doc; compute `totalItems`, `totalValue`, `purchasedCount`, `remainingCount`, `purchasedValue`, `remainingValue`; build `byCategory` array (one entry per categoryId with ≥1 item); return HTTP 404 if not found or `isPublic: false`
    - `DELETE /registry/:registryId` (auth + ownerUid check): delete entire Firestore document; return HTTP 200 on success; HTTP 403 on uid mismatch
    - `PATCH /registry/:registryId` (auth + ownerUid check): accept `{ isPublic, eventDate, coRegistrantFirstName, coRegistrantLastName }`; validate `eventDate` if provided; update Firestore document; return updated metadata
    - Export the Express router
    - _Requirements: 13.1, 13.2, 13.3, 13.4, 14.5, 14.6, 14.7_

  - [ ]* 9.4 Write property tests for registry item management and dashboard (Properties 11, 12, 13)
    - **Property 11: Registry Item Management Invariants** — verify HTTP 404 for unknown productId, HTTP 400 for invalid categoryId, HTTP 403 for uid mismatch, quantity increment on duplicate productId+categoryId
    - **Property 12: Registry Dashboard Calculation Correctness** — verify totalItems, totalValue, purchasedCount, remainingCount, purchasedValue, remainingValue, and byCategory entries are all mathematically correct for any items array
    - **Property 13: Registry Name Search Case-Insensitivity** — verify any casing variant of firstName/lastName returns the registry when isPublic:true
    - **Validates: Requirements 11.3, 12.2, 12.3, 12.4, 12.9, 13.1, 13.2**
    - _Requirements: 11.3, 12.2, 12.3, 12.4, 12.9, 13.1, 13.2_


- [ ] 10. Update `server.js` — mount routes and wire startup
  - [ ] 10.1 Extend `server.js` with graph startup, route mounting, and error handler
    - Modify `mock api/mock-api/server.js`
    - Add `require("./firebase/adminInit")` at the top to trigger Firebase SDK initialization before any request is handled
    - Import `buildGraph` from `services/productGraph.js`; call `buildGraph()` synchronously before `app.listen()` so the graph is ready before the first request
    - Import and mount `routes/cart.js` at `/cart`: `app.use("/cart", require("./routes/cart"))`
    - Import and mount `routes/registry.js` at `/registry`: `app.use("/registry", require("./routes/registry"))`
    - Add centralized error handler middleware as the last `app.use` call: `app.use((err, req, res, next) => { console.error(err); res.status(err.status || 500).json({ error: err.message || "Internal server error", code: err.code || "INTERNAL_ERROR" }); })`
    - Existing `/health`, `/login`, `/profile`, `/feed`, `/skus` endpoints must remain unchanged
    - _Requirements: 1.1, 6.4, 6.5, 8.8, 14.8_

- [ ] 11. Checkpoint — Full integration complete
  - Ensure all tests pass, ask the user if questions arise.


- [ ] 12. Write property-based tests for all 13 correctness properties
  - [ ] 12.1 Set up property-based testing framework
    - Install `fast-check` as a dev dependency: `npm install --save-dev fast-check@^3.0.0`
    - Create `mock api/mock-api/tests/` directory
    - Create `mock api/mock-api/tests/pbt.test.js` as the main test file
    - Configure a test runner (add `"test": "node --test tests/pbt.test.js"` to `package.json` scripts, or use Jest if preferred)
    - _Requirements: all_

  - [ ]* 12.2 Write property tests for graph construction (Properties 1–4)
    - **Property 1: Product Graph Node Construction Invariants** — use `fc.record` to generate arbitrary SKU-like objects; call `buildGraph([sku])`; assert Product/Brand/Material nodes and edges exist with correct field values
    - **Property 2: Array String Parser Round-Trip** — use `fc.array(fc.string())` to generate element lists; construct `"[a, b, c]"` strings; assert `parseArrayString` output matches manual split+trim
    - **Property 3: RELATED_CATEGORY Edge Weight Hierarchy** — generate pairs of SKUs with controlled shared properties; assert edge weight = 4 for collection match, 2 for productType-only
    - **Property 4: Domain Rules Edge Construction** — for each rule in domain-rules.json, generate SKU pairs matching source/target productType; assert edges exist with correct relation/context/weight
    - **Validates: Requirements 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8**

  - [ ]* 12.3 Write property tests for merge algorithm and grounding (Properties 5–6)
    - **Property 5: Recommendations Merge Algorithm Invariants** — use `fc.array` to generate graph and Pinecone candidate lists; assert no duplicates, graph score retained, sorted descending, ≤5 results, no cart items in output
    - **Property 6: Recommendation Grounding and Metadata Completeness** — assert every productId in recommendations exists in the Product Graph and metadata fields match skus.json
    - **Validates: Requirements 2.3, 2.4, 2.5, 2.6, 5.2, 5.3, 5.5**

  - [ ]* 12.4 Write property tests for cart services (Properties 7–9)
    - **Property 7: Bundle Detection Invariants** — generate cart states with controlled collection/brand overlaps; assert collection bundles form first, registryCategory always valid, highest-priced item determines category
    - **Property 8: Availability Routing Invariants** — generate productId inputs with NLA/BACK_ORDERED/ON_HAND availability; assert correct routing and saveForLater always present in response
    - **Property 9: Cart Total Price Calculation** — generate arbitrary cart item arrays; assert totalPrice and totalItems match computed sums
    - **Validates: Requirements 3.1, 3.2, 3.4, 3.5, 4.1, 4.2, 4.4, 8.9**

  - [ ]* 12.5 Write property tests for auth enforcement and registry (Properties 10–13)
    - **Property 10: Firebase Auth Enforcement on Cart Endpoints** — assert HTTP 401 for missing/invalid token on all cart endpoints; assert existing endpoints unaffected
    - **Property 11: Registry Item Management Invariants** — assert HTTP 404/400/403 for invalid inputs; assert quantity increment on duplicate productId+categoryId
    - **Property 12: Registry Dashboard Calculation Correctness** — generate arbitrary items arrays; assert all dashboard totals are mathematically correct
    - **Property 13: Registry Name Search Case-Insensitivity** — generate firstName/lastName strings; assert any casing variant returns the registry
    - **Validates: Requirements 6.1, 6.2, 6.5, 11.3, 12.2, 12.3, 12.4, 12.9, 13.1, 13.2**

- [ ] 13. Final checkpoint — All tests pass
  - Ensure all tests pass, ask the user if questions arise.


---

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP
- Each task references specific requirements for traceability
- The seed script (`scripts/seedPinecone.js`) is a one-time operation — run `node scripts/seedPinecone.js` before the demo after setting `PINECONE_API_KEY` and `PINECONE_INDEX_NAME` env vars
- Firebase Admin SDK requires either `FIREBASE_SERVICE_ACCOUNT_JSON` or `FIREBASE_SERVICE_ACCOUNT_PATH` to be set; `FIREBASE_PROJECT_ID` is recommended
- Cart state is in-memory only — a server restart clears all carts (by design for the hackathon demo)
- Registry state is persisted in Firestore and survives server restarts
- The `user_001` hardcoded cart key prevents cart loss on Firebase token expiry during the demo
- Property tests use `fast-check` for generative testing; each property maps directly to a design document property number

---

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2"] },
    { "id": 1, "tasks": ["2.1", "2.2"] },
    { "id": 2, "tasks": ["3.1"] },
    { "id": 3, "tasks": ["3.2", "3.3"] },
    { "id": 4, "tasks": ["3.4", "5.1", "5.2", "5.3", "6.1", "6.2"] },
    { "id": 5, "tasks": ["5.4", "6.3"] },
    { "id": 6, "tasks": ["6.4", "8.1", "9.1"] },
    { "id": 7, "tasks": ["8.2", "9.2"] },
    { "id": 8, "tasks": ["8.3", "9.3"] },
    { "id": 9, "tasks": ["9.4", "10.1"] },
    { "id": 10, "tasks": ["12.1"] },
    { "id": 11, "tasks": ["12.2", "12.3", "12.4", "12.5"] }
  ]
}
```