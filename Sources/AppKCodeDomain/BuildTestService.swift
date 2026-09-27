import Foundation
import AppKCodeShared
import AppKCodeInfrastructure

public final class BuildTestService: @unchecked Sendable {
    private let processRunner: ProcessRunner

    public init(processRunner: ProcessRunner = ProcessRunner()) {
        self.processRunner = processRunner
    }

    public func detectBuildTool(at url: URL) -> BuildTool? {
        for tool in [BuildTool.swiftBuild, .xcodebuild, .cmake, .make, .goBuild] {
            let markerPath = url.appendingPathComponent(tool.markerFile).path
            if FileManager.default.fileExists(atPath: markerPath) {
                return tool
            }
            if tool == .xcodebuild {
                let xcodeDirs = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
                if xcodeDirs.contains(where: { $0.hasSuffix(".xcodeproj") || $0.hasSuffix(".xcworkspace") }) {
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
}