//
//  WishlistView.swift
//  WSHackathonApp
//

import SwiftUI

struct WishlistView: View {

    @EnvironmentObject var wishlistRepository: WishlistRepository
    @EnvironmentObject var cartRepository: CartRepository
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if wishlistRepository.items.isEmpty {
                    emptyState
                } else {
                    itemList
                }
            }
            .navigationTitle("Wishlist")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "heart")
                .font(.system(size: 52))
                .foregroundColor(Color(.systemGray3))
            Text("Your wishlist is empty")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            Text("Tap the heart on any product\nto save it here.")
                .font(.system(size: 14))
                .foregroundColor(Color(.systemGray))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Item List
    private var itemList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(wishlistRepository.items) { product in
                    WishlistRow(
                        product: product,
                        onRemove: { wishlistRepository.remove(product.id) },
                        onAddToCart: { cartRepository.add(product: product) }
                    )
                    Divider()
                        .padding(.leading, 88)
                }
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - Wishlist Row
private struct WishlistRow: View {
    let product: ProductItem
    let onRemove: () -> Void
    let onAddToCart: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Product image
            AsyncImage(url: product.imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 72)
                        .clipped()
                        .cornerRadius(10)
                case .failure:
                    placeholder
                default:
                    ZStack {
                        Color(.systemGray5)
                        ProgressView()
                    }
                    .frame(width: 72, height: 72)
                    .cornerRadius(10)
                }
            }
            .frame(width: 72, height: 72)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(product.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)

                Text(product.price?.formatted(.currency(code: "USD")) ?? "")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
            }

            Spacer()

            // Actions
            VStack(spacing: 10) {
                // Remove from wishlist
                Button(action: onRemove) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                }

                // Add to cart
                Button(action: onAddToCart) {
                    Image(systemName: "cart.badge.plus")
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                }
            }
            .padding(.trailing, 4)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var placeholder: some View {
        ZStack {
            Color(.systemGray5)
            Image(systemName: "photo")
                .foregroundColor(Color(.systemGray3))
                .font(.system(size: 22))
        }
        .frame(width: 72, height: 72)
        .cornerRadius(10)
    }
}
