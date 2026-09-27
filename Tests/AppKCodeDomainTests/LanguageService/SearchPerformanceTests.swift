import XCTest
@testable import AppKCodeDomain

final class SearchPerformanceTests: XCTestCase {
    func testSearchPerformance_120KB_10000Matches() {
        let content = String(repeating: "Hello World ", count: 10000)
        let buffer = TextBuffer(content)
        let engine = SearchEngine()
        let start = Date()
        let results = engine.find(query: "Hello", in: buffer)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertEqual(results.count, 10000)
        XCTAssertLessThan(elapsed, 1.0, "120KB / 10000 matches should be < 1s (H6)")
    }

    func testSearchPerformance_1MB() {
        let content = String(repeating: "Hello World ", count: 100000)
        let buffer = TextBuffer(content)
        let engine = SearchEngine()
        let start = Date()
        let results = engine.find(query: "Hello", in: buffer)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertEqual(results.count, 100000)
        XCTAssertLessThan(elapsed, 2.0, "1MB search should be < 2s (H6)")
    }

    func testSearchPerformance_10MB() {
        let content = String(repeating: "Hello World ", count: 1000000)
        let buffer = TextBuffer(content)
        let engine = SearchEngine()
        let start = Date()
        let results = engine.find(query: "Hello", in: buffer)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertEqual(results.count, 1000000)
        XCTAssertLessThan(elapsed, 10.0, "10MB search should be < 10s (H6)")
    }

    func testSearchPerformance_CaseInsensitive() {
        let content = String(repeating: "Hello World ", count: 10000)
        let buffer = TextBuffer(content)
        let engine = SearchEngine()
        let start = Date()
        let results = engine.find(query: "hello", in: buffer)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertEqual(results.count, 10000)
        XCTAssertLessThan(elapsed, 1.0, "Case-insensitive 120KB should be < 1s (H6)")
    }

    func testSearchPerformance_NoMatch() {
        let content = String(repeating: "Hello World ", count: 10000)
        let buffer = TextBuffer(content)
        let engine = SearchEngine()
        let start = Date()
        let results = engine.find(query: "NotFound", in: buffer)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertEqual(results.count, 0)
        XCTAssertLessThan(elapsed, 0.5, "No match search should be fast")
    }
}