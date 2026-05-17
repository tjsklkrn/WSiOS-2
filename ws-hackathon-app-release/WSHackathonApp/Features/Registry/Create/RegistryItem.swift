//
//  RegistryItem.swift
//  WSHackathonApp
//
//  Created by Nilesh Mahajan on 06/04/26.
//

import Foundation
struct RegistryItem: Identifiable {
    let id: String // productId
    let title: String
    let price: Double
    let imageUrl: String?
    var quantity: Int
    var purchasedQuantity: Int = 0
    var isGroupGift: Bool = false
    var contributedAmount: Double = 0.0
    var addedByUserId: String = ""  // tracks who added this item
}
