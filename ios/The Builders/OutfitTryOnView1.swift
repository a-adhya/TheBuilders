//
//  OutfitTryOnView1.swift
//  TheBuilders
//
//  Created by Cassie Liu on 10/28/25.
//

import SwiftUI

struct OutfitTryOnView1: View {
    @State var currentOutfit: Outfit
    @Environment(\.dismiss) private var dismiss
    @State private var navigateToConfirm = false
    @State private var isRegenerating = false
    @State private var navigateToRegenerate = false
    
    private let outfitAPI: OutfitAPI = MockOutfitAPI()
    
    init(outfit: Outfit) {
        _currentOutfit = State(initialValue: outfit)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
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
                        
                        ChatBubble(text: "Here is the outfit on your avatar. What do you think?")
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // Avatar display placeholder (white rectangle)
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .frame(height: 400)
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
                            navigateToConfirm = true
                        }) {
                            Text("Accept outfit")
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
            .navigationDestination(isPresented: $navigateToConfirm) {
                OutfitConfirm1(outfit: currentOutfit)
                    .onAppear {
                        navigateToConfirm = false
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

#Preview {
    OutfitTryOnView1(
        outfit: Outfit(
            id: 1,
            top: ClothingItem(id: 1, name: "Grey Cable Knit Sweater", color: .gray, isInLaundry: false, category: "Tops", description: "Comfortable grey sweater"),
            bottom: ClothingItem(id: 2, name: "Dark Green Pants", color: .green, isInLaundry: false, category: "Bottoms", description: "Comfortable dark green pants"),
            shoes: ClothingItem(id: 3, name: "Brown Boots", color: .brown, isInLaundry: false, category: "Shoes", description: "Brown lace-up boots"),
            accessories: nil
        )
    )
}

