//
//  CartItemRow.swift
//  WSHackathonApp
//
//  Created by Nilesh Mahajan on 06/04/26.
//

import SwiftUI

struct CartItemRow: View {
    
    let item: CartItem
    let onAdd: () -> Void
    let onDecrease: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            let url = item.imageURL
            // MARK: - Image
            CustomAsyncImage(url: url)
                .frame(width: 80, height: 80)
                .cornerRadius(8)
                .clipped()
            
            // MARK: - Info
            VStack(alignment: .leading, spacing: 6) {
                
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                
                Text("$\(item.price, specifier: "%.2f")")
                    .font(.subheadline)
                    .foregroundColor(.black)
                
                Spacer()
                
                // MARK: - Quantity Controls
                HStack(spacing: 12) {
                    Button(action: onDecrease) {
                        Image(systemName: "minus.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .disabled(item.quantity <= 1)
                    .opacity(item.quantity <= 1 ? 0.3 : 1.0)
                    
                    Text("\(item.quantity)")
                        .fontWeight(.medium)
                    
                    Button(action: onAdd) {
                        Image(systemName: "plus.circle.fill")
                    }
                    .buttonStyle(.borderless)
                }
                .font(.title3)
                .foregroundColor(.black)
            }
            
            Spacer()
            
            // MARK: - Delete & Total Price
            VStack(alignment: .trailing) {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(Color(.systemRed))
                        .padding(8)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
                .buttonStyle(.borderless)
                
                Spacer()
                
                Text("$\(item.price * Double(item.quantity), specifier: "%.2f")")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color(.systemGray4), radius: 2, x: 0, y: 1)
    }
}
