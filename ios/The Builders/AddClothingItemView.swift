import SwiftUI
import UIKit

struct AddClothingItemView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var wardrobeManager: WardrobeManager
    var onGarmentCreated: (() -> Void)? = nil
    
    @State private var selectedCategory: String = ClothingItem.Category.tops.rawValue
    @State private var itemName: String = ""
    @State private var selectedMaterial: String = "Cotton"
    @State private var selectedColor: Color = .purple
    @State private var itemNotes: String = ""
    @State private var imagePreview: Image?
    @State private var uploadImageData: Data?
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showImageSourcePicker = false
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    
    private let categories: [String] = ClothingItem.Category.allCases.map { $0.rawValue }
    private let materials = ["Cotton", "Denim", "Wool", "Corduroy", "Silk", "Satin", "Leather", "Athletic"]
    
    private var isFormValid: Bool {
        guard uploadImageData != nil else { return false }
        return !itemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 30) {
                            Spacer(minLength: 0)
                            
                            imagePickerSection
                            nameSection
                            categorySection
                            materialSection
                            colorSection
                            notesSection
                            
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: geometry.size.height - 150)
                        .padding(.top, 24)
                        .padding(.bottom, 24)
                    }
                    actionSection
                }
            }
            .background(Color(.systemGray6))
            .navigationBarHidden(true)
            .alert(
                "Unable to add item",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { newValue in
                        if !newValue { errorMessage = nil }
                    }
                ),
                actions: {
                    Button("OK", role: .cancel) { errorMessage = nil }
                },
                message: {
                    Text(errorMessage ?? "Unknown error")
                }
            )
        }
    }
    
    // MARK: - Sections
    
    private var imagePickerSection: some View {
        VStack(spacing: 16) {
            Button(action: {
                showImageSourcePicker = true
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 30)
                        .fill(Color.white)
                        .frame(height: 240)
                        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                    
                    if let preview = imagePreview {
                        preview
                            .resizable()
                            .scaledToFill()
                            .frame(height: 240)
                            .clipShape(RoundedRectangle(cornerRadius: 30))
                            .padding(.horizontal, 20)
                    } else {
                        HStack {
                            Spacer(minLength: 24)
                            VStack {
                                Image(systemName: "square.and.arrow.up")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 64, height: 64)
                                    .foregroundColor(.black)
                                Text("Upload")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            
                            Rectangle()
                                .fill(Color.purple.opacity(0.6))
                                .frame(width: 1, height: 160)
                            
                            VStack {
                                Image(systemName: "camera")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 64, height: 64)
                                    .foregroundColor(.black)
                                Text("Capture")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            Spacer(minLength: 24)
                        }
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
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
    
    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Item Name")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(Color.purple.opacity(0.8))
            
            TextField("e.g. Black Leather Jacket", text: $itemName)
                .font(.body)
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
        }
        .padding(.horizontal, 20)
    }
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Clothing Type")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(Color.purple.opacity(0.8))
            
            Picker("Clothing Type", selection: $selectedCategory) {
                ForEach(categories, id: \.self) { category in
                    Text(category).tag(category)
                }
            }
            .pickerStyle(.menu)
            .tint(.purple)
            .labelsHidden()
            .overlay(
                RoundedRectangle(cornerRadius: 25)
                    .stroke(Color.purple, lineWidth: 2)
            )
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color.purple.opacity(0.1))
            )
        }
        .padding(.horizontal, 20)
    }
    
    private var materialSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Material")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(Color.purple.opacity(0.8))
            
            Picker("Material", selection: $selectedMaterial) {
                ForEach(materials, id: \.self) { material in
                    Text(material).tag(material)
                }
            }
            .pickerStyle(.menu)
            .tint(.purple)
            .labelsHidden()
            .overlay(
                RoundedRectangle(cornerRadius: 25)
                    .stroke(Color.purple, lineWidth: 2)
            )
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color.purple.opacity(0.1))
            )
        }
        .padding(.horizontal, 20)
    }
    
    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Color")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(Color.purple.opacity(0.8))
            
            HStack(spacing: 16) {
                ColorPicker("Pick a color", selection: $selectedColor, supportsOpacity: false)
                    .labelsHidden()
                
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedColor)
                    .frame(width: 60, height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black.opacity(0.1), lineWidth: 1)
                    )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color.purple.opacity(0.1))
            )
        }
        .padding(.horizontal, 20)
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes (optional)")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(Color.purple.opacity(0.8))
            
            TextField("Add fit notes or care details...", text: $itemNotes, axis: .vertical)
                .font(.body)
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
                .lineLimit(2...5)
        }
        .padding(.horizontal, 20)
    }
    
    private var actionSection: some View {
        HStack(spacing: 16) {
            Button(action: { dismiss() }) {
                Text("Cancel")
                    .font(.headline)
                    .foregroundColor(.purple)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(Color.purple.opacity(0.5), lineWidth: 2)
                    )
            }
            
            Button(action: {
                Task { await submitItem() }
            }) {
                Group {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Add Item")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(isFormValid ? Color.purple : Color.gray)
                .cornerRadius(28)
            }
            .disabled(!isFormValid || isSubmitting)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            Rectangle()
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: -1)
        )
    }
    
    // MARK: - Private helpers
    
    private func submitItem() async {
        guard let imageData = uploadImageData else {
            await MainActor.run {
                errorMessage = "Please select an image before submitting."
            }
            return
        }
        
        await MainActor.run { isSubmitting = true }
        
        do {
            let garment = GarmentDTO(
                id: 0,
                owner: "local",
                category: selectedCategory,
                color: selectedColor,
                name: itemName.trimmingCharacters(in: .whitespacesAndNewlines),
                material: selectedMaterial,
                imageURL: nil,
                dirty: false
            )
            
            _ = try await wardrobeManager.createGarment(garment, imageData: imageData)
            
            await MainActor.run {
                isSubmitting = false
                onGarmentCreated?()
                dismiss()
            }
        } catch {
            await MainActor.run {
                isSubmitting = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    AddClothingItemView(wardrobeManager: WardrobeManager(api: MockGarmentAPI()))
}
