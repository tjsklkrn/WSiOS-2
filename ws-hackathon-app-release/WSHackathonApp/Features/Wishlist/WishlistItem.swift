//
//  WishlistItem.swift
//  WSHackathonApp
//

import Foundation

struct WishlistItem: Identifiable {
    let id: String
    let title: String
    let price: Double
    let path: String?

    var imageURL: URL? {
        guard let p = path else { return nil }
        return URL(string: AppConstants.API.imageBasePath + p)
    }
}
