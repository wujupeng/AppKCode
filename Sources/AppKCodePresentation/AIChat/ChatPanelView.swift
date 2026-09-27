import SwiftUI
import AppKit
import AppKCodeShared

struct ChatPanelView: View {
    @ObservedObject var viewModel: ChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            chatHeader
            messageList
            if let error = viewModel.errorMessage {
                errorBanner(error)
            }
            ChatInputView(
                onSend: { text, sources in
                    viewModel.send(message: text, contextSources: sources)
                },
                isStreaming: viewModel.streamingState == .streaming,
                selectedSources: $viewModel.selectedSources
            )
        }
    }

    private var chatHeader: some View {
        HStack {
            Image(systemName: "bubble.left.and.bubble.right")
                .foregroundColor(.accentColor)
            Text("AI Chat")
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
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var statusColor: Color {
        switch viewModel.streamingState {
        case .idle: return .gray
        case .streaming: return .blue
        case .error: return .red
        case .cancelled: return .orange
        case .active: return .green
        }
    }

    private var statusText: String {
        switch viewModel.streamingState {
        case .idle: return "Ready"
        case .streaming: return "Streaming…"
        case .error: return "Error"
        case .cancelled: return "Cancelled"
        case .active: return "Active"
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.messages, id: \.id) { msg in
                        ChatMessageView(message: msg)
                            .id(msg.id)
                    }
                    if viewModel.streamingState == .streaming && !viewModel.currentStreamingText.isEmpty {
                        HStack {
                            Text(viewModel.currentStreamingText)
                                .font(.system(size: 13))
                                .textSelection(.enabled)
                            Spacer()
                        }
                        .padding(.leading, 12)
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

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(message)
                .font(.caption)
                .foregroundColor(.red)
            Spacer()
        }
        .padding(8)
        .background(Color.red.opacity(0.1))
    }
}