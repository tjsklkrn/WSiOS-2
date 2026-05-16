//
//  ProductCardView.swift
//  WSHackathonApp
//
//  Created by Nilesh Mahajan on 03/04/26.
//

import Foundation
import SwiftUI

struct ProductCardView: View {
    let product: ProductItem
    let isWishlisted: Bool
    let onToggleWishlist: () -> Void
    let onTap: () -> Void

    // Best-seller badge (mocked; production would come from API)
    private var isBestSeller: Bool { true }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {

                // MARK: - Image + Overlay Badges
                GeometryReader { geo in
                    ZStack(alignment: .topLeading) {
                        AsyncImage(url: product.imageURL) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: geo.size.width, height: 150)
                                    .clipped()
                                    .cornerRadius(8)
                            } else if phase.error != nil {
                                ZStack {
                                    Color(.systemGray5)
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 30))
                                }
                                .frame(width: geo.size.width, height: 150)
                                .cornerRadius(8)
                            } else {
                                ZStack {
                                    Color(.systemGray5)
                                    ProgressView()
                                }
                                .frame(width: geo.size.width, height: 150)
                                .cornerRadius(8)
                            }
                        }

                        // "Best Seller" badge (top-left)
                        if isBestSeller {
                            Text("Best Seller")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.black)
                                .cornerRadius(4, corners: [.topLeft, .bottomRight])
                        }

                        // Wishlist heart (top-right)
                        VStack {
                            HStack {
                                Spacer()
                                Button(action: onToggleWishlist) {
                                    Image(systemName: isWishlisted ? "heart.fill" : "heart")
                                        .font(.system(size: 18))
                                        .foregroundColor(isWishlisted ? .red : .white)
                                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                }
                                .padding(8)
                            }
                            Spacer()
                        }
                        .frame(width: geo.size.width, height: 150)
                    }
                }
                .frame(height: 150)

                // MARK: - Product Title
                Text(product.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .foregroundColor(.primary)

                // MARK: - Suggested Price
                if let price = product.price, price > 0 {
                    Text("Sugg. Price \(price.suggestedPrice.formatted(.currency(code: "USD")))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // MARK: - Our Price
                HStack(spacing: 4) {
                    Text("Our Price")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text(product.price?.formatted(.currency(code: "USD")) ?? "")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(Color(red: 0.7, green: 0.1, blue: 0.1))
                }

                Text("Free Shipping")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(10)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color(.systemGray4), radius: 2, x: 0, y: 1)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Helpers

private extension Double {
    /// Returns a slightly inflated "suggested" price for display purposes
    var suggestedPrice: Double { self * 1.3 }
}

/// Rounded corners on specific corners only
private extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

private struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
