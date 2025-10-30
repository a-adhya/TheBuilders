//
//  HomeView.swift
//  The Builders
//
//  Created by Cassie Liu on 10/28/25.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        VStack(spacing: 0) {
            // Main content area
            VStack(spacing: 40) {
                Spacer().frame(height: 80)
                
                // Greeting text
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Good Morning,")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                            
                            Text("Sugih Jamin")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.purple)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 30)
                }
                
                // Character illustration
                VStack {
                    // Simple character representation
                    VStack(spacing: 0) {
                        // Head
                        Circle()
                            .fill(Color.brown.opacity(0.8))
                            .frame(width: 80, height: 80)
                            .overlay(
                                VStack(spacing: 8) {
                                    // Hair
                                    Ellipse()
                                        .fill(Color.black)
                                        .frame(width: 70, height: 25)
                                        .offset(y: -15)
                                    
                                    // Eyes
                                    HStack(spacing: 15) {
                                        Circle().fill(Color.black).frame(width: 8, height: 8)
                                        Circle().fill(Color.black).frame(width: 8, height: 8)
                                    }
                                    .offset(y: -10)
                                    
                                    // Smile
                                    Arc(startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
                                        .stroke(Color.black, lineWidth: 2)
                                        .frame(width: 20, height: 10)
                                        .offset(y: -5)
                                }
                            )
                        
                        // Body
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 60, height: 120)
                            .cornerRadius(15)
                            .overlay(
                                // Arms crossed
                                VStack {
                                    Rectangle()
                                        .fill(Color.brown.opacity(0.8))
                                        .frame(width: 80, height: 12)
                                        .cornerRadius(6)
                                        .offset(y: 20)
                                }
                            )
                        
                        // Legs
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: 50, height: 100)
                            .cornerRadius(12)
                        
                        // Shoes
                        Rectangle()
                            .fill(Color.brown)
                            .frame(width: 55, height: 20)
                            .cornerRadius(10)
                    }
                }
                .padding(.vertical, 20)
                
                Spacer()
                
                // Weather card
                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color.white)
                        .frame(height: 140)
                        .overlay(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(Color.purple.opacity(0.3), lineWidth: 2)
                        )
                        .overlay(
                            VStack(spacing: 12) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Clear.")
                                            .font(.title3)
                                            .fontWeight(.medium)
                                        
                                        HStack {
                                            // Sun icon
                                            Image(systemName: "sun.max.fill")
                                                .foregroundColor(.orange)
                                                .font(.title2)
                                            
                                            VStack(alignment: .leading) {
                                                Text("51°F")
                                                    .font(.title)
                                                    .fontWeight(.bold)
                                                Text("Feels 46°F")
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                        
                                        Text("53°f 39°f")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 8) {
                                        HStack {
                                            Image(systemName: "wind")
                                                .foregroundColor(.gray)
                                            Text("Wind 7mph")
                                                .font(.caption)
                                        }
                                        
                                        HStack {
                                            Image(systemName: "drop")
                                                .foregroundColor(.blue)
                                            Text("Feels dry")
                                                .font(.caption)
                                        }
                                        
                                        HStack {
                                            Image(systemName: "sunset")
                                                .foregroundColor(.orange)
                                            Text("Sunset 5:22")
                                                .font(.caption)
                                        }
                                        
                                        HStack {
                                            Image(systemName: "moon.fill")
                                                .foregroundColor(.black)
                                            Text("Waning crescent")
                                                .font(.caption)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 15)
                        )
                        .padding(.horizontal, 30)
                }
                
                Spacer().frame(height: 120) // Space for tab bar
            }
        }
        .background(Color(.systemGray6))
        .ignoresSafeArea(.all, edges: .top)
    }
}

// Arc shape for smile
struct Arc: Shape {
    var startAngle: Angle
    var endAngle: Angle
    var clockwise: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: clockwise)
        return path
    }
}

#Preview {
    HomeView()
}
