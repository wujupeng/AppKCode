import Foundation
import AppKCodeShared
import AppKCodeDomain
import AppKCodeInfrastructure

// MARK: - MCP Host App Service (TASK-024)

public final class MCPHostAppService: @unchecked Sendable {
    private let hostService: MCPHostService
    private let toolDiscovery: MCPToolDiscovery
    private let resourceDiscovery: MCPResourceDiscovery
    private let toolInvocation: MCPToolInvocation
    private let toolRegistry: ToolRegistry

    public init(
        hostService: MCPHostService,
        toolDiscovery: MCPToolDiscovery,
        resourceDiscovery: MCPResourceDiscovery,
        toolInvocation: MCPToolInvocation,
        toolRegistry: ToolRegistry
    ) {
        self.hostService = hostService
        self.toolDiscovery = toolDiscovery
        self.resourceDiscovery = resourceDiscovery
        self.toolInvocation = toolInvocation
        self.toolRegistry = toolRegistry
    }

    public func registerAndEnable(_ config: MCPServerConfig) async throws -> [ToolID] {
        try await hostService.registerServer(config)
        _ = try await hostService.enableServer(config.id)

        let adapterFactory: (MCPServerID, MCPToolDescriptor, ToolSchema) -> AgentTool = { serverID, descriptor, schema in
            MCPToolAdapter(serverID: serverID, descriptor: descriptor, schema: schema, invocation: self.toolInvocation)
        }

        return try await toolDiscovery.discoverAndRegister(
            serverID: config.id,
            serverName: config.name,
            registry: toolRegistry,
            adapterFactory: adapterFactory
        )
    }

    public func listServers() -> [MCPServerConfig] {
        hostService.listServers()
    }

    public func serverState(_ id: MCPServerID) -> MCPConnectionState {
        hostService.serverState(id)
    }

    public func disableServer(_ id: MCPServerID) async throws {
        try await hostService.disableServer(id)
    }

    public func discoverTools(_ id: MCPServerID) async throws -> [ToolSchema] {
        let descriptors = try await toolDiscovery.discoverTools(serverID: id)
        let config = hostService.listServers().first { $0.id == id }
        let serverName = config?.name ?? "unknown"
        return descriptors.map { toolDiscovery.convertToToolSchema($0, serverID: id, serverName: serverName) }
    }

    public func discoverResources(_ id: MCPServerID) async throws -> [MCPResourceDescriptor] {
        try await resourceDiscovery.discoverResources(serverID: id)
    }
}