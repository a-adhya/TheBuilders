//
//  ClothingItemCard.swift
//  TheBuilders
//
//  Created by Cassie Liu on 10/28/25.
//

import SwiftUI

// Individual clothing item card component
struct ClothingItemCard: View {
    let item: ClothingItem
    let showLaundry: Bool
    let wardrobeManager: WardrobeManager
    @State private var showingDetail = false
    
    var body: some View {
        VStack {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .frame(height: 150)
                
                // Clothing representation
                clothingIcon
                
                // Laundry basket icon if item is in laundry and toggle is on
                if item.isInLaundry && showLaundry {
                    laundryIndicator
                }
                
                // Hide item if it's in laundry and toggle is off
                if item.isInLaundry && !showLaundry {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.gray.opacity(0.5))
                        .frame(height: 150)
                }
            }
        }
        .opacity(item.isInLaundry && !showLaundry ? 0.3 : 1.0)
        .onTapGesture {
            showingDetail = true
        }
        .sheet(isPresented: $showingDetail) {
            ClothingItemDetailView(item: item, wardrobeManager: wardrobeManager)
        }
    }
    
    // MARK: - Private Views
    
    @ViewBuilder
    private var clothingIcon: some View {
        if item.name.contains("T-Shirt") {
            // T-Shirt icon
            Image(systemName: "tshirt.fill")
                .font(.system(size: 60))
                .foregroundColor(item.color)
        } else if item.name.contains("Jeans") || item.name.contains("Pants") {
            // Pants icon
            RoundedRectangle(cornerRadius: 8)
                .fill(item.color)
                .frame(width: 40, height: 80)
        } else if item.name.contains("Dress") {
            // Dress icon
            Image(systemName: "figure.dress.line.vertical.figure")
                .font(.system(size: 60))
                .foregroundColor(item.color)
        } else if item.name.contains("Sneakers") || item.name.contains("Boots") {
            // Shoe icon
            Image(systemName: "shoeprints.fill")
                .font(.system(size: 40))
                .foregroundColor(item.color)
        } else {
            // For text-only items, show name in a rectangular box
            // Check if this looks like a text-only item (no common keywords)
            let hasImagePattern = item.name.contains("T-Shirt") || 
                                   item.name.contains("Jeans") || 
                                   item.name.contains("Pants") || 
                                   item.name.contains("Dress") || 
                                   item.name.contains("Sneakers") || 
                                   item.name.contains("Boots")
            
            if !hasImagePattern {
                // Text-only item: show name in rectangular box
                RoundedRectangle(cornerRadius: 12)
                    .fill(item.color.opacity(0.3))
                    .overlay(
                        Text(item.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(item.color)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .padding(8)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Generic accessory icon
                Image(systemName: "circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(item.color)
            }
        }
    }
    
    private var laundryIndicator: some View {
        VStack {
            HStack {
                Spacer()
                Image(systemName: "basket.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.gray)
                    .padding(8)
            }
            Spacer()
        }
    }
}