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
    let onAdd: () -> Void
    let onRemove: () -> Void
    let onAddToRegistry: () -> Void
    let onRemoveFromRegistry: () -> Void
    let onToggleWishlist: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // MARK: - Image Area
            ZStack(alignment: .topTrailing) {
                productImage

                // Heart / Wishlist button
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
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color(.systemGray4), lineWidth: 1)
        )
        .clipped()
    }

    // MARK: - Product Image
    @ViewBuilder
    private var productImage: some View {
        AsyncImage(url: product.imageURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .frame(height: 160)
                    .clipped()
            case .failure:
                imagePlaceholder
            default:
                ZStack {
                    Color(.systemGray5)
                    ProgressView()
                }
                .frame(height: 160)
            }
        }
        .frame(height: 160)
        .cornerRadius(16)
        .clipped()
    }

    private var imagePlaceholder: some View {
        ZStack {
            Color(.systemGray5)
            Image(systemName: "photo")
                .foregroundColor(Color(.systemGray3))
                .font(.system(size: 28))
        }
        .frame(height: 160)
        .cornerRadius(16)
    }
}
