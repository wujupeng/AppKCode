import Foundation
import AppKCodeShared
import CryptoKit

// MARK: - IPC Channel Protocol (TASK-005.1, H22)

public protocol IPCChannel: Sendable {
    var descriptor: IPCChannelDescriptor { get }
    var isConnected: Bool { get }

    func connect() async throws
    func disconnect() async throws
    func sendRequest(_ method: String, params: AnyCodableValue?) async throws -> IPCResponse
    func sendNotification(_ method: String, params: AnyCodableValue?) async throws
    func incomingMessages() -> AsyncStream<IPCMessage>
    func transferLargeData(_ data: Data) async throws -> FileTransferRef
    func receiveLargeData(_ ref: FileTransferRef) async throws -> Data
}

// MARK: - Stdio IPC Channel (TASK-005.2, based on Process stdin/stdout)

public final class StdioIPCChannel: IPCChannel, @unchecked Sendable {
    public let descriptor: IPCChannelDescriptor
    private let process: Process
    private let stdinPipe: Pipe
    private let stdoutPipe: Pipe
    private let lock = NSLock()
    private var _isConnected: Bool = false
    private var nextRequestID: Int64 = 1
    private var pendingRequests: [Int64: CheckedContinuation<IPCResponse, Error>] = [:]
    private var incomingContinuation: AsyncStream<IPCMessage>.Continuation?
    private let readQueue = DispatchQueue(label: "appk.ipc.read")

    public var isConnected: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isConnected
    }

    public init(process: Process, descriptor: IPCChannelDescriptor = IPCChannelDescriptor(kind: .stdio)) {
        self.process = process
        self.descriptor = descriptor
        self.stdinPipe = Pipe()
        self.stdoutPipe = Pipe()
    }

    public func connect() async throws {
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe

        lock.lock()
        _isConnected = true
        lock.unlock()

        startReadingStdout()
    }

    public func disconnect() async throws {
        lock.lock()
        _isConnected = false

        for (_, continuation) in pendingRequests {
            continuation.resume(throwing: ExtensionHostError.ipcChannelFailed)
        }
        pendingRequests.removeAll()
        lock.unlock()

        try? stdinPipe.fileHandleForWriting.close()
        try? stdoutPipe.fileHandleForReading.close()
    }

    public func sendRequest(_ method: String, params: AnyCodableValue?) async throws -> IPCResponse {
        lock.lock()
        let requestID = nextRequestID
        nextRequestID += 1
        lock.unlock()

        let message = IPCMessage(id: requestID, method: method, params: params)

        let data = try JSONEncoder().encode(message)
        let line = data + Data([0x0A])

        lock.lock()
        let isConnectedNow = _isConnected
        lock.unlock()
        if !isConnectedNow {
            throw ExtensionHostError.ipcChannelFailed
        }

        try stdinPipe.fileHandleForWriting.write(contentsOf: line)

        return try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            pendingRequests[requestID] = continuation
            lock.unlock()
        }
    }

    public func sendNotification(_ method: String, params: AnyCodableValue?) async throws {
        let message = IPCMessage(method: method, params: params)
        let data = try JSONEncoder().encode(message)
        let line = data + Data([0x0A])

        lock.lock()
        let isConnectedNow = _isConnected
        lock.unlock()
        if !isConnectedNow {
            throw ExtensionHostError.ipcChannelFailed
        }

        try stdinPipe.fileHandleForWriting.write(contentsOf: line)
    }

    public func incomingMessages() -> AsyncStream<IPCMessage> {
        AsyncStream { continuation in
            lock.lock()
            self.incomingContinuation = continuation
            lock.unlock()
        }
    }

    public func transferLargeData(_ data: Data) async throws -> FileTransferRef {
        let tempDir = NSTemporaryDirectory()
        let tempPath = (tempDir as NSString).appendingPathComponent("appk-transfer-\(UUID().uuidString)")
        try data.write(to: URL(fileURLWithPath: tempPath))

        let sha256 = SHA256Calculator.sha256(data)
        return FileTransferRef(path: tempPath, size: Int64(data.count), sha256: sha256)
    }

    public func receiveLargeData(_ ref: FileTransferRef) async throws -> Data {
        try Data(contentsOf: URL(fileURLWithPath: ref.path))
    }

    private func startReadingStdout() {
        readQueue.async { [weak self] in
            guard let self = self else { return }
            var buffer = Data()

            while true {
                let chunk = self.stdoutPipe.fileHandleForReading.availableData
                if chunk.isEmpty { break }

                buffer.append(chunk)

                while let newlineIndex = buffer.firstIndex(of: 0x0A) {
                    let lineData = buffer[buffer.startIndex..<newlineIndex]
                    buffer = Data(buffer[buffer.index(after: newlineIndex)...])

                    self.processLine(Data(lineData))
                }
            }
        }
    }

    private func processLine(_ lineData: Data) {
        guard let message = try? JSONDecoder().decode(IPCMessage.self, from: lineData) else {
            return
        }

        if message.isResponse, let id = message.id {
            lock.lock()
            let continuation = pendingRequests.removeValue(forKey: id)
            lock.unlock()

            if let continuation = continuation {
                let response = IPCResponse(id: id, result: message.result, error: message.error)
                continuation.resume(returning: response)
            }
        }

        if message.isNotification || message.isRequest {
            lock.lock()
            let continuation = incomingContinuation
            lock.unlock()
            continuation?.yield(message)
        }
    }
}

// MARK: - Named Pipe IPC Channel (TASK-005.6)

public final class NamedPipeIPCChannel: IPCChannel, @unchecked Sendable {
    public let descriptor: IPCChannelDescriptor
    private let lock = NSLock()
    private var _isConnected: Bool = false
    private var nextRequestID: Int64 = 1
    private var pipeFD: Int32 = -1

    public var isConnected: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isConnected
    }

    public init(pipePath: String) {
        self.descriptor = IPCChannelDescriptor(kind: .namedPipe, path: pipePath)
    }

    public func connect() async throws {
        lock.lock()
        _isConnected = true
        lock.unlock()
    }

    public func disconnect() async throws {
        lock.lock()
        _isConnected = false
        if pipeFD >= 0 {
            close(pipeFD)
            pipeFD = -1
        }
        lock.unlock()
    }

    public func sendRequest(_ method: String, params: AnyCodableValue?) async throws -> IPCResponse {
        throw ExtensionHostError.ipcChannelFailed
    }

    public func sendNotification(_ method: String, params: AnyCodableValue?) async throws {
    }

    public func incomingMessages() -> AsyncStream<IPCMessage> {
        AsyncStream { _ in }
    }

    public func transferLargeData(_ data: Data) async throws -> FileTransferRef {
        let tempDir = NSTemporaryDirectory()
        let tempPath = (tempDir as NSString).appendingPathComponent("appk-transfer-\(UUID().uuidString)")
        try data.write(to: URL(fileURLWithPath: tempPath))
        let sha256 = SHA256Calculator.sha256(data)
        return FileTransferRef(path: tempPath, size: Int64(data.count), sha256: sha256)
    }

    public func receiveLargeData(_ ref: FileTransferRef) async throws -> Data {
        try Data(contentsOf: URL(fileURLWithPath: ref.path))
    }
}

// MARK: - SHA256 Helper

enum SHA256Calculator {
    static func sha256(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}