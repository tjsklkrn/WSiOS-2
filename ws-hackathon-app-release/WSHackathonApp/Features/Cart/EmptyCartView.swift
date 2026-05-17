//
//  EmptyCartView.swift
//  WSHackathonApp
//
//  Created by Nilesh Mahajan on 05/04/26.
//
import SwiftUI

struct EmptyCartView: View {

    var onContinueShopping: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "cart")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundColor(Color(white: 0.7))

            Text("YOUR BAG IS EMPTY")
                .font(.system(size: 12, weight: .medium))
                .tracking(1.5)
                .foregroundColor(.black)

            Text("Add items to your bag to see them here.")
                .font(.system(size: 13))
                .foregroundColor(Color(white: 0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                onContinueShopping?()
            } label: {
                Text("CONTINUE SHOPPING")
                    .font(.system(size: 12, weight: .medium))
                    .tracking(1.2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.black)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)
            .buttonStyle(.plain)
        }
    }
}
