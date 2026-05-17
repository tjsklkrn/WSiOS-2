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
    case find
    case category(String)
    case manage
    case registryDetail(UUID)
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

                            noRegistryContent
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
                case .find: FindRegistryView()
                case .category(let name): CategoryProductsView(category: name)
                case .manage: ManageRegistryView()
                case .registryDetail(let id): RegistryDetailView(registryId: id)
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

            // Section header
            VStack(spacing: 6) {
                Text("YOUR REGISTRY")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1.5)
                    .foregroundColor(Color(white: 0.5))
                    .padding(.top, 28)

                Text("Celebrate Every Occasion")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.black)

                Text("Create a registry for your wedding, baby shower,\nhousewarming, or any special event.")
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.45))
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
                    .padding(.horizontal, 32)
            }
            .padding(.bottom, 28)

            // Divider
            Rectangle()
                .fill(Color(white: 0.88))
                .frame(height: 1)
                .padding(.horizontal, 16)
                .padding(.bottom, 24)

            // Action Buttons
            VStack(spacing: 0) {
                // Create Registry
                Button {
                    tabBarVM.registryPath.append(.create)
                } label: {
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("CREATE A REGISTRY")
                                .font(.system(size: 11, weight: .medium))
                                .tracking(1.2)
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
                }
                .buttonStyle(.plain)

                // Divider between buttons
                Rectangle()
                    .fill(Color(white: 0.88))
                    .frame(height: 1)

                // Find Registry
                Button {
                    tabBarVM.registryPath.append(.find)
                } label: {
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("FIND A REGISTRY")
                                .font(.system(size: 11, weight: .medium))
                                .tracking(1.2)
                                .foregroundColor(.black)
                            Text("Search for a friend or family registry")
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
                }
                .buttonStyle(.plain)

                // Divider between buttons
                Rectangle()
                    .fill(Color(white: 0.88))
                    .frame(height: 1)

                // Manage Registry
                Button {
                    tabBarVM.registryPath.append(.manage)
                } label: {
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("MANAGE YOUR REGISTRY")
                                .font(.system(size: 11, weight: .medium))
                                .tracking(1.2)
                                .foregroundColor(.black)
                            Text("Update settings and track gifts")
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
                }
                .buttonStyle(.plain)
            }
            .overlay(Rectangle().stroke(Color(white: 0.88), lineWidth: 1))
            .padding(.horizontal, 16)

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
                            tabBarVM.registryPath.append(.category(category.title))
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

}
