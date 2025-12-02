//
//  OutfitTryOnView1.swift
//  TheBuilders
//
//  Created by Angshu Adhya on 11/4/2025.
//

import SwiftUI

struct OutfitTryOnView1: View {
    @State var currentOutfit: Outfit
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var avatarManager: AvatarManager
    @State private var navigateToConfirm = false
    @State private var isRegenerating = false
    @State private var navigateToRegenerate = false
    @State private var tryOnImage: UIImage?
    @State private var isLoadingTryOn = false
    @State private var tryOnError: String?
    
    private let outfitAPI: OutfitAPI = RealOutfitAPI()
    // Use MockAvatarAPI if USE_MOCK_TRY_ON is true, otherwise use RealAvatarAPI
    private let avatarAPI: AvatarAPIProtocol = USE_MOCK_TRY_ON ? MockAvatarAPI() : RealAvatarAPI()
    private let userId: Int = 1 // Default user ID, can be made dynamic later
    
    init(outfit: Outfit) {
        _currentOutfit = State(initialValue: outfit)
    }
    
    /// Extracts garment IDs from the current outfit
    private var garmentIds: [Int] {
        var ids = [currentOutfit.top.id, currentOutfit.bottom.id, currentOutfit.shoes.id]
        if let accessories = currentOutfit.accessories {
            ids.append(accessories.id)
        }
        return ids
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
                    
                    // Avatar display with try-on image
                    ZStack {
                        if isLoadingTryOn {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white)
                                .frame(width: 300, height: 450)
                                .overlay(
                                    VStack(spacing: 16) {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle())
                                        Text("Generating try-on preview...")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.purple.opacity(0.3), lineWidth: 2)
                                )
                                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                        } else if let tryOnImage = tryOnImage {
                            Image(uiImage: tryOnImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 300, height: 450)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.purple.opacity(0.3), lineWidth: 2)
                                )
                                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                        } else if let error = tryOnError {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white)
                                .frame(width: 300, height: 450)
                                .overlay(
                                    VStack(spacing: 8) {
                                        Image(systemName: "exclamationmark.triangle")
                                            .font(.title)
                                            .foregroundColor(.red)
                                        Text("Failed to load preview")
                                            .font(.headline)
                                            .foregroundColor(.red)
                                        Text(error)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal)
                                    }
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.purple.opacity(0.3), lineWidth: 2)
                                )
                                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                        } else {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white)
                                .frame(width: 300, height: 450)
                                .overlay(
                                    VStack {
                                        Text("Avatar Preview")
                                            .font(.headline)
                                            .foregroundColor(.gray)
                                        Text("(Loading...)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.purple.opacity(0.3), lineWidth: 2)
                                )
                                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            // Update avatar with try-on image immediately when accepting outfit
                            if let tryOnImage = tryOnImage {
                                avatarManager.updateAvatar(tryOnImage)
                            }
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
            .onAppear {
                Task {
                    await loadTryOnImage()
                }
            }
            .navigationDestination(isPresented: $navigateToConfirm) {
                OutfitConfirm1(outfit: currentOutfit, tryOnImage: tryOnImage)
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
    
    @MainActor
    private func regenerateOutfit() async {
        isRegenerating = true
        
        do {
            // Call backend with empty context for regeneration
            let garments = try await outfitAPI.generateOutfit(context: "", userId: userId)
            
            if garments.isEmpty {
                isRegenerating = false
                print("Error: no garments found")
                return
            }
            
            // Convert garments to Outfit structure
            guard let newOutfit = garmentsToOutfit(garments: garments) else {
                isRegenerating = false
                print("Error: Could not generate outfit from available garments")
                return
            }
            
            // Update current outfit and navigate to OutfitTryOnView2
            self.currentOutfit = newOutfit
            self.isRegenerating = false
            self.navigateToRegenerate = true
            
            // Reload try-on image with new outfit
            await loadTryOnImage()
        } catch {
            self.isRegenerating = false
            print("Error regenerating outfit: \(error)")
        }
    }
    
    /// Loads the try-on preview image for the current outfit
    @MainActor
    private func loadTryOnImage() async {
        isLoadingTryOn = true
        tryOnError = nil
        
        do {
            let image = try await avatarAPI.tryOn(userId: userId, garmentIds: garmentIds)
            self.tryOnImage = image
            self.isLoadingTryOn = false
        } catch {
            self.tryOnError = error.localizedDescription
            self.isLoadingTryOn = false
            print("Error loading try-on image: \(error)")
        }
    }
}

#Preview {
    OutfitTryOnView1(
        outfit: Outfit(
            id: 1,
            top: ClothingItem(id: 1, name: "Grey Cable Knit Sweater", color: .gray, isInLaundry: false, category: "Tops", description: "Comfortable grey sweater", imageURL: nil),
            bottom: ClothingItem(id: 2, name: "Dark Green Pants", color: .green, isInLaundry: false, category: "Bottoms", description: "Comfortable dark green pants", imageURL: nil),
            shoes: ClothingItem(id: 3, name: "Brown Boots", color: .brown, isInLaundry: false, category: "Shoes", description: "Brown lace-up boots", imageURL: nil),
            accessories: nil
        )
    )
}

