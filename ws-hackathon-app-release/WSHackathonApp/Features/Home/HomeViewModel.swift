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
    @Published var products: [ProductItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // Recently viewed items (in-session)
    @Published var recentlyViewed: [ProductItem] = []

    // "Customers who searched X also browsed" — derived from searchText
    @Published var alsoBrowsed: [ProductItem] = []

    private var hasLoaded = false
    private var cartRepository: CartRepository?
    private var registryRepository: RegistryRepository?
    private var wishlistRepository: WishlistRepository?
    private var cancellables = Set<AnyCancellable>()

    func bind(cartRepository: CartRepository,
              registryRepository: RegistryRepository,
              wishlistRepository: WishlistRepository) {
        self.cartRepository = cartRepository
        self.registryRepository = registryRepository
        self.wishlistRepository = wishlistRepository

        // When search text changes, update alsoBrowsed from full product list
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] query in
                self?.updateAlsoBrowsed(for: query)
            }
            .store(in: &cancellables)
    }

    // MARK: - Recently Viewed

    func recordView(_ product: ProductItem) {
        // Move to front if already viewed; max 20
        recentlyViewed.removeAll { $0.id == product.id }
        recentlyViewed.insert(product, at: 0)
        if recentlyViewed.count > 20 { recentlyViewed = Array(recentlyViewed.prefix(20)) }
    }

    // MARK: - Also Browsed

    private func updateAlsoBrowsed(for query: String) {
        guard !query.isEmpty else {
            alsoBrowsed = []
            return
        }
        // Products NOT matching the exact query but related (everything else)
        let matched = products.filter { $0.title.localizedCaseInsensitiveContains(query) }
        let others  = products.filter { !$0.title.localizedCaseInsensitiveContains(query) }
        // Show "others" (customers who searched X also browsed these), shuffled for freshness
        alsoBrowsed = Array((others.isEmpty ? matched : others).shuffled().prefix(10))
    }

    // MARK: - Cart

    func addToCart(_ product: ProductItem) {
        cartRepository?.add(product: product)
    }

    func removeFromCart(_ product: ProductItem) {
        cartRepository?.remove(productId: product.id)
    }

    // MARK: - Registry

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

    // MARK: - Wishlist

    func isWishlisted(_ product: ProductItem) -> Bool {
        wishlistRepository?.isWishlisted(product) ?? false
    }

    func toggleWishlist(_ product: ProductItem) {
        wishlistRepository?.toggle(product: product)
        // Trigger UI refresh
        objectWillChange.send()
    }

    // MARK: - Quantities

    func quantity(for product: ProductItem) -> Int {
        cartRepository?.items.first(where: { $0.id == product.id })?.quantity ?? 0
    }

    func registryQuantity(for product: ProductItem) -> Int {
        registryRepository?.currentRegistry?.items.first(where: { $0.id == product.id })?.quantity ?? 0
    }

    // MARK: - Filtered Products

    var filteredProducts: [ProductItem] {
        if searchText.isEmpty {
            return products
        } else {
            return products.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }

    // MARK: - Fetch

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
