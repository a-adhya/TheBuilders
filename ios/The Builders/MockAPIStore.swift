import Foundation
import SwiftUI
import UIKit

// MARK: - API Models

struct GarmentDTO: Identifiable, Equatable {
    var id: Int
    var owner: String
    var category: String
    var color: Color
    var name: String
    var material: String?
    var imageURL: URL?
    var dirty: Bool
}

// MARK: - API Protocol

protocol GarmentAPI {
    func fetchGarments(owner: String?) async throws -> [GarmentDTO]
    func createGarment(_ garment: GarmentDTO) async throws -> GarmentDTO
    func updateGarment(id: Int, dirty: Bool?) async throws -> GarmentDTO
    func updateGarmentFull(_ garment: GarmentDTO) async throws -> GarmentDTO
    func deleteGarment(id: Int) async throws
}

// MARK: - Mock API (in-memory)

final class MockGarmentAPI: GarmentAPI {
    static let defaultSeed: [GarmentDTO] = [
        GarmentDTO(id: 4, owner: "local", category: "Tops", color: .blue, name: "Blue T-Shirt", material: "Comfortable cotton blue t-shirt", imageURL: nil, dirty: false),
        GarmentDTO(id: 5, owner: "local", category: "Tops", color: .green, name: "Green T-Shirt", material: "Soft green casual tee", imageURL: nil, dirty: false),
        GarmentDTO(id: 6, owner: "local", category: "Tops", color: .orange, name: "Orange T-Shirt", material: "Bright orange summer shirt", imageURL: nil, dirty: true),
        GarmentDTO(id: 7, owner: "local", category: "Tops", color: .red, name: "Red T-Shirt", material: "Classic red cotton t-shirt", imageURL: nil, dirty: false),
        GarmentDTO(id: 8, owner: "local", category: "Bottoms", color: .blue, name: "Blue Jeans", material: "Comfortable denim jeans", imageURL: nil, dirty: false),
        GarmentDTO(id: 9, owner: "local", category: "Bottoms", color: .black, name: "Black Pants", material: "Formal black trousers", imageURL: nil, dirty: false),
        GarmentDTO(id: 10, owner: "local", category: "Dresses", color: .pink, name: "Summer Dress", material: "Light pink summer dress", imageURL: nil, dirty: false),
        GarmentDTO(id: 11, owner: "local", category: "Dresses", color: .black, name: "Evening Dress", material: "Elegant black evening gown", imageURL: nil, dirty: true),
        GarmentDTO(id: 12, owner: "local", category: "Shoes", color: .white, name: "Sneakers", material: "White running sneakers", imageURL: nil, dirty: false),
        GarmentDTO(id: 13, owner: "local", category: "Shoes", color: .brown, name: "Boots", material: "Brown leather boots", imageURL: nil, dirty: false),
        GarmentDTO(id: 14, owner: "local", category: "Accessories", color: .gray, name: "Watch", material: "Silver wrist watch", imageURL: nil, dirty: false),
        GarmentDTO(id: 15, owner: "local", category: "Accessories", color: .gray, name: "Hat", material: "Gray baseball cap", imageURL: nil, dirty: false)
    ]

    private var garments: [GarmentDTO]
    private let latencyMs: UInt64
    private let queue = DispatchQueue(label: "mock.garment.api", attributes: .concurrent)

    init(seed: [GarmentDTO] = MockGarmentAPI.defaultSeed, latencyMs: UInt64 = 150) {
        self.garments = seed
        self.latencyMs = latencyMs
    }

    func fetchGarments(owner: String?) async throws -> [GarmentDTO] {
        try await sleepLatency()
        return queueSync {
            if let owner = owner {
                return garments.filter { $0.owner == owner }
            }
            return garments
        }
    }

    func createGarment(_ garment: GarmentDTO) async throws -> GarmentDTO {
        try await sleepLatency()
        return queueSync {
            var next = garment
            if garments.contains(where: { $0.id == garment.id }) {
                let maxId = garments.map { $0.id }.max() ?? 0
                next.id = maxId + 1
            }
            garments.append(next)
            return next
        }
    }

    func updateGarment(id: Int, dirty: Bool?) async throws -> GarmentDTO {
        try await sleepLatency()
        return try queueSyncThrowing {
            guard let index = garments.firstIndex(where: { $0.id == id }) else {
                throw NSError(domain: "MockGarmentAPI", code: 404, userInfo: [NSLocalizedDescriptionKey: "garment not found"])
            }
            if let dirty = dirty {
                garments[index].dirty = dirty
            }
            return garments[index]
        }
    }

    func updateGarmentFull(_ garment: GarmentDTO) async throws -> GarmentDTO {
        try await sleepLatency()
        return try queueSyncThrowing {
            guard let index = garments.firstIndex(where: { $0.id == garment.id }) else {
                throw NSError(domain: "MockGarmentAPI", code: 404, userInfo: [NSLocalizedDescriptionKey: "garment not found"])
            }
            garments[index] = garment
            return garments[index]
        }
    }

    func deleteGarment(id: Int) async throws {
        try await sleepLatency()
        _ = queueSync { garments.removeAll { $0.id == id } }
    }

    // MARK: - Helpers

    private func sleepLatency() async throws {
        try await Task.sleep(nanoseconds: latencyMs * 1_000_000)
    }

    private func queueSync<T>(_ body: () -> T) -> T {
        var result: T!
        queue.sync { result = body() }
        return result
    }

    private func queueSyncThrowing<T>(_ body: () throws -> T) throws -> T {
        var output: Result<T, Error>!
        queue.sync {
            do { output = .success(try body()) }
            catch { output = .failure(error) }
        }
        return try output.get()
    }
}

// MARK: - Real API Implementation

final class RealGarmentAPI: GarmentAPI {
    private let baseURL: String
    
    init(baseURL: String = "http://localhost:8000") {
        self.baseURL = baseURL
    }
    
    // MARK: - API Protocol Implementation
    
    func fetchGarments(owner: String?) async throws -> [GarmentDTO] {
        // Convert owner string to int (default to 1 if "local" or nil)
        let userId = convertOwnerToUserId(owner)
        
        var urlString = "\(baseURL)/api/item/get?user_id=\(userId)"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 404 {
                return [] // No items found, return empty array
            }
            throw URLError(.badServerResponse)
        }
        
        // Decode API response
        let apiResponse = try JSONDecoder().decode(APIWardrobeResponse.self, from: data)
        
        // Convert API garments to DTOs
        return apiResponse.garments.map { $0.toDTO() }
    }
    
    func createGarment(_ garment: GarmentDTO) async throws -> GarmentDTO {
        guard let url = URL(string: "\(baseURL)/create_garment") else {
            throw URLError(.badURL)
        }
        
        // Convert DTO to API request format
        let apiRequest = garment.toAPIRequest()
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(apiRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 500 {
                throw NSError(domain: "RealGarmentAPI", code: 500, userInfo: [NSLocalizedDescriptionKey: "Internal server error"])
            }
            throw URLError(.badServerResponse)
        }
        
        // Decode API response
        let apiResponse = try JSONDecoder().decode(APIGarmentResponse.self, from: data)
        return apiResponse.toDTO()
    }
    
    func updateGarment(id: Int, dirty: Bool?) async throws -> GarmentDTO {
        guard let url = URL(string: "\(baseURL)/garments/\(id)") else {
            throw URLError(.badURL)
        }
        
        // Create partial update request
        struct UpdateRequest: Codable {
            let dirty: Bool?
        }
        let updateRequest = UpdateRequest(dirty: dirty)
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(updateRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 404 {
                throw NSError(domain: "RealGarmentAPI", code: 404, userInfo: [NSLocalizedDescriptionKey: "Garment not found"])
            }
            if httpResponse.statusCode == 500 {
                throw NSError(domain: "RealGarmentAPI", code: 500, userInfo: [NSLocalizedDescriptionKey: "Internal server error"])
            }
            throw URLError(.badServerResponse)
        }
        
        // Decode API response
        let apiResponse = try JSONDecoder().decode(APIGarmentResponse.self, from: data)
        return apiResponse.toDTO()
    }
    
    func updateGarmentFull(_ garment: GarmentDTO) async throws -> GarmentDTO {
        guard let url = URL(string: "\(baseURL)/garments/\(garment.id)") else {
            throw URLError(.badURL)
        }
        
        // Convert DTO to API update request format
        struct UpdateRequest: Codable {
            let category: Int?
            let material: Int?
            let color: String?
            let name: String?
            let image_url: String?
            let dirty: Bool?
        }
        
        let category = convertUICategoryToAPICategory(garment.category)
        let material = convertMaterialStringToAPIMaterial(garment.material)
        let colorHex = convertColorToHex(garment.color)
        let imageUrl = garment.imageURL?.absoluteString
        
        let updateRequest = UpdateRequest(
            category: category,
            material: material,
            color: colorHex,
            name: garment.name,
            image_url: imageUrl,
            dirty: garment.dirty
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(updateRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 404 {
                throw NSError(domain: "RealGarmentAPI", code: 404, userInfo: [NSLocalizedDescriptionKey: "Garment not found"])
            }
            if httpResponse.statusCode == 500 {
                throw NSError(domain: "RealGarmentAPI", code: 500, userInfo: [NSLocalizedDescriptionKey: "Internal server error"])
            }
            throw URLError(.badServerResponse)
        }
        
        // Decode API response
        let apiResponse = try JSONDecoder().decode(APIGarmentResponse.self, from: data)
        return apiResponse.toDTO()
    }
    
    func deleteGarment(id: Int) async throws {
        // Backend team is working on this, so throw an error for now
        throw NSError(domain: "RealGarmentAPI", code: 501, userInfo: [NSLocalizedDescriptionKey: "Delete endpoint not yet implemented by backend"])
    }
    
    // MARK: - Helper Functions
    
    private func convertOwnerToUserId(_ owner: String?) -> Int {
        // Default to user_id 1 for "local" or nil
        if owner == nil || owner == "local" {
            return 1
        }
        // Try to parse as int if it's a number string
        return Int(owner ?? "1") ?? 1
    }
}

// MARK: - API Response Models

private struct APIWardrobeResponse: Codable {
    let garments: [APIGarmentResponse]
}

private struct APIGarmentResponse: Codable {
    let id: Int
    let owner: Int
    let category: Int
    let material: Int
    let color: String
    let name: String
    let image_url: String
    let dirty: Bool
    let created_at: String
    
    func toDTO() -> GarmentDTO {
        GarmentDTO(
            id: id,
            owner: String(owner),
            category: convertAPICategoryToUICategory(category),
            color: convertHexToColor(color),
            name: name,
            material: convertAPIMaterialToMaterialString(material),
            imageURL: URL(string: image_url),
            dirty: dirty
        )
    }
}

struct APICreateGarmentRequest: Codable {
    let owner: Int
    let category: Int
    let material: Int
    let color: String
    let name: String
    let image_url: String
    let dirty: Bool
}

// MARK: - Conversion Helpers

private func convertAPICategoryToUICategory(_ apiCategory: Int) -> String {
    switch apiCategory {
    case 1, 2, 3, 4: // SHIRT, TSHIRT, JACKET, SWEATER
        return "Tops"
    case 5, 6, 7: // JEANS, PANTS, SHORTS
        return "Bottoms"
    case 8: // SHOES
        return "Shoes"
    case 9: // ACCESSORY
        return "Accessories"
    default:
        return "Tops" // Default fallback
    }
}

private func convertUICategoryToAPICategory(_ uiCategory: String) -> Int {
    switch uiCategory {
    case "Tops":
        return 1 // Default to SHIRT for Tops
    case "Bottoms":
        return 5 // Default to JEANS for Bottoms
    case "Dresses":
        return 6 // Map Dresses to PANTS (no DRESS in API enum)
    case "Shoes":
        return 8
    case "Accessories":
        return 9
    default:
        return 1 // Default to SHIRT
    }
}

private func convertAPIMaterialToMaterialString(_ apiMaterial: Int) -> String {
    switch apiMaterial {
    case 1: return "Cotton"
    case 2: return "Denim"
    case 3: return "Wool"
    case 4: return "Corduroy"
    case 5: return "Silk"
    case 6: return "Satin"
    case 7: return "Leather"
    case 8: return "Athletic"
    default: return "Cotton"
    }
}

private func convertMaterialStringToAPIMaterial(_ material: String?) -> Int {
    guard let material = material else { return 1 }
    switch material {
    case "Cotton": return 1
    case "Denim": return 2
    case "Wool": return 3
    case "Corduroy": return 4
    case "Silk": return 5
    case "Satin": return 6
    case "Leather": return 7
    case "Athletic": return 8
    default: return 1
    }
}

private func convertColorToHex(_ color: Color) -> String {
    // Convert SwiftUI Color to hex string
    let uiColor = UIColor(color)
    
    // Get the CGColor and its components
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    
    // Try to get RGB components directly
    if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
    
    // If getRed fails, try using CGColor components
    let components = uiColor.cgColor.components ?? []
    if components.count >= 3 {
        let r = Int((components[0] * 255).rounded())
        let g = Int((components[1] * 255).rounded())
        let b = Int((components[2] * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
    
    // Fallback if conversion fails
    return "#000000"
}

private func convertHexToColor(_ hex: String) -> Color {
    var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
    
    var rgb: UInt64 = 0
    Scanner(string: hexSanitized).scanHexInt64(&rgb)
    
    let r = Double((rgb & 0xFF0000) >> 16) / 255.0
    let g = Double((rgb & 0x00FF00) >> 8) / 255.0
    let b = Double(rgb & 0x0000FF) / 255.0
    
    return Color(red: r, green: g, blue: b)
}

// MARK: - GarmentDTO Extension for API Conversion

extension GarmentDTO {
    fileprivate func toAPIRequest() -> APICreateGarmentRequest {
        let userId = Int(self.owner) ?? 1
        let category = convertUICategoryToAPICategory(self.category)
        let material = convertMaterialStringToAPIMaterial(self.material)
        let colorHex = convertColorToHex(self.color)
        let imageUrl = self.imageURL?.absoluteString ?? ""
        
        return APICreateGarmentRequest(
            owner: userId,
            category: category,
            material: material,
            color: colorHex,
            name: self.name,
            image_url: imageUrl,
            dirty: self.dirty
        )
    }
}

// MARK: - Mapping between DTO and UI Model

extension GarmentDTO {
    func toClothingItem() -> ClothingItem {
        ClothingItem(
            id: id,
            name: name,
            color: color,
            isInLaundry: dirty,
            category: category,
            description: material ?? ""
        )
    }
}

extension ClothingItem {
    func toDTO(owner: String = "local") -> GarmentDTO {
        GarmentDTO(
            id: id,
            owner: owner,
            category: category,
            color: color,
            name: name,
            material: description,
            imageURL: nil,
            dirty: isInLaundry
        )
    }
}


