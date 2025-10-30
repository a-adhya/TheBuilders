//
//  ModelsClothingItem.swift  
//  TheBuilders
//
//  Created by Cassie Liu on 10/28/25.
//

import SwiftUI

// Data model for clothing items
struct ClothingItem: Identifiable, Equatable {
    let id: Int
    var name: String
    let color: Color
    var isInLaundry: Bool
    var category: String
    var description: String
    
    // Categories enum for type safety
    enum Category: String, CaseIterable {
        case tops = "Tops"
        case bottoms = "Bottoms"  
        case dresses = "Dresses"
        case shoes = "Shoes"
        case accessories = "Accessories"
    }
}

