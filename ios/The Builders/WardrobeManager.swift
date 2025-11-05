//
//  WardrobeManager.swift
//  TheBuilders
//
//  Created by Cassie Liu on 10/28/2025.
//

import SwiftUI
import Combine

// Observable data manager for clothing items
// Connected to real backend API via RealGarmentAPI
@MainActor
class WardrobeManager: ObservableObject {
    @Published var items: [ClothingItem] = []
    private let api: GarmentAPI
    
    // Categories for easy access
    let categories: [String] = ClothingItem.Category.allCases.map { category in category.rawValue }
    
    init(api: GarmentAPI? = nil) {
        let realAPI = RealGarmentAPI()
        self.api = api ?? realAPI
        Task { await load() }
    }

    // MARK: - API-backed operations

    func load(owner: String? = nil) async {
        do {
            let dtos = try await api.fetchGarments(owner: owner)
            self.items = dtos.map { $0.toClothingItem() }
        } catch {
            // keep items unchanged on failure
        }
    }
    
    // MARK: - Public Methods
    
    func updateItem(_ updatedItem: ClothingItem) async {
        do {
            let dto = updatedItem.toDTO()
            let saved = try await api.updateGarmentFull(dto)
            if let index = items.firstIndex(where: { $0.id == saved.id }) {
                items[index] = saved.toClothingItem()
            }
        } catch {
            // ignore for mock
        }
    }
    
    func deleteItem(withId id: Int) async {
        do {
            try await api.deleteGarment(id: id)
            items.removeAll { $0.id == id }
        } catch {
            // ignore for mock
        }
    }
    
    func getItems(for category: String, owner: String? = nil) async -> [ClothingItem] {
        do {
            let dtos = try await api.fetchGarments(owner: owner)
            let mapped = dtos.map { $0.toClothingItem() }
            self.items = mapped
            return mapped.filter { $0.category == category }
        } catch {
            return items.filter { $0.category == category }
        }
    }
    
    func getAvailableItems(for category: String, owner: String? = nil) async -> [ClothingItem] {
        do {
            let dtos = try await api.fetchGarments(owner: owner)
            let mapped = dtos.map { $0.toClothingItem() }
            self.items = mapped
            return mapped.filter { $0.category == category && !$0.isInLaundry }
        } catch {
            return items.filter { $0.category == category && !$0.isInLaundry }
        }
    }
    
    func getLaundryItems(owner: String? = nil) async -> [ClothingItem] {
        do {
            let dtos = try await api.fetchGarments(owner: owner)
            let mapped = dtos.map { $0.toClothingItem() }
            self.items = mapped
            return mapped.filter { $0.isInLaundry }
        } catch {
            return items.filter { $0.isInLaundry }
        }
    }

    // Move an item to laundry by id
    func sendToLaundry(itemId: Int) async {
        do {
            _ = try await api.updateGarment(id: itemId, dirty: true)
            if let index = items.firstIndex(where: { $0.id == itemId }) {
                items[index].isInLaundry = true
            }
        } catch {
            // ignore for mock
        }
    }

    // Bring an item back from laundry by id
    func returnFromLaundry(itemId: Int) async {
        do {
            _ = try await api.updateGarment(id: itemId, dirty: false)
            if let index = items.firstIndex(where: { $0.id == itemId }) {
                items[index].isInLaundry = false
            }
        } catch {
            // ignore for mock
        }
    }
    
    // Create a new garment
    func createGarment(_ garment: GarmentDTO) async throws -> GarmentDTO {
        let created = try await api.createGarment(garment)
        await load()
        return created
    }
}
