import SwiftUI

struct CategoryProductsView: View {
    let category: String
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var cartRepo: CartRepository
    @EnvironmentObject var registryRepo: RegistryRepository
    @EnvironmentObject var wishlistRepo: WishlistRepository
    @EnvironmentObject var tabBarVM: WSTabBarViewModel
    
    @State private var products: [ProductItem] = []
    @State private var isLoading = false
    
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
                    
                    Text(category.uppercased())
                        .font(.system(size: 13, weight: .medium))
                        .tracking(1.5)
                    
                    Spacer()
                    
                    // placeholder to center text
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 16)
                
                Rectangle()
                    .fill(Color(white: 0.9))
                    .frame(height: 1)
                
                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if products.isEmpty {
                    Spacer()
                    Text("No items found in this category.")
                        .foregroundColor(Color(white: 0.5))
                    Spacer()
                } else {
                    ScrollView {
                        let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(products) { product in
                                ProductCardView(
                                    product: product,
                                    quantity: cartRepo.items.first(where: { $0.id == product.id })?.quantity ?? 0,
                                    registryQuantity: registryRepo.currentRegistry?.items.first(where: { $0.id == product.id })?.quantity ?? 0,
                                    isWishlisted: wishlistRepo.isWishlisted(product),
                                    onAdd: { cartRepo.add(product: product) },
                                    onRemove: { cartRepo.remove(productId: product.id) },
                                    onAddToRegistry: {
                                        if registryRepo.isActiveRegistry {
                                            registryRepo.addProduct(product)
                                        } else {
                                            tabBarVM.selectTab(.registry)
                                        }
                                    },
                                    onRemoveFromRegistry: { registryRepo.removeItem(product.id) },
                                    onToggleWishlist: { wishlistRepo.toggle(product) }
                                )
                            }
                        }
                        .padding(20)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            await loadProducts()
        }
    }
    
    private func loadProducts() async {
        isLoading = true
        do {
            let dtos: [ProductItemDTO] = try await APIClient.shared.request(Endpoint.products())
            let allProducts = dtos.map { ProductItem(from: $0) }
            
            // simple category filtering mapping
            let searchTerms: [String]
            switch category.lowercased() {
            case "cookware": searchTerms = ["pan", "pot", "cookware", "skillet"]
            case "dinnerware": searchTerms = ["plate", "bowl", "mug", "dinner", "saucer"]
            case "bar & wine": searchTerms = ["glass", "wine", "decanter", "bar", "cocktail"]
            case "small appliances": searchTerms = ["blender", "espresso", "toaster", "appliance", "coffee", "mixer"]
            case "cutlery": searchTerms = ["knife", "cutlery", "block"]
            case "storage": searchTerms = ["canister", "organis", "storage", "jar", "container"]
            default: searchTerms = [category.lowercased()]
            }
            
            products = allProducts.filter { product in
                let title = product.title.lowercased()
                return searchTerms.contains { term in title.contains(term) }
            }
        } catch {
            print("Failed to load products: \(error)")
        }
        isLoading = false
    }
}
