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
    let brand: String?
    let productType: String?

    init(id: String, title: String, price: Double?, path: String?, brand: String? = nil, productType: String? = nil) {
        self.id = id
        self.title = title
        self.price = price
        self.path = path
        self.brand = brand
        self.productType = productType
    }

    var imageURL: URL? {
        guard let imageUrl = path else { return nil }
        return URL(string: AppConstants.API.imageBasePath + imageUrl)
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
        
        self.brand = dto.properties?.brand
        self.productType = dto.properties?.productType
    }
}
