//
//  SignupView.swift
//  WSHackathonApp
//
//  Created by SDC-USER on 16/05/26.
//

import SwiftUI

struct SignupView: View {

    @EnvironmentObject var authVM: AuthViewModel
    @FocusState private var focusedField: SignupField?
    @State private var isPasswordVisible: Bool = false
    @State private var isConfirmVisible: Bool = false

    enum SignupField: Hashable {
        case email, name, password, confirm
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // MARK: - Back Button
                Button(action: { authVM.goBackToEmail() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 16))
                    }
                    .foregroundColor(.black)
                }
                .padding(.top, 56)
                .padding(.bottom, 50)

                // MARK: - Header
                Text("Create an Account")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.black)
                    .padding(.bottom, 28)

                // MARK: - Email Field
                fieldLabel("Email")
                TextField("Email address", text: $authVM.email)
                    .font(.system(size: 15))
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .focused($focusedField, equals: .email)
                    .padding(.horizontal, 14)
                    .frame(height: 52)
                    .overlay(
                        RoundedRectangle(cornerRadius: 0)
                            .stroke(focusedField == .email ? Color.black : Color(.systemGray3), lineWidth: 1)
                    )
                    .padding(.bottom, 16)

                // MARK: - Full Name Field
                fieldLabel("Full Name")
                inputField(
                    placeholder: "Full Name",
                    text: $authVM.fullName,
                    contentType: .name,
                    field: .name
                )
                .padding(.bottom, 16)

                // MARK: - Password Field
                fieldLabel("Password")
                passwordInputField(
                    placeholder: "Password (min. 6 characters)",
                    text: $authVM.password,
                    isVisible: $isPasswordVisible,
                    contentType: .newPassword,
                    field: .password
                )
                .padding(.bottom, 16)

                // MARK: - Confirm Password Field
                fieldLabel("Confirm Password")
                passwordInputField(
                    placeholder: "Confirm Password",
                    text: $authVM.confirmPassword,
                    isVisible: $isConfirmVisible,
                    contentType: .newPassword,
                    field: .confirm
                )
                .padding(.bottom, 16)

                // MARK: - Password match indicator
                if !authVM.confirmPassword.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: authVM.password == authVM.confirmPassword ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(authVM.password == authVM.confirmPassword ? .green : .red)
                        Text(authVM.password == authVM.confirmPassword ? "Passwords match" : "Passwords do not match")
                            .font(.system(size: 12))
                            .foregroundColor(authVM.password == authVM.confirmPassword ? .green : .red)
                    }
                    .padding(.bottom, 16)
                }

                // MARK: - Error
                if !authVM.errorMessage.isEmpty {
                    Text(authVM.errorMessage)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                        .padding(.bottom, 12)
                }

                // MARK: - Create Account Button
                Button(action: { authVM.signUp() }) {
                    ZStack {
                        Rectangle()
                            .fill(Color.black)
                            .frame(height: 52)

                        if authVM.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("CREATE ACCOUNT")
                                .font(.system(size: 13, weight: .semibold))
                                .tracking(2)
                                .foregroundColor(.white)
                        }
                    }
                }
                .disabled(authVM.isLoading || !canSubmit)
                .opacity(canSubmit ? 1 : 0.5)
                .padding(.bottom, 24)

                // MARK: - Terms note
                Text("By creating an account, you agree to our Terms of Use and Privacy Policy.")
                    .font(.system(size: 11))
                    .foregroundColor(Color(.systemGray))
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 32)
            }
            .padding(.horizontal, 24)
        }
        .background(Color.white)
        .ignoresSafeArea(edges: .top)
        .onAppear { focusedField = authVM.email.isEmpty ? .email : .name }
    }

    // MARK: - Helpers

    private var canSubmit: Bool {
        !authVM.email.isEmpty &&
        !authVM.fullName.isEmpty &&
        authVM.password.count >= 6 &&
        authVM.password == authVM.confirmPassword
    }

    @ViewBuilder
    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(1)
            .foregroundColor(Color(.systemGray))
            .padding(.bottom, 6)
    }

    @ViewBuilder
    private func inputField(
        placeholder: String,
        text: Binding<String>,
        contentType: UITextContentType,
        field: SignupField
    ) -> some View {
        TextField(placeholder, text: text)
            .font(.system(size: 15))
            .textContentType(contentType)
            .autocapitalization(contentType == .name ? .words : .none)
            .disableAutocorrection(true)
            .focused($focusedField, equals: field)
            .padding(.horizontal, 14)
            .frame(height: 52)
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(focusedField == field ? Color.black : Color(.systemGray3), lineWidth: 1)
            )
    }

    @ViewBuilder
    private func passwordInputField(
        placeholder: String,
        text: Binding<String>,
        isVisible: Binding<Bool>,
        contentType: UITextContentType,
        field: SignupField
    ) -> some View {
        ZStack(alignment: .trailing) {
            Group {
                if isVisible.wrappedValue {
                    TextField(placeholder, text: text)
                        .focused($focusedField, equals: field)
                } else {
                    SecureField(placeholder, text: text)
                        .focused($focusedField, equals: field)
                }
            }
            .font(.system(size: 15))
            .textContentType(contentType)
            .padding(.leading, 14)
            .padding(.trailing, 48)
            .frame(height: 52)
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(focusedField == field ? Color.black : Color(.systemGray3), lineWidth: 1)
            )

            Button(action: { isVisible.wrappedValue.toggle() }) {
                Image(systemName: isVisible.wrappedValue ? "eye.slash" : "eye")
                    .font(.system(size: 16))
                    .foregroundColor(Color(.systemGray))
            }
            .padding(.trailing, 14)
        }
    }
}

#Preview {
    let vm = AuthViewModel()
    vm.email = "new@example.com"
    vm.currentStep = .signup
    return SignupView().environmentObject(vm)
}
