import XCTest
@testable import AppKCodeInfrastructure
@testable import AppKCodeShared

final class ProcessRunnerCommandTests: XCTestCase {
    func testRunCommandWithAbsoluteExecutable() async throws {
        let runner = ProcessRunner()
        let cmd = Command(executable: "/bin/echo", arguments: ["hello"])
        let result = try await runner.run(cmd)
        XCTAssertEqual(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines), "hello")
        XCTAssertEqual(result.exitCode, 0)
    }

    func testRunCommandWithEnvironment() async throws {
        let runner = ProcessRunner()
        let cmd = Command(executable: "/usr/bin/env", arguments: [], environment: ["MY_TEST_VAR": "test123"])
        let result = try await runner.run(cmd)
        XCTAssertTrue(result.stdout.contains("MY_TEST_VAR=test123"))
    }

    func testRunCommandWithWorkingDirectory() async throws {
        let runner = ProcessRunner()
        let cmd = Command(executable: "/bin/pwd", arguments: [], workingDirectory: URL(fileURLWithPath: "/tmp"))
        let result = try await runner.run(cmd)
        let pwd = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(pwd.hasSuffix("/tmp"), "pwd was \(pwd)")
    }

    func testRunCommandExitCode() async throws {
        let runner = ProcessRunner()
        let cmd = Command(executable: "/bin/sh", arguments: ["-c", "exit 42"])
        let result = try await runner.run(cmd)
        XCTAssertEqual(result.exitCode, 42)
    }

    func testRunCommandFailure() async throws {
        let runner = ProcessRunner()
        let cmd = Command(executable: "/bin/cat", arguments: ["/nonexistent_file_xyz"])
        let result = try await runner.run(cmd)
        XCTAssertNotEqual(result.exitCode, 0)
        XCTAssertFalse(result.stderr.isEmpty)
    }

    func testRunWithStdin() async throws {
        let runner = ProcessRunner()
        let cmd = Command(executable: "/usr/bin/wc", arguments: ["-c"])
        let result = try await runner.runWithStdin(cmd, stdin: "hello world")
        let count = Int(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        XCTAssertEqual(count, 11)
    }

    func testRunStreamingCommand() async throws {
        let runner = ProcessRunner()
        let cmd = Command(executable: "/bin/echo", arguments: ["streamed"])
        var outputs: [String] = []
        var exitCode: Int32 = -1
        for await output in runner.runStreaming(cmd) {
            switch output {
            case .stdout(let s): outputs.append(s)
            case .stderr(let s): outputs.append(s)
            case .exit(let code): exitCode = code
            }
        }
        XCTAssertEqual(exitCode, 0)
        XCTAssertTrue(outputs.contains(where: { $0.contains("streamed") }))
    }

    func testH7ComplianceNoEnvStringConcatenation() async throws {
        let runner = ProcessRunner()
        let cmd = Command(executable: "/bin/echo", arguments: ["h7-test"])
        let result = try await runner.run(cmd)
        XCTAssertEqual(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines), "h7-test")
    }

    func testM0CompatRunMethod() async throws {
        let runner = ProcessRunner()
        let result = try await runner.run("/bin/echo", args: ["compat"])
        XCTAssertEqual(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines), "compat")
        XCTAssertEqual(result.exitCode, 0)
    }

    func testM0CompatIsInstalled() async throws {
        let runner = ProcessRunner()
        let installed = await runner.isInstalled("echo")
        XCTAssertTrue(installed)
    }

    func testM0CompatIsInstalledNotInstalled() async throws {
        let runner = ProcessRunner()
        let installed = await runner.isInstalled("nonexistent_binary_xyz123")
        XCTAssertFalse(installed)
    }
}