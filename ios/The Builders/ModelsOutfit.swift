//
//  ModelsOutfit.swift
//  TheBuilders
//
//  Created by Cassie Liu on 10/28/25.
//

import SwiftUI

// Data model for generated outfits
struct Outfit: Identifiable, Equatable {
    let id: Int
    var top: ClothingItem
    var bottom: ClothingItem
    var shoes: ClothingItem
    var accessories: ClothingItem?
    
    var items: [ClothingItem] {
        var allItems = [top, bottom, shoes]
        if let accessories = accessories {
            allItems.append(accessories)
        }
        return allItems
    }
}

// MARK: - API Category Mapping
// Maps actual API categories (from src/models/enums.py) to iOS UI categories

enum APICategory: Int {
    case SHIRT = 1
    case TSHIRT = 2
    case JACKET = 3
    case SWEATER = 4
    case JEANS = 5
    case PANTS = 6
    case SHORTS = 7
    case SHOES = 8
    case ACCESSORY = 9
    
    // Maps API category to iOS UI category string
    var uiCategory: String {
        switch self {
        case .SHIRT, .TSHIRT, .JACKET, .SWEATER:
            return "Tops"
        case .JEANS, .PANTS, .SHORTS:
            return "Bottoms"
        case .SHOES:
            return "Shoes"
        case .ACCESSORY:
            return "Accessories"
        }
    }
}

enum APIMaterial: Int {
    case COTTON = 1
    case DENIM = 2
    case WOOL = 3
    case COURDORY = 4
    case SILK = 5
    case SATIN = 6
    case LEATHER = 7
    case ATHLETIC = 8
    
    var displayName: String {
        switch self {
        case .COTTON: return "Cotton"
        case .DENIM: return "Denim"
        case .WOOL: return "Wool"
        case .COURDORY: return "Corduroy"
        case .SILK: return "Silk"
        case .SATIN: return "Satin"
        case .LEATHER: return "Leather"
        case .ATHLETIC: return "Athletic"
        }
    }
}

// MARK: - Mock Outfit API
// This follows the actual API structure from src/api/schema.py and src/models/enums.py

protocol OutfitAPI {
    func generateOutfit(occasion: String?, preferredItems: String?, mood: String?) async throws -> Outfit
}

final class MockOutfitAPI: OutfitAPI {
    private let garmentAPI: GarmentAPI
    private let latencyMs: UInt64
    
    init(garmentAPI: GarmentAPI = MockGarmentAPI(), latencyMs: UInt64 = 500) {
        self.garmentAPI = garmentAPI
        self.latencyMs = latencyMs
    }
    
    func generateOutfit(occasion: String?, preferredItems: String?, mood: String?) async throws -> Outfit {
        // Simulate API latency (matches actual API behavior)
        try await Task.sleep(nanoseconds: latencyMs * 1_000_000)
        
        // Fetch available garments (following API structure: owner is int, but iOS uses string for "local")
        let garments = try await garmentAPI.fetchGarments(owner: "local")
            .filter { !$0.dirty } // Only use clean items (dirty=false means available)
        
        // Filter garments by UI category (iOS abstracts API categories into Tops, Bottoms, Shoes, Accessories)
        // API categories map as follows:
        // - Tops: SHIRT(1), TSHIRT(2), JACKET(3), SWEATER(4)
        // - Bottoms: JEANS(5), PANTS(6), SHORTS(7)
        // - Shoes: SHOES(8)
        // - Accessories: ACCESSORY(9)
        let tops = garments.filter { $0.category == "Tops" }
        let bottoms = garments.filter { $0.category == "Bottoms" }
        let shoes = garments.filter { $0.category == "Shoes" }
        let accessories = garments.filter { $0.category == "Accessories" }
        
        // Select items based on availability and preferences
        // If no items available, create fallback items matching API structure
        let selectedTop: GarmentDTO
        if let top = tops.randomElement() ?? tops.first {
            selectedTop = top
        } else {
            // Fallback: Create a default top matching API structure
            // API: owner (int), category (Category enum), material (Material enum), color (str hex), name (str), image_url (str), dirty (bool)
            selectedTop = GarmentDTO(
                id: Int.random(in: 1000...9999),
                owner: "local",
                category: "Tops",
                color: .blue,
                name: "Blue T-Shirt",
                material: "Cotton",
                imageURL: nil,
                dirty: false
            )
        }
        
        let selectedBottom: GarmentDTO
        if let bottom = bottoms.randomElement() ?? bottoms.first {
            selectedBottom = bottom
        } else {
            // Fallback: Create a default bottom matching API structure
            selectedBottom = GarmentDTO(
                id: Int.random(in: 1000...9999),
                owner: "local",
                category: "Bottoms",
                color: .blue,
                name: "Blue Jeans",
                material: "Denim",
                imageURL: nil,
                dirty: false
            )
        }
        
        // Try to find preferred shoes if specified
        var selectedShoes: GarmentDTO
        if let preferredItems = preferredItems?.lowercased(), preferredItems.contains("boot") {
            selectedShoes = shoes.first { $0.name.lowercased().contains("boot") }
                ?? shoes.randomElement()
                ?? shoes.first
                ?? GarmentDTO(
                    id: Int.random(in: 1000...9999),
                    owner: "local",
                    category: "Shoes",
                    color: .brown,
                    name: "Boots",
                    material: "Leather",
                    imageURL: nil,
                    dirty: false
                )
        } else {
            selectedShoes = shoes.randomElement()
                ?? shoes.first
                ?? GarmentDTO(
                    id: Int.random(in: 1000...9999),
                    owner: "local",
                    category: "Shoes",
                    color: .white,
                    name: "Sneakers",
                    material: "Athletic",
                    imageURL: nil,
                    dirty: false
                )
        }
        
        let selectedAccessory = accessories.randomElement()
        
        // Create outfit matching the API response structure
        // The API would return outfit items with:
        // - id (int, auto-incremented)
        // - owner (int, but iOS uses "local" for local user)
        // - category (Category enum, mapped to UI string)
        // - material (Material enum, mapped to string)
        // - color (str hex code like "#0000FF")
        // - name (str, max 128 chars)
        // - image_url (str, max 512 chars)
        // - dirty (bool)
        // - created_at (datetime)
        let outfit = Outfit(
            id: Int.random(in: 1...10000),
            top: selectedTop.toClothingItem(),
            bottom: selectedBottom.toClothingItem(),
            shoes: selectedShoes.toClothingItem(),
            accessories: selectedAccessory?.toClothingItem()
        )
        
        return outfit
    }
}

