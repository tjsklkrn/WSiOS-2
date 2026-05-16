# Requirements Document

## Introduction

This document covers two features for the Williams Sonoma iOS hackathon app: **Smart Cart** and **Smart Registry**. Both are implemented as backend-only API extensions to the existing Node.js/Express `server.js`. No SwiftUI changes are in scope.

**Smart Cart** introduces a heterogeneous product relationship graph built from `skus.json`, a parallel recommendations engine combining graph traversal and Pinecone vector search, bundle detection with registry-style category grouping, save-for-later surfacing for unavailable products, Firebase Auth token validation, and on-device natural language copy generation via Apple Foundation Models in Swift. The server returns structured recommendation data only.

**Smart Registry** introduces a full registry lifecycle backed by Firebase Firestore for real-time persistence — matching the Williams Sonoma website experience. Users can create a registry for a specific event (Wedding, Housewarming, Birthday, Anniversary), find any registry by name or ID, and manage registry items organized into product categories. All registry state is persisted in Firestore and synced in real time. Only API endpoints are in scope; no SwiftUI changes are required.

---

## Glossary

- **Smart Cart API**: The set of new Express endpoints added to `server.js` that implement cart, recommendation, bundle, and save-for-later functionality.
- **Product Graph**: An in-memory heterogeneous directed graph with three node types (Product, Brand, Material) and five edge types, constructed from `skus.json` at server startup.
- **Product Node**: A graph node representing a single SKU, with `id` = `"prod_{skuId}"`, carrying `price`, `availability`, and `name` attributes.
- **Brand Node**: A graph node representing a unique brand, with `id` = `"brand_{brandSlug}"` and `type` = `"Brand"`.
- **Material Node**: A graph node representing a unique material, with `id` = `"material_{materialSlug}"` and `type` = `"Material"`.
- **BRANDED_BY**: A directed edge from a Product node to a Brand node.
- **MADE_OF**: A directed edge from a Product node to a Material node.
- **RELATED_CATEGORY**: A directed edge between two Product nodes that share the same collection or productType cluster, carrying a `context` label (e.g., "Premium Cookware Set").
- **COMPLEMENTARY_USAGE**: A directed edge between two Product nodes defined by functional domain rules in `domain-rules.json` (e.g., Coffee Maker → Cup & Saucer = "Coffee & Tea Station"), carrying a `context` label.
- **MAINTAINED_BY**: A directed edge between two Product nodes representing a care/maintenance relationship defined in `domain-rules.json` (e.g., Cutting Board → Board Oil = "Product Care Duo"), carrying a `context` label.
- **Edge Weight**: A numeric score (1–4) assigned to product-to-product edges based on the highest-priority shared property: collection = 4, brand = 3, productType = 2, material = 1. Functional domain edges (`COMPLEMENTARY_USAGE`, `MAINTAINED_BY`) use weights defined in `domain-rules.json`.
- **Recommendations Engine**: The subsystem that runs graph traversal and Pinecone vector search in parallel, merges results, de-duplicates, and returns a ranked list of complementary products.
- **Pinecone**: The external vector database used to store and query product embeddings for semantic similarity search.
- **Bundle**: A grouping of two or more cart items that share the same collection or brand, surfaced with a discount label, grouping identifier, and registry category.
- **Registry Category**: One of the Williams Sonoma website registry categories used to classify bundle candidates: `Cookware`, `Bakeware`, `Cutlery & Knives`, `Electrics`, `Tabletop & Bar`, `Food & Entertaining`, `Storage & Organization`.
- **Save-for-Later**: A list of cart-eligible products whose availability status is `NLA`, surfaced with a re-engagement trigger endpoint. Products with `BACK_ORDERED` status remain in the active cart with a warning flag.
- **MCP Orchestrator**: The request-routing layer embedded in `server.js` that coordinates calls to the Product Graph service, Pinecone, and the product database, grounding all responses in the Product Graph to prevent hallucinated product references.
- **Firebase Auth**: Firebase Authentication used exclusively for JWT token validation on protected endpoints. No Firestore persistence is used.
- **Cart State**: In-memory server-side representation of a user's active cart, keyed by the hardcoded demo identifier `user_001`. Not persisted to any database.
- **CartViewModel**: The iOS `@MainActor ObservableObject` that binds to `CartRepository` and exposes cart state to the SwiftUI view layer.
- **CartRepository**: The iOS `@MainActor ObservableObject` that holds in-memory `[CartItem]` and exposes add/remove/quantity operations.
- **NLA**: "No Longer Available" — a product availability status indicating the product cannot be purchased. NLA products are automatically moved to save-for-later.
- **BACK_ORDERED**: A product availability status indicating the product is temporarily out of stock but expected to return. BACK_ORDERED products remain in the active cart with a `backOrdered: true` flag.
- **SKU**: A single product record in `skus.json`, identified by a unique string `id`.
- **domain-rules.json**: A configuration file defining explicit functional domain relationships between product types, used to construct `COMPLEMENTARY_USAGE` and `MAINTAINED_BY` edges in the Product Graph.

### Registry Glossary

- **Registry**: A named wishlist tied to a specific event (Wedding, Housewarming, Birthday, Anniversary), owned by a Firebase-authenticated user, persisted in Firestore.
- **Registry ID**: A unique string identifier auto-generated by Firestore when a registry is created.
- **Registry Event**: The occasion type for a registry — one of: `wedding`, `housewarming`, `birthday`, `anniversary`.
- **Registry Category**: A product grouping within a registry matching Williams Sonoma's website structure: `Cookware`, `Bakeware`, `Cutlery & Knives`, `Electrics`, `Tabletop & Bar`, `Food & Entertaining`, `Storage & Organization`.
- **Registry Item**: A product added to a registry, carrying `productId`, `name`, `price`, `imagePath`, `quantity`, `categoryId`, and `purchased` flag.
- **Firestore**: Firebase's real-time NoSQL document database used to persist all registry state. Registry documents are stored under the collection path `registries/{registryId}`.
- **Registry Owner**: The Firebase-authenticated user (`uid`) who created the registry. Only the owner can modify or delete the registry.
- **Find Registry**: A public search operation that returns registry metadata by registrant name or registry ID, without requiring authentication.
- **Registry Dashboard**: A summary response for a registry showing total items, total value, purchased count, remaining count, and per-category breakdowns.

---

## Requirements

### Requirement 1: Product Graph Construction

**User Story:** As a backend developer, I want the server to build a heterogeneous weighted product relationship graph from `skus.json` at startup, so that recommendation and bundle queries can be served without re-reading or re-parsing the catalog on every request.

#### Acceptance Criteria

1. WHEN the Smart Cart API starts, THE Product Graph SHALL be constructed in memory from all SKU records present in `skus.json` before any cart or recommendation endpoint accepts requests.
2. THE Product Graph SHALL represent each SKU as a Product node with `id` = `"prod_{skuId}"`, carrying the SKU's `price`, `availability`, and `name` attributes.
3. THE Product Graph SHALL represent each unique brand value as a Brand node with `id` = `"brand_{brandSlug}"` and `type` = `"Brand"`, and SHALL create a `BRANDED_BY` directed edge from each Product node to its corresponding Brand node.
4. THE Product Graph SHALL represent each unique material value as a Material node with `id` = `"material_{materialSlug}"` and `type` = `"Material"`, and SHALL create a `MADE_OF` directed edge from each Product node to its corresponding Material node.
5. WHEN two Product nodes share the same `collection` or `productType` property value, THE Product Graph SHALL create a `RELATED_CATEGORY` directed edge between those nodes, carrying a `context` label derived from the shared collection or productType cluster name.
6. THE Product Graph SHALL assign edge weights to `RELATED_CATEGORY` edges using the hierarchy: collection = 4, brand = 3, productType = 2, material = 1, based on the highest-priority shared property between the two Product nodes.
7. THE Product Graph SHALL construct `COMPLEMENTARY_USAGE` and `MAINTAINED_BY` edges between Product nodes according to the explicit functional domain rules defined in `domain-rules.json`, independent of shared SKU property values.
8. WHEN a SKU property value is an array encoded as a string (e.g., `"collection": "[he-pantry, he-fridge]"`), THE Product Graph SHALL parse that string using a custom string parser — not `JSON.parse` — treating each unquoted element as an individual property value when computing edges.
9. THE Product Graph SHALL remain immutable after initial construction; catalog changes require a server restart to take effect.

---

### Requirement 2: Recommendations Engine

**User Story:** As an iOS client, I want the server to return ranked complementary product suggestions for the active cart, so that the app can surface relevant upsell items to the user.

#### Acceptance Criteria

1. WHEN `GET /cart/recommendations` is called, THE Recommendations Engine SHALL initiate graph traversal and Pinecone vector search concurrently for the products in the active cart.
2. THE Recommendations Engine SHALL wait no longer than 1000ms for Pinecone before returning graph-traversal-only results as partial results.
3. THE Recommendations Engine SHALL merge graph traversal results and Pinecone results into a single candidate list, removing any duplicate product IDs and retaining the higher score for duplicates.
4. THE Recommendations Engine SHALL rank the merged candidate list in descending order of score, with graph edge weight taking precedence over Pinecone similarity score when both are present for the same candidate.
5. THE Recommendations Engine SHALL exclude from results any product already present in the active cart.
6. THE Recommendations Engine SHALL return the top 5 ranked candidates in the recommendations response payload.
7. IF Pinecone is unavailable, THEN THE Recommendations Engine SHALL return graph-traversal-only results without surfacing an error to the iOS client.
8. IF graph traversal yields no results, THEN THE Recommendations Engine SHALL return Pinecone-only results without surfacing an error to the iOS client.

---

### Requirement 3: Bundle Detection

**User Story:** As an iOS client, I want the server to detect when cart items belong to the same collection or brand cluster, so that the app can display a bundle offer with a discount or grouping label and a registry category.

#### Acceptance Criteria

1. WHEN the cart contains two or more items that share the same `collection` property value, THE Smart Cart API SHALL identify those items as a bundle candidate.
2. WHEN the cart contains two or more items that share the same `brand` property value and no `collection` match exists among them, THE Smart Cart API SHALL identify those items as a bundle candidate.
3. THE Smart Cart API SHALL include all detected bundle candidates in the `GET /cart/bundles` response, each bundle containing the list of matching product IDs, the shared property type (`collection` or `brand`), the shared property value, a discount label string, and a `registryCategory` field.
4. THE Smart Cart API SHALL assign each bundle a `registryCategory` value from the following set: `Cookware`, `Bakeware`, `Cutlery & Knives`, `Electrics`, `Tabletop & Bar`, `Food & Entertaining`, `Storage & Organization`.
5. WHEN a bundle spans multiple registry categories, THE Smart Cart API SHALL assign the `registryCategory` of the highest-priced item in the bundle.
6. WHEN no bundle candidates are detected, THE Smart Cart API SHALL return an empty `bundles` array in the `GET /cart/bundles` response.
7. THE Smart Cart API SHALL evaluate bundle detection using the same property-array parsing rules as the Product Graph (each array element treated as an individual value).

---

### Requirement 4: Save-for-Later

**User Story:** As an iOS client, I want the server to automatically move NLA products to save-for-later and flag back-ordered products in the active cart, so that the user can be re-engaged when those products become available.

#### Acceptance Criteria

1. WHEN a product with availability `NLA` is added to the cart, THE Smart Cart API SHALL automatically place it in the save-for-later list and NOT add it to active cart items.
2. WHEN a product with availability `BACK_ORDERED` is added to the cart, THE Smart Cart API SHALL add it to the active cart items AND include a `backOrdered: true` flag on that item in the response.
3. THE Smart Cart API SHALL determine save-for-later eligibility by reading the `availability` field from `skus.json` at runtime; no hardcoded product ID list SHALL be used.
4. THE Smart Cart API SHALL include the save-for-later list in the `GET /cart` response under a dedicated `saveForLater` array field.
5. THE Smart Cart API SHALL expose a `POST /cart/save-for-later/:productId/notify` endpoint that records a re-engagement notification request for the specified product ID.
6. WHEN `POST /cart/save-for-later/:productId/notify` is called for a product not present in the save-for-later list, THEN THE Smart Cart API SHALL return HTTP 404 with an error message identifying the product ID.

---

### Requirement 5: MCP Orchestrator

**User Story:** As a backend developer, I want a request-routing orchestrator embedded in `server.js` that coordinates calls to the Product Graph, Pinecone, and the product database, so that all recommendation responses are grounded in verified product data and cannot reference products not present in the catalog.

#### Acceptance Criteria

1. THE MCP Orchestrator SHALL route all recommendation requests through the Product Graph before returning a response to the caller.
2. WHEN the Recommendations Engine produces a candidate product ID, THE MCP Orchestrator SHALL verify that the product ID exists as a Product node in the Product Graph before including it in the response.
3. IF a candidate product ID does not exist in the Product Graph, THEN THE MCP Orchestrator SHALL discard that candidate and SHALL NOT include it in the response payload.
4. THE MCP Orchestrator SHALL coordinate concurrent calls to the Product Graph service and Pinecone, collecting both results before invoking the merge step.
5. THE MCP Orchestrator SHALL attach the resolved product metadata (name, price, image path, availability) from `skus.json` to each recommendation in the response payload.

---

### Requirement 6: Firebase Authentication

**User Story:** As a security-conscious developer, I want all cart and recommendation endpoints to require a valid Firebase Auth token, so that unauthenticated requests cannot read or modify cart state.

#### Acceptance Criteria

1. THE Smart Cart API SHALL validate the Firebase Auth JWT token present in the `Authorization: Bearer <token>` header on every request to cart and recommendation endpoints.
2. IF the `Authorization` header is absent or the token is invalid, THEN THE Smart Cart API SHALL return HTTP 401 with an error body before processing the request.
3. WHEN the Firebase Auth token is valid, THE Smart Cart API SHALL use the hardcoded identifier `user_001` as the cart state key, regardless of the `uid` extracted from the token, to prevent cart loss on token expiry during the hackathon demo.
4. THE Smart Cart API SHALL NOT use Firestore or any external database for cart persistence; cart state SHALL be stored in server memory keyed by `user_001`.
5. THE Smart Cart API SHALL NOT apply Firebase Auth validation to the existing `/login`, `/profile`, `/feed`, and `/skus` endpoints.

---

### Requirement 7: Pinecone Vector Search Integration

**User Story:** As a backend developer, I want product embeddings stored in Pinecone so that the Recommendations Engine can perform semantic similarity queries in parallel with graph traversal.

#### Acceptance Criteria

1. THE Smart Cart API SHALL maintain a Pinecone index containing one vector per SKU, where each vector represents the semantic embedding of the product's name and key properties.
2. WHEN the Recommendations Engine initiates a Pinecone query, THE Smart Cart API SHALL query the Pinecone index using the embedding of the triggering product and retrieve the top 10 nearest neighbors.
3. THE Smart Cart API SHALL use the Pinecone similarity score (0.0–1.0) as the initial ranking score for Pinecone-sourced candidates before merging with graph results.
4. IF the Pinecone index does not contain an embedding for a queried product ID, THEN THE Smart Cart API SHALL log a warning and proceed with graph-traversal-only results for that query.
5. THE Smart Cart API SHALL read the Pinecone API key and index name from environment variables `PINECONE_API_KEY` and `PINECONE_INDEX_NAME`.

---

### Requirement 8: Recommendation Copy — Structured Data Contract

**User Story:** As an iOS client, I want the server to return structured recommendation data at checkout so that the iOS app can generate natural language copy on-device using Apple Foundation Models, without any server-side LLM dependency.

#### Acceptance Criteria

1. THE Smart Cart API SHALL expose a `POST /cart/checkout/recommendations` endpoint that accepts the current cart item IDs and returns structured recommendation data for each suggested product.
2. THE Smart Cart API SHALL NOT call any external LLM API for copy generation; all natural language copy generation SHALL be performed on-device by the iOS app using Apple Foundation Models in Swift.
3. WHEN `POST /cart/checkout/recommendations` is called, THE Smart Cart API SHALL return a JSON response conforming to the following structure for each recommendation candidate:
   ```json
   {
     "recommendations": [
       {
         "productId": "<id>",
         "name": "<product name>",
         "price": <number>,
         "imagePath": "<path>",
         "availability": "<status>",
         "graphScore": <integer>,
         "pineconeScore": <number>,
         "relationContext": "<context label>",
         "relationType": "<edge type>"
       }
     ]
   }
   ```
4. THE Smart Cart API SHALL populate `relationContext` with the `context` label from the Product Graph edge connecting the cart item to the recommendation candidate, and `relationType` with the edge type (e.g., `RELATED_CATEGORY`, `COMPLEMENTARY_USAGE`, `MAINTAINED_BY`).
5. THE Smart Cart API SHALL NOT read or use environment variables `FM_API_KEY` or `FM_API_ENDPOINT`; those variables are not required by this system.

---

### Requirement 9: Cart API Endpoints

**User Story:** As an iOS client developer, I want a well-defined set of cart endpoints that the `CartRepository` and `CartViewModel` can consume, so that the iOS app can manage cart state, retrieve recommendations, and surface bundles without UI changes.

#### Acceptance Criteria

1. THE Smart Cart API SHALL expose `POST /cart/items` accepting a JSON body `{ "productId": "<id>", "quantity": <int> }` and returning ONLY the updated cart state including active items, save-for-later items, total price, and total item count; `POST /cart/items` SHALL NOT trigger or return recommendations.
2. THE Smart Cart API SHALL expose `GET /cart/recommendations` to return the current ranked recommendation list for the active cart contents; the iOS app SHALL call this endpoint separately after a debounce period following a cart update.
3. THE Smart Cart API SHALL expose `DELETE /cart/items/:productId` to remove a product from the active cart and return the updated cart state.
4. THE Smart Cart API SHALL expose `GET /cart` to return the full cart state for the authenticated user, including active items, save-for-later items, total price, and total item count.
5. THE Smart Cart API SHALL expose `GET /cart/bundles` to return detected bundle candidates for the active cart.
6. THE Smart Cart API SHALL expose `POST /cart/save-for-later/:productId/notify` as specified in Requirement 4.
7. THE Smart Cart API SHALL expose `POST /cart/checkout/recommendations` as specified in Requirement 8.
8. WHEN a `productId` supplied to any cart endpoint does not exist in `skus.json`, THEN THE Smart Cart API SHALL return HTTP 404 with an error body identifying the unknown product ID.
9. THE Smart Cart API SHALL return all responses as JSON with `Content-Type: application/json`.
10. THE Smart Cart API SHALL include a `totalPrice` field (sum of `sellingPrice × quantity` for all active cart items) and a `totalItems` field (sum of all active item quantities) in every cart state response.

---

## Registry Requirements

### Requirement 10: Create Registry

**User Story:** As a Firebase-authenticated user, I want to create a registry for my event so that I can start adding products and share it with guests.

#### Acceptance Criteria

1. THE Registry API SHALL expose `POST /registry` accepting a JSON body `{ "firstName": "<string>", "lastName": "<string>", "eventType": "<wedding|housewarming|birthday|anniversary>", "eventDate": "<ISO8601 date string>", "coRegistrantFirstName": "<string|optional>", "coRegistrantLastName": "<string|optional>" }`.
2. WHEN `POST /registry` is called with a valid Firebase Auth token, THE Registry API SHALL create a new Firestore document under `registries/{registryId}` containing the submitted fields plus `ownerUid`, `createdAt` timestamp, `items: []`, and `isPublic: true`.
3. THE Registry API SHALL auto-generate the `registryId` using Firestore's document ID generation and return it in the response.
4. IF `eventType` is not one of `wedding`, `housewarming`, `birthday`, or `anniversary`, THEN THE Registry API SHALL return HTTP 400 with a descriptive error message.
5. IF `eventDate` is not a valid ISO 8601 date string, THEN THE Registry API SHALL return HTTP 400 with a descriptive error message.
6. A single Firebase `uid` MAY own multiple registries for different events; THE Registry API SHALL NOT enforce a one-registry-per-user limit.
7. THE Registry API SHALL return HTTP 201 with the created registry document (excluding `ownerUid`) on success.
8. THE Registry API SHALL require a valid Firebase Auth token on `POST /registry`; unauthenticated requests SHALL receive HTTP 401.

---

### Requirement 11: Find Registry

**User Story:** As a guest, I want to search for a registry by the registrant's name or registry ID so that I can view items and purchase gifts.

#### Acceptance Criteria

1. THE Registry API SHALL expose `GET /registry/search` accepting query parameters `firstName`, `lastName`, and/or `registryId`.
2. WHEN `GET /registry/search` is called with `registryId`, THE Registry API SHALL return the matching registry document if it exists and `isPublic: true`, or HTTP 404 if not found.
3. WHEN `GET /registry/search` is called with `firstName` and `lastName`, THE Registry API SHALL return all registries where the `firstName` and `lastName` fields match (case-insensitive) and `isPublic: true`.
4. WHEN `GET /registry/search` returns multiple results, THE Registry API SHALL include `registryId`, `firstName`, `lastName`, `eventType`, `eventDate`, and `coRegistrantFirstName`/`coRegistrantLastName` (if present) for each result, but SHALL NOT include the full items list.
5. IF no matching registries are found, THE Registry API SHALL return HTTP 200 with an empty `results` array.
6. THE Registry API SHALL NOT require Firebase Auth on `GET /registry/search`; it is a public endpoint.
7. IF neither `registryId` nor at least one of `firstName`/`lastName` is provided, THE Registry API SHALL return HTTP 400.

---

### Requirement 12: Manage Registry Items and Categories

**User Story:** As a registry owner, I want to add products to my registry under specific categories, update quantities, and remove items, so that my registry stays organized and accurate.

#### Acceptance Criteria

1. THE Registry API SHALL expose `POST /registry/:registryId/items` accepting `{ "productId": "<string>", "quantity": <int>, "categoryId": "<string>" }` to add a product to the registry under the specified category.
2. WHEN `POST /registry/:registryId/items` is called, THE Registry API SHALL validate that `productId` exists in `skus.json`; if not, return HTTP 404 with an error identifying the unknown product.
3. WHEN `POST /registry/:registryId/items` is called, THE Registry API SHALL validate that `categoryId` is one of: `cookware`, `bakeware`, `cutlery-knives`, `electrics`, `tabletop-bar`, `food-entertaining`, `storage-organization`; if not, return HTTP 400.
4. IF the product already exists in the registry under the same `categoryId`, THE Registry API SHALL increment the quantity by the supplied `quantity` value rather than creating a duplicate entry.
5. IF the product already exists in the registry under a different `categoryId`, THE Registry API SHALL create a separate entry under the new category.
6. THE Registry API SHALL expose `PATCH /registry/:registryId/items/:productId` accepting `{ "quantity": <int>, "categoryId": "<string|optional>" }` to update quantity or move an item to a different category.
7. THE Registry API SHALL expose `DELETE /registry/:registryId/items/:productId` to remove a product from the registry entirely (all category entries for that product).
8. THE Registry API SHALL expose `GET /registry/:registryId/items` to return all items in the registry, grouped by `categoryId`, each item carrying `productId`, `name`, `price`, `imagePath`, `quantity`, `categoryId`, and `purchased` flag.
9. ALL item management endpoints (`POST`, `PATCH`, `DELETE` on `/registry/:registryId/items`) SHALL require a valid Firebase Auth token and SHALL verify that the authenticated `uid` matches the registry's `ownerUid`; mismatched requests SHALL receive HTTP 403.
10. THE Registry API SHALL write all item changes to Firestore in real time so that concurrent reads reflect the latest state without requiring a server restart.

---

### Requirement 13: Registry Dashboard

**User Story:** As a registry owner or guest, I want to see a summary of the registry's progress so that I can track what has been purchased and what remains.

#### Acceptance Criteria

1. THE Registry API SHALL expose `GET /registry/:registryId/dashboard` returning a summary object with: `totalItems` (sum of all item quantities), `totalValue` (sum of `price × quantity` for all items), `purchasedCount` (sum of quantities where `purchased: true`), `remainingCount` (`totalItems - purchasedCount`), `purchasedValue`, `remainingValue`, and a `byCategory` array.
2. THE `byCategory` array SHALL contain one entry per category that has at least one item, each entry carrying `categoryId`, `categoryLabel`, `itemCount`, `totalValue`, `purchasedCount`, and `remainingCount`.
3. THE Registry API SHALL NOT require Firebase Auth on `GET /registry/:registryId/dashboard`; it is a public endpoint.
4. IF the registry does not exist or `isPublic: false`, THE Registry API SHALL return HTTP 404.

---

### Requirement 14: Registry API — Firestore Persistence and Real-Time Updates

**User Story:** As a backend developer, I want all registry state persisted in Firestore so that data survives server restarts and multiple clients see consistent state in real time.

#### Acceptance Criteria

1. THE Registry API SHALL use the Firebase Admin SDK to read and write all registry data to Firestore; no in-memory registry state SHALL be maintained on the server.
2. ALL registry Firestore documents SHALL be stored under the top-level collection `registries` with the document ID equal to the `registryId`.
3. THE Registry API SHALL initialize the Firebase Admin SDK using the service account credentials read from the environment variable `FIREBASE_SERVICE_ACCOUNT_JSON` (a JSON string) or `FIREBASE_SERVICE_ACCOUNT_PATH` (a file path).
4. WHEN a registry item is added, updated, or removed, THE Registry API SHALL perform the Firestore write atomically using Firestore transactions or batch writes to prevent partial updates.
5. THE Registry API SHALL expose `DELETE /registry/:registryId` to permanently delete a registry and all its items from Firestore; this endpoint SHALL require Firebase Auth and SHALL verify `ownerUid` matches the authenticated `uid`, returning HTTP 403 on mismatch.
6. THE Registry API SHALL expose `PATCH /registry/:registryId` accepting `{ "isPublic": <boolean>, "eventDate": "<ISO8601>", "coRegistrantFirstName": "<string>", "coRegistrantLastName": "<string>" }` to update registry metadata; this endpoint SHALL require Firebase Auth and `ownerUid` verification.
7. THE Registry API SHALL NOT apply Firebase Auth to `GET /registry/search` or `GET /registry/:registryId/dashboard` (public read endpoints).
8. THE Registry API SHALL return all responses as JSON with `Content-Type: application/json`.