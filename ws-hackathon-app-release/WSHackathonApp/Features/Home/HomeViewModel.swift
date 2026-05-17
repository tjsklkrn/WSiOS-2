//
//  HomeViewModel.swift
//  WSHackathonApp
//
//  Created by Nilesh Mahajan on 04/04/26.
//

import Foundation
import Combine

@MainActor
class HomeViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var selectedBrand: String?
    @Published var selectedCategory: String?
    @Published var products: [ProductItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private var hasLoaded = false
    private var cartRepository: CartRepository?
    private var registryRepository: RegistryRepository?
    private var wishlistRepository: WishlistRepository?

    func bind(cartRepository: CartRepository,
              registryRepository: RegistryRepository,
              wishlistRepository: WishlistRepository) {
        self.cartRepository = cartRepository
        self.registryRepository = registryRepository
        self.wishlistRepository = wishlistRepository
    }

    // Cart
    func addToCart(_ product: ProductItem) {
        cartRepository?.add(product: product)
    }

    func removeFromCart(_ product: ProductItem) {
        cartRepository?.remove(productId: product.id)
    }

    // Registry
    func addToRegistry(_ product: ProductItem) {
        registryRepository?.addProduct(product)
    }

    func canAddToRegistry(_ product: ProductItem) -> Bool {
        if let registryRepository, registryRepository.isActiveRegistry {
            return true
        }
        return false
    }

    func removeFromRegistry(_ product: ProductItem) {
        registryRepository?.removeItem(product.id)
    }

    // Wishlist
    func toggleWishlist(_ product: ProductItem) {
        wishlistRepository?.toggle(product)
    }

    func isWishlisted(_ product: ProductItem) -> Bool {
        wishlistRepository?.isWishlisted(product) ?? false
    }

    func quantity(for product: ProductItem) -> Int {
        cartRepository?.items.first(where: { $0.id == product.id })?.quantity ?? 0
    }

    func registryQuantity(for product: ProductItem) -> Int {
        registryRepository?.currentRegistry?.items.first(where: { $0.id == product.id })?.quantity ?? 0
    }

    var availableBrands: [String] {
        let brands = products.compactMap { $0.brand }
        return Array(Set(brands)).sorted()
    }

    var availableCategories: [String] {
        let categories = products.compactMap { $0.productType }
        return Array(Set(categories)).sorted()
    }

    var filteredProducts: [ProductItem] {
        var result = products
        
        if !searchText.isEmpty {
            result = result.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
        
        if let brand = selectedBrand {
            result = result.filter { $0.brand == brand }
        }
        
        if let category = selectedCategory {
            result = result.filter { $0.productType == category }
        }
        
        return result
    }
    
    func formatSlug(_ slug: String) -> String {
        return slug.replacingOccurrences(of: "-", with: " ").capitalized
    }

    func fetchProducts() async {
        guard !hasLoaded else { return }
        hasLoaded = true

        isLoading = true
        errorMessage = nil

        do {
            let dtos: [ProductItemDTO] = try await APIClient.shared.request(Endpoint.products())
            self.products = dtos.map { ProductItem(from: $0) }
        } catch {
            print(error)
            errorMessage = "Failed to load products"
        }

        isLoading = false
    }
}
