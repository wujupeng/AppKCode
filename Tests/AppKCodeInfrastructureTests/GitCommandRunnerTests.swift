import XCTest
@testable import AppKCodeInfrastructure
@testable import AppKCodeShared

final class GitCommandRunnerTests: XCTestCase {
    private var tempRepoURL: URL!

    override func setUpWithError() throws {
        tempRepoURL = FileManager.default.temporaryDirectory.appendingPathComponent("git-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempRepoURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: tempRepoURL.path) {
            try? FileManager.default.removeItem(at: tempRepoURL)
        }
    }

    private func initRepo() async throws {
        let runner = GitCommandRunner()
        _ = try await runner.run(arguments: ["init"], at: tempRepoURL)
        _ = try await runner.run(arguments: ["config", "user.name", "Test"], at: tempRepoURL)
        _ = try await runner.run(arguments: ["config", "user.email", "test@test.com"], at: tempRepoURL)
    }

    func testRun_RevParseHead() async throws {
        try await initRepo()
        let content = "test content"
        try content.write(to: tempRepoURL.appendingPathComponent("test.txt"), atomically: true, encoding: .utf8)
        let runner = GitCommandRunner()
        _ = try await runner.run(arguments: ["add", "test.txt"], at: tempRepoURL)
        _ = try await runner.run(arguments: ["commit", "-m", "init"], at: tempRepoURL)
        let head = try await runner.run(arguments: ["rev-parse", "HEAD"], at: tempRepoURL)
        XCTAssertFalse(head.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    func testRun_Status() async throws {
        try await initRepo()
        let runner = GitCommandRunner()
        let status = try await runner.run(arguments: ["status", "--porcelain=v1", "--branch"], at: tempRepoURL)
        XCTAssertTrue(status.contains("##"))
    }

    func testRunWithExitCode_Success() async throws {
        try await initRepo()
        let runner = GitCommandRunner()
        let (stdout, stderr, exitCode) = try await runner.runWithExitCode(
            arguments: ["rev-parse", "--is-inside-work-tree"],
            at: tempRepoURL
        )
        XCTAssertEqual(exitCode, 0)
        XCTAssertEqual(stdout.trimmingCharacters(in: .whitespacesAndNewlines), "true")
        XCTAssertTrue(stderr.isEmpty)
    }

    func testRunWithExitCode_Failure() async throws {
        try await initRepo()
        let runner = GitCommandRunner()
        let (_, _, exitCode) = try await runner.runWithExitCode(
            arguments: ["rev-parse", "nonexistent_ref"],
            at: tempRepoURL
        )
        XCTAssertNotEqual(exitCode, 0)
    }

    func testRun_ThrowsOnNonZeroExit() async throws {
        try await initRepo()
        let runner = GitCommandRunner()
        do {
            _ = try await runner.run(arguments: ["rev-parse", "nonexistent_ref"], at: tempRepoURL)
            XCTFail("Should have thrown")
        } catch {
            XCTAssertTrue(error is AppKError)
        }
    }

    func testRunStreaming() async throws {
        try await initRepo()
        let runner = GitCommandRunner()
        var gotOutput = false
        var gotExit = false
        for await output in runner.runStreaming(arguments: ["status"], at: tempRepoURL) {
            switch output {
            case .stdout: gotOutput = true
            case .stderr: break
            case .exit: gotExit = true
            }
        }
        XCTAssertTrue(gotOutput)
        XCTAssertTrue(gotExit)
    }

    func testRun_UsesCommandModel() async throws {
        try await initRepo()
        let runner = GitCommandRunner()
        let result = try await runner.runWithExitCode(
            arguments: ["branch", "--list"],
            at: tempRepoURL
        )
        XCTAssertEqual(result.exitCode, 0)
    }
}