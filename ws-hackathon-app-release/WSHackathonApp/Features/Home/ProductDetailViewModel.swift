//
//  ProductDetailViewModel.swift
//  WSHackathonApp
//

import Foundation
import Combine

// MARK: - Review Model

struct ProductReview: Identifiable {
    let id: UUID = UUID()
    let author: String
    let rating: Int        // 1-5
    let date: String
    let comment: String
}

// MARK: - Size / Color Option

struct SizeOption: Identifiable, Hashable {
    let id: String
    let label: String
}

struct ColorOption: Identifiable, Hashable {
    let id: String
    let label: String
    let hexColor: String   // e.g. "#3A9E9E"
}

// MARK: - ViewModel

@MainActor
class ProductDetailViewModel: ObservableObject {

    let product: ProductItem

    @Published var selectedSize: SizeOption?
    @Published var selectedColor: ColorOption?
    @Published var quantity: Int = 1
    @Published var isWishlisted: Bool = false

    // Mocked options — in production these come from API
    let sizes: [SizeOption] = [
        SizeOption(id: "1", label: "1 QT."),
        SizeOption(id: "2", label: "1 3/4 QT."),
        SizeOption(id: "3", label: "2 1/2 QT."),
        SizeOption(id: "4", label: "5 QT.")
    ]

    let colors: [ColorOption] = [
        ColorOption(id: "1", label: "Bleu Riviera",  hexColor: "#3A9E9E"),
        ColorOption(id: "2", label: "Artichaut",     hexColor: "#3D5C2E"),
        ColorOption(id: "3", label: "Rose Quartz",   hexColor: "#F2B8B0"),
        ColorOption(id: "4", label: "Cerise",        hexColor: "#8B1A1A"),
        ColorOption(id: "5", label: "Nectar",        hexColor: "#D9732C")
    ]

    let reviews: [ProductReview] = [
        ProductReview(author: "Sarah M.", rating: 5, date: "Apr 12, 2025",
                      comment: "Absolutely love this! Great quality and looks beautiful in my kitchen."),
        ProductReview(author: "James T.", rating: 4, date: "Mar 28, 2025",
                      comment: "Very sturdy and heats evenly. Would buy again."),
        ProductReview(author: "Priya K.", rating: 3, date: "Feb 14, 2025",
                      comment: "Good product but the lid doesn't seal as tight as expected."),
        ProductReview(author: "Daniel R.", rating: 5, date: "Jan 9, 2025",
                      comment: "Worth every penny. A heirloom-quality piece.")
    ]

    var averageRating: Double {
        guard !reviews.isEmpty else { return 0 }
        return Double(reviews.map(\.rating).reduce(0, +)) / Double(reviews.count)
    }

    let frequentlyBought: [ProductItem] = [
        ProductItem(id: "FB-1", title: "Crockery Cleaner & Conditioner", price: 27.00, path: nil),
        ProductItem(id: "FB-2", title: "Stainless Steel Sponge Set", price: 15.00, path: nil),
        ProductItem(id: "FB-3", title: "Silicone Spatula", price: 12.50, path: nil)
    ]

    private var wishlistRepository: WishlistRepository?
    private var cartRepository: CartRepository?
    private var registryRepository: RegistryRepository?

    init(product: ProductItem) {
        self.product = product
        selectedColor = colors.first
        selectedSize  = sizes.first
    }

    func bind(wishlistRepository: WishlistRepository,
              cartRepository: CartRepository,
              registryRepository: RegistryRepository) {
        self.wishlistRepository = wishlistRepository
        self.cartRepository     = cartRepository
        self.registryRepository = registryRepository
        isWishlisted = wishlistRepository.isWishlisted(product)
    }

    func toggleWishlist() {
        wishlistRepository?.toggle(product: product)
        isWishlisted.toggle()
    }

    func addToCart() {
        guard quantity > 0 else { return }
        for _ in 0..<quantity {
            cartRepository?.add(product: product)
        }
    }

    func incrementQuantity() { quantity += 1 }
    func decrementQuantity() { if quantity > 1 { quantity -= 1 } }

    func addToRegistry() {
        registryRepository?.addProduct(product)
    }
}
