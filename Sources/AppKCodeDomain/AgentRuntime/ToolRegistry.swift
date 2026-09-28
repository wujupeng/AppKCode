import Foundation
import AppKCodeShared

// MARK: - Tool Registry (TASK-012)

public enum ToolRegistryError: Error, Sendable {
    case duplicateRegistration(ToolID)
    case toolNotFound(ToolID)
}

public final class ToolRegistry: @unchecked Sendable {
    private var tools: [ToolID: AgentTool] = [:]
    private let lock = NSLock()

    public init() {}

    public func register(_ tool: AgentTool) throws {
        lock.lock()
        defer { lock.unlock() }
        let id = tool.schema.id
        if tools[id] != nil {
            throw ToolRegistryError.duplicateRegistration(id)
        }
        tools[id] = tool
    }

    public func resolve(_ id: ToolID) -> AgentTool? {
        lock.lock()
        defer { lock.unlock() }
        return tools[id]
    }

    public func schema(_ id: ToolID) -> ToolSchema? {
        lock.lock()
        defer { lock.unlock() }
        return tools[id]?.schema
    }

    public func listAll() -> [ToolSchema] {
        lock.lock()
        defer { lock.unlock() }
        return tools.values.map { $0.schema }.sorted { $0.id.rawValue < $1.id.rawValue }
    }

    public func listByPermission(_ permission: ToolPermission) -> [ToolSchema] {
        lock.lock()
        defer { lock.unlock() }
        return tools.values
            .filter { $0.schema.permission == permission }
            .map { $0.schema }
            .sorted { $0.id.rawValue < $1.id.rawValue }
    }

    public func listByCategory(_ category: ToolCategory) -> [ToolSchema] {
        lock.lock()
        defer { lock.unlock() }
        return tools.values
            .filter { $0.schema.category == category }
            .map { $0.schema }
            .sorted { $0.id.rawValue < $1.id.rawValue }
    }
}