//
//  S3UploadService.swift
//  TheBuilders
//
//  Service for uploading images directly to Minio/S3 blob storage
//

import Foundation
import UIKit

enum S3UploadError: LocalizedError {
    case invalidURL
    case uploadFailed(Error)
    case noData
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid upload URL"
        case .uploadFailed(let error):
            return "Upload failed: \(error.localizedDescription)"
        case .noData:
            return "No image data available"
        }
    }
}

struct S3UploadService {
    private let minioBaseURL: String
    private let bucketName: String
    
    init(minioBaseURL: String = "http://localhost:9000", bucketName: String = "images") {
        self.minioBaseURL = minioBaseURL
        self.bucketName = bucketName
    }
    
    /// Upload an image to Minio/S3 storage
    /// - Parameters:
    ///   - image: The UIImage to upload
    ///   - key: The S3 key (path) where the image should be stored (e.g., "garment_blue_shirt_1" or "chat/1234567890_uuid.jpg")
    /// - Returns: The full CDN URL where the image can be accessed
    func uploadImage(_ image: UIImage, key: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw S3UploadError.noData
        }
        
        // Construct the upload URL
        // The key should match the backend pattern: /images/garment_{base}_{owner} or /images/chat_{timestamp}_{uuid}
        // Remove leading slash if present, then construct full URL
        let cleanKey = key.hasPrefix("/") ? String(key.dropFirst()) : key
        let uploadURLString = "\(minioBaseURL)/\(cleanKey)"
        
        guard let uploadURL = URL(string: uploadURLString) else {
            throw S3UploadError.invalidURL
        }
        
        // Create PUT request
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = imageData
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw S3UploadError.uploadFailed(NSError(domain: "S3Upload", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"]))
        }
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw S3UploadError.uploadFailed(NSError(domain: "S3Upload", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Upload failed with status \(httpResponse.statusCode)"]))
        }

        return uploadURLString
    }
    
    /// Generate a temporary key for chat images
    /// Format: /images/chat_{timestamp}_{uuid}.jpg
    /// UUID ensures uniqueness even if multiple images are uploaded at the same timestamp
    func generateChatImageKey() -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let uuid = UUID().uuidString.prefix(8)  // Use first 8 chars of UUID for uniqueness
        // For chat: /images/chat_{timestamp}_{uuid}
        return "/\(bucketName)/chat_\(timestamp)_\(uuid).jpg"
    }
}

