//
//  AvatarAPI.swift
//  TheBuilders
//
//  Avatar API service for uploading and fetching user avatars
//

import Foundation
import UIKit

// MARK: - Configuration

let USE_MOCK_AVATAR_UPLOAD = false
let USE_REAL_API_WITH_MOCK_PHOTO = false // easy for simulator testing
let USE_MOCK_TRY_ON = false

// MARK: - API Models

struct AvatarUploadResponse: Codable {
    let avatar_url: String  // Backend returns "avatar_url"
}

// MARK: - Avatar API Protocol

protocol AvatarAPIProtocol {
    func uploadAvatar(userId: Int, image: UIImage) async throws -> UIImage
    func tryOn(userId: Int, garmentIds: [Int]) async throws -> UIImage
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
        
        // Load test_avatar.png from project root
        let projectRootPath = "/Users/cassieliu/TheBuilders/test_avatar.png"
        guard let avatarImage = UIImage(contentsOfFile: projectRootPath) else {
            throw AvatarAPIError.imageNotFound
        }
        return avatarImage
    }
    
    func tryOn(userId: Int, garmentIds: [Int]) async throws -> UIImage {
        try await Task.sleep(nanoseconds: latencyMs * 2_000_000)
        
        let projectRootPath = "/Users/cassieliu/TheBuilders/test_avatar.png" //only for local testing 
        guard let tryOnImage = UIImage(contentsOfFile: projectRootPath) else {
            throw AvatarAPIError.imageNotFound
        }
        return tryOnImage
    }
}

// MARK: - Real Avatar API Implementation
final class RealAvatarAPI: AvatarAPIProtocol {
    private let baseURL: String
    private let session: URLSession
    
    /// Initializes the RealAvatarAPI with a base URL and optional URLSession.
    /// - Parameters:
    ///   - baseURL: The base URL of the backend API (default: "http://localhost:8000")
    ///   - session: Optional URLSession to use for network requests.
    init(baseURL: String = "http://localhost:8000", session: URLSession? = nil) {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 600.0
        config.timeoutIntervalForResource = 720.0
        self.session = session ?? URLSession(configuration: config)
    }
    
    /// Uploads an avatar image to the backend and retrieves the processed avatar.
    func uploadAvatar(userId: Int, image: UIImage) async throws -> UIImage {
        // Step 1: Prepare the image to upload
        let imageToUpload: UIImage
        if USE_REAL_API_WITH_MOCK_PHOTO {
            // Load test_avatar_generation.png from project root， only for local testing 
            let projectRootPath = "/Users/cassieliu/TheBuilders/test_avatar_generation.png"
            guard let mockImage = UIImage(contentsOfFile: projectRootPath) else {
                throw AvatarAPIError.imageNotFound
            }
            imageToUpload = mockImage
        } else {
            imageToUpload = image // use the real image from the user
        }
        
        // Step 2: Convert UIImage to JPEG data for upload
        guard let imageData = imageToUpload.jpegData(compressionQuality: 0.8) else {
            throw AvatarAPIError.imageConversionFailed
        }
        
        // Step 3: Construct the upload request
        // Backend endpoint: POST /users/{user_id}/avatar
        guard let uploadURL = URL(string: "\(baseURL)/users/\(userId)/avatar") else {
            throw AvatarAPIError.invalidURL
        }
        
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        
        // Create multipart/form-data request body
        // FastAPI backend expects: image: UploadFile = File(...)
        // The field name must be "image" to match the backend parameter name
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Build multipart form data body manually
        // Format:
        // --boundary\r\n
        // Content-Disposition: form-data; name="field_name"; filename="filename"\r\n
        // Content-Type: image/jpeg\r\n
        // \r\n
        // [binary data]
        // \r\n
        // --boundary--\r\n
        var body = Data()
        
        let boundaryPrefix = "--\(boundary)\r\n"
        let contentDisposition = "Content-Disposition: form-data; name=\"image\"; filename=\"avatar.jpg\"\r\n"
        let contentType = "Content-Type: image/jpeg\r\n"
        let headerEnd = "\r\n"
        let partEnd = "\r\n"
        let finalBoundary = "--\(boundary)--\r\n"
        
        body.append(boundaryPrefix.data(using: .utf8)!)
        body.append(contentDisposition.data(using: .utf8)!)
        body.append(contentType.data(using: .utf8)!)
        body.append(headerEnd.data(using: .utf8)!)
        body.append(imageData)
        body.append(partEnd.data(using: .utf8)!)
        body.append(finalBoundary.data(using: .utf8)!)
        
        request.httpBody = body
        
        print("Request URL: \(uploadURL)")
        print("Request body size: \(body.count) bytes")
        print("Boundary: \(boundary)")
        
        // Send the request and get the response
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            // Handle network errors (timeout, connection failures, etc.)
            if let urlError = error as? URLError {
                switch urlError.code {
                case .timedOut:
                    throw AvatarAPIError.networkError(error)
                case .cannotConnectToHost, .networkConnectionLost:
                    throw AvatarAPIError.networkError(error)
                default:
                    throw AvatarAPIError.networkError(error)
                }
            }
            throw AvatarAPIError.networkError(error)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AvatarAPIError.invalidResponse
        }
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw AvatarAPIError.serverError(httpResponse.statusCode)
        }
        
        // Decode response to get avatar URL
        // Backend returns: { "avatar_url": "/avatars/user_1" }
        let uploadResponse = try JSONDecoder().decode(AvatarUploadResponse.self, from: data)
        let avatarPath = uploadResponse.avatar_url
        
        // Fetch the generated avatar image from MinIO
        let minioBaseURL = baseURL.replacingOccurrences(of: ":8000", with: ":9000")
        let avatarURLString = "\(minioBaseURL)\(avatarPath)"
        
        guard let avatarURL = URL(string: avatarURLString) else {
            throw AvatarAPIError.invalidURL
        }
        
        let (avatarData, avatarResponse) = try await session.data(from: avatarURL)
        
        guard let httpResponse = avatarResponse as? HTTPURLResponse else {
            throw AvatarAPIError.invalidResponse
        }
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw AvatarAPIError.serverError(httpResponse.statusCode)
        }
        
        // Convert data to UIImage
        guard let avatarImage = UIImage(data: avatarData) else {
            print("Failed to convert avatar data to UIImage")
            throw AvatarAPIError.imageConversionFailed
        }
        
        return avatarImage
    }
    
    /// Generates a try-on preview image of the user's avatar wearing the specified garments.
    func tryOn(userId: Int, garmentIds: [Int]) async throws -> UIImage {
        // Step 1: Construct the request URL
        // Backend endpoint: POST /users/{user_id}/tryon
        guard let url = URL(string: "\(baseURL)/users/\(userId)/tryon") else {
            throw AvatarAPIError.invalidURL
        }
        
        // Step 2: Create request body
        // Backend expects: { "garments": [1, 2, 3] }
        struct TryOnRequest: Codable {
            let garments: [Int]
        }
        
        let requestBody = TryOnRequest(garments: garmentIds)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("image/png", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        print("Try-on request URL: \(url)")
        print("Try-on garment IDs: \(garmentIds)")
        
        // Step 3: Send the request
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            if let urlError = error as? URLError {
                switch urlError.code {
                case .timedOut:
                    throw AvatarAPIError.networkError(error)
                case .cannotConnectToHost, .networkConnectionLost:
                    throw AvatarAPIError.networkError(error)
                default:
                    throw AvatarAPIError.networkError(error)
                }
            }
            throw AvatarAPIError.networkError(error)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AvatarAPIError.invalidResponse
        }
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw AvatarAPIError.serverError(httpResponse.statusCode)
        }
        
        // Step 4: Convert PNG bytes to UIImage
        // Backend returns raw PNG bytes with Content-Type: image/png
        guard let tryOnImage = UIImage(data: data) else {
            print("Failed to convert try-on data to UIImage")
            throw AvatarAPIError.imageConversionFailed
        }
        
        print(" Try-on image received successfully (size: \(data.count) bytes)")
        return tryOnImage
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
