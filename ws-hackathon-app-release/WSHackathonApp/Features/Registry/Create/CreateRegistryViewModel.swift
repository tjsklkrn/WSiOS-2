//
//  CreateRegistryViewModel.swift
//  WSHackathonApp
//
//  Created by Nilesh Mahajan on 06/04/26.
//

import Foundation
import Combine

@MainActor
final class CreateRegistryViewModel: ObservableObject {
    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var selectedEvent: RegistryEvent = .birthday
    @Published var date: Date = Date()
    @Published var visibility: RegistryVisibility = .public
    @Published var password: String = ""
    
    var isValid: Bool {
        if visibility == .protected && password.isEmpty {
            return false
        }
        return !firstName.isEmpty && !lastName.isEmpty
    }
}
