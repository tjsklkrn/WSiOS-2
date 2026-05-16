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

        // AR World Tracking — horizontal plane detection
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        arView.session.run(config)

        // Coaching overlay — guides user to scan a surface
        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        coachingOverlay.session = arView.session
        coachingOverlay.goal = .horizontalPlane
        arView.addSubview(coachingOverlay)

        // Tap gesture to place
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tap)

        context.coordinator.arView = arView
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // Reset: remove anchor from scene when user taps trash
        if !viewModel.isModelPlaced, let anchor = viewModel.currentAnchor {
            uiView.scene.removeAnchor(anchor)
            viewModel.currentAnchor = nil
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

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
                  let productImage = viewModel.productImage else { return }

            let location = recognizer.location(in: arView)

            // Raycast onto a real horizontal plane for a stable anchor
            let results = arView.raycast(from: location, allowing: .existingPlaneGeometry, alignment: .horizontal)
            guard let hit = results.first else {
                // Fall back to estimated plane if no real plane hit yet
                let estimated = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .horizontal)
                if let est = estimated.first {
                    placeEntity(image: productImage, at: est, in: arView)
                }
                return
            }

            placeEntity(image: productImage, at: hit, in: arView)
        }

        private func placeEntity(image: UIImage, at result: ARRaycastResult, in arView: ARView) {
            // Use AnchorEntity locked to the detected plane transform
            // This keeps the object perfectly pinned to the table surface
            let anchor = AnchorEntity(world: result.worldTransform)
            arView.scene.addAnchor(anchor)

            let model = viewModel.create3DProductEntity(from: image)
            model.name = "product3D"

            // Lift the entity by half its height so it sits ON the surface, not inside it
            let height: Float = 0.25 * 0.04 // same as in ViewModel
            model.position.y = height / 2

            // Only allow rotation & scale — no translation to prevent drifting
            arView.installGestures([.rotation, .scale], for: model)

            anchor.addChild(model)
            viewModel.currentAnchor = anchor

            withAnimation {
                viewModel.isModelPlaced = true
            }

            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
