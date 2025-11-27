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

// MARK: - Outfit API
// This follows the actual API structure from src/api/schema.py and src/models/enums.py

protocol OutfitAPI {
    func generateOutfit(context: String, userId: Int) async throws -> [GarmentDTO]
}

final class RealOutfitAPI: OutfitAPI {
    private let baseURL: String
    
    init(baseURL: String = "http://192.168.86.28:8000") {
        self.baseURL = baseURL
    }
    
    func generateOutfit(context: String, userId: Int) async throws -> [GarmentDTO] {
        guard let url = URL(string: "\(baseURL)/generate_outfit?user_id=\(userId)") else {
            throw URLError(.badURL)
        }
        
        // Create request body
        struct GenerateOutfitRequest: Codable {
            let optional_string: String?
        }
        
        let requestBody = GenerateOutfitRequest(optional_string: context.isEmpty ? nil : context)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 500 {
                // Check if it's a "no garments" error
                if let errorData = try? JSONDecoder().decode([String: String].self, from: data),
                   let detail = errorData["detail"],
                   detail.contains("no garments") || detail.contains("No garments") {
                    return [] // Return empty array for no garments
                }
            }
            // Capture the response body as a string for error display
            let responseBody = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            throw NSError(domain: "RealOutfitAPI", code: httpResponse.statusCode, userInfo: [
                NSLocalizedDescriptionKey: responseBody
            ])
        }
        
        // Decode API response
        struct GenerateOutfitResponse: Codable {
            let garments: [OutfitAPIGarmentResponse]
        }
        
        struct OutfitAPIGarmentResponse: Codable {
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
                // Convert API category to UI category
                let uiCategory: String
                switch category {
                case 1, 2, 3, 4: // SHIRT, TSHIRT, JACKET, SWEATER
                    uiCategory = "Tops"
                case 5, 6, 7: // JEANS, PANTS, SHORTS
                    uiCategory = "Bottoms"
                case 8: // SHOES
                    uiCategory = "Shoes"
                case 9: // ACCESSORY
                    uiCategory = "Accessories"
                default:
                    uiCategory = "Tops"
                }
                
                // Convert API material to string
                let materialString: String
                switch material {
                case 1: materialString = "Cotton"
                case 2: materialString = "Denim"
                case 3: materialString = "Wool"
                case 4: materialString = "Corduroy"
                case 5: materialString = "Silk"
                case 6: materialString = "Satin"
                case 7: materialString = "Leather"
                case 8: materialString = "Athletic"
                default: materialString = "Cotton"
                }
                
                // Convert hex color to SwiftUI Color
                var hexSanitized = color.trimmingCharacters(in: .whitespacesAndNewlines)
                hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
                var rgb: UInt64 = 0
                Scanner(string: hexSanitized).scanHexInt64(&rgb)
                let r = Double((rgb & 0xFF0000) >> 16) / 255.0
                let g = Double((rgb & 0x00FF00) >> 8) / 255.0
                let b = Double(rgb & 0x0000FF) / 255.0
                let swiftColor = Color(red: r, green: g, blue: b)
                
                return GarmentDTO(
                    id: id,
                    owner: String(owner),
                    category: uiCategory,
                    color: swiftColor,
                    name: name,
                    material: materialString,
                    imageURL: URL(string: image_url),
                    dirty: dirty
                )
            }
        }
        
        let apiResponse = try JSONDecoder().decode(GenerateOutfitResponse.self, from: data)
        
        // Convert API garments to DTOs
        return apiResponse.garments.map { $0.toDTO() }
    }
}

final class MockOutfitAPI: OutfitAPI {
    private let garmentAPI: GarmentAPI
    private let latencyMs: UInt64
    
    init(garmentAPI: GarmentAPI = MockGarmentAPI(), latencyMs: UInt64 = 500) {
        self.garmentAPI = garmentAPI
        self.latencyMs = latencyMs
    }
    
    func generateOutfit(context: String, userId: Int) async throws -> [GarmentDTO] {
        // For mock, ignore context and userId, just return mock garments
        try await Task.sleep(nanoseconds: latencyMs * 1_000_000)
        
        let garments = try await garmentAPI.fetchGarments(owner: "local")
            .filter { !$0.dirty }
        
        // Return a sample outfit - top, bottom, shoes, optional accessory
        let tops = garments.filter { $0.category == "Tops" }
        let bottoms = garments.filter { $0.category == "Bottoms" }
        let shoes = garments.filter { $0.category == "Shoes" }
        let accessories = garments.filter { $0.category == "Accessories" }
        
        var outfit: [GarmentDTO] = []
        if let top = tops.randomElement() ?? tops.first {
            outfit.append(top)
        }
        if let bottom = bottoms.randomElement() ?? bottoms.first {
            outfit.append(bottom)
        }
        if let shoe = shoes.randomElement() ?? shoes.first {
            outfit.append(shoe)
        }
        if let accessory = accessories.randomElement() {
            outfit.append(accessory)
        }
        
        return outfit
    }
    
    // Legacy method for backward compatibility (deprecated)
    func generateOutfitLegacy(occasion: String?, preferredItems: String?, mood: String?) async throws -> Outfit {
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

// Helper function to convert garment DTOs to Outfit structure
func garmentsToOutfit(garments: [GarmentDTO]) -> Outfit? {
    let tops = garments.filter { $0.category == "Tops" }
    let bottoms = garments.filter { $0.category == "Bottoms" }
    let shoes = garments.filter { $0.category == "Shoes" }
    let accessories = garments.filter { $0.category == "Accessories" }
    
    guard let top = tops.first,
          let bottom = bottoms.first,
          let shoe = shoes.first else {
        return nil // Need at least top, bottom, and shoes
    }
    
    return Outfit(
        id: Int.random(in: 1...10000),
        top: top.toClothingItem(),
        bottom: bottom.toClothingItem(),
        shoes: shoe.toClothingItem(),
        accessories: accessories.first?.toClothingItem()
    )
}

