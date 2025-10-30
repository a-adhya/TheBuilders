import Foundation
import SwiftUI

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
        GarmentDTO(id: 1, owner: "local", category: "Tops", color: .blue, name: "Blue T-Shirt", material: "Comfortable cotton blue t-shirt", imageURL: nil, dirty: false),
        GarmentDTO(id: 2, owner: "local", category: "Tops", color: .green, name: "Green T-Shirt", material: "Soft green casual tee", imageURL: nil, dirty: false),
        GarmentDTO(id: 3, owner: "local", category: "Tops", color: .orange, name: "Orange T-Shirt", material: "Bright orange summer shirt", imageURL: nil, dirty: true),
        GarmentDTO(id: 4, owner: "local", category: "Tops", color: .red, name: "Red T-Shirt", material: "Classic red cotton t-shirt", imageURL: nil, dirty: false),
        GarmentDTO(id: 5, owner: "local", category: "Bottoms", color: .blue, name: "Blue Jeans", material: "Comfortable denim jeans", imageURL: nil, dirty: false),
        GarmentDTO(id: 6, owner: "local", category: "Bottoms", color: .black, name: "Black Pants", material: "Formal black trousers", imageURL: nil, dirty: false),
        GarmentDTO(id: 7, owner: "local", category: "Dresses", color: .pink, name: "Summer Dress", material: "Light pink summer dress", imageURL: nil, dirty: false),
        GarmentDTO(id: 8, owner: "local", category: "Dresses", color: .black, name: "Evening Dress", material: "Elegant black evening gown", imageURL: nil, dirty: true),
        GarmentDTO(id: 9, owner: "local", category: "Shoes", color: .white, name: "Sneakers", material: "White running sneakers", imageURL: nil, dirty: false),
        GarmentDTO(id: 10, owner: "local", category: "Shoes", color: .brown, name: "Boots", material: "Brown leather boots", imageURL: nil, dirty: false),
        GarmentDTO(id: 11, owner: "local", category: "Accessories", color: .gray, name: "Watch", material: "Silver wrist watch", imageURL: nil, dirty: false),
        GarmentDTO(id: 12, owner: "local", category: "Accessories", color: .gray, name: "Hat", material: "Gray baseball cap", imageURL: nil, dirty: false)
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


