import Foundation
#if canImport(AppKit)
import AppKit
#endif

public final class TerminalRenderer: @unchecked Sendable {
    public init() {}

    public func renderText(from grid: [[TerminalCell]]) -> String {
        grid.map { row in
            row.map { String($0.character) }.joined()
        }.joined(separator: "\n")
    }

    public func renderLine(_ row: [TerminalCell]) -> String {
        row.map { String($0.character) }.joined()
    }

    #if canImport(AppKit)
    public func renderAttributedString(from grid: [[TerminalCell]]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for (rowIndex, row) in grid.enumerated() {
            let lineStr = renderLine(row)
            let attributed = NSMutableAttributedString(string: lineStr)
            var col = 0
            for cell in row {
                if col < attributed.length {
                    let range = NSRange(location: col, length: 1)
                    var attributes: [NSAttributedString.Key: Any] = [:]
                    if cell.foregroundColor != .default {
                        attributes[.foregroundColor] = nsColor(for: cell.foregroundColor)
                    }
                    if cell.backgroundColor != .default {
                        attributes[.backgroundColor] = nsColor(for: cell.backgroundColor)
                    }
                    if cell.bold {
                        attributes[.font] = NSFont.monospacedSystemFont(ofSize: 13, weight: .bold)
                    }
                    attributed.addAttributes(attributes, range: range)
                }
                col += 1
            }
            result.append(attributed)
            if rowIndex < grid.count - 1 {
                result.append(NSAttributedString(string: "\n"))
            }
        }
        return result
    }

    private func nsColor(for terminalColor: TerminalColor) -> NSColor {
        switch terminalColor {
        case .default: return NSColor.textColor
        case .black: return NSColor.black
        case .red: return NSColor(red: 0.8, green: 0.0, blue: 0.0, alpha: 1.0)
        case .green: return NSColor(red: 0.0, green: 0.7, blue: 0.0, alpha: 1.0)
        case .yellow: return NSColor(red: 0.8, green: 0.7, blue: 0.0, alpha: 1.0)
        case .blue: return NSColor(red: 0.0, green: 0.0, blue: 0.8, alpha: 1.0)
        case .magenta: return NSColor(red: 0.7, green: 0.0, blue: 0.7, alpha: 1.0)
        case .cyan: return NSColor(red: 0.0, green: 0.7, blue: 0.7, alpha: 1.0)
        case .white: return NSColor.white
        case .brightBlack: return NSColor.darkGray
        case .brightRed: return NSColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 1.0)
        case .brightGreen: return NSColor(red: 0.2, green: 1.0, blue: 0.2, alpha: 1.0)
        case .brightYellow: return NSColor(red: 1.0, green: 1.0, blue: 0.2, alpha: 1.0)
        case .brightBlue: return NSColor(red: 0.2, green: 0.2, blue: 1.0, alpha: 1.0)
        case .brightMagenta: return NSColor(red: 1.0, green: 0.2, blue: 1.0, alpha: 1.0)
        case .brightCyan: return NSColor(red: 0.2, green: 1.0, blue: 1.0, alpha: 1.0)
        case .brightWhite: return NSColor(white: 0.9, alpha: 1.0)
        case .color256(let n): return color256(n)
        }
    }

    private func color256(_ n: Int) -> NSColor {
        if n < 16 {
            let basic: [TerminalColor] = [.black, .red, .green, .yellow, .blue, .magenta, .cyan, .white,
                                          .brightBlack, .brightRed, .brightGreen, .brightYellow, .brightBlue, .brightMagenta, .brightCyan, .brightWhite]
            return nsColor(for: basic[n])
        }
        if n >= 232 {
            let gray = 8 + (n - 232) * 10
            let v = CGFloat(gray) / 255.0
            return NSColor(white: v, alpha: 1.0)
        }
        let i = n - 16
        let r = i / 36
        let g = (i % 36) / 6
        let b = i % 6
        let component: (Int) -> CGFloat = { idx in
            idx == 0 ? 0 : CGFloat(55 + idx * 40) / 255.0
        }
        return NSColor(red: component(r), green: component(g), blue: component(b), alpha: 1.0)
    }
    #endif
}