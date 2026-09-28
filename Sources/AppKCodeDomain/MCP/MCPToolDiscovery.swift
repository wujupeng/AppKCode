import Foundation
import AppKCodeShared
import AppKCodeInfrastructure

// MARK: - MCP Tool Discovery (TASK-013)

public final class MCPToolDiscovery: @unchecked Sendable {
    private let processManager: MCPServerProcessManager

    public init(processManager: MCPServerProcessManager) {
        self.processManager = processManager
    }

    public func discoverTools(serverID: MCPServerID) async throws -> [MCPToolDescriptor] {
        guard let transport = processManager.getTransport(serverID) else {
            throw MCPHostError.serverNotRegistered(serverID)
        }

        let request = MCPJSONRPCRequest(id: 1, method: "tools/list", params: nil)
        let response = try await transport.send(request)

        if let error = response.error {
            throw MCPHostError.discoveryFailed(serverID, error.message)
        }

        guard let resultData = response.result,
              case .object(let dict) = resultData,
              case .array(let toolsArray) = dict["tools"] else {
            return []
        }

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        return toolsArray.compactMap { toolValue in
            guard let data = try? encoder.encode(toolValue) else { return nil }
            return try? decoder.decode(MCPToolDescriptor.self, from: data)
        }
    }

    public func convertToToolSchema(_ descriptor: MCPToolDescriptor, serverID: MCPServerID, serverName: String) -> ToolSchema {
        let toolID = ToolID("mcp.\(serverName).\(descriptor.name)")
        let permission: ToolPermission
        if descriptor.annotations?.readOnlyHint == true {
            permission = .readOnly
        } else {
            permission = .high
        }

        let params = descriptor.inputSchema.properties.map { (name, prop) in
            ToolParameterSchema(
                name: name,
                type: mapSchemaType(prop.type),
                required: descriptor.inputSchema.required.contains(name),
                description: prop.description ?? ""
            )
        }

        return ToolSchema(
            id: toolID,
            category: .mcp,
            permission: permission,
            parameters: params,
            returnType: .object,
            description: descriptor.description,
            version: "1.0"
        )
    }

    public func discoverAndRegister(
        serverID: MCPServerID,
        serverName: String,
        registry: ToolRegistry,
        adapterFactory: (MCPServerID, MCPToolDescriptor, ToolSchema) -> AgentTool
    ) async throws -> [ToolID] {
        let descriptors = try await discoverTools(serverID: serverID)
        var registeredIDs: [ToolID] = []

        for descriptor in descriptors {
            let schema = convertToToolSchema(descriptor, serverID: serverID, serverName: serverName)
            let adapter = adapterFactory(serverID, descriptor, schema)
            do {
                try registry.register(adapter)
                registeredIDs.append(schema.id)
            } catch {
                continue
            }
        }

        return registeredIDs
    }

    private func mapSchemaType(_ type: String) -> ToolParameterType {
        switch type {
        case "string": return .string
        case "integer": return .integer
        case "boolean": return .boolean
        case "array": return .array(of: .string)
        case "object": return .object
        default: return .string
        }
    }
}