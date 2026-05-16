//
//  ARExperienceView.swift
//  WSHackathonApp
//

import SwiftUI

struct ARExperienceView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ARViewModel()

    let productImageURL: URL?
    let productTitle: String

    var body: some View {
        ZStack {
            // AR Scene
            ARViewContainer(viewModel: viewModel)
                .ignoresSafeArea()

            // Top Controls Overlay
            VStack {
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .padding(14)
                            .background(.ultraThinMaterial, in: Circle())
                            .environment(\.colorScheme, .dark)
                    }

                    Spacer()

                    if viewModel.isModelPlaced {
                        Button(action: {
                            withAnimation {
                                viewModel.isModelPlaced = false
                            }
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.red)
                                .padding(14)
                                .background(.ultraThinMaterial, in: Circle())
                                .environment(\.colorScheme, .dark)
                        }
                    }
                }
                .padding()

                Spacer()

                // Bottom Instruction / Status
                if viewModel.isLoading {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(.white)
                        Text("Loading product image...")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .environment(\.colorScheme, .dark)
                    .padding(.bottom, 40)
                } else if !viewModel.isModelPlaced {
                    VStack(spacing: 8) {
                        Text(productTitle)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white.opacity(0.8))
                        Text("Tap on your table to place this product")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .environment(\.colorScheme, .dark)
                    .padding(.bottom, 40)
                }
            }
        }
        .task {
            // Download the product image as soon as the AR view appears
            if let url = productImageURL {
                await viewModel.downloadProductImage(from: url)
            }
        }
    }
}
