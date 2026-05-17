//
//  CartView.swift
//  WSHackathonApp
//

import SwiftUI

struct CartView: View {
    @StateObject private var viewModel = CartViewModel()
    @EnvironmentObject var cartRepository: CartRepository
    @EnvironmentObject var tabBarVM: WSTabBarViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGray6).ignoresSafeArea()

                if viewModel.isLoading && viewModel.items.isEmpty {
                    ProgressView()
                } else if viewModel.isEmptyCart {
                    VStack {
                        EmptyCartView { tabBarVM.selectTab(.home) }
                        Spacer()
                    }
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
            HStack {
                Text(AppStrings.Cart.total)
                    .font(.headline)
                Spacer()
                Text(viewModel.totalPriceText)
                    .font(.headline)
                    .fontWeight(.bold)
            }

            Button(action: {
                viewModel.checkout()
            }) {
                Text(AppStrings.Cart.checkoutButton)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color(.systemGray4), radius: 4, x: 0, y: -2)
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
            AsyncImage(url: item.imageURL) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                        .frame(width: 130, height: 110)
                        .clipped()
                default:
                    Color(.systemGray5)
                        .frame(width: 130, height: 110)
                }
            }
            .frame(width: 130, height: 110)
            .cornerRadius(10)
            .clipped()

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(2)
                    .frame(width: 130, alignment: .leading)

                Text(item.price.formatted(.currency(code: "USD")))
                    .font(.system(size: 12, weight: .bold))

                if let context = item.context, !context.isEmpty {
                    Text(context)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
        .frame(width: 130)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color(.systemGray4), radius: 3, x: 0, y: 1)
    }
}
