import Foundation
import AppKCodeShared

// MARK: - MCP Transport Protocol (TASK-007)

public protocol MCPTransportProtocol: Sendable {
    func send(_ request: MCPJSONRPCRequest) async throws -> MCPJSONRPCResponse
    func sendNotification(_ notification: MCPJSONRPCNotification) async throws
    func start() async throws
    func stop() async throws
}

// MARK: - MCP Stdio Transport (TASK-007)

public final class MCPStdioTransport: MCPTransportProtocol, @unchecked Sendable {
    private let config: MCPServerConfig
    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var nextRequestID: Int = 1
    private var pendingRequests: [Int: CheckedContinuation<MCPJSONRPCResponse, Error>] = [:]
    private let lock = NSLock()
    private var readTask: Task<Void, Never>?
    private var isStarted = false

    public init(config: MCPServerConfig) {
        self.config = config
    }

    public func start() async throws {
        guard case .stdio(let command, let args, let env) = config.transport else {
            throw MCPTransportError.transportMismatch
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = args
        if let env = env {
            process.environment = env
        }

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe

        try process.run()

        self.process = process
        self.stdinPipe = stdinPipe
        self.stdoutPipe = stdoutPipe
        self.isStarted = true

        startReadingStdout()
    }

    public func stop() async throws {
        readTask?.cancel()
        readTask = nil
        process?.terminate()
        process = nil
        stdinPipe = nil
        stdoutPipe = nil
        isStarted = false

        lock.lock()
        let pending = pendingRequests
        pendingRequests.removeAll()
        lock.unlock()

        for (_, continuation) in pending {
            continuation.resume(throwing: MCPTransportError.serverStopped)
        }
    }

    public func send(_ request: MCPJSONRPCRequest) async throws -> MCPJSONRPCResponse {
        guard isStarted, let pipe = stdinPipe else {
            throw MCPTransportError.notStarted
        }

        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let line = data + Data([0x0A])

        return try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            pendingRequests[request.id] = continuation
            lock.unlock()

            pipe.fileHandleForWriting.write(line)
        }
    }

    public func sendNotification(_ notification: MCPJSONRPCNotification) async throws {
        guard isStarted, let pipe = stdinPipe else {
            throw MCPTransportError.notStarted
        }

        let encoder = JSONEncoder()
        let data = try encoder.encode(notification)
        let line = data + Data([0x0A])
        pipe.fileHandleForWriting.write(line)
    }

    private func startReadingStdout() {
        guard let pipe = stdoutPipe else { return }

        readTask = Task.detached { [weak self] in
            let handle = pipe.fileHandleForReading
            var buffer = Data()

            while !Task.isCancelled {
                let available = handle.availableData
                if available.isEmpty { break }

                buffer.append(available)

                while let newlineIndex = buffer.firstIndex(of: 0x0A) {
                    let lineData = buffer[buffer.startIndex..<newlineIndex]
                    buffer = Data(buffer[buffer.index(after: newlineIndex)...])

                    guard !lineData.isEmpty else { continue }

                    if let response = try? JSONDecoder().decode(MCPJSONRPCResponse.self, from: lineData) {
                        self?.handleResponse(response)
                    }
                }
            }
        }
    }

    private func handleResponse(_ response: MCPJSONRPCResponse) {
        lock.lock()
        let continuation = pendingRequests.removeValue(forKey: response.id)
        lock.unlock()

        continuation?.resume(returning: response)
    }

    func getNextRequestID() -> Int {
        lock.lock()
        defer { lock.unlock() }
        let id = nextRequestID
        nextRequestID += 1
        return id
    }
}

// MARK: - MCP Transport Error

public enum MCPTransportError: Error, Sendable {
    case transportMismatch
    case notStarted
    case serverStopped
    case connectionFailed(String)
    case timeout
    case invalidResponse
}