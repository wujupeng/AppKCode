import Foundation

// MARK: - MCP Server ID (TASK-001.1)

public struct MCPServerID: Hashable, Sendable, Codable {
    public let rawValue: String
    public init() { self.rawValue = UUID().uuidString }
    public init(_ value: String) { self.rawValue = value }
}

// MARK: - MCP Transport (TASK-001.1)

public enum MCPTransport: Sendable, Codable, Equatable {
    case stdio(command: String, args: [String], env: [String: String]?)
    case http(endpoint: URL)
    case sse(endpoint: URL)
}

// MARK: - MCP Server Config (TASK-001.2)

public struct MCPServerConfig: Sendable, Codable, Equatable {
    public let id: MCPServerID
    public let name: String
    public let transport: MCPTransport
    public let enabled: Bool
    public let autoDiscoverTools: Bool
    public let timeoutSeconds: Int

    public init(
        id: MCPServerID = MCPServerID(),
        name: String,
        transport: MCPTransport,
        enabled: Bool = true,
        autoDiscoverTools: Bool = true,
        timeoutSeconds: Int = 30
    ) {
        self.id = id
        self.name = name
        self.transport = transport
        self.enabled = enabled
        self.autoDiscoverTools = autoDiscoverTools
        self.timeoutSeconds = timeoutSeconds
    }
}

// MARK: - MCP Connection State (TASK-001.3)

public enum MCPConnectionState: Sendable, Codable, Equatable {
    case disconnected
    case connecting
    case connected
    case disconnectedUnexpectedly(reason: String)
    case failed(error: String)
}

// MARK: - MCP Tool Annotations (TASK-001.4)

public struct MCPToolAnnotations: Sendable, Codable, Equatable {
    public let readOnlyHint: Bool?
    public let destructiveHint: Bool?

    public init(readOnlyHint: Bool? = nil, destructiveHint: Bool? = nil) {
        self.readOnlyHint = readOnlyHint
        self.destructiveHint = destructiveHint
    }
}

// MARK: - MCP Tool Descriptor (TASK-001.4)

public struct MCPToolDescriptor: Sendable, Codable, Equatable {
    public let name: String
    public let description: String
    public let inputSchema: JSONSchema
    public let annotations: MCPToolAnnotations?

    public init(name: String, description: String, inputSchema: JSONSchema, annotations: MCPToolAnnotations? = nil) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
        self.annotations = annotations
    }
}

// MARK: - MCP Resource Descriptor (TASK-001.5)

public struct MCPResourceDescriptor: Sendable, Codable, Equatable {
    public let uri: String
    public let name: String
    public let description: String?
    public let mimeType: String?

    public init(uri: String, name: String, description: String? = nil, mimeType: String? = nil) {
        self.uri = uri
        self.name = name
        self.description = description
        self.mimeType = mimeType
    }
}

// MARK: - MCP Content (TASK-001.6)

public enum MCPContent: Sendable, Codable, Equatable {
    case text(String)
    case image(data: Data, mimeType: String)
    case resource(uri: String)
}

// MARK: - MCP Tool Invocation Request (TASK-001.6)

public struct MCPToolInvocationRequest: Sendable, Codable, Equatable {
    public let serverID: MCPServerID
    public let toolName: String
    public let arguments: [String: AnyCodableValue]

    public init(serverID: MCPServerID, toolName: String, arguments: [String: AnyCodableValue] = [:]) {
        self.serverID = serverID
        self.toolName = toolName
        self.arguments = arguments
    }
}

// MARK: - MCP Tool Invocation Result (TASK-001.6)

public enum MCPToolInvocationResult: Sendable, Codable, Equatable {
    case success(content: [MCPContent], isError: Bool)
    case failure(error: MCPError)
}

// MARK: - MCP Error (TASK-001.7)

public struct MCPError: Error, Sendable, Codable, Equatable {
    public let code: Int
    public let message: String
    public let data: AnyCodableValue?

    public init(code: Int, message: String, data: AnyCodableValue? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }
}

public enum MCPErrorCode: Int, Sendable, Codable, Equatable {
    case parseError = -32700
    case invalidRequest = -32600
    case methodNotFound = -32601
    case invalidParams = -32602
    case internalError = -32603
}