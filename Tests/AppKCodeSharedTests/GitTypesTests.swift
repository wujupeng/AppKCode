import XCTest
@testable import AppKCodeShared

final class GitTypesTests: XCTestCase {
    func testGitFileStatusValues() {
        XCTAssertEqual(GitFileStatus.modified.rawValue, "modified")
        XCTAssertEqual(GitFileStatus.staged.rawValue, "staged")
        XCTAssertEqual(GitFileStatus.untracked.rawValue, "untracked")
        XCTAssertEqual(GitFileStatus.deleted.rawValue, "deleted")
    }

    func testGitFileStatusItemCreation() {
        let item = GitFileStatusItem(path: "test.swift", status: .modified, staged: false)
        XCTAssertEqual(item.path, "test.swift")
        XCTAssertEqual(item.status, .modified)
        XCTAssertFalse(item.staged)
        XCTAssertNil(item.oldPath)
    }

    func testGitFileStatusItemWithOldPath() {
        let item = GitFileStatusItem(path: "new.swift", status: .renamed, staged: true, oldPath: "old.swift")
        XCTAssertEqual(item.oldPath, "old.swift")
        XCTAssertTrue(item.staged)
    }

    func testGitOperationKindRiskClassification() {
        XCTAssertEqual(GitRiskLevel.classify(.status), .readOnly)
        XCTAssertEqual(GitRiskLevel.classify(.diff), .readOnly)
        XCTAssertEqual(GitRiskLevel.classify(.log), .readOnly)
        XCTAssertEqual(GitRiskLevel.classify(.branchList), .readOnly)
        XCTAssertEqual(GitRiskLevel.classify(.fetch(remote: "origin")), .readOnly)

        XCTAssertEqual(GitRiskLevel.classify(.stage(paths: [])), .low)
        XCTAssertEqual(GitRiskLevel.classify(.unstage(paths: [])), .low)
        XCTAssertEqual(GitRiskLevel.classify(.checkout(branch: "main")), .low)
        XCTAssertEqual(GitRiskLevel.classify(.branchCreate(name: "feature")), .low)
        XCTAssertEqual(GitRiskLevel.classify(.pull(remote: "origin", branch: "main")), .low)

        XCTAssertEqual(GitRiskLevel.classify(.commit(message: "msg", paths: [])), .high)
        XCTAssertEqual(GitRiskLevel.classify(.push(remote: "origin", branch: "main")), .high)
        XCTAssertEqual(GitRiskLevel.classify(.resetHard(target: "HEAD~1")), .high)
        XCTAssertEqual(GitRiskLevel.classify(.rebase(target: "main")), .high)
    }

    func testGitRepositoryStatusNotARepository() {
        let status = GitRepositoryStatus.notARepository
        XCTAssertFalse(status.isRepository)
        XCTAssertNil(status.currentBranch)
        XCTAssertEqual(status.aheadCount, 0)
        XCTAssertEqual(status.behindCount, 0)
        XCTAssertTrue(status.files.isEmpty)
    }

    func testGitDiffLineKind() {
        let line = GitDiffLine(kind: .added, oldLineNumber: nil, newLineNumber: 5, content: "new line")
        XCTAssertEqual(line.kind, .added)
        XCTAssertNil(line.oldLineNumber)
        XCTAssertEqual(line.newLineNumber, 5)
    }

    func testGitDiffHunkCreation() {
        let hunk = GitDiffHunk(oldStartLine: 1, oldLineCount: 3, newStartLine: 1, newLineCount: 4, lines: [])
        XCTAssertEqual(hunk.oldStartLine, 1)
        XCTAssertEqual(hunk.newLineCount, 4)
    }

    func testGitFileDiffCreation() {
        let diff = GitFileDiff(oldPath: "a.swift", newPath: "a.swift", hunks: [], addedLinesCount: 5, deletedLinesCount: 2)
        XCTAssertEqual(diff.oldPath, "a.swift")
        XCTAssertEqual(diff.addedLinesCount, 5)
        XCTAssertEqual(diff.deletedLinesCount, 2)
    }

    func testGitCommitInfoCreation() {
        let commit = GitCommitInfo(
            sha: "abc123", shortSha: "abc123",
            authorName: "Test", authorEmail: "test@test.com", authorDate: Date(),
            committerName: "Test", committerEmail: "test@test.com", committerDate: Date(),
            message: "Test commit", messageSubject: "Test commit", messageBody: "",
            parentShas: []
        )
        XCTAssertEqual(commit.sha, "abc123")
        XCTAssertEqual(commit.authorName, "Test")
        XCTAssertTrue(commit.parentShas.isEmpty)
    }

    func testGitBranchInfoCreation() {
        let branch = GitBranchInfo(
            name: "feature", isCurrent: false, isRemote: false,
            upstreamTracking: "origin/feature", lastCommitSha: "abc123", lastCommitDate: Date()
        )
        XCTAssertEqual(branch.name, "feature")
        XCTAssertFalse(branch.isCurrent)
        XCTAssertEqual(branch.upstreamTracking, "origin/feature")
    }

    func testAllTypesAreSendable() {
        let _ = GitFileStatus.modified as any Sendable
        let _ = GitOperationKind.status as any Sendable
        let _ = GitRiskLevel.readOnly as any Sendable
    }
}