import SwiftUI
import AppKCodeShared
import AppKCodeApplication

// MARK: - MCP Server Management View (TASK-028)

public struct MCPServerManagementView: View {
    @StateObject var viewModel = MCPServerManagementViewModel()

    public init() {}

    public var body: some View {
        List(viewModel.servers, id: \.id) { server in
            HStack {
                VStack(alignment: .leading) {
                    Text(server.name).font(.headline)
                    Text(transportText(server.transport)).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                connectionStateIcon(viewModel.serverStates[server.id] ?? .disconnected)
                Text("\(viewModel.toolCounts[server.id] ?? 0) tools").font(.caption).foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func transportText(_ transport: MCPTransport) -> String {
        switch transport {
        case .stdio(let cmd, _, _): return "stdio: \(cmd)"
        case .http(let url): return "http: \(url.host ?? "")"
        case .sse(let url): return "sse: \(url.host ?? "")"
        }
    }

    private func connectionStateIcon(_ state: MCPConnectionState) -> some View {
        switch state {
        case .connected: return Image(systemName: "circle.fill").foregroundColor(.green)
        case .connecting: return Image(systemName: "circle.dashed").foregroundColor(.yellow)
        case .disconnected: return Image(systemName: "circle").foregroundColor(.gray)
        case .disconnectedUnexpectedly: return Image(systemName: "exclamationmark.circle").foregroundColor(.orange)
        case .failed: return Image(systemName: "xmark.circle").foregroundColor(.red)
        }
    }
}

@MainActor
public final class MCPServerManagementViewModel: ObservableObject {
    @Published public var servers: [MCPServerConfig] = []
    @Published public var serverStates: [MCPServerID: MCPConnectionState] = [:]
    @Published public var toolCounts: [MCPServerID: Int] = [:]

    public init() {}
}