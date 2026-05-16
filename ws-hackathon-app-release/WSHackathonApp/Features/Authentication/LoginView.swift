//
//  LoginView.swift
//  WSHackathonApp
//
//  Created by SDC-USER on 16/05/26.
//

import SwiftUI

struct LoginView: View {

    @EnvironmentObject var authVM: AuthViewModel

    // MARK: Focus State
    @FocusState private var emailFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {

                    // Logo space from top (approx 15% of screen or fixed)
                    Spacer()
                        .frame(minHeight: 40, idealHeight: geometry.size.height * 0.15, maxHeight: geometry.size.height * 0.15)

                    // MARK: - Logo / Wordmark
                    HStack {
                        Spacer()
                        Text("WILLIAMS SONOMA")
                            .font(.system(size: 22, weight: .semibold, design: .serif))
                            .tracking(3)
                            .foregroundColor(.black)
                        Spacer()
                    }
                    
                    // Spacer to vertically center the form in the remaining space
                    Spacer()
                        .frame(minHeight: 80)

                    // MARK: - Login Form Content
                    VStack(alignment: .leading, spacing: 0) {
                        // MARK: - Header
                        Text("Sign In or Create an Account")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundColor(.black)
                            .padding(.bottom, 8)

                        Text("Enter your email address to get started.")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color(.systemGray))
                            .padding(.bottom, 28)

                        // MARK: - Email Field
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .stroke(emailFocused ? Color.black : Color(.systemGray3), lineWidth: 1)
                                .frame(height: 52)

                            HStack {
                                TextField("Email", text: $authVM.email)
                                    .font(.system(size: 15))
                                    .keyboardType(.emailAddress)
                                    .textContentType(.emailAddress)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .focused($emailFocused)
                                    .padding(.horizontal, 14)
                            }
                        }
                        .padding(.bottom, 16)

                        // MARK: - Error message
                        if !authVM.errorMessage.isEmpty {
                            Text(authVM.errorMessage)
                                .font(.system(size: 13))
                                .foregroundColor(.red)
                                .padding(.bottom, 12)
                        }

                        // MARK: - Continue Button
                        Button(action: {
                            emailFocused = false
                            authVM.continueWithEmail()
                        }) {
                            ZStack {
                                Rectangle()
                                    .fill(Color.black)
                                    .frame(height: 52)

                                if authVM.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("CONTINUE")
                                        .font(.system(size: 13, weight: .semibold))
                                        .tracking(2)
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .disabled(authVM.isLoading || authVM.email.isEmpty)
                        .opacity(authVM.email.isEmpty ? 0.5 : 1)
                        .padding(.bottom, 40)

                        // MARK: - Social / New User Section
                        VStack(alignment: .center, spacing: 14) {

                            HStack {
                                VStack { Divider() }
                                Text("OR")
                                    .font(.system(size: 11, weight: .semibold))
                                    .tracking(1)
                                    .foregroundColor(Color(.systemGray))
                                    .fixedSize()
                                VStack { Divider() }
                            }

                            // MARK: Google Sign-In Button
                            Button(action: {
                                emailFocused = false
                                authVM.signInWithGoogle()
                            }) {
                                ZStack {
                                    Rectangle()
                                        .fill(Color.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 52)
                                        .overlay(
                                            Rectangle()
                                                .stroke(Color.black, lineWidth: 1)
                                        )

                                    HStack(spacing: 12) {
                                        Image("GoogleLogo")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 22, height: 22)

                                        Text("Continue with Google")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.black)
                                    }
                                }
                            }
                            .disabled(authVM.isLoading)

                            // MARK: Divider
                            HStack {
                                VStack { Divider() }
                                Text("NEW HERE?")
                                    .font(.system(size: 10, weight: .semibold))
                                    .tracking(1)
                                    .foregroundColor(Color(.systemGray))
                                    .fixedSize()
                                VStack { Divider() }
                            }

                            // MARK: Create Account Button
                            Button(action: {
                                emailFocused = false
                                authVM.errorMessage = ""
                                authVM.password = ""
                                authVM.confirmPassword = ""
                                authVM.currentStep = .signup
                            }) {
                                ZStack {
                                    Rectangle()
                                        .fill(Color.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 52)
                                        .overlay(
                                            Rectangle()
                                                .stroke(Color.black, lineWidth: 1)
                                        )

                                    Text("CREATE AN ACCOUNT")
                                        .font(.system(size: 13, weight: .semibold))
                                        .tracking(2)
                                        .foregroundColor(.black)
                                }
                            }
                            .disabled(authVM.isLoading)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 24)
                    
                    // Spacer to vertically center the form in the remaining space
                    Spacer()
                        .frame(minHeight: 32)
                }
                .frame(minHeight: geometry.size.height)
            }
            .background(Color.white)
            .ignoresSafeArea(edges: .top)
            .onAppear { emailFocused = true }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
