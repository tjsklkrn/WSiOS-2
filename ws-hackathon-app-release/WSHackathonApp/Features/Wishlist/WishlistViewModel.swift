//
//  WishlistViewModel.swift
//  WSHackathonApp
//

import Foundation
import Combine

@MainActor
class WishlistViewModel: ObservableObject {

    @Published var items: [WishlistItem] = []
    private var wishlistRepository: WishlistRepository?
    private var cancellables = Set<AnyCancellable>()

    func bind(wishlistRepository: WishlistRepository) {
        self.wishlistRepository = wishlistRepository
        wishlistRepository.$items
            .receive(on: RunLoop.main)
            .assign(to: &$items)
    }

    func remove(item: WishlistItem) {
        wishlistRepository?.remove(productId: item.id)
    }
}
