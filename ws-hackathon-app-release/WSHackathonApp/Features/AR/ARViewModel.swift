//
//  ARViewModel.swift
//  WSHackathonApp
//

import SwiftUI
import RealityKit
import ARKit

@MainActor
final class ARViewModel: ObservableObject {
    @Published var selectedModelName: String = "plate"
    @Published var isModelPlaced: Bool = false
    @Published var isLoading: Bool = false
    @Published var isSurfaceDetected: Bool = false
    
    // Available products to switch between
    let availableProducts = [
        ("plate", "Plate"),
        ("bowl", "Bowl"),
        ("mug", "Mug"),
        ("cupset", "Cup Set")
    ]
    
    // Store reference to the currently active entity to remove or change it
    var currentEntity: ModelEntity?
    var anchorEntity: AnchorEntity?
    
    nonisolated private func loadUSDZ(name: String) -> ModelEntity? {
        try? ModelEntity.loadModel(named: name)
    }

    // Safely load a model, using a fallback if the USDZ is not found in the bundle.
    func loadModel(name: String) async -> ModelEntity {
        isLoading = true
        defer { isLoading = false }
        
        // Try loading synchronously (safe enough for small local USDZ in this context)
        if let entity = loadUSDZ(name: name) {
            entity.generateCollisionShapes(recursive: true)
            return entity
        }
        
        // Fallback: Generate a high-quality basic shape representing the crockery item
        let fallback = createFallbackModel(for: name)
        fallback.generateCollisionShapes(recursive: true)
        return fallback
    }
    
    private func createFallbackModel(for name: String) -> ModelEntity {
        // Luxury subtle ceramic-like material
        var material = SimpleMaterial(color: .white, isMetallic: false)
        material.roughness = 0.2
        
        let mesh: MeshResource
        
        switch name {
        case "plate":
            mesh = .generateBox(size: SIMD3<Float>(0.24, 0.015, 0.24), cornerRadius: 0.12)
        case "bowl":
            mesh = .generateSphere(radius: 0.08)
        case "mug":
            mesh = .generateBox(size: SIMD3<Float>(0.09, 0.1, 0.09), cornerRadius: 0.045)
        case "cupset":
            mesh = .generateBox(size: SIMD3<Float>(0.15, 0.08, 0.15), cornerRadius: 0.01)
        default:
            mesh = .generateBox(size: 0.1)
        }
        
        return ModelEntity(mesh: mesh, materials: [material])
    }
}
