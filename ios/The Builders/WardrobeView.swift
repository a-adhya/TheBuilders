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
                
                // Add Item button
                addItemButton
            }
            .background(Color(.systemGray6))
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingAddItem) {
            AddClothingItemView()
        }
    }
    
    // MARK: - Private Views
    
    private var laundryToggleSection: some View {
        HStack {
            Text("View Laundry")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.purple)
            
            Spacer()
            
            Toggle("", isOn: $showLaundry)
                .labelsHidden()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
    private var clothingItemsGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 20) {
                ForEach(wardrobeManager.getItems(for: selectedCategory)) { item in
                    ClothingItemCard(
                        item: item,
                        showLaundry: showLaundry,
                        wardrobeManager: wardrobeManager
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
    }
    
    private var addItemButton: some View {
        Button(action: {
            showingAddItem = true
        }) {
            Text("Add Item +")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.purple.opacity(0.7))
                .cornerRadius(25)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 100) // Extra space for tab bar
    }
}
#Preview {
    WardrobeView()
}
