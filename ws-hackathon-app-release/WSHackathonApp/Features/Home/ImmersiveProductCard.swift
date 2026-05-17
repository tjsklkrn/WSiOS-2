//
//  ImmersiveProductCard.swift
//  WSHackathonApp
//

import SwiftUI

struct ImmersiveProductCard: View {
    let product: ProductItem
    let isWishlisted: Bool
    let onToggleWishlist: () -> Void
    let onTap: () -> Void
    let isFullWidth: Bool

    // Deterministic badge — never changes on tap/scroll
    private var badgeText: String? {
        let options: [String?] = ["BEST SELLER", "NEW", nil, nil, nil, nil]
        return options[abs(product.id.hashValue) % options.count]
    }

    var body: some View {
        let cardHeight: CGFloat = isFullWidth ? 320 : 220

        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {

                // MARK: - Image
                AsyncImage(url: product.imageURL) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color(white: 0.93)
                            .overlay(ProgressView().tint(.gray))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // MARK: - Gradient
                LinearGradient(
                    colors: [.clear, .black.opacity(0.55)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                // MARK: - Title + Price
                VStack(alignment: .leading, spacing: 3) {
                    Text(product.title)
                        .font(.system(size: isFullWidth ? 16 : 13, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .tracking(0.2)

                    if let price = product.price, price > 0 {
                        Text(price.formatted(.currency(code: "USD")))
                            .font(.system(size: isFullWidth ? 14 : 12, weight: .regular))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
                .padding(.horizontal, isFullWidth ? 18 : 12)
                .padding(.bottom, isFullWidth ? 18 : 12)

                // MARK: - Badge + Wishlist (top)
                VStack {
                    HStack(alignment: .top) {
                        if let badge = badgeText {
                            Text(badge)
                                .font(.system(size: 9, weight: .bold))
                                .tracking(0.8)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black)
                                .foregroundColor(.white)
                        }
                        Spacer()
                        Button(action: onToggleWishlist) {
                            Image(systemName: isWishlisted ? "heart.fill" : "heart")
                                .font(.system(size: 17))
                                .foregroundColor(isWishlisted
                                    ? Color(red: 0.64, green: 0.07, blue: 0.07)
                                    : .white)
                                .shadow(color: .black.opacity(0.25), radius: 2)
                        }
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(12)
            }
            // Explicit frame on the ZStack so all layers are constrained
            .frame(maxWidth: .infinity)
            .frame(height: cardHeight)
            .background(Color(white: 0.93))
            .clipped()
        }
        .buttonStyle(.plain)
    }
}
