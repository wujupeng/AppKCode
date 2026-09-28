import Foundation
import AppKCodeShared
import AppKCodeInfrastructure

// MARK: - MCP Tool Invocation (TASK-016)

public final class MCPToolInvocation: @unchecked Sendable {
    private let processManager: MCPServerProcessManager

    public init(processManager: MCPServerProcessManager) {
        self.processManager = processManager
    }

    public func invoke(_ request: MCPToolInvocationRequest) async throws -> MCPToolInvocationResult {
        guard let transport = processManager.getTransport(request.serverID) else {
            return .failure(error: MCPError(code: -1, message: "Server not found"))
        }

        let argsObject = request.arguments.reduce(into: [String: AnyCodableValue]()) { dict, pair in
            dict[pair.key] = pair.value
        }

        let rpcRequest = MCPJSONRPCRequest(
            id: 1,
            method: "tools/call",
            params: .object([
                "name": .string(request.toolName),
                "arguments": .object(argsObject)
            ])
        )

        let response: MCPJSONRPCResponse
        do {
            response = try await transport.send(rpcRequest)
        } catch {
            return .failure(error: MCPError(code: -1, message: "Transport error: \(error.localizedDescription)"))
        }

        if let error = response.error {
            return .failure(error: MCPError(code: error.code, message: error.message, data: error.data))
        }

        guard let resultData = response.result,
              case .object(let dict) = resultData else {
            return .success(content: [], isError: false)
        }

        var isError = false
        if case .bool(let v) = dict["isError"] { isError = v }
        let content = parseContent(dict["content"])

        return .success(content: content, isError: isError)
    }

    private func parseContent(_ value: AnyCodableValue?) -> [MCPContent] {
        guard case .array(let items) = value else { return [] }
        return items.compactMap { item in
            guard case .object(let dict) = item else { return nil }
            if case .string(let text) = dict["text"] {
                return .text(text)
            }
            return nil
        }
    }
}