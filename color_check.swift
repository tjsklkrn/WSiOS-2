import Foundation
import CoreGraphics
import CoreImage

guard CommandLine.arguments.count > 1 else { exit(1) }
let imagePath = CommandLine.arguments[1]
let url = URL(fileURLWithPath: imagePath)

guard let cgImage = CGImageSourceCreateWithURL(url as CFURL, nil).flatMap({ CGImageSourceCreateImageAtIndex($0, 0, nil) }) else {
    print("Could not load image")
    exit(1)
}

let width = cgImage.width
let height = cgImage.height
print("Image size: \(width)x\(height)")

guard let dataProvider = cgImage.dataProvider,
      let pixelData = dataProvider.data,
      let ptr = CFDataGetBytePtr(pixelData) else {
    print("Could not get pixel data")
    exit(1)
}

func getColor(u: Double, v_from_bottom: Double) {
    let px = Int(Double(width) * u)
    let py = Int(Double(height) * (1.0 - v_from_bottom))
    let bytesPerPixel = cgImage.bitsPerPixel / 8
    let bytesPerRow = cgImage.bytesPerRow
    let pixelInfo = py * bytesPerRow + px * bytesPerPixel
    
    let r = ptr[pixelInfo]
    let g = ptr[pixelInfo + 1]
    let b = ptr[pixelInfo + 2]
    
    print("Color at (\(u), \(v_from_bottom)) - px:\(px), py:\(py) -> R:\(r) G:\(g) B:\(b)")
}

getColor(u: 0.5, v_from_bottom: 0.57) // Create A Registry Background
getColor(u: 0.5, v_from_bottom: 0.47) // Find a Registry Background
getColor(u: 0.5, v_from_bottom: 0.35) // Between buttons and categories
getColor(u: 0.22, v_from_bottom: 0.30) // Cookware Background
getColor(u: 0.5, v_from_bottom: 0.88) // Registry Header Background
