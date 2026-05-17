//
//  CartViewModel.swift
//  WSHackathonApp
//

import Foundation
import Combine

@MainActor
final class CartViewModel: ObservableObject {

    // MARK: - Cart State (mirrors CartRepository)
    @Published private(set) var items: [CartItem] = []
    @Published private(set) var saveForLater: [SaveForLaterItemResponse] = []
    @Published private(set) var totalPrice: Double = 0
    @Published private(set) var totalItems: Int = 0
    @Published private(set) var isLoading: Bool = false

    // MARK: - Recommendations
    @Published private(set) var recommendations: [RecommendationItem] = []
    @Published private(set) var isLoadingRecommendations: Bool = false

    // MARK: - Bundles
    @Published private(set) var bundles: [BundleItem] = []
    @Published private(set) var isLoadingBundles: Bool = false

    private var repository: CartRepository?
    private var cancellables = Set<AnyCancellable>()

    // Debounce recommendations fetch after cart changes
    private let cartChangedSubject = PassthroughSubject<Void, Never>()

    // MARK: - Bind

    func bind(repository: CartRepository) {
        self.repository = repository

        // Mirror repository state into viewModel published properties
        repository.$items
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.items = $0 }
            .store(in: &cancellables)

        repository.$saveForLater
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.saveForLater = $0 }
            .store(in: &cancellables)

        repository.$totalPrice
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.totalPrice = $0 }
            .store(in: &cancellables)

        repository.$totalItems
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.totalItems = $0 }
            .store(in: &cancellables)

        repository.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.isLoading = $0 }
            .store(in: &cancellables)

        // Debounce: fetch recommendations + bundles 800ms after cart changes
        cartChangedSubject
            .debounce(for: .milliseconds(800), scheduler: DispatchQueue.main)
            .sink { [weak self] in
                Task { [weak self] in
                    await self?.fetchRecommendationsAndBundles()
                }
            }
            .store(in: &cancellables)

        // Trigger on item changes
        repository.$items
            .dropFirst()
            .map { _ in () }
            .subscribe(cartChangedSubject)
            .store(in: &cancellables)
    }

    // MARK: - Load

    func loadCart() async {
        await repository?.loadCart()
        await fetchRecommendationsAndBundles()
    }

    // MARK: - Cart Actions

    var isEmptyCart: Bool { items.isEmpty }

    var totalPriceText: String {
        String(format: "$%.2f", totalPrice)
    }

    func add(_ item: CartItem) {
        repository?.increaseQuantity(productId: item.id)
    }

    func removeItem(_ item: CartItem) {
        repository?.remove(productId: item.id)
    }

    func deleteItem(_ item: CartItem) {
        repository?.delete(productId: item.id)
    }

    func notifySaveForLater(productId: String) {
        Task { await repository?.notifySaveForLater(productId: productId) }
    }

    // MARK: - Checkout

    func checkout() {
        Task {
            await repository?.checkout()
            await loadCart()
        }
    }

    // MARK: - Recommendations

    func fetchRecommendationsAndBundles() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchRecommendations() }
            group.addTask { await self.fetchBundles() }
        }
    }

    private func fetchRecommendations() async {
        guard !(items.isEmpty) else {
            recommendations = []
            return
        }
        isLoadingRecommendations = true
        defer { isLoadingRecommendations = false }
        do {
            let response: RecommendationsResponse = try await APIClient.shared.request(
                Endpoint.cartRecommendations()
            )
            recommendations = response.recommendations
        } catch {
            print("[CartViewModel] fetchRecommendations error:", error)
        }
    }

    private func fetchBundles() async {
        guard !(items.isEmpty) else {
            bundles = []
            return
        }
        isLoadingBundles = true
        defer { isLoadingBundles = false }
        do {
            let response: BundlesResponse = try await APIClient.shared.request(
                Endpoint.cartBundles()
            )
            bundles = response.bundles
        } catch {
            print("[CartViewModel] fetchBundles error:", error)
        }
    }
}
