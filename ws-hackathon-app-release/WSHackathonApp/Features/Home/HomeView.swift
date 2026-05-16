//
//  HomeView.swift
//  WSHackathonApp
//
//  Created by Nilesh Mahajan on 03/04/26.
//

import SwiftUI

struct HomeView: View {

    @StateObject private var viewModel = HomeViewModel()

    @EnvironmentObject var cartRepository: CartRepository
    @EnvironmentObject var registryRepository: RegistryRepository
    @EnvironmentObject var tabBarVM: WSTabBarViewModel

    @EnvironmentObject var authVM: AuthViewModel

    @State private var showSignOutConfirm = false
    

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGray6)
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {

                    // MARK: - Search Bar
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField(AppStrings.Home.searchPlaceHolder, text: $viewModel.searchText)
                    }
                    .padding(10)
                    .background(Color.white)
                    .cornerRadius(8)
                    .padding([.horizontal, .top], 16)

                    // MARK: - Content
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView()
                            .frame(maxWidth: .infinity)
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 0) {

                                // MARK: - Main Grid
                                let spacing: CGFloat = 12
                                let columns = [
                                    GridItem(.flexible(), spacing: spacing),
                                    GridItem(.flexible(), spacing: spacing)
                                ]
                                LazyVGrid(columns: columns, spacing: spacing) {
                                    ForEach(viewModel.filteredProducts) { product in
                                        ProductCardView(
                                            product: product,
                                            quantity: viewModel.quantity(for: product),
                                            registryQuantity: viewModel.registryQuantity(for: product),
                                            isWishlisted: viewModel.isWishlisted(product),
                                            onAdd: { viewModel.addToCart(product) },
                                            onRemove: { viewModel.removeFromCart(product) },
                                            onAddToRegistry: {
                                                if viewModel.canAddToRegistry(product) {
                                                    viewModel.addToRegistry(product)
                                                } else {
                                                    tabBarVM.selectTab(.registry)
                                                }
                                            },
                                            onRemoveFromRegistry: { viewModel.removeFromRegistry(product) },
                                            onToggleWishlist: { viewModel.toggleWishlist(product) },
                                            onTap: {
                                                viewModel.recordView(product)
                                                selectedProduct = product
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 16)

                                // MARK: - "Customers Who Searched… Also Browsed"
                                if !viewModel.alsoBrowsed.isEmpty {
                                    alsoBrowsedSection
                                        .padding(.top, 24)
                                }

                                // MARK: - Recently Viewed
                                if !viewModel.recentlyViewed.isEmpty {
                                    recentlyViewedSection
                                        .padding(.top, 24)
                                }

                                Spacer(minLength: 32)
                            }
                        }
                    }
                }
            }
            .navigationTitle(AppStrings.Home.title)

            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showSignOutConfirm = true }) {
                        Image(systemName: "person.circle")
                            .font(.system(size: 18))
                            .foregroundColor(.primary)
                    }
                }
            }
            .confirmationDialog("Sign Out", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) {
                    authVM.signOut()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out?")
            }

            .onAppear {
                Task {
                    viewModel.bind(
                        cartRepository: cartRepository,
                        registryRepository: registryRepository,
                        wishlistRepository: wishlistRepository
                    )
                    await viewModel.fetchProducts()
                }
            }
            .sheet(item: $selectedProduct) { product in
                ProductDetailView(product: product)
                    .environmentObject(wishlistRepository)
                    .environmentObject(cartRepository)
            }
        }
    }

    // MARK: - Also Browsed Section

    private var alsoBrowsedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Customers Who Searched \"\(viewModel.searchText)\"")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 16)
                Text("Also Browsed")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 16)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(viewModel.alsoBrowsed) { product in
                        HorizontalProductCard(product: product) {
                            viewModel.recordView(product)
                            selectedProduct = product
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Recently Viewed Section

    private var recentlyViewedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recently Viewed")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(viewModel.recentlyViewed) { product in
                        HorizontalProductCard(product: product) {
                            viewModel.recordView(product)
                            selectedProduct = product
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - Horizontal Product Card (for scrollable sections)

struct HorizontalProductCard: View {
    let product: ProductItem
    let onTap: () -> Void
    private let cardWidth: CGFloat = 152
    private let imageHeight: CGFloat = 130

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                AsyncImage(url: product.imageURL) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: cardWidth, height: imageHeight)
                            .clipped()
                            .cornerRadius(8)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))
                            .frame(width: cardWidth, height: imageHeight)
                            .overlay(
                                phase.error != nil
                                    ? AnyView(Image(systemName: "photo").foregroundColor(.gray).font(.title2))
                                    : AnyView(ProgressView())
                            )
                    }
                }

                Text(product.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                    .frame(width: cardWidth, alignment: .leading)

                if let price = product.price {
                    Text(price.formatted(.currency(code: "USD")))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 0)
            }
            .frame(width: cardWidth)
            .padding(10)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color(.systemGray4), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}
