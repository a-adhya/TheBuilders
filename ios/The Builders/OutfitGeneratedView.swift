//
//  OutfitGeneratedView.swift
//  TheBuilders
//
//  Created by Angshu Adhya on 11/4/2025.
//

import SwiftUI

struct OutfitGeneratedView: View {
    @State var currentOutfit: Outfit
    @Environment(\.dismiss) private var dismiss
    @State private var navigateToTryOn = false
    @State private var isRegenerating = false
    @State private var navigateToRegenerate = false
    
    private let outfitAPI: OutfitAPI = MockOutfitAPI()
    
    init(outfit: Outfit) {
        _currentOutfit = State(initialValue: outfit)
    }
    
    private var outfitItems: [ClothingItem] {
        var items = [currentOutfit.top, currentOutfit.bottom, currentOutfit.shoes]
        if let accessories = currentOutfit.accessories {
            items.append(accessories)
        }
        return items
    }
    
    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
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
                        
                        ChatBubble(text: "Based on your wardrobe and preferences, here is your outfit of the day.")
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // Outfit items display in 2-column grid with constrained height
                    LazyVGrid(columns: gridColumns, spacing: 12) {
                        ForEach(outfitItems, id: \.id) { item in
                            OutfitItemCard(item: item)
                                .frame(maxHeight: 150) // Constrain height so buttons are visible
                        }
                    }
                    .padding(.horizontal)
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            navigateToTryOn = true
                        }) {
                            Text("See outfit on avatar")
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.purple)
                                .cornerRadius(28)
                        }
                        .disabled(isRegenerating)
                        
                        Button(action: {
                            Task {
                                await regenerateOutfit()
                            }
                        }) {
                            if isRegenerating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(Color.purple)
                                    .cornerRadius(28)
                            } else {
                                Text("Regenerate outfit")
                                    .font(.title3)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(Color.purple)
                                    .cornerRadius(28)
                            }
                        }
                        .disabled(isRegenerating)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                .padding(.top, 20)
                .padding(.bottom, 100) // Extra padding for tab bar
            }
            .background(Color(.systemGray6))
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $navigateToTryOn) {
                OutfitTryOnView1(outfit: currentOutfit)
                    .onAppear {
                        navigateToTryOn = false
                    }
            }
            .navigationDestination(isPresented: $navigateToRegenerate) {
                OutfitTryOnView2(outfit: currentOutfit)
                    .onAppear {
                        navigateToRegenerate = false
                    }
            }
        }
    }
    
    private func regenerateOutfit() async {
        await MainActor.run {
            isRegenerating = true
        }
        
        do {
            let newOutfit = try await outfitAPI.generateOutfit(occasion: nil, preferredItems: nil, mood: nil)
            
            await MainActor.run {
                // Update current outfit and navigate to OutfitTryOnView2
                self.currentOutfit = newOutfit
                self.isRegenerating = false
                self.navigateToRegenerate = true
            }
        } catch {
            await MainActor.run {
                self.isRegenerating = false
            }
            print("Error regenerating outfit: \(error)")
        }
    }
}

// MARK: - Outfit Item Card

struct OutfitItemCard: View {
    let item: ClothingItem
    
    var body: some View {
        VStack(spacing: 8) {
            // Placeholder for clothing image - flexible sizing
            RoundedRectangle(cornerRadius: 12)
                .fill(item.color.opacity(0.3))
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    Image(systemName: getCategoryIcon(category: item.category))
                        .font(.system(size: 24))
                        .foregroundColor(item.color)
                )
                .frame(minHeight: 60, maxHeight: 100)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(item.category)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func getCategoryIcon(category: String) -> String {
        switch category.lowercased() {
        case "tops":
            return "tshirt.fill"
        case "bottoms":
            return "pants.fill"
        case "shoes":
            return "shoe.fill"
        case "accessories":
            return "watch.square.fill"
        default:
            return "tshirt.fill"
        }
    }
}

// MARK: - Bot Icon Component

struct BotIcon: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(
                    colors: [Color.purple, Color.blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 60, height: 60)
            
            // Robot face
            VStack(spacing: 4) {
                // Antenna
                Circle()
                    .fill(Color.white)
                    .frame(width: 6, height: 6)
                    .offset(y: -8)
                
                // Eyes
                HStack(spacing: 8) {
                    Circle().fill(Color.white).frame(width: 10, height: 10)
                    Circle().fill(Color.white).frame(width: 10, height: 10)
                }
                
                // Smiling mouth
                CustomArc(startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: 14, height: 7)
            }
        }
    }
}

// MARK: - Chat Bubble Component

struct ChatBubble: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.body)
            .foregroundColor(.black)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                    
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                }
            )
    }
}

#Preview {
    OutfitGeneratedView(
        outfit: Outfit(
            id: 1,
            top: ClothingItem(id: 1, name: "Grey Cable Knit Sweater", color: .gray, isInLaundry: false, category: "Tops", description: "Comfortable grey sweater"),
            bottom: ClothingItem(id: 2, name: "Dark Green Pants", color: .green, isInLaundry: false, category: "Bottoms", description: "Comfortable dark green pants"),
            shoes: ClothingItem(id: 3, name: "Brown Boots", color: .brown, isInLaundry: false, category: "Shoes", description: "Brown lace-up boots"),
            accessories: nil
        )
    )
}

