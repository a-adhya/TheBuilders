//
//  OutfitTryOnView2.swift
//  TheBuilders
//
//  Created by Angshu Adhya on 11/4/2025.
//

import SwiftUI

struct OutfitTryOnView2: View {
    @State var currentOutfit: Outfit
    @Environment(\.dismiss) private var dismiss
    @State private var navigateToTryOn = false
    @State private var isRegenerating = false
    
    private let outfitAPI: OutfitAPI = RealOutfitAPI()
    private let userId: Int = 1 // Default user ID, can be made dynamic later
    
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
                        
                        ChatBubble(text: "No worries! Here is another outfit for you.")
                        
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
        }
    }
    
    private func regenerateOutfit() async {
        await MainActor.run {
            isRegenerating = true
        }
        
        // Agentic loop: handle tool requests until we get garments
        var previousMessages: [[String: Any]]? = nil
        
        while true {
            do {
                let result = try await outfitAPI.generateOutfit(context: "", userId: userId, previousMessages: previousMessages)
                
                switch result {
                case .garments(let garments):
                    if garments.isEmpty {
                        await MainActor.run {
                            self.isRegenerating = false
                        }
                        print("Error: no garments found")
                        return
                    }
                    
                    guard let newOutfit = garmentsToOutfit(garments: garments) else {
                        await MainActor.run {
                            self.isRegenerating = false
                        }
                        print("Error: Could not generate outfit from available garments")
                        return
                    }
                    
                    await MainActor.run {
                        self.currentOutfit = newOutfit
                        self.isRegenerating = false
                    }
                    return
                    
                case .toolRequest(let messages, let toolName):
                    if toolName == "get_location" {
                        let locationService = LocationService()
                        do {
                            let (latitude, longitude) = try await locationService.getCurrentLocation()
                            previousMessages = updateLocationToolResult(
                                previousMessages: messages,
                                latitude: latitude,
                                longitude: longitude
                            )
                            continue
                        } catch {
                            await MainActor.run {
                                self.isRegenerating = false
                            }
                            print("Failed to get location: \(error.localizedDescription)")
                            return
                        }
                    } else {
                        await MainActor.run {
                            self.isRegenerating = false
                        }
                        print("Unknown tool request: \(toolName)")
                        return
                    }
                }
            } catch {
                await MainActor.run {
                    self.isRegenerating = false
                }
                print("Error regenerating outfit: \(error)")
                return
            }
        }
    }
}

#Preview {
    OutfitTryOnView2(
        outfit: Outfit(
            id: 1,
            top: ClothingItem(id: 1, name: "Grey Cable Knit Sweater", color: .gray, isInLaundry: false, category: "Tops", description: "Comfortable grey sweater", imageURL: nil),
            bottom: ClothingItem(id: 2, name: "Dark Green Pants", color: .green, isInLaundry: false, category: "Bottoms", description: "Comfortable dark green pants", imageURL: nil),
            shoes: ClothingItem(id: 3, name: "Brown Boots", color: .brown, isInLaundry: false, category: "Shoes", description: "Brown lace-up boots", imageURL: nil),
            accessories: nil
        )
    )
}

