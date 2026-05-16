//
//  WSHackathonAppApp.swift
//  WSHackathonApp
//
//  Created by Nilesh Mahajan on 03/04/26.
//

import SwiftUI
import FirebaseCore
import GoogleSignIn

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions:
        [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }

    // MARK: - Handle Google Sign-In URL callback
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}

@main
struct WSHackathonAppApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self)
    var delegate

    @StateObject private var registryRepo = RegistryRepository()
    @StateObject private var cartRepo = CartRepository()
    @StateObject private var tabBarVM = WSTabBarViewModel()
    @StateObject private var authVM = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            if authVM.isLoggedIn {
                WSTabView()
                    .environmentObject(registryRepo)
                    .environmentObject(cartRepo)
                    .environmentObject(tabBarVM)
                    .environmentObject(authVM)
            } else {
                AuthContainerView()
                    .environmentObject(authVM)
            }
        }
    }
}
