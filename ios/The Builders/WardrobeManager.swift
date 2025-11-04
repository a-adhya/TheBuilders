//
//  WardrobeManager.swift
//  TheBuilders
//
//  Created by Cassie Liu on 10/28/25.
//

import SwiftUI
import Combine

//TODO: Fake DB, need to connect with backend
// Observable data manager for clothing items
class WardrobeManager: ObservableObject {
    @Published var items: [ClothingItem] = []
    
    // Categories for easy access
    let categories: [String] = ClothingItem.Category.allCases.map { category in category.rawValue }
    
    init() {
        loadSampleData()
    }
    
    private func loadSampleData() {
        items = [
            ClothingItem(id: 1, name: "Blue T-Shirt", color: .blue, isInLaundry: false, category: "Tops", description: "Comfortable cotton blue t-shirt"),
            ClothingItem(id: 2, name: "Green T-Shirt", color: .green, isInLaundry: false, category: "Tops", description: "Soft green casual tee"),
            ClothingItem(id: 3, name: "Orange T-Shirt", color: .orange, isInLaundry: true, category: "Tops", description: "Bright orange summer shirt"),
            ClothingItem(id: 4, name: "Red T-Shirt", color: .red, isInLaundry: false, category: "Tops", description: "Classic red cotton t-shirt"),
            ClothingItem(id: 5, name: "Blue Jeans", color: .blue, isInLaundry: false, category: "Bottoms", description: "Comfortable denim jeans"),
            ClothingItem(id: 6, name: "Black Pants", color: .black, isInLaundry: false, category: "Bottoms", description: "Formal black trousers"),
            ClothingItem(id: 7, name: "Summer Dress", color: .pink, isInLaundry: false, category: "Dresses", description: "Light pink summer dress"),
            ClothingItem(id: 8, name: "Evening Dress", color: .black, isInLaundry: true, category: "Dresses", description: "Elegant black evening gown"),
            ClothingItem(id: 9, name: "Sneakers", color: .white, isInLaundry: false, category: "Shoes", description: "White running sneakers"),
            ClothingItem(id: 10, name: "Boots", color: .brown, isInLaundry: false, category: "Shoes", description: "Brown leather boots"),
            ClothingItem(id: 11, name: "Watch", color: .gray, isInLaundry: false, category: "Accessories", description: "Silver wrist watch"),
            ClothingItem(id: 12, name: "Hat", color: .gray, isInLaundry: false, category: "Accessories", description: "Gray baseball cap"),
        ]
    }
    
    // MARK: - Public Methods
    
    func updateItem(_ updatedItem: ClothingItem) {
        if let index = items.firstIndex(where: { $0.id == updatedItem.id }) {
            items[index] = updatedItem
        }
    }
    
    func deleteItem(withId id: Int) {
        items.removeAll { $0.id == id }
    }
    
    func getItems(for category: String) -> [ClothingItem] {
        return items.filter { $0.category == category }
    }
    
    func getAvailableItems(for category: String) -> [ClothingItem] {
        return items.filter { $0.category == category && !$0.isInLaundry }
    }
    
    func getLaundryItems() -> [ClothingItem] {
        return items.filter { $0.isInLaundry }
    }
}
