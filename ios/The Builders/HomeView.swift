//
//  HomeView.swift
//  TheBuilders
//
//  Created by Cassie Liu on 10/28/25.
//

import SwiftUI
import Combine

struct HomeView: View {
    @StateObject private var viewModel = WeatherViewModel()
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
                            Group {
                                if let w = viewModel.weather {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("\(w.condition).")
                                                .font(.title3)
                                                .fontWeight(.medium)
                                            
                                            HStack {
                                                Image(systemName: w.temperatureF >= 70 ? "sun.max.fill" : "cloud.sun.fill")
                                                    .foregroundColor(.orange)
                                                    .font(.title2)
                                                
                                                VStack(alignment: .leading) {
                                                    Text("\(w.temperatureF)°F")
                                                        .font(.title)
                                                        .fontWeight(.bold)
                                                    Text("Feels \(w.feelsLikeF)°F")
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                }
                                            }
                                            
                                            Text("\(w.highF)°f \(w.lowF)°f")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                        
                                        Spacer()
                                        
                                        VStack(alignment: .trailing, spacing: 8) {
                                            HStack {
                                                Image(systemName: "wind")
                                                    .foregroundColor(.gray)
                                                Text("Wind \(w.windMph)mph")
                                                    .font(.caption)
                                            }
                                            
                                            HStack {
                                                Image(systemName: "drop")
                                                    .foregroundColor(.blue)
                                                Text("Humidity \(w.humidityPct)%")
                                                    .font(.caption)
                                            }
                                            
                                            HStack {
                                                Image(systemName: "sunset")
                                                    .foregroundColor(.orange)
                                                Text("Sunset \(w.sunset)")
                                                    .font(.caption)
                                            }
                                            
                                            HStack {
                                                Image(systemName: "moon.fill")
                                                    .foregroundColor(.black)
                                                Text(w.moonPhase)
                                                    .font(.caption)
                                            }
                                        }
                                    }
                                } else if viewModel.isLoading {
                                    HStack {
                                        ProgressView()
                                        Text("Fetching weather...")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        Spacer()
                                    }
                                } else if let err = viewModel.errorMessage {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle")
                                            .foregroundColor(.orange)
                                        Text(err)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        Spacer()
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
    .task { await viewModel.load() }
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
