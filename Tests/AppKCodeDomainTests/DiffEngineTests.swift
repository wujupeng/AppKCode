import XCTest
@testable import AppKCodeShared

final class DiffEngineTests: XCTestCase {
    func testIdenticalContentProducesNoHunks() {
        let content = "line1\nline2\nline3"
        let hunks = DiffEngine.computeDiff(old: content, new: content)
        XCTAssertTrue(hunks.isEmpty, "Identical content should produce no hunks")
    }

    func testAddedLine() {
        let old = "line1\nline3"
        let new = "line1\nline2\nline3"
        let hunks = DiffEngine.computeDiff(old: old, new: new)
        XCTAssertFalse(hunks.isEmpty, "Added line should produce hunks")
        let addedLines = hunks.flatMap { $0.lines }.filter { $0.changeType == .added }
        XCTAssertFalse(addedLines.isEmpty, "Should have added lines")
    }

    func testRemovedLine() {
        let old = "line1\nline2\nline3"
        let new = "line1\nline3"
        let hunks = DiffEngine.computeDiff(old: old, new: new)
        XCTAssertFalse(hunks.isEmpty)
        let removedLines = hunks.flatMap { $0.lines }.filter { $0.changeType == .removed }
        XCTAssertFalse(removedLines.isEmpty, "Should have removed lines")
    }

    func testApplyAcceptedHunks() {
        let old = "line1\nline3"
        let new = "line1\nline2\nline3"
        let hunks = DiffEngine.computeDiff(old: old, new: new)
        let acceptedIndices = Set(hunks.indices)
        let result = DiffEngine.applyHunks(hunks, to: old, acceptedHunkIndices: acceptedIndices)
        XCTAssertEqual(result, new, "Applying all accepted hunks should produce new content")
    }

    func testRejectAllHunks() {
        let old = "line1\nline3"
        let new = "line1\nline2\nline3"
        let hunks = DiffEngine.computeDiff(old: old, new: new)
        let result = DiffEngine.applyHunks(hunks, to: old, acceptedHunkIndices: [])
        XCTAssertEqual(result, old, "Rejecting all hunks should keep original content")
    }
}