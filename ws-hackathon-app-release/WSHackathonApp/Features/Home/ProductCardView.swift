//
//  ProductCardView.swift
//  WSHackathonApp
//

import Foundation
import SwiftUI

struct ProductCardView: View {
    let product: ProductItem
    let quantity: Int
    let registryQuantity: Int
    let isWishlisted: Bool
    let onTap: () -> Void
    let onAdd: () -> Void
    let onRemove: () -> Void
    let onAddToRegistry: () -> Void
    let onRemoveFromRegistry: () -> Void
    let onToggleWishlist: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 0) {

                    // MARK: - Image Area
                    productImage

                    // MARK: - Info Area
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(product.price?.formatted(.currency(code: "USD")) ?? "")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                }
            }
            .buttonStyle(.plain)

            Button(action: onToggleWishlist) {
                Image(systemName: isWishlisted ? "heart.fill" : "heart")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isWishlisted ? .red : Color(.systemGray))
                    .frame(width: 32, height: 32)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
            }
            .padding(10)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color(.systemGray4), lineWidth: 1)
        )
    }

    // MARK: - Product Image
    @ViewBuilder
    private var productImage: some View {
        Color.clear
            .frame(maxWidth: .infinity, minHeight: 160, maxHeight: 160)
            .overlay(
                AsyncImage(url: product.imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        imagePlaceholder
                    default:
                        ZStack {
                            Color(.systemGray5)
                            ProgressView()
                        }
                    }
                }
            )
            .clipped()
            .cornerRadius(16, corners: [.topLeft, .topRight])
    }

    private var imagePlaceholder: some View {
        ZStack {
            Color(.systemGray5)
            Image(systemName: "photo")
                .foregroundColor(Color(.systemGray3))
                .font(.system(size: 28))
        }
    }
}

// MARK: - Selective corner radius helper

private extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

private struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
