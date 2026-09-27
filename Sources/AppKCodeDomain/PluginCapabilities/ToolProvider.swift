import Foundation
import AppKCodeInfrastructure

public protocol ToolProvider: PluginCapability {
    func availableTools() -> [String]
    func execute(tool: String, arguments: [String: AnyCodable]) async throws -> AnyCodable
}