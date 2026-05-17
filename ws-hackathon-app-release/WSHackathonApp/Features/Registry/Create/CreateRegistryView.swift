//
//  CreateRegistryView.swift
//  WSHackathonApp
//
//  Created by Nilesh Mahajan on 04/04/26.
//

import SwiftUI

struct CreateRegistryView: View {
    
    @StateObject private var viewModel = CreateRegistryViewModel()
    @EnvironmentObject var tabBarVM: WSTabBarViewModel
    @EnvironmentObject var registryRepo: RegistryRepository
    @Environment(\.dismiss) var dismiss
    
    @State private var navigateToSuccess = false
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        
                        // MARK: - Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CREATE YOUR")
                                .font(.system(size: 11, weight: .medium))
                                .tracking(1.5)
                                .foregroundColor(Color(white: 0.5))
                            
                            Text("Registry")
                                .font(.system(size: 34, weight: .light))
                                .foregroundColor(.black)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 24)
                        
                        Rectangle()
                            .fill(Color(white: 0.9))
                            .frame(height: 1)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)
                        
                        // MARK: - Form fields
                        VStack(alignment: .leading, spacing: 24) {
                            
                            // First Name
                            VStack(alignment: .leading, spacing: 8) {
                                Text("FIRST NAME")
                                    .font(.system(size: 10, weight: .medium))
                                    .tracking(1.5)
                                    .foregroundColor(Color(white: 0.5))
                                TextField("Enter first name", text: $viewModel.firstName)
                                    .font(.system(size: 16))
                                    .foregroundColor(.black)
                                Rectangle()
                                    .fill(Color(white: 0.9))
                                    .frame(height: 1)
                                    .padding(.top, 4)
                            }
                            
                            // Last Name
                            VStack(alignment: .leading, spacing: 8) {
                                Text("LAST NAME")
                                    .font(.system(size: 10, weight: .medium))
                                    .tracking(1.5)
                                    .foregroundColor(Color(white: 0.5))
                                TextField("Enter last name", text: $viewModel.lastName)
                                    .font(.system(size: 16))
                                    .foregroundColor(.black)
                                Rectangle()
                                    .fill(Color(white: 0.9))
                                    .frame(height: 1)
                                    .padding(.top, 4)
                            }
                            
                            // Event Type
                            VStack(alignment: .leading, spacing: 8) {
                                Text("EVENT TYPE")
                                    .font(.system(size: 10, weight: .medium))
                                    .tracking(1.5)
                                    .foregroundColor(Color(white: 0.5))
                                
                                Picker("", selection: $viewModel.selectedEvent) {
                                    ForEach(RegistryEvent.allCases) { event in
                                        Text(event.title).tag(event)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .accentColor(.black)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Rectangle()
                                    .fill(Color(white: 0.9))
                                    .frame(height: 1)
                                    .padding(.top, 4)
                            }
                            
                            // Event Date
                            VStack(alignment: .leading, spacing: 8) {
                                Text("EVENT DATE")
                                    .font(.system(size: 10, weight: .medium))
                                    .tracking(1.5)
                                    .foregroundColor(Color(white: 0.5))
                                
                                DatePicker(
                                    "",
                                    selection: $viewModel.date,
                                    in: Date()...,
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .padding(.top, 4)
                                
                                Rectangle()
                                    .fill(Color(white: 0.9))
                                    .frame(height: 1)
                                    .padding(.top, 12)
                            }
                            
                            // Visibility
                            VStack(alignment: .leading, spacing: 8) {
                                Text("VISIBILITY")
                                    .font(.system(size: 10, weight: .medium))
                                    .tracking(1.5)
                                    .foregroundColor(Color(white: 0.5))
                                
                                Picker("", selection: $viewModel.visibility) {
                                    ForEach(RegistryVisibility.allCases) { vis in
                                        Text(vis.title).tag(vis)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .accentColor(.black)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Rectangle()
                                    .fill(Color(white: 0.9))
                                    .frame(height: 1)
                                    .padding(.top, 4)
                            }
                            
                            if viewModel.visibility == .protected {
                                // Password
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("PASSWORD")
                                        .font(.system(size: 10, weight: .medium))
                                        .tracking(1.5)
                                        .foregroundColor(Color(white: 0.5))
                                    SecureField("Enter registry password", text: $viewModel.password)
                                        .font(.system(size: 16))
                                        .foregroundColor(.black)
                                    Rectangle()
                                        .fill(Color(white: 0.9))
                                        .frame(height: 1)
                                        .padding(.top, 4)
                                }
                            }
                            
                        }
                        .padding(.horizontal, 20)
                        
                        // MARK: - Perks
                        VStack(alignment: .leading, spacing: 20) {
                            HStack(alignment: .top, spacing: 16) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 20, weight: .light))
                                    .foregroundColor(.black)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("10% Completion Discount")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.black)
                                    Text("Enjoy savings on remaining registry items after\nyour event.")
                                        .font(.system(size: 13))
                                        .foregroundColor(Color(white: 0.5))
                                }
                            }
                            
                            HStack(alignment: .top, spacing: 16) {
                                Image(systemName: "gift")
                                    .font(.system(size: 20, weight: .light))
                                    .foregroundColor(.black)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Free Expert Advice")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.black)
                                    Text("In-store or online, we'll help you build the perfect registry.")
                                        .font(.system(size: 13))
                                        .foregroundColor(Color(white: 0.5))
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 32)
                        .padding(.bottom, 40)
                    }
                }
                
                // MARK: - Create Button
                Button(action: {
                    registryRepo.createRegistry(
                        firstName: viewModel.firstName,
                        lastName: viewModel.lastName,
                        event: viewModel.selectedEvent,
                        date: viewModel.date,
                        visibility: viewModel.visibility,
                        password: viewModel.visibility == .protected ? viewModel.password : nil
                    )
                    navigateToSuccess = true
                }) {
                    Text("CREATE REGISTRY")
                        .font(.system(size: 13, weight: .medium))
                        .tracking(1.5)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(viewModel.isValid ? Color.black : Color(white: 0.85))
                }
                .disabled(!viewModel.isValid)
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                        .frame(width: 44, height: 44)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                }
            }
        }
        .navigationDestination(isPresented: $navigateToSuccess) {
            RegistrySuccessView()
        }
    }
}

#Preview {
    CreateRegistryView()
}
