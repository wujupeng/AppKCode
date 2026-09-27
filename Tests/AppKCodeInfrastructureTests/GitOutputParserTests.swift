import XCTest
@testable import AppKCodeInfrastructure
@testable import AppKCodeShared

final class GitOutputParserTests: XCTestCase {
    private let parser = GitOutputParser()

    // MARK: - parseStatus

    func testParseStatus_BranchOnly() {
        let output = "## main\n"
        let result = parser.parseStatus(output)
        XCTAssertEqual(result.branch, "main")
        XCTAssertNil(result.upstream)
        XCTAssertEqual(result.ahead, 0)
        XCTAssertEqual(result.behind, 0)
        XCTAssertTrue(result.files.isEmpty)
    }

    func testParseStatus_BranchWithUpstream() {
        let output = "## main...origin/main\n"
        let result = parser.parseStatus(output)
        XCTAssertEqual(result.branch, "main")
        XCTAssertEqual(result.upstream, "origin/main")
    }

    func testParseStatus_AheadBehind() {
        let output = "## main...origin/main [ahead 2, behind 1]\n"
        let result = parser.parseStatus(output)
        XCTAssertEqual(result.branch, "main")
        XCTAssertEqual(result.upstream, "origin/main")
        XCTAssertEqual(result.ahead, 2)
        XCTAssertEqual(result.behind, 1)
    }

    func testParseStatus_AheadOnly() {
        let output = "## feature...origin/feature [ahead 3]\n"
        let result = parser.parseStatus(output)
        XCTAssertEqual(result.ahead, 3)
        XCTAssertEqual(result.behind, 0)
    }

    func testParseStatus_UntrackedFile() {
        let output = "## main\n?? newfile.swift\n"
        let result = parser.parseStatus(output)
        XCTAssertEqual(result.files.count, 1)
        XCTAssertEqual(result.files[0].path, "newfile.swift")
        XCTAssertEqual(result.files[0].status, .untracked)
        XCTAssertFalse(result.files[0].staged)
    }

    func testParseStatus_ModifiedFile() {
        let output = "## main\n M modified.swift\n"
        let result = parser.parseStatus(output)
        XCTAssertEqual(result.files.count, 1)
        XCTAssertEqual(result.files[0].path, "modified.swift")
        XCTAssertEqual(result.files[0].status, .modified)
        XCTAssertFalse(result.files[0].staged)
    }

    func testParseStatus_StagedFile() {
        let output = "## main\nM  staged.swift\n"
        let result = parser.parseStatus(output)
        XCTAssertEqual(result.files.count, 1)
        XCTAssertEqual(result.files[0].path, "staged.swift")
        XCTAssertEqual(result.files[0].status, .staged)
        XCTAssertTrue(result.files[0].staged)
    }

    func testParseStatus_DeletedFile() {
        let output = "## main\n D deleted.swift\n"
        let result = parser.parseStatus(output)
        XCTAssertEqual(result.files.count, 1)
        XCTAssertEqual(result.files[0].path, "deleted.swift")
        XCTAssertEqual(result.files[0].status, .deleted)
    }

    func testParseStatus_RenamedFile() {
        let output = "## main\nR  old.swift -> new.swift\n"
        let result = parser.parseStatus(output)
        XCTAssertEqual(result.files.count, 1)
        XCTAssertEqual(result.files[0].path, "new.swift")
        XCTAssertEqual(result.files[0].status, .renamed)
        XCTAssertEqual(result.files[0].oldPath, "old.swift")
    }

    func testParseStatus_ConflictedFile() {
        let output = "## main\nUU conflict.swift\n"
        let result = parser.parseStatus(output)
        XCTAssertEqual(result.files.count, 1)
        XCTAssertEqual(result.files[0].path, "conflict.swift")
        XCTAssertEqual(result.files[0].status, .conflicted)
    }

    func testParseStatus_MultipleFiles() {
        let output = "## main\nM  staged.swift\n M modified.swift\n?? untracked.swift\n"
        let result = parser.parseStatus(output)
        XCTAssertEqual(result.files.count, 3)
    }

    func testParseStatus_EmptyOutput() {
        let result = parser.parseStatus("")
        XCTAssertNil(result.branch)
        XCTAssertTrue(result.files.isEmpty)
    }

    // MARK: - parseDiff

    func testParseDiff_SimpleAddition() {
        let output = """
diff --git a/test.swift b/test.swift
index 1111111..2222222 100644
--- a/test.swift
+++ b/test.swift
@@ -1,3 +1,4 @@
 line1
 line2
+new line
 line3
"""
        let diffs = parser.parseDiff(output)
        XCTAssertEqual(diffs.count, 1)
        XCTAssertEqual(diffs[0].oldPath, "a/test.swift")
        XCTAssertEqual(diffs[0].newPath, "b/test.swift")
        XCTAssertEqual(diffs[0].addedLinesCount, 1)
        XCTAssertEqual(diffs[0].deletedLinesCount, 0)
        XCTAssertEqual(diffs[0].hunks.count, 1)
        XCTAssertEqual(diffs[0].hunks[0].lines.count, 4)
    }

    func testParseDiff_Deletion() {
        let output = """
diff --git a/test.swift b/test.swift
--- a/test.swift
+++ b/test.swift
@@ -1,3 +1,2 @@
 line1
-old line
 line2
"""
        let diffs = parser.parseDiff(output)
        XCTAssertEqual(diffs.count, 1)
        XCTAssertEqual(diffs[0].deletedLinesCount, 1)
        XCTAssertEqual(diffs[0].addedLinesCount, 0)
    }

    func testParseDiff_NewFile() {
        let output = """
diff --git a/new.swift b/new.swift
--- /dev/null
+++ b/new.swift
@@ -0,0 +1,2 @@
+line1
+line2
"""
        let diffs = parser.parseDiff(output)
        XCTAssertEqual(diffs.count, 1)
        XCTAssertEqual(diffs[0].oldPath, "")
        XCTAssertEqual(diffs[0].newPath, "b/new.swift")
        XCTAssertEqual(diffs[0].addedLinesCount, 2)
    }

    func testParseDiff_EmptyOutput() {
        let diffs = parser.parseDiff("")
        XCTAssertTrue(diffs.isEmpty)
    }

    func testParseDiff_MultipleFiles() {
        let output = """
diff --git a/file1.swift b/file1.swift
--- a/file1.swift
+++ b/file1.swift
@@ -1,1 +1,2 @@
 line1
+added1
diff --git a/file2.swift b/file2.swift
--- a/file2.swift
+++ b/file2.swift
@@ -1,1 +1,2 @@
 line1
+added2
"""
        let diffs = parser.parseDiff(output)
        XCTAssertEqual(diffs.count, 2)
        XCTAssertEqual(diffs[0].newPath, "b/file1.swift")
        XCTAssertEqual(diffs[1].newPath, "b/file2.swift")
    }

    // MARK: - parseLog

    func testParseLog_SingleCommit() {
        let sep = "\u{1E}"
        let recordSep = "\u{1F}"
        let output = "abc123\(sep)Author\(sep)a@b.com\(sep)1700000000\(sep)Author\(sep)a@b.com\(sep)1700000000\(sep)Test commit\(sep)\(sep)\(recordSep)"
        let commits = parser.parseLog(output)
        XCTAssertEqual(commits.count, 1)
        XCTAssertEqual(commits[0].sha, "abc123")
        XCTAssertEqual(commits[0].shortSha, "abc123")
        XCTAssertEqual(commits[0].authorName, "Author")
        XCTAssertEqual(commits[0].messageSubject, "Test commit")
        XCTAssertEqual(commits[0].messageBody, "")
    }

    func testParseLog_MultipleCommits() {
        let sep = "\u{1E}"
        let recordSep = "\u{1F}"
        let output = "sha1\(sep)A\(sep)a@b.com\(sep)1700000000\(sep)A\(sep)a@b.com\(sep)1700000000\(sep)Msg1\(sep)\(sep)\(recordSep)sha2\(sep)B\(sep)b@b.com\(sep)1700000001\(sep)B\(sep)b@b.com\(sep)1700000001\(sep)Msg2\(sep)\(sep)\(recordSep)"
        let commits = parser.parseLog(output)
        XCTAssertEqual(commits.count, 2)
        XCTAssertEqual(commits[0].sha, "sha1")
        XCTAssertEqual(commits[1].sha, "sha2")
    }

    func testParseLog_WithParents() {
        let sep = "\u{1E}"
        let recordSep = "\u{1F}"
        let output = "merge123\(sep)A\(sep)a@b.com\(sep)1700000000\(sep)A\(sep)a@b.com\(sep)1700000000\(sep)Merge\(sep)\(sep)parent1 parent2\(recordSep)"
        let commits = parser.parseLog(output)
        XCTAssertEqual(commits.count, 1)
        XCTAssertEqual(commits[0].parentShas, ["parent1", "parent2"])
    }

    func testParseLog_EmptyOutput() {
        let commits = parser.parseLog("")
        XCTAssertTrue(commits.isEmpty)
    }

    // MARK: - parseBranches

    func testParseBranches_CurrentAndRemote() {
        let output = "* main\n  feature\n  remotes/origin/main\n"
        let branches = parser.parseBranches(output)
        XCTAssertEqual(branches.count, 3)
        XCTAssertTrue(branches[0].isCurrent)
        XCTAssertEqual(branches[0].name, "main")
        XCTAssertFalse(branches[1].isCurrent)
        XCTAssertEqual(branches[1].name, "feature")
        XCTAssertTrue(branches[2].isRemote)
    }

    func testParseBranches_EmptyOutput() {
        let branches = parser.parseBranches("")
        XCTAssertTrue(branches.isEmpty)
    }

    // MARK: - logFormat

    func testLogFormat_ContainsFieldSeparators() {
        let format = parser.logFormat
        XCTAssertTrue(format.contains("\u{1E}"))
        XCTAssertTrue(format.contains("\u{1F}"))
    }

    func testLogFormat_ContainsPlaceholders() {
        let format = parser.logFormat
        XCTAssertTrue(format.contains("%H"))
        XCTAssertTrue(format.contains("%an"))
        XCTAssertTrue(format.contains("%ae"))
        XCTAssertTrue(format.contains("%s"))
        XCTAssertTrue(format.contains("%b"))
    }
}