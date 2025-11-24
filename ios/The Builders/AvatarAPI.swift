//
//  AvatarAPI.swift
//  TheBuilders
//
//  Avatar API service for uploading and fetching user avatars
//

import Foundation
import UIKit

// MARK: - Configuration

/// Set to `true` to use mock API (uses test_avatar.png), `false` to use real API
let USE_MOCK_AVATAR_API = false

// MARK: - API Models

struct AvatarUploadResponse: Codable {
    let avatar_path: String
}

// MARK: - Avatar API Protocol

protocol AvatarAPIProtocol {
    func uploadAvatar(userId: Int, image: UIImage) async throws -> UIImage
}

// MARK: - Mock Avatar API
final class MockAvatarAPI: AvatarAPIProtocol {
    private let latencyMs: UInt64
    
    init(latencyMs: UInt64 = 1000) {
        self.latencyMs = latencyMs
    }
    
    func uploadAvatar(userId: Int, image: UIImage) async throws -> UIImage {
        // Simulate network delay
        try await Task.sleep(nanoseconds: latencyMs * 1_000_000)
        
        // Try to load mock avatar from bundle
        // First try: standard bundle resource (if added to Xcode project)
        if let avatarPath = Bundle.main.path(forResource: "test_avatar", ofType: "png"),
           let avatarImage = UIImage(contentsOfFile: avatarPath) {
            return avatarImage
        }
        
        // Second try: try loading from main bundle with UIImage(named:)
        if let avatarImage = UIImage(named: "test_avatar") {
            return avatarImage
        }
        
        // Third try: check project root directory (for development)
        // This works if the file is in the project root and accessible
        let projectRootPath = "/Users/cassieliu/TheBuilders/test_avatar.png"
        if FileManager.default.fileExists(atPath: projectRootPath),
           let avatarImage = UIImage(contentsOfFile: projectRootPath) {
            return avatarImage
        }
        
        // If all else fails, return the original image as a fallback
        // This ensures the mock always works, even if test_avatar.png isn't found
        return image
    }
}

// MARK: - Real Avatar API Implementation
final class RealAvatarAPI: AvatarAPIProtocol {
    private let baseURL: String
    private let session: URLSession
    
    init(baseURL: String = "http://localhost:8000", session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }
    
    func uploadAvatar(userId: Int, image: UIImage) async throws -> UIImage {
        // Step 1: Upload image to backend
        guard let uploadURL = URL(string: "\(baseURL)/avatar/upload") else {
            throw AvatarAPIError.invalidURL
        }
        
        // Convert UIImage to JPEG data
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw AvatarAPIError.imageConversionFailed
        }
        
        // Create multipart form data request
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add user_id field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"user_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(userId)\r\n".data(using: .utf8)!)
        
        // Add image file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"avatar.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // Upload and get avatar path
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AvatarAPIError.invalidResponse
        }
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw AvatarAPIError.serverError(httpResponse.statusCode)
        }
        
        // Decode response to get avatar path
        let uploadResponse = try JSONDecoder().decode(AvatarUploadResponse.self, from: data)
        let avatarPath = uploadResponse.avatar_path
        
        // Step 2: Fetch the generated avatar image
        // Construct URL from avatar path (assuming it's served at the same base URL)
        // Path format: /avatars/user_123
        let avatarURLString = "\(baseURL)\(avatarPath)"
        guard let avatarURL = URL(string: avatarURLString) else {
            throw AvatarAPIError.invalidURL
        }
        
        let (avatarData, avatarResponse) = try await session.data(from: avatarURL)
        
        guard let avatarHttpResponse = avatarResponse as? HTTPURLResponse else {
            throw AvatarAPIError.invalidResponse
        }
        
        guard (200..<300).contains(avatarHttpResponse.statusCode) else {
            throw AvatarAPIError.serverError(avatarHttpResponse.statusCode)
        }
        
        // Convert data to UIImage
        guard let avatarImage = UIImage(data: avatarData) else {
            throw AvatarAPIError.imageConversionFailed
        }
        
        return avatarImage
    }
}

// MARK: - Avatar API Errors

enum AvatarAPIError: LocalizedError {
    case invalidURL
    case imageConversionFailed
    case invalidResponse
    case serverError(Int)
    case networkError(Error)
    case imageNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL for avatar service"
        case .imageConversionFailed:
            return "Failed to convert image"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let code):
            return "Server error with code: \(code)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .imageNotFound:
            return "Avatar image not found"
        }
    }
}
