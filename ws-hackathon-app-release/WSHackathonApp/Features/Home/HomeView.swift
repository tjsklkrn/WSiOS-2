//
//  HomeView.swift
//  WSHackathonApp
//
//  Created by Nilesh Mahajan on 03/04/26.
//

import SwiftUI

// MARK: - Category Model

private struct WSCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
}

// MARK: - Product Grid Row Model

private enum ProductRow: Identifiable {
    case pair(ProductItem, ProductItem)
    case single(ProductItem)
    case featured(ProductItem)

    var id: String {
        switch self {
        case .pair(let a, let b): return "\(a.id)_\(b.id)_pair"
        case .single(let a):     return "\(a.id)_single"
        case .featured(let a):   return "\(a.id)_featured"
        }
    }
}

// MARK: - HomeView

struct HomeView: View {

    @StateObject private var viewModel = HomeViewModel()

    @EnvironmentObject var cartRepository: CartRepository
    @EnvironmentObject var registryRepository: RegistryRepository
    @EnvironmentObject var tabBarVM: WSTabBarViewModel
    @EnvironmentObject var wishlistRepository: WishlistRepository

    @State private var selectedProduct: ProductItem? = nil
    @State private var visibleProductCount: Int = 6
    @State private var selectedCategory: String = "All"

    // Williams-Sonoma style categories
    private let categories: [WSCategory] = [
        WSCategory(name: "All",         icon: "square.grid.2x2"),
        WSCategory(name: "Cookware",    icon: "frying.pan"),
        WSCategory(name: "Knives",      icon: "scissors"),
        WSCategory(name: "Bakeware",    icon: "birthday.cake"),
        WSCategory(name: "Electrics",   icon: "bolt.circle"),
        WSCategory(name: "Tabletop",    icon: "fork.knife"),
        WSCategory(name: "Bar & Wine",  icon: "wineglass"),
        WSCategory(name: "Storage",     icon: "cabinet"),
        WSCategory(name: "Sale",        icon: "tag"),
    ]

    private var productRows: [ProductRow] {
        let slice = Array(viewModel.filteredProducts.prefix(visibleProductCount))
        return makeRows(slice)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView().tint(.black)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {

                            // MARK: - Custom Large Title (scrolls with content)
                            Text("Home")
                                .font(.system(size: 34, weight: .light))
                                .foregroundColor(.black)
                                .padding(.horizontal, 20)
                                .padding(.top, 16)
                                .padding(.bottom, 14)

                            // MARK: - Search Bar
                            searchBar
                                .padding(.horizontal, 16)
                                .padding(.bottom, 20)

                            // MARK: - Categories
                            categoryStrip
                                .padding(.bottom, 4)

                            // Thin divider below categories
                            Rectangle()
                                .fill(Color(white: 0.9))
                                .frame(height: 1)
                                .padding(.bottom, 2)

                            // MARK: - Product Grid
                            LazyVStack(spacing: 0) {
                                productGrid
                            }

                            // MARK: - Load More
                            if viewModel.filteredProducts.count > visibleProductCount {
                                loadMoreButton
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 24)
                            }

                            // MARK: - Find Your Inspiration
                            if !viewModel.filteredProducts.isEmpty {
                                WSInspirationSection(
                                    products: Array(viewModel.filteredProducts.suffix(6)),
                                    onTap: { product in
                                        viewModel.recordView(product)
                                        selectedProduct = product
                                    }
                                )
                                .padding(.top, 8)
                            }

                            // MARK: - Shop By Room
                            WSShopByRoomSection()

                            // MARK: - Recently Viewed
                            if !viewModel.recentlyViewed.isEmpty {
                                WSHorizontalProductSection(
                                    title: "RECENTLY VIEWED",
                                    products: viewModel.recentlyViewed,
                                    onTap: { product in
                                        viewModel.recordView(product)
                                        selectedProduct = product
                                    }
                                )
                            }

                            Spacer(minLength: 40)
                        }
                    }
                }
            }
            // Empty inline title = no text collapses into nav bar on scroll
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    NavigationLink(destination:
                        WishlistView()
                            .environmentObject(wishlistRepository)
                            .environmentObject(cartRepository)
                    ) {
                        Image(systemName: wishlistRepository.items.isEmpty ? "heart" : "heart.fill")
                            .font(.system(size: 18))
                            .foregroundColor(wishlistRepository.items.isEmpty
                                ? .black
                                : Color(red: 0.64, green: 0.07, blue: 0.07))
                    }

                    NavigationLink(destination: ProfileView()) {
                        Image(systemName: "person")
                            .font(.system(size: 18))
                            .foregroundColor(.black)
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

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(Color(white: 0.5))
            TextField(AppStrings.Home.searchPlaceHolder, text: $viewModel.searchText)
                .font(.system(size: 14))
                .foregroundColor(.black)
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(white: 0.6))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .overlay(Rectangle().stroke(Color(white: 0.82), lineWidth: 1))
    }

    // MARK: - Category Strip

    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(categories) { category in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedCategory = category.name
                        }
                    } label: {
                        VStack(spacing: 10) {
                            // Icon circle
                            ZStack {
                                Circle()
                                    .fill(selectedCategory == category.name
                                          ? Color.black
                                          : Color(white: 0.96))
                                    .frame(width: 52, height: 52)
                                Image(systemName: category.icon)
                                    .font(.system(size: 20, weight: .light))
                                    .foregroundColor(selectedCategory == category.name
                                                     ? .white
                                                     : Color(white: 0.3))
                            }

                            // Label
                            Text(category.name)
                                .font(.system(size: 10, weight: selectedCategory == category.name ? .medium : .regular))
                                .foregroundColor(selectedCategory == category.name ? .black : Color(white: 0.45))
                                .lineLimit(1)
                        }
                        .frame(width: 72)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
        }
    }

    // MARK: - Product Grid

    @ViewBuilder
    private var productGrid: some View {
        ForEach(productRows) { row in
            rowView(for: row)
        }
    }

    @ViewBuilder
    private func rowView(for row: ProductRow) -> some View {
        switch row {
        case .pair(let a, let b):
            HStack(spacing: 2) {
                cardView(product: a, isFullWidth: false)
                cardView(product: b, isFullWidth: false)
            }

        case .single(let a):
            HStack(spacing: 2) {
                cardView(product: a, isFullWidth: false)
                Color(white: 0.95)
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
            }

        case .featured(let a):
            cardView(product: a, isFullWidth: true)
        }
    }

    private func cardView(product: ProductItem, isFullWidth: Bool) -> some View {
        ImmersiveProductCard(
            product: product,
            isWishlisted: viewModel.isWishlisted(product),
            onToggleWishlist: { viewModel.toggleWishlist(product) },
            onTap: {
                viewModel.recordView(product)
                selectedProduct = product
            },
            isFullWidth: isFullWidth
        )
    }

    // MARK: - Load More

    private var loadMoreButton: some View {
        Button {
            visibleProductCount += 6
        } label: {
            Text("LOAD MORE")
                .font(.system(size: 12, weight: .medium))
                .tracking(1.2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundColor(.black)
                .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Row Builder

    private func makeRows(_ products: [ProductItem]) -> [ProductRow] {
        var rows: [ProductRow] = []
        var i = 0
        while i < products.count {
            // Pair row (2 items side by side)
            if i + 1 < products.count {
                rows.append(.pair(products[i], products[i + 1]))
            } else {
                rows.append(.single(products[i]))
            }
            i += 2

            // Featured full-width row (1 item)
            if i < products.count {
                rows.append(.featured(products[i]))
                i += 1
            }
        }
        return rows
    }
}

// MARK: - WS Inspiration Section

struct WSInspirationSection: View {
    let products: [ProductItem]
    let onTap: (ProductItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            Rectangle()
                .fill(Color(white: 0.88))
                .frame(height: 1)
                .padding(.horizontal, 16)
                .padding(.bottom, 24)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MORE TO DISCOVER")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(1.5)
                        .foregroundColor(Color(white: 0.5))
                    Text("Find Your Inspiration")
                        .font(.system(size: 22, weight: .light))
                        .foregroundColor(.black)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(products) { product in
                        Button {
                            onTap(product)
                        } label: {
                            ZStack(alignment: .bottomTrailing) {
                                AsyncImage(url: product.imageURL) { phase in
                                    if let image = phase.image {
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 210, height: 290)
                                            .clipped()
                                    } else {
                                        Rectangle()
                                            .fill(Color(white: 0.93))
                                            .frame(width: 210, height: 290)
                                            .overlay(ProgressView().tint(.gray))
                                    }
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(product.title)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    if let price = product.price, price > 0 {
                                        Text(price.formatted(.currency(code: "USD")))
                                            .font(.system(size: 11))
                                            .foregroundColor(.white.opacity(0.85))
                                    }
                                }
                                .padding(12)
                                .frame(width: 210, alignment: .leading)
                                .background(
                                    LinearGradient(
                                        colors: [.clear, .black.opacity(0.5)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }

            Button { } label: {
                Text("SHOP ALL")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(1.5)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundColor(.black)
                    .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 32)
            .buttonStyle(.plain)
        }
    }
}

// MARK: - WS Horizontal Product Section

struct WSHorizontalProductSection: View {
    let title: String
    let products: [ProductItem]
    let onTap: (ProductItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(Color(white: 0.88))
                .frame(height: 1)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)

            Text(title)
                .font(.system(size: 10, weight: .medium))
                .tracking(1.5)
                .foregroundColor(Color(white: 0.5))
                .padding(.horizontal, 16)
                .padding(.bottom, 14)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(products) { product in
                        Button {
                            onTap(product)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                AsyncImage(url: product.imageURL) { phase in
                                    if let image = phase.image {
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 160, height: 160)
                                            .clipped()
                                    } else {
                                        Rectangle()
                                            .fill(Color(white: 0.93))
                                            .frame(width: 160, height: 160)
                                    }
                                }

                                Text(product.title)
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(.black)
                                    .lineLimit(2)
                                    .frame(width: 160, alignment: .leading)

                                if let price = product.price, price > 0 {
                                    Text(price.formatted(.currency(code: "USD")))
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.black)
                                }
                            }
                            .frame(width: 160)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 28)
    }
}

// MARK: - Legacy HorizontalProductCard

struct HorizontalProductCard: View {
    let product: ProductItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                AsyncImage(url: product.imageURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Rectangle().fill(Color(white: 0.93))
                    }
                }
                .frame(width: 160, height: 160)
                .clipped()

                Text(product.title)
                    .font(.system(size: 12))
                    .foregroundColor(.black)
                    .lineLimit(2)
                    .frame(width: 160, alignment: .leading)

                if let price = product.price, price > 0 {
                    Text(price.formatted(.currency(code: "USD")))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.black)
                }
            }
            .frame(width: 160)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - WS Shop By Room Section

struct WSShopByRoomSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(Color(white: 0.88))
                .frame(height: 1)
                .padding(.horizontal, 16)
                .padding(.bottom, 24)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SHOP THE LOOK")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(1.5)
                        .foregroundColor(Color(white: 0.5))
                    Text("Kitchen")
                        .font(.system(size: 22, weight: .light))
                        .foregroundColor(.black)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)

            NavigationLink(destination: ShopTheLookView()) {
                ZStack(alignment: .center) {
                    Image("kitchen_set")
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 240)
                        .clipped()
                        
                    Color.black.opacity(0.15)
                    
                    Text("EXPLORE KITCHEN")
                        .font(.system(size: 12, weight: .medium))
                        .tracking(2.0)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .foregroundColor(.black)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 32)
    }
}
