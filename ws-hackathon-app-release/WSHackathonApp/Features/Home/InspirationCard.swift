//
//  InspirationCard.swift
//  WSHackathonApp
//

import SwiftUI

struct InspirationCard: View {
    let product: ProductItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: product.imageURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                            .frame(width: 210, height: 290)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color(white: 0.93))
                            .frame(width: 210, height: 290)
                            .overlay(ProgressView().tint(.gray))
                    }
                }

                Image(systemName: "tag.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .padding(9)
                    .background(Color.black.opacity(0.55))
                    .clipShape(Circle())
                    .padding(12)
            }
        }
        .buttonStyle(.plain)
    }
}
