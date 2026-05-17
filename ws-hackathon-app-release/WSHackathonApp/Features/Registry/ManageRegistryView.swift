import SwiftUI

struct ManageRegistryView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var registryRepo: RegistryRepository
    @EnvironmentObject var tabBarVM: WSTabBarViewModel
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Navigation Bar
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                            .frame(width: 44, height: 44)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    }
                    
                    Spacer()
                    
                    Text("MANAGE REGISTRIES")
                        .font(.system(size: 13, weight: .medium))
                        .tracking(1.5)
                    
                    Spacer()
                    
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 16)
                
                Rectangle()
                    .fill(Color(white: 0.9))
                    .frame(height: 1)
                
                if registryRepo.registries.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 36, weight: .ultraLight))
                            .foregroundColor(Color(white: 0.7))
                        Text("You haven't created any registries yet.")
                            .font(.system(size: 13))
                            .foregroundColor(Color(white: 0.5))
                        
                        Button {
                            dismiss()
                            tabBarVM.registryPath.append(.create)
                        } label: {
                            Text("CREATE A REGISTRY")
                                .font(.system(size: 11, weight: .medium))
                                .tracking(1.2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.black)
                        }
                        .padding(.top, 8)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(registryRepo.registries) { registry in
                                Button {
                                    registryRepo.currentRegistryId = registry.id
                                    tabBarVM.registryPath.append(.registryDetail(registry.id))
                                } label: {
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack {
                                            Text(registry.displayName)
                                                .font(.system(size: 18, weight: .medium))
                                                .foregroundColor(.black)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(Color(white: 0.5))
                                        }
                                        
                                        HStack {
                                            Text("Items: \(registry.items.count)")
                                                .font(.system(size: 13))
                                                .foregroundColor(Color(white: 0.5))
                                            
                                            Spacer()
                                            
                                            Text(registry.visibility.title)
                                                .font(.system(size: 11, weight: .medium))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color(.systemGray6))
                                                .cornerRadius(4)
                                                .foregroundColor(.black)
                                        }
                                    }
                                    .padding(20)
                                    .background(Color.white)
                                    .overlay(Rectangle().stroke(Color(white: 0.88), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(20)
                    }
                }
            }
        }
        .navigationBarHidden(true)
    }
}
