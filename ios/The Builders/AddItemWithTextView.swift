//
//  AddItemWithTextView.swift
//  TheBuilders
//
//  Created by Angshu Adhya on 11/4/2025.
//

import SwiftUI

struct AddItemWithTextView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: String = ClothingItem.Category.tops.rawValue
    @State private var selectedColor: Color = .blue
    @State private var itemName: String = ""
    @State private var selectedMaterial: String = "Cotton"
    @State private var isSubmitting = false
    @State private var showSuccess = false
    
    let wardrobeManager: WardrobeManager
    
    private let categories: [String] = ClothingItem.Category.allCases.map { $0.rawValue }
    private let materials = ["Cotton", "Denim", "Wool", "Corduroy", "Silk", "Satin", "Leather", "Athletic"]
    private let colors: [(String, Color)] = [
        // Primary Colors
        ("Red", .red),
        ("Blue", .blue),
        ("Green", .green),
        ("Yellow", .yellow),
        ("Orange", .orange),
        ("Purple", .purple),
        ("Pink", .pink),
        
        // Neutrals
        ("Black", .black),
        ("White", .white),
        ("Gray", .gray),
        ("Brown", .brown),
        
        // Blues
        ("Navy", Color(red: 0.0, green: 0.0, blue: 0.5)),
        ("Sky Blue", Color(red: 0.53, green: 0.81, blue: 0.92)),
        ("Teal", Color(red: 0.0, green: 0.5, blue: 0.5)),
        ("Turquoise", Color(red: 0.25, green: 0.88, blue: 0.82)),
        ("Cyan", .cyan),
        ("Indigo", Color(red: 0.29, green: 0.0, blue: 0.51)),
        
        // Greens
        ("Lime", .green.opacity(0.7)),
        ("Mint", Color(red: 0.6, green: 1.0, blue: 0.8)),
        ("Forest Green", Color(red: 0.13, green: 0.55, blue: 0.13)),
        ("Olive", Color(red: 0.5, green: 0.5, blue: 0.0)),
        ("Emerald", Color(red: 0.31, green: 0.78, blue: 0.47)),
        
        // Reds & Pinks
        ("Crimson", Color(red: 0.86, green: 0.08, blue: 0.24)),
        ("Maroon", Color(red: 0.5, green: 0.0, blue: 0.0)),
        ("Coral", Color(red: 1.0, green: 0.5, blue: 0.31)),
        ("Salmon", Color(red: 0.98, green: 0.5, blue: 0.45)),
        ("Rose", Color(red: 1.0, green: 0.75, blue: 0.8)),
        ("Magenta", .pink.opacity(0.8)),
        
        // Yellows & Oranges
        ("Gold", Color(red: 1.0, green: 0.84, blue: 0.0)),
        ("Amber", Color(red: 1.0, green: 0.75, blue: 0.0)),
        ("Tangerine", Color(red: 1.0, green: 0.39, blue: 0.28)),
        ("Burnt Orange", Color(red: 0.8, green: 0.33, blue: 0.0)),
        
        // Purples & Violets
        ("Lavender", Color(red: 0.9, green: 0.9, blue: 0.98)),
        ("Violet", Color(red: 0.5, green: 0.0, blue: 1.0)),
        ("Plum", Color(red: 0.56, green: 0.27, blue: 0.52)),
        ("Mauve", Color(red: 0.88, green: 0.69, blue: 1.0)),
        
        // Browns & Tans
        ("Tan", Color(red: 0.82, green: 0.71, blue: 0.55)),
        ("Beige", Color(red: 0.96, green: 0.96, blue: 0.86)),
        ("Khaki", Color(red: 0.76, green: 0.69, blue: 0.57)),
        ("Chocolate", Color(red: 0.48, green: 0.25, blue: 0.0)),
        ("Coffee", Color(red: 0.44, green: 0.31, blue: 0.22)),
        
        // Grays
        ("Charcoal", Color(red: 0.21, green: 0.27, blue: 0.31)),
        ("Silver", Color(red: 0.75, green: 0.75, blue: 0.75)),
        ("Slate", Color(red: 0.44, green: 0.5, blue: 0.56)),
        
        // Pastels
        ("Light Blue", Color(red: 0.68, green: 0.85, blue: 0.9)),
        ("Light Green", Color(red: 0.56, green: 0.93, blue: 0.56)),
        ("Light Pink", Color(red: 1.0, green: 0.71, blue: 0.76)),
        ("Lavender Blue", Color(red: 0.9, green: 0.9, blue: 0.98)),
        ("Peach", Color(red: 1.0, green: 0.9, blue: 0.71)),
        ("Cream", Color(red: 1.0, green: 0.99, blue: 0.82))
    ]
    
    private var isFormValid: Bool {
        !itemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 25) {
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
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    // Category picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Category")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(Color.purple.opacity(0.8))
                        
                        Picker("Category", selection: $selectedCategory) {
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
                    
                    // Color picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Color")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(Color.purple.opacity(0.8))
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(colors, id: \.0) { colorTuple in
                                    Button(action: {
                                        selectedColor = colorTuple.1
                                    }) {
                                        Circle()
                                            .fill(colorTuple.1)
                                            .frame(width: 50, height: 50)
                                            .overlay(
                                                Circle()
                                                    .stroke(selectedColor == colorTuple.1 ? Color.purple : Color.clear, lineWidth: 3)
                                            )
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white, lineWidth: selectedColor == colorTuple.1 ? 2 : 0)
                                                    .padding(2)
                                            )
                                    }
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Name field
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Name")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(Color.purple.opacity(0.8))
                        
                        TextField("Enter item name...", text: $itemName)
                            .font(.body)
                            .foregroundColor(.primary)
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
                    
                    // Material picker
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
                    
                    // Add Item button
                    Button(action: {
                        Task {
                            await submitItem()
                        }
                    }) {
                        if isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.purple)
                                .cornerRadius(28)
                        } else {
                            Text("Add Item")
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(isFormValid ? Color.purple : Color.gray)
                                .cornerRadius(28)
                        }
                    }
                    .disabled(!isFormValid || isSubmitting)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .padding(.top, 20)
                .padding(.bottom, 100) // Extra padding for tab bar
            }
            .background(Color(.systemGray6))
            .navigationBarHidden(true)
            .overlay {
                if showSuccess {
                    SuccessPopup(isPresented: $showSuccess) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    @MainActor
    private func submitItem() async {
        isSubmitting = true
        
        do {
            // Create GarmentDTO
            let garment = GarmentDTO(
                id: 0, // Will be auto-assigned
                owner: "local",
                category: selectedCategory,
                color: selectedColor,
                name: itemName.trimmingCharacters(in: .whitespacesAndNewlines),
                material: selectedMaterial,
                imageURL: nil, // No image for text-only items
                dirty: false
            )
            
            // Create garment via API
            _ = try await wardrobeManager.createGarment(garment)
            
            // Refresh wardrobe
            await wardrobeManager.load()
            
            isSubmitting = false
            showSuccess = true
        } catch {
            isSubmitting = false
            print("Error creating garment: \(error)")
        }
    }
}

// Success popup overlay
struct SuccessPopup: View {
    @Binding var isPresented: Bool
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                    onDismiss()
                }
            
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                
                Text("Success!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Item has been added to your wardrobe!")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button(action: {
                    isPresented = false
                    onDismiss()
                }) {
                    Text("OK")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.purple)
                        .cornerRadius(25)
                }
                .padding(.top, 10)
            }
            .padding(30)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 40)
        }
    }
}

// Extension to convert Color to hex string
extension Color {
    func toHex() -> String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)
        
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

#Preview {
    AddItemWithTextView(wardrobeManager: WardrobeManager())
}

