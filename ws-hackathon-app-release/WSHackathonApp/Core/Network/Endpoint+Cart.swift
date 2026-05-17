//
//  Endpoint+Cart.swift
//  WSHackathonApp
//

import Foundation

extension Endpoint {

    // MARK: - Cart State

    /// GET /cart
    static func getCart() -> Endpoint {
        Endpoint(path: "/cart", method: .get)
    }

    /// POST /cart/items  body: { productId, quantity }
    static func addCartItem() -> Endpoint {
        Endpoint(path: "/cart/items", method: .post)
    }

    /// DELETE /cart/items/:productId
    static func deleteCartItem(productId: String) -> Endpoint {
        Endpoint(path: "/cart/items/\(productId)", method: .delete)
    }

    // MARK: - Recommendations

    /// GET /cart/recommendations
    static func cartRecommendations() -> Endpoint {
        Endpoint(path: "/cart/recommendations", method: .get)
    }

    // MARK: - Bundles

    /// GET /cart/bundles
    static func cartBundles() -> Endpoint {
        Endpoint(path: "/cart/bundles", method: .get)
    }

    // MARK: - Save For Later

    /// POST /cart/save-for-later/:productId/notify
    static func notifySaveForLater(productId: String) -> Endpoint {
        Endpoint(path: "/cart/save-for-later/\(productId)/notify", method: .post)
    }

    // MARK: - Checkout

    /// POST /cart/checkout
    static func checkout() -> Endpoint {
        Endpoint(path: "/cart/checkout", method: .post)
    }
}
