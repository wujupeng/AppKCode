import Foundation
import AppKCodeShared

// MARK: - MCP HTTP Transport (TASK-008)

public final class MCPHttpTransport: MCPTransportProtocol, @unchecked Sendable {
    private let config: MCPServerConfig
    private let session: URLSession
    private var nextRequestID: Int = 1
    private let lock = NSLock()
    private var isStarted = false

    public init(config: MCPServerConfig) {
        self.config = config
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = TimeInterval(config.timeoutSeconds)
        self.session = URLSession(configuration: sessionConfig)
    }

    public func start() async throws {
        switch config.transport {
        case .http, .sse:
            isStarted = true
        case .stdio:
            throw MCPTransportError.transportMismatch
        }
    }

    public func stop() async throws {
        isStarted = false
    }

    public func send(_ request: MCPJSONRPCRequest) async throws -> MCPJSONRPCResponse {
        guard isStarted else {
            throw MCPTransportError.notStarted
        }

        guard case .http(let endpoint) = config.transport else {
            throw MCPTransportError.transportMismatch
        }

        let encoder = JSONEncoder()
        let bodyData = try encoder.encode(request)

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = bodyData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MCPTransportError.connectionFailed("HTTP request failed")
        }

        let mcpResponse = try JSONDecoder().decode(MCPJSONRPCResponse.self, from: data)
        return mcpResponse
    }

    public func sendNotification(_ notification: MCPJSONRPCNotification) async throws {
        guard isStarted else {
            throw MCPTransportError.notStarted
        }

        guard case .http(let endpoint) = config.transport else {
            throw MCPTransportError.transportMismatch
        }

        let encoder = JSONEncoder()
        let bodyData = try encoder.encode(notification)

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = bodyData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        _ = try await session.data(for: urlRequest)
    }

    func getNextRequestID() -> Int {
        lock.lock()
        defer { lock.unlock() }
        let id = nextRequestID
        nextRequestID += 1
        return id
    }
}