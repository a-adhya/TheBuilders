import SwiftUI

struct AddClothingItemView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: String = ClothingItem.Category.tops.rawValue
    @State private var itemDescription: String = ""

    // Reuse categories defined in model
    private let categories: [String] = ClothingItem.Category.allCases.map { $0.rawValue }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 30) {
                        imagePickerSection
                        categorySection
                        descriptionSection
                        Spacer(minLength: 120)
                    }
                }
                bottomButtonsSection
            }
            .background(Color(.systemGray6))
            .navigationBarHidden(true)
        }
    }

    // MARK: - Sections

    private var imagePickerSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30)
                .fill(Color.white)
                .frame(height: 220)
                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
            HStack {
                Spacer(minLength: 24)
                VStack {
                    Image(systemName: "square.and.arrow.up")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .foregroundColor(.black)
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Color.purple.opacity(0.6))
                    .frame(width: 1, height: 140)

                VStack {
                    Image(systemName: "camera")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .foregroundColor(.black)
                }
                .frame(maxWidth: .infinity)
                Spacer(minLength: 24)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
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

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Description")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(Color.purple.opacity(0.8))

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
                .lineLimit(2...6)
        }
        .padding(.horizontal, 20)
    }

    private var bottomButtonsSection: some View {
        HStack(spacing: 0) {
            Button(action: { dismiss() }) {
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

            Button(action: { /* Placeholder - disabled for now */ }) {
                VStack(spacing: 8) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 24))
                    Text("Update")
                        .font(.system(size: 16, weight: .medium))
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(true)
            .foregroundColor(.purple.opacity(0.4))
            .buttonStyle(PlainButtonStyle())

            Button(action: { /* Placeholder - disabled for now */ }) {
                VStack(spacing: 8) {
                    Image(systemName: "trash")
                        .font(.system(size: 24))
                    Text("Trash")
                        .font(.system(size: 16, weight: .medium))
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(true)
            .foregroundColor(.red.opacity(0.4))
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
}

#Preview {
    AddClothingItemView()
}
