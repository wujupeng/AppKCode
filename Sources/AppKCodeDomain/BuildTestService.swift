import Foundation
import AppKCodeShared
import AppKCodeInfrastructure

public final class BuildTestService: BuildService, TestService, @unchecked Sendable {
    private let processRunner: ProcessRunner
    private let outputParser: BuildOutputParser
    private var currentProcess: Process? = nil
    private let lock = NSLock()

    public init(processRunner: ProcessRunner = ProcessRunner()) {
        self.processRunner = processRunner
        self.outputParser = BuildOutputParser()
    }

    public var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return currentProcess?.isRunning ?? false
    }

    public func detectBuildTool(at url: URL) -> BuildTool? {
        for tool in [BuildTool.swiftBuild, .xcodebuild, .cmake, .make, .goBuild] {
            let markerPath = url.appendingPathComponent(tool.markerFile).path
            if FileManager.default.fileExists(atPath: markerPath) {
                return tool
            }
            if tool == .xcodebuild {
                let xcodeDirs = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
                if xcodeDirs.contains(where: { $0.lastPathComponent.hasSuffix(".xcodeproj") || $0.lastPathComponent.hasSuffix(".xcworkspace") }) {
                    return .xcodebuild
                }
            }
        }
        return nil
    }

    public func runBuild(tool: BuildTool, at url: URL) async throws -> BuildResult {
        guard await processRunner.isInstalled(tool.binaryName) else {
            throw AppKError.toolExecutionFailed(tool: tool.binaryName, cause: "未找到 \(tool.binaryName)，请先安装")
        }
        let cmdParts = tool.buildCommand.split(separator: " ").map(String.init)
        let binary = cmdParts[0]
        let args = Array(cmdParts.dropFirst())
        let result = try await processRunner.run(binary, args: args, in: url)
        return BuildResult(success: result.exitCode == 0, output: result.stdout + result.stderr, tool: tool)
    }

    public func runTest(tool: BuildTool, at url: URL) async throws -> TestReport {
        guard await processRunner.isInstalled(tool.binaryName) else {
            throw AppKError.toolExecutionFailed(tool: tool.binaryName, cause: "未找到 \(tool.binaryName)，请先安装")
        }
        let cmdParts = tool.testCommand.split(separator: " ").map(String.init)
        let binary = cmdParts[0]
        let args = Array(cmdParts.dropFirst())
        let result = try await processRunner.run(binary, args: args, in: url)
        return TestReportParser.parse(output: result.stdout + result.stderr, exitCode: result.exitCode)
    }

    public func build(tool: BuildTool, configuration: BuildConfiguration, projectRoot: URL) -> AsyncStream<BuildEvent> {
        let command = Command.build(tool: tool, configuration: configuration, projectRoot: projectRoot)
        return buildStream(command, tool: tool)
    }

    public func rebuild(tool: BuildTool, configuration: BuildConfiguration, projectRoot: URL) -> AsyncStream<BuildEvent> {
        AsyncStream { continuation in
            Task { [weak self] in
                guard let self = self else { continuation.finish(); return }
                continuation.yield(.started(command: "clean + build"))
                do {
                    _ = try await self.clean(tool: tool, projectRoot: projectRoot)
                } catch {
                    continuation.yield(.stderr("Clean failed: \(error.localizedDescription)"))
                }
                let buildStream = self.build(tool: tool, configuration: configuration, projectRoot: projectRoot)
                for await event in buildStream {
                    continuation.yield(event)
                }
                continuation.finish()
            }
        }
    }

    public func clean(tool: BuildTool, projectRoot: URL) async throws -> BuildResult {
        let command = Command.clean(tool: tool, projectRoot: projectRoot)
        let result = try await processRunner.run(command)
        return BuildResult(success: result.exitCode == 0, output: result.stdout + result.stderr, tool: tool)
    }

    public func run(executable: URL, arguments: [String], workingDirectory: URL?, environment: [String: String]) -> AsyncStream<RunEvent> {
        let command = Command.run(executable: executable, arguments: arguments, workingDirectory: workingDirectory, environment: environment)
        return AsyncStream { continuation in
            continuation.yield(.started(command: command.commandLine))
            Task { [weak self] in
                guard let self = self else { continuation.finish(); return }
                let stream = self.processRunner.runStreaming(command)
                for await output in stream {
                    switch output {
                    case .stdout(let s): continuation.yield(.stdout(s))
                    case .stderr(let s): continuation.yield(.stderr(s))
                    case .exit(let code): continuation.yield(.exited(code: code))
                    }
                }
                continuation.finish()
            }
        }
    }

    public func runTests(tool: BuildTool, configuration: BuildConfiguration, projectRoot: URL) -> AsyncStream<TestEvent> {
        let command = Command.test(tool: tool, configuration: configuration, projectRoot: projectRoot)
        return AsyncStream { continuation in
            continuation.yield(.started(command: command.commandLine))
            Task { [weak self] in
                guard let self = self else { continuation.finish(); return }
                var outputBuffer = ""
                let stream = self.processRunner.runStreaming(command)
                for await output in stream {
                    switch output {
                    case .stdout(let s):
                        continuation.yield(.stdout(s))
                        outputBuffer += s
                    case .stderr(let s):
                        continuation.yield(.stderr(s))
                        outputBuffer += s
                    case .exit(let code):
                        let report = TestReportParser.parse(output: outputBuffer, exitCode: code)
                        continuation.yield(.completed(report: report))
                    }
                }
                continuation.finish()
            }
        }
    }

    public func stop() async {
        lock.lock()
        let proc = currentProcess
        lock.unlock()
        proc?.terminate()
    }

    private func buildStream(_ command: Command, tool: BuildTool) -> AsyncStream<BuildEvent> {
        AsyncStream { continuation in
            continuation.yield(.started(command: command.commandLine))
            Task { [weak self] in
                guard let self = self else { continuation.finish(); return }
                var outputBuffer = ""
                let stream = self.processRunner.runStreaming(command)
                for await output in stream {
                    switch output {
                    case .stdout(let s):
                        continuation.yield(.stdout(s))
                        outputBuffer += s
                        let problems = self.outputParser.parse(s)
                        for p in problems { continuation.yield(.problem(p)) }
                    case .stderr(let s):
                        continuation.yield(.stderr(s))
                        outputBuffer += s
                        let problems = self.outputParser.parse(s)
                        for p in problems { continuation.yield(.problem(p)) }
                    case .exit(let code):
                        let result = BuildResult(success: code == 0, output: outputBuffer, tool: tool)
                        continuation.yield(.completed(result: result))
                    }
                }
                continuation.finish()
            }
        }
    }
}
