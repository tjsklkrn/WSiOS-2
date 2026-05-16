//
//  CartRepository.swift
//  WSHackathonApp
//
//  Created by Nilesh Mahajan on 06/04/26.
//

import Foundation
import Combine
import FirebaseAuth

@MainActor
final class CartRepository: ObservableObject {
    
    @Published private(set) var items: [CartItem] = [] {
        didSet {
            saveCart()
        }
    }
    
    private var authStateDidChangeListenerHandle: AuthStateDidChangeListenerHandle?
    
    init() {
        authStateDidChangeListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.loadCart()
            }
        }
    }
    
    deinit {
        if let handle = authStateDidChangeListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    // MARK: - Persistence
    private var cartKey: String {
        let uid = Auth.auth().currentUser?.uid ?? "anonymous"
        return "cart_items_\(uid)"
    }
    
    private func saveCart() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: cartKey)
        }
    }
    
    private func loadCart() {
        if let data = UserDefaults.standard.data(forKey: cartKey),
           let decoded = try? JSONDecoder().decode([CartItem].self, from: data) {
            items = decoded
        } else {
            items = []
        }
    }
    
    // MARK: - Add Item
    func add(product: ProductItem, quantity: Int = 1) {
        guard let priceValue = product.price else { return }
        
        if let index = items.firstIndex(where: { $0.id == product.id }) {
            items[index].quantity += 1
        } else {
            let newItem = CartItem(
                id: product.id,
                title: product.title,
                price: priceValue,
                path: product.path,
                quantity: quantity
            )
            items.append(newItem)
        }
    }
    
    // MARK: - Decrease Quantity
    func decreaseQuantity(productId: String) {
        guard let index = items.firstIndex(where: { $0.id == productId }) else { return }
        if items[index].quantity > 1 {
            items[index].quantity -= 1
        }
    }
    
    // MARK: - Remove/Delete Item Entirely
    func remove(productId: String) {
        items.removeAll(where: { $0.id == productId })
    }
    
    // MARK: - Total Price
    var totalPrice: Double {
        items.reduce(0) { $0 + ($1.price * Double($1.quantity)) }
    }
    
    // MARK: - Total Count
    var totalItems: Int {
        items.reduce(0) { $0 + $1.quantity }
    }
    
    func increaseQuantity(productId: String) {
        guard let index = items.firstIndex(where: { $0.id == productId }) else { return }
        items[index].quantity += 1
    }
}
