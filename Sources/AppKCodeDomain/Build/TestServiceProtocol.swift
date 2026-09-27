import Foundation
import AppKCodeShared

public protocol TestService: AnyObject {
    var isRunning: Bool { get }

    func runTests(tool: BuildTool, configuration: BuildConfiguration, projectRoot: URL) -> AsyncStream<TestEvent>
    func stop() async
}