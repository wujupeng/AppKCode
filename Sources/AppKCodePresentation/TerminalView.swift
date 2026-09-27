import SwiftUI
import AppKit
import AppKCodeShared
import AppKCodeInfrastructure

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
        textView.isRichText = false

        scrollView.documentView = textView
        context.coordinator.textView = textView
        viewModel.start()
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        if textView.string != viewModel.output {
            let oldUTF16 = (textView.string as NSString).length
            let newUTF16 = (viewModel.output as NSString).length
            if newUTF16 > oldUTF16 {
                let appended = (viewModel.output as NSString).substring(from: oldUTF16)
                textView.replaceCharacters(in: NSRange(location: oldUTF16, length: 0), with: appended)
                textView.scrollToEndOfDocument(nil)
            }
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
    @Published var output: String = ""
    private let ptyManager = PTYManager()
    private let parser = VT100Parser()
    private var readTask: Task<Void, Never>?

    func start() {
        guard readTask == nil else { return }
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        do {
            try ptyManager.spawn(shell: shell)
            startReading()
        } catch {
            output = "无法创建终端，请关闭其他终端后重试\n"
        }
    }

    private func startReading() {
        readTask = Task { [weak self] in
            guard let self = self else { return }
            while !Task.isCancelled && self.ptyManager.isAlive {
                let data = await self.ptyManager.read()
                if !data.isEmpty {
                    self.parser.parse(data)
                    let rendered = self.parser.renderText()
                    await MainActor.run {
                        self.output = rendered
                    }
                }
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
        }
    }

    func sendInput(_ text: String) {
        try? ptyManager.writeString(text)
    }

    func stop() {
        readTask?.cancel()
        readTask = nil
        ptyManager.close()
    }

    deinit { stop() }
}