import Foundation

public final class TerminalBuffer: @unchecked Sendable {
    public private(set) var visibleRows: [[TerminalCell]]
    public private(set) var historyRows: [[TerminalCell]]
    public private(set) var cursorRow: Int = 0
    public private(set) var cursorCol: Int = 0
    public private(set) var maxCols: Int

    private let maxVisibleRows: Int
    private let maxHistoryRows: Int

    public init(rows: Int = 50, cols: Int = 200, maxHistory: Int = 10000) {
        self.maxVisibleRows = rows
        self.maxCols = cols
        self.maxHistoryRows = maxHistory
        self.visibleRows = Array(repeating: Array(repeating: TerminalCell(), count: cols), count: rows)
        self.historyRows = []
    }

    public func resize(rows: Int, cols: Int) {
        maxCols = cols
        if rows > maxVisibleRows {
            let extra = rows - maxVisibleRows
            for _ in 0..<extra {
                visibleRows.append(Array(repeating: TerminalCell(), count: cols))
            }
        } else if rows < maxVisibleRows {
            let removed = maxVisibleRows - rows
            for _ in 0..<removed {
                let row = visibleRows.removeFirst()
                historyRows.append(row)
            }
        }
    }

    public func writeCell(_ cell: TerminalCell, at row: Int, col: Int) {
        guard row >= 0 && row < visibleRows.count && col >= 0 && col < maxCols else { return }
        visibleRows[row][col] = cell
    }

    public func scrollUp(_ lines: Int) {
        for _ in 0..<lines {
            if !visibleRows.isEmpty {
                let row = visibleRows.removeFirst()
                historyRows.append(row)
                visibleRows.append(Array(repeating: TerminalCell(), count: maxCols))
            }
        }
        trimHistory()
    }

    public func clearVisible() {
        visibleRows = Array(repeating: Array(repeating: TerminalCell(), count: maxCols), count: maxVisibleRows)
    }

    public func clearHistory() {
        historyRows = []
    }

    public func clearAll() {
        clearVisible()
        clearHistory()
    }

    public var totalRows: Int {
        historyRows.count + visibleRows.count
    }

    public func row(at index: Int) -> [TerminalCell]? {
        if index < historyRows.count {
            return historyRows[index]
        }
        let visibleIndex = index - historyRows.count
        if visibleIndex < visibleRows.count {
            return visibleRows[visibleIndex]
        }
        return nil
    }

    private func trimHistory() {
        while historyRows.count > maxHistoryRows {
            historyRows.removeFirst()
        }
    }
}