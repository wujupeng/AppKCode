import SwiftUI
import AppKCodeShared

struct ContextPreviewView: View {
    let items: [ContextItem]
    let budget: ContextBudget

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            ForEach(items, id: \.id) { item in
                contextItemRow(item)
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var header: some View {
        HStack {
            Text("Context Preview")
                .font(.headline)
            Spacer()
            Text("\(totalTokens) / \(budget.maxTokens) tokens")
                .font(.caption)
                .foregroundColor(totalTokens > budget.maxTokens ? .red : .secondary)
        }
    }

    private func contextItemRow(_ item: ContextItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("[source: \(item.source.rawValue)]")
                    .font(.caption2)
                    .foregroundColor(.accentColor)
                if let path = item.path {
                    Text(path.lastPathComponent)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                if let range = item.range {
                    Text("L\(range.startLine)-\(range.endLine)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("~\(item.tokenEstimate) tokens")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Text(item.content.prefix(200))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(3)
        }
        .padding(6)
        .background(Color(NSColor.textBackgroundColor).opacity(0.5))
        .cornerRadius(4)
    }

    private var totalTokens: Int {
        items.reduce(0) { $0 + $1.tokenEstimate }
    }
}