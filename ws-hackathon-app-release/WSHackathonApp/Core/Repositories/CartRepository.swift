//
//  CartRepository.swift
//  WSHackathonApp
//

import Foundation
import Combine

/// Manages cart state by syncing with the backend API.
/// All mutations go through the server; local state is derived from server responses.
@MainActor
final class CartRepository: ObservableObject {

    // MARK: - Published State

    @Published private(set) var items: [CartItem] = []
    @Published private(set) var saveForLater: [SaveForLaterItemResponse] = []
    @Published private(set) var totalPrice: Double = 0
    @Published private(set) var totalItems: Int = 0
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?

    // MARK: - Load Cart

    func loadCart() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response: CartStateResponse = try await APIClient.shared.request(Endpoint.getCart())
            apply(response)
        } catch {
            errorMessage = "Failed to load cart"
            print("[CartRepository] loadCart error:", error)
        }
    }

    // MARK: - Add Item

    func add(product: ProductItem, quantity: Int = 1) {
        Task {
            do {
                let body = AddCartItemRequest(productId: product.id, quantity: quantity)
                let response: CartStateResponse = try await APIClient.shared.request(
                    Endpoint.addCartItem(), body: body
                )
                apply(response)
            } catch {
                // Optimistic fallback: add locally so UI doesn't freeze
                addLocally(product: product, quantity: quantity)
                print("[CartRepository] add error:", error)
            }
        }
    }

    // MARK: - Remove Item (decrement)

    func remove(productId: String) {
        guard let index = items.firstIndex(where: { $0.id == productId }) else { return }
        if items[index].quantity > 1 {
            // Decrement locally first for instant feedback, then sync
            items[index].quantity -= 1
            recalculateTotals()
        } else {
            delete(productId: productId)
        }
    }

    // MARK: - Delete Item Completely

    func delete(productId: String) {
        Task {
            // Optimistic remove
            items.removeAll { $0.id == productId }
            recalculateTotals()
            do {
                let response: CartStateResponse = try await APIClient.shared.request(
                    Endpoint.deleteCartItem(productId: productId)
                )
                apply(response)
            } catch {
                print("[CartRepository] delete error:", error)
            }
        }
    }

    // MARK: - Increase Quantity

    func increaseQuantity(productId: String) {
        guard let product = items.first(where: { $0.id == productId }) else { return }
        Task {
            do {
                let body = AddCartItemRequest(productId: productId, quantity: 1)
                let response: CartStateResponse = try await APIClient.shared.request(
                    Endpoint.addCartItem(), body: body
                )
                apply(response)
            } catch {
                // Optimistic increment
                if let index = items.firstIndex(where: { $0.id == productId }) {
                    items[index].quantity += 1
                    recalculateTotals()
                }
                print("[CartRepository] increaseQuantity error:", error)
            }
        }
    }

    // MARK: - Notify Save For Later

    func notifySaveForLater(productId: String) async {
        do {
            let _: NotifyResponse = try await APIClient.shared.request(
                Endpoint.notifySaveForLater(productId: productId)
            )
        } catch {
            print("[CartRepository] notifySaveForLater error:", error)
        }
    }

    // MARK: - Checkout

    func checkout() async {
        isLoading = true
        defer { isLoading = false }
        do {
            struct CheckoutResponse: Decodable {
                let success: Bool
                let itemsCheckedOut: Int
                let message: String
            }
            let _: CheckoutResponse = try await APIClient.shared.request(Endpoint.checkout())
            items = []
            recalculateTotals()
        } catch {
            errorMessage = "Failed to complete checkout"
            print("[CartRepository] checkout error:", error)
        }
    }

    // MARK: - Private Helpers

    private func apply(_ response: CartStateResponse) {
        items = response.items.map { $0.toCartItem() }
        saveForLater = response.saveForLater
        totalPrice = response.totalPrice
        totalItems = response.totalItems
    }

    private func recalculateTotals() {
        totalPrice = items.reduce(0) { $0 + $1.price * Double($1.quantity) }
        totalItems = items.reduce(0) { $0 + $1.quantity }
    }

    private func addLocally(product: ProductItem, quantity: Int) {
        guard let price = product.price else { return }
        if let index = items.firstIndex(where: { $0.id == product.id }) {
            items[index].quantity += quantity
        } else {
            items.append(CartItem(
                id: product.id,
                title: product.title,
                price: price,
                path: product.path,
                quantity: quantity
            ))
        }
        recalculateTotals()
    }
}
