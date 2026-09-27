import Foundation
import AppKCodeInfrastructure

public protocol CommandProvider: PluginCapability {
    func availableCommands() -> [String]
    func execute(command: String, arguments: [String: AnyCodable]) async throws -> AnyCodable
}