//
//  OrderHistoryManager.swift
//  WSHackathonApp
//
//  Created by Nilesh Mahajan on 17/05/26.
//

import Foundation

struct OrderHistoryItem: Codable, Identifiable {
    let id: String // ORD-XXXXXX
    let dateString: String
    let total: Double
    let items: [OrderItem]
    let status: String // "Processing", "Shipped", "Delivered"

    struct OrderItem: Codable, Identifiable {
        let id: String
        let title: String
        let quantity: Int
        let price: Double
        let path: String?
    }
}

class OrderHistoryManager {
    static let shared = OrderHistoryManager()
    private let key = "williams_sonoma_order_history"

    func getOrders() -> [OrderHistoryItem] {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return []
        }
        do {
            return try JSONDecoder().decode([OrderHistoryItem].self, from: data)
        } catch {
            print("[OrderHistoryManager] decode error:", error)
            return []
        }
    }

    func saveOrder(items: [CartItem], total: Double) {
        var currentOrders = getOrders()

        // Generate a random order ID like ORD-129481
        let orderId = "ORD-\(Int.random(in: 100000...999999))"

        // Format current date
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let dateStr = formatter.string(from: Date())

        let orderItems = items.map { item in
            OrderHistoryItem.OrderItem(
                id: item.id,
                title: item.title,
                quantity: item.quantity,
                price: item.price,
                path: item.path
            )
        }

        let newOrder = OrderHistoryItem(
            id: orderId,
            dateString: dateStr,
            total: total,
            items: orderItems,
            status: "Processing"
        )

        // Prepend so latest order shows at the top!
        currentOrders.insert(newOrder, at: 0)

        do {
            let data = try JSONEncoder().encode(currentOrders)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("[OrderHistoryManager] encode error:", error)
        }
    }
}
