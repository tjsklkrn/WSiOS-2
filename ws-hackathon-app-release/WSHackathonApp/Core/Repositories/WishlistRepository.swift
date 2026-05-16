//
//  WishlistRepository.swift
//  WSHackathonApp
//

import Foundation
import Combine

@MainActor
final class WishlistRepository: ObservableObject {

    @Published private(set) var items: [ProductItem] = []

    // MARK: - Toggle
    func toggle(_ product: ProductItem) {
        if isWishlisted(product) {
            items.removeAll { $0.id == product.id }
        } else {
            items.append(product)
        }
    }

    // MARK: - Query
    func isWishlisted(_ product: ProductItem) -> Bool {
        items.contains { $0.id == product.id }
    }

    // MARK: - Remove
    func remove(_ productId: String) {
        items.removeAll { $0.id == productId }
    }

    // MARK: - Count
    var count: Int { items.count }
}
