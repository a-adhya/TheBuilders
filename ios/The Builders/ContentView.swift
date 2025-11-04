//
//  ContentView.swift
//  TheBuilders
//
//  Created by Cassie Liu on 10/28/25.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home tab
            HomeView()
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                    Text("Home")
                }
                .tag(0)
            
            // Outfit Generator tab
            OutfitGeneratorView()
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "tshirt.fill" : "tshirt")
                    Text("Outfit\nGenerator")
                }
                .tag(1)
            
            // Feedback tab
            FeedbackView()
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "bubble.left.and.bubble.right.fill" : "bubble.left.and.bubble.right")
                    Text("Feedback")
                }
                .tag(2)
            
            // Wardrobe tab
            WardrobeView()
                .tabItem {
                    Image(systemName: "hanger")
                    Text("Wardrobe")
                }
                .tag(3)
        }
        .accentColor(.purple)
        .onAppear {
            // Customize tab bar appearance
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.white
            
            // Configure selected state
            appearance.stackedLayoutAppearance.selected.iconColor = UIColor.systemPurple
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
                .foregroundColor: UIColor.systemPurple,
                .font: UIFont.systemFont(ofSize: 11, weight: .medium)
            ]
            
            // Configure normal state
            appearance.stackedLayoutAppearance.normal.iconColor = UIColor.systemGray
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
                .foregroundColor: UIColor.systemGray,
                .font: UIFont.systemFont(ofSize: 11, weight: .medium)
            ]
            
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

#Preview {
    ContentView()
}
