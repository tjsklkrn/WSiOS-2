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

    // MARK: - Selected Look State
    @State private var selectedLook: LookType
    @State private var productToOpen: ProductItem? = nil

    enum LookType {
        case kitchen, dining
    }

    init(initialLook: LookType = .kitchen) {
        _selectedLook = State(initialValue: initialLook)
    }

    // MARK: - Kitchen Hotspots (Linked directly to real skus.json entries)
    let kitchenHotspots: [Hotspot] = [
        Hotspot(
            xOffset: 0.45,
            yOffset: 0.48,
            product: ProductItem(
                id: "8931142",
                title: "Breville the Barista Express Impress Espresso Machine, Stainless Steel",
                price: 899.95,
                path: "/img_breville_impress.png"
            )
        ),
        Hotspot(
            xOffset: 0.78,
            yOffset: 0.48,
            product: ProductItem(
                id: "2349015",
                title: "KitchenAid Artisan Series 5-Qt. Stand Mixer, Ice Blue",
                price: 449.95,
                path: "/img_kitchenaid_blue.png"
            )
        )
    ]

    // MARK: - Dining Table Hotspots (Linked directly to real skus.json dinnerware and serving entries)
    let diningHotspots: [Hotspot] = [
        Hotspot(
            xOffset: 0.60,
            yOffset: 0.56,
            product: ProductItem(
                id: "6247040",
                title: "Hold Everything Lidded Ceramic Bowl, Ashwood, 12\"",
                price: 89.95,
                path: "/img64m.jpg"
            )
        ),
        Hotspot(
            xOffset: 0.68,
            yOffset: 0.82,
            product: ProductItem(
                id: "6771049",
                title: "Williams Sonoma Brasserie Porcelain Dinner Plates, Set of 4",
                price: 64.95,
                path: "/img_ws_plates.png"
            )
        ),
        Hotspot(
            xOffset: 0.72,
            yOffset: 0.42,
            product: ProductItem(
                id: "9440123",
                title: "Riedel Vinum Cabernet/Merlot Wine Glasses, Set of 4",
                price: 118.00,
                path: "/img_riedel_glasses.png"
            )
        ),
        Hotspot(
            xOffset: 0.16,
            yOffset: 0.64,
            product: ProductItem(
                id: "2505456",
                title: "Williams Sonoma End-Grain Cutting Board, Acacia, 15\" X 20\"",
                price: 129.95,
                path: "/img17m.jpg"
            )
        )
    ]

    // MARK: - Computed Active Hotspots
    private var activeHotspots: [Hotspot] {
        selectedLook == .kitchen ? kitchenHotspots : diningHotspots
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header Nav Bar with integrated Look Selector
                headerNavBar

                // Main Image with Hotspots
                GeometryReader { geo in
                    ZStack(alignment: .topLeading) {
                        Image(selectedLook == .kitchen ? "kitchen_set" : "dining_set")
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()

                        // Draw Hotspots depending on selection using dedicated HotspotView subview
                        ForEach(activeHotspots) { hotspot in
                            HotspotView(
                                hotspot: hotspot,
                                productToOpen: $productToOpen
                            )
                            .offset(
                                x: geo.size.width * hotspot.xOffset - 22,
                                y: geo.size.height * hotspot.yOffset - 22
                            )
                        }
                    }
                }
                .ignoresSafeArea(edges: .bottom)
            }
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

    // MARK: - Header Nav Bar

    private var headerNavBar: some View {
        HStack {
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.black)
                    .contentShape(Rectangle())
            }

            Spacer()

            Text("Shop the Look")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.black)
                .tracking(0.5)

            Spacer()

            Spacer().frame(width: 24)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(Color.white)
        .overlay(
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
}

// ---------------------------------------------------------------------------
// Dedicated Hotspot View Subview (Direct transition to details on tap)
// ---------------------------------------------------------------------------

struct HotspotView: View {
    let hotspot: Hotspot
    @Binding var productToOpen: ProductItem?

    var body: some View {
        // The pulsating dot (fixed tight layout box to prevent gesture blocking)
        ZStack {
            // The pulse ring
            Circle()
                .stroke(Color.white.opacity(0.6), lineWidth: 1)
                .frame(width: 32, height: 32)
                .scaleEffect(1.3)
                .opacity(0.8)
                .animation(Animation.easeOut(duration: 1.5).repeatForever(autoreverses: false), value: true)

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
        .frame(width: 44, height: 44) // Perfect touch target size
        .contentShape(Rectangle()) // Ensures correct touch response
        .onTapGesture {
            productToOpen = hotspot.product
        }
    }
}
