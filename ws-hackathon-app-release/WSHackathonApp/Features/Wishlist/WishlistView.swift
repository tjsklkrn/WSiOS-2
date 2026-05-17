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
        ZStack {
            Color.white.ignoresSafeArea()

            if viewModel.items.isEmpty {
                // MARK: - Empty State
                VStack(spacing: 18) {
                    Image(systemName: "heart")
                        .font(.system(size: 40, weight: .ultraLight))
                        .foregroundColor(Color(white: 0.7))
                    Text("YOUR WISHLIST IS EMPTY")
                        .font(.system(size: 12, weight: .medium))
                        .tracking(1.5)
                        .foregroundColor(.black)
                    Text(AppStrings.Wishlist.emptyMessage)
                        .font(.system(size: 13))
                        .foregroundColor(Color(white: 0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Item count header
                        HStack {
                            Text("\(viewModel.items.count) \(viewModel.items.count == 1 ? "ITEM" : "ITEMS")")
                                .font(.system(size: 11, weight: .medium))
                                .tracking(1.2)
                                .foregroundColor(Color(white: 0.5))
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)

                        Rectangle()
                            .fill(Color(white: 0.88))
                            .frame(height: 1)

                        ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                            WSWishlistItemRow(
                                item: item,
                                onRemove: { viewModel.remove(item: item) },
                                onAddToCart: {
                                    let product = ProductItem(
                                        id: item.id,
                                        title: item.title,
                                        price: item.price,
                                        path: item.path
                                    )
                                    cartRepository.add(product: product)
                                }
                            )
                            Rectangle()
                                .fill(Color(white: 0.9))
                                .frame(height: 1)
                                .padding(.horizontal, 16)
                        }
                    }
                }
            }
        }
        .navigationTitle(AppStrings.Wishlist.title)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            viewModel.bind(wishlistRepository: wishlistRepository)
        }
    }
}

// MARK: - WS Wishlist Item Row

private struct WSWishlistItemRow: View {
    let item: WishlistItem
    let onRemove: () -> Void
    let onAddToCart: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Image
            AsyncImage(url: item.imageURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Rectangle().fill(Color(white: 0.93))
                }
            }
            .frame(width: 90, height: 90)
            .clipped()

            // Details
            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.black)
                    .lineLimit(2)

                Text(item.price.formatted(.currency(code: "USD")))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.black)

                Button(action: onAddToCart) {
                    Text("ADD TO BAG")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(1.0)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.black)
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }

            Spacer()

            // Remove
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(white: 0.5))
            }
        }
        .padding(16)
    }
}
