//
//  CategoryTabView.swift
//  TheBuilders
//
//  Created by Cassie Liu on 10/28/25.
//

import SwiftUI

struct CategoryTabView: View {
    let categories: [String]
    @Binding var selectedCategory: String
    @Binding var selectedIndex: Int
    @State private var isHovering = false
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(categories.enumerated()), id: \.element) { index, category in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedCategory = category
                                selectedIndex = index
                            }
                        }) {
                            VStack(spacing: 8) {
                                Text(category)
                                    .font(.title2)
                                    .fontWeight(selectedCategory == category ? .bold : .medium)
                                    .foregroundColor(selectedCategory == category ? .purple : .gray)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                
                                // 下划线指示器
                                Rectangle()
                                    .fill(selectedCategory == category ? Color.purple : Color.clear)
                                    .frame(height: 3)
                                    .padding(.horizontal, 20)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .id(index)
                    }
                }
                .padding(.horizontal, 0)
                .contentShape(Rectangle())
                .onHover { hovering in
                    isHovering = hovering
                }
                .gesture(swipeGesture(proxy: proxy))
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ScrollWheel"))) { notification in
                    handleScrollWheel(notification: notification, proxy: proxy)
                }
            }
        }
        .background(
            Rectangle()
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .padding(.top, 10)
    }
    
    // MARK: - Private Methods
    
    private func swipeGesture(proxy: ScrollViewProxy) -> some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .local)
            .onChanged { _ in
                // Provide immediate feedback during drag
            }
            .onEnded { value in
                let threshold: CGFloat = 20
                
                if value.translation.width > threshold {
                    // Swipe right - go to previous category
                    let newIndex = max(0, selectedIndex - 1)
                    updateSelection(to: newIndex, proxy: proxy)
                } else if value.translation.width < -threshold {
                    // Swipe left - go to next category
                    let newIndex = min(categories.count - 1, selectedIndex + 1)
                    updateSelection(to: newIndex, proxy: proxy)
                }
            }
    }
    
    private func handleScrollWheel(notification: Notification, proxy: ScrollViewProxy) {
        if isHovering, let scrollDelta = notification.userInfo?["delta"] as? CGFloat {
            if scrollDelta > 0 {
                // Scroll right - go to previous category
                let newIndex = max(0, selectedIndex - 1)
                updateSelection(to: newIndex, proxy: proxy)
            } else if scrollDelta < 0 {
                // Scroll left - go to next category
                let newIndex = min(categories.count - 1, selectedIndex + 1)
                updateSelection(to: newIndex, proxy: proxy)
            }
        }
    }
    
    private func updateSelection(to newIndex: Int, proxy: ScrollViewProxy) {
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedIndex = newIndex
            selectedCategory = categories[newIndex]
            proxy.scrollTo(newIndex, anchor: .center)
        }
    }
}
