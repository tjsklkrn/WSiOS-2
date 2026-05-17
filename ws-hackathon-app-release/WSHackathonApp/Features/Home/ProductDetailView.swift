//
//  ProductDetailView.swift
//  WSHackathonApp
//
//  Full product detail sheet — mirrors Williams-Sonoma product page.
//

import SwiftUI

struct ProductDetailView: View {

    @StateObject private var viewModel: ProductDetailViewModel
    @EnvironmentObject var wishlistRepository: WishlistRepository
    @EnvironmentObject var cartRepository: CartRepository
    @EnvironmentObject var registryRepository: RegistryRepository
    @EnvironmentObject var tabBarVM: WSTabBarViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showReviews  = false
    @State private var showShareSheet = false
    @State private var showAddedToCartOptions = false
    @State private var showSizePicker = false
    @State private var selectedFBProduct: ProductItem? = nil

    init(product: ProductItem) {
        _viewModel = StateObject(wrappedValue: ProductDetailViewModel(product: product))
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // MARK: - Hero Image
                    heroImage

                    VStack(alignment: .leading, spacing: 0) {

                        // MARK: - Title + Actions row
                        titleRow
                            .padding(.horizontal, 16)
                            .padding(.top, 16)

                        // MARK: - Rating Row
                        ratingRow
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                        // MARK: - Price
                        Text(viewModel.product.price?.formatted(.currency(code: "USD")) ?? "")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)

                        // Free shipping badge
                        Text("Free Shipping")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.top, 2)

                        Divider().padding(.horizontal, 16).padding(.vertical, 12)

                        // MARK: - Filter/Availability chips
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                FilterChip(label: "Ready To Ship")
                                FilterChip(label: "Best Seller")
                                FilterChip(label: "Free Shipping")
                            }
                            .padding(.horizontal, 16)
                        }

                        Divider().padding(.horizontal, 16).padding(.vertical, 12)

                        // MARK: - Select Size
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SELECT SIZE")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)

                            Button {
                                showSizePicker.toggle()
                            } label: {
                                HStack {
                                    Text(viewModel.selectedSize?.label ?? "Select a size")
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.primary)
                                        .font(.caption)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(4)
                            }
                        }
                        .padding(.horizontal, 16)

                        if showSizePicker {
                            VStack(spacing: 0) {
                                ForEach(viewModel.sizes) { size in
                                    Button {
                                        viewModel.selectedSize = size
                                        showSizePicker = false
                                    } label: {
                                        HStack {
                                            Text(size.label)
                                                .font(.subheadline)
                                                .foregroundColor(.primary)
                                            Spacer()
                                            if viewModel.selectedSize?.id == size.id {
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(.black)
                                                    .font(.caption)
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                    }
                                    Divider()
                                }
                            }
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .shadow(color: Color(.systemGray4), radius: 4, x: 0, y: 2)
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                        }

                        Divider().padding(.horizontal, 16).padding(.vertical, 12)

                        // MARK: - Select Color
                        VStack(alignment: .leading, spacing: 10) {
                            Text("SELECT COLOR: \(viewModel.selectedColor?.label.uppercased() ?? "")")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 16)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(viewModel.colors) { color in
                                        colorSwatch(color)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }

                            Text("SKU: \(viewModel.product.id.prefix(7).uppercased())")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 16)
                        }
                        .padding(.leading, 0)

                        Divider().padding(.horizontal, 16).padding(.vertical, 12)

                        // MARK: - Quantity Stepper
                        HStack(spacing: 20) {
                            Button(action: viewModel.decrementQuantity) {
                                Image(systemName: "minus")
                                    .font(.system(size: 14, weight: .medium))
                                    .frame(width: 32, height: 32)
                                    .background(Color(.systemGray5))
                                    .clipShape(Circle())
                            }
                            Text("\(viewModel.quantity)")
                                .font(.headline)
                                .frame(minWidth: 24)
                            Button(action: viewModel.incrementQuantity) {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .medium))
                                    .frame(width: 32, height: 32)
                                    .background(Color(.systemGray5))
                                    .clipShape(Circle())
                            }
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)

                        Divider().padding(.horizontal, 16).padding(.vertical, 12)

                        // MARK: - Delivery
                        VStack(alignment: .leading, spacing: 8) {
                            Text("DELIVERY & PICKUP OPTIONS")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)

                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color(.systemGray3), lineWidth: 1)
                                .frame(height: 64)
                                .overlay(
                                    VStack(spacing: 2) {
                                        Text("Free Ship to home")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        Text("May 18 – May 20")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                )

                            HStack {
                                Text("Delivering to ")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                + Text("10001")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .underline()
                            }
                        }
                        .padding(.horizontal, 16)

                        Divider().padding(.horizontal, 16).padding(.vertical, 12)

                        // MARK: - Add to Cart Button
                        if showAddedToCartOptions {
                            HStack(spacing: 12) {
                                Button(action: {
                                    showAddedToCartOptions = false
                                    dismiss()
                                }) {
                                    Text("Continue Shopping")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity)
                                        .padding(14)
                                        .background(Color.white)
                                        .foregroundColor(.black)
                                        .cornerRadius(4)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(Color.black, lineWidth: 1)
                                        )
                                }
                                
                                Button(action: {
                                    dismiss()
                                    tabBarVM.selectTab(.cart)
                                }) {
                                    Text("Go to Cart")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity)
                                        .padding(14)
                                        .background(Color.black)
                                        .foregroundColor(.white)
                                        .cornerRadius(4)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                        } else {
                            Button(action: {
                                viewModel.addToCart()
                                withAnimation {
                                    showAddedToCartOptions = true
                                }
                            }) {
                                Text(AppStrings.Home.addToCartButton)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(14)
                                    .background(Color(hex: "#C11F1F"))
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                        }

                        // MARK: - Add to Registry Button
                        Button(action: {
                            viewModel.addToRegistry()
                        }) {
                            Text(AppStrings.Home.addToRegistry)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(14)
                                .background(Color.white)
                                .foregroundColor(.black)
                                .cornerRadius(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.black, lineWidth: 1)
                                )
                        }
                        .padding(.horizontal, 16)

                        Divider().padding(.horizontal, 16).padding(.vertical, 16)

                        // MARK: - Frequently Bought Together
                        frequentlyBoughtSection

                        Divider().padding(.horizontal, 16).padding(.vertical, 12)

                        // MARK: - Reviews
                        reviewsSection

                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { showShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                    }
                    Button(action: { viewModel.toggleWishlist() }) {
                        Image(systemName: viewModel.isWishlisted ? "heart.fill" : "heart")
                            .font(.system(size: 16))
                            .foregroundColor(viewModel.isWishlisted ? .red : .primary)
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
            Task {
                await viewModel.fetchFrequentlyBought()
            }
        }
    }

    // MARK: - Hero Image

    private var heroImage: some View {
        AsyncImage(url: viewModel.product.imageURL) { phase in
            if let image = phase.image {
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
            } else if phase.error != nil {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(maxWidth: .infinity, minHeight: 260)
                    .overlay(Image(systemName: "photo").foregroundColor(.gray).font(.largeTitle))
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(maxWidth: .infinity, minHeight: 260)
                    .overlay(ProgressView())
            }
        }
        .frame(maxWidth: .infinity, minHeight: 260)
    }

    private var titleRow: some View {
        Text(viewModel.product.title)
            .font(.headline)
            .fontWeight(.semibold)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Rating Row

    private var ratingRow: some View {
        HStack(spacing: 8) {
            // Stars
            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= Int(viewModel.averageRating.rounded()) ? "star.fill" : "star")
                        .font(.system(size: 12))
                        .foregroundColor(.black)
                }
            }

            NavigationLink {
                ReviewsSheet(reviews: viewModel.reviews, average: viewModel.averageRating)
            } label: {
                Text("READ REVIEWS >")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }

            Text("Q & A >")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
    }

    // MARK: - Color Swatch

    private func colorSwatch(_ color: ColorOption) -> some View {
        let isSelected = viewModel.selectedColor?.id == color.id
        return RoundedRectangle(cornerRadius: 4)
            .fill(Color(hex: color.hexColor))
            .frame(width: 52, height: 36)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 2)
            )
            .onTapGesture { viewModel.selectedColor = color }
            .padding(isSelected ? 2 : 0)
            .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    // MARK: - Frequently Bought Together

    private var frequentlyBoughtSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Frequently Bought Together")
                .font(.headline)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(viewModel.frequentlyBought) { product in
                        HorizontalProductCard(product: product) {
                            selectedFBProduct = product
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Reviews Section

    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Customer Reviews")
                    .font(.headline)
                Spacer()
                NavigationLink("See All", destination: ReviewsSheet(reviews: viewModel.reviews, average: viewModel.averageRating))
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 16)

            ForEach(viewModel.reviews.prefix(2)) { review in
                ReviewRow(review: review)
                    .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - Supporting Views

private struct FilterChip: View {
    let label: String
    var body: some View {
        Text(label)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemGray5))
            .foregroundColor(.primary)
            .cornerRadius(16)
    }
}

private struct ReviewRow: View {
    let review: ProductReview
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { s in
                    Image(systemName: s <= review.rating ? "star.fill" : "star")
                        .font(.system(size: 11))
                        .foregroundColor(.black)
                }
                Spacer()
                Text(review.date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(review.author)
                .font(.caption)
                .fontWeight(.semibold)
            Text(review.comment)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Reviews Sheet

private struct ReviewsSheet: View {
    let reviews: [ProductReview]
    let average: Double
    @Environment(\.dismiss) var dismiss

    var body: some View {
        List(reviews) { review in
            ReviewRow(review: review)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .navigationTitle("Reviews (\(reviews.count))")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Share Sheet

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
