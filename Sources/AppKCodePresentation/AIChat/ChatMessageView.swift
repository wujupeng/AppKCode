import SwiftUI
import AppKit
import AppKCodeShared

struct ChatMessageView: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                contentView
                metaInfo
            }
            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }

    private var contentView: some View {
        Text(message.content)
            .font(.system(size: 13))
            .foregroundColor(message.role == .user ? .white : .primary)
            .padding(10)
            .background(message.role == .user ? Color.accentColor : Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .textSelection(.enabled)
    }

    private var metaInfo: some View {
        HStack(spacing: 6) {
            if message.role == .system {
                Text("system")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            if let usage = message.metadata.tokenUsage {
                Text("\(usage.promptTokens)→\(usage.completionTokens) tokens")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}