import Foundation
import AppKCodeShared

public final class ProcessRunner: @unchecked Sendable {
    public init() {}

    public func run(_ command: Command) async throws -> ProcessResult {
        let process = Process()
        try configure(process, command)

        let tmpDir = FileManager.default.temporaryDirectory
        let stdoutPath = tmpDir.appendingPathComponent("appk-stdout-\(UUID().uuidString)")
        let stderrPath = tmpDir.appendingPathComponent("appk-stderr-\(UUID().uuidString)")

        FileManager.default.createFile(atPath: stdoutPath.path, contents: nil)
        FileManager.default.createFile(atPath: stderrPath.path, contents: nil)

        let stdoutHandle = try FileHandle(forWritingTo: stdoutPath)
        let stderrHandle = try FileHandle(forWritingTo: stderrPath)
        process.standardOutput = stdoutHandle
        process.standardError = stderrHandle

        return try await withCheckedThrowingContinuation { continuation in
            do {
                try process.run()
            } catch {
                try? stdoutHandle.close()
                try? stderrHandle.close()
                try? FileManager.default.removeItem(at: stdoutPath)
                try? FileManager.default.removeItem(at: stderrPath)
                continuation.resume(throwing: AppKError.toolExecutionFailed(tool: command.executable, cause: error.localizedDescription))
                return
            }

            DispatchQueue.global().async {
                process.waitUntilExit()
                try? stdoutHandle.close()
                try? stderrHandle.close()

                let stdoutData = (try? Data(contentsOf: stdoutPath)) ?? Data()
                let stderrData = (try? Data(contentsOf: stderrPath)) ?? Data()
                try? FileManager.default.removeItem(at: stdoutPath)
                try? FileManager.default.removeItem(at: stderrPath)

                let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""
                continuation.resume(returning: ProcessResult(stdout: stdout, stderr: stderr, exitCode: process.terminationStatus))
            }
        }
    }

    public func runWithStdin(_ command: Command, stdin: String) async throws -> ProcessResult {
        let process = Process()
        try configure(process, command)

        let stdinPipe = Pipe()
        process.standardInput = stdinPipe

        let tmpDir = FileManager.default.temporaryDirectory
        let stdoutPath = tmpDir.appendingPathComponent("appk-stdin-stdout-\(UUID().uuidString)")
        let stderrPath = tmpDir.appendingPathComponent("appk-stdin-stderr-\(UUID().uuidString)")
        FileManager.default.createFile(atPath: stdoutPath.path, contents: nil)
        FileManager.default.createFile(atPath: stderrPath.path, contents: nil)
        let stdoutHandle = try FileHandle(forWritingTo: stdoutPath)
        let stderrHandle = try FileHandle(forWritingTo: stderrPath)
        process.standardOutput = stdoutHandle
        process.standardError = stderrHandle

        return try await withCheckedThrowingContinuation { continuation in
            do {
                try process.run()
            } catch {
                try? stdoutHandle.close()
                try? stderrHandle.close()
                try? FileManager.default.removeItem(at: stdoutPath)
                try? FileManager.default.removeItem(at: stderrPath)
                continuation.resume(throwing: AppKError.toolExecutionFailed(tool: command.executable, cause: error.localizedDescription))
                return
            }

            stdinPipe.fileHandleForWriting.write(Data(stdin.utf8))
            try? stdinPipe.fileHandleForWriting.close()

            DispatchQueue.global().async {
                process.waitUntilExit()
                try? stdoutHandle.close()
                try? stderrHandle.close()

                let stdoutData = (try? Data(contentsOf: stdoutPath)) ?? Data()
                let stderrData = (try? Data(contentsOf: stderrPath)) ?? Data()
                try? FileManager.default.removeItem(at: stdoutPath)
                try? FileManager.default.removeItem(at: stderrPath)

                let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""
                continuation.resume(returning: ProcessResult(stdout: stdout, stderr: stderr, exitCode: process.terminationStatus))
            }
        }
    }

    public func runStreaming(_ command: Command) -> AsyncStream<ProcessOutput> {
        AsyncStream { continuation in
            DispatchQueue.global().async {
                let process = Process()
                do {
                    try self.configure(process, command)
                } catch {
                    continuation.finish()
                    return
                }

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                do {
                    try process.run()
                } catch {
                    continuation.finish()
                    return
                }


                let timeoutTimer: DispatchSourceTimer?
                if let timeout = command.timeout {
                    let timer = DispatchSource.makeTimerSource()
                    timer.schedule(deadline: .now() + timeout)
                    timer.setEventHandler {
                        process.terminate()
                    }
                    timer.resume()
                    timeoutTimer = timer
                } else {
                    timeoutTimer = nil
                }

                DispatchQueue.global().async {
                    while process.isRunning {
                        let stdoutData = stdoutPipe.fileHandleForReading.availableData
                        if !stdoutData.isEmpty, let str = String(data: stdoutData, encoding: .utf8) {
                            continuation.yield(.stdout(str))
                        }
                        let stderrData = stderrPipe.fileHandleForReading.availableData
                        if !stderrData.isEmpty, let str = String(data: stderrData, encoding: .utf8) {
                            continuation.yield(.stderr(str))
                        }
                        if stdoutData.isEmpty && stderrData.isEmpty { break }
                        Thread.sleep(forTimeInterval: 0.01)
                    }
                    process.waitUntilExit()
                    let remainingStdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    let remainingStderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    if !remainingStdout.isEmpty, let str = String(data: remainingStdout, encoding: .utf8) {
                        continuation.yield(.stdout(str))
                    }
                    if !remainingStderr.isEmpty, let str = String(data: remainingStderr, encoding: .utf8) {
                        continuation.yield(.stderr(str))
                    }
                    continuation.yield(.exit(process.terminationStatus))
                    timeoutTimer?.cancel()
                    continuation.finish()
                }
            }
        }
    }

    public func run(_ command: String, args: [String] = [], in cwd: URL? = nil) async throws -> ProcessResult {
        try await run(Command(executable: command, arguments: args, workingDirectory: cwd))
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

    private func configure(_ process: Process, _ command: Command) throws {
        let resolved = resolveExecutable(command.executable)
        guard let path = resolved else {
            throw AppKError.toolExecutionFailed(tool: command.executable, cause: "executable not found in PATH")
        }
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = command.arguments
        if let cwd = command.workingDirectory { process.currentDirectoryURL = cwd }
        if !command.environment.isEmpty {
            var env = ProcessInfo.processInfo.environment
            for (k, v) in command.environment { env[k] = v }
            process.environment = env
        }
    }

    private func resolveExecutable(_ name: String) -> String? {
        if name.hasPrefix("/") {
            return FileManager.default.isExecutableFile(atPath: name) ? name : nil
        }
        if name.contains("/") {
            let cwd = FileManager.default.currentDirectoryPath
            let full = cwd + "/" + name
            if FileManager.default.isExecutableFile(atPath: full) { return full }
        }
        guard let path = ProcessInfo.processInfo.environment["PATH"] else { return nil }
        for dir in path.split(separator: ":") {
            let full = "\(dir)/\(name)"
            if FileManager.default.isExecutableFile(atPath: full) { return full }
        }
        return nil
    }
}
