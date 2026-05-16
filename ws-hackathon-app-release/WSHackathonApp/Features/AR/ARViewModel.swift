//
//  ARViewModel.swift
//  WSHackathonApp
//

import SwiftUI
import RealityKit
import ARKit
import Combine

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
            if let img = UIImage(data: data) {
                self.productImage = img
            }
        } catch {
            print("AR: image download failed: \(error)")
        }
    }

    // MARK: - Build AR Entity

    /// Creates a vertical standing card with the product photo at real-world scale.
    /// This is the same technique used by IKEA Place and Amazon AR View.
    func buildProductEntity(from image: UIImage) -> ModelEntity {
        let aspectRatio = Float(image.size.width / image.size.height)

        // Real-world size: 30 cm tall, width proportional
        let cardHeight: Float = 0.30
        let cardWidth: Float = cardHeight * aspectRatio

        // Flat plane — we rotate it to stand vertical after placement
        let mesh = MeshResource.generatePlane(width: cardWidth, height: cardHeight)

        var material = UnlitMaterial()
        if let cg = image.cgImage,
           let texture = try? TextureResource.generate(from: cg, options: .init(semantic: .color)) {
            material.color = .init(tint: .white, texture: .init(texture))
        } else {
            material.color = .init(tint: .white)
        }

        let card = ModelEntity(mesh: mesh, materials: [material])

        // Rotate to stand upright (90 degrees around X axis)
        card.transform.rotation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])

        // Lift it so the bottom edge sits on the table
        card.position.y = cardHeight / 2

        card.generateCollisionShapes(recursive: true)
        return card
    }

    // MARK: - Shadow Disc

    /// A dark transparent disc placed flat on the table to simulate a shadow
    func buildShadow(radius: Float) -> ModelEntity {
        let mesh = MeshResource.generatePlane(width: radius * 2, depth: radius * 2)
        var mat = UnlitMaterial()
        mat.color = .init(tint: UIColor(white: 0, alpha: 0.25))
        let shadow = ModelEntity(mesh: mesh, materials: [mat])
        shadow.position.y = 0.001 // just above surface to avoid z-fighting
        return shadow
    }
}
