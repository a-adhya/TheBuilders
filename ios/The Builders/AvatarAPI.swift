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
/// Set to `true` to use real API but always send test_avatar_generation.png to backend
let USE_REAL_API_WITH_MOCK_PHOTO = true

// MARK: - API Models

struct AvatarUploadResponse: Codable {
    let avatar_url: String  // Backend returns "avatar_url"
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
    
    /// Initializes the RealAvatarAPI with a base URL and optional URLSession.
    ///
    /// - Parameters:
    ///   - baseURL: The base URL of the backend API (default: "http://localhost:8000")
    ///   - session: Optional URLSession to use for network requests. If nil, creates a new session
    ///              with extended timeouts suitable for avatar generation (10 minutes request timeout,
    ///              12 minutes resource timeout) since avatar processing can take significant time.
    init(baseURL: String = "http://localhost:8000", session: URLSession? = nil) {
        self.baseURL = baseURL
        // Configure session with long timeouts for avatar generation
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 600.0
        config.timeoutIntervalForResource = 720.0
        self.session = session ?? URLSession(configuration: config)
    }
    
    /// Uploads an avatar image to the backend and retrieves the processed avatar.
    ///
    /// This method performs a three-step process:
    /// 1. Uploads the user's image to the backend API endpoint POST /users/{user_id}/avatar
    ///    - The user_id is passed as a path parameter in the URL
    ///    - The image is sent as multipart/form-data with field name "image"
    ///    - The backend processes the image and stores it in MinIO object storage
    /// 2. Decodes the response to get the avatar URL path returned by the backend
    ///    - Backend returns JSON: { "avatar_url": "/avatars/user_1" }
    /// 3. Fetches the generated avatar image from MinIO storage
    ///    - Constructs MinIO URL by replacing port 8000 with 9000 in baseURL
    ///    - Attempts to fetch with the path as-is, then retries with .png extension if needed
    ///
    /// - Parameters:
    ///   - userId: The user ID to associate the avatar with (used in URL path)
    ///   - image: The UIImage to upload and process
    /// - Returns: The processed avatar UIImage from MinIO
    /// - Throws: AvatarAPIError for various failure scenarios (network, conversion, server errors)
    func uploadAvatar(userId: Int, image: UIImage) async throws -> UIImage {
        // Step 1: Prepare the image to upload
        // If USE_REAL_API_WITH_MOCK_PHOTO is true, use test_avatar_generation.png instead of user's photo
        let imageToUpload: UIImage
        if USE_REAL_API_WITH_MOCK_PHOTO {
            // Try to load test_avatar_generation.png from bundle or file system
            if let mockImage = UIImage(named: "test_avatar_generation") {
                imageToUpload = mockImage
            } else if let mockImagePath = Bundle.main.path(forResource: "test_avatar_generation", ofType: "png"),
                      let mockImage = UIImage(contentsOfFile: mockImagePath) {
                imageToUpload = mockImage
                print("Using test_avatar_generation.png from bundle path (real API with mock photo)")
            } else {
                // Fallback to project root
                let projectRootPath = "/Users/cassieliu/TheBuilders/test_avatar_generation.png"
                if let mockImage = UIImage(contentsOfFile: projectRootPath) {
                    imageToUpload = mockImage
                    print("Using test_avatar_generation.png from project root (real API with mock photo)")
                } else {
                    // If can't find mock photo, use original image
                    imageToUpload = image
                    print("Could not find test_avatar_generation.png, using original image")
                }
            }
        } else {
            imageToUpload = image
        }
        
        // Step 2: Convert UIImage to JPEG data for upload
        // Using 0.8 compression quality to balance file size and image quality
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
        
        // Set Accept header to indicate we expect JSON response
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
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
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Avatar upload failed!")
            print("   Status code: \(httpResponse.statusCode)")
            print("   Response headers: \(httpResponse.allHeaderFields)")
            print("   Response body: \(errorBody)")
            print("   Response body (hex): \(data.map { String(format: "%02x", $0) }.joined())")
            
            // Try to parse as JSON to get more details
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("   Parsed JSON: \(json)")
            }
            
            throw AvatarAPIError.serverError(httpResponse.statusCode)
        }
        
        //Step 2: Decode response to get avatar URL
        // Backend returns: { "avatar_url": "/avatars/user_1" }
        // Note: Backend stores as PNG (content_type="image/png") but path doesn't include extension
        let uploadResponse = try JSONDecoder().decode(AvatarUploadResponse.self, from: data)
        let avatarPath = uploadResponse.avatar_url
        
        // Step 3: Fetch the generated avatar image from MinIO
        // Step 3.1: Try fetching from MinIO directly
        // MinIO public URL format: http://{server_ip}:9000/avatars/user_1
        let minioBaseURL = baseURL.replacingOccurrences(of: ":8000", with: ":9000")
        
        var avatarURLString = "\(minioBaseURL)\(avatarPath)"
        
        guard var avatarURL = URL(string: avatarURLString) else {
            throw AvatarAPIError.invalidURL
        }
        
        // Step 3.1.2: Try fetching with the path as returned by backend
        var (avatarData, avatarResponse) = try await session.data(from: avatarURL)
        var avatarHttpResponse = avatarResponse as? HTTPURLResponse
        
        // If that fails, try adding .png extension (since backend stores as PNG)
        if avatarHttpResponse?.statusCode != 200 {
            print("First attempt failed (status: \(avatarHttpResponse?.statusCode ?? -1)), trying with .png extension")
            avatarURLString = "\(minioBaseURL)\(avatarPath).png"
            if let urlWithExtension = URL(string: avatarURLString) {
                avatarURL = urlWithExtension
                (avatarData, avatarResponse) = try await session.data(from: avatarURL)
                avatarHttpResponse = avatarResponse as? HTTPURLResponse
                print("Retry with extension: \(avatarURLString)")
            }
        }
        
        guard let httpResponse = avatarHttpResponse else {
            throw AvatarAPIError.invalidResponse
        }
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            let errorMsg = "Failed to fetch avatar from MinIO. Status: \(httpResponse.statusCode), URL: \(avatarURLString)"
            print(" \(errorMsg)")
            print("   Backend returned path: \(avatarPath)")
            print("   MinIO base URL: \(minioBaseURL)")
            throw AvatarAPIError.serverError(httpResponse.statusCode)
        }
        
        // Convert data to UIImage
        guard let avatarImage = UIImage(data: avatarData) else {
            print("Failed to convert avatar data to UIImage")
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
