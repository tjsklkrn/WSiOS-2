//
//  CartItemRow.swift
//  WSHackathonApp
//
//  Created by Nilesh Mahajan on 06/04/26.
//
//  NOTE: This component is superseded by WSCartItemRow inside CartView.swift.
//  Kept for backwards compatibility only.
//

import SwiftUI

struct CartItemRow: View {

    let item: CartItem
    let onAdd: () -> Void
    let onRemove: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            AsyncImage(url: item.imageURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Rectangle().fill(Color(white: 0.93))
                }
            }
            .frame(width: 90, height: 90)
            .clipped()

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.black)
                    .lineLimit(2)

                Text("$\(item.price, specifier: "%.2f")")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.black)

                HStack(spacing: 0) {
                    Button(action: onRemove) {
                        Image(systemName: "minus")
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 32, height: 32)
                            .foregroundColor(.black)
                    }
                    Rectangle().fill(Color(white: 0.85)).frame(width: 1, height: 20)
                    Text("\(item.quantity)")
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 36, height: 32)
                        .foregroundColor(.black)
                    Rectangle().fill(Color(white: 0.85)).frame(width: 1, height: 20)
                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 32, height: 32)
                            .foregroundColor(.black)
                    }
                }
                .overlay(Rectangle().stroke(Color(white: 0.82), lineWidth: 1))
                .padding(.top, 4)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(white: 0.5))
                }
                Spacer()
                Text("$\(item.price * Double(item.quantity), specifier: "%.2f")")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.black)
            }
        }
        .padding(16)
    }
}
