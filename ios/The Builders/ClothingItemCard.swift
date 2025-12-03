//
//  ClothingItemCard.swift
//  TheBuilders
//
//  Created by Cassie Liu on 10/28/25.
//

import SwiftUI

// Individual clothing item card component
struct ClothingItemCard: View {
    let item: ClothingItem
    let showLaundry: Bool
    let wardrobeManager: WardrobeManager
    @State private var showingDetail = false
    
    var body: some View {
        VStack {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .frame(height: 150)
                
                // Clothing representation
                clothingIcon
                
                // Laundry basket icon if item is in laundry and toggle is on
                if item.isInLaundry && showLaundry {
                    laundryIndicator
                }
                
                // Hide item if it's in laundry and toggle is off
                if item.isInLaundry && !showLaundry {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.gray.opacity(0.5))
                        .frame(height: 150)
                }
            }
        }
        .opacity(item.isInLaundry && !showLaundry ? 0.3 : 1.0)
        .onTapGesture {
            showingDetail = true
        }
        .sheet(isPresented: $showingDetail) {
            ClothingItemDetailView(item: item, wardrobeManager: wardrobeManager)
        }
    }
    
    // MARK: - Private Views
    
    @ViewBuilder
    private var clothingIcon: some View {
        // Check if we have a valid imageURL
        if let imageURL = item.imageURL, !imageURL.absoluteString.isEmpty {
            remoteImageView(for: imageURL)
        } else {
            // For items without images, always show colored rectangle with name
            // This matches the design shown (green/blue rectangle with "Shirt1"/"Shirt")
            coloredRectangleView
        }
    }
    
    @ViewBuilder
    private var coloredRectangleView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(item.color.opacity(0.3))
            .overlay(
                Text(item.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(item.color)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(8)
    }
    
    @ViewBuilder
    private func remoteImageView(for url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                    .frame(width: 120, height: 120)
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 150, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            case .failure:
                // If image fails to load, fall back to colored rectangle with name
                coloredRectangleView
            @unknown default:
                coloredRectangleView
            }
        }
    }
    
    private var laundryIndicator: some View {
        VStack {
            HStack {
                Spacer()
                Image(systemName: "basket.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.gray)
                    .padding(8)
            }
            Spacer()
        }
    }
}