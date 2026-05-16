//
//  WishlistRepository.swift
//  WSHackathonApp
//

import Foundation
import Combine

@MainActor
final class WishlistRepository: ObservableObject {

    @Published private(set) var items: [WishlistItem] = []

    // MARK: - Toggle

    func toggle(product: ProductItem) {
        if isWishlisted(product) {
            remove(productId: product.id)
        } else {
            add(product: product)
        }
    }

    // MARK: - Add

    func add(product: ProductItem) {
        guard !isWishlisted(product) else { return }
        let item = WishlistItem(
            id: product.id,
            title: product.title,
            price: product.price ?? 0.0,
            path: product.path
        )
        items.append(item)
    }

    // MARK: - Remove

    func remove(productId: String) {
        items.removeAll { $0.id == productId }
    }

    // MARK: - Query

    func isWishlisted(_ product: ProductItem) -> Bool {
        items.contains { $0.id == product.id }
    }
}
