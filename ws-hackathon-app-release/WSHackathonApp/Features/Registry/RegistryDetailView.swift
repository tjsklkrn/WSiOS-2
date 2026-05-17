import SwiftUI

struct RegistryDetailView: View {
    let registryId: UUID
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var registryRepo: RegistryRepository
    @EnvironmentObject var cartRepo: CartRepository
    @EnvironmentObject var tabBarVM: WSTabBarViewModel
    
    @StateObject private var viewModel = RegistryViewModel()
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Navigation Bar
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                            .frame(width: 44, height: 44)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    }
                    
                    Spacer()
                    
                    Text("REGISTRY DETAILS")
                        .font(.system(size: 13, weight: .medium))
                        .tracking(1.5)
                    
                    Spacer()
                    
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 16)
                
                Rectangle()
                    .fill(Color(white: 0.9))
                    .frame(height: 1)
                
                if let registry = registryRepo.registries.first(where: { $0.id == registryId }) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            
                            // Registry Info
                            VStack(alignment: .leading, spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("YOUR REGISTRY")
                                        .font(.system(size: 10, weight: .medium))
                                        .tracking(1.5)
                                        .foregroundColor(Color(white: 0.5))
                                    Text(registry.displayName)
                                        .font(.system(size: 22, weight: .light))
                                        .foregroundColor(.black)
                                    Text(registry.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.system(size: 13))
                                        .foregroundColor(Color(white: 0.5))
                                }
                                
                                Rectangle()
                                    .fill(Color(white: 0.9))
                                    .frame(height: 1)
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("REGISTRY ID:")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(Color(white: 0.5))
                                        Text(registry.id.uuidString.prefix(8).uppercased())
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.black)
                                    }
                                    
                                    HStack {
                                        Text("VISIBILITY:")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(Color(white: 0.5))
                                        
                                        Text(registry.visibility.title)
                                            .font(.system(size: 12, weight: .medium))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(4)
                                    }
                                    
                                    // MARK: Budget Tracker
                                    VStack(alignment: .leading, spacing: 10) {
                                        let totalValue = registry.items.reduce(0) { $0 + ($1.price * Double($1.quantity)) }
                                        let purchasedValue = registry.items.reduce(0) { $0 + ($1.price * Double($1.purchasedQuantity)) + $1.contributedAmount }
                                        let progress = totalValue > 0 ? purchasedValue / totalValue : 0
                                        
                                        HStack {
                                            Text("BUDGET TRACKER:")
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(Color(white: 0.5))
                                            Spacer()
                                            Text(String(format: "$%.0f / $%.0f", purchasedValue, totalValue))
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(.black)
                                        }
                                        
                                        GeometryReader { geo in
                                            ZStack(alignment: .leading) {
                                                Rectangle()
                                                    .fill(Color(white: 0.9))
                                                    .frame(height: 6)
                                                
                                                Rectangle()
                                                    .fill(Color.black)
                                                    .frame(width: geo.size.width * CGFloat(min(progress, 1.0)), height: 6)
                                            }
                                        }
                                        .frame(height: 6)
                                        .clipShape(Capsule())
                                    }
                                    .padding(.top, 8)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 24)
                            
                            Rectangle()
                                .fill(Color(white: 0.9))
                                .frame(height: 1)
                            
                            // Items List
                            if !registry.items.isEmpty {
                                VStack(alignment: .leading, spacing: 20) {
                                    Text("REGISTRY ITEMS")
                                        .font(.system(size: 10, weight: .medium))
                                        .tracking(1.5)
                                        .foregroundColor(Color(white: 0.5))
                                        .padding(.horizontal, 20)
                                        .padding(.top, 24)
                                    
                                    VStack(spacing: 0) {
                                        ForEach(Array(registry.items.enumerated()), id: \.element.id) { index, item in
                                            VStack(spacing: 0) {
                                                RegistryItemRow(
                                                    viewModel: RegistryItemRowViewModel(
                                                        item: item,
                                                        registryRepo: registryRepo,
                                                        cartRepo: cartRepo,
                                                        tabbarVM: tabBarVM
                                                    )
                                                )
                                                
                                                // Group Gifting indicator (Mock rule: item over $100)
                                                if item.price >= 100.0 {
                                                    HStack {
                                                        Image(systemName: "person.3")
                                                            .font(.system(size: 12))
                                                        Text("Group Gifting Enabled")
                                                            .font(.system(size: 11, weight: .medium))
                                                        Spacer()
                                                    }
                                                    .foregroundColor(Color(white: 0.4))
                                                    .padding(.horizontal, 16)
                                                    .padding(.bottom, 16)
                                                }
                                                
                                                if index < registry.items.count - 1 {
                                                    Rectangle()
                                                        .fill(Color(white: 0.9))
                                                        .frame(height: 1)
                                                        .padding(.horizontal, 16)
                                                }
                                            }
                                        }
                                    }
                                }
                            } else {
                                VStack(spacing: 16) {
                                    Image(systemName: "tray")
                                        .font(.system(size: 36, weight: .ultraLight))
                                        .foregroundColor(Color(white: 0.7))
                                        .padding(.top, 40)
                                    Text("No items added yet")
                                        .font(.system(size: 13))
                                        .foregroundColor(Color(white: 0.5))
                                }
                                .frame(maxWidth: .infinity)
                            }
                            
                            // MARK: Recommendations (Popular Items)
                            VStack(alignment: .leading, spacing: 16) {
                                Rectangle()
                                    .fill(Color(white: 0.9))
                                    .frame(height: 1)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 32)
                                
                                Text("SUGGESTED FOR YOU")
                                    .font(.system(size: 10, weight: .medium))
                                    .tracking(1.5)
                                    .foregroundColor(Color(white: 0.5))
                                    .padding(.horizontal, 20)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        // Mock trending items
                                        ForEach(mockTrendingItems, id: \.id) { mockItem in
                                            VStack(alignment: .leading, spacing: 8) {
                                                Rectangle()
                                                    .fill(Color(white: 0.95))
                                                    .frame(width: 120, height: 120)
                                                    .overlay(
                                                        Image(systemName: "star.fill")
                                                            .foregroundColor(Color(white: 0.8))
                                                            .font(.system(size: 30))
                                                    )
                                                
                                                Text(mockItem.title)
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(.black)
                                                    .lineLimit(2)
                                                
                                                Text(String(format: "$%.2f", mockItem.price))
                                                    .font(.system(size: 12))
                                                    .foregroundColor(Color(white: 0.5))
                                                
                                                Button {
                                                    registryRepo.addProduct(ProductItem(id: mockItem.id, title: mockItem.title, price: mockItem.price, path: nil))
                                                } label: {
                                                    Text("ADD")
                                                        .font(.system(size: 10, weight: .bold))
                                                        .tracking(1.0)
                                                        .frame(maxWidth: .infinity)
                                                        .padding(.vertical, 8)
                                                        .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
                                                        .foregroundColor(.black)
                                                }
                                            }
                                            .frame(width: 120)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 20)
                                }
                            }
                            
                            // Actions
                            VStack(spacing: 16) {
                                Rectangle()
                                    .fill(Color(white: 0.9))
                                    .frame(height: 1)
                                    .padding(.top, 16)
                                
                                Button {
                                    // Data Consolidation Mock action
                                } label: {
                                    HStack {
                                        Image(systemName: "square.and.arrow.up")
                                        Text("Export & Consolidate Data")
                                    }
                                    .font(.system(size: 13, weight: .medium))
                                    .tracking(0.5)
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .overlay(Rectangle().stroke(Color(white: 0.88), lineWidth: 1))
                                }
                                .padding(.horizontal, 20)
                                
                                Button("Delete Registry") {
                                    registryRepo.deleteRegistry(id: registryId)
                                    dismiss()
                                }
                                .font(.system(size: 11, weight: .medium))
                                .tracking(0.5)
                                .foregroundColor(Color(red: 0.64, green: 0.07, blue: 0.07))
                                .padding(.bottom, 40)
                            }
                            .padding(.top, 16)
                        }
                    }
                } else {
                    Spacer()
                    Text("Registry not found")
                    Spacer()
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            registryRepo.currentRegistryId = registryId
            viewModel.bind(repository: registryRepo)
        }
    }
    
    private var mockTrendingItems: [(id: String, title: String, price: Double)] {
        [
            (id: "T1", title: "Vitamix Professional Blender", price: 499.95),
            (id: "T2", title: "Le Creuset Dutch Oven", price: 359.99),
            (id: "T3", title: "KitchenAid Stand Mixer", price: 399.00),
            (id: "T4", title: "Global 7-Piece Knife Set", price: 299.95)
        ]
    }
}
