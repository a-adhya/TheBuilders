//
//  WardrobeView.swift
//  TheBuilders
//
//  Created by Cassie Liu on 10/28/25.
//

import SwiftUI

struct WardrobeView: View {
    @StateObject private var wardrobeManager = WardrobeManager()
    @State private var selectedCategory = "Tops"
    @State private var showLaundry = false
    @State private var selectedIndex = 0
    @State private var showingAddItem = false
    @State private var showingAddItemWithText = false
    @State private var displayedItems: [ClothingItem] = []
    
    let categories = ClothingItem.Category.allCases.map { $0.rawValue }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category tabs
                CategoryTabView(
                    categories: categories,
                    selectedCategory: $selectedCategory,
                    selectedIndex: $selectedIndex
                )
                
                // View Laundry toggle
                laundryToggleSection
                
                // Content area
                clothingItemsGrid
                
                // Add Item buttons
                addItemButtons
            }
            .background(Color(.systemGray6))
            .navigationBarHidden(true)
            .task { await refreshItems() }
        }
        .sheet(isPresented: $showingAddItem) {
            AddClothingItemView()
        }
        .sheet(isPresented: $showingAddItemWithText) {
            AddItemWithTextView(wardrobeManager: wardrobeManager)
                .onDisappear {
                    Task {
                        await refreshItems()
                    }
                }
        }
        .onChange(of: showLaundry) { _, _ in
            Task { await refreshItems() }
        }
        .onChange(of: selectedCategory) { _, _ in
            Task { await refreshItems() }
        }
    }
    
    // MARK: - Private Views
    
    private var laundryToggleSection: some View {
        HStack(spacing: 12) {
            Text("View Laundry")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.purple)

            Spacer(minLength: 0)

            Toggle("", isOn: $showLaundry)
                .labelsHidden()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
    
    private var clothingItemsGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(displayedItems) { item in
                    ZStack {
                        ClothingItemCard(
                            item: item,
                            showLaundry: showLaundry,
                            wardrobeManager: wardrobeManager
                        )

                        VStack {
                            HStack {
                                Spacer()
                                if showLaundry {
                                    // Restore from laundry button (top-right)
                                    Button(action: {
                                        Task {
                                            await wardrobeManager.returnFromLaundry(itemId: item.id)
                                            await refreshItems()
                                        }
                                    }) {
                                        Image(systemName: "arrow.uturn.left")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.purple)
                                            .padding(8)
                                            .background(
                                                Circle().fill(Color.white)
                                                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                                            )
                                    }
                                } else {
                                    // Send to laundry button (top-right)
                                    Button(action: {
                                        Task {
                                            await wardrobeManager.sendToLaundry(itemId: item.id)
                                            await refreshItems()
                                        }
                                    }) {
                                        Image(systemName: "basket.fill")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.gray)
                                            .padding(8)
                                            .background(
                                                Circle().fill(Color.white)
                                                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                                            )
                                    }
                                }
                            }
                            Spacer()
                        }
                        .padding(8)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
    }

    // MARK: - Data Loading
    private func refreshItems() async {
        if showLaundry {
            // Only laundry items in the selected category
            let allLaundry = await wardrobeManager.getLaundryItems()
            displayedItems = allLaundry.filter { $0.category == selectedCategory }
        } else {
            displayedItems = await wardrobeManager.getAvailableItems(for: selectedCategory)
        }
    }
    
    private var addItemButtons: some View {
        VStack(spacing: 12) {
            Button(action: {
                showingAddItem = true
            }) {
                Text("Add Item with Image+")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.purple.opacity(0.7))
                    .cornerRadius(25)
            }
            
            Button(action: {
                showingAddItemWithText = true
            }) {
                Text("Add Item with Text+")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.purple.opacity(0.7))
                    .cornerRadius(25)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 100) // Extra space for tab bar
    }
}
#Preview {
    WardrobeView()
}
