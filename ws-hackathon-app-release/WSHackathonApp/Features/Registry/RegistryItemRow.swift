//
//  RegistryItemRow.swift
//  WSHackathonApp
//
//  Created by Nilesh Mahajan on 06/04/26.
//
import SwiftUI

struct RegistryItemRow: View {

    @StateObject private var viewModel: RegistryItemRowViewModel

    init(viewModel: RegistryItemRowViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {

            // Image
            CustomAsyncImage(url: viewModel.imageURL)
                .frame(width: 88, height: 88)
                .clipped()

            // Info
            VStack(alignment: .leading, spacing: 5) {
                Text(viewModel.title)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.black)
                    .lineLimit(2)

                Text(viewModel.priceText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.black)

                // Quantity stepper
                HStack(spacing: 0) {
                    Button(action: viewModel.decreaseQty) {
                        Image(systemName: "minus")
                            .font(.system(size: 10, weight: .medium))
                            .frame(width: 28, height: 28)
                            .foregroundColor(.black)
                    }
                    Rectangle()
                        .fill(Color(white: 0.85))
                        .frame(width: 1, height: 18)
                    Text(viewModel.quantityText)
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 32, height: 28)
                        .foregroundColor(.black)
                    Rectangle()
                        .fill(Color(white: 0.85))
                        .frame(width: 1, height: 18)
                    Button(action: viewModel.increaseQty) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .medium))
                            .frame(width: 28, height: 28)
                            .foregroundColor(.black)
                    }
                }
                .overlay(Rectangle().stroke(Color(white: 0.82), lineWidth: 1))
                .padding(.top, 4)
            }

            Spacer()

            // Actions
            VStack(alignment: .trailing, spacing: 12) {
                Button(action: viewModel.removeItem) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(white: 0.5))
                }
                Spacer()
                Button(action: viewModel.addToCart) {
                    Text("ADD TO BAG")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(0.8)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.black)
                        .foregroundColor(.white)
                }
            }
        }
        .padding(16)
    }
}
