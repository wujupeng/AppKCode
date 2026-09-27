import Foundation
import AppKCodeShared

public protocol BuildService: AnyObject {
    var isRunning: Bool { get }

    func build(tool: BuildTool, configuration: BuildConfiguration, projectRoot: URL) -> AsyncStream<BuildEvent>
    func clean(tool: BuildTool, projectRoot: URL) async throws -> BuildResult
    func rebuild(tool: BuildTool, configuration: BuildConfiguration, projectRoot: URL) -> AsyncStream<BuildEvent>
    func run(executable: URL, arguments: [String], workingDirectory: URL?, environment: [String: String]) -> AsyncStream<RunEvent>
    func stop() async
}