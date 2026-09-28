import SwiftUI
import AppKCodeShared

// MARK: - MCP Tool Browser View (TASK-029)

public struct MCPToolBrowserView: View {
    public let tools: [ToolSchema]
    public let resources: [MCPResourceDescriptor]

    public init(tools: [ToolSchema] = [], resources: [MCPResourceDescriptor] = []) {
        self.tools = tools
        self.resources = resources
    }

    public var body: some View {
        TabView {
            VStack {
                Text("MCP Tools").font(.headline).padding(.top, 8)
                List(tools, id: \.id) { tool in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(tool.id.rawValue).font(.system(.body, design: .monospaced))
                            Text(tool.description).font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        permissionBadge(tool.permission)
                    }
                }
            }
            .tabItem { Label("Tools", systemImage: "wrench.and.screwdriver") }

            VStack {
                Text("MCP Resources").font(.headline).padding(.top, 8)
                List(resources, id: \.uri) { resource in
                    VStack(alignment: .leading) {
                        Text(resource.name).font(.body)
                        Text(resource.uri).font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            .tabItem { Label("Resources", systemImage: "doc.on.doc") }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func permissionBadge(_ permission: ToolPermission) -> some View {
        switch permission {
        case .readOnly:
            return Text("Auto").foregroundColor(.green).font(.caption)
        case .low:
            return Text("Low").foregroundColor(.yellow).font(.caption)
        case .high:
            return Text("Approval").foregroundColor(.red).font(.caption)
        }
    }
}