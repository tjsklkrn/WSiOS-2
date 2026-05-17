//
//  ProfileRepository.swift
//  WSHackathonApp
//
//  Created by AI Assistant
//

import Foundation
import Combine
import FirebaseAuth

@MainActor
final class ProfileRepository: ObservableObject {
    
    @Published private(set) var currentProfile: UserProfile?
    @Published private(set) var hasCompletedProfile: Bool = false
    
    private var authStateDidChangeListenerHandle: AuthStateDidChangeListenerHandle?
    
    init() {
        authStateDidChangeListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.loadProfile()
            }
        }
    }
    
    deinit {
        if let handle = authStateDidChangeListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    // MARK: - Persistence
    private var profileKey: String {
        let uid = Auth.auth().currentUser?.uid ?? "anonymous"
        return "user_profile_\(uid)"
    }
    
    func saveProfile(_ profile: UserProfile) {
        if let encoded = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(encoded, forKey: profileKey)
            self.currentProfile = profile
            self.hasCompletedProfile = true
        }
    }
    
    func loadProfile() {
        if let data = UserDefaults.standard.data(forKey: profileKey),
           let decoded = try? JSONDecoder().decode(UserProfile.self, from: data) {
            self.currentProfile = decoded
            self.hasCompletedProfile = true
        } else {
            self.currentProfile = nil
            self.hasCompletedProfile = false
        }
    }
}
