//
//  Registry.swift
//  WSHackathonApp
//
//  Created by Nilesh Mahajan on 06/04/26.
//

import Foundation

enum RegistryVisibility: String, CaseIterable, Identifiable {
    case `public` = "Public"
    case `private` = "Private"
    case protected = "Protected"
    
    var id: String { self.rawValue }
    var title: String { self.rawValue }
}

struct Registry: Identifiable {
    let id: UUID
    let firstName: String
    let lastName: String
    let event: RegistryEvent
    let date: Date
    let visibility: RegistryVisibility
    var items: [RegistryItem]
    var password: String?         // only set when visibility == .protected
    let ownerId: String           // mock user id of registry creator
    var collaboratorIds: [String] // users who joined via password
    
    var displayName: String {
        "\(firstName) \(lastName) - \(event.title)"
    }
}
