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
            .map { repoItems in
                // Ensure types align with [WishlistItem]. If they already match, this map is a no-op.
                repoItems as? [WishlistItem] ?? []
            }
            .receive(on: RunLoop.main)
            .assign(to: &$items)
    }

    func remove(item: WishlistItem) {
        wishlistRepository?.remove(item.id)
    }
}

