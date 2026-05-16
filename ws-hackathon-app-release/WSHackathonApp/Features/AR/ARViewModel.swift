//
//  ARViewModel.swift
//  WSHackathonApp
//

import SwiftUI
import RealityKit
import ARKit

@MainActor
final class ARViewModel: ObservableObject {
    @Published var isModelPlaced: Bool = false
    @Published var isLoading: Bool = false
    @Published var productImage: UIImage? = nil

    var currentAnchor: AnchorEntity?

    // MARK: - Image Download

    func downloadProductImage(from url: URL) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                self.productImage = image
            }
        } catch {
            print("AR: Failed to download product image: \(error)")
        }
    }

    // MARK: - 3D Entity Creation

    /// Creates a 3D box entity with the product image applied to the top face,
    /// and a realistic material on the sides — giving a true 3D appearance.
    func create3DProductEntity(from image: UIImage) -> ModelEntity {
        let aspectRatio = Float(image.size.width / image.size.height)

        // Real-world size: 25 cm wide, proportional depth
        let width: Float = 0.25
        let depth: Float = width / aspectRatio
        let height: Float = width * 0.04  // thickness ~4% of width

        // Build a box mesh
        let mesh = MeshResource.generateBox(size: [width, height, depth])

        // --- Top face material: product image ---
        var topMaterial = UnlitMaterial()
        if let cgImage = image.cgImage {
            do {
                let texture = try TextureResource.generate(from: cgImage, options: .init(semantic: .color))
                topMaterial.color = .init(tint: .white, texture: .init(texture))
            } catch {
                topMaterial.color = .init(tint: .white)
            }
        }

        // --- Side/bottom material: neutral off-white like product packaging ---
        var sideMaterial = SimpleMaterial(color: UIColor(white: 0.92, alpha: 1.0), isMetallic: false)
        sideMaterial.roughness = 0.6

        // RealityKit box has 6 faces in this order:
        // right, left, top, bottom, front, back
        let entity = ModelEntity(
            mesh: mesh,
            materials: [sideMaterial, sideMaterial, topMaterial, sideMaterial, sideMaterial, sideMaterial]
        )

        entity.generateCollisionShapes(recursive: true)
        return entity
    }

    // MARK: - Reset

    func resetPlacement(in scene: RealityKit.Scene) {
        if let anchor = currentAnchor {
            scene.removeAnchor(anchor)
            currentAnchor = nil
        }
        isModelPlaced = false
    }
}
