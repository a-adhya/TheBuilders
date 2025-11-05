import Foundation
import SwiftUI

// MARK: - API Models
// These models follow the actual API structure from src/api/schema.py (CreateGarmentResponse)
// The iOS layer abstracts the API response into more iOS-friendly types:
// - API owner: int -> iOS: String (uses "local" for local user)
// - API category: Category enum (SHIRT=1, TSHIRT=2, etc.) -> iOS: String ("Tops", "Bottoms", etc.)
// - API material: Material enum (COTTON=1, DENIM=2, etc.) -> iOS: String?
// - API color: str (7-char hex like "#FF0000") -> iOS: Color (SwiftUI Color)
// - API image_url: str (512 chars) -> iOS: URL? (optional URL)
// - API dirty: bool -> iOS: bool (maps directly)
// - API created_at: datetime -> iOS: Not stored in DTO (can be added if needed)

struct GarmentDTO: Identifiable, Equatable {
    var id: Int  // Maps to API id (int, auto-incremented)
    var owner: String  // Maps to API owner (int in API, abstracted to String for iOS)
    var category: String  // Maps to API category enum (Category enum in API, abstracted to String)
    var color: Color  // Maps to API color (str hex in API, converted to SwiftUI Color)
    var name: String  // Maps to API name (str, max 128 chars)
    var material: String?  // Maps to API material enum (Material enum in API, abstracted to String)
    var imageURL: URL?  // Maps to API image_url (str, max 512 chars in API, converted to URL)
    var dirty: Bool  // Maps to API dirty (bool)
}

// MARK: - API Protocol
// This protocol follows the actual API endpoints from src/api/server.py:
// - POST /create_garment -> createGarment
// - PATCH /garments/{id} -> updateGarment (partial) and updateGarmentFull (full)
// - GET /garments (not in API yet, but iOS expects it) -> fetchGarments
// - DELETE (not in API yet, but iOS expects it) -> deleteGarment

protocol GarmentAPI {
    func fetchGarments(owner: String?) async throws -> [GarmentDTO]  // GET /garments?owner=X (not in API yet)
    func createGarment(_ garment: GarmentDTO) async throws -> GarmentDTO  // POST /create_garment
    func updateGarment(id: Int, dirty: Bool?) async throws -> GarmentDTO  // PATCH /garments/{id} (partial update)
    func updateGarmentFull(_ garment: GarmentDTO) async throws -> GarmentDTO  // PATCH /garments/{id} (full update)
    func deleteGarment(id: Int) async throws  // DELETE /garments/{id} (not in API yet)
}

// MARK: - Mock API (in-memory)
// This mock API follows the actual API structure from src/api/server.py
// It simulates the API behavior with in-memory storage for development/testing

final class MockGarmentAPI: GarmentAPI {
    // Default seed data matching API structure:
    // - Categories map to API Category enum: SHIRT(1), TSHIRT(2), JACKET(3), SWEATER(4) -> "Tops"
    //                                        JEANS(5), PANTS(6), SHORTS(7) -> "Bottoms"
    //                                        SHOES(8) -> "Shoes"
    //                                        ACCESSORY(9) -> "Accessories"
    // - Materials map to API Material enum: COTTON(1), DENIM(2), WOOL(3), LEATHER(7), etc.
    // - Colors are SwiftUI Colors (API uses hex strings like "#0000FF")
    // - owner is "local" (API uses int, iOS abstracts to string)
    static let defaultSeed: [GarmentDTO] = [
        GarmentDTO(id: 1, owner: "local", category: "Tops", color: .blue, name: "Blue T-Shirt", material: "Cotton", imageURL: nil, dirty: false),
        GarmentDTO(id: 2, owner: "local", category: "Tops", color: .green, name: "Green T-Shirt", material: "Cotton", imageURL: nil, dirty: false),
        GarmentDTO(id: 3, owner: "local", category: "Tops", color: .orange, name: "Orange T-Shirt", material: "Cotton", imageURL: nil, dirty: true),
        GarmentDTO(id: 4, owner: "local", category: "Tops", color: .red, name: "Red T-Shirt", material: "Cotton", imageURL: nil, dirty: false),
        GarmentDTO(id: 5, owner: "local", category: "Bottoms", color: .blue, name: "Blue Jeans", material: "Denim", imageURL: nil, dirty: false),
        GarmentDTO(id: 6, owner: "local", category: "Bottoms", color: .black, name: "Black Pants", material: "Cotton", imageURL: nil, dirty: false),
        GarmentDTO(id: 7, owner: "local", category: "Tops", color: .pink, name: "Pink Sweater", material: "Wool", imageURL: nil, dirty: false),
        GarmentDTO(id: 8, owner: "local", category: "Tops", color: .black, name: "Black Jacket", material: "Leather", imageURL: nil, dirty: true),
        GarmentDTO(id: 9, owner: "local", category: "Shoes", color: .white, name: "Sneakers", material: "Athletic", imageURL: nil, dirty: false),
        GarmentDTO(id: 10, owner: "local", category: "Shoes", color: .brown, name: "Boots", material: "Leather", imageURL: nil, dirty: false),
        GarmentDTO(id: 11, owner: "local", category: "Accessories", color: .gray, name: "Watch", material: "Metal", imageURL: nil, dirty: false),
        GarmentDTO(id: 12, owner: "local", category: "Accessories", color: .gray, name: "Hat", material: "Cotton", imageURL: nil, dirty: false)
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


