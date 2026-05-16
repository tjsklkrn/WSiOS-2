# Design Document — Smart Cart & Smart Registry

## Overview

This document covers the backend architecture for the Williams Sonoma iOS hackathon app's **Smart Cart** and **Smart Registry** features. All implementation targets the Node.js/Express server at `mock api/mock-api/server.js` (port 3001). No SwiftUI changes are in scope.

---

## 1. System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        iOS SwiftUI App                          │
│   CartRepository / CartViewModel / RegistryRepository           │
└────────────────────────────┬────────────────────────────────────┘
                             │ HTTP/JSON (port 3001)
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Express API Gateway (server.js)               │
│                                                                 │
│  ┌──────────────────┐   ┌──────────────────────────────────┐   │
│  │ firebaseAuth.js  │   │  routes/cart.js                  │   │
│  │ (JWT middleware) │──▶│  routes/registry.js              │   │
│  └──────────────────┘   └──────────────┬─────────────────-─┘   │
└────────────────────────────────────────┼────────────────────────┘
                                         │
              ┌──────────────────────────┼──────────────────────┐
              │                          │                       │
              ▼                          ▼                       ▼
┌─────────────────────┐   ┌─────────────────────────┐  ┌───────────────────┐
│  MCP Orchestrator   │   │  cartService.js          │  │  Firebase Admin   │
│  (mcpOrchestrator)  │   │  saveForLater.js         │  │  SDK (adminInit)  │
└──────┬──────────────┘   └─────────────────────────┘  └────────┬──────────┘
       │                                                          │
  ┌────┴──────────────────────┐                                  ▼
  │                           │                        ┌──────────────────┐
  ▼                           ▼                        │    Firestore     │
┌──────────────────┐  ┌──────────────────┐             │  registries/{id} │
│ productGraph.js  │  │ pineconeService  │             └──────────────────┘
│ (graph traversal)│  │ (vector search)  │
└──────────────────┘  └──────────────────┘
       │
       ▼
┌──────────────────┐
│  bundleDetector  │
│  .js             │
└──────────────────┘
       │
       ▼
┌──────────────────┐
│  skus.json       │
│  (Product DB)    │
└──────────────────┘
```

**Request flow — Smart Cart:**
1. iOS app sends `Authorization: Bearer <token>` on all cart/recommendation requests.
2. `firebaseAuth.js` middleware validates the JWT; rejects with HTTP 401 on failure.
3. `routes/cart.js` dispatches to `mcpOrchestrator.js`, `cartService.js`, or `saveForLater.js`.
4. `mcpOrchestrator.js` fans out to `productGraph.js` (sync) and `pineconeService.js` (async, 1000ms timeout).
5. Results are merged, grounded against the Product Graph, metadata attached from `skus.json`, and returned.

**Request flow — Smart Registry:**
1. Write endpoints require `Authorization: Bearer <token>` validated by `firebaseAuth.js`.
2. `routes/registry.js` uses Firebase Admin SDK via `firebase/adminInit.js` to read/write Firestore.
3. All registry state lives in Firestore `registries/{registryId}`; no in-memory registry state on the server.


---

## 2. File / Module Structure

```
mock api/mock-api/
├── server.js                   # existing — extended with new routes + startup graph build
├── domain-rules.json           # new — functional domain relationship rules
├── responses/
│   └── skus.json               # existing — product catalog (read-only at runtime)
├── services/
│   ├── productGraph.js         # graph construction + traversal
│   ├── pineconeService.js      # Pinecone integrated inference upsert + query (no external AI API)
│   ├── bundleDetector.js       # bundle detection logic
│   ├── mcpOrchestrator.js      # parallel coordination + grounding + metadata attachment
│   ├── cartService.js          # in-memory cart state (keyed by user_001)
│   └── saveForLater.js         # NLA/BACK_ORDERED routing + notify endpoint logic
├── middleware/
│   └── firebaseAuth.js         # Firebase JWT validation middleware
├── routes/
│   ├── cart.js                 # all /cart/* route handlers
│   └── registry.js             # all /registry/* route handlers
└── firebase/
    └── adminInit.js            # Firebase Admin SDK initialization (singleton)
```

**Changes to `server.js`:**
- Import and mount `routes/cart.js` at `/cart`
- Import and mount `routes/registry.js` at `/registry`
- Call `productGraph.buildGraph()` at startup before `app.listen()`
- Import `firebase/adminInit.js` to trigger SDK initialization


---

## 3. Product Graph Data Model

The graph is a plain JavaScript object built once at startup and exported as a frozen singleton.

### Node Schema

```js
// Product node
{
  id: "prod_2453926",          // "prod_" + sku.id
  type: "Product",
  name: "Staub Enameled Cast Iron Round Dutch Oven, 7-Qt., Basil",
  price: 299.95,               // sku.price.sellingPrice
  availability: "ON_HAND",     // sku.availability
  imagePath: "/img83m.jpg"     // sku.media.images[0].path
}

// Brand node
{
  id: "brand_staub",           // "brand_" + slugify(brandValue)
  type: "Brand",
  label: "staub"
}

// Material node
{
  id: "material_enameled-cast-iron",   // "material_" + slugify(materialValue)
  type: "Material",
  label: "enameled-cast-iron"
}
```

### Edge Schema

```js
{
  source: "prod_2453926",
  target: "brand_staub",
  relation: "BRANDED_BY",      // BRANDED_BY | MADE_OF | RELATED_CATEGORY | COMPLEMENTARY_USAGE | MAINTAINED_BY
  weight: 3,                   // numeric weight (1–4); 0 for non-product edges
  context: null                // string label for RELATED_CATEGORY / COMPLEMENTARY_USAGE / MAINTAINED_BY
}
```

### In-Memory Adjacency Representation

```js
// services/productGraph.js — exported singleton
const graph = {
  nodes: new Map(),   // nodeId (string) → node object
  edges: [],          // flat array of all edge objects
  // adjacency index: productId → array of { neighborId, relation, weight, context }
  adjacency: new Map()
};

// Example adjacency entry for prod_2453926:
graph.adjacency.get("prod_2453926") === [
  { neighborId: "brand_staub",          relation: "BRANDED_BY",        weight: 3, context: null },
  { neighborId: "material_enameled-cast-iron", relation: "MADE_OF",    weight: 1, context: null },
  { neighborId: "prod_181543",          relation: "RELATED_CATEGORY",  weight: 4, context: "staub-cast-iron" }
]
```

### Array-Valued Property Parser

SKU properties like `"[he-pantry, he-fridge]"` are NOT valid JSON (unquoted elements). A custom parser handles them:

```js
// Parses "[he-pantry, he-fridge]" → ["he-pantry", "he-fridge"]
// Parses "williams-sonoma" → ["williams-sonoma"]  (scalar passthrough)
function parseArrayString(value) {
  if (typeof value !== "string") return [];
  const trimmed = value.trim();
  if (trimmed.startsWith("[") && trimmed.endsWith("]")) {
    return trimmed
      .slice(1, -1)
      .split(",")
      .map(s => s.trim())
      .filter(Boolean);
  }
  return [trimmed];
}
```

This function is used by both `productGraph.js` and `bundleDetector.js` to ensure consistent parsing.


---

## 4. domain-rules.json Schema

```json
{
  "rules": [
    {
      "sourceProductType": "cutting-boards-storage",
      "targetProductType": "cutting-board-oil",
      "relation": "MAINTAINED_BY",
      "context": "Product Care Duo",
      "weight": 3
    },
    {
      "sourceProductType": "dutch-ovens",
      "targetProductType": "fry-pans-skillets",
      "relation": "RELATED_CATEGORY",
      "context": "Premium Cookware Set",
      "weight": 4
    },
    {
      "sourceProductType": "coffee-maker",
      "targetProductType": "cups-and-saucers",
      "relation": "COMPLEMENTARY_USAGE",
      "context": "Coffee & Tea Station",
      "weight": 2
    },
    {
      "sourceProductType": "dutch-ovens",
      "targetProductType": "cutting-boards-storage",
      "relation": "COMPLEMENTARY_USAGE",
      "context": "Cookware Prep Essentials",
      "weight": 2
    },
    {
      "sourceProductType": "oil",
      "targetProductType": "dutch-ovens",
      "relation": "COMPLEMENTARY_USAGE",
      "context": "Cooking Essentials",
      "weight": 2
    },
    {
      "sourceProductType": "oil",
      "targetProductType": "fry-pans-skillets",
      "relation": "COMPLEMENTARY_USAGE",
      "context": "Cooking Essentials",
      "weight": 2
    }
  ]
}
```

**Schema fields:**
- `sourceProductType` — matches `sku.properties.productType` (or any value from `allProductTypes` after array parsing)
- `targetProductType` — same
- `relation` — one of `COMPLEMENTARY_USAGE` | `MAINTAINED_BY` | `RELATED_CATEGORY`
- `context` — human-readable label attached to the edge
- `weight` — numeric edge weight (1–4)

**Graph construction logic for domain rules:**
For each rule, find all Product nodes where `productType` matches `sourceProductType`, and all Product nodes where `productType` matches `targetProductType`. Create a directed edge from each source node to each target node with the specified relation, context, and weight. Edges are bidirectional for traversal purposes (both directions added to the adjacency index).


---

## 5. MCP Orchestrator Design

### Sequence Diagram

```
iOS Client          cart.js route       mcpOrchestrator.js     productGraph.js    pineconeService.js
    │                    │                      │                      │                   │
    │ GET /cart/recs     │                      │                      │                   │
    │───────────────────▶│                      │                      │                   │
    │                    │ getRecommendations() │                      │                   │
    │                    │─────────────────────▶│                      │                   │
    │                    │                      │                      │                   │
    │                    │                      │ traverseGraph(       │                   │
    │                    │                      │   cartProductIds)    │                   │
    │                    │                      │─────────────────────▶│                   │
    │                    │                      │                      │                   │
    │                    │                      │ queryPinecone(       │                   │
    │                    │                      │   cartProductIds)    │                   │
    │                    │                      │──────────────────────────────────────────▶│
    │                    │                      │                      │                   │
    │                    │                      │◀─────────────────────│ graphCandidates   │
    │                    │                      │                      │                   │
    │                    │                      │◀──────────────────────────────────────────│
    │                    │                      │  pineconeCandidates (or timeout after 1s) │
    │                    │                      │                      │                   │
    │                    │                      │ merge(graph, pinecone)                    │
    │                    │                      │ dedup + rank                              │
    │                    │                      │ excludeCartItems                          │
    │                    │                      │ top5                                      │
    │                    │                      │                      │                   │
    │                    │                      │ groundAgainstGraph(candidates)            │
    │                    │                      │─────────────────────▶│                   │
    │                    │                      │◀─────────────────────│ verified IDs       │
    │                    │                      │                      │                   │
    │                    │                      │ attachMetadata(verified, skus)            │
    │                    │◀─────────────────────│ recommendations[]                        │
    │◀───────────────────│                      │                      │                   │
    │  { recommendations }                      │                      │                   │
```

### Orchestrator Implementation Sketch

```js
// services/mcpOrchestrator.js
async function getRecommendations(cartItems, graph, skusMap) {
  const cartProductIds = new Set(cartItems.map(i => i.productId));

  // Fan out: graph traversal (sync wrapped in Promise) + Pinecone (async with timeout)
  const graphPromise = Promise.resolve(graph.traverseForRecommendations(cartProductIds));
  const pineconePromise = pineconeService
    .queryForCart(cartProductIds)
    .catch(() => []);                          // graceful degradation on Pinecone failure

  const timeoutPromise = new Promise(resolve =>
    setTimeout(() => resolve([]), 1000)        // 1000ms Pinecone timeout
  );

  const [graphCandidates, pineconeCandidates] = await Promise.all([
    graphPromise,
    Promise.race([pineconePromise, timeoutPromise])
  ]);

  // Merge, dedup, rank, exclude cart items, top 5
  const merged = mergeCandidates(graphCandidates, pineconeCandidates, cartProductIds);

  // Ground: discard any productId not in the Product Graph
  const grounded = merged.filter(c => graph.nodes.has(`prod_${c.productId}`));

  // Attach metadata from skus.json
  return grounded.map(c => ({
    ...c,
    ...skusMap.get(c.productId)   // name, price, imagePath, availability
  }));
}
```


---

## 6. Recommendations Merge Algorithm

```
function mergeCandidates(graphCandidates, pineconeCandidates, cartProductIds):
  // graphCandidates: [{ productId, score, source: "graph" }]
  // pineconeCandidates: [{ productId, score, source: "pinecone" }]

  scoreMap = new Map()   // productId → { score, source }

  for each candidate in graphCandidates:
    scoreMap.set(candidate.productId, { score: candidate.score, source: "graph" })

  for each candidate in pineconeCandidates:
    if scoreMap.has(candidate.productId):
      existing = scoreMap.get(candidate.productId)
      // Graph edge weight takes precedence; only upgrade if Pinecone score is higher
      // AND existing source is not "graph"
      if existing.source !== "graph" AND candidate.score > existing.score:
        scoreMap.set(candidate.productId, { score: candidate.score, source: "pinecone" })
      // If existing source IS "graph", keep graph score (graph takes precedence)
    else:
      scoreMap.set(candidate.productId, { score: candidate.score, source: "pinecone" })

  // Exclude products already in cart
  candidates = Array.from(scoreMap.entries())
    .filter(([productId, _]) => NOT cartProductIds.has(productId))
    .map(([productId, { score, source }]) => ({ productId, score, source }))

  // Sort descending by score
  candidates.sort((a, b) => b.score - a.score)

  // Return top 5
  return candidates.slice(0, 5)
```

**Score normalization:** Graph edge weights (1–4) and Pinecone scores (0.0–1.0) are on different scales. To enable meaningful comparison when a product appears in both sources, graph scores are kept as-is (higher is better) and Pinecone scores are multiplied by 4 to normalize to the same 0–4 range before merging. Graph source always wins on tie.


---

## 7. Bundle Detection Algorithm

```
VALID_REGISTRY_CATEGORIES = {
  "cookware": "Cookware",
  "bakeware": "Bakeware",
  "cutlery-knives": "Cutlery & Knives",
  "electrics": "Electrics",
  "tabletop-bar": "Tabletop & Bar",
  "food-entertaining": "Food & Entertaining",
  "storage-organization": "Storage & Organization"
}

// productType → registryCategory mapping (used for category assignment)
PRODUCT_TYPE_TO_REGISTRY_CATEGORY = {
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
}

function detectBundles(cartItems, skusMap):
  bundles = []

  // Step 1: Collection-first clustering
  collectionMap = new Map()   // collectionValue → [cartItem]
  for each item in cartItems:
    sku = skusMap.get(item.productId)
    collections = parseArrayString(sku.properties.collection)
    for each collection in collections:
      if NOT collectionMap.has(collection): collectionMap.set(collection, [])
      collectionMap.get(collection).push(item)

  usedInCollectionBundle = new Set()
  for each [collectionValue, items] in collectionMap:
    if items.length >= 2:
      bundle = buildBundle(items, "collection", collectionValue, skusMap)
      bundles.push(bundle)
      items.forEach(i => usedInCollectionBundle.add(i.productId))

  // Step 2: Brand clustering (only for items NOT already in a collection bundle)
  remainingItems = cartItems.filter(i => NOT usedInCollectionBundle.has(i.productId))
  brandMap = new Map()   // brandValue → [cartItem]
  for each item in remainingItems:
    sku = skusMap.get(item.productId)
    brands = parseArrayString(sku.properties.brand)
    for each brand in brands:
      if NOT brandMap.has(brand): brandMap.set(brand, [])
      brandMap.get(brand).push(item)

  for each [brandValue, items] in brandMap:
    if items.length >= 2:
      bundle = buildBundle(items, "brand", brandValue, skusMap)
      bundles.push(bundle)

  return bundles

function buildBundle(items, sharedPropertyType, sharedPropertyValue, skusMap):
  productIds = items.map(i => i.productId)

  // Assign registryCategory: category of highest-priced item
  highestPricedItem = items.reduce((max, i) =>
    skusMap.get(i.productId).price.sellingPrice > skusMap.get(max.productId).price.sellingPrice ? i : max
  )
  highestSku = skusMap.get(highestPricedItem.productId)
  productType = parseArrayString(highestSku.properties.productType)[0]
  registryCategoryId = PRODUCT_TYPE_TO_REGISTRY_CATEGORY[productType] ?? "cookware"

  discountLabel = sharedPropertyType === "collection"
    ? "Bundle & Save — " + sharedPropertyValue
    : "Brand Bundle — " + sharedPropertyValue

  return {
    productIds,
    sharedPropertyType,
    sharedPropertyValue,
    discountLabel,
    registryCategory: VALID_REGISTRY_CATEGORIES[registryCategoryId]
  }
```


---

## 8. Pinecone Integration

### Embedding Strategy

Each SKU is embedded as a single text string combining its most semantically meaningful fields:

```
"{name} | brand: {brand} | productType: {productType} | material: {material} | collection: {collection}"
```

Example for the Staub Dutch Oven:
```
"Staub Enameled Cast Iron Round Dutch Oven, 7-Qt., Basil | brand: staub | productType: dutch-ovens | material: enameled-cast-iron | collection: staub-cast-iron"
```

Array-valued properties are joined with spaces before embedding (e.g., `"[he-pantry, he-fridge]"` → `"he-pantry he-fridge"`).

### Index Setup

Pinecone's **integrated inference** is used — the index is created with a built-in embedding model so the server never calls an external AI API. No `OPENAI_API_KEY` or any other AI API key is required.

- **Index name:** read from `PINECONE_INDEX_NAME` env var
- **Index type:** Serverless with integrated inference (`llama-text-embed-v2`, dimension 1024)
- **Metric:** cosine
- **Namespace:** `ws-products`
- **Vector ID:** SKU `id` (e.g., `"2505456"`)
- **Metadata stored per vector:** `{ productId, name, productType, brand }`

With integrated inference, Pinecone accepts raw text at upsert and query time — it handles embedding generation internally. The server only sends the text string.

### Seed Script Design

```
scripts/seedPinecone.js:
  1. Load skus.json
  2. For each SKU, build embedding text string
  3. Upsert to Pinecone using the integrated inference upsert API
     (send { id, text, metadata } — Pinecone embeds the text internally)
  4. Upsert in batches of 10
  5. Log success/failure per SKU
```

Run once before demo: `node scripts/seedPinecone.js`

No external embedding API call. No AI API key.

### Query Flow

```js
// services/pineconeService.js
// Uses Pinecone integrated inference — query by text, not by vector
async function queryForCart(cartProductIds) {
  const results = [];
  for (const productId of cartProductIds) {
    const sku = skusMap.get(productId);
    if (!sku) { console.warn(`No SKU for ${productId}`); continue; }

    const queryText = buildEmbeddingText(sku);

    // Pinecone integrated inference: send text directly, no embedding step
    const response = await pineconeIndex.searchRecords({
      query: { inputs: { text: queryText }, topK: 10 },
      namespace: "ws-products"
    });

    response.result.hits.forEach(hit => {
      if (hit._id !== productId) {   // exclude self
        results.push({ productId: hit._id, score: hit._score, source: "pinecone" });
      }
    });
  }
  return results;
}
```

### Environment Variables

| Variable | Purpose |
|---|---|
| `PINECONE_API_KEY` | Pinecone API authentication |
| `PINECONE_INDEX_NAME` | Name of the Pinecone index |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | Firebase service account as JSON string |
| `FIREBASE_SERVICE_ACCOUNT_PATH` | Path to Firebase service account JSON file |
| `FIREBASE_PROJECT_ID` | Firebase project ID (used if SDK needs explicit project) |


---

## 9. Firebase Auth Middleware

```js
// middleware/firebaseAuth.js
const admin = require("../firebase/adminInit");

async function firebaseAuth(req, res, next) {
  const authHeader = req.headers["authorization"] || "";
  if (!authHeader.startsWith("Bearer ")) {
    return res.status(401).json({ error: "Missing or malformed Authorization header" });
  }

  const token = authHeader.slice(7);
  try {
    const decoded = await admin.auth().verifyIdToken(token);
    req.firebaseUid = decoded.uid;   // attached for potential future use
    req.cartUserId = "user_001";     // hardcoded for demo stability (Req 6.3)
    next();
  } catch (err) {
    return res.status(401).json({ error: "Invalid or expired Firebase token" });
  }
}

module.exports = firebaseAuth;
```

**Why `user_001` instead of `uid`:**
Firebase ID tokens expire after 1 hour. During a live hackathon demo, a token expiry mid-demo would cause the cart to appear empty (new token → new uid → empty cart). By keying cart state to the hardcoded `user_001`, the in-memory cart survives token rotation. The `uid` is still extracted and attached to `req.firebaseUid` for registry ownership checks, where Firestore persistence makes it safe to use the real uid.

**Protected endpoints (middleware applied):**
- All `/cart/*` routes
- `POST /registry`
- `POST /registry/:registryId/items`
- `PATCH /registry/:registryId/items/:productId`
- `DELETE /registry/:registryId/items/:productId`
- `DELETE /registry/:registryId`
- `PATCH /registry/:registryId`

**Unprotected endpoints (no middleware):**
- `/login`, `/profile`, `/feed`, `/skus` (existing)
- `GET /registry/search` (public)
- `GET /registry/:registryId/dashboard` (public)
- `GET /registry/:registryId/items` (public read)


---

## 10. Firestore Data Model

### Document Schema: `registries/{registryId}`

```json
{
  "registryId": "auto-generated-firestore-id",
  "ownerUid": "firebase-uid-of-creator",
  "firstName": "Jane",
  "lastName": "Smith",
  "firstNameLower": "jane",
  "lastNameLower": "smith",
  "eventType": "wedding",
  "eventDate": "2025-09-15",
  "coRegistrantFirstName": "John",
  "coRegistrantLastName": "Smith",
  "isPublic": true,
  "createdAt": "2025-06-01T10:00:00Z",
  "items": [
    {
      "productId": "2453926",
      "name": "Staub Enameled Cast Iron Round Dutch Oven, 7-Qt., Basil",
      "price": 299.95,
      "imagePath": "/img83m.jpg",
      "quantity": 1,
      "categoryId": "cookware",
      "purchased": false
    }
  ]
}
```

### Embedded Items Array vs Subcollection

**Decision: embedded `items` array** (not a subcollection).

Rationale:
- The catalog has 10 SKUs; a registry will have at most ~50 items in a hackathon context.
- Embedded array allows atomic reads of the full registry in a single Firestore document fetch.
- Dashboard calculations can be done server-side from a single document read.
- Firestore document size limit (1MB) is not a concern at this scale.
- Subcollections would require additional queries for dashboard aggregation.

### Indexing Strategy for Name Search

Firestore does not support case-insensitive queries natively. The solution is to store lowercase shadow fields alongside the original:

- `firstNameLower` = `firstName.toLowerCase()`
- `lastNameLower` = `lastName.toLowerCase()`

Query: `where("firstNameLower", "==", firstName.toLowerCase()).where("lastNameLower", "==", lastName.toLowerCase()).where("isPublic", "==", true)`

**Composite index required** (create in Firebase Console or `firestore.indexes.json`):
```json
{
  "collectionGroup": "registries",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "firstNameLower", "order": "ASCENDING" },
    { "fieldPath": "lastNameLower", "order": "ASCENDING" },
    { "fieldPath": "isPublic", "order": "ASCENDING" }
  ]
}
```


---

## 11. Registry Search Design

```js
// routes/registry.js — GET /registry/search
app.get("/registry/search", async (req, res) => {
  const { registryId, firstName, lastName } = req.query;

  if (!registryId && !firstName && !lastName) {
    return res.status(400).json({ error: "Provide registryId or firstName/lastName" });
  }

  const db = admin.firestore();

  if (registryId) {
    const doc = await db.collection("registries").doc(registryId).get();
    if (!doc.exists || !doc.data().isPublic) {
      return res.status(404).json({ error: "Registry not found" });
    }
    return res.json({ results: [formatRegistryMetadata(doc)] });
  }

  // Name search — uses lowercase index fields
  let query = db.collection("registries").where("isPublic", "==", true);
  if (firstName) query = query.where("firstNameLower", "==", firstName.toLowerCase());
  if (lastName)  query = query.where("lastNameLower",  "==", lastName.toLowerCase());

  const snapshot = await query.get();
  const results = snapshot.docs.map(formatRegistryMetadata);
  return res.json({ results });
});

function formatRegistryMetadata(doc) {
  const d = doc.data();
  return {
    registryId: doc.id,
    firstName: d.firstName,
    lastName: d.lastName,
    eventType: d.eventType,
    eventDate: d.eventDate,
    ...(d.coRegistrantFirstName && { coRegistrantFirstName: d.coRegistrantFirstName }),
    ...(d.coRegistrantLastName  && { coRegistrantLastName:  d.coRegistrantLastName  })
    // items array intentionally excluded
  };
}
```


---

## 12. API Response Schemas

### `GET /cart`

```json
{
  "userId": "user_001",
  "items": [
    {
      "productId": "2453926",
      "name": "Staub Enameled Cast Iron Round Dutch Oven, 7-Qt., Basil",
      "price": 299.95,
      "imagePath": "/img83m.jpg",
      "quantity": 2,
      "availability": "ON_HAND",
      "backOrdered": false
    }
  ],
  "saveForLater": [
    {
      "productId": "1341411",
      "name": "Apilco Tradition Porcelain Cup & Saucer, Each",
      "price": 34.95,
      "imagePath": "/img95m.jpg",
      "availability": "NLA"
    }
  ],
  "totalPrice": 599.90,
  "totalItems": 2
}
```

### `POST /cart/items`

Request: `{ "productId": "2453926", "quantity": 1 }`

Response (same shape as `GET /cart`):
```json
{
  "userId": "user_001",
  "items": [ ... ],
  "saveForLater": [ ... ],
  "totalPrice": 299.95,
  "totalItems": 1
}
```

### `DELETE /cart/items/:productId`

Response (same shape as `GET /cart`):
```json
{
  "userId": "user_001",
  "items": [],
  "saveForLater": [],
  "totalPrice": 0,
  "totalItems": 0
}
```

### `GET /cart/recommendations`

```json
{
  "recommendations": [
    {
      "productId": "6121370",
      "name": "Williams Sonoma Board Oil",
      "price": 10.95,
      "imagePath": "/img27m.jpg",
      "availability": "ON_HAND",
      "score": 3,
      "source": "graph",
      "context": "Product Care Duo"
    },
    {
      "productId": "181543",
      "name": "Staub Enameled Cast Iron Traditional Deep Skillet, 8 1/2\", Citron",
      "price": 180.00,
      "imagePath": "/img5m.jpg",
      "availability": "ON_HAND",
      "score": 4,
      "source": "graph",
      "context": "staub-cast-iron"
    }
  ]
}
```

### `GET /cart/bundles`

```json
{
  "bundles": [
    {
      "productIds": ["2453926", "181543"],
      "sharedPropertyType": "collection",
      "sharedPropertyValue": "staub-cast-iron",
      "discountLabel": "Bundle & Save — staub-cast-iron",
      "registryCategory": "Cookware"
    }
  ]
}
```

### `POST /registry`

Request:
```json
{
  "firstName": "Jane",
  "lastName": "Smith",
  "eventType": "wedding",
  "eventDate": "2025-09-15",
  "coRegistrantFirstName": "John",
  "coRegistrantLastName": "Smith"
}
```

Response (HTTP 201):
```json
{
  "registryId": "abc123firestore",
  "firstName": "Jane",
  "lastName": "Smith",
  "eventType": "wedding",
  "eventDate": "2025-09-15",
  "coRegistrantFirstName": "John",
  "coRegistrantLastName": "Smith",
  "isPublic": true,
  "createdAt": "2025-06-01T10:00:00Z",
  "items": []
}
```

### `GET /registry/search`

```json
{
  "results": [
    {
      "registryId": "abc123firestore",
      "firstName": "Jane",
      "lastName": "Smith",
      "eventType": "wedding",
      "eventDate": "2025-09-15",
      "coRegistrantFirstName": "John",
      "coRegistrantLastName": "Smith"
    }
  ]
}
```

### `GET /registry/:registryId/items`

```json
{
  "registryId": "abc123firestore",
  "itemsByCategory": {
    "cookware": [
      {
        "productId": "2453926",
        "name": "Staub Enameled Cast Iron Round Dutch Oven, 7-Qt., Basil",
        "price": 299.95,
        "imagePath": "/img83m.jpg",
        "quantity": 1,
        "categoryId": "cookware",
        "purchased": false
      }
    ],
    "electrics": [
      {
        "productId": "8381456",
        "name": "Cuisinart PerfecTemp Programmable Coffee Maker with Glass Carafe, 14-cup",
        "price": 119.95,
        "imagePath": "/img122m.jpg",
        "quantity": 1,
        "categoryId": "electrics",
        "purchased": false
      }
    ]
  }
}
```

### `GET /registry/:registryId/dashboard`

```json
{
  "registryId": "abc123firestore",
  "totalItems": 3,
  "totalValue": 599.85,
  "purchasedCount": 1,
  "remainingCount": 2,
  "purchasedValue": 299.95,
  "remainingValue": 299.90,
  "byCategory": [
    {
      "categoryId": "cookware",
      "categoryLabel": "Cookware",
      "itemCount": 2,
      "totalValue": 479.95,
      "purchasedCount": 1,
      "remainingCount": 1
    },
    {
      "categoryId": "electrics",
      "categoryLabel": "Electrics",
      "itemCount": 1,
      "totalValue": 119.95,
      "purchasedCount": 0,
      "remainingCount": 1
    }
  ]
}
```


---

## 13. Error Handling Strategy

All error responses use a consistent JSON envelope:

```json
{
  "error": "<human-readable message>",
  "code": "<machine-readable code>",
  "details": { }   // optional, for validation errors
}
```

### HTTP Status Code Map

| Scenario | Status | `code` |
|---|---|---|
| Missing/invalid Firebase token | 401 | `UNAUTHORIZED` |
| Valid token but wrong owner (registry) | 403 | `FORBIDDEN` |
| Unknown `productId` in skus.json | 404 | `PRODUCT_NOT_FOUND` |
| Registry not found or `isPublic: false` | 404 | `REGISTRY_NOT_FOUND` |
| Product not in save-for-later (notify) | 404 | `NOT_IN_SAVE_FOR_LATER` |
| Invalid `eventType` | 400 | `INVALID_EVENT_TYPE` |
| Invalid `eventDate` (not ISO 8601) | 400 | `INVALID_EVENT_DATE` |
| Invalid `categoryId` | 400 | `INVALID_CATEGORY_ID` |
| Missing required search params | 400 | `MISSING_SEARCH_PARAMS` |
| Missing required body fields | 400 | `MISSING_REQUIRED_FIELDS` |
| Firestore write failure | 500 | `FIRESTORE_ERROR` |
| Unexpected server error | 500 | `INTERNAL_ERROR` |

### Error Middleware

```js
// Centralized error handler registered last in server.js
app.use((err, req, res, next) => {
  console.error(err);
  res.status(err.status || 500).json({
    error: err.message || "Internal server error",
    code: err.code || "INTERNAL_ERROR"
  });
});
```

All route handlers use `next(err)` to propagate errors to this handler, keeping route code clean.


---

## 14. Environment Variables

Complete list of all required environment variables:

| Variable | Required | Description |
|---|---|---|
| `PINECONE_API_KEY` | Yes | Pinecone API authentication key |
| `PINECONE_INDEX_NAME` | Yes | Name of the Pinecone index (e.g., `ws-products`) |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | One of these two | Firebase Admin SDK service account as a JSON string (useful for env-var-only deployments) |
| `FIREBASE_SERVICE_ACCOUNT_PATH` | One of these two | Path to the Firebase service account JSON file on disk |
| `FIREBASE_PROJECT_ID` | Recommended | Firebase project ID; required if not embedded in service account JSON |
| `OPENAI_API_KEY` | Yes (for embeddings) | OpenAI API key used by `pineconeService.js` to generate product embeddings |
| `PORT` | No (default 3001) | Express server port |

**Initialization logic for Firebase Admin SDK (`firebase/adminInit.js`):**

```js
const admin = require("firebase-admin");

if (!admin.apps.length) {
  let credential;
  if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
    credential = admin.credential.cert(serviceAccount);
  } else if (process.env.FIREBASE_SERVICE_ACCOUNT_PATH) {
    const serviceAccount = require(process.env.FIREBASE_SERVICE_ACCOUNT_PATH);
    credential = admin.credential.cert(serviceAccount);
  } else {
    throw new Error("Firebase credentials not configured");
  }
  admin.initializeApp({
    credential,
    projectId: process.env.FIREBASE_PROJECT_ID
  });
}

module.exports = admin;
```


---

## 15. Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Product Graph Node Construction Invariants

*For any* SKU record in `skus.json`, after `buildGraph([sku])` is called:
- A Product node must exist with `id = "prod_{sku.id}"`, `price = sku.price.sellingPrice`, `availability = sku.availability`, and `name = sku.name`
- If the SKU has a `brand` property, a Brand node must exist with `id = "brand_{brandSlug}"` and a `BRANDED_BY` edge must exist from the Product node to the Brand node
- If the SKU has a `material` property, a Material node must exist with `id = "material_{materialSlug}"` and a `MADE_OF` edge must exist from the Product node to the Material node

**Validates: Requirements 1.2, 1.3, 1.4**

---

### Property 2: Array String Parser Round-Trip

*For any* string of the form `"[a, b, c]"` where elements are non-empty and comma-separated, `parseArrayString(str)` must return an array equivalent to manually splitting on `","` and trimming each element. For any scalar string (no brackets), `parseArrayString(str)` must return a single-element array containing the trimmed string.

**Validates: Requirements 1.8, 3.7**

---

### Property 3: RELATED_CATEGORY Edge Weight Hierarchy

*For any* two SKU records that share at least one `collection` or `productType` value, the `RELATED_CATEGORY` edge between their Product nodes must have `weight = 4` if they share a `collection` value, or `weight = 2` if they share only a `productType` value (collection takes precedence).

**Validates: Requirements 1.5, 1.6**

---

### Property 4: Domain Rules Edge Construction

*For any* rule in `domain-rules.json` with `sourceProductType` S and `targetProductType` T, and *for any* two SKUs where one has `productType` S and the other has `productType` T, the graph must contain a directed edge between their Product nodes with the rule's `relation`, `context`, and `weight`.

**Validates: Requirements 1.7**

---

### Property 5: Recommendations Merge Algorithm Invariants

*For any* two candidate lists (graph candidates and Pinecone candidates):
- The merged result must contain no duplicate `productId` values
- For any `productId` appearing in both lists, the retained score must equal the graph score (graph takes precedence over Pinecone)
- For any `productId` appearing only in one list, the retained score must equal that list's score
- The merged result must be sorted in descending order of score
- The merged result must contain at most 5 items
- No `productId` in the merged result may appear in the active cart's item list

**Validates: Requirements 2.3, 2.4, 2.5, 2.6**

---

### Property 6: Recommendation Grounding and Metadata Completeness

*For any* recommendation returned by `GET /cart/recommendations`:
- The `productId` must exist as a Product node in the Product Graph (i.e., must be present in `skus.json`)
- The recommendation object must include `name`, `price`, `imagePath`, and `availability` fields whose values match the corresponding SKU record in `skus.json`

**Validates: Requirements 5.2, 5.3, 5.5**

---

### Property 7: Bundle Detection Invariants

*For any* cart state:
- If two or more items share a `collection` value (after array parsing), `detectBundles` must return a bundle containing all those `productId`s with `sharedPropertyType = "collection"`
- If two or more items share a `brand` value and are not already grouped by a collection bundle, `detectBundles` must return a bundle with `sharedPropertyType = "brand"`
- *For any* bundle in the response, `registryCategory` must be one of the 7 valid values: `Cookware`, `Bakeware`, `Cutlery & Knives`, `Electrics`, `Tabletop & Bar`, `Food & Entertaining`, `Storage & Organization`
- *For any* bundle spanning items from multiple registry categories, the assigned `registryCategory` must equal the category of the item with the highest `sellingPrice`

**Validates: Requirements 3.1, 3.2, 3.4, 3.5**

---

### Property 8: Availability Routing Invariants

*For any* product added via `POST /cart/items`:
- If the product's `availability` in `skus.json` is `NLA`, the product must appear in `saveForLater` and must NOT appear in `items` in any subsequent cart state response
- If the product's `availability` is `BACK_ORDERED`, the product must appear in `items` with `backOrdered: true`
- *For any* cart state response (`GET /cart`, `POST /cart/items`, `DELETE /cart/items/:productId`), the response must always include a `saveForLater` array field (may be empty)

**Validates: Requirements 4.1, 4.2, 4.4**

---

### Property 9: Cart Total Price Calculation

*For any* cart state with active items, `totalPrice` must equal the sum of `(sku.price.sellingPrice × item.quantity)` for all items in the active cart, and `totalItems` must equal the sum of all item quantities.

**Validates: Requirements 8.9**

---

### Property 10: Firebase Auth Enforcement on Cart Endpoints

*For any* request to a cart or recommendation endpoint (`/cart`, `/cart/items`, `/cart/recommendations`, `/cart/bundles`, `/cart/save-for-later/:productId/notify`) that is missing the `Authorization` header or carries an invalid token, the response must be HTTP 401 with an error body. The existing unprotected endpoints (`/login`, `/profile`, `/feed`, `/skus`) must continue to respond normally without an `Authorization` header.

**Validates: Requirements 6.1, 6.2, 6.5**

---

### Property 11: Registry Item Management Invariants

*For any* registry item write operation (`POST`, `PATCH`, `DELETE` on `/registry/:registryId/items`):
- If `productId` does not exist in `skus.json`, the response must be HTTP 404
- If `categoryId` is not one of the 7 valid category IDs, the response must be HTTP 400
- If the authenticated `uid` does not match the registry's `ownerUid`, the response must be HTTP 403
- If a product is added with the same `productId` and `categoryId` as an existing item, the existing item's quantity must be incremented by the supplied quantity (no duplicate entry created)

**Validates: Requirements 12.2, 12.3, 12.4, 12.9**

---

### Property 12: Registry Dashboard Calculation Correctness

*For any* registry document with a non-empty `items` array:
- `totalItems` must equal the sum of all item `quantity` values
- `totalValue` must equal the sum of `(item.price × item.quantity)` for all items
- `purchasedCount` must equal the sum of `quantity` for items where `purchased = true`
- `remainingCount` must equal `totalItems - purchasedCount`
- `purchasedValue` must equal the sum of `(item.price × item.quantity)` for purchased items
- `remainingValue` must equal `totalValue - purchasedValue`
- The `byCategory` array must contain exactly one entry per `categoryId` that has at least one item

**Validates: Requirements 13.1, 13.2**

---

### Property 13: Registry Name Search Case-Insensitivity

*For any* registry with `firstName` F and `lastName` L, a `GET /registry/search` request with any casing variant of F and L (e.g., `"JANE"`, `"jane"`, `"Jane"`) must return that registry in the results (assuming `isPublic: true`).

**Validates: Requirements 11.3**

