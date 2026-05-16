//
//  VisualSearchView.swift
//  WSHackathonApp
//

import SwiftUI
import Vision
import CoreImage

struct VisualSearchView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: HomeViewModel

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        // Default to camera if available, otherwise photo library for simulator testing
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
        } else {
            picker.sourceType = .photoLibrary
        }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: VisualSearchView

        init(_ parent: VisualSearchView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            guard let image = info[.originalImage] as? UIImage,
                  let ciImage = CIImage(image: image) else {
                parent.dismiss()
                return
            }

            // Perform Vision classification
            let request = VNClassifyImageRequest { [weak self] request, error in
                guard let self = self,
                      let results = request.results as? [VNClassificationObservation],
                      let topResult = results.first else {
                    DispatchQueue.main.async {
                        self?.parent.dismiss()
                    }
                    return
                }

                // Apple's Vision model returns very specific labels like "plate", "bowl", "cup", "cutting board"
                // We grab the most confident identifier and use it as our search query
                DispatchQueue.main.async {
                    // Extract the primary object name from the identifier (often comma-separated synonyms)
                    let searchKeyword = topResult.identifier.components(separatedBy: ",").first ?? topResult.identifier
                    self.parent.viewModel.searchText = searchKeyword
                    self.parent.dismiss()
                }
            }

            // Use the global dispatch queue to avoid blocking UI
            DispatchQueue.global(qos: .userInitiated).async {
                let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    print("Failed to perform classification: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.parent.dismiss()
                    }
                }
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
