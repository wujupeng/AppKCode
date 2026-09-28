import Foundation
import AppKCodeShared

// MARK: - MCP Server Event (TASK-009.3)

public enum MCPServerEvent: Sendable, Equatable {
    case connected(MCPServerID)
    case disconnected(MCPServerID, reason: String)
    case failed(MCPServerID, error: String)
}

// MARK: - MCP Managed Server (internal)

struct MCPManagedServer {
    let config: MCPServerConfig
    let transport: MCPTransportProtocol
    var state: MCPConnectionState
}

// MARK: - MCP Server Process Manager (TASK-009)

public final class MCPServerProcessManager: @unchecked Sendable {
    private var servers: [MCPServerID: MCPManagedServer] = [:]
    private let lock = NSLock()
    private var eventContinuation: AsyncStream<MCPServerEvent>.Continuation?

    public init() {}

    public var serverEvents: AsyncStream<MCPServerEvent> {
        AsyncStream { continuation in
            self.eventContinuation = continuation
        }
    }

    public func startServer(_ config: MCPServerConfig) async throws -> MCPConnectionState {
        lock.lock()
        defer { lock.unlock() }

        let transport: MCPTransportProtocol
        switch config.transport {
        case .stdio:
            transport = MCPStdioTransport(config: config)
        case .http, .sse:
            transport = MCPHttpTransport(config: config)
        }

        servers[config.id] = MCPManagedServer(config: config, transport: transport, state: .connecting)

        do {
            try await transport.start()
            servers[config.id]?.state = .connected
            eventContinuation?.yield(.connected(config.id))
            return .connected
        } catch {
            servers[config.id]?.state = .failed(error: error.localizedDescription)
            eventContinuation?.yield(.failed(config.id, error: error.localizedDescription))
            return .failed(error: error.localizedDescription)
        }
    }

    public func stopServer(_ id: MCPServerID) async throws {
        lock.lock()
        let server = servers.removeValue(forKey: id)
        lock.unlock()

        if let server = server {
            try? await server.transport.stop()
            eventContinuation?.yield(.disconnected(id, reason: "Stopped by user"))
        }
    }

    public func stopAll() async throws {
        lock.lock()
        let allServers = servers
        servers.removeAll()
        lock.unlock()

        for (_, server) in allServers {
            try? await server.transport.stop()
            eventContinuation?.yield(.disconnected(server.config.id, reason: "Stopped all"))
        }
    }

    public func connectionState(_ id: MCPServerID) -> MCPConnectionState {
        lock.lock()
        defer { lock.unlock() }
        return servers[id]?.state ?? .disconnected
    }

    public func getTransport(_ id: MCPServerID) -> MCPTransportProtocol? {
        lock.lock()
        defer { lock.unlock() }
        return servers[id]?.transport
    }

    public func listServers() -> [MCPServerConfig] {
        lock.lock()
        defer { lock.unlock() }
        return servers.values.map { $0.config }
    }
}