import Foundation
import AppKCodeShared
import AppKCodeInfrastructure

// MARK: - MCP Tool Adapter (TASK-015, H15)
// Adapts MCP Tool to M7 AgentTool protocol.
// H15: All calls go through MCPToolInvocation, not directly to transport/process.
// H13: Tool Isolation - MCP Tool does not directly access Process/Transport.

public final class MCPToolAdapter: AgentTool, @unchecked Sendable {
    public let schema: ToolSchema
    private let serverID: MCPServerID
    private let descriptor: MCPToolDescriptor
    private let invocation: MCPToolInvocation

    public init(serverID: MCPServerID, descriptor: MCPToolDescriptor, schema: ToolSchema, invocation: MCPToolInvocation) {
        self.serverID = serverID
        self.descriptor = descriptor
        self.schema = schema
        self.invocation = invocation
    }

    public func validate(arguments: ToolArguments) -> ValidationResult {
        var missingFields: [String] = []
        for requiredField in descriptor.inputSchema.required {
            if arguments.values[requiredField] == nil {
                missingFields.append(requiredField)
            }
        }
        if !missingFields.isEmpty {
            return .invalid(reason: "Missing required fields: \(missingFields.joined(separator: ", "))", missingFields: missingFields)
        }
        return .valid
    }

    public func execute(arguments: ToolArguments, session: AgentSessionID) async throws -> ToolOutput {
        var mcpArgs: [String: AnyCodableValue] = [:]
        for (key, value) in arguments.values {
            mcpArgs[key] = toolValueToAnyCodable(value)
        }

        let request = MCPToolInvocationRequest(
            serverID: serverID,
            toolName: descriptor.name,
            arguments: mcpArgs
        )

        let result = try await invocation.invoke(request)

        switch result {
        case .success(let content, let isError):
            if isError {
                let errorText = content.compactMap { if case .text(let t) = $0 { return t } else { return nil } }.joined(separator: "\n")
                throw MCPError(code: -1, message: errorText)
            }
            let textParts = content.compactMap { if case .text(let t) = $0 { return t } else { return nil } }
            let text = textParts.joined(separator: "\n")
            return ToolOutput(text: text)
        case .failure(let error):
            throw error
        }
    }

    private func toolValueToAnyCodable(_ value: ToolValue) -> AnyCodableValue {
        switch value {
        case .string(let v): return .string(v)
        case .integer(let v): return .int(v)
        case .boolean(let v): return .bool(v)
        case .filePath(let v): return .string(v.path)
        case .url(let v): return .string(v.absoluteString)
        case .array(let v): return .array(v.map { toolValueToAnyCodable($0) })
        }
    }
}