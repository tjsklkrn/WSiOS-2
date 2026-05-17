import Foundation
import Vision
import CoreImage

guard CommandLine.arguments.count > 1 else { exit(1) }
let imagePath = CommandLine.arguments[1]
let url = URL(fileURLWithPath: imagePath)

guard let ciImage = CIImage(contentsOf: url) else {
    print("Could not load image")
    exit(1)
}

let request = VNRecognizeTextRequest { request, error in
    guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
    for observation in observations {
        guard let topCandidate = observation.topCandidates(1).first else { continue }
        let bbox = observation.boundingBox
        print("Text: '\(topCandidate.string)' at x:\(String(format: "%.2f", bbox.origin.x)), y:\(String(format: "%.2f", bbox.origin.y)), w:\(String(format: "%.2f", bbox.size.width)), h:\(String(format: "%.2f", bbox.size.height))")
    }
}
request.recognitionLevel = .accurate

let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
try? handler.perform([request])
