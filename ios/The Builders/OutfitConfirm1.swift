//
//  OutfitConfirm1.swift
//  TheBuilders
//
//  Created by Angshu Adhya on 11/4/2025.
//

import SwiftUI

struct OutfitConfirm1: View {
    let outfit: Outfit
    @Environment(\.dismiss) private var dismiss
    @State private var navigateToComplete = false
    @State private var selectedOption: LaundryOption?
    
    enum LaundryOption {
        case laundry
        case wardrobe
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Back button
                    HStack {
                        Button(action: {
                            dismiss()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .medium))
                                Text("Back")
                                    .font(.body)
                            }
                            .foregroundColor(.purple)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Bot message
                    HStack(alignment: .top) {
                        BotIcon()
                            .padding(.trailing, 12)
                        
                        ChatBubble(text: "Great outfit choice! Would you like to place these items in laundry or keep them active in your wardrobe?")
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // Avatar display placeholder (white rectangle) - reduced height
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .frame(height: 200)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .overlay(
                            VStack {
                                Text("Avatar Preview")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                Text("(Image placeholder)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        )
                        .padding(.horizontal)
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            selectedOption = .laundry
                            navigateToComplete = true
                        }) {
                            Text("Put in laundry")
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.purple)
                                .cornerRadius(28)
                        }
                        
                        Button(action: {
                            selectedOption = .wardrobe
                            navigateToComplete = true
                        }) {
                            Text("Keep in wardrobe")
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.purple)
                                .cornerRadius(28)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                .padding(.top, 20)
                .padding(.bottom, 100) // Extra padding for tab bar
            }
            .background(Color(.systemGray6))
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $navigateToComplete) {
                OutfitGenerationComplete(outfit: outfit, selectedOption: selectedOption ?? .wardrobe)
            }
        }
    }
}

#Preview {
    OutfitConfirm1(
        outfit: Outfit(
            id: 1,
            top: ClothingItem(id: 1, name: "Grey Cable Knit Sweater", color: .gray, isInLaundry: false, category: "Tops", description: "Comfortable grey sweater"),
            bottom: ClothingItem(id: 2, name: "Dark Green Pants", color: .green, isInLaundry: false, category: "Bottoms", description: "Comfortable dark green pants"),
            shoes: ClothingItem(id: 3, name: "Brown Boots", color: .brown, isInLaundry: false, category: "Shoes", description: "Brown lace-up boots"),
            accessories: nil
        )
    )
}

