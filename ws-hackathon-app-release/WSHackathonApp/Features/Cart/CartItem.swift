//
//  CartItem.swift
//  WSHackathonApp
//

import Foundation

struct CartItem: Identifiable {
    let id: String
    let title: String
    let price: Double
    let path: String?
    var quantity: Int
    var backOrdered: Bool

    init(id: String, title: String, price: Double, path: String?, quantity: Int, backOrdered: Bool = false) {
        self.id = id
        self.title = title
        self.price = price
        self.path = path
        self.quantity = quantity
        self.backOrdered = backOrdered
    }

    var imageURL: URL? {
        guard let imageUrl = path else { return nil }
        return URL(string: AppConstants.API.imageBasePath + imageUrl)
    }
}
