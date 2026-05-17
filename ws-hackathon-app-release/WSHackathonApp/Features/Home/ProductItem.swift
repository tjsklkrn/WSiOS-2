//
//  ProductItem.swift
//  WSHackathonApp
//
//  Created by Nilesh Mahajan on 05/04/26.
//

import Foundation

struct ProductItem: Identifiable {
    let id: String
    let title: String
    let price: Double?
    let path: String?

    init(id: String, title: String, price: Double?, path: String?) {
        self.id = id
        self.title = title
        self.price = price
        self.path = path
    }

    var imageURL: URL? {
        guard let imageUrl = path else { return nil }
        // Paths from the API start with "/" (e.g. "/img17m.jpg").
        // imageBasePath already ends with "/", so strip the leading slash
        // to avoid a double-slash that breaks URLSession image loading.
        let cleanPath = imageUrl.hasPrefix("/") ? String(imageUrl.dropFirst()) : imageUrl
        return URL(string: AppConstants.API.imageBasePath + cleanPath)
    }
}

extension ProductItem {
    init(from dto: ProductItemDTO) {
        self.id = dto.id
        self.title = dto.name

        if let priceValue = dto.price?.regularPrice {
            self.price = priceValue
        } else {
            self.price = 0.0
        }

        if let firstImage = dto.media?.images?.first?.path {
            self.path = firstImage
        } else {
            self.path = nil
        }
    }
}
