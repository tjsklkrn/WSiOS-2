//
//  ProfileCompletionView.swift
//  WSHackathonApp
//
//  Created by AI Assistant
//

import SwiftUI

struct ProfileCompletionView: View {
    @EnvironmentObject var profileRepo: ProfileRepository
    @EnvironmentObject var authVM: AuthViewModel
    
    @State private var fullName: String = ""
    @State private var phoneNumber: String = ""
    @State private var dateOfBirth: String = ""
    @State private var gender: String = ""
    @State private var address: String = ""
    
    var isFormValid: Bool {
        !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !dateOfBirth.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !gender.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    Text("Welcome!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Please complete your profile to continue.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    VStack(spacing: 16) {
                        profileField(title: AppStrings.Profile.fullName, text: $fullName)
                        profileField(title: AppStrings.Profile.phoneNumber, text: $phoneNumber)
                            .keyboardType(.phonePad)
                        profileField(title: AppStrings.Profile.dateOfBirth, text: $dateOfBirth)
                        profileField(title: AppStrings.Profile.gender, text: $gender)
                        profileField(title: AppStrings.Profile.address, text: $address)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    
                    Button(action: saveProfile) {
                        Text(AppStrings.Profile.saveButton)
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isFormValid ? Color.black : Color.gray)
                            .cornerRadius(10)
                    }
                    .disabled(!isFormValid)
                    .padding(.top, 16)
                    
                    Button(action: {
                        authVM.signOut()
                    }) {
                        Text("Sign Out")
                            .foregroundColor(.red)
                            .padding(.top, 8)
                    }
                }
                .padding()
            }
            .background(Color(.systemGray6).ignoresSafeArea())
            .navigationTitle(AppStrings.Profile.completeProfileTitle)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let name = authVM.fullName.isEmpty ? nil : authVM.fullName {
                    fullName = name
                }
            }
        }
    }
    
    @ViewBuilder
    private func profileField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            TextField(title, text: text)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
    }
    
    private func saveProfile() {
        let profile = UserProfile(
            fullName: fullName,
            phoneNumber: phoneNumber,
            dateOfBirth: dateOfBirth,
            gender: gender,
            address: address
        )
        profileRepo.saveProfile(profile)
    }
}
