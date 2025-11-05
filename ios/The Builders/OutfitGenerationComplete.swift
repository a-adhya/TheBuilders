//
//  OutfitGenerationComplete.swift
//  TheBuilders
//
//  Created by Angshu Adhya on 11/4/2025.
//

import SwiftUI
import Combine

struct OutfitGenerationComplete: View {
    let outfit: Outfit
    let selectedOption: OutfitConfirm1.LaundryOption
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var tabSelection: TabSelectionManager
    
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
                        
                        ChatBubble(text: "Glad you liked this outfit! Would you like to generate another one or return to home?")
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // Empty space (no avatar display on this screen) - reduced height
                    Color.clear
                        .frame(height: 150)
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            // Switch to outfit generator tab and pop to root
                            tabSelection.selectedTab = 1
                            // Dismiss all navigation views to get back to root
                            dismiss()
                        }) {
                            Text("Generate another outfit")
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.purple)
                                .cornerRadius(28)
                        }
                        
                        Button(action: {
                            // Switch to home tab and dismiss all navigation views
                            tabSelection.selectedTab = 0
                            dismiss()
                        }) {
                            Text("Return to home")
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
        }
    }
}

#Preview {
    OutfitGenerationComplete(
        outfit: Outfit(
            id: 1,
            top: ClothingItem(id: 1, name: "Grey Cable Knit Sweater", color: .gray, isInLaundry: false, category: "Tops", description: "Comfortable grey sweater"),
            bottom: ClothingItem(id: 2, name: "Dark Green Pants", color: .green, isInLaundry: false, category: "Bottoms", description: "Comfortable dark green pants"),
            shoes: ClothingItem(id: 3, name: "Brown Boots", color: .brown, isInLaundry: false, category: "Shoes", description: "Brown lace-up boots"),
            accessories: nil
        ),
        selectedOption: OutfitConfirm1.LaundryOption.wardrobe
    )
}

