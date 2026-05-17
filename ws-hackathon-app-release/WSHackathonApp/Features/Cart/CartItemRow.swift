//
//  CartItemRow.swift
//  WSHackathonApp
//

import SwiftUI

struct CartItemRow: View {
    let item: CartItem
    let onAdd: () -> Void
    let onRemove: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // MARK: - Product Image (Square with clean thin border)
            CustomAsyncImage(url: item.imageURL)
                .frame(width: 84, height: 84)
                .clipped()
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                )

            // MARK: - Product Details Stack
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.system(size: 13, weight: .bold)) // Modern bold sans-serif title
                    .foregroundColor(.black)
                    .lineLimit(2)

                // Clean Pricing: display "each" pricing only if quantity > 1
                if item.quantity > 1 {
                    Text("$\(item.price, specifier: "%.2f") each")
                        .font(.system(size: 11))
                        .foregroundColor(Color(.systemGray))
                } else {
                    Text("$\(item.price, specifier: "%.2f")")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.black)
                }

                Spacer(minLength: 6)

                // MARK: - Stepper controls
                HStack(spacing: 12) {
                    Button(action: onRemove) {
                        Image(systemName: "minus")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 26, height: 26)
                            .background(Color(.systemGray6))
                            .foregroundColor(.black)
                            .cornerRadius(2)
                    }

                    Text("\(item.quantity)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.black)

                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 26, height: 26)
                            .background(Color(.systemGray6))
                            .foregroundColor(.black)
                            .cornerRadius(2)
                    }
                }
            }

            Spacer()

            // MARK: - Subtotal (when qty > 1) & Deletion Action
            VStack(alignment: .trailing, spacing: 14) {
                if item.quantity > 1 {
                    Text("$\(item.price * Double(item.quantity), specifier: "%.2f")")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.black)
                }

                Spacer()

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(hex: "#C11F1F")) // Signature red trash bin
                        .frame(width: 26, height: 26)
                        .background(Color(hex: "#C11F1F").opacity(0.06))
                        .cornerRadius(2)
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(4) // W-S signature rectangular format
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color(.systemGray4), lineWidth: 0.7) // Flat crisp border
        )
    }
}
