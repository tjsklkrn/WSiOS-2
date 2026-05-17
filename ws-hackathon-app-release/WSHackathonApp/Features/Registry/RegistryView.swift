//
//  RegistryView.swift
//  WSHackathonApp
//
//  Created by Nilesh Mahajan on 03/04/26.
//

import SwiftUI

enum RegistryRoute: Hashable {
    case create
    case success
}

struct RegistryView: View {

    @StateObject private var viewModel = RegistryViewModel()

    @EnvironmentObject var registryRepo: RegistryRepository
    @EnvironmentObject var cartRepo: CartRepository
    @EnvironmentObject var tabBarVM: WSTabBarViewModel

    var body: some View {
        NavigationStack(path: $tabBarVM.registryPath) {
            ZStack {
                Color.white.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {

                        // MARK: - Hero Image
                        GeometryReader { geometry in
                            Image(AppImages.Registry.header)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width, height: 240)
                                .clipped()
                                .overlay(
                                    // Dark gradient at bottom for text legibility
                                    LinearGradient(
                                        colors: [.clear, .black.opacity(0.4)],
                                        startPoint: .center,
                                        endPoint: .bottom
                                    )
                                )
                        }
                        .frame(height: 240)

                        // MARK: - Content
                        VStack(spacing: 0) {

                            if viewModel.hasRegistry {
                                registryHeader
                                    .padding(.top, 24)

                                if viewModel.hasItems {
                                    registryItemsList
                                        .padding(.top, 20)
                                } else {
                                    emptyItemsView
                                }

                            } else {
                                noRegistryContent
                            }
                        }
                    }
                }
            }
            .navigationTitle(AppStrings.Registry.title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: RegistryRoute.self) { route in
                switch route {
                case .create: CreateRegistryView()
                case .success: RegistrySuccessView()
                }
            }
        }
        .onAppear {
            viewModel.bind(repository: registryRepo)
        }
    }
}

// MARK: - Components
private extension RegistryView {

    var noRegistryContent: some View {
        VStack(spacing: 0) {

            // Action Buttons
            VStack(spacing: 2) {
                // Create Registry
                Button {
                    tabBarVM.registryPath.append(.create)
                } label: {
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Create A Registry")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(.black)
                            Text("Start adding gifts for your event")
                                .font(.system(size: 13))
                                .foregroundColor(Color(white: 0.5))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(white: 0.5))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                    .background(Color.white)
                    .overlay(Rectangle().stroke(Color(white: 0.88), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)

                // Find Registry
                Button {
                    // Future feature
                } label: {
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Find a Registry")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(.black)
                            Text("Search for a friend or family registry!")
                                .font(.system(size: 13))
                                .foregroundColor(Color(white: 0.5))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(white: 0.5))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                    .background(Color.white)
                    .overlay(Rectangle().stroke(Color(white: 0.88), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
            }

            // MARK: - Registry Categories
            VStack(alignment: .leading, spacing: 0) {
                Rectangle()
                    .fill(Color(white: 0.88))
                    .frame(height: 1)
                    .padding(.horizontal, 16)
                    .padding(.top, 32)
                    .padding(.bottom, 20)

                Text("Registry Favourites by Category")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)

                let columns = [GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2)]
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(RegistryView.registryCategories, id: \.title) { category in
                        Button {
                            // future
                        } label: {
                            VStack(spacing: 10) {
                                Image(systemName: category.icon)
                                    .font(.system(size: 24, weight: .light))
                                    .foregroundColor(.black)
                                    .frame(height: 28)
                                Text(category.title)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.black)
                                    .tracking(0.3)
                                Text(category.subtitle)
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(white: 0.5))
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .padding(.horizontal, 8)
                            .background(Color(white: 0.97))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }

            // MARK: - Why Register
            VStack(alignment: .leading, spacing: 0) {
                Rectangle()
                    .fill(Color(white: 0.88))
                    .frame(height: 1)
                    .padding(.horizontal, 16)
                    .padding(.top, 32)
                    .padding(.bottom, 20)

                Text(AppStrings.Registry.topReasons)
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1.5)
                    .foregroundColor(Color(white: 0.5))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)

                VStack(spacing: 0) {
                    ForEach(Array(viewModel.instructions.enumerated()), id: \.element.id) { index, item in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(item.title)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.black)
                            Text(item.description)
                                .font(.system(size: 12))
                                .foregroundColor(Color(white: 0.45))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)
                        .background(Color.white)

                        if index < viewModel.instructions.count - 1 {
                            Rectangle()
                                .fill(Color(white: 0.9))
                                .frame(height: 1)
                                .padding(.horizontal, 20)
                        }
                    }
                }
                .overlay(Rectangle().stroke(Color(white: 0.88), lineWidth: 1))
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
    }

    private static let registryCategories: [(icon: String, title: String, subtitle: String)] = [
        ("frying.pan",      "Cookware",         "Pots, pans & sets"),
        ("fork.knife",      "Dinnerware",       "Plates, bowls & mugs"),
        ("wineglass",       "Bar & Wine",       "Glasses & decanters"),
        ("refrigerator",    "Small Appliances", "Blenders, espresso & more"),
        ("tablecells",      "Cutlery",          "Knives & knife sets"),
        ("cabinet",         "Storage",          "Canisters & organisation")
    ]

    var emptyItemsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundColor(Color(white: 0.7))
                .padding(.top, 32)
            Text("No items added yet")
                .font(.system(size: 13))
                .foregroundColor(Color(white: 0.5))
        }
        .padding(.bottom, 40)
    }

    var registryItemsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                RegistryItemRow(
                    viewModel: RegistryItemRowViewModel(
                        item: item,
                        registryRepo: registryRepo,
                        cartRepo: cartRepo,
                        tabbarVM: tabBarVM
                    )
                )
                if index < viewModel.items.count - 1 {
                    Rectangle()
                        .fill(Color(white: 0.9))
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                }
            }
        }
        .padding(.bottom, 40)
    }

    var registryHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                Text("YOUR REGISTRY")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1.5)
                    .foregroundColor(Color(white: 0.5))
                Text(viewModel.displayTitle)
                    .font(.system(size: 22, weight: .light))
                    .foregroundColor(.black)
                Text(viewModel.displayDate)
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.5))
                    .padding(.top, 2)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)

            Rectangle()
                .fill(Color(white: 0.88))
                .frame(height: 1)
                .padding(.horizontal, 16)

            Button("Delete Registry") {
                viewModel.deleteRegistry(using: registryRepo)
            }
            .font(.system(size: 11, weight: .medium))
            .tracking(0.5)
            .foregroundColor(Color(red: 0.64, green: 0.07, blue: 0.07))
            .padding(.horizontal, 16)
            .padding(.top, 14)
        }
    }
}
