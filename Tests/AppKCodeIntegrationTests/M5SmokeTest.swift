import XCTest
@testable import AppKCodeDomain
@testable import AppKCodeApplication
@testable import AppKCodeShared
@testable import AppKCodeInfrastructure
@testable import AppKCodePresentation

final class M5SmokeTest: XCTestCase {

    // MARK: - G1: Repository Detection

    func testM5_G1_01_gitServiceProtocolExists() {
        let svc: GitServiceProtocol = GitServiceImpl()
        XCTAssertNotNil(svc)
    }

    func testM5_G1_02_gitRepositoryStatusExists() {
        let status = GitRepositoryStatus.notARepository
        XCTAssertFalse(status.isRepository)
    }

    func testM5_G1_03_gitRepositoryDetectorExists() {
        let detector = GitRepositoryDetector()
        XCTAssertNotNil(detector)
    }

    // MARK: - G2: Status

    func testM5_G2_01_gitFileStatusAllCases() {
        XCTAssertEqual(GitFileStatus.modified.rawValue, "modified")
        XCTAssertEqual(GitFileStatus.staged.rawValue, "staged")
        XCTAssertEqual(GitFileStatus.untracked.rawValue, "untracked")
        XCTAssertEqual(GitFileStatus.deleted.rawValue, "deleted")
        XCTAssertEqual(GitFileStatus.renamed.rawValue, "renamed")
        XCTAssertEqual(GitFileStatus.conflicted.rawValue, "conflicted")
    }

    func testM5_G2_02_gitFileStatusItemCreation() {
        let item = GitFileStatusItem(path: "test.swift", status: .modified, staged: false)
        XCTAssertEqual(item.path, "test.swift")
        XCTAssertEqual(item.status, .modified)
    }

    func testM5_G2_03_gitOutputParserExists() {
        let parser = GitOutputParser()
        XCTAssertNotNil(parser)
    }

    // MARK: - G3: Diff

    func testM5_G3_01_gitDiffLineKindExists() {
        let line = GitDiffLine(kind: .added, oldLineNumber: nil, newLineNumber: 1, content: "test")
        XCTAssertEqual(line.kind, .added)
    }

    func testM5_G3_02_gitDiffHunkExists() {
        let hunk = GitDiffHunk(oldStartLine: 1, oldLineCount: 1, newStartLine: 1, newLineCount: 1, lines: [])
        XCTAssertEqual(hunk.oldStartLine, 1)
    }

    func testM5_G3_03_gitFileDiffExists() {
        let diff = GitFileDiff(oldPath: "a", newPath: "b", hunks: [], addedLinesCount: 0, deletedLinesCount: 0)
        XCTAssertEqual(diff.oldPath, "a")
    }

    // MARK: - G4: Stage / Unstage

    func testM5_G4_01_gitOperationKindStage() {
        let op = GitOperationKind.stage(paths: ["file.swift"])
        XCTAssertEqual(GitRiskLevel.classify(op), .low)
    }

    func testM5_G4_02_gitOperationKindUnstage() {
        let op = GitOperationKind.unstage(paths: ["file.swift"])
        XCTAssertEqual(GitRiskLevel.classify(op), .low)
    }

    // MARK: - G5: Commit (H2 Approval Gate)

    func testM5_G5_01_gitOperationKindCommit() {
        let op = GitOperationKind.commit(message: "msg", paths: [])
        XCTAssertEqual(GitRiskLevel.classify(op), .high)
    }

    func testM5_G5_02_gitServiceImplWithApproval() {
        let svc = GitServiceImpl(approvalService: nil)
        XCTAssertNotNil(svc)
    }

    // MARK: - G6: Branch

    func testM5_G6_01_gitBranchInfoExists() {
        let branch = GitBranchInfo(name: "main", isCurrent: true, isRemote: false,
                                    upstreamTracking: nil, lastCommitSha: "abc", lastCommitDate: Date())
        XCTAssertEqual(branch.name, "main")
        XCTAssertTrue(branch.isCurrent)
    }

    func testM5_G6_02_gitOperationKindBranchCreate() {
        let op = GitOperationKind.branchCreate(name: "feature")
        XCTAssertEqual(GitRiskLevel.classify(op), .low)
    }

    func testM5_G6_03_gitOperationKindBranchDelete() {
        let op = GitOperationKind.branchDelete(name: "feature")
        XCTAssertEqual(GitRiskLevel.classify(op), .low)
    }

    // MARK: - G7: Checkout

    func testM5_G7_01_gitOperationKindCheckout() {
        let op = GitOperationKind.checkout(branch: "main")
        XCTAssertEqual(GitRiskLevel.classify(op), .low)
    }

    // MARK: - G8: Log / History

    func testM5_G8_01_gitCommitInfoExists() {
        let commit = GitCommitInfo(sha: "abc", shortSha: "abc",
                                    authorName: "A", authorEmail: "a@b.com", authorDate: Date(),
                                    committerName: "A", committerEmail: "a@b.com", committerDate: Date(),
                                    message: "msg", messageSubject: "msg", messageBody: "", parentShas: [])
        XCTAssertEqual(commit.sha, "abc")
    }

    func testM5_G8_02_gitOperationKindLog() {
        let op = GitOperationKind.log
        XCTAssertEqual(GitRiskLevel.classify(op), .readOnly)
    }

    // MARK: - G9: Push / Pull / Fetch

    func testM5_G9_01_gitOperationKindPush() {
        let op = GitOperationKind.push(remote: "origin", branch: "main")
        XCTAssertEqual(GitRiskLevel.classify(op), .high)
    }

    func testM5_G9_02_gitOperationKindPull() {
        let op = GitOperationKind.pull(remote: "origin", branch: "main")
        XCTAssertEqual(GitRiskLevel.classify(op), .low)
    }

    func testM5_G9_03_gitOperationKindFetch() {
        let op = GitOperationKind.fetch(remote: "origin")
        XCTAssertEqual(GitRiskLevel.classify(op), .readOnly)
    }

    // MARK: - H7: Command Execution Safety

    func testM5_H7_01_gitCommandRunnerUsesCommand() {
        let runner = GitCommandRunner()
        XCTAssertNotNil(runner)
    }

    func testM5_H7_02_gitCommandThroughStructuredModel() async throws {
        let runner = GitCommandRunner()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        _ = try await runner.run(arguments: ["init"], at: tempDir)
        let (stdout, _, exitCode) = try await runner.runWithExitCode(
            arguments: ["rev-parse", "--is-inside-work-tree"],
            at: tempDir
        )
        XCTAssertEqual(exitCode, 0)
        XCTAssertEqual(stdout.trimmingCharacters(in: .whitespacesAndNewlines), "true")
    }

    // MARK: - H8: Git Operation Layer Isolation

    func testM5_H8_01_gitServiceProtocolIsInDomain() {
        let svc: GitServiceProtocol = GitServiceImpl()
        XCTAssertNotNil(svc)
    }

    func testM5_H8_02_gitServiceImplImplementsProtocol() {
        let svc: GitServiceProtocol = GitServiceImpl()
        XCTAssertNotNil(svc)
    }

    @MainActor
    func testM5_H8_03_gitStateManagerExists() async {
        let svc = GitServiceImpl()
        let manager = GitStateManager(gitService: svc)
        await manager.setRepository(URL(fileURLWithPath: "/tmp"))
        XCTAssertNotNil(manager.status)
    }

    @MainActor
    func testM5_H8_04_gitStateManagerComputedProperties() async {
        let svc = GitServiceImpl()
        let manager = GitStateManager(gitService: svc)
        await manager.setRepository(URL(fileURLWithPath: "/tmp"))
        XCTAssertEqual(manager.modifiedCount, 0)
        XCTAssertEqual(manager.stagedCount, 0)
        XCTAssertEqual(manager.untrackedCount, 0)
    }

    // MARK: - GitStateManager

    @MainActor
    func testM5_H8_05_gitStateManagerObservableObject() {
        let svc = GitServiceImpl()
        let manager = GitStateManager(gitService: svc)
        XCTAssertFalse(manager.isLoading)
        XCTAssertNil(manager.lastError)
    }

    // MARK: - Presentation Layer Views

    func testM5_H8_10_gitStatusViewExists() {
        XCTAssertNotNil(GitStatusView.self)
    }

    func testM5_H8_11_gitChangesViewExists() {
        XCTAssertNotNil(GitChangesView.self)
    }

    func testM5_H8_12_gitDiffViewExists() {
        XCTAssertNotNil(GitDiffView.self)
    }

    func testM5_H8_13_gitBranchViewExists() {
        XCTAssertNotNil(GitBranchView.self)
    }

    func testM5_H8_14_gitHistoryViewExists() {
        XCTAssertNotNil(GitHistoryView.self)
    }

    func testM5_H8_15_gitPanelViewExists() {
        XCTAssertNotNil(GitPanelView.self)
    }

    // MARK: - M0 Git Compatibility (M0 GitService class preserved)

    func testM5_REG_01_m0GitStatusStructPreserved() {
        let status = GitStatus(branchName: "main", modifiedCount: 0, stagedCount: 0, untrackedCount: 0)
        XCTAssertEqual(status.branchName, "main")
        XCTAssertEqual(status.modifiedCount, 0)
    }

    func testM5_REG_02_m0GitServiceClassPreserved() {
        let _ = GitService()
    }

    func testM5_REG_03_m0GitStatusBarViewPreserved() {
        XCTAssertNotNil(GitStatusBarView.self)
    }

    // MARK: - M4 Regression

    func testM5_REG_10_m4CommandModelPreserved() {
        let cmd = Command(executable: "git", arguments: ["status"])
        XCTAssertEqual(cmd.executable, "git")
    }

    func testM5_REG_11_m4ProcessRunnerPreserved() async throws {
        let runner = ProcessRunner()
        let result = try await runner.run("/bin/echo", args: ["m5-reg"])
        XCTAssertTrue(result.stdout.contains("m5-reg"))
    }

    func testM5_REG_12_m4BuildTestServicePreserved() {
        let svc = BuildTestService()
        XCTAssertFalse(svc.isRunning)
    }

    // MARK: - M3 Regression

    func testM5_REG_20_m3LSPTypesPreserved() {
        let pos = LSPPosition(line: 0, character: 0)
        XCTAssertEqual(pos.line, 0)
    }

    // MARK: - M2 Regression

    func testM5_REG_30_m2SearchEnginePreserved() {
        let engine = SearchEngine()
        XCTAssertNotNil(engine)
    }

    // MARK: - M1 Regression

    func testM5_REG_40_m1ApprovalTypesPreserved() {
        let payload = ApprovalPayload(
            description: "test", affectedFiles: [],
            reason: "test", sessionID: AgentSessionID()
        )
        XCTAssertEqual(payload.description, "test")
    }

    // MARK: - M0 Regression

    func testM5_REG_50_m0ProcessRunnerCompat() async throws {
        let runner = ProcessRunner()
        let installed = await runner.isInstalled("git")
        XCTAssertTrue(installed)
    }
}