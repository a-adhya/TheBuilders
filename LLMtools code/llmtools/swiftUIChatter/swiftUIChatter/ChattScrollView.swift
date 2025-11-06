import SwiftUI

struct ChattView: View {
    let chatt: Chatt
    let isSender: Bool
    
    var body: some View {
        VStack(alignment: isSender ? .trailing : .leading, spacing: 4) {
            if let msg = chatt.message, !msg.isEmpty {
                Text(isSender ? "" : chatt.username ?? "")
                    .font(.subheadline)
                    .foregroundColor(.purple)
                    .padding(.leading, 4)
                
                Text(msg)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(isSender ? .systemBlue : .systemBackground))
                    .foregroundColor(isSender ? .white: .primary)
                    .cornerRadius(20)
                    .shadow(radius: 2)
                    .frame(maxWidth: 300, alignment: isSender ? .trailing : .leading)
                
                Text(chatt.timestamp ??  "")
                    .font(.caption2)
                    .foregroundColor(.gray)
                
                Spacer()
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
    }
}

struct ChattScrollView: View {
    @Environment(ChattViewModel.self) private var vm
    
    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(ChattStore.shared.chatts) {
                    ChattView(chatt: $0, isSender: $0.username == vm.username)
                }
            }
        }
    }
}
