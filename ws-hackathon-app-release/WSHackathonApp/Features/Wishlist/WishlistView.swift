//
//  WishlistView.swift
//  WSHackathonApp
//

import SwiftUI

struct WishlistView: View {

    @StateObject private var viewModel = WishlistViewModel()
    @EnvironmentObject var wishlistRepository: WishlistRepository
    @EnvironmentObject var cartRepository: CartRepository

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.items.isEmpty {
                    emptyState
                } else {
                    itemsList
                }
            }
            .navigationTitle(AppStrings.Wishlist.title)
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemGray6).ignoresSafeArea())
        }
        .onAppear {
            viewModel.bind(wishlistRepository: wishlistRepository)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "heart.slash")
                .font(.system(size: 52))
                .foregroundColor(.secondary)
            Text(AppStrings.Wishlist.emptyTitle)
                .font(.headline)
            Text(AppStrings.Wishlist.emptyMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    // MARK: - Items List

    private var itemsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.items) { item in
                    WishlistItemRow(
                        item: item,
                        onRemove: { viewModel.remove(item: item) },
                        onAddToCart: {
                            // Convert WishlistItem -> ProductItem for cart
                            let product = ProductItem(
                                id: item.id,
                                title: item.title,
                                price: item.price,
                                path: item.path
                            )
                            cartRepository.add(product: product)
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - WishlistItemRow

private struct WishlistItemRow: View {
    let item: WishlistItem
    let onRemove: () -> Void
    let onAddToCart: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Product image
            AsyncImage(url: item.imageURL) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                Text(item.price.formatted(.currency(code: "USD")))
                    .font(.subheadline)
                    .foregroundColor(.primary)

                HStack(spacing: 8) {
                    Button(action: onAddToCart) {
                        Text(AppStrings.Home.addToCartButton)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    }
                    Button(action: onRemove) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 18))
                    }
                }
            }

            Spacer()
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color(.systemGray4), radius: 2, x: 0, y: 1)
    }
}
