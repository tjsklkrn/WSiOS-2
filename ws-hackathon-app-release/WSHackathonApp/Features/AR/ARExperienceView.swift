//
//  ARExperienceView.swift
//  WSHackathonApp
//

import SwiftUI

struct ARExperienceView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ARViewModel()
    
    let initialProductName: String
    
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
                
                // Bottom Product Selector Overlay
                if viewModel.isModelPlaced {
                    ProductSelectorOverlay(viewModel: viewModel)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    Text("Point your camera at a flat surface and tap to place")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial, in: Capsule())
                        .environment(\.colorScheme, .dark)
                        .padding(.bottom, 40)
                }
            }
            
            // Loading Overlay
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                    .padding(24)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .environment(\.colorScheme, .dark)
            }
        }
        .onAppear {
            let normalized = initialProductName.lowercased()
            if normalized.contains("plate") {
                viewModel.selectedModelName = "plate"
            } else if normalized.contains("bowl") {
                viewModel.selectedModelName = "bowl"
            } else if normalized.contains("mug") {
                viewModel.selectedModelName = "mug"
            } else if normalized.contains("cup") {
                viewModel.selectedModelName = "cupset"
            } else {
                viewModel.selectedModelName = "plate"
            }
        }
    }
}

// MARK: - Product Selector Overlay

struct ProductSelectorOverlay: View {
    @ObservedObject var viewModel: ARViewModel
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(viewModel.availableProducts, id: \.0) { product in
                    Button(action: {
                        withAnimation {
                            viewModel.selectedModelName = product.0
                        }
                        let generator = UISelectionFeedbackGenerator()
                        generator.selectionChanged()
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: iconName(for: product.0))
                                .font(.system(size: 24))
                                .foregroundColor(viewModel.selectedModelName == product.0 ? .black : .white)
                            
                            Text(product.1)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(viewModel.selectedModelName == product.0 ? .black : .white)
                        }
                        .frame(width: 80, height: 80)
                        .background(
                            viewModel.selectedModelName == product.0
                                ? Color.white
                                : Color.clear
                        )
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(
            LinearGradient(
                colors: [.black.opacity(0.6), .clear],
                startPoint: .bottom,
                endPoint: .top
            )
        )
    }
    
    private func iconName(for id: String) -> String {
        switch id {
        case "plate": return "circle"
        case "bowl": return "lanyardcard.fill" // generic approx
        case "mug": return "mug.fill"
        case "cupset": return "cup.and.saucer.fill"
        default: return "square"
        }
    }
}
