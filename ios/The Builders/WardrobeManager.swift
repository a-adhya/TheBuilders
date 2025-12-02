//
//  WardrobeManager.swift
//  TheBuilders
//
//  Created by Cassie Liu on 10/28/2025.
//

import SwiftUI
import Combine
import Foundation

// Observable data manager for clothing items
// Connected to real backend API via RealGarmentAPI
@MainActor
class WardrobeManager: ObservableObject {
    @Published var items: [ClothingItem] = []
    let api: GarmentAPI  // Made public for image classification access
    
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
    
    func updateItem(_ updatedItem: ClothingItem, imageData: Data? = nil) async {
        do {
            var dto = updatedItem.toDTO()
            
            // Get the current item to compare image URLs
            let currentItem = items.first { $0.id == updatedItem.id }
            let oldImageURL = currentItem?.imageURL
            
            // If a new image is provided, we need to upload it
            // First, update the garment to get the new image URL (if name changed)
            // Then upload the image to that URL, deleting old image if URL changed
            if let imageData = imageData {
                // Update the garment first to get the correct image URL
                // The backend will generate a new image URL if the name changed
                let saved = try await api.updateGarmentFull(dto)
                
                // Update the image in blob storage (handles old image deletion if URL changed)
                if let newImageURL = saved.imageURL {
                    try await ImageUploadService.shared.updateImage(
                        imageData,
                        to: newImageURL,
                        oldImageURL: oldImageURL
                    )
                }
                
                if let index = items.firstIndex(where: { $0.id == saved.id }) {
                    items[index] = saved.toClothingItem()
                }
            } else {
                // No new image, just update normally
                let saved = try await api.updateGarmentFull(dto)
                if let index = items.firstIndex(where: { $0.id == saved.id }) {
                    items[index] = saved.toClothingItem()
                }
            }
        } catch {
            // ignore for mock
        }
    }
    
    func deleteItem(withId id: Int) async {
        do {
            // Get the item before deleting to access its image URL
            let itemToDelete = items.first { $0.id == id }
            
            // Delete the image from blob storage first
            if let imageURL = itemToDelete?.imageURL {
                try? await ImageUploadService.shared.deleteImage(from: imageURL)
            }
            
            // Then delete from the database
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
    
    // Create a new garment, optionally uploading an image directly to the CDN
    func createGarment(_ garment: GarmentDTO, imageData: Data? = nil) async throws -> GarmentDTO {
        let created = try await api.createGarment(garment)
        
        if let data = imageData, let uploadURL = created.imageURL {
            try await ImageUploadService.shared.uploadImage(data, to: uploadURL)
        }
        
        await load()
        return created
    }
}
