//
//  CartResponse.swift
//  WSHackathonApp
//
//  Decodable models for all /cart/* API responses.
//

import Foundation

// MARK: - Cart State

struct CartStateResponse: Decodable {
    let userId: String
    let items: [CartItemResponse]
    let saveForLater: [SaveForLaterItemResponse]
    let totalPrice: Double
    let totalItems: Int
}

struct CartItemResponse: Decodable, Identifiable {
    let productId: String
    let name: String
    let price: Double
    let imagePath: String
    let quantity: Int
    let availability: String
    let backOrdered: Bool

    var id: String { productId }

    /// Convert to the local CartItem used by the UI
    func toCartItem() -> CartItem {
        CartItem(
            id: productId,
            title: name,
            price: price,
            path: imagePath,
            quantity: quantity,
            backOrdered: backOrdered
        )
    }
}

struct SaveForLaterItemResponse: Decodable, Identifiable {
    let productId: String
    let name: String
    let price: Double
    let imagePath: String
    let availability: String

    var id: String { productId }
}

// MARK: - Add Item Request

struct AddCartItemRequest: Encodable {
    let productId: String
    let quantity: Int
}

// MARK: - Recommendations

struct RecommendationsResponse: Decodable {
    let recommendations: [RecommendationItem]
}

struct RecommendationItem: Decodable, Identifiable {
    let productId: String
    let name: String
    let price: Double
    let imagePath: String
    let availability: String
    let score: Double
    let source: String
    let context: String?

    var id: String { productId }

    var imageURL: URL? {
        let cleanPath = imagePath.hasPrefix("/") ? String(imagePath.dropFirst()) : imagePath
        return URL(string: AppConstants.API.imageBasePath + cleanPath)
    }
}

// MARK: - Bundles

struct BundlesResponse: Decodable {
    let bundles: [BundleItem]
}

struct BundleItem: Decodable, Identifiable {
    let productIds: [String]
    let sharedPropertyType: String
    let sharedPropertyValue: String
    let discountLabel: String
    let registryCategory: String

    var id: String { sharedPropertyValue + sharedPropertyType }
}

// MARK: - Notify Response

struct NotifyResponse: Decodable {
    let success: Bool
    let productId: String
}
