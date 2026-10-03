import Foundation

// MARK: - IPC Message (TASK-001.3, REQ-032, JSON-RPC 2.0)

public struct IPCMessage: Sendable, Codable, Equatable {
    public let jsonrpc: String
    public let id: Int64?
    public let method: String?
    public let params: AnyCodableValue?
    public let result: AnyCodableValue?
    public let error: IPCError?

    public init(
        jsonrpc: String = "2.0",
        id: Int64? = nil,
        method: String? = nil,
        params: AnyCodableValue? = nil,
        result: AnyCodableValue? = nil,
        error: IPCError? = nil
    ) {
        self.jsonrpc = jsonrpc
        self.id = id
        self.method = method
        self.params = params
        self.result = result
        self.error = error
    }

    public var isRequest: Bool { id != nil && method != nil }
    public var isResponse: Bool { id != nil && (result != nil || error != nil) }
    public var isNotification: Bool { id == nil && method != nil }
}

// MARK: - IPC Error (TASK-001.4, REQ-035)

public struct IPCError: Sendable, Codable, Equatable {
    public let code: Int32
    public let message: String

    public init(code: Int32, message: String) {
        self.code = code
        self.message = message
    }

    public static let parseError = IPCError(code: -32700, message: "Parse error")
    public static let invalidRequest = IPCError(code: -32600, message: "Invalid Request")
    public static let methodNotFound = IPCError(code: -32601, message: "Method not found")
    public static let invalidParams = IPCError(code: -32602, message: "Invalid params")
    public static let internalError = IPCError(code: -32603, message: "Internal error")

    public static func serverError(code: Int32, message: String) -> IPCError {
        IPCError(code: code, message: message)
    }
}

// MARK: - IPC Response (TASK-001.4)

public struct IPCResponse: Sendable, Codable, Equatable {
    public let id: Int64
    public let result: AnyCodableValue?
    public let error: IPCError?

    public init(id: Int64, result: AnyCodableValue? = nil, error: IPCError? = nil) {
        self.id = id
        self.result = result
        self.error = error
    }

    public func toMessage() -> IPCMessage {
        IPCMessage(id: id, result: result, error: error)
    }
}

// MARK: - IPC Channel Descriptor (TASK-001.5)

public enum IPCChannelKind: String, Sendable, Codable, Hashable {
    case stdio
    case namedPipe
}

public struct IPCChannelDescriptor: Sendable, Codable, Hashable {
    public let kind: IPCChannelKind
    public let path: String?

    public init(kind: IPCChannelKind, path: String? = nil) {
        self.kind = kind
        self.path = path
    }
}

// MARK: - File Transfer Ref (TASK-001.6, REQ-034)

public struct FileTransferRef: Sendable, Codable, Hashable {
    public let path: String
    public let size: Int64
    public let sha256: String

    public init(path: String, size: Int64, sha256: String) {
        self.path = path
        self.size = size
        self.sha256 = sha256
    }
}