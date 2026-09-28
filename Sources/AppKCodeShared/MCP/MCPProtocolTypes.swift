import Foundation

// MARK: - AnyCodableValue (TASK-002.5)
// General-purpose JSON value wrapper supporting dynamic JSON parameters in MCP protocol

public indirect enum AnyCodableValue: Sendable, Codable, Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([AnyCodableValue])
    case object([String: AnyCodableValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let v = try? container.decode(Bool.self) {
            self = .bool(v)
        } else if let v = try? container.decode(Int.self) {
            self = .int(v)
        } else if let v = try? container.decode(Double.self) {
            self = .double(v)
        } else if let v = try? container.decode(String.self) {
            self = .string(v)
        } else if let v = try? container.decode([AnyCodableValue].self) {
            self = .array(v)
        } else if let v = try? container.decode([String: AnyCodableValue].self) {
            self = .object(v)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSON value"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let v):
            try container.encode(v)
        case .int(let v):
            try container.encode(v)
        case .double(let v):
            try container.encode(v)
        case .string(let v):
            try container.encode(v)
        case .array(let v):
            try container.encode(v)
        case .object(let v):
            try container.encode(v)
        }
    }
}

// MARK: - MCP Client Info (TASK-002.1)

public struct MCPClientInfo: Sendable, Codable, Equatable {
    public let name: String
    public let version: String

    public init(name: String, version: String) {
        self.name = name
        self.version = version
    }
}

public struct MCPClientCapabilities: Sendable, Codable, Equatable {
    public let sampling: Bool
    public let roots: Bool

    public init(sampling: Bool = false, roots: Bool = false) {
        self.sampling = sampling
        self.roots = roots
    }
}

// MARK: - MCP Server Info (TASK-002.1)

public struct MCPServerInfo: Sendable, Codable, Equatable {
    public let name: String
    public let version: String

    public init(name: String, version: String) {
        self.name = name
        self.version = version
    }
}

public struct MCPServerCapabilities: Sendable, Codable, Equatable {
    public let tools: Bool
    public let resources: Bool
    public let prompts: Bool

    public init(tools: Bool = false, resources: Bool = false, prompts: Bool = false) {
        self.tools = tools
        self.resources = resources
        self.prompts = prompts
    }
}

// MARK: - MCP Initialize Request/Response (TASK-002.1)

public struct MCPInitializeRequest: Sendable, Codable, Equatable {
    public let protocolVersion: String
    public let clientInfo: MCPClientInfo
    public let capabilities: MCPClientCapabilities

    public init(protocolVersion: String, clientInfo: MCPClientInfo, capabilities: MCPClientCapabilities) {
        self.protocolVersion = protocolVersion
        self.clientInfo = clientInfo
        self.capabilities = capabilities
    }
}

public struct MCPInitializeResponse: Sendable, Codable, Equatable {
    public let protocolVersion: String
    public let serverInfo: MCPServerInfo
    public let capabilities: MCPServerCapabilities

    public init(protocolVersion: String, serverInfo: MCPServerInfo, capabilities: MCPServerCapabilities) {
        self.protocolVersion = protocolVersion
        self.serverInfo = serverInfo
        self.capabilities = capabilities
    }
}

// MARK: - MCP List Tools/Resources Responses (TASK-002.2)

public struct MCPListToolsResponse: Sendable, Codable, Equatable {
    public let tools: [MCPToolDescriptor]

    public init(tools: [MCPToolDescriptor]) {
        self.tools = tools
    }
}

public struct MCPListResourcesResponse: Sendable, Codable, Equatable {
    public let resources: [MCPResourceDescriptor]

    public init(resources: [MCPResourceDescriptor]) {
        self.resources = resources
    }
}

// MARK: - MCP Call Tool Request/Response (TASK-002.3)

public struct MCPCallToolRequest: Sendable, Codable, Equatable {
    public let name: String
    public let arguments: [String: AnyCodableValue]

    public init(name: String, arguments: [String: AnyCodableValue] = [:]) {
        self.name = name
        self.arguments = arguments
    }
}

public struct MCPCallToolResponse: Sendable, Codable, Equatable {
    public let content: [MCPContent]
    public let isError: Bool

    public init(content: [MCPContent], isError: Bool = false) {
        self.content = content
        self.isError = isError
    }
}

// MARK: - MCP Notification (TASK-002.4)

public enum MCPNotification: Sendable, Codable, Equatable {
    case toolsListChanged
    case resourcesListChanged
    case progress(token: String, progress: Double, total: Double?)
}

// MARK: - MCP JSON-RPC 2.0 Message Types
// Prefixed with MCP to avoid conflict with M3 LSP JSON-RPC types in Infrastructure

public struct MCPJSONRPCRequest: Sendable, Codable, Equatable {
    public let jsonrpc: String
    public let id: Int
    public let method: String
    public let params: AnyCodableValue?

    public init(id: Int, method: String, params: AnyCodableValue? = nil) {
        self.jsonrpc = "2.0"
        self.id = id
        self.method = method
        self.params = params
    }
}

public struct MCPJSONRPCResponse: Sendable, Codable, Equatable {
    public let jsonrpc: String
    public let id: Int
    public let result: AnyCodableValue?
    public let error: MCPJSONRPCError?

    public init(id: Int, result: AnyCodableValue? = nil, error: MCPJSONRPCError? = nil) {
        self.jsonrpc = "2.0"
        self.id = id
        self.result = result
        self.error = error
    }
}

public struct MCPJSONRPCError: Sendable, Codable, Equatable {
    public let code: Int
    public let message: String
    public let data: AnyCodableValue?

    public init(code: Int, message: String, data: AnyCodableValue? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }
}

public struct MCPJSONRPCNotification: Sendable, Codable, Equatable {
    public let jsonrpc: String
    public let method: String
    public let params: AnyCodableValue?

    public init(method: String, params: AnyCodableValue? = nil) {
        self.jsonrpc = "2.0"
        self.method = method
        self.params = params
    }
}
