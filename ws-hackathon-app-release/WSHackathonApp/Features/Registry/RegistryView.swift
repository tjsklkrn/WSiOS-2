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
                Color(.systemGray6)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        
                        // MARK: - Header Image
                        GeometryReader { geometry in
                            Image(AppImages.Registry.header)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width, height: 200)
                                .clipped()
                        }
                        .frame(height: 200)
                        
                        // MARK: - Content
                        VStack(spacing: 16) {
                            
                            if viewModel.hasRegistry {
                                
                                registryHeader
                                
                                if viewModel.hasItems {
                                    registryItemsList
                                } else {
                                    emptyItemsView
                                }
                                
                            } else {
                                registryCard
                                instructionCard
                            }
                        }
                        .padding(.top, 16)
                    }
                }
            }
            .navigationTitle(AppStrings.Registry.title)
            .navigationBarTitleDisplayMode(.inline)
            
            // MARK: - Navigation
            
            .navigationDestination(for: RegistryRoute.self) { route in
                switch route {
                case .create:
                    CreateRegistryView()
                    
                case .success:
                    RegistrySuccessView()
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
    
    var registryCard: some View {
        VStack(spacing: 12) {

            // 1. CREATE A REGISTRY  (primary)
            Button {
                tabBarVM.registryPath.append(.create)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.black)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(AppStrings.Registry.create)
                            .font(.headline)
                            .foregroundColor(.black)
                        Text("Start adding gifts for your event")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: AppImages.Registry.chevron)
                        .foregroundColor(.gray)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)

            // 2. FIND A REGISTRY  (secondary)
            Button {
                // Navigate to registry search (future feature)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass.circle")
                        .font(.system(size: 22))
                        .foregroundColor(.black)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Find a Registry")
                            .font(.headline)
                            .foregroundColor(.black)
                        Text("Search for a friend or family registry")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: AppImages.Registry.chevron)
                        .foregroundColor(.gray)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)

            // 3. REGISTRY FAVOURITES BY CATEGORY
            registryFavouritesByCategory
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Registry Favourites by Category

    private static let registryCategories: [(icon: String, title: String, subtitle: String)] = [
        ("frying.pan",      "Cookware",    "Pots, pans & sets"),
        ("fork.knife",      "Dinnerware",  "Plates, bowls & mugs"),
        ("wineglass",       "Bar & Wine",  "Glasses & decanters"),
        ("refrigerator",    "Small Appliances", "Blenders, espresso & more"),
        ("tablecells",      "Cutlery",     "Knives & knife sets"),
        ("cabinet",         "Storage",     "Canisters & organisation")
    ]

    var registryFavouritesByCategory: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Registry Favourites by Category")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal, 4)

            let columns = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(RegistryView.registryCategories, id: \.title) { category in
                    Button {
                        // Navigate to category (future feature)
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: category.icon)
                                .font(.system(size: 26))
                                .foregroundColor(.black)
                                .frame(height: 32)
                            Text(category.title)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                            Text(category.subtitle)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 8)
                        .background(Color.white)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 0)
    }

    var createRegistryButton: some View {
        HStack(spacing: 12) {
            Image(systemName: AppImages.Registry.plus)
                .foregroundColor(.black)
            Text(AppStrings.Registry.create)
                .font(.headline)
                .foregroundColor(.black)
            Spacer()
            Image(systemName: AppImages.Registry.chevron)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    var instructionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            Text(AppStrings.Registry.topReasons)
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(viewModel.instructions.enumerated()), id: \.element.id) { index, item in
                    instructionRow(
                        title: item.title,
                        description: item.description
                    )
                    if index != viewModel.instructions.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
    
    func instructionRow(title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(description)
                .font(.footnote)
                .foregroundColor(.gray)
        }
    }
    
    var emptyItemsView: some View {
        Text(AppStrings.Registry.noItemsAdded)
            .foregroundColor(.gray)
            .padding()
    }
    
    var registryItemsList: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.items) { item in
                RegistryItemRow(
                    viewModel: RegistryItemRowViewModel(
                        item: item,
                        registryRepo: registryRepo,
                        cartRepo: cartRepo,
                        tabbarVM: tabBarVM
                    )
                )
            }
        }
        .padding(.horizontal, 16)
    }
    
    var registryHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            Text(viewModel.displayTitle)
                .font(.headline)
            
            Text(viewModel.displayDate)
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Button("Delete Registry") {
                viewModel.deleteRegistry(using: registryRepo)
            }
            .font(.caption)
            .foregroundColor(.red)
            .padding(.top, 4)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
}

