import Foundation
import AppKCodeShared
import AppKCodeInfrastructure

// MARK: - MCP Resource Discovery (TASK-014)

public final class MCPResourceDiscovery: @unchecked Sendable {
    private let processManager: MCPServerProcessManager

    public init(processManager: MCPServerProcessManager) {
        self.processManager = processManager
    }

    public func discoverResources(serverID: MCPServerID) async throws -> [MCPResourceDescriptor] {
        guard let transport = processManager.getTransport(serverID) else {
            throw MCPHostError.serverNotRegistered(serverID)
        }

        let request = MCPJSONRPCRequest(id: 1, method: "resources/list", params: nil)
        let response = try await transport.send(request)

        if let error = response.error {
            throw MCPHostError.discoveryFailed(serverID, error.message)
        }

        guard let resultData = response.result,
              case .object(let dict) = resultData,
              case .array(let resourcesArray) = dict["resources"] else {
            return []
        }

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        return resourcesArray.compactMap { resourceValue in
            guard let data = try? encoder.encode(resourceValue) else { return nil }
            return try? decoder.decode(MCPResourceDescriptor.self, from: data)
        }
    }

    public func readResource(serverID: MCPServerID, uri: String) async throws -> MCPContent {
        guard let transport = processManager.getTransport(serverID) else {
            throw MCPHostError.serverNotRegistered(serverID)
        }

        let params = AnyCodableValue.object(["uri": .string(uri)])
        let request = MCPJSONRPCRequest(id: 1, method: "resources/read", params: params)
        let response = try await transport.send(request)

        if let error = response.error {
            throw MCPError(code: error.code, message: error.message)
        }

        guard let resultData = response.result,
              case .object(let dict) = resultData,
              case .array(let contentsArray) = dict["contents"],
              let firstContent = contentsArray.first,
              case .object(let contentDict) = firstContent,
              case .string(let text) = contentDict["text"] else {
            return .text("")
        }

        return .text(text)
    }
}