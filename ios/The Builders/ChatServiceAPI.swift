//
//  ChatService.swift
//  TheBuilders
//
//  Created on 11/5/2025.
//

import Foundation

// MARK: - API Models

struct ConversationMessage: Codable {
    let role: String
    let content: ContentValue
    
    enum ContentValue: Codable {
        case string(String)
        case array([ContentBlock])
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .string(let str):
                try container.encode(str)
            case .array(let arr):
                try container.encode(arr)
            }
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let str = try? container.decode(String.self) {
                self = .string(str)
            } else if let arr = try? container.decode([ContentBlock].self) {
                self = .array(arr)
            } else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Content must be string or array")
            }
        }
        
        // Helper method to extract text content
        func getText() -> String {
            switch self {
            case .string(let str):
                return str
            case .array(let blocks):
                return blocks.compactMap { $0.text }.joined(separator: " ")
            }
        }
        
        // Helper method to check if content contains a string
        func contains(_ searchString: String) -> Bool {
            return getText().contains(searchString)
        }
        
        // Helper method to append text to content
        func appending(_ text: String) -> ContentValue {
            switch self {
            case .string(let str):
                return .string(str + text)
            case .array(let blocks):
                var newBlocks = blocks
                // Find the last text block or create one
                if let lastIndex = newBlocks.lastIndex(where: { $0.type == "text" && $0.text != nil }) {
                    let lastTextBlock = newBlocks[lastIndex]
                    if let existingText = lastTextBlock.text {
                        newBlocks[lastIndex] = ContentBlock(type: "text", source: nil, text: existingText + text)
                    }
                } else {
                    // No text block found, add a new one
                    newBlocks.append(ContentBlock(type: "text", source: nil, text: text))
                }
                return .array(newBlocks)
            }
        }
        
        // Helper method to get lowercase text
        var lowercased: String {
            return getText().lowercased()
        }
    }
    
    struct ContentBlock: Codable {
        let type: String
        let source: ImageSource?
        let text: String?
        
        enum CodingKeys: String, CodingKey {
            case type
            case source
            case text
        }
    }
    
    struct ImageSource: Codable {
        let type: String
        let url: String?
        let media_type: String?
        let data: String?
        
        enum CodingKeys: String, CodingKey {
            case type
            case url
            case media_type
            case data
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(type, forKey: .type)
            
            // For URL type, only encode url (no media_type or data)
            if type == "url", let url = url {
                try container.encode(url, forKey: .url)
            }
            // For base64 type, encode media_type and data (no url)
            else if type == "base64" {
                if let media_type = media_type {
                    try container.encode(media_type, forKey: .media_type)
                }
                if let data = data {
                    try container.encode(data, forKey: .data)
                }
            }
        }
    }
    
    init(role: String, content: ContentValue) {
        self.role = role
        self.content = content
    }
    
    // Convenience initializer for text-only messages
    init(role: String, text: String) {
        self.role = role
        self.content = .string(text)
    }
}

struct ChatRequest: Codable {
    let messages: [ConversationMessage]
    
    init(messages: [ConversationMessage]) {
        self.messages = messages
    }
}



struct ChatResponse: Codable {
    let response: String
}

// MARK: - Chat Service Protocol

protocol ChatServiceProtocol {
    func sendMessage(messages: [ConversationMessage], weatherData: WeatherData?) async throws -> String
}

// MARK: - Chat Service Implementation

final class ChatService: ChatServiceProtocol {
    private let baseURL: String
    private let session: URLSession
    
    init(baseURL: String = "http://localhost:8000", session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }
    
    func sendMessage(messages: [ConversationMessage], weatherData: WeatherData?) async throws -> String {
        guard let url = URL(string: "\(baseURL)/chat") else {
            throw ChatError.invalidURL
        }
        
        // Start with the original conversation messages
        var processedMessages = messages
        
        // Check if weather information already exists in conversation history
        let hasWeatherInfo = messages.contains { message in
            message.content.contains("this is my current weather context") ||
            message.content.contains("Current weather conditions") ||
            message.content.contains("Please give me recommendations based on this weather context")
        }
        
        // Only append weather data if:
        // 1. We have weather data
        // 2. The last message is from user
        // 3. Weather info hasn't been appended before in this conversation
        if let lastMessage = messages.last, 
           lastMessage.role == "user",
           let weatherData = weatherData,
           !hasWeatherInfo {
            let weatherContext = createWeatherContext(from: weatherData)
            // Append weather context to the last user message
            let enhancedContent = lastMessage.content.appending("\n\n" + weatherContext)
            processedMessages[processedMessages.count - 1] = ConversationMessage(
                role: "user",
                content: enhancedContent
            )
        }
        
        // Ensure all messages have valid roles (only "user" or "assistant")
        // Backend only accepts "user" or "assistant" roles
        let validMessages = processedMessages.filter { $0.role == "user" || $0.role == "assistant" }
        
        // Ensure we still have at least one message after filtering
        guard !validMessages.isEmpty else {
            throw ChatError.invalidRequest("At least one message with valid role (user or assistant) is required")
        }
        
        let request = ChatRequest(messages: validMessages)
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            throw ChatError.encodingFailed(error)
        }
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatError.invalidResponse
        }
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ChatError.serverError(httpResponse.statusCode)
        }
        
        do {
            let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
            return chatResponse.response
        } catch {
            throw ChatError.decodingFailed(error)
        }
    }
    
    private func createWeatherContext(from weatherData: WeatherData) -> String {
        return """
        Hi, this is my current weather context:
        - Condition: \(weatherData.condition)
        - Temperature: \(weatherData.temperatureF)°F (feels like \(weatherData.feelsLikeF)°F)
        - High/Low: \(weatherData.highF)°F / \(weatherData.lowF)°F
        - Wind: \(weatherData.windMph) mph
        - Humidity: \(weatherData.humidityPct)%
        - Sunset: \(weatherData.sunset)
        - Moon phase: \(weatherData.moonPhase)
        
        Please give me recommendations based on this weather context.
        """
    }
}

// MARK: - Mock Chat Service (for testing only)

#if DEBUG
final class MockChatService: ChatServiceProtocol {
    private let delay: TimeInterval
    
    init(delay: TimeInterval = 1.0) {
        self.delay = delay
    }
    
    func sendMessage(messages: [ConversationMessage], weatherData: WeatherData?) async throws -> String {
        // Simulate network delay
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        // Generate a mock response based on the last user message
        guard let lastMessage = messages.last else {
            return "I'm here to help with your fashion questions! 👗"
        }
        
        let userContent = lastMessage.content.lowercased
        
        if userContent.contains("outfit") || userContent.contains("clothes") {
            return generateOutfitResponse(userMessage: userContent, weatherData: weatherData)
        } else if userContent.contains("color") {
            return "Great question about colors! Color coordination can really make an outfit pop. What specific colors are you working with? 🎨"
        } else if userContent.contains("style") {
            return "Style is all about expressing yourself! What kind of look are you going for - casual, formal, or something in between? ✨"
        } else if userContent.contains("hello") || userContent.contains("hi") {
            return "Hi there! I'm excited to help you with your fashion journey. What can I assist you with today? 👋"
        } else {
            return "That's interesting! I'm here to help with all your fashion and style questions. Feel free to ask me about outfits, colors, or styling tips! 💫"
        }
    }
    
    private func generateOutfitResponse(userMessage: String, weatherData: WeatherData?) -> String {
        var response = "I'd love to help you with outfit suggestions! "
        
        if let weather = weatherData {
            // Include weather-appropriate suggestions
            let temp = weather.temperatureF
            let condition = weather.condition.lowercased()
            
            if temp < 40 {
                response += "Since it's quite cold (\(temp)°F) and \(weather.condition.lowercased()), I'd recommend layers! Think cozy sweaters, warm coats, and maybe some stylish boots. "
            } else if temp < 60 {
                response += "With the temperature at \(temp)°F and \(condition) conditions, a light jacket or cardigan would be perfect! You could also try layering with a cute scarf. "
            } else if temp < 75 {
                response += "The weather looks nice at \(temp)°F and \(condition)! This is perfect for a cute blouse with jeans or a light dress. "
            } else {
                response += "It's warm at \(temp)°F and \(condition) - great weather for lighter fabrics! Consider breathable materials like cotton or linen. "
            }
            
            if weather.windMph > 15 {
                response += "It's a bit windy today (\(weather.windMph) mph), so you might want to avoid flowy pieces that could get messy. "
            }
            
            if weather.humidityPct > 70 {
                response += "With \(weather.humidityPct)% humidity, breathable fabrics will keep you more comfortable. "
            }
        }
        
        response += "What specific occasion or style are you thinking about? 🌟"
        
        return response
    }
}
#endif

// MARK: - Chat Errors

enum ChatError: LocalizedError {
    case invalidURL
    case encodingFailed(Error)
    case decodingFailed(Error)
    case invalidResponse
    case serverError(Int)
    case networkError(Error)
    case invalidRequest(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL for chat service"
        case .encodingFailed(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let code):
            return "Server error with code: \(code)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidRequest(let message):
            return message
        }
    }
}
