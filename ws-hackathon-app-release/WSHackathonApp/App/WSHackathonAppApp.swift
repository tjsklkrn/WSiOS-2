//
//  WSHackathonAppApp.swift
//  WSHackathonApp
//
//  Created by Nilesh Mahajan on 03/04/26.
//

import SwiftUI

@main
struct WSHackathonAppApp: App {
    @StateObject private var registryRepo = RegistryRepository()
    @StateObject private var cartRepo = CartRepository()
    @StateObject private var tabBarVM = WSTabBarViewModel()
    @StateObject private var wishlistRepo = WishlistRepository()

    init() {
        applyGlobalAppearance()
    }

    var body: some Scene {
        WindowGroup {
            WSTabView()
                .environmentObject(registryRepo)
                .environmentObject(cartRepo)
                .environmentObject(tabBarVM)
                .environmentObject(wishlistRepo)
        }
    }

    private func applyGlobalAppearance() {
        // MARK: - Tab Bar (Williams-Sonoma: clean white, black icons)
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = .white
        tabAppearance.shadowColor = UIColor(white: 0.88, alpha: 1.0)

        // Normal state: light gray
        let normalAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: UIColor(white: 0.6, alpha: 1.0)
        ]
        tabAppearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttrs
        tabAppearance.stackedLayoutAppearance.normal.iconColor = UIColor(white: 0.6, alpha: 1.0)

        // Selected state: pure black
        let selectedAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: UIColor.black
        ]
        tabAppearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttrs
        tabAppearance.stackedLayoutAppearance.selected.iconColor = UIColor.black

        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        // MARK: - Navigation Bar (Williams-Sonoma: clean white, black text)
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = .white
        navAppearance.shadowColor = UIColor(white: 0.88, alpha: 1.0)

        // Large title: slightly lighter weight for premium feel
        navAppearance.largeTitleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 34, weight: .light),
            .foregroundColor: UIColor.black
        ]
        // Inline title
        navAppearance.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 16, weight: .regular),
            .foregroundColor: UIColor.black
        ]

        // Compact (inline) appearance — transparent so the custom in-scroll title is the hero
        let inlineNavAppearance = UINavigationBarAppearance()
        inlineNavAppearance.configureWithTransparentBackground()
        inlineNavAppearance.backgroundColor = UIColor.white.withAlphaComponent(0.95)
        inlineNavAppearance.shadowColor = .clear
        inlineNavAppearance.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 16, weight: .regular),
            .foregroundColor: UIColor.black
        ]

        UINavigationBar.appearance().standardAppearance = inlineNavAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = inlineNavAppearance
        UINavigationBar.appearance().tintColor = .black
    }
}
