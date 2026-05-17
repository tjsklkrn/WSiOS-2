import Foundation

struct ProductItemDTO: Identifiable, Codable {
    let id: String
    let name: String
    let properties: ProductProperties?
}

struct ProductProperties: Codable {
    let brand: String?
    let productType: String?
}

let fileURL = URL(fileURLWithPath: "mock api/mock-api/responses/skus.json")
do {
    let data = try Data(contentsOf: fileURL)
    let dtos = try JSONDecoder().decode([ProductItemDTO].self, from: data)
    let brands = dtos.compactMap { $0.properties?.brand }
    let types = dtos.compactMap { $0.properties?.productType }
    print("Found \(brands.count) brands and \(types.count) product types.")
    if let first = brands.first { print("First brand: \(first)") }
} catch {
    print("Decoding error: \(error)")
}
