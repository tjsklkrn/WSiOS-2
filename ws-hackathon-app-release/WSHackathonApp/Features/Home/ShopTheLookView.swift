//
//  ShopTheLookView.swift
//  WSHackathonApp
//
//  Created by Nilesh Mahajan on 07/04/26.
//

import SwiftUI

struct Hotspot: Identifiable {
    let id = UUID()
    let xOffset: CGFloat
    let yOffset: CGFloat
    let product: ProductItem
}

struct ShopTheLookView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var wishlistRepository: WishlistRepository
    @EnvironmentObject var cartRepository: CartRepository
    @EnvironmentObject var registryRepository: RegistryRepository
    @EnvironmentObject var tabBarVM: WSTabBarViewModel

    let hotspots: [Hotspot] = [
        Hotspot(
            xOffset: 0.45,
            yOffset: 0.48,
            product: ProductItem(id: "hotspot_espresso", title: "Breville Barista Pro Espresso Machine", price: 849.95, path: nil)
        ),
        Hotspot(
            xOffset: 0.65,
            yOffset: 0.52,
            product: ProductItem(id: "hotspot_mixer", title: "KitchenAid Artisan Stand Mixer", price: 449.95, path: nil)
        )
    ]

    @State private var selectedHotspot: UUID? = nil
    @State private var productToOpen: ProductItem? = nil

    var body: some View {
        ZStack(alignment: .top) {
            Color.white.ignoresSafeArea()

            // Main Image with Hotspots
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    Image("kitchen_set")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedHotspot = nil
                            }
                        }

                    // Draw Hotspots
                    ForEach(hotspots) { hotspot in
                        let xPos = geo.size.width * hotspot.xOffset
                        let yPos = geo.size.height * hotspot.yOffset

                        ZStack {
                            // The pulse ring
                            Circle()
                                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                                .frame(width: 32, height: 32)
                                .scaleEffect(selectedHotspot == hotspot.id ? 1.5 : 1.0)
                                .opacity(selectedHotspot == hotspot.id ? 0.0 : 1.0)
                                .animation(Animation.easeOut(duration: 1.5).repeatForever(autoreverses: false), value: selectedHotspot == hotspot.id)

                            // The main dot
                            Circle()
                                .fill(Color.white)
                                .frame(width: 14, height: 14)
                                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                                .overlay(
                                    Circle()
                                        .stroke(Color.black.opacity(0.1), lineWidth: 1)
                                )
                        }
                        .position(x: xPos, y: yPos)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if selectedHotspot == hotspot.id {
                                    productToOpen = hotspot.product
                                } else {
                                    selectedHotspot = hotspot.id
                                }
                            }
                        }

                        // Popover Card
                        if selectedHotspot == hotspot.id {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(hotspot.product.title)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.black)
                                    .lineLimit(2)

                                if let price = hotspot.product.price {
                                    Text(price.formatted(.currency(code: "USD")))
                                        .font(.system(size: 11, weight: .regular))
                                        .foregroundColor(Color(white: 0.4))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(width: 140, alignment: .leading)
                            .background(Color.white)
                            .overlay(Rectangle().stroke(Color(white: 0.88), lineWidth: 1))
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
                            // Position popover above or below depending on yOffset
                            .position(x: xPos, y: yPos + (hotspot.yOffset > 0.5 ? -60 : 60))
                            .onTapGesture {
                                productToOpen = hotspot.product
                            }
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                        }
                    }
                }
            }
            .ignoresSafeArea()

            // Custom Back Button
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.black)
                        .frame(width: 36, height: 36)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 50)
            .ignoresSafeArea()
        }
        .navigationBarHidden(true)
        .sheet(item: $productToOpen) { product in
            ProductDetailView(product: product)
                .environmentObject(wishlistRepository)
                .environmentObject(cartRepository)
                .environmentObject(registryRepository)
                .environmentObject(tabBarVM)
        }
    }
}
