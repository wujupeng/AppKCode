import Foundation

public protocol WorkspaceProvider: PluginCapability {
    func workspaceRoot() -> URL?
    func findFiles(pattern: String) async throws -> [URL]
    func readFile(_ url: URL) async throws -> String
    func writeFile(_ url: URL, content: String) async throws
}