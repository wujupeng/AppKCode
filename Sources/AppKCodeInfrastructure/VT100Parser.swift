import Foundation

public struct TerminalCell: Equatable {
    public var character: Character
    public var foregroundColor: TerminalColor
    public var backgroundColor: TerminalColor
    public var bold: Bool
    public var italic: Bool

    public init(character: Character = " ", foregroundColor: TerminalColor = .default, backgroundColor: TerminalColor = .default, bold: Bool = false, italic: Bool = false) {
        self.character = character
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.bold = bold
        self.italic = italic
    }
}

public enum TerminalColor: Equatable {
    case `default`, black, red, green, yellow, blue, magenta, cyan, white
    case brightBlack, brightRed, brightGreen, brightYellow, brightBlue, brightMagenta, brightCyan, brightWhite
    case color256(Int)
}

public final class VT100Parser: @unchecked Sendable {
    public private(set) var grid: [[TerminalCell]]
    public private(set) var cursorRow: Int = 0
    public private(set) var cursorCol: Int = 0
    public private(set) var currentFgColor: TerminalColor = .default
    public private(set) var currentBgColor: TerminalColor = .default
    public private(set) var bold: Bool = false
    public private(set) var cursorVisible: Bool = true
    public private(set) var alternateScreenActive: Bool = false

    private var alternateGrid: [[TerminalCell]]? = nil
    private var alternateCursorRow: Int = 0
    private var alternateCursorCol: Int = 0

    private let maxRows: Int
    private let maxCols: Int

    public init(rows: Int = 50, cols: Int = 200) {
        self.maxRows = rows
        self.maxCols = cols
        self.grid = Array(repeating: Array(repeating: TerminalCell(), count: cols), count: rows)
    }

    public var cursorPosition: (row: Int, col: Int) {
        (cursorRow, cursorCol)
    }

    public func parse(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        var i = text.startIndex
        while i < text.endIndex {
            let ch = text[i]
            if ch == "\u{1B}" {
                let next = text.index(after: i)
                if next < text.endIndex && text[next] == "[" {
                    i = parseEscapeSequence(text, from: next)
                    continue
                }
            }
            if ch == "\n" {
                cursorRow += 1
                cursorCol = 0
                ensureCapacity()
            } else if ch == "\r" {
                cursorCol = 0
            } else if ch == "\t" {
                cursorCol = ((cursorCol / 8) + 1) * 8
                ensureCapacity()
            } else if ch != "\u{1B}" {
                if cursorCol < maxCols && cursorRow < maxRows {
                    grid[cursorRow][cursorCol].character = ch
                    grid[cursorRow][cursorCol].foregroundColor = currentFgColor
                    grid[cursorRow][cursorCol].backgroundColor = currentBgColor
                    grid[cursorRow][cursorCol].bold = bold
                }
                cursorCol += 1
                ensureCapacity()
            }
            i = text.index(after: i)
        }
    }

    private func parseEscapeSequence(_ text: String, from start: String.Index) -> String.Index {
        var i = text.index(after: start)

        if i < text.endIndex && text[i] == "?" {
            return parsePrivateMode(text, from: i)
        }

        var params: [Int] = []
        var currentParam = ""

        while i < text.endIndex {
            let ch = text[i]
            if ch.isNumber {
                currentParam.append(ch)
            } else if ch == ";" {
                if let p = Int(currentParam) { params.append(p) }
                currentParam = ""
            } else if ch == "m" {
                if !currentParam.isEmpty, let p = Int(currentParam) { params.append(p) }
                applySGR(params)
                return text.index(after: i)
            } else if ch == "H" || ch == "f" {
                if !currentParam.isEmpty, let p = Int(currentParam) { params.append(p) }
                let row = params.count > 0 ? params[0] - 1 : 0
                let col = params.count > 1 ? params[1] - 1 : 0
                cursorRow = max(0, min(row, maxRows - 1))
                cursorCol = max(0, min(col, maxCols - 1))
                return text.index(after: i)
            } else if ch == "J" {
                if !currentParam.isEmpty, let p = Int(currentParam) { params.append(p) }
                clearScreen(mode: params.first ?? 0)
                return text.index(after: i)
            } else if ch == "K" {
                clearLine()
                return text.index(after: i)
            } else if ch == "A" {
                cursorRow = max(0, cursorRow - (params.first ?? 1))
                return text.index(after: i)
            } else if ch == "B" {
                cursorRow = min(maxRows - 1, cursorRow + (params.first ?? 1))
                return text.index(after: i)
            } else if ch == "C" {
                cursorCol = min(maxCols - 1, cursorCol + (params.first ?? 1))
                return text.index(after: i)
            } else if ch == "D" {
                cursorCol = max(0, cursorCol - (params.first ?? 1))
                return text.index(after: i)
            }
            i = text.index(after: i)
        }
        return i
    }

    private func parsePrivateMode(_ text: String, from start: String.Index) -> String.Index {
        var i = start
        var paramStr = ""
        while i < text.endIndex {
            let ch = text[i]
            if ch.isNumber {
                paramStr.append(ch)
            } else if ch == "h" {
                applyPrivateMode(paramStr, enable: true)
                return text.index(after: i)
            } else if ch == "l" {
                applyPrivateMode(paramStr, enable: false)
                return text.index(after: i)
            }
            i = text.index(after: i)
        }
        return i
    }

    private func applyPrivateMode(_ param: String, enable: Bool) {
        switch param {
        case "25":
            cursorVisible = enable
        case "1049":
            if enable {
                if alternateGrid == nil {
                    alternateGrid = grid
                    alternateCursorRow = cursorRow
                    alternateCursorCol = cursorCol
                    grid = Array(repeating: Array(repeating: TerminalCell(), count: maxCols), count: maxRows)
                    cursorRow = 0
                    cursorCol = 0
                }
                alternateScreenActive = true
            } else {
                if let saved = alternateGrid {
                    grid = saved
                    cursorRow = alternateCursorRow
                    cursorCol = alternateCursorCol
                    alternateGrid = nil
                }
                alternateScreenActive = false
            }
        default:
            break
        }
    }

    private func applySGR(_ params: [Int]) {
        if params.isEmpty {
            currentFgColor = .default; currentBgColor = .default; bold = false
            return
        }

        var i = 0
        while i < params.count {
            let p = params[i]
            switch p {
            case 0: currentFgColor = .default; currentBgColor = .default; bold = false
            case 1: bold = true
            case 30: currentFgColor = .black
            case 31: currentFgColor = .red
            case 32: currentFgColor = .green
            case 33: currentFgColor = .yellow
            case 34: currentFgColor = .blue
            case 35: currentFgColor = .magenta
            case 36: currentFgColor = .cyan
            case 37: currentFgColor = .white
            case 90: currentFgColor = .brightBlack
            case 91: currentFgColor = .brightRed
            case 92: currentFgColor = .brightGreen
            case 93: currentFgColor = .brightYellow
            case 94: currentFgColor = .brightBlue
            case 95: currentFgColor = .brightMagenta
            case 96: currentFgColor = .brightCyan
            case 97: currentFgColor = .brightWhite
            case 40: currentBgColor = .black
            case 41: currentBgColor = .red
            case 42: currentBgColor = .green
            case 43: currentBgColor = .yellow
            case 44: currentBgColor = .blue
            case 45: currentBgColor = .magenta
            case 46: currentBgColor = .cyan
            case 47: currentBgColor = .white
            case 38:
                if i + 2 < params.count && params[i + 1] == 5 {
                    currentFgColor = .color256(params[i + 2])
                    i += 2
                }
            case 48:
                if i + 2 < params.count && params[i + 1] == 5 {
                    currentBgColor = .color256(params[i + 2])
                    i += 2
                }
            default: break
            }
            i += 1
        }
    }

    private func clearScreen(mode: Int) {
        if mode == 2 || mode == 0 {
            grid = Array(repeating: Array(repeating: TerminalCell(), count: maxCols), count: maxRows)
        }
    }

    private func clearLine() {
        if cursorRow < maxRows {
            grid[cursorRow] = Array(repeating: TerminalCell(), count: maxCols)
        }
    }

    private func ensureCapacity() {
        if cursorRow >= maxRows {
            grid.removeFirst(cursorRow - maxRows + 1)
            grid.append(Array(repeating: TerminalCell(), count: maxCols))
            cursorRow = maxRows - 1
        }
    }

    public func renderText() -> String {
        grid.map { row in
            String(row.map { $0.character }.prefix(while: { $0 != " " }).count > 0
                  ? row.map { String($0.character) }.joined()
                  : "")
        }.joined(separator: "\n")
    }
}
