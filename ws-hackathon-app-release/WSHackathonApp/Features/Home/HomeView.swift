//
//  HomeView.swift
//  WSHackathonApp
//

import SwiftUI

// MARK: - Promo Banner Model
private struct PromoBanner: Identifiable {
    let id: Int
    let headline: String
    let subtext: String
    let icon: String
    let accentColor: Color
}

struct HomeView: View {

    @StateObject private var viewModel = HomeViewModel()

    @EnvironmentObject var cartRepository: CartRepository
    @EnvironmentObject var registryRepository: RegistryRepository
    @EnvironmentObject var wishlistRepository: WishlistRepository
    @EnvironmentObject var tabBarVM: WSTabBarViewModel

    @State private var selectedCategory: String = "All"
    @State private var currentBannerIndex: Int = 0
    @State private var showWishlist: Bool = false

    private let categories = ["All", "Cookware", "Knives", "Bakeware", "Electrics", "Tabletop"]

    private let banners: [PromoBanner] = [
        PromoBanner(id: 0, headline: "Free Shipping", subtext: "On all orders over $99", icon: "shippingbox", accentColor: Color(red: 0.95, green: 0.93, blue: 0.88)),
        PromoBanner(id: 1, headline: "New Arrivals", subtext: "Fresh picks for your kitchen", icon: "sparkles", accentColor: Color(red: 0.88, green: 0.93, blue: 0.95)),
        PromoBanner(id: 2, headline: "Members Save 15%", subtext: "Join our loyalty program today", icon: "star.circle", accentColor: Color(red: 0.93, green: 0.90, blue: 0.96)),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // MARK: - Header
                    headerView

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 20) {

                            // MARK: - Search Bar
                            searchBar

                            // MARK: - Promo Carousel
                            promoCarousel

                            // MARK: - Category Chips
                            categoryChips

                            // MARK: - Product Grid
                            productGrid
                        }
                        .padding(.bottom, 100)
                    }
                }
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
                startAutoScroll()
            }
            .sheet(isPresented: $showWishlist) {
                WishlistView()
                    .environmentObject(wishlistRepository)
                    .environmentObject(cartRepository)
            }
        }
    }

    // MARK: - Auto Scroll Timer
    private func startAutoScroll() {
        Timer.scheduledTimer(withTimeInterval: 3.5, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                currentBannerIndex = (currentBannerIndex + 1) % banners.count
            }
        }
    }

    // MARK: - Header
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer()

                // Wishlist heart icon
                Button(action: { showWishlist = true }) {
                    Image(systemName: wishlistRepository.count > 0 ? "heart.fill" : "heart")
                        .font(.system(size: 22))
                        .foregroundColor(wishlistRepository.count > 0 ? .red : .primary)
                        .frame(width: 42, height: 42)
                }

                // Profile icon
                Button(action: {}) {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 42, height: 42)
                        .overlay(
                            Image(systemName: "person.crop.circle")
                                .foregroundColor(.primary)
                                .font(.system(size: 22))
                        )
                }
            }

            // Hero headline
            Text("Discover our\ncurated collection")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.primary)
                .lineSpacing(2)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color(.systemGray2))
                .font(.system(size: 16))

            TextField("Search", text: $viewModel.searchText)
                .font(.system(size: 15))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal, 20)
    }

    // MARK: - Promo Carousel
    private var promoCarousel: some View {
        VStack(spacing: 10) {
            TabView(selection: $currentBannerIndex) {
                ForEach(banners) { banner in
                    BannerCard(banner: banner)
                        .tag(banner.id)
                        .padding(.horizontal, 20)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 140)

            // Dot indicators
            HStack(spacing: 6) {
                ForEach(0..<banners.count, id: \.self) { index in
                    Capsule()
                        .fill(currentBannerIndex == index ? Color.black : Color(.systemGray4))
                        .frame(width: currentBannerIndex == index ? 20 : 6, height: 6)
                        .animation(.easeInOut(duration: 0.3), value: currentBannerIndex)
                }
            }
        }
    }

    // MARK: - Category Chips
    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(categories, id: \.self) { category in
                    CategoryChip(
                        title: category,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Product Grid
    private var productGrid: some View {
        Group {
            if viewModel.isLoading {
                VStack {
                    Spacer(minLength: 60)
                    ProgressView()
                        .scaleEffect(1.2)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if viewModel.filteredProducts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(Color(.systemGray3))
                    Text("No products found")
                        .font(.system(size: 16))
                        .foregroundColor(Color(.systemGray))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else {
                let columns = [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14)
                ]
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(viewModel.filteredProducts) { product in
                        ProductCardView(
                            product: product,
                            quantity: viewModel.quantity(for: product),
                            registryQuantity: viewModel.registryQuantity(for: product),
                            isWishlisted: wishlistRepository.isWishlisted(product),
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
                            onToggleWishlist: { wishlistRepository.toggle(product) }
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Banner Card
private struct BannerCard: View {
    let banner: PromoBanner

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(banner.accentColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color(.systemGray4), lineWidth: 1)
                )

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(banner.headline)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(.primary)

                    Text(banner.subtext)
                        .font(.system(size: 13))
                        .foregroundColor(Color(.systemGray))

                    HStack(spacing: 5) {
                        Text("Shop now")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(20)
                }
                .padding(.leading, 20)
                .padding(.vertical, 20)

                Spacer()

                Image(systemName: banner.icon)
                    .font(.system(size: 52))
                    .foregroundColor(.primary.opacity(0.15))
                    .padding(.trailing, 24)
            }
        }
        .frame(height: 140)
    }
}

// MARK: - Category Chip
private struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(isSelected ? Color.black : Color(.systemGray6))
                .clipShape(Capsule())
        }
    }
}
