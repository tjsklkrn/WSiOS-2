//
//  CartView.swift
//  WSHackathonApp
//
//  Created by Nilesh Mahajan on 03/04/26.
//

import SwiftUI

struct CartView: View {
    @StateObject private var viewModel = CartViewModel()
    @EnvironmentObject var cartRepository: CartRepository
    @EnvironmentObject var tabBarVM: WSTabBarViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()

                if viewModel.isEmptyCart {
                    // MARK: - Empty State
                    VStack(spacing: 0) {
                        Spacer()
                        VStack(spacing: 20) {
                            Image(systemName: "cart")
                                .font(.system(size: 40, weight: .ultraLight))
                                .foregroundColor(Color(white: 0.7))

                            Text("YOUR BAG IS EMPTY")
                                .font(.system(size: 13, weight: .medium))
                                .tracking(1.5)
                                .foregroundColor(.black)

                            Text("Add items to your bag to see them here.")
                                .font(.system(size: 13))
                                .foregroundColor(Color(white: 0.5))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)

                            Button {
                                tabBarVM.selectTab(.home)
                            } label: {
                                Text("CONTINUE SHOPPING")
                                    .font(.system(size: 12, weight: .medium))
                                    .tracking(1.2)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.black)
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 32)
                            .padding(.top, 8)
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }

                } else {
                    VStack(spacing: 0) {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 0) {
                                // Item count
                                HStack {
                                    Text("\(viewModel.items.count) \(viewModel.items.count == 1 ? "ITEM" : "ITEMS")")
                                        .font(.system(size: 11, weight: .medium))
                                        .tracking(1.2)
                                        .foregroundColor(Color(white: 0.5))
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                                .padding(.bottom, 12)

                                Rectangle()
                                    .fill(Color(white: 0.9))
                                    .frame(height: 1)
                                    .padding(.horizontal, 16)

                                ForEach(viewModel.items) { item in
                                    WSCartItemRow(
                                        item: item,
                                        onAdd: { viewModel.add(item) },
                                        onRemove: { viewModel.removeItem(item) },
                                        onDelete: { viewModel.deleteItem(item) }
                                    )

                                    Rectangle()
                                        .fill(Color(white: 0.9))
                                        .frame(height: 1)
                                        .padding(.horizontal, 16)
                                }

                                // Promo / free shipping note
                                HStack(spacing: 8) {
                                    Image(systemName: "shippingbox")
                                        .font(.system(size: 14))
                                        .foregroundColor(.black)
                                    Text("Free Standard Shipping on this order")
                                        .font(.system(size: 12))
                                        .foregroundColor(.black)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(white: 0.96))
                                .padding(.top, 16)
                                .padding(.horizontal, 16)
                            }
                        }

                        // MARK: - Bottom Summary
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(Color(white: 0.88))
                                .frame(height: 1)

                            VStack(spacing: 14) {
                                HStack {
                                    Text("SUBTOTAL")
                                        .font(.system(size: 11, weight: .medium))
                                        .tracking(1.2)
                                        .foregroundColor(Color(white: 0.5))
                                    Spacer()
                                    Text(viewModel.totalPriceText)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.black)
                                }

                                Button {
                                    // checkout
                                } label: {
                                    Text("PROCEED TO CHECKOUT")
                                        .font(.system(size: 12, weight: .medium))
                                        .tracking(1.5)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 17)
                                        .background(Color.black)
                                        .foregroundColor(.white)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 18)
                            .background(Color.white)
                        }
                    }
                }
            }
            .navigationTitle(AppStrings.Cart.title)
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            Task { viewModel.bind(repository: cartRepository) }
        }
    }
}

// MARK: - WS Cart Item Row

private struct WSCartItemRow: View {
    let item: CartItem
    let onAdd: () -> Void
    let onRemove: () -> Void
    let onDelete: () -> Void

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
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.black)
                    .lineLimit(2)

                Text(item.price.formatted(.currency(code: "USD")))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.black)

                // Quantity row
                HStack(spacing: 0) {
                    Button(action: onRemove) {
                        Image(systemName: "minus")
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 32, height: 32)
                            .foregroundColor(.black)
                    }
                    Rectangle()
                        .fill(Color(white: 0.85))
                        .frame(width: 1, height: 20)

                    Text("\(item.quantity)")
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 36, height: 32)
                        .foregroundColor(.black)

                    Rectangle()
                        .fill(Color(white: 0.85))
                        .frame(width: 1, height: 20)

                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 32, height: 32)
                            .foregroundColor(.black)
                    }
                }
                .overlay(Rectangle().stroke(Color(white: 0.82), lineWidth: 1))
                .padding(.top, 4)
            }

            Spacer()

            // Delete
            VStack(alignment: .trailing) {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(white: 0.5))
                }
                Spacer()
                Text("$\(item.price * Double(item.quantity), specifier: "%.2f")")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.black)
            }
        }
        .padding(16)
    }
}
