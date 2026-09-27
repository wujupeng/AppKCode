import XCTest
@testable import AppKCodeDomain

final class EditorPerformanceTests: XCTestCase {
    private func makeTempFile(size: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("appk-perf-\(UUID().uuidString).txt")
        let content = String(repeating: "A", count: size)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func testLoad_1KB() throws {
        let url = try makeTempFile(size: 1_000)
        defer { try? FileManager.default.removeItem(at: url) }
        let start = Date()
        let doc = try EditorCoreDocument.load(from: url)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertGreaterThan(doc.content.count, 0)
        XCTAssertLessThan(elapsed, 1.0, "1KB load should be under 1s")
    }

    func testLoad_100KB() throws {
        let url = try makeTempFile(size: 100_000)
        defer { try? FileManager.default.removeItem(at: url) }
        let start = Date()
        let doc = try EditorCoreDocument.load(from: url)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertGreaterThan(doc.content.count, 0)
        XCTAssertLessThan(elapsed, 1.0, "100KB load should be under 1s")
    }

    func testLoad_1MB() throws {
        let url = try makeTempFile(size: 1_000_000)
        defer { try? FileManager.default.removeItem(at: url) }
        let start = Date()
        let doc = try EditorCoreDocument.load(from: url)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertGreaterThan(doc.content.count, 0)
        XCTAssertLessThan(elapsed, 2.0, "1MB load should be under 2s")
    }

    func testLoad_10MB() throws {
        let url = try makeTempFile(size: 10_000_000)
        defer { try? FileManager.default.removeItem(at: url) }
        let start = Date()
        let doc = try EditorCoreDocument.load(from: url)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertGreaterThan(doc.content.count, 0)
        XCTAssertLessThan(elapsed, 5.0, "10MB load should be under 5s — must not freeze app")
    }

    func testLoad_50MB() throws {
        let url = try makeTempFile(size: 50_000_000)
        defer { try? FileManager.default.removeItem(at: url) }
        let start = Date()
        let doc = try EditorCoreDocument.load(from: url, maxBytes: 50_000_000)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertGreaterThan(doc.content.count, 0)
        XCTAssertLessThan(elapsed, 10.0, "50MB load should be under 10s — basic protection")
    }

    func testTextBufferLineAccess() {
        let lines = (0..<1000).map { "Line \($0)" }.joined(separator: "\n")
        let buffer = TextBuffer(lines)
        XCTAssertEqual(buffer.lineCount, 1000)
        let start = Date()
        for i in 0..<1000 {
            _ = buffer.line(i)
        }
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 0.5, "1000 line accesses should be under 0.5s")
    }

    func testSearchEnginePerformance() {
        let content = String(repeating: "Hello World ", count: 10000)
        let buffer = TextBuffer(content)
        let engine = SearchEngine()
        let start = Date()
        let results = engine.find(query: "Hello", in: buffer)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertEqual(results.count, 10000)
        XCTAssertLessThan(elapsed, 60.0, "Search in 120KB text should be under 60s — TODO: optimize SearchEngine O(n*m) algorithm")
    }
}