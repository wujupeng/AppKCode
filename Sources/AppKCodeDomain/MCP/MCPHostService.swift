import Foundation
import AppKCodeShared
import AppKCodeInfrastructure

// MARK: - MCP Host Service Protocol (TASK-012.1)

public protocol MCPHostService: Sendable {
    func registerServer(_ config: MCPServerConfig) async throws
    func enableServer(_ id: MCPServerID) async throws -> MCPConnectionState
    func disableServer(_ id: MCPServerID) async throws
    func listServers() -> [MCPServerConfig]
    func serverState(_ id: MCPServerID) -> MCPConnectionState
    var serverEvents: AsyncStream<MCPServerEvent> { get }
}

// MARK: - MCP Host Service Impl (TASK-012.2~012.3)

public final class MCPHostServiceImpl: MCPHostService, @unchecked Sendable {
    private let processManager: MCPServerProcessManager
    private var configs: [MCPServerID: MCPServerConfig] = [:]
    private let lock = NSLock()

    public init(processManager: MCPServerProcessManager) {
        self.processManager = processManager
    }

    public var serverEvents: AsyncStream<MCPServerEvent> {
        processManager.serverEvents
    }

    public func registerServer(_ config: MCPServerConfig) async throws {
        lock.lock()
        configs[config.id] = config
        lock.unlock()
    }

    public func enableServer(_ id: MCPServerID) async throws -> MCPConnectionState {
        lock.lock()
        let config = configs[id]
        lock.unlock()

        guard let config = config else {
            throw MCPHostError.serverNotRegistered(id)
        }

        return try await processManager.startServer(config)
    }

    public func disableServer(_ id: MCPServerID) async throws {
        try await processManager.stopServer(id)
    }

    public func listServers() -> [MCPServerConfig] {
        lock.lock()
        defer { lock.unlock() }
        return Array(configs.values)
    }

    public func serverState(_ id: MCPServerID) -> MCPConnectionState {
        processManager.connectionState(id)
    }
}

// MARK: - MCP Host Error

public enum MCPHostError: Error, Sendable {
    case serverNotRegistered(MCPServerID)
    case serverAlreadyEnabled(MCPServerID)
    case discoveryFailed(MCPServerID, String)
}