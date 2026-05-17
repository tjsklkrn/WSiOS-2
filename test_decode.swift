import Foundation

struct ProductItemDTO: Identifiable, Codable {
    let id: String
    let name: String
    let media: ProductMedia?
}

struct ProductMedia: Codable {
    let images: [ProductImage]?
}

struct ProductImage: Codable {
    let type: String?
    let path: String?
}

let url = URL(fileURLWithPath: "mock api/mock-api/responses/skus.json")
let data = try! Data(contentsOf: url)
do {
    let dtos = try JSONDecoder().decode([ProductItemDTO].self, from: data)
    print("SUCCESS")
    print("FIRST ITEM IMAGE PATH: \(dtos.first?.media?.images?.first?.path ?? "nil")")
} catch {
    print("ERROR: \(error)")
}
