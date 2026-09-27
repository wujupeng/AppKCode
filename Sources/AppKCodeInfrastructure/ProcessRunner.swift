import Foundation
import AppKCodeShared

public final class ProcessRunner: @unchecked Sendable {
    public init() {}

    public func run(_ command: String, args: [String] = [], in cwd: URL? = nil) async throws -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command] + args
        if let cwd = cwd { process.currentDirectoryURL = cwd }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        return try await withCheckedThrowingContinuation { continuation in
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: AppKError.toolExecutionFailed(tool: command, cause: error.localizedDescription))
                return
            }

            DispatchQueue.global().async {
                process.waitUntilExit()
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""
                continuation.resume(returning: ProcessResult(stdout: stdout, stderr: stderr, exitCode: process.terminationStatus))
            }
        }
    }

    public func runStreaming(_ command: String, args: [String] = [], in cwd: URL? = nil,
                             onOutput: @escaping @Sendable (String) -> Void,
                             onError: @escaping @Sendable (String) -> Void) async throws -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command] + args
        if let cwd = cwd { process.currentDirectoryURL = cwd }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        return try await withCheckedThrowingContinuation { continuation in
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: AppKError.toolExecutionFailed(tool: command, cause: error.localizedDescription))
                return
            }

            DispatchQueue.global().async {
                while process.isRunning {
                    let stdoutData = stdoutPipe.fileHandleForReading.availableData
                    if !stdoutData.isEmpty, let str = String(data: stdoutData, encoding: .utf8) {
                        onOutput(str)
                    }
                    let stderrData = stderrPipe.fileHandleForReading.availableData
                    if !stderrData.isEmpty, let str = String(data: stderrData, encoding: .utf8) {
                        onError(str)
                    }
                    if stdoutData.isEmpty && stderrData.isEmpty { break }
                    Thread.sleep(forTimeInterval: 0.01)
                }
                process.waitUntilExit()
                let remainingStdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let remainingStderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                if !remainingStdout.isEmpty, let str = String(data: remainingStdout, encoding: .utf8) { onOutput(str) }
                if !remainingStderr.isEmpty, let str = String(data: remainingStderr, encoding: .utf8) { onError(str) }
                continuation.resume(returning: ProcessResult(
                    stdout: "",
                    stderr: "",
                    exitCode: process.terminationStatus
                ))
            }
        }
    }

    public func isInstalled(_ binary: String) async -> Bool {
        guard let result = try? await run("which", args: [binary]) else { return false }
        return result.exitCode == 0
    }
}