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
        
        // Setup AR Configuration for Horizontal Plane Detection
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic
        
        // Use LiDAR if available for better occlusion and placement
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        
        arView.session.run(config)
        
        // Add Luxury Coaching Overlay (Apple native surface detection guide)
        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        coachingOverlay.session = arView.session
        coachingOverlay.goal = .horizontalPlane
        arView.addSubview(coachingOverlay)
        
        // Setup tap gesture for placement
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)
        context.coordinator.arView = arView
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // Handle dynamic model switching without re-placing the anchor
        if viewModel.isModelPlaced, let anchor = viewModel.anchorEntity, let current = viewModel.currentEntity {
            if current.name != viewModel.selectedModelName && !viewModel.isLoading {
                Task { @MainActor in
                    let newModel = await viewModel.loadModel(name: viewModel.selectedModelName)
                    newModel.name = viewModel.selectedModelName
                    
                    // Swap cleanly
                    anchor.removeChild(current)
                    anchor.addChild(newModel)
                    
                    // Re-enable interactions
                    uiView.installGestures([.rotation, .scale, .translation], for: newModel)
                    
                    viewModel.currentEntity = newModel
                }
            }
        }
        
        // Handle removal / reset
        if !viewModel.isModelPlaced && viewModel.anchorEntity != nil {
            if let anchor = viewModel.anchorEntity {
                uiView.scene.removeAnchor(anchor)
                viewModel.anchorEntity = nil
                viewModel.currentEntity = nil
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }
    
    @MainActor
    class Coordinator: NSObject {
        var viewModel: ARViewModel
        weak var arView: ARView?
        
        init(viewModel: ARViewModel) {
            self.viewModel = viewModel
        }
        
        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let arView = arView, !viewModel.isModelPlaced else { return }
            
            let location = recognizer.location(in: arView)
            
            let results = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .horizontal)
            if let firstResult = results.first {
                placeModel(at: firstResult, in: arView)
            }
        }
        
        private func placeModel(at result: ARRaycastResult, in arView: ARView) {
            let anchor = AnchorEntity(world: result.worldTransform)
            arView.scene.addAnchor(anchor)
            
            viewModel.anchorEntity = anchor
            
            Task { @MainActor in
                let model = await viewModel.loadModel(name: viewModel.selectedModelName)
                model.name = viewModel.selectedModelName
                
                // Add scale, rotation, translation capabilities
                arView.installGestures([.rotation, .scale, .translation], for: model)
                
                anchor.addChild(model)
                viewModel.currentEntity = model
                
                withAnimation {
                    viewModel.isModelPlaced = true
                }
                
                // Provide haptic feedback for premium feel
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        }
    }
}
