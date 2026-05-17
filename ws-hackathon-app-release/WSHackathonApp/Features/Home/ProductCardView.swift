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

    // Deterministic badge
    private var badgeText: String? {
        let hash = abs(product.id.hashValue)
        let options: [String?] = ["BEST SELLER", "NEW", nil, nil, nil, nil]
        return options[hash % options.count]
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {

                // MARK: - Image Zone
                ZStack(alignment: .topLeading) {
                    GeometryReader { geo in
                        AsyncImage(url: product.imageURL) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: geo.size.width, height: 200)
                                    .clipped()
                            } else {
                                Rectangle()
                                    .fill(Color(white: 0.93))
                                    .frame(width: geo.size.width, height: 200)
                                    .overlay(ProgressView().tint(.gray))
                            }
                        }
                    }
                    .frame(height: 200)

                    // Badge
                    if let badge = badgeText {
                        Text(badge)
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.8)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black)
                            .foregroundColor(.white)
                    }

                    // Wishlist
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: onToggleWishlist) {
                                Image(systemName: isWishlisted ? "heart.fill" : "heart")
                                    .font(.system(size: 16))
                                    .foregroundColor(isWishlisted ? Color(red: 0.64, green: 0.07, blue: 0.07) : Color(white: 0.3))
                                    .padding(10)
                                    .background(Color.white.opacity(0.9))
                            }
                        }
                        Spacer()
                    }
                    .frame(height: 200)
                }

                // MARK: - Text Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.title)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.black)
                        .lineLimit(2)

                    if let price = product.price, price > 0 {
                        Text(price.formatted(.currency(code: "USD")))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.black)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Helpers

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
