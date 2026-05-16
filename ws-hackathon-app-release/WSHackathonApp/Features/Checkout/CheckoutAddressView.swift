//
//  CheckoutAddressView.swift
//  WSHackathonApp
//
//  Created by AI Assistant
//

import SwiftUI

struct CheckoutAddressView: View {
    @StateObject private var viewModel = CheckoutAddressViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                // Form Fields
                VStack(spacing: 16) {
                    addressField(title: AppStrings.Checkout.fullName, text: $viewModel.fullName)
                    addressField(title: AppStrings.Checkout.streetAddress, text: $viewModel.streetAddress)
                    
                    HStack(spacing: 16) {
                        addressField(title: AppStrings.Checkout.city, text: $viewModel.city)
                        addressField(title: AppStrings.Checkout.state, text: $viewModel.state)
                    }
                    
                    HStack(spacing: 16) {
                        addressField(title: AppStrings.Checkout.zipCode, text: $viewModel.zipCode)
                            .keyboardType(.numberPad)
                        addressField(title: AppStrings.Checkout.phoneNumber, text: $viewModel.phoneNumber)
                            .keyboardType(.phonePad)
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                
                // Proceed Button
                NavigationLink(destination: PaymentGatewayView()) {
                    Text(AppStrings.Checkout.proceedToPayment)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.isFormValid ? Color.black : Color.gray)
                        .cornerRadius(10)
                }
                .disabled(!viewModel.isFormValid)
                .padding(.top, 16)
            }
            .padding()
        }
        .background(Color(.systemGray6).ignoresSafeArea())
        .navigationTitle(AppStrings.Checkout.addressTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @ViewBuilder
    private func addressField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            TextField(title, text: text)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
    }
}

#Preview {
    NavigationStack {
        CheckoutAddressView()
    }
}
