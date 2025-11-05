import SwiftUI

import SwiftUI

struct ChatMessage: Identifiable, Equatable {
    enum Role { case user, assistant }
    let id = UUID()
    let role: Role
    let text: String
    let timestamp: Date = Date()
    
    // Convert to API format
    func toConversationMessage() -> ConversationMessage {
        return ConversationMessage(
            role: role == .user ? "user" : "assistant",
            content: text
        )
    }
}

struct FeedbackView: View {
    @State private var messages: [ChatMessage] = [
        ChatMessage(role: .assistant, text: "Hi! I’m your personal outfit companion 🌸\nI can give you some general fashion recommendations, or you can send me your outfit and I’ll tell you what I think!")
    ]
    @State private var inputText: String = ""
    @State private var isSending: Bool = false
    @State private var errorMessage: String?
    @State private var showError: Bool = false
    
    // Chat service - uses configuration to determine mock vs real
    private let chatService: ChatServiceProtocol
    
    // Weather service to provide context for outfit questions
    @StateObject private var weatherViewModel = WeatherViewModel()
    
    init() {
        // Always use real chat service for production
        self.chatService = ChatService(baseURL: "http://localhost:8000")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { message in
                            messageBubble(for: message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(Color(UIColor.systemGray6))
                .onChange(of: messages.count) { oldValue, newValue in
                    // Auto-scroll to bottom on new message
                    if let lastID = messages.last?.id {
                        withAnimation { proxy.scrollTo(lastID, anchor: .bottom) }
                    }
                }
            }

            // Input bar
            inputBar
                .background(.thinMaterial)
        }
        .navigationTitle("Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $showError) {
            Button("OK") { showError = false }
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
        .task {
            // Pre-load weather data when view appears
            if weatherViewModel.weather == nil {
                await weatherViewModel.load()
            }
        }
    }

    // MARK: - Views

    @ViewBuilder
    private func messageBubble(for message: ChatMessage) -> some View {
        HStack(alignment: .bottom) {
            if message.role == .assistant {
                // Assistant bubble left aligned
                VStack(alignment: .leading) {
                    Text(message.text)
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color.purple.opacity(0.1))
                        )
                }
                Spacer(minLength: 40)
            } else {
                Spacer(minLength: 40)
                // User bubble right aligned
                VStack(alignment: .trailing) {
                    Text(message.text)
                        .font(.body)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color.purple)
                        )
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Type your message...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                )
                .lineLimit(1...4)

            Button(action: sendMessage) {
                Image(systemName: isSending ? "hourglass" : "paperplane.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Circle().fill(Color.purple))
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        inputText = ""
        isSending = true
        
        // Clear any previous error
        errorMessage = nil
        showError = false
        
        // Append user message
        messages.append(ChatMessage(role: .user, text: text))
        
        // Call the chat API
        Task {
            do {
                // Convert messages to API format
                let conversationMessages = messages.map { $0.toConversationMessage() }
                
                // Check if this is an outfit-related question
                let isOutfitRelated = isOutfitRelatedQuestion(text)
                var weatherData: WeatherData? = nil
                
                // If it's outfit-related, try to get weather data
                if isOutfitRelated {
                    // Load weather if not already loaded
                    if weatherViewModel.weather == nil && !weatherViewModel.isLoading {
                        await weatherViewModel.load()
                    }
                    weatherData = weatherViewModel.weather
                }
                
                // Send to backend with weather context if needed
                let systemPrompt: String?
                if isOutfitRelated, let weather = weatherData {
                    systemPrompt = """
                    You are a fashion assistant. Consider the current weather conditions when making outfit recommendations:
                    - Temperature: \(weather.temperatureF)°F (feels like \(weather.feelsLikeF)°F)
                    - Conditions: \(weather.condition)
                    - Wind: \(weather.windMph) mph
                    - Humidity: \(weather.humidityPct)%
                    - High/Low: \(weather.highF)°F / \(weather.lowF)°F
                    
                    Always incorporate these weather factors into your clothing suggestions.
                    """
                } else if isOutfitRelated {
                    systemPrompt = "You are a fashion assistant. Provide helpful outfit and style advice."
                } else {
                    systemPrompt = nil
                }
                
                let response = try await chatService.sendMessage(
                    messages: conversationMessages,
                    weatherData: nil, // Don't send weatherContext to maintain backend compatibility
                    systemPrompt: systemPrompt
                )
                
                // Update UI on main thread
                await MainActor.run {
                    messages.append(ChatMessage(role: .assistant, text: response))
                    isSending = false
                }
            } catch {
                // Handle error on main thread
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isSending = false
                }
            }
        }
    }
    
    private func isOutfitRelatedQuestion(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        let outfitKeywords = ["outfit", "clothes", "clothing", "wear", "dress", "shirt", "pants", "jacket", "coat", "style", "fashion", "what to wear", "what should i wear"]
        
        return outfitKeywords.contains { lowercased.contains($0) }
    }
}

#Preview {
    NavigationView {
        FeedbackView()
    }
}
