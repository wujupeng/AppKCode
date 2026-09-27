import Foundation

public final class LSPTransport: @unchecked Sendable {
    private let processManager: LSPProcessManager
    private let codec: JSONRPCCodec
    private let lock = NSLock()

    public init(processManager: LSPProcessManager) {
        self.processManager = processManager
        self.codec = JSONRPCCodec()
    }

    public func send(_ message: JSONRPCMessage) throws {
        let data = try codec.encode(message)
        try processManager.writeToStdin(data)
    }

    public func sendRequest(id: Int64, method: String, params: AnyCodable? = nil) throws {
        let request = JSONRPCRequest(id: id, method: method, params: params)
        try send(.request(request))
    }

    public func sendNotification(method: String, params: AnyCodable? = nil) throws {
        let notification = JSONRPCNotification(method: method, params: params)
        try send(.notification(notification))
    }

    public func receive() async throws -> [JSONRPCMessage] {
        guard let data = await processManager.readFromStdout() else {
            return []
        }
        return codec.decode(data)
    }

    public func clearBuffer() {
        codec.clearBuffer()
    }
}