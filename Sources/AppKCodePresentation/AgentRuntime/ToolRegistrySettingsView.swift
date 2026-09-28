import SwiftUI
import AppKCodeShared

// MARK: - Tool Registry Settings View (TASK-030)

public struct ToolRegistrySettingsView: View {
    public let tools: [ToolSchema]

    public init(tools: [ToolSchema] = []) {
        self.tools = tools
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Tool Registry")
                    .font(.headline)
                Spacer()
            }
            .padding(8)

            Divider()

            List(tools, id: \.id) { tool in
                ToolSchemaRowView(tool: tool)
            }
        }
    }
}

struct ToolSchemaRowView: View {
    let tool: ToolSchema
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                permissionIcon
                Text(tool.id.rawValue)
                    .font(.system(.body, design: .monospaced))
                Spacer()
                Text(tool.version)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture { isExpanded.toggle() }

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Category: \(tool.category.rawValue)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(tool.description)
                        .font(.caption)
                    ForEach(tool.parameters, id: \.name) { param in
                        HStack {
                            Text("\(param.name)")
                                .font(.system(.caption, design: .monospaced))
                            Text(param.required ? "(required)" : "(optional)")
                                .font(.caption2)
                                .foregroundColor(param.required ? .red : .secondary)
                            Text(param.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.leading, 24)
            }
        }
    }

    @ViewBuilder var permissionIcon: some View {
        switch tool.permission {
        case .readOnly:
            Text("R").font(.caption2.bold())
                .padding(.horizontal, 4).padding(.vertical, 2)
                .background(.green.opacity(0.2)).cornerRadius(4)
        case .low:
            Text("L").font(.caption2.bold())
                .padding(.horizontal, 4).padding(.vertical, 2)
                .background(.blue.opacity(0.2)).cornerRadius(4)
        case .high:
            Text("H").font(.caption2.bold())
                .padding(.horizontal, 4).padding(.vertical, 2)
                .background(.red.opacity(0.2)).cornerRadius(4)
        }
    }
}