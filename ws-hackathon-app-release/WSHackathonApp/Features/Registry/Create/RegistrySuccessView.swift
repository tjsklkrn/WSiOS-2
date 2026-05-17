//
//  RegistrySuccessView.swift
//  WSHackathonApp
//
//  Created by Nilesh Mahajan on 06/04/26.
//

import Foundation
import SwiftUI

struct RegistrySuccessView: View {

    @EnvironmentObject var registryRepo: RegistryRepository
    @EnvironmentObject var tabBarVM: WSTabBarViewModel

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Checkmark icon
                ZStack {
                    Circle()
                        .stroke(Color.black, lineWidth: 1)
                        .frame(width: 72, height: 72)
                    Image(systemName: "checkmark")
                        .font(.system(size: 28, weight: .ultraLight))
                        .foregroundColor(.black)
                }
                .padding(.bottom, 28)

                Text("REGISTRY CREATED")
                    .font(.system(size: 12, weight: .medium))
                    .tracking(2.0)
                    .foregroundColor(.black)
                    .padding(.bottom, 10)

                if let name = registryRepo.currentRegistry?.displayName {
                    Text(name)
                        .font(.system(size: 22, weight: .light))
                        .foregroundColor(.black)
                        .padding(.bottom, 6)
                }

                Text("Your registry has been created.\nStart adding items you love.")
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.45))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)

                Rectangle()
                    .fill(Color(white: 0.88))
                    .frame(height: 1)
                    .padding(.horizontal, 60)
                    .padding(.bottom, 40)

                // CTA buttons
                VStack(spacing: 10) {
                    Button {
                        tabBarVM.resetRegistryFlow()
                        tabBarVM.selectTab(.home)
                    } label: {
                        Text("START BROWSING")
                            .font(.system(size: 12, weight: .medium))
                            .tracking(1.5)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(Color.black)
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)

                    Button {
                        tabBarVM.resetRegistryFlow()
                    } label: {
                        Text("VIEW MY REGISTRY")
                            .font(.system(size: 12, weight: .medium))
                            .tracking(1.2)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .foregroundColor(.black)
                            .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}
