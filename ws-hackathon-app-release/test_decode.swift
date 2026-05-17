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

let jsonString = """
[
  {
    "id": "2505456",
    "name": "Williams Sonoma End-Grain Cutting Board, Acacia, 15\" X 20\"",
    "media": {
      "images": [
        {
          "type": "prodimage",
          "path": "/img17m.jpg"
        }
      ]
    }
  }
]
"""

let data = jsonString.data(using: .utf8)!
do {
    let dtos = try JSONDecoder().decode([ProductItemDTO].self, from: data)
    print("SUCCESS: \(!(dtos.first?.media?.images?.first?.path ?? "").isEmpty)")
    print("PATH: \(dtos.first?.media?.images?.first?.path ?? "nil")")
} catch {
    print("ERROR: \(error)")
}
