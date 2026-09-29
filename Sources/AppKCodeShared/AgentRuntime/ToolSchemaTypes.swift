import Foundation

// MARK: - Tool ID (TASK-003.1)

public struct ToolID: Hashable, Sendable, Codable {
    public let rawValue: String
    public init(_ value: String) { self.rawValue = value }
}

// MARK: - Tool Category (TASK-003.1)

public enum ToolCategory: String, Sendable, Codable {
    case fileRead
    case fileWrite
    case command
    case git
    case buildTest
    case context
    case search
    case mcp
    case skill
    case extension_
    case adapter
}

// MARK: - Tool Permission (TASK-003.2)

public enum ToolPermission: String, Sendable, Codable {
    case readOnly
    case low
    case high
}

// MARK: - Tool Parameter Type (TASK-003.3)

public indirect enum ToolParameterType: Sendable, Codable, Equatable {
    case string
    case integer
    case boolean
    case filePath
    case url
    case array(of: ToolParameterType)
    case object
}

// MARK: - Tool Value (TASK-003.5)

public indirect enum ToolValue: Sendable, Codable, Equatable {
    case string(String)
    case integer(Int)
    case boolean(Bool)
    case filePath(URL)
    case url(URL)
    case array([ToolValue])
}

// MARK: - Tool Parameter Schema (TASK-003.3)

public struct ToolParameterSchema: Sendable, Codable, Equatable {
    public let name: String
    public let type: ToolParameterType
    public let required: Bool
    public let description: String
    public let defaultValue: ToolValue?

    public init(name: String, type: ToolParameterType, required: Bool, description: String, defaultValue: ToolValue? = nil) {
        self.name = name
        self.type = type
        self.required = required
        self.description = description
        self.defaultValue = defaultValue
    }
}

// MARK: - Tool Schema (TASK-003.4)

public struct ToolSchema: Sendable, Codable, Equatable {
    public let id: ToolID
    public let category: ToolCategory
    public let permission: ToolPermission
    public let parameters: [ToolParameterSchema]
    public let returnType: ToolParameterType
    public let description: String
    public let version: String

    public init(id: ToolID, category: ToolCategory, permission: ToolPermission, parameters: [ToolParameterSchema], returnType: ToolParameterType, description: String, version: String) {
        self.id = id
        self.category = category
        self.permission = permission
        self.parameters = parameters
        self.returnType = returnType
        self.description = description
        self.version = version
    }
}

// MARK: - Tool Arguments (TASK-003.5)

public struct ToolArguments: Sendable, Codable, Equatable {
    public let values: [String: ToolValue]

    public init(values: [String: ToolValue] = [:]) {
        self.values = values
    }

    public func string(_ key: String) -> String? {
        if case .string(let v) = values[key] { return v }
        return nil
    }

    public func integer(_ key: String) -> Int? {
        if case .integer(let v) = values[key] { return v }
        return nil
    }

    public func boolean(_ key: String) -> Bool? {
        if case .boolean(let v) = values[key] { return v }
        return nil
    }

    public func filePath(_ key: String) -> URL? {
        if case .filePath(let v) = values[key] { return v }
        return nil
    }

    public func url(_ key: String) -> URL? {
        if case .url(let v) = values[key] { return v }
        return nil
    }

    public func array(_ key: String) -> [ToolValue]? {
        if case .array(let v) = values[key] { return v }
        return nil
    }
}