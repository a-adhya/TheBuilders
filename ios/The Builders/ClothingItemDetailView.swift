//
//  ClothingItemDetailView.swift
//  TheBuilders
//
//  Created by Cassie Liu on 10/28/25.
//

import SwiftUI
import UIKit

// Clothing Item Detail View
struct ClothingItemDetailView: View {
    @State private var item: ClothingItem
    @State private var selectedCategory: String
    @State private var itemDescription: String
    @State private var imagePreview: Image?
    @State private var uploadImageData: Data?
    @State private var showImageSourcePicker = false
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @Environment(\.dismiss) private var dismiss
    
    let wardrobeManager: WardrobeManager
    let categories: [String]
    
    init(item: ClothingItem, wardrobeManager: WardrobeManager) {
        self._item = State(initialValue: item)
        self._selectedCategory = State(initialValue: item.category)
        // Use a sensible default category list so dropdown actually has options
        let defaultCategories = [
            "Tops",
            "Bottoms",
            "Dresses",
            "Shoes",
            "Accessories"
        ]
        // If current item.category exists in defaults, keep it; otherwise append it
        var all = defaultCategories
        if !all.contains(item.category) {
            all.append(item.category)
        }
        self.categories = all
        self._itemDescription = State(initialValue: item.description)
        self.wardrobeManager = wardrobeManager
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Content
                ScrollView {
                    VStack(spacing: 30) {
                        // Clothing Image Section
                        clothingImageSection
                        
                        // Category Section
                        categorySection
                        
                        // Description Section
                        descriptionSection
                        
                        Spacer(minLength: 100)
                    }
                }
                
                // Bottom buttons
                bottomButtonsSection
            }
            .background(Color(.systemGray6))
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - Private Views
    
    private var clothingImageSection: some View {
        VStack {
            Button(action: {
                showImageSourcePicker = true
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 30)
                        .fill(Color.white)
                        .frame(width: 300, height: 300)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    
                    // Large clothing representation
                    clothingIcon
                    
                    // Edit icon in top right
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "pencil")
                                .font(.system(size: 20))
                                .foregroundColor(.gray)
                                .padding(12)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(0.8))
                                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                                )
                        }
                        Spacer()
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .confirmationDialog("Select Image Source", isPresented: $showImageSourcePicker, titleVisibility: .visible) {
            Button("Camera") {
                showCamera = true
            }
            Button("Photo Library") {
                showPhotoLibrary = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(sourceType: .camera, selectedImage: $imagePreview, imageData: $uploadImageData)
        }
        .sheet(isPresented: $showPhotoLibrary) {
            ImagePicker(sourceType: .photoLibrary, selectedImage: $imagePreview, imageData: $uploadImageData)
        }
    }
    
    @ViewBuilder
    private var clothingIcon: some View {
        if let preview = imagePreview {
            preview
                .resizable()
                .scaledToFill()
                .frame(width: 260, height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 25))
        } else if let imageURL = item.imageURL {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                        .frame(width: 200, height: 200)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 260, height: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 25))
                case .failure:
                    Image(systemName: "photo")
                        .font(.system(size: 100))
                        .foregroundColor(.gray)
                @unknown default:
                    EmptyView()
                }
            }
        } else if item.name.contains("T-Shirt") {
            Image(systemName: "tshirt.fill")
                .font(.system(size: 150))
                .foregroundColor(item.color)
        } else if item.name.contains("Jeans") || item.name.contains("Pants") {
            RoundedRectangle(cornerRadius: 15)
                .fill(item.color)
                .frame(width: 80, height: 160)
        } else if item.name.contains("Dress") {
            Image(systemName: "figure.dress.line.vertical.figure")
                .font(.system(size: 150))
                .foregroundColor(item.color)
        } else if item.name.contains("Sneakers") || item.name.contains("Boots") {
            Image(systemName: "shoeprints.fill")
                .font(.system(size: 100))
                .foregroundColor(item.color)
        } else {
            Image(systemName: "circle.fill")
                .font(.system(size: 100))
                .foregroundColor(item.color)
        }
    }
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Clothing Type")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(Color.purple.opacity(0.8))
                Spacer()
            }

            // Real dropdown using Picker with menu style
            Picker("Clothing Type", selection: $selectedCategory) {
                ForEach(categories, id: \.self) { category in
                    Text(category).tag(category)
                }
            }
            .pickerStyle(.menu)
            .tint(.purple)
            .labelsHidden()
            .overlay(
                // Keep your rounded rectangle look
                RoundedRectangle(cornerRadius: 25)
                    .stroke(Color.purple, lineWidth: 2)
            )
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color.purple.opacity(0.1))
            )
            .padding(.horizontal, 0)
        }
        .padding(.horizontal, 20)
    }
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Description")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(Color.purple.opacity(0.8))
                Spacer()
            }
            
            TextField("Enter description...", text: $itemDescription, axis: .vertical)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.purple)
                .padding(.horizontal, 20)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(Color.purple, lineWidth: 2)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color.purple.opacity(0.1))
                        )
                )
                .lineLimit(3...6)
        }
        .padding(.horizontal, 20)
    }
    
    private var bottomButtonsSection: some View {
        HStack(spacing: 0) {
            // Back button
            Button(action: {
                dismiss()
            }) {
                VStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 24))
                        .foregroundColor(.purple)
                    Text("Back")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.purple)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Update button
            Button(action: {
                Task { await updateItem() }
            }) {
                VStack(spacing: 8) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 24))
                        .foregroundColor(.purple)
                    Text("Update")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.purple)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Delete button
            Button(action: {
                Task { await deleteItem() }
            }) {
                VStack(spacing: 8) {
                    Image(systemName: "trash")
                        .font(.system(size: 24))
                        .foregroundColor(.red)
                    Text("Trash")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.red)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .background(
            Rectangle()
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: -1)
        )
    }
    
    // MARK: - Private Methods
    
    private func updateItem() async {
        var updatedItem = item
        // Model uses String for category; assign directly
        updatedItem.category = selectedCategory
        updatedItem.description = itemDescription

        await wardrobeManager.updateItem(updatedItem, imageData: uploadImageData)
        dismiss()
    }
    
    private func deleteItem() async {
        await wardrobeManager.deleteItem(withId: item.id)
        dismiss()
    }
}

