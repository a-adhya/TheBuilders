import SwiftUI
import PhotosUI

struct UploadAvatarView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var isUploading = false
    @State private var uploadError: String?
    @Binding var avatarImage: UIImage?
    @Binding var userName: String
    
    // Initialize API based on configuration
    private let avatarAPI: AvatarAPIProtocol = USE_MOCK_AVATAR_UPLOAD ? MockAvatarAPI() : RealAvatarAPI()
    private let userId: Int = 1 // Default user ID
    
    init(avatarImage: Binding<UIImage?>, userName: Binding<String>) {
        self._avatarImage = avatarImage
        self._userName = userName
        // Initialize selectedImage with existing avatar if available
        self._selectedImage = State(initialValue: avatarImage.wrappedValue)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 30) {
                        imagePickerSection
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Your Name")
                                .font(.title2)
                                .fontWeight(.heavy)
                                .foregroundColor(Color.purple.opacity(0.8))
                            TextField("Enter your name...", text: $userName)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.purple)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 15)
                                .background(
                                    RoundedRectangle(cornerRadius: 25)
                                        .stroke(Color.purple, lineWidth: 2)
                                        .background(
                                            RoundedRectangle(cornerRadius: 25)
                                                .fill(Color.purple.opacity(0.1))
                                        )
                                )
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 120)
                    }
                }
                bottomButtonsSection
            }
            .background(Color(.systemGray6))
            .navigationBarHidden(true)
            .photosPicker(isPresented: $showImagePicker, selection: $selectedPhoto, matching: .images)
            .sheet(isPresented: $showCamera) {
                AvatarImagePicker(image: $selectedImage, sourceType: .camera)
            }
            .onChange(of: selectedPhoto) { oldValue, newValue in
                Task { @MainActor in
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImage = image
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private var imagePickerSection: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 30)
                    .fill(Color.white)
                    .frame(height: 220)
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                
                if let selectedImage = selectedImage {
                    // Show selected image
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 30))
                } else {
                    // Show upload options
                    HStack {
                        Spacer(minLength: 24)
                        
                        // Photo Library Button
                        Button(action: {
                            showImagePicker = true
                        }) {
                            VStack(spacing: 12) {
                                Image(systemName: "square.and.arrow.up")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 64, height: 64)
                                    .foregroundColor(.purple)
                                
                                Text("Photo Library")
                                    .font(.caption)
                                    .foregroundColor(.black)
                            }
                        }
                        .frame(maxWidth: .infinity)

                        Rectangle()
                            .fill(Color.purple.opacity(0.6))
                            .frame(width: 1, height: 140)

                        // Camera Button
                        Button(action: {
                            showCamera = true
                        }) {
                            VStack(spacing: 12) {
                                Image(systemName: "camera")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 64, height: 64)
                                    .foregroundColor(.purple)
                                
                                Text("Camera")
                                    .font(.caption)
                                    .foregroundColor(.black)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        Spacer(minLength: 24)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
        }
    }

    private var bottomButtonsSection: some View {
        HStack(spacing: 0) {
            Button(action: { dismiss() }) {
                VStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 24))
                        .foregroundColor(.purple)
                    Text("Back")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.purple)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: {
                // Prevent multiple taps while uploading
                guard !isUploading else { return }
                Task {
                    await uploadAvatar()
                }
            }) {
                VStack(spacing: 8) {
                    if isUploading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                    } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 24))
                    }
                    Text(isUploading ? "Uploading..." : "Done")
                        .font(.system(size: 16, weight: .medium))
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(selectedImage == nil || isUploading)
            .foregroundColor(selectedImage == nil || isUploading ? .purple.opacity(0.4) : .purple)
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .background(
            Rectangle()
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: -1)
        )
        .alert("Upload Error", isPresented: .constant(uploadError != nil)) {
            Button("OK") {
                uploadError = nil
            }
        } message: {
            if let error = uploadError {
                Text(error)
            }
        }
    }
    
    // MARK: - API Methods

    // Need to double check with the main actor usage here
    
    /// Uploads the selected avatar image using the configured AvatarAPI.
    ///
    /// This method:
    /// 1. Validates that an image has been selected
    /// 2. Sets uploading state to show progress indicator
    /// 3. Calls avatarAPI.uploadAvatar()
    /// 4. Updates the avatarImage binding with the processed result
    /// 5. Dismisses the view on success, or shows error alert on failure
    ///
    /// The API call is asynchronous and may take several minutes for real avatar generation.
    @MainActor
    private func uploadAvatar() async {
        guard let image = selectedImage else { return }
        
        isUploading = true
        uploadError = nil
        
        do {
            let processedAvatar = try await avatarAPI.uploadAvatar(userId: userId, image: image)
            avatarImage = processedAvatar
            isUploading = false
            dismiss()
        } catch {
            isUploading = false
            uploadError = "Failed to upload avatar: \(error.localizedDescription)"
        }
    }
}

// MARK: - Image Picker (Camera)
fileprivate struct AvatarImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    var sourceType: UIImagePickerController.SourceType
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: AvatarImagePicker
        
        init(_ parent: AvatarImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    UploadAvatarView(avatarImage: .constant(nil), userName: .constant(""))
}
