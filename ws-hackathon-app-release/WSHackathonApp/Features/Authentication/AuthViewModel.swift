//
//  AuthViewModel.swift
//  WSHackathonApp
//
//  Created by SDC-USER on 16/05/26.
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseCore
import GoogleSignIn

// MARK: - Auth Flow Step
enum AuthStep {
    case email
    case password
    case signup
}

// MARK: - Alert type
enum AuthAlert: Identifiable {
    case verificationSent(email: String)
    case notVerified(email: String)
    case invalidEmail
    case resendSuccess

    var id: String {
        switch self {
        case .verificationSent: return "verificationSent"
        case .notVerified:      return "notVerified"
        case .invalidEmail:     return "invalidEmail"
        case .resendSuccess:    return "resendSuccess"
        }
    }

    var title: String {
        switch self {
        case .verificationSent: return "Verify Your Email"
        case .notVerified:      return "Email Not Verified"
        case .invalidEmail:     return "Invalid Email Address"
        case .resendSuccess:    return "Email Sent"
        }
    }

    var message: String {
        switch self {
        case .verificationSent(let email):
            return "A verification link has been sent to \(email).\n\nPlease check your inbox (and spam folder) and tap the link before signing in."
        case .notVerified(let email):
            return "The email address \(email) has not been verified yet.\n\nPlease check your inbox for the verification link, or request a new one."
        case .invalidEmail:
            return "This email address doesn't appear to be valid. Please double-check it and try again."
        case .resendSuccess:
            return "A new verification link has been sent. Please check your inbox."
        }
    }
}

// MARK: - AuthViewModel
class AuthViewModel: ObservableObject {

    // MARK: Published State
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var confirmPassword: String = ""
    @Published var fullName: String = ""

    @Published var currentStep: AuthStep = .email
    @Published var isLoggedIn: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""

    /// Set to trigger an alert presentation in the active view
    @Published var activeAlert: AuthAlert? = nil

    // MARK: - Continue (email-first)
    func continueWithEmail() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidEmail(trimmedEmail) else {
            errorMessage = "Please enter a valid email address."
            return
        }
        errorMessage = ""
        email = trimmedEmail
        currentStep = .password
    }

    // MARK: - Sign In
    func signIn() {
        guard !password.isEmpty else {
            errorMessage = "Please enter your password."
            return
        }
        errorMessage = ""
        isLoading = true

        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            guard let self else { return }
            DispatchQueue.main.async {
                self.isLoading = false

                if let error = error {
                    let code = AuthErrorCode(rawValue: (error as NSError).code)
                    if code == .userNotFound {
                        // No account — redirect to signup
                        self.password = ""
                        self.errorMessage = ""
                        self.currentStep = .signup
                    } else if code == .invalidEmail {
                        self.activeAlert = .invalidEmail
                    } else {
                        self.errorMessage = self.friendlyError(error)
                    }
                    return
                }

                // Sign-in succeeded — check email verification
                guard let user = result?.user else {
                    self.isLoggedIn = true
                    return
                }

                if user.isEmailVerified {
                    self.isLoggedIn = true
                } else {
                    // Not verified — sign them out and prompt
                    try? Auth.auth().signOut()
                    self.password = ""
                    self.activeAlert = .notVerified(email: self.email)
                }
            }
        }
    }

    // MARK: - Sign Up
    func signUp() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidEmail(trimmedEmail) else {
            activeAlert = .invalidEmail
            return
        }
        email = trimmedEmail

        let trimmedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Please enter your full name."
            return
        }
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return
        }
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }
        errorMessage = ""
        isLoading = true

        Auth.auth().createUser(withEmail: trimmedEmail, password: password) { [weak self] result, error in
            guard let self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    self.isLoading = false
                    let code = AuthErrorCode(rawValue: (error as NSError).code)
                    if code == .invalidEmail {
                        self.activeAlert = .invalidEmail
                    } else {
                        self.errorMessage = self.friendlyError(error)
                    }
                }
                return
            }

            guard let user = result?.user else {
                DispatchQueue.main.async { self.isLoading = false }
                return
            }

            // Set display name
            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = trimmedName
            changeRequest.commitChanges { _ in }

            // Send verification email
            user.sendEmailVerification { [weak self] _ in
                guard let self else { return }
                // Sign out so they must verify before accessing the app
                try? Auth.auth().signOut()
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.password = ""
                    self.confirmPassword = ""
                    // Show "check your inbox" alert
                    self.activeAlert = .verificationSent(email: trimmedEmail)
                }
            }
        }
    }

    // MARK: - Resend Verification Email
    /// Call when user taps "Resend" in the notVerified alert.
    func resendVerificationEmail() {
        isLoading = true
        // Temporarily sign in to get the user object, then send verification
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            guard let self else { return }
            DispatchQueue.main.async {
                self.isLoading = false
                if let user = result?.user {
                    user.sendEmailVerification { _ in
                        try? Auth.auth().signOut()
                    }
                    self.activeAlert = .resendSuccess
                }
            }
        }
    }

    // MARK: - Sign In with Google
    func signInWithGoogle() {
        // Read CLIENT_ID from whichever GoogleService-Info plist is bundled
        let plistNames = ["GoogleService-Info", "GoogleService-Info-2"]
        var clientID: String?
        for name in plistNames {
            if let path = Bundle.main.path(forResource: name, ofType: "plist"),
               let plist = NSDictionary(contentsOfFile: path),
               let id = plist["CLIENT_ID"] as? String {
                clientID = id
                break
            }
        }
        guard let clientID else {
            errorMessage = "Google Sign-In is not configured. Please check GoogleService-Info.plist."
            return
        }

        // Configure GIDSignIn with the client ID
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        // Get the topmost view controller to present the sign-in sheet
        guard
            let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
            let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else {
            errorMessage = "Unable to present Google Sign-In."
            return
        }

        errorMessage = ""

        GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { [weak self] result, error in
            guard let self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    // Don't show an error if the user simply cancelled
                    let nsError = error as NSError
                    if nsError.domain == "com.google.GIDSignIn" && nsError.code == -5 {
                        return // user cancelled — no spinner was shown, nothing to reset
                    }
                    self.errorMessage = error.localizedDescription
                }
                return
            }

            guard
                let user = result?.user,
                let idToken = user.idToken?.tokenString
            else {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to retrieve Google credentials. Please try again."
                }
                return
            }

            // User picked an account — now show loading while we call Firebase
            DispatchQueue.main.async { self.isLoading = true }

            // Exchange Google token for a Firebase credential
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )

            Auth.auth().signIn(with: credential) { [weak self] authResult, error in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.isLoading = false
                    if let error = error {
                        self.errorMessage = error.localizedDescription
                    } else {
                        // Google accounts are pre-verified — go straight into the app
                        self.isLoggedIn = true
                    }
                }
            }
        }
    }

    // MARK: - Sign Out
    func signOut() {
        try? Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut() // also clear Google session
        DispatchQueue.main.async {
            self.email = ""
            self.password = ""
            self.confirmPassword = ""
            self.fullName = ""
            self.errorMessage = ""
            self.activeAlert = nil
            self.currentStep = .email
            self.isLoggedIn = false
        }
    }

    // MARK: - Go back to email step
    func goBackToEmail() {
        password = ""
        confirmPassword = ""
        fullName = ""
        errorMessage = ""
        currentStep = .email
    }

    // MARK: - Helpers
    func isValidEmail(_ email: String) -> Bool {
        let regex = #"^[A-Z0-9a-z._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return email.range(of: regex, options: .regularExpression) != nil
    }

    private func friendlyError(_ error: Error) -> String {
        let code = AuthErrorCode(rawValue: (error as NSError).code)
        switch code {
        case .wrongPassword:
            return "Incorrect password. Please try again."
        case .userNotFound:
            return "No account found with this email."
        case .emailAlreadyInUse:
            return "An account with this email already exists."
        case .weakPassword:
            return "Password is too weak. Use at least 6 characters."
        case .invalidEmail:
            return "Please enter a valid email address."
        case .networkError:
            return "Network error. Please check your connection."
        case .tooManyRequests:
            return "Too many attempts. Please try again later."
        default:
            return error.localizedDescription
        }
    }
}
