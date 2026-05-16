//
//  PasswordView.swift
//  WSHackathonApp
//
//  Created by SDC-USER on 16/05/26.
//

import SwiftUI
import FirebaseAuth

struct PasswordView: View {

    @EnvironmentObject var authVM: AuthViewModel
    @FocusState private var passwordFocused: Bool
    @State private var isPasswordVisible: Bool = false
    @State private var resetEmailSent: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // MARK: - Logo / Wordmark
                HStack {
                    Spacer()
                    Text("WILLIAMS SONOMA")
                        .font(.system(size: 22, weight: .semibold, design: .serif))
                        .tracking(3)
                        .foregroundColor(.black)
                    Spacer()
                }
                .padding(.top, 56)
                .padding(.bottom, 40)

                // MARK: - Back Button
                Button(action: { authVM.goBackToEmail() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 14))
                    }
                    .foregroundColor(.black)
                }
                .padding(.bottom, 24)

                // MARK: - Header
                Text("Welcome back")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.black)
                    .padding(.bottom, 6)

                Text(authVM.email)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.bottom, 24)

                // MARK: - Password Field
                ZStack(alignment: .trailing) {
                    Group {
                        if isPasswordVisible {
                            TextField("Password", text: $authVM.password)
                                .focused($passwordFocused)
                        } else {
                            SecureField("Password", text: $authVM.password)
                                .focused($passwordFocused)
                        }
                    }
                    .font(.system(size: 15))
                    .textContentType(.password)
                    .padding(.leading, 14)
                    .padding(.trailing, 48)
                    .frame(height: 52)
                    .overlay(
                        RoundedRectangle(cornerRadius: 0)
                            .stroke(passwordFocused ? Color.black : Color(.systemGray3), lineWidth: 1)
                    )

                    Button(action: { isPasswordVisible.toggle() }) {
                        Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                            .font(.system(size: 16))
                            .foregroundColor(Color(.systemGray))
                    }
                    .padding(.trailing, 14)
                }
                .padding(.bottom, 12)

                // MARK: - Forgot Password
                Button(action: { sendPasswordReset() }) {
                    Text(resetEmailSent ? "Reset email sent ✓" : "Forgot password?")
                        .font(.system(size: 13))
                        .foregroundColor(resetEmailSent ? .green : .black)
                        .underline(!resetEmailSent)
                }
                .padding(.bottom, 16)

                // MARK: - Error
                if !authVM.errorMessage.isEmpty {
                    Text(authVM.errorMessage)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                        .padding(.bottom, 12)
                }

                // MARK: - Sign In Button
                Button(action: { authVM.signIn() }) {
                    ZStack {
                        Rectangle()
                            .fill(Color.black)
                            .frame(height: 52)

                        if authVM.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("SIGN IN")
                                .font(.system(size: 13, weight: .semibold))
                                .tracking(2)
                                .foregroundColor(.white)
                        }
                    }
                }
                .disabled(authVM.isLoading || authVM.password.isEmpty)
                .opacity(authVM.password.isEmpty ? 0.5 : 1)

                Spacer(minLength: 32)
            }
            .padding(.horizontal, 24)
        }
        .background(Color.white)
        .ignoresSafeArea(edges: .top)
        .onAppear { passwordFocused = true }
    }

    // MARK: - Forgot Password
    private func sendPasswordReset() {
        guard !authVM.email.isEmpty else { return }
        authVM.errorMessage = ""
        Auth.auth().sendPasswordReset(withEmail: authVM.email) { error in
            DispatchQueue.main.async {
                if let error = error {
                    authVM.errorMessage = error.localizedDescription
                } else {
                    resetEmailSent = true
                }
            }
        }
    }
}

#Preview {
    let vm = AuthViewModel()
    vm.email = "john@example.com"
    return PasswordView().environmentObject(vm)
}
