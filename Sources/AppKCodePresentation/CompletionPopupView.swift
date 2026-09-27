import SwiftUI
import AppKCodeDomain

public struct CompletionPopupView: View {
    let items: [CompletionItem]
    let selectedIndex: Int
    let onAccept: (CompletionItem) -> Void
    let onDismiss: () -> Void

    public init(items: [CompletionItem], selectedIndex: Int,
                onAccept: @escaping (CompletionItem) -> Void,
                onDismiss: @escaping () -> Void) {
        self.items = items
        self.selectedIndex = selectedIndex
        self.onAccept = onAccept
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        CompletionRowView(item: item, isSelected: index == selectedIndex)
                            .onTapGesture {
                                onAccept(item)
                            }
                    }
                }
            }
        }
        .frame(width: 300, height: min(CGFloat(items.count) * 22 + 8, 200))
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(4)
        .shadow(radius: 4)
        .onExitCommand {
            onDismiss()
        }
    }
}

struct CompletionRowView: View {
    let item: CompletionItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: kindIcon)
                .foregroundColor(kindColor)
                .frame(width: 16)

            Text(item.label)
                .font(.system(size: 13, design: .default))

            if let detail = item.detail {
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
    }

    private var kindIcon: String {
        guard let kind = item.kind else { return "doc.text" }
        switch kind {
        case .method, .function: return "func"
        case .variable, .field: return "var"
        case .class: return "class"
        case .struct: return "struct"
        case .enum: return "enum"
        case .interface: return "protocol"
        case .property: return "property"
        case .keyword: return "keyword"
        case .module: return "module"
        case .file: return "doc.text"
        case .folder: return "folder"
        case .snippet: return "snippet"
        default: return "doc.text"
        }
    }

    private var kindColor: Color {
        guard let kind = item.kind else { return .secondary }
        switch kind {
        case .method, .function: return .purple
        case .variable, .field: return .blue
        case .class: return .orange
        case .struct: return .orange
        case .enum: return .orange
        case .interface: return .orange
        case .property: return .blue
        case .keyword: return .pink
        case .module: return .green
        default: return .secondary
        }
    }
}