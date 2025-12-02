import SwiftUI
import PhotosUI

struct ChatMessage: Identifiable, Equatable {
    enum Role { case user, assistant }
    let id = UUID()
    let role: Role
    let text: String
    var images: [UIImage]? = nil  // Temporary - used before upload
    var imageURLs: [String]? = nil  // URLs after upload to S3
    let timestamp: Date = Date()
    
    // Equatable conformance - ignore images for equality check since UIImage isn't Equatable
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        return lhs.id == rhs.id &&
               lhs.role == rhs.role &&
               lhs.text == rhs.text &&
               (lhs.images?.count ?? 0) == (rhs.images?.count ?? 0) &&
               lhs.imageURLs == rhs.imageURLs
    }
    
    // Convert to API format
    // Note: Images should already be uploaded to S3 and have URLs set in imageURLs
    func toConversationMessage() -> ConversationMessage {
        let roleString = role == .user ? "user" : "assistant"
        
        // If there are image URLs, create content array with image blocks and text
        if let urls = imageURLs, !urls.isEmpty {
            var contentBlocks: [ConversationMessage.ContentBlock] = []
            
            // Add image blocks with URLs (images already uploaded to S3)
            for url in urls {
                let imageSource = ConversationMessage.ImageSource(
                    type: "url",
                    url: url,
                    media_type: nil,  // Not needed for URL type
                    data: nil
                )
                contentBlocks.append(ConversationMessage.ContentBlock(
                    type: "image",
                    source: imageSource,
                    text: nil
                ))
            }
            
            // Add text block if there's text
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                contentBlocks.append(ConversationMessage.ContentBlock(
                    type: "text",
                    source: nil,
                    text: text
                ))
            }
            
            return ConversationMessage(
                role: roleString,
                content: .array(contentBlocks)
            )
        } else {
            // Text-only message
            return ConversationMessage(
                role: roleString,
                text: text
            )
        }
    }
    
    // Convert Markdown to plain text for display
    var displayText: String {
        return text.cleanedMarkdown()
    }
}

extension String {
    func cleanedMarkdown() -> String {
        var cleaned = self
        
        // Remove code blocks ``` first (multi-line)
        while let startRange = cleaned.range(of: "```") {
            if let endRange = cleaned[startRange.upperBound...].range(of: "```") {
                cleaned.removeSubrange(startRange.lowerBound..<endRange.upperBound)
            } else {
                break
            }
        }
        
        // Split into lines to handle multi-line patterns
        var lines = cleaned.components(separatedBy: .newlines)
        
        // Process each line
        for i in 0..<lines.count {
            var line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Remove markdown headers (##, ###, etc.) at start of line
            if trimmed.hasPrefix("#") {
                line = line.replacingOccurrences(of: #"^#+\s*"#, with: "", options: .regularExpression)
            }
            
            // Remove markdown list markers (-, *) at start of line and replace with bullet
            if trimmed.hasPrefix("-") || trimmed.hasPrefix("*") {
                line = line.replacingOccurrences(of: #"^\s*[-*]\s+"#, with: "• ", options: .regularExpression)
            }
            
            // Remove numbered list markers (1., 2., etc.) at start of line
            if trimmed.first?.isNumber == true {
                line = line.replacingOccurrences(of: #"^\s*\d+\.\s+"#, with: "", options: .regularExpression)
            }
            
            // Remove bold markdown (**text**) first
            line = line.replacingOccurrences(of: #"\*\*([^*]+)\*\*"#, with: "$1", options: .regularExpression)
            
            // Remove italic markdown (*text*) - simple pattern matching
            // Since bold is already removed, any remaining *text* is italic
            while let startRange = line.range(of: "*") {
                let afterStart = line.index(after: startRange.lowerBound)
                if let endRange = line[afterStart...].range(of: "*") {
                    // Found *text* pattern
                    let text = line[startRange.upperBound..<endRange.lowerBound]
                    line.replaceSubrange(startRange.lowerBound...endRange.lowerBound, with: String(text))
                } else {
                    break
                }
            }
            
            // Remove italic markdown (_text_)
            line = line.replacingOccurrences(of: #"_([^_]+)_"#, with: "$1", options: .regularExpression)
            
            // Remove markdown links [text](url) -> text
            line = line.replacingOccurrences(of: #"\[([^\]]+)\]\([^\)]+\)"#, with: "$1", options: .regularExpression)
            
            // Remove inline code `code`
            line = line.replacingOccurrences(of: #"`([^`]+)`"#, with: "$1", options: .regularExpression)
            
            lines[i] = line
        }
        
        // Join lines back
        cleaned = lines.joined(separator: "\n")
        
        // Clean up extra whitespace and newlines
        while cleaned.contains("\n\n\n") {
            cleaned = cleaned.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned
    }
}

struct FeedbackView: View {
    @State private var messages: [ChatMessage] = [
        ChatMessage(role: .assistant, text: "Hi! I'm your personal outfit companion 🌸\nI can give you some general fashion recommendations, or you can send me your outfit and I'll tell you what I think!")
    ]
    @State private var inputText: String = ""
    @State private var isSending: Bool = false
    @State private var errorMessage: String?
    @State private var showError: Bool = false
    @State private var selectedImages: [UIImage] = []
    @State private var showImagePicker: Bool = false
    @State private var showCamera: Bool = false
    @State private var showImageSourcePicker: Bool = false
    
    // Chat service - uses configuration to determine mock vs real
    private let chatService: ChatServiceProtocol
    
    // Weather service to provide context for outfit questions
    @StateObject private var weatherViewModel = WeatherViewModel()
    
    // S3/Minio upload service for images
    private let s3UploadService = S3UploadService()
    
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
                .contentShape(Rectangle())
                .onTapGesture {
                    hideKeyboard()
                }
                .onChange(of: messages.count) { oldValue, newValue in
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
                    Text(message.displayText)
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
                VStack(alignment: .trailing, spacing: 8) {
                    // Show images if any
                    if let images = message.images {
                        ForEach(0..<images.count, id: \.self) { index in
                            Image(uiImage: images[index])
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 200, maxHeight: 200)
                                .cornerRadius(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white)
                                )
                        }
                    }
                    
                    // Show text if any
                    if !message.text.isEmpty {
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
    }

    private var inputBar: some View {
        VStack(spacing: 8) {
            // Show selected images preview
            if !selectedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(0..<selectedImages.count, id: \.self) { index in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: selectedImages[index])
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .cornerRadius(8)
                                
                                Button(action: {
                                    selectedImages.remove(at: index)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                        .background(Circle().fill(Color.white))
                                }
                                .offset(x: 5, y: -5)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .frame(height: 70)
            }
            
            HStack(spacing: 12) {
                // Image picker button
                Button(action: {
                    showImageSourcePicker = true
                }) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.purple)
                        .padding(12)
                        .background(Circle().fill(Color.purple.opacity(0.1)))
                }
                
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
                .disabled((inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedImages.isEmpty) || isSending)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .confirmationDialog("Add Image", isPresented: $showImageSourcePicker, titleVisibility: .visible) {
            Button("Camera") {
                showCamera = true
            }
            Button("Photo Library") {
                showImagePicker = true
            }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showImagePicker) {
            PHPickerViewControllerWrapper(images: $selectedImages)
        }
        .sheet(isPresented: $showCamera) {
            FeedbackImagePicker(images: $selectedImages, sourceType: .camera)
        }
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let images = selectedImages
        
        // Must have either text or images
        guard !text.isEmpty || !images.isEmpty else { return }
        
        // Clear input immediately (optimistic UI update)
        let textToSend = text
        let imagesToSend = images
        inputText = ""
        selectedImages = []
        isSending = true
        
        // Clear any previous error
        errorMessage = nil
        showError = false
        
        // Create placeholder message (will be updated with URLs after upload)
        var userMessage = ChatMessage(role: .user, text: textToSend)
        if !imagesToSend.isEmpty {
            userMessage.images = imagesToSend
        }
        
        // Append user message (with images, URLs will be added after upload)
        messages.append(userMessage)
        
        // Call the chat API
        Task {
            do {
                // If there are images, upload them to S3 first
                var imageURLs: [String] = []
                if !imagesToSend.isEmpty {
                    for image in imagesToSend {
                        let key = s3UploadService.generateChatImageKey()
                        let url = try await s3UploadService.uploadImage(image, key: key)
                        imageURLs.append(url)
                    }
                    
                    // Update the message with the uploaded image URLs
                    if let lastIndex = messages.indices.last, messages[lastIndex].role == .user {
                        messages[lastIndex].imageURLs = imageURLs
                        // Clear the UIImage array since we now have URLs
                        messages[lastIndex].images = nil
                    }
                }
                
                // Convert messages to API format (now with URLs instead of images)
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
                // The ChatService will automatically append weather context to user messages
                // when outfit-related questions are detected
                let response = try await chatService.sendMessage(
                    messages: conversationMessages,
                    weatherData: weatherData
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
    
    // hide keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), 
                                       to: nil, from: nil, for: nil)
    }
}

// MARK: - Image Picker

struct FeedbackImagePicker: UIViewControllerRepresentable {
    @Binding var images: [UIImage]
    var sourceType: UIImagePickerController.SourceType
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: FeedbackImagePicker
        
        init(_ parent: FeedbackImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.images.append(image)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Multiple Image Picker (Photo Library)

struct PHPickerViewControllerWrapper: UIViewControllerRepresentable {
    @Binding var images: [UIImage]
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.selectionLimit = 10
        configuration.filter = .images
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PHPickerViewControllerWrapper
        
        init(_ parent: PHPickerViewControllerWrapper) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            for result in results {
                if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                        if let image = image as? UIImage {
                            DispatchQueue.main.async {
                                self?.parent.images.append(image)
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        FeedbackView()
    }
}
