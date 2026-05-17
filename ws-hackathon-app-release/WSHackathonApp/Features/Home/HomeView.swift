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
    let imageURL: URL?
    let targetProductId: String
}

struct HomeView: View {

    @StateObject private var viewModel = HomeViewModel()

    @EnvironmentObject var cartRepository: CartRepository
    @EnvironmentObject var registryRepository: RegistryRepository
    @EnvironmentObject var wishlistRepository: WishlistRepository
    @EnvironmentObject var tabBarVM: WSTabBarViewModel
    @EnvironmentObject var profileRepo: ProfileRepository
    @EnvironmentObject var authVM: AuthViewModel

    @State private var currentBannerIndex: Int = 0
    @State private var showWishlist: Bool = false
    @State private var selectedProduct: ProductItem?
    @State private var showProfile: Bool = false

    private let banners: [PromoBanner] = [
        PromoBanner(
            id: 0,
            headline: "Free Shipping",
            subtext: "On orders over $99",
            imageURL: URL(string: "https://images.unsplash.com/photo-1556910103-1c02745aae4d?q=80&w=2940&auto=format&fit=crop"),
            targetProductId: "3104592"
        ),
        PromoBanner(
            id: 1,
            headline: "New Arrivals",
            subtext: "Fresh picks for your kitchen",
            imageURL: URL(string: "https://images.unsplash.com/photo-1581622558667-3419a8dc5f83?q=80&w=2940&auto=format&fit=crop"),
            targetProductId: "8931142"
        ),
        PromoBanner(
            id: 2,
            headline: "Members Save",
            subtext: "Join our loyalty program today",
            imageURL: URL(string: "https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?q=80&w=2940&auto=format&fit=crop"),
            targetProductId: "1940567"
        ),
    ]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {

                    // MARK: - Search Bar
                    searchBar

                    // MARK: - Shop The Look
                    shopTheLookSection

                    // MARK: - Filters
                    filterSection

                    // MARK: - Product Grid
                    productGrid
                }
                .padding(.bottom, 100)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Elevate Your Home")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { showWishlist = true }) {
                        Image(systemName: wishlistRepository.count > 0 ? "heart.fill" : "heart")
                            .font(.system(size: 20))
                            .foregroundColor(wishlistRepository.count > 0 ? .red : .primary)
                    }

                    Button(action: { showProfile = true }) {
                        Image(systemName: "person.crop.circle")
                            .foregroundColor(.primary)
                            .font(.system(size: 20))
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
            .sheet(isPresented: $showProfile) {
                ProfileView()
                    .environmentObject(profileRepo)
                    .environmentObject(authVM)
            }
            .sheet(isPresented: $showWishlist) {
                WishlistView()
                    .environmentObject(wishlistRepository)
                    .environmentObject(cartRepository)
            }
            .sheet(item: $selectedProduct) { product in
                ProductDetailView(product: product)
                    .environmentObject(wishlistRepository)
                    .environmentObject(cartRepository)
                    .environmentObject(registryRepository)
                    .environmentObject(tabBarVM)
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
                    BannerCard(banner: banner) {
                        if let product = viewModel.products.first(where: { $0.id == banner.targetProductId }) {
                            selectedProduct = product
                        }
                    }
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

    // MARK: - Filters
    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !viewModel.availableCategories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        CategoryChip(
                            title: "All Categories",
                            isSelected: viewModel.selectedCategory == nil
                        ) {
                            withAnimation { viewModel.selectedCategory = nil }
                        }
                        ForEach(viewModel.availableCategories, id: \.self) { category in
                            CategoryChip(
                                title: viewModel.formatSlug(category),
                                isSelected: viewModel.selectedCategory == category
                            ) {
                                withAnimation { viewModel.selectedCategory = category }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            
            if !viewModel.availableBrands.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        CategoryChip(
                            title: "All Brands",
                            isSelected: viewModel.selectedBrand == nil
                        ) {
                            withAnimation { viewModel.selectedBrand = nil }
                        }
                        ForEach(viewModel.availableBrands, id: \.self) { brand in
                            CategoryChip(
                                title: viewModel.formatSlug(brand),
                                isSelected: viewModel.selectedBrand == brand
                            ) {
                                withAnimation { viewModel.selectedBrand = brand }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    // MARK: - Shop The Look
    private var shopTheLookSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SHOP THE LOOK")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(1.5)
                        .foregroundColor(Color(.systemGray))

                    Text("Kitchen & Dining")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.primary)
                }

                Spacer()
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    NavigationLink(destination: ShopTheLookView(initialLook: .kitchen)) {
                        ZStack {
                            Image("kitchen_set")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 320, height: 220)
                                .clipped()

                            Color.black.opacity(0.18)

                            Text("EXPLORE KITCHEN")
                                .font(.system(size: 12, weight: .semibold))
                                .tracking(1.4)
                                .foregroundColor(.black)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 11)
                                .background(Color.white)
                                .cornerRadius(20)
                        }
                        .cornerRadius(20)
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: ShopTheLookView(initialLook: .dining)) {
                        ZStack {
                            Image("dining_set")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 320, height: 220)
                                .clipped()

                            Color.black.opacity(0.18)

                            Text("EXPLORE DINING")
                                .font(.system(size: 12, weight: .semibold))
                                .tracking(1.4)
                                .foregroundColor(.black)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 11)
                                .background(Color.white)
                                .cornerRadius(20)
                        }
                        .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
            }
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
                            onTap: { selectedProduct = product },
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
    let onShopNow: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background Image
            AsyncImage(url: banner.imageURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    Color(.systemGray5)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 140, maxHeight: 140)
            .clipped()
            
            // Gradient Overlay
            LinearGradient(
                colors: [Color.black.opacity(0.0), Color.black.opacity(0.75)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 80)
            .frame(maxHeight: .infinity, alignment: .bottom)

            // Content
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(banner.headline)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    Text(banner.subtext)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.9))
                }

                Spacer()
                
                Button(action: onShopNow) {
                    HStack(spacing: 5) {
                        Text("Shop now")
                            .font(.system(size: 13, weight: .bold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.1), radius: 3, y: 2)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(height: 140)
        .cornerRadius(20)
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
