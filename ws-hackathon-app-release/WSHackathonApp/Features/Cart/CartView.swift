//
//  CartView.swift
//  WSHackathonApp
//
//  Created by Nilesh Mahajan on 03/04/26.
//

import SwiftUI

struct CartView: View {
    @StateObject private var viewModel = CartViewModel()
    @EnvironmentObject var cartRepository: CartRepository
    @EnvironmentObject var tabBarVM: WSTabBarViewModel
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGray6)
                    .ignoresSafeArea()
                if viewModel.isEmptyCart {
                    EmptyCartView {
                        tabBarVM.selectTab(.home)
                    }
                } else {
                    VStack(spacing: 0) {
                        
                        ScrollView {
                            VStack(spacing: 16) {
                                ForEach(viewModel.items) { item in
                                    NavigationLink(destination: Text("Product Details for \(item.title)")) {
                                        CartItemRow(
                                            item: item,
                                            onAdd: { viewModel.add(item) },
                                            onDecrease: { viewModel.decreaseItem(item) },
                                            onDelete: { viewModel.removeItem(item) }
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(16)
                        }
                        
                        // MARK: - Bottom Total View
                        VStack(spacing: 12) {
                            
                            HStack {
                                Text(AppStrings.Cart.total)
                                    .font(.headline)
                                
                                Spacer()
                                
                                Text(viewModel.totalPriceText)
                                    .font(.headline)
                                    .fontWeight(.bold)
                            }
                            
                            NavigationLink(destination: CheckoutAddressView()) {
                                Text(AppStrings.Cart.checkoutButton)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.black)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(16.0)
                        .shadow(color: Color(.systemGray4), radius: 4, x: 0, y: -2)
                    }
                }
            }
            .navigationTitle(AppStrings.Cart.title)
        }
        .onAppear {
            Task {
                viewModel.bind(repository: cartRepository)
            }
        }
    }
}
