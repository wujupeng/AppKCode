import XCTest
@testable import AppKCodeDomain
@testable import AppKCodeInfrastructure
@testable import AppKCodeShared

final class GitServiceImplTests: XCTestCase {
    private var tempRepoURL: URL!
    private var service: GitServiceImpl!

    override func setUpWithError() throws {
        tempRepoURL = FileManager.default.temporaryDirectory.appendingPathComponent("git-svc-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempRepoURL, withIntermediateDirectories: true)
        service = GitServiceImpl()
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

    private func createAndCommitFile(_ name: String, _ content: String) async throws {
        try content.write(to: tempRepoURL.appendingPathComponent(name), atomically: true, encoding: .utf8)
        let runner = GitCommandRunner()
        _ = try await runner.run(arguments: ["add", name], at: tempRepoURL)
        _ = try await runner.run(arguments: ["commit", "-m", "add \(name)"], at: tempRepoURL)
    }

    // MARK: - G1: Repository Detection

    func testG1_IsGitRepository_False() async {
        let result = await service.isGitRepository(at: tempRepoURL)
        XCTAssertFalse(result)
    }

    func testG1_IsGitRepository_True() async throws {
        try await initRepo()
        let result = await service.isGitRepository(at: tempRepoURL)
        XCTAssertTrue(result)
    }

    func testG1_DetectRepository_NotARepo() async {
        let status = await service.detectRepository(at: tempRepoURL)
        XCTAssertFalse(status.isRepository)
    }

    func testG1_DetectRepository_ValidRepo() async throws {
        try await initRepo()
        let status = await service.detectRepository(at: tempRepoURL)
        XCTAssertTrue(status.isRepository)
    }

    // MARK: - G2: Status

    func testG2_GetStatus_CleanRepo() async throws {
        try await initRepo()
        try await createAndCommitFile("test.txt", "content")
        let status = try await service.getStatus(at: tempRepoURL)
        XCTAssertTrue(status.isRepository)
        XCTAssertFalse(status.hasUncommittedChanges)
    }

    func testG2_GetStatus_WithModifications() async throws {
        try await initRepo()
        try await createAndCommitFile("test.txt", "content")
        try "modified".write(to: tempRepoURL.appendingPathComponent("test.txt"), atomically: true, encoding: .utf8)
        let status = try await service.getStatus(at: tempRepoURL)
        XCTAssertTrue(status.hasUncommittedChanges)
        XCTAssertFalse(status.files.isEmpty)
    }

    func testG2_GetStatus_UntrackedFile() async throws {
        try await initRepo()
        try await createAndCommitFile("test.txt", "content")
        try "new".write(to: tempRepoURL.appendingPathComponent("new.txt"), atomically: true, encoding: .utf8)
        let status = try await service.getStatus(at: tempRepoURL)
        XCTAssertTrue(status.files.contains(where: { $0.status == .untracked }))
    }

    // MARK: - G3: Diff

    func testG3_GetWorkingDiff() async throws {
        try await initRepo()
        try await createAndCommitFile("test.txt", "line1\nline2\n")
        try "line1\nmodified\n".write(to: tempRepoURL.appendingPathComponent("test.txt"), atomically: true, encoding: .utf8)
        let diff = try await service.getWorkingDiff(at: tempRepoURL, filePath: "test.txt")
        XCTAssertNotNil(diff)
        XCTAssertGreaterThan(diff!.addedLinesCount, 0)
    }

    func testG3_GetStagedDiff() async throws {
        try await initRepo()
        try await createAndCommitFile("test.txt", "line1\n")
        try "line1\nline2\n".write(to: tempRepoURL.appendingPathComponent("test.txt"), atomically: true, encoding: .utf8)
        try await service.stage(paths: ["test.txt"], at: tempRepoURL)
        let diff = try await service.getStagedDiff(at: tempRepoURL, filePath: "test.txt")
        XCTAssertNotNil(diff)
    }

    func testG3_GetHeadDiff() async throws {
        try await initRepo()
        try await createAndCommitFile("test.txt", "line1\n")
        try "line1\nline2\n".write(to: tempRepoURL.appendingPathComponent("test.txt"), atomically: true, encoding: .utf8)
        let diff = try await service.getHeadDiff(at: tempRepoURL, filePath: "test.txt")
        XCTAssertNotNil(diff)
    }

    func testG3_GetCommitDiff() async throws {
        try await initRepo()
        try await createAndCommitFile("test.txt", "line1\n")
        let status = try await service.getStatus(at: tempRepoURL)
        _ = status
        let log = try await service.getLog(at: tempRepoURL, limit: 1, skip: 0)
        XCTAssertEqual(log.count, 1)
        let diffs = try await service.getCommitDiff(at: tempRepoURL, sha: log[0].sha)
        XCTAssertFalse(diffs.isEmpty)
    }

    // MARK: - G4: Stage / Unstage

    func testG4_StageFile() async throws {
        try await initRepo()
        try await createAndCommitFile("test.txt", "content")
        try "new".write(to: tempRepoURL.appendingPathComponent("new.txt"), atomically: true, encoding: .utf8)
        try await service.stage(paths: ["new.txt"], at: tempRepoURL)
        let status = try await service.getStatus(at: tempRepoURL)
        XCTAssertTrue(status.files.contains(where: { $0.staged }))
    }

    func testG4_StageAll() async throws {
        try await initRepo()
        try await createAndCommitFile("test.txt", "content")
        try "a".write(to: tempRepoURL.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try "b".write(to: tempRepoURL.appendingPathComponent("b.txt"), atomically: true, encoding: .utf8)
        try await service.stageAll(at: tempRepoURL)
        let status = try await service.getStatus(at: tempRepoURL)
        XCTAssertTrue(status.files.allSatisfy { $0.staged })
    }

    func testG4_UnstageFile() async throws {
        try await initRepo()
        try await createAndCommitFile("test.txt", "content")
        try "new".write(to: tempRepoURL.appendingPathComponent("new.txt"), atomically: true, encoding: .utf8)
        try await service.stage(paths: ["new.txt"], at: tempRepoURL)
        try await service.unstage(paths: ["new.txt"], at: tempRepoURL)
        let status = try await service.getStatus(at: tempRepoURL)
        XCTAssertTrue(status.files.contains(where: { !$0.staged }))
    }

    // MARK: - G5: Commit

    func testG5_CommitWithoutApproval() async throws {
        try await initRepo()
        try "content".write(to: tempRepoURL.appendingPathComponent("test.txt"), atomically: true, encoding: .utf8)
        try await service.stage(paths: ["test.txt"], at: tempRepoURL)
        let sha = try await service.commit(message: "test commit", paths: [], at: tempRepoURL)
        XCTAssertFalse(sha.isEmpty)
    }

    // MARK: - G6: Branch

    func testG6_ListBranches() async throws {
        try await initRepo()
        try await createAndCommitFile("test.txt", "content")
        let branches = try await service.listBranches(at: tempRepoURL)
        XCTAssertFalse(branches.isEmpty)
        XCTAssertTrue(branches.contains(where: { $0.isCurrent }))
    }

    func testG6_CreateBranch() async throws {
        try await initRepo()
        try await createAndCommitFile("test.txt", "content")
        try await service.createBranch(name: "feature", at: tempRepoURL, from: nil)
        let branches = try await service.listBranches(at: tempRepoURL)
        XCTAssertTrue(branches.contains(where: { $0.name == "feature" }))
    }

    func testG6_DeleteBranch() async throws {
        try await initRepo()
        try await createAndCommitFile("test.txt", "content")
        try await service.createBranch(name: "temp", at: tempRepoURL, from: nil)
        try await service.deleteBranch(name: "temp", at: tempRepoURL, force: false)
        let branches = try await service.listBranches(at: tempRepoURL)
        XCTAssertFalse(branches.contains(where: { $0.name == "temp" }))
    }

    // MARK: - G7: Checkout

    func testG7_CheckoutNewBranch() async throws {
        try await initRepo()
        try await createAndCommitFile("test.txt", "content")
        try await service.checkoutNewBranch(name: "feature", from: nil, at: tempRepoURL)
        let status = try await service.getStatus(at: tempRepoURL)
        XCTAssertEqual(status.currentBranch, "feature")
    }

    func testG7_CheckoutExistingBranch() async throws {
        try await initRepo()
        try await createAndCommitFile("test.txt", "content")
        try await service.createBranch(name: "feature", at: tempRepoURL, from: nil)
        try await service.checkout(branch: "feature", at: tempRepoURL)
        let status = try await service.getStatus(at: tempRepoURL)
        XCTAssertEqual(status.currentBranch, "feature")
    }

    // MARK: - G8: Log / History

    func testG8_GetLog() async throws {
        try await initRepo()
        try await createAndCommitFile("test.txt", "content")
        let log = try await service.getLog(at: tempRepoURL, limit: 10, skip: 0)
        XCTAssertEqual(log.count, 1)
        XCTAssertFalse(log[0].sha.isEmpty)
        XCTAssertEqual(log[0].authorName, "Test")
    }

    func testG8_GetLogMultipleCommits() async throws {
        try await initRepo()
        try await createAndCommitFile("a.txt", "a")
        try await createAndCommitFile("b.txt", "b")
        let log = try await service.getLog(at: tempRepoURL, limit: 10, skip: 0)
        XCTAssertEqual(log.count, 2)
    }

    func testG8_GetCommitInfo() async throws {
        try await initRepo()
        try await createAndCommitFile("test.txt", "content")
        let log = try await service.getLog(at: tempRepoURL, limit: 1, skip: 0)
        let info = try await service.getCommitInfo(sha: log[0].sha, at: tempRepoURL)
        XCTAssertEqual(info.sha, log[0].sha)
    }

    // MARK: - H2: Approval Gate

    func testH2_CommitWithApproval_Rejected() async throws {
        try await initRepo()
        try "content".write(to: tempRepoURL.appendingPathComponent("test.txt"), atomically: true, encoding: .utf8)
        try await service.stage(paths: ["test.txt"], at: tempRepoURL)
        let rejectingService = GitServiceImpl(approvalService: MockApprovalService(shouldAllow: false))
        do {
            _ = try await rejectingService.commit(message: "test", paths: [], at: tempRepoURL)
            XCTFail("Should have thrown approval rejected")
        } catch let error as AppKError {
            switch error {
            case .approvalRejected: break
            default: XCTFail("Wrong error: \(error)")
            }
        }
    }

    func testH2_CommitWithApproval_Allowed() async throws {
        try await initRepo()
        try "content".write(to: tempRepoURL.appendingPathComponent("test.txt"), atomically: true, encoding: .utf8)
        try await service.stage(paths: ["test.txt"], at: tempRepoURL)
        let allowingService = GitServiceImpl(approvalService: MockApprovalService(shouldAllow: true))
        let sha = try await allowingService.commit(message: "approved commit", paths: [], at: tempRepoURL)
        XCTAssertFalse(sha.isEmpty)
    }

    func testH2_PushWithApproval_Rejected() async throws {
        try await initRepo()
        try await createAndCommitFile("test.txt", "content")
        let rejectingService = GitServiceImpl(approvalService: MockApprovalService(shouldAllow: false))
        do {
            try await rejectingService.push(remote: "origin", branch: "main", at: tempRepoURL)
            XCTFail("Should have thrown approval rejected")
        } catch let error as AppKError {
            switch error {
            case .approvalRejected: break
            default: XCTFail("Wrong error: \(error)")
            }
        }
    }
}

// MARK: - Mock Approval Service

private final class MockApprovalService: AppApprovalService, @unchecked Sendable {
    private let shouldAllow: Bool

    init(shouldAllow: Bool) {
        self.shouldAllow = shouldAllow
    }

    func classify(operation: OperationDescriptor) -> RiskLevel {
        .high
    }

    func requestApproval(_ payload: ApprovalPayload) async throws -> ApprovalDecision {
        shouldAllow ? .allow : .reject
    }

    func auditTrail(session: AgentSessionID) async throws -> [AuditRecord] {
        []
    }
}