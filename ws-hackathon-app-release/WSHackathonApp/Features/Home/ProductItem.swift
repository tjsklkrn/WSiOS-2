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
        if let imageUrl = path {
            return URL(string: AppConstants.API.imageBasePath + imageUrl)
        }
        return nil
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

        // Prioritize 'primary' image type if available
        let images = dto.media?.images ?? []
        if let primaryImage = images.first(where: { $0.type == "primary" })?.path {
            self.path = primaryImage
        } else {
            self.path = images.first?.path
        }
    }
}
