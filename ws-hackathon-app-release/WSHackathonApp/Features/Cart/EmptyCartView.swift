//
//  EmptyCartView.swift
//  WSHackathonApp
//

import SwiftUI

struct EmptyCartView: View {
    var onContinueShopping: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Sleek Minimal Icon
            Image(systemName: "bag")
                .font(.system(size: 64, weight: .thin))
                .foregroundColor(Color(.systemGray3))

            // Clean Typography
            VStack(spacing: 8) {
                Text("Your Cart is Empty")
                    .font(.system(size: 20, weight: .bold)) // Modern bold Title look
                    .foregroundColor(.black)

                Text("Looks like you haven't added anything to your cart yet.")
                    .font(.system(size: 13))
                    .foregroundColor(Color(.systemGray))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer().frame(height: 12)

            // Continue Shopping CTA
            Button(action: {
                onContinueShopping?()
            }) {
                Text("CONTINUE SHOPPING")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: "#C11F1F")) // Signature Crimson Red
                    .cornerRadius(4) // Flat rectangular button style
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGray6).ignoresSafeArea())
    }
}
