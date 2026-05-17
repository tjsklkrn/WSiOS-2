//
//  RegistryRepository.swift
//  WSHackathonApp
//
//  Created by Nilesh Mahajan on 06/04/26.
//

import Combine
import Foundation

@MainActor
final class RegistryRepository: ObservableObject {
    
    // The mock logged-in user's ID – in production this comes from AuthViewModel
    let currentUserId: String = "user_me"
    
    @Published var registries: [Registry] = []
    @Published var currentRegistryId: UUID?
    
    var currentRegistry: Registry? {
        registries.first { $0.id == currentRegistryId }
    }
    
    // All registries visible to this user (owned + collaborated + public/protected ones)
    var allDiscoverableRegistries: [Registry] {
        // Own registries + seed registries + any protected ones the user has joined
        var all = registries  // user's own
        for seed in Self.seedRegistries {
            if !all.contains(where: { $0.id == seed.id }) {
                all.append(seed)
            }
        }
        return all
    }
    
    // MARK: - Seed Data (static, discoverable by search)
    static let seedRegistries: [Registry] = {
        let calendar = Calendar.current
        let id1 = UUID(uuidString: "A1000001-0000-0000-0000-000000000001")!
        let id2 = UUID(uuidString: "A1000002-0000-0000-0000-000000000002")!
        let id3 = UUID(uuidString: "A1000003-0000-0000-0000-000000000003")!
        let id4 = UUID(uuidString: "A1000004-0000-0000-0000-000000000004")!
        return [
            Registry(id: id1, firstName: "Priya", lastName: "Sharma",
                     event: .wedding,
                     date: calendar.date(from: DateComponents(year: 2026, month: 11, day: 15))!,
                     visibility: .public, items: [],
                     password: nil, ownerId: "user_seed1", collaboratorIds: []),
            Registry(id: id2, firstName: "Arjun", lastName: "Mehta",
                     event: .anniversary,
                     date: calendar.date(from: DateComponents(year: 2026, month: 8, day: 3))!,
                     visibility: .protected, items: [],
                     password: "baby2026", ownerId: "user_seed2", collaboratorIds: []),
            Registry(id: id3, firstName: "Sara", lastName: "Patel",
                     event: .housewarming,
                     date: calendar.date(from: DateComponents(year: 2026, month: 7, day: 20))!,
                     visibility: .public, items: [],
                     password: nil, ownerId: "user_seed3", collaboratorIds: []),
            Registry(id: id4, firstName: "Rahul", lastName: "Nair",
                     event: .birthday,
                     date: calendar.date(from: DateComponents(year: 2026, month: 9, day: 10))!,
                     visibility: .protected, items: [],
                     password: "rn1234", ownerId: "user_seed4", collaboratorIds: [])
        ]
    }()
    
    // MARK: - Search
    func search(firstName: String, lastName: String, registryId: String) -> [Registry] {
        let pool = allDiscoverableRegistries
        
        if !registryId.isEmpty {
            return pool.filter { reg in
                reg.id.uuidString.uppercased().hasPrefix(registryId.uppercased())
            }
        }
        
        return pool.filter { reg in
            let fnMatch = firstName.isEmpty || reg.firstName.localizedCaseInsensitiveContains(firstName)
            let lnMatch = lastName.isEmpty  || reg.lastName.localizedCaseInsensitiveContains(lastName)
            return fnMatch && lnMatch
        }
    }
    
    // MARK: - Collaborator Join
    /// Returns true if the user successfully joined (password correct or not protected)
    @discardableResult
    func joinRegistry(id: UUID, password enteredPassword: String) -> Bool {
        // Try own registries first
        if let idx = registries.firstIndex(where: { $0.id == id }) {
            let reg = registries[idx]
            if reg.visibility == .protected {
                guard reg.password == enteredPassword else { return false }
            }
            if !registries[idx].collaboratorIds.contains(currentUserId) {
                registries[idx].collaboratorIds.append(currentUserId)
            }
            return true
        }
        // Seed registries – not stored locally but validate password
        if let seed = Self.seedRegistries.first(where: { $0.id == id }) {
            if seed.visibility == .protected {
                return seed.password == enteredPassword
            }
            return true
        }
        return false
    }
    
    func isCollaborator(registryId: UUID) -> Bool {
        if let reg = allDiscoverableRegistries.first(where: { $0.id == registryId }) {
            return reg.collaboratorIds.contains(currentUserId)
        }
        return false
    }
    
    func isOwner(registryId: UUID) -> Bool {
        allDiscoverableRegistries.first(where: { $0.id == registryId })?.ownerId == currentUserId
    }
    
    // MARK: - Create
    var isActiveRegistry: Bool {
        !registries.isEmpty
    }
    
    func createRegistry(firstName: String,
                        lastName: String,
                        event: RegistryEvent,
                        date: Date,
                        visibility: RegistryVisibility = .public,
                        password: String? = nil) {
        
        let newRegistry = Registry(
            id: UUID(),
            firstName: firstName,
            lastName: lastName,
            event: event,
            date: date,
            visibility: visibility,
            items: [],
            password: visibility == .protected ? password : nil,
            ownerId: currentUserId,
            collaboratorIds: []
        )
        registries.append(newRegistry)
        currentRegistryId = newRegistry.id
    }
    
    // MARK: - Delete Registry
    func deleteRegistry(id: UUID) {
        registries.removeAll { $0.id == id }
        if currentRegistryId == id {
            currentRegistryId = registries.first?.id
        }
    }
    
    // MARK: - Add Product (for collaborator: specify ownerTag)
    func addProduct(_ product: ProductItem, addedBy userId: String? = nil) {
        guard let id = currentRegistryId else { return }
        guard let index = registries.firstIndex(where: { $0.id == id }) else { return }
        
        let price = product.price ?? 0.0
        let tagger = userId ?? currentUserId
        
        if let itemIndex = registries[index].items.firstIndex(where: { $0.id == product.id && $0.addedByUserId == tagger }) {
            registries[index].items[itemIndex].quantity += 1
        } else {
            registries[index].items.append(
                RegistryItem(
                    id: product.id,
                    title: product.title,
                    price: price,
                    imageUrl: product.path,
                    quantity: 1,
                    addedByUserId: tagger
                )
            )
        }
    }
    
    // MARK: - Remove Item
    func removeItem(_ productId: String, fromRegistryId id: UUID? = nil) {
        let targetId = id ?? currentRegistryId
        guard let registryId = targetId else { return }
        guard let index = registries.firstIndex(where: { $0.id == registryId }) else { return }
        registries[index].items.removeAll { $0.id == productId && $0.addedByUserId == currentUserId }
    }
    
    // MARK: - Update Quantity
    func increaseQty(_ productId: String, inRegistryId id: UUID? = nil) {
        let targetId = id ?? currentRegistryId
        guard let registryId = targetId else { return }
        guard let index = registries.firstIndex(where: { $0.id == registryId }) else { return }
        if let itemIndex = registries[index].items.firstIndex(where: { $0.id == productId && $0.addedByUserId == currentUserId }) {
            registries[index].items[itemIndex].quantity += 1
        }
    }
    
    func decreaseQty(_ productId: String, inRegistryId id: UUID? = nil) {
        let targetId = id ?? currentRegistryId
        guard let registryId = targetId else { return }
        guard let index = registries.firstIndex(where: { $0.id == registryId }) else { return }
        guard let itemIndex = registries[index].items.firstIndex(where: { $0.id == productId && $0.addedByUserId == currentUserId }) else { return }
        if registries[index].items[itemIndex].quantity > 1 {
            registries[index].items[itemIndex].quantity -= 1
        } else {
            registries[index].items.remove(at: itemIndex)
        }
    }
    
    func quantity(for registryItem: RegistryItem, inRegistryId id: UUID? = nil) -> Int {
        let targetId = id ?? currentRegistryId
        return registries.first(where: { $0.id == targetId })?.items.first(where: { $0.id == registryItem.id })?.quantity ?? 0
    }
}
