import SwiftUI

struct ChatMessage: Identifiable, Equatable {
    enum Role { case user, assistant }
    let id = UUID()
    let role: Role
    let text: String
    let timestamp: Date = Date()
}

struct FeedbackView: View {
    @State private var messages: [ChatMessage] = [
        ChatMessage(role: .assistant, text: "Hi! I’m your personal outfit companion 🌸\nI can give you some general fashion recommendations, or you can send me your outfit and I’ll tell you what I think!")
    ]
    @State private var inputText: String = ""
    @State private var isSending: Bool = false

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

        // Append user message
        messages.append(ChatMessage(role: .user, text: text))

        // TODO: Integrate AI here. For now, we simulate an assistant reply after a short delay.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            let placeholder = "(TODO) This is where the AI reply will appear. For now, I'm a placeholder!"
            messages.append(ChatMessage(role: .assistant, text: placeholder))
            isSending = false
        }
    }
}

#Preview {
    NavigationView {
        FeedbackView()
    }
}
