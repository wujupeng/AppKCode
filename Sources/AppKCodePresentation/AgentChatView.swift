import SwiftUI
import AppKCodeShared

struct AgentChatView: View {
    @ObservedObject var viewModel: AgentChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            chatHeader
            messageList
            ChatInputBar(onSend: viewModel.sendMessage)
        }
    }

    private var chatHeader: some View {
        HStack {
            Image(systemName: "bubble.left.and.bubble.right")
                .foregroundColor(.accentColor)
            Text("AI Agent")
                .font(.headline)
            Spacer()
            statusIndicator
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var statusIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(viewModel.statusText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var statusColor: Color {
        switch viewModel.status {
        case .idle: return .gray
        case .thinking: return .blue
        case .error: return .red
        case .active: return .green
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.messages) { msg in
                        ChatMessageView(message: msg)
                            .id(msg.id)
                    }
                }
                .padding(12)
            }
            .onChange(of: viewModel.messages.count) { _ in
                if let lastID = viewModel.messages.last?.id {
                    withAnimation { proxy.scrollTo(lastID, anchor: .bottom) }
                }
            }
        }
    }
}

struct ChatMessageView: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer() }
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.system(size: 13))
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .padding(10)
                    .background(message.role == .user ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .textSelection(.enabled)
            }
            if message.role == .assistant { Spacer() }
        }
    }
}

struct ChatInputBar: View {
    @State private var inputText: String = ""
    let onSend: (String) -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("Ask anything…", text: $inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...5)
                .onSubmit { send() }

            Button(action: send) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 14))
            }
            .buttonStyle(.borderedProminent)
            .disabled(inputText.isEmpty)
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func send() {
        guard !inputText.isEmpty else { return }
        onSend(inputText)
        inputText = ""
    }
}