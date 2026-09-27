import XCTest
@testable import AppKCodeInfrastructure

final class VT100ParserExtendedTests: XCTestCase {
    func test256ColorForeground() {
        let parser = VT100Parser()
        let escape = "\u{1B}[38;5;196mX"
        parser.parse(Data(escape.utf8))
        XCTAssertEqual(parser.currentFgColor, .color256(196))
    }

    func test256ColorBackground() {
        let parser = VT100Parser()
        let escape = "\u{1B}[48;5;21mX"
        parser.parse(Data(escape.utf8))
        XCTAssertEqual(parser.currentBgColor, .color256(21))
    }

    func testCursorVisibleHide() {
        let parser = VT100Parser()
        let escape = "\u{1B}[?25l"
        parser.parse(Data(escape.utf8))
        XCTAssertFalse(parser.cursorVisible)
    }

    func testCursorVisibleShow() {
        let parser = VT100Parser()
        let hideShow = "\u{1B}[?25l\u{1B}[?25h"
        parser.parse(Data(hideShow.utf8))
        XCTAssertTrue(parser.cursorVisible)
    }

    func testAlternateScreenEnter() {
        let parser = VT100Parser()
        parser.parse(Data("hello".utf8))
        let enterAlt = "\u{1B}[?1049h"
        parser.parse(Data(enterAlt.utf8))
        XCTAssertTrue(parser.alternateScreenActive)
    }

    func testAlternateScreenExit() {
        let parser = VT100Parser()
        parser.parse(Data("hello".utf8))
        let enterExit = "\u{1B}[?1049h\u{1B}[?1049l"
        parser.parse(Data(enterExit.utf8))
        XCTAssertFalse(parser.alternateScreenActive)
    }

    func testCursorPosition() {
        let parser = VT100Parser()
        let move = "\u{1B}[5;10H"
        parser.parse(Data(move.utf8))
        XCTAssertEqual(parser.cursorPosition.row, 4)
        XCTAssertEqual(parser.cursorPosition.col, 9)
    }

    func testM0CompatBasicText() {
        let parser = VT100Parser()
        parser.parse(Data("hello\nworld".utf8))
        let text = parser.renderText()
        XCTAssertTrue(text.contains("hello"))
        XCTAssertTrue(text.contains("world"))
    }

    func testM0Compat16Color() {
        let parser = VT100Parser()
        let escape = "\u{1B}[31mR\u{1B}[0m"
        parser.parse(Data(escape.utf8))
        XCTAssertTrue(parser.grid[0][0].character == "R")
    }

    func testM0CompatClearScreen() {
        let parser = VT100Parser()
        parser.parse(Data("hello".utf8))
        parser.parse(Data("\u{1B}[2J".utf8))
        XCTAssertEqual(parser.grid[0][0].character, " ")
    }
}

final class TerminalBufferTests: XCTestCase {
    func testBufferCreation() {
        let buffer = TerminalBuffer(rows: 10, cols: 80)
        XCTAssertEqual(buffer.visibleRows.count, 10)
        XCTAssertEqual(buffer.maxCols, 80)
        XCTAssertEqual(buffer.historyRows.count, 0)
    }

    func testBufferScrollUp() {
        let buffer = TerminalBuffer(rows: 5, cols: 10)
        buffer.scrollUp(2)
        XCTAssertEqual(buffer.historyRows.count, 2)
        XCTAssertEqual(buffer.visibleRows.count, 5)
    }

    func testBufferClearVisible() {
        let buffer = TerminalBuffer(rows: 5, cols: 10)
        buffer.writeCell(TerminalCell(character: "X"), at: 0, col: 0)
        buffer.clearVisible()
        XCTAssertEqual(buffer.visibleRows[0][0].character, " ")
    }

    func testBufferClearAll() {
        let buffer = TerminalBuffer(rows: 5, cols: 10)
        buffer.scrollUp(3)
        buffer.clearAll()
        XCTAssertEqual(buffer.historyRows.count, 0)
        XCTAssertEqual(buffer.visibleRows.count, 5)
    }

    func testBufferResize() {
        let buffer = TerminalBuffer(rows: 10, cols: 80)
        buffer.resize(rows: 20, cols: 100)
        XCTAssertEqual(buffer.maxCols, 100)
    }

    func testBufferTotalRows() {
        let buffer = TerminalBuffer(rows: 5, cols: 10)
        buffer.scrollUp(3)
        XCTAssertEqual(buffer.totalRows, 8)
    }
}

final class TerminalRendererTests: XCTestCase {
    func testRenderText() {
        let renderer = TerminalRenderer()
        let grid: [[TerminalCell]] = [
            [TerminalCell(character: "h"), TerminalCell(character: "i")],
            [TerminalCell(character: "b"), TerminalCell(character: "y"), TerminalCell(character: "e")]
        ]
        let text = renderer.renderText(from: grid)
        XCTAssertEqual(text, "hi\nbye")
    }

    func testRenderLine() {
        let renderer = TerminalRenderer()
        let row: [TerminalCell] = [TerminalCell(character: "A"), TerminalCell(character: "B")]
        XCTAssertEqual(renderer.renderLine(row), "AB")
    }
}