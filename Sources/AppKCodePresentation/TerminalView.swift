import SwiftUI
import AppKit
import AppKCodeShared
import AppKCodeInfrastructure
import AppKCodeDomain

struct TerminalView: NSViewRepresentable {
    @ObservedObject var viewModel: TerminalViewModel

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = NSColor.textColor
        textView.backgroundColor = NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        textView.isRichText = true
        textView.allowsBackgroundColor = true

        scrollView.documentView = textView
        context.coordinator.textView = textView
        viewModel.start()
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        if viewModel.attributedOutput.length > 0 && textView.string != viewModel.plainOutput {
            textView.textStorage?.setAttributedString(viewModel.attributedOutput)
            textView.scrollToEndOfDocument(nil)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    final class Coordinator: NSObject {
        weak var textView: NSTextView?
        let viewModel: TerminalViewModel
        init(viewModel: TerminalViewModel) { self.viewModel = viewModel }
    }
}

final class TerminalViewModel: ObservableObject {
    @Published var plainOutput: String = ""
    @Published var attributedOutput: NSAttributedString = NSAttributedString()
    private let session: TerminalSession
    private var readTask: Task<Void, Never>?
    private let renderer = TerminalRenderer()

    init(rows: Int = 50, cols: Int = 200) {
        self.session = TerminalSession(rows: rows, cols: cols)
    }

    func start() {
        guard readTask == nil else { return }
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let command = Command(executable: shell, arguments: [], environment: [:])
        do {
            try session.start(command: command)
            startReading()
        } catch {
            plainOutput = "无法创建终端，请关闭其他终端后重试\n"
            attributedOutput = NSAttributedString(string: plainOutput)
        }
    }

    private func startReading() {
        readTask = Task { [weak self] in
            guard let self = self else { return }
            while !Task.isCancelled && self.session.isRunning {
                let data = await self.session.pty.read()
                if !data.isEmpty {
                    self.session.parser.parse(data)
                    let rendered = self.renderer.renderAttributedString(from: self.session.parser.grid)
                    let plain = self.renderer.renderText(from: self.session.parser.grid)
                    await MainActor.run {
                        self.attributedOutput = rendered
                        self.plainOutput = plain
                    }
                }
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
        }
    }

    func sendInput(_ text: String) {
        try? session.sendInput(text)
    }

    func resize(cols: Int, rows: Int) {
        session.resize(cols: cols, rows: rows)
    }

    func stop() {
        readTask?.cancel()
        readTask = nil
        session.close()
    }

    deinit { stop() }
}
