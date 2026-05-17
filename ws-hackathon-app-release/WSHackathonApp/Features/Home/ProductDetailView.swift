//
//  ProductDetailView.swift
//  WSHackathonApp
//
//  Full product detail sheet — Williams-Sonoma inspired.
//

import SwiftUI

struct ProductDetailView: View {

    @StateObject private var viewModel: ProductDetailViewModel
    @EnvironmentObject var wishlistRepository: WishlistRepository
    @EnvironmentObject var cartRepository: CartRepository
    @EnvironmentObject var registryRepository: RegistryRepository
    @EnvironmentObject var tabBarVM: WSTabBarViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showShareSheet = false
    @State private var showAddedToCartOptions = false
    @State private var showSizePicker = false
    @State private var selectedFBProduct: ProductItem? = nil

    init(product: ProductItem) {
        _viewModel = StateObject(wrappedValue: ProductDetailViewModel(product: product))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        // MARK: - Hero Image
                        heroImage

                        // MARK: - Product Info Block
                        VStack(alignment: .leading, spacing: 0) {

                            // Title
                            Text(viewModel.product.title)
                                .font(.system(size: 20, weight: .light))
                                .foregroundColor(.black)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 20)
                                .padding(.top, 20)

                            // Rating Row
                            ratingRow
                                .padding(.horizontal, 20)
                                .padding(.top, 10)

                            // Price
                            VStack(alignment: .leading, spacing: 2) {
                                Text(viewModel.product.price?.formatted(.currency(code: "USD")) ?? "")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.black)
                                Text("Free Standard Shipping")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(white: 0.45))
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 14)

                            wsDivider.padding(.top, 20)

                            // MARK: - Tags Row
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    WSTag(label: "Ready To Ship")
                                    WSTag(label: "Best Seller")
                                    WSTag(label: "Free Shipping")
                                }
                                .padding(.horizontal, 20)
                            }
                            .padding(.vertical, 16)

                            wsDivider

                            // MARK: - Select Size
                            VStack(alignment: .leading, spacing: 10) {
                                Text("SELECT SIZE")
                                    .font(.system(size: 9, weight: .medium))
                                    .tracking(1.3)
                                    .foregroundColor(Color(white: 0.5))

                                Button {
                                    showSizePicker.toggle()
                                } label: {
                                    HStack {
                                        Text(viewModel.selectedSize?.label ?? "Select a size")
                                            .font(.system(size: 14))
                                            .foregroundColor(.black)
                                        Spacer()
                                        Image(systemName: showSizePicker ? "chevron.up" : "chevron.down")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(.black)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 13)
                                    .overlay(Rectangle().stroke(Color(white: 0.82), lineWidth: 1))
                                }

                                if showSizePicker {
                                    VStack(spacing: 0) {
                                        ForEach(viewModel.sizes) { size in
                                            Button {
                                                viewModel.selectedSize = size
                                                showSizePicker = false
                                            } label: {
                                                HStack {
                                                    Text(size.label)
                                                        .font(.system(size: 14))
                                                        .foregroundColor(.black)
                                                    Spacer()
                                                    if viewModel.selectedSize?.id == size.id {
                                                        Image(systemName: "checkmark")
                                                            .font(.system(size: 11, weight: .medium))
                                                            .foregroundColor(.black)
                                                    }
                                                }
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 14)
                                            }
                                            Rectangle()
                                                .fill(Color(white: 0.9))
                                                .frame(height: 1)
                                        }
                                    }
                                    .overlay(Rectangle().stroke(Color(white: 0.82), lineWidth: 1))
                                    .background(Color.white)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 18)

                            wsDivider

                            // MARK: - Select Color
                            VStack(alignment: .leading, spacing: 12) {
                                Text("SELECT COLOR\(viewModel.selectedColor != nil ? ": \(viewModel.selectedColor!.label.uppercased())" : "")")
                                    .font(.system(size: 9, weight: .medium))
                                    .tracking(1.3)
                                    .foregroundColor(Color(white: 0.5))

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(viewModel.colors) { color in
                                            colorSwatch(color)
                                        }
                                    }
                                }

                                Text("SKU: \(viewModel.product.id.prefix(7).uppercased())")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(white: 0.5))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 18)

                            wsDivider

                            // MARK: - Quantity
                            VStack(alignment: .leading, spacing: 10) {
                                Text("QUANTITY")
                                    .font(.system(size: 9, weight: .medium))
                                    .tracking(1.3)
                                    .foregroundColor(Color(white: 0.5))

                                HStack(spacing: 0) {
                                    Button(action: viewModel.decrementQuantity) {
                                        Image(systemName: "minus")
                                            .font(.system(size: 12, weight: .medium))
                                            .frame(width: 44, height: 44)
                                            .foregroundColor(.black)
                                    }
                                    Rectangle().fill(Color(white: 0.82)).frame(width: 1, height: 24)
                                    Text("\(viewModel.quantity)")
                                        .font(.system(size: 15, weight: .medium))
                                        .frame(width: 48, height: 44)
                                        .foregroundColor(.black)
                                    Rectangle().fill(Color(white: 0.82)).frame(width: 1, height: 24)
                                    Button(action: viewModel.incrementQuantity) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 12, weight: .medium))
                                            .frame(width: 44, height: 44)
                                            .foregroundColor(.black)
                                    }
                                }
                                .overlay(Rectangle().stroke(Color(white: 0.82), lineWidth: 1))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 18)

                            wsDivider

                            // MARK: - Delivery
                            VStack(alignment: .leading, spacing: 10) {
                                Text("DELIVERY & PICKUP")
                                    .font(.system(size: 9, weight: .medium))
                                    .tracking(1.3)
                                    .foregroundColor(Color(white: 0.5))

                                HStack(spacing: 14) {
                                    Image(systemName: "shippingbox")
                                        .font(.system(size: 18, weight: .light))
                                        .foregroundColor(.black)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Free Ship to Home")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.black)
                                        Text("May 18 – May 20 · Delivering to 10001")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color(white: 0.45))
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .overlay(Rectangle().stroke(Color(white: 0.82), lineWidth: 1))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 18)

                            wsDivider

                            // MARK: - Frequently Bought Together
                            frequentlyBoughtSection
                                .padding(.top, 24)

                            wsDivider.padding(.top, 16)

                            // MARK: - Reviews
                            reviewsSection
                                .padding(.top, 24)
                                .padding(.bottom, 100) // Bottom padding for sticky buttons
                        }
                    }
                }

                // MARK: - Sticky Bottom CTA
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color(white: 0.88))
                        .frame(height: 1)

                    VStack(spacing: 10) {
                        if showAddedToCartOptions {
                            HStack(spacing: 10) {
                                Button {
                                    showAddedToCartOptions = false
                                } label: {
                                    Text("CONTINUE SHOPPING")
                                        .font(.system(size: 11, weight: .medium))
                                        .tracking(1.0)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .foregroundColor(.black)
                                        .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
                                }
                                .buttonStyle(.plain)

                                Button {
                                    dismiss()
                                    tabBarVM.selectTab(.cart)
                                } label: {
                                    Text("VIEW BAG")
                                        .font(.system(size: 11, weight: .medium))
                                        .tracking(1.0)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(Color.black)
                                        .foregroundColor(.white)
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            HStack(spacing: 10) {
                                Button {
                                    viewModel.addToCart()
                                    withAnimation { showAddedToCartOptions = true }
                                } label: {
                                    Text("ADD TO BAG")
                                        .font(.system(size: 12, weight: .medium))
                                        .tracking(1.5)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 17)
                                        .background(Color.black)
                                        .foregroundColor(.white)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    viewModel.addToRegistry()
                                } label: {
                                    Text("ADD TO REGISTRY")
                                        .font(.system(size: 12, weight: .medium))
                                        .tracking(1.2)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 17)
                                        .foregroundColor(.black)
                                        .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.white)
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.black)
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button { showShareSheet = true } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15))
                            .foregroundColor(.black)
                    }
                    Button { viewModel.toggleWishlist() } label: {
                        Image(systemName: viewModel.isWishlisted ? "heart.fill" : "heart")
                            .font(.system(size: 15))
                            .foregroundColor(viewModel.isWishlisted ? Color(red: 0.64, green: 0.07, blue: 0.07) : .black)
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [viewModel.product.title])
            }
            .sheet(item: $selectedFBProduct) { product in
                ProductDetailView(product: product)
                    .environmentObject(wishlistRepository)
                    .environmentObject(cartRepository)
                    .environmentObject(registryRepository)
                    .environmentObject(tabBarVM)
            }
        }
        .onAppear {
            viewModel.bind(
                wishlistRepository: wishlistRepository,
                cartRepository: cartRepository,
                registryRepository: registryRepository
            )
        }
    }

    // MARK: - Hero Image
    private var heroImage: some View {
        AsyncImage(url: viewModel.product.imageURL) { phase in
            if let image = phase.image {
                image.resizable().scaledToFit()
                    .frame(maxWidth: .infinity)
                    .background(Color(white: 0.97))
            } else {
                Rectangle()
                    .fill(Color(white: 0.95))
                    .frame(maxWidth: .infinity, minHeight: 300)
                    .overlay(ProgressView().tint(.gray))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    // MARK: - Rating Row
    private var ratingRow: some View {
        HStack(spacing: 6) {
            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= Int(viewModel.averageRating.rounded()) ? "star.fill" : "star")
                        .font(.system(size: 11))
                        .foregroundColor(.black)
                }
            }
            NavigationLink {
                ReviewsSheet(reviews: viewModel.reviews, average: viewModel.averageRating)
            } label: {
                Text("Read Reviews")
                    .font(.system(size: 11))
                    .underline()
                    .foregroundColor(Color(white: 0.35))
            }
            Text("·")
                .foregroundColor(Color(white: 0.6))
            Text("Q & A")
                .font(.system(size: 11))
                .underline()
                .foregroundColor(Color(white: 0.35))
        }
    }

    // MARK: - Color Swatch
    private func colorSwatch(_ color: ColorOption) -> some View {
        let isSelected = viewModel.selectedColor?.id == color.id
        return Rectangle()
            .fill(Color(hex: color.hexColor))
            .frame(width: 40, height: 40)
            .overlay(
                Rectangle()
                    .stroke(isSelected ? Color.black : Color(white: 0.82), lineWidth: isSelected ? 2 : 1)
            )
            .padding(isSelected ? 2 : 0)
            .onTapGesture { viewModel.selectedColor = color }
            .animation(.easeInOut(duration: 0.12), value: isSelected)
    }

    // MARK: - Frequently Bought Together
    private var frequentlyBoughtSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("FREQUENTLY BOUGHT TOGETHER")
                .font(.system(size: 10, weight: .medium))
                .tracking(1.5)
                .foregroundColor(Color(white: 0.5))
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(viewModel.frequentlyBought) { product in
                        Button {
                            selectedFBProduct = product
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                AsyncImage(url: product.imageURL) { phase in
                                    if let image = phase.image {
                                        image.resizable().scaledToFill()
                                    } else {
                                        Rectangle().fill(Color(white: 0.93))
                                    }
                                }
                                .frame(width: 150, height: 150)
                                .clipped()

                                Text(product.title)
                                    .font(.system(size: 12))
                                    .foregroundColor(.black)
                                    .lineLimit(2)
                                    .frame(width: 150, alignment: .leading)

                                if let price = product.price, price > 0 {
                                    Text(price.formatted(.currency(code: "USD")))
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.black)
                                }
                            }
                            .frame(width: 150)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Reviews Section
    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("CUSTOMER REVIEWS")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1.5)
                    .foregroundColor(Color(white: 0.5))
                Spacer()
                NavigationLink(destination: ReviewsSheet(reviews: viewModel.reviews, average: viewModel.averageRating)) {
                    Text("See All")
                        .font(.system(size: 12))
                        .underline()
                        .foregroundColor(Color(white: 0.35))
                }
            }
            .padding(.horizontal, 20)

            ForEach(viewModel.reviews.prefix(2)) { review in
                WSReviewRow(review: review)
                    .padding(.horizontal, 20)
            }
        }
    }

    private var wsDivider: some View {
        Rectangle()
            .fill(Color(white: 0.9))
            .frame(height: 1)
            .padding(.horizontal, 16)
    }
}

// MARK: - Supporting Views

private struct WSTag: View {
    let label: String
    var body: some View {
        Text(label.uppercased())
            .font(.system(size: 9, weight: .medium))
            .tracking(0.8)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundColor(Color(white: 0.35))
            .overlay(Rectangle().stroke(Color(white: 0.82), lineWidth: 1))
    }
}

private struct WSReviewRow: View {
    let review: ProductReview
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { s in
                    Image(systemName: s <= review.rating ? "star.fill" : "star")
                        .font(.system(size: 10))
                        .foregroundColor(.black)
                }
                Spacer()
                Text(review.date)
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.5))
            }
            Text(review.author)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.black)
            Text(review.comment)
                .font(.system(size: 12))
                .foregroundColor(Color(white: 0.45))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 16)
        .overlay(
            Rectangle()
                .fill(Color(white: 0.9))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

private struct ReviewsSheet: View {
    let reviews: [ProductReview]
    let average: Double
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(reviews) { review in
                        WSReviewRow(review: review)
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.top, 16)
            }
        }
        .navigationTitle("Reviews (\(reviews.count))")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Color+Hex extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
