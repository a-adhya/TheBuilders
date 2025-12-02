import Foundation

/// Lightweight helper responsible for uploading, updating, and deleting images directly to/from MinIO/S3-compatible storage.
/// This keeps the backend agnostic of binary uploads while ensuring the frontend can control retries/errors.
struct ImageUploadService {
    static let shared = ImageUploadService()
    
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func uploadImage(_ data: Data, to url: URL, contentType: String = "image/jpeg") async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(String(data.count), forHTTPHeaderField: "Content-Length")
        
        let (_, response) = try await session.upload(for: request, from: data)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
    
    /// Delete an image from blob storage
    func deleteImage(from url: URL) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        // Accept 204 (No Content) or 200 (OK) as success
        guard (200..<300).contains(httpResponse.statusCode) || httpResponse.statusCode == 204 else {
            throw URLError(.badServerResponse)
        }
    }
    
    /// Update an image in blob storage
    /// If oldImageURL is provided and different from newImageURL, deletes the old image first
    func updateImage(_ data: Data, to newImageURL: URL, oldImageURL: URL?, contentType: String = "image/jpeg") async throws {
        // If the image URL changed, delete the old image first
        if let oldURL = oldImageURL, oldURL != newImageURL {
            try? await deleteImage(from: oldURL)
        }
        
        // Upload the new image
        try await uploadImage(data, to: newImageURL, contentType: contentType)
    }
}

