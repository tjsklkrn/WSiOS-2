import SwiftUI

struct HorizontalProductCard: View {
    let product: ProductItem
    let onTap: () -> Void

    init(product: ProductItem, onTap: @escaping () -> Void) {
        self.product = product
        self.onTap = onTap
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                AsyncImage(url: product.imageURL) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipped()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    } else if phase.error != nil {
                        ZStack {
                            Rectangle().fill(Color(.systemGray5))
                            Image(systemName: "photo").foregroundColor(.gray)
                        }
                        .frame(width: 100, height: 100)
                        .cornerRadius(8)
                    } else {
                        ZStack {
                            Rectangle().fill(Color(.systemGray5))
                            ProgressView()
                        }
                        .frame(width: 100, height: 100)
                        .cornerRadius(8)
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(product.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if let price = product.price?.formatted(.currency(code: "USD")) {
                        Text(price)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                }
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}


