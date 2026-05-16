//
//  AuthContainerView.swift
//  WSHackathonApp
//
//  Created by SDC-USER on 16/05/26.
//

import SwiftUI

/// Routes between LoginView → PasswordView / SignupView based on AuthViewModel state.
/// Also owns the global auth alert presentation.
struct AuthContainerView: View {

    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        ZStack {
            switch authVM.currentStep {
            case .email:
                LoginView()
                    .environmentObject(authVM)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading),
                        removal: .move(edge: .leading)
                    ))

            case .password:
                PasswordView()
                    .environmentObject(authVM)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    ))

            case .signup:
                SignupView()
                    .environmentObject(authVM)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authVM.currentStep)
        // MARK: - Global Auth Alerts
        .alert(item: $authVM.activeAlert) { alert in
            switch alert {

            case .verificationSent(let email):
                return Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("Got it")) {
                        // Reset to email step so user can sign in after verifying
                        authVM.currentStep = .email
                    }
                )

            case .notVerified:
                return Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    primaryButton: .default(Text("Resend Email")) {
                        authVM.resendVerificationEmail()
                    },
                    secondaryButton: .cancel(Text("OK")) {
                        authVM.activeAlert = nil
                    }
                )

            case .invalidEmail:
                return Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("Correct Email")) {
                        authVM.activeAlert = nil
                    }
                )

            case .resendSuccess:
                return Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
}

#Preview {
    AuthContainerView()
        .environmentObject(AuthViewModel())
}
