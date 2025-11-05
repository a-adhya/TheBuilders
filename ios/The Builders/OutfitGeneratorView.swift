//
//  OutfitGeneratorView.swift
//  TheBuilders
//
//  Created by Angshu Adhya on 11/4/2025.
//

import SwiftUI

struct OutfitGeneratorView: View {
    @State private var occasion = ""
    @State private var preferredItems = ""
    @State private var mood = ""
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case occasion, preferredItems, mood
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    // Welcome text and character with chat bubble
                    VStack(spacing: 20) {
                        // Chat bubble with bot message
                        HStack(alignment: .top) {
                            // Modern chatbot icon
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(LinearGradient(
                                        colors: [Color.purple, Color.blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                    .frame(width: 60, height: 60)
                                
                                // Robot face
                                VStack(spacing: 4) {
                                    // Antenna
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 6, height: 6)
                                        .offset(y: -8)
                                    
                                    // Eyes
                                    HStack(spacing: 8) {
                                        Circle().fill(Color.white).frame(width: 10, height: 10)
                                        Circle().fill(Color.white).frame(width: 10, height: 10)
                                    }
                                    
                                    // Smiling mouth
                                    CustomArc(startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
                                        .stroke(Color.white, lineWidth: 2)
                                        .frame(width: 14, height: 7)
                                }
                            }
                            .padding(.trailing, 12)
                            
                            // Chat bubble
                            VStack(alignment: .leading) {
                                Text("Welcome to your personal outfit generator! Before I generate your outfits, I would like to get a better sense of what you're going for. Please fill out the following questions. When you're ready, hit the Generate Outfit button below!")
                                    .font(.body)
                                    .foregroundColor(.black)
                                    .multilineTextAlignment(.leading)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 20)
                                                .fill(Color.white)
                                            
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                        }
                                    )
                                
//                                // Chat bubble tail
//                                HStack {
//                                    Triangle()
//                                        .fill(Color.white)
//                                        .frame(width: 12, height: 8)
//                                        .rotationEffect(.degrees(180))
//                                        .offset(x: 8, y: -4)
//                                    
//                                    Spacer()
//                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                    
                    // Input sections
                    VStack(spacing: 25) {
                        // Occasion input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Is there a special occasion you're dressing up for, or looking for something more casual?")
                                .font(.body)
                                .multilineTextAlignment(.leading)
                            
                            TextField("Casual fall day", text: $occasion)
                                .textFieldStyle(CustomTextFieldStyle())
                                .focused($focusedField, equals: .occasion)
                                .submitLabel(.next)
                                .onSubmit {
                                    focusedField = .preferredItems
                                }
                        }
                        
                        // Preferred items input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("(Optional) Any items you'd prefer with your outfit?")
                                .font(.body)
                                .multilineTextAlignment(.leading)
                            
                            TextField("Boots", text: $preferredItems)
                                .textFieldStyle(CustomTextFieldStyle())
                                .focused($focusedField, equals: .preferredItems)
                                .submitLabel(.next)
                                .onSubmit {
                                    focusedField = .mood
                                }
                        }
                        
                        // Mood input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("(Optional) What mood are you going for with your outfit?")
                                .font(.body)
                                .multilineTextAlignment(.leading)
                            
                            TextField("Something that makes me look spiffy", text: $mood)
                                .textFieldStyle(CustomTextFieldStyle())
                                .focused($focusedField, equals: .mood)
                                .submitLabel(.done)
                                .onSubmit {
                                    focusedField = nil
                                }
                        }
                    }
                    
                    // Generate Outfit Button
                    Button(action: {
                        // Dismiss keyboard before generating outfit
                        focusedField = nil
                        // TODO: Implement outfit generation logic
                        print("Generate outfit tapped")
                    }) {
                        Text("Generate Outfit")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.purple)
                            .cornerRadius(28)
                    }
                   
                    
                    // Bottom spacing for tab bar
                    Color.clear.frame(height: 120)
                }
                .padding(.horizontal, 12)
                
            }
            .background(Color(.systemGray6))
            .navigationBarHidden(true)
            .onTapGesture {
                // Dismiss keyboard when tapping the background
                focusedField = nil
            }
        }
    }
}

// Custom text field style to match the design
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .font(.body)
            .foregroundColor(.primary)
    }
}



// Custom shapes for chat bubble
struct CustomArc: Shape {
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

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        return path
    }
}

#Preview {
    OutfitGeneratorView()
}

