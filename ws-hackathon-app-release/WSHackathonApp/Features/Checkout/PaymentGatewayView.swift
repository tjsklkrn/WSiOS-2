//
//  PaymentGatewayView.swift
//  WSHackathonApp
//
//  Created by AI Assistant
//

import SwiftUI

struct PaymentGatewayView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "creditcard.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.green)
            
            Text(AppStrings.Checkout.paymentTitle)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(AppStrings.Checkout.mockPaymentDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            Button(action: {
                // Here is where payment logic would be implemented
                dismiss()
            }) {
                Text(AppStrings.Checkout.finishOrder)
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
        }
        .padding()
        .navigationTitle(AppStrings.Checkout.paymentTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        PaymentGatewayView()
    }
}
