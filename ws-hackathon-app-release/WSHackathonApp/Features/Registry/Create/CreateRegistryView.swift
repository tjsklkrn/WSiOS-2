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

    @State private var navigateToSuccess = false

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // MARK: - Header
                    VStack(alignment: .leading, spacing: 6) {
                        Text("CREATE YOUR")
                            .font(.system(size: 11, weight: .medium))
                            .tracking(1.8)
                            .foregroundColor(Color(white: 0.5))
                        Text("Registry")
                            .font(.system(size: 32, weight: .light))
                            .foregroundColor(.black)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                    .padding(.bottom, 28)

                    Rectangle()
                        .fill(Color(white: 0.88))
                        .frame(height: 1)
                        .padding(.horizontal, 20)

                    // MARK: - Form Fields
                    Group {
                        WSRegistryField(
                            label: "FIRST NAME",
                            placeholder: "Enter first name",
                            text: $viewModel.firstName
                        )
                        Rectangle().fill(Color(white: 0.9)).frame(height: 1).padding(.horizontal, 20)

                        WSRegistryField(
                            label: "LAST NAME",
                            placeholder: "Enter last name",
                            text: $viewModel.lastName
                        )
                        Rectangle().fill(Color(white: 0.9)).frame(height: 1).padding(.horizontal, 20)
                    }

                    // Event Type
                    VStack(alignment: .leading, spacing: 6) {
                        Text("EVENT TYPE")
                            .font(.system(size: 9, weight: .medium))
                            .tracking(1.3)
                            .foregroundColor(Color(white: 0.5))

                        Picker(AppStrings.Registry.event, selection: $viewModel.selectedEvent) {
                            ForEach(RegistryEvent.allCases) { event in
                                Text(event.title).tag(event)
                            }
                        }
                        .pickerStyle(.menu)
                        .accentColor(.black)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, -4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)

                    Rectangle().fill(Color(white: 0.9)).frame(height: 1).padding(.horizontal, 20)

                    // Event Date
                    VStack(alignment: .leading, spacing: 6) {
                        Text("EVENT DATE")
                            .font(.system(size: 9, weight: .medium))
                            .tracking(1.3)
                            .foregroundColor(Color(white: 0.5))

                        DatePicker(
                            "",
                            selection: $viewModel.date,
                            in: Date()...,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .accentColor(.black)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)

                    Rectangle().fill(Color(white: 0.88)).frame(height: 1).padding(.horizontal, 20)

                    // MARK: - Info Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 14) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 16, weight: .light))
                                .foregroundColor(.black)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("10% Completion Discount")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.black)
                                Text("Enjoy savings on remaining registry items after your event.")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(white: 0.45))
                            }
                        }
                        HStack(spacing: 14) {
                            Image(systemName: "gift")
                                .font(.system(size: 16, weight: .light))
                                .foregroundColor(.black)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Free Expert Advice")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.black)
                                Text("In-store or online, we'll help you build the perfect registry.")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(white: 0.45))
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)

                    // MARK: - Create Button
                    Button {
                        registryRepo.createRegistry(
                            firstName: viewModel.firstName,
                            lastName: viewModel.lastName,
                            event: viewModel.selectedEvent,
                            date: viewModel.date
                        )
                        navigateToSuccess = true
                    } label: {
                        Text("CREATE REGISTRY")
                            .font(.system(size: 12, weight: .medium))
                            .tracking(1.5)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(viewModel.isValid ? Color.black : Color(white: 0.7))
                            .foregroundColor(.white)
                    }
                    .disabled(!viewModel.isValid)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .buttonStyle(.plain)

                    Spacer(minLength: 48)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToSuccess) {
            RegistrySuccessView()
        }
    }
}

// MARK: - WS Registry Form Field

private struct WSRegistryField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .tracking(1.3)
                .foregroundColor(Color(white: 0.5))
            TextField(placeholder, text: $text)
                .font(.system(size: 14))
                .foregroundColor(.black)
                .padding(.vertical, 4)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}
