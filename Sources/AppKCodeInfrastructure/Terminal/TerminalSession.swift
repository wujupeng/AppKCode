import Foundation
import AppKCodeShared

public final class TerminalSession: @unchecked Sendable {
    public let id: TerminalSessionID
    public private(set) var pty: PTYManager
    public private(set) var parser: VT100Parser
    public private(set) var buffer: TerminalBuffer
    public private(set) var renderer: TerminalRenderer
    public private(set) var isRunning: Bool = false

    public var onOutput: ((Data) -> Void)? = nil
    public var onExit: ((Int32) -> Void)? = nil

    private var readTask: Task<Void, Never>? = nil

    public init(rows: Int = 50, cols: Int = 200) {
        self.id = TerminalSessionID()
        self.pty = PTYManager()
        self.parser = VT100Parser(rows: rows, cols: cols)
        self.buffer = TerminalBuffer(rows: rows, cols: cols)
        self.renderer = TerminalRenderer()
    }

    public func start(command: Command) throws {
        try pty.spawn(command: command)
        isRunning = true

        pty.onExit = { [weak self] code in
            self?.isRunning = false
            self?.onExit?(code)
        }

        readTask = Task { [weak self] in
            guard let self = self else { return }
            while self.isRunning && self.pty.masterFD >= 0 {
                let data = await self.pty.read()
                if !data.isEmpty {
                    self.parser.parse(data)
                    self.onOutput?(data)
                } else {
                    try? await Task.sleep(nanoseconds: 10_000_000)
                }
            }
        }
    }

    public func sendInput(_ text: String) throws {
        try pty.writeString(text)
    }

    public func resize(cols: Int, rows: Int) {
        pty.resize(cols: cols, rows: rows)
        buffer.resize(rows: rows, cols: cols)
    }

    public func close() {
        isRunning = false
        readTask?.cancel()
        readTask = nil
        pty.close()
    }

    public func renderText() -> String {
        renderer.renderText(from: parser.grid)
    }

    #if canImport(AppKit)
    public func renderAttributedString() -> NSAttributedString {
        renderer.renderAttributedString(from: parser.grid)
    }
    #endif

    deinit { close() }
}

public struct TerminalSessionID: Sendable, Equatable, Hashable {
    public let rawValue: UUID
    public init() { self.rawValue = UUID() }
    public init(_ value: UUID) { self.rawValue = value }
}