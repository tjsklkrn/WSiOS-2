//
//  ARViewContainer.swift
//  WSHackathonApp
//

import SwiftUI
import RealityKit
import ARKit

struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var viewModel: ARViewModel

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        arView.session.run(config)

        // Native coaching overlay — tells user to scan surface
        let coaching = ARCoachingOverlayView()
        coaching.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        coaching.session = arView.session
        coaching.goal = .horizontalPlane
        arView.addSubview(coaching)

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tap)
        context.coordinator.arView = arView
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // Remove anchor when user resets
        if !viewModel.isModelPlaced, let anchor = viewModel.currentAnchor {
            uiView.scene.removeAnchor(anchor)
            viewModel.currentAnchor = nil
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(viewModel: viewModel) }

    // MARK: - Coordinator

    @MainActor
    class Coordinator: NSObject {
        var viewModel: ARViewModel
        weak var arView: ARView?

        init(viewModel: ARViewModel) {
            self.viewModel = viewModel
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let arView = arView,
                  !viewModel.isModelPlaced,
                  let image = viewModel.productImage else { return }

            let pt = recognizer.location(in: arView)

            // Prefer a hit on a real detected plane (most stable)
            let hits = arView.raycast(from: pt, allowing: .existingPlaneGeometry, alignment: .horizontal)
            let result = hits.first ?? arView.raycast(from: pt, allowing: .estimatedPlane, alignment: .horizontal).first
            guard let hit = result else { return }

            place(image: image, at: hit, in: arView)
        }

        private func place(image: UIImage, at hit: ARRaycastResult, in arView: ARView) {
            // Anchor locked to the real-world transform of the hit plane point
            let anchor = AnchorEntity(world: hit.worldTransform)

            // Shadow first (underneath the card)
            let aspectRatio = Float(image.size.width / image.size.height)
            let cardHeight: Float = 0.30
            let cardWidth: Float = cardHeight * aspectRatio
            let shadowRadius = max(cardWidth, cardHeight) * 0.55
            let shadow = viewModel.buildShadow(radius: shadowRadius)
            anchor.addChild(shadow)

            // Product card
            let card = viewModel.buildProductEntity(from: image)
            // Allow rotate and scale only — no translation so it doesn't drift
            arView.installGestures([.rotation, .scale], for: card)
            anchor.addChild(card)

            arView.scene.addAnchor(anchor)
            viewModel.currentAnchor = anchor

            withAnimation { viewModel.isModelPlaced = true }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
