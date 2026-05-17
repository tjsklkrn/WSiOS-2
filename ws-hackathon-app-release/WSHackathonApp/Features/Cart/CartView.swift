//
//  CartView.swift
//  WSHackathonApp
//

import SwiftUI

struct CartView: View {
    @StateObject private var viewModel = CartViewModel()
    @State private var isShowingCheckout = false
    @EnvironmentObject var cartRepository: CartRepository
    @EnvironmentObject var tabBarVM: WSTabBarViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGray6).ignoresSafeArea()

                if viewModel.isLoading && viewModel.items.isEmpty {
                    ProgressView()
                } else if viewModel.isEmptyCart {
                    EmptyCartView { tabBarVM.selectTab(.home) }
                } else {                    VStack(spacing: 0) {
                        ScrollView {
                            VStack(spacing: 20) {

                                // MARK: - Cart Items
                                cartItemsSection

                                // MARK: - Back-ordered warning
                                if viewModel.items.contains(where: { $0.backOrdered }) {
                                    backOrderedBanner
                                }

                                // MARK: - Bundles
                                if !viewModel.bundles.isEmpty {
                                    bundlesSection
                                }

                                // MARK: - Save For Later
                                if !viewModel.saveForLater.isEmpty {
                                    saveForLaterSection
                                }

                                // MARK: - Recommendations
                                recommendationsSection
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 120)
                        }

                        // MARK: - Checkout Bar
                        checkoutBar
                    }
                }
            }
            .navigationTitle(AppStrings.Cart.title)
            .task { await viewModel.loadCart() }
        }
        .onAppear {
            viewModel.bind(repository: cartRepository)
        }
        .fullScreenCover(isPresented: $isShowingCheckout) {
            CheckoutView(cartViewModel: viewModel, cartRepository: cartRepository)
                .environmentObject(tabBarVM)
        }
    }

    // MARK: - Cart Items Section

    private var cartItemsSection: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.items) { item in
                CartItemRow(
                    item: item,
                    onAdd: { viewModel.add(item) },
                    onRemove: { viewModel.removeItem(item) },
                    onDelete: { viewModel.deleteItem(item) }
                )
            }
        }
    }

    // MARK: - Back-ordered Banner

    private var backOrderedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.badge.exclamationmark")
                .foregroundColor(.orange)
            Text("Some items are back-ordered and will ship when available.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(10)
    }

    // MARK: - Bundles Section

    private var bundlesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Bundle & Save", systemImage: "tag.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)

            ForEach(viewModel.bundles) { bundle in
                BundleCard(bundle: bundle)
            }
        }
    }

    // MARK: - Save For Later Section

    private var saveForLaterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Save For Later", systemImage: "clock.arrow.circlepath")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)

            ForEach(viewModel.saveForLater) { item in
                SaveForLaterRow(item: item) {
                    viewModel.notifySaveForLater(productId: item.productId)
                }
            }
        }
    }

    // MARK: - Recommendations Section

    private var recommendationsSection: some View {
        Group {
            if viewModel.isLoadingRecommendations {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Finding recommendations…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else if !viewModel.recommendations.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label("You Might Also Like", systemImage: "sparkles")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(viewModel.recommendations) { rec in
                                RecommendationCard(item: rec)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    // MARK: - Checkout Bar

    private var checkoutBar: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                let totalItems = viewModel.items.reduce(0) { $0 + $1.quantity }
                
                HStack {
                    Text("Order Summary (\(totalItems) \(totalItems == 1 ? "item" : "items"))")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.black)
                    Spacer()
                }
                .padding(.bottom, 2)
                
                // Show up to 3 items, then a summary indicator
                let displayedItems = Array(viewModel.items.prefix(3))
                ForEach(displayedItems) { item in
                    HStack {
                        Text("\(item.quantity)x \(item.title)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.black)
                            .lineLimit(1)
                        Spacer()
                        Text("$\(item.price * Double(item.quantity), specifier: "%.2f")")
                            .font(.system(size: 12))
                            .foregroundColor(.black)
                    }
                }
                
                if viewModel.items.count > 3 {
                    Text("+ \(viewModel.items.count - 3) more items")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.top, 2)
                }
                
                Divider()
                    .padding(.vertical, 4)
                
                HStack {
                    Text(AppStrings.Cart.total)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black)
                    Spacer()
                    Text(viewModel.totalPriceText)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.black)
                }
            }
            .padding(.bottom, 4)

            Button(action: {
                isShowingCheckout = true
            }) {
                Text(AppStrings.Cart.checkoutButton)
                    .font(.system(size: 14, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: "#C11F1F")) // Williams-Sonoma Signature Crimson Red
                    .foregroundColor(.white)
                    .cornerRadius(4) // Flat rectangular CTA style
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color(.systemGray4), lineWidth: 0.7) // Crisp structural border
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
    }
}

// MARK: - Bundle Card

private struct BundleCard: View {
    let bundle: BundleItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(bundle.discountLabel)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
            HStack {
                Image(systemName: "tag")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(bundle.registryCategory)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.yellow.opacity(0.12))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.yellow.opacity(0.4), lineWidth: 1)
        )
    }
}

// MARK: - Save For Later Row

private struct SaveForLaterRow: View {
    let item: SaveForLaterItemResponse
    let onNotify: () -> Void

    @State private var notified = false

    var imageURL: URL? {
        let cleanPath = item.imagePath.hasPrefix("/") ? String(item.imagePath.dropFirst()) : item.imagePath
        return URL(string: AppConstants.API.imageBasePath + cleanPath)
    }

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                        .frame(width: 60, height: 60).clipped().cornerRadius(8)
                default:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(width: 60, height: 60)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(2)
                Text(item.price.formatted(.currency(code: "USD")))
                    .font(.system(size: 13, weight: .bold))
                Text("Currently unavailable")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: {
                onNotify()
                notified = true
            }) {
                Text(notified ? "Notified ✓" : "Notify Me")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(notified ? Color.green.opacity(0.15) : Color.black)
                    .foregroundColor(notified ? .green : .white)
                    .cornerRadius(8)
            }
            .disabled(notified)
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color(.systemGray5), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Recommendation Card

private struct RecommendationCard: View {
    let item: RecommendationItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Elegant scaled-to-fit container that shows the complete product shape without cropping
            AsyncImage(url: item.imageURL) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFit()
                        .frame(width: 120, height: 100)
                        .padding(6)
                default:
                    Color(.systemGray5)
                        .frame(width: 130, height: 112)
                }
            }
            .frame(width: 140, height: 112)
            .background(Color.white)
            .cornerRadius(10)
            .clipped()
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.black)
                    .lineLimit(2)
                    .frame(width: 124, alignment: .leading)

                Text(item.price.formatted(.currency(code: "USD")))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.black)

                if let context = item.context, !context.isEmpty {
                    Text(context.capitalized)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .frame(width: 140)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.04), lineWidth: 0.5)
        )
    }
}
