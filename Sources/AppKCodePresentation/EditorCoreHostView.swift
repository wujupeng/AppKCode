import SwiftUI
import AppKit
import AppKCodeShared
import AppKCodeDomain
import AppKCodeInfrastructure

struct EditorCoreHostView: NSViewRepresentable {
    @ObservedObject var document: EditorDocument
    let editorState: EditorState
    let highlighterRegistry: SyntaxHighlighterRegistry

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        let textView = NSTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: editorState.fontSize, weight: .regular)
        textView.textColor = NSColor.textColor
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.delegate = context.coordinator
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true

        if let textStorage = textView.textStorage {
            textStorage.replaceCharacters(in: NSRange(location: 0, length: 0), with: document.content)
            applySyntaxHighlight(textStorage: textStorage)
        }

        let gutterView = GutterView(frame: NSRect(x: 0, y: 0, width: 50, height: scrollView.bounds.height))
        gutterView.autoresizingMask = [.height]
        scrollView.addSubview(gutterView)
        gutterView.textView = textView

        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.gutterView = gutterView
        context.coordinator.editorState = editorState
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        if let textStorage = textView.textStorage {
            let current = textStorage.string
            if current != document.content {
                let selectedRange = textView.selectedRange()
                textStorage.replaceCharacters(in: NSRange(location: 0, length: textStorage.length), with: document.content)
                textView.setSelectedRange(selectedRange)
                applySyntaxHighlight(textStorage: textStorage)
            }
        }
        context.coordinator.gutterView?.needsDisplay = true
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(document: document)
    }

    private func applySyntaxHighlight(textStorage: NSTextStorage) {
        let fullText = textStorage.string
        let language = editorState.document.language
        guard let highlighter = highlighterRegistry.highlighter(for: language) else { return }

        let font = NSFont.monospacedSystemFont(ofSize: editorState.fontSize, weight: .regular)
        textStorage.removeAttribute(.font, range: NSRange(location: 0, length: textStorage.length))
        textStorage.addAttribute(.font, value: font, range: NSRange(location: 0, length: textStorage.length))

        let tokens = highlighter.tokenize(fullText)
        for token in tokens {
            let nsRange = NSRange(location: token.range.start.offset,
                                   length: token.range.end.offset - token.range.start.offset)
            if nsRange.location + nsRange.length <= textStorage.length {
                textStorage.addAttribute(.foregroundColor, value: colorForToken(token.type), range: nsRange)
            }
        }
    }

    private func colorForToken(_ type: SyntaxTokenType) -> NSColor {
        switch type {
        case .keyword: return NSColor(red: 0.5, green: 0.2, blue: 0.8, alpha: 1.0)
        case .string: return NSColor(red: 0.2, green: 0.6, blue: 0.2, alpha: 1.0)
        case .comment: return NSColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
        case .number: return NSColor(red: 0.8, green: 0.4, blue: 0.1, alpha: 1.0)
        case .type: return NSColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0)
        case .function: return NSColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1.0)
        case .identifier: return NSColor.textColor
        case .operator: return NSColor(red: 0.6, green: 0.3, blue: 0.3, alpha: 1.0)
        case .punctuation: return NSColor.textColor
        case .attribute: return NSColor(red: 0.6, green: 0.3, blue: 0.6, alpha: 1.0)
        case .plain: return NSColor.textColor
        case .heading: return NSColor(red: 0.2, green: 0.2, blue: 0.8, alpha: 1.0)
        case .link: return NSColor(red: 0.1, green: 0.4, blue: 0.8, alpha: 1.0)
        case .key: return NSColor(red: 0.5, green: 0.2, blue: 0.8, alpha: 1.0)
        case .value: return NSColor(red: 0.2, green: 0.6, blue: 0.2, alpha: 1.0)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        weak var textView: NSTextView?
        weak var gutterView: GutterView?
        var editorState: EditorState?
        let document: EditorDocument

        init(document: EditorDocument) {
            self.document = document
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = textView else { return }
            let newContent = textView.string
            DispatchQueue.main.async { [weak self] in
                self?.document.updateContent(newContent)
            }
            gutterView?.needsDisplay = true
        }
    }
}

final class GutterView: NSView {
    weak var textView: NSTextView?
    private let lineNumberFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
    private let backgroundColor = NSColor(white: 0.95, alpha: 1.0)
    private let textColor = NSColor(white: 0.5, alpha: 1.0)
    private let currentLineTextColor = NSColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0)

    override func draw(_ dirtyRect: NSRect) {
        backgroundColor.setFill()
        dirtyRect.fill()

        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        let text = textView.string
        let lineCount = text.split(separator: "\n").count + (text.isEmpty ? 0 : 1)
        let currentLine = currentLineNumber(textView: textView)

        let attrs: [NSAttributedString.Key: Any] = [.font: lineNumberFont, .foregroundColor: textColor]
        let currentAttrs: [NSAttributedString.Key: Any] = [.font: lineNumberFont, .foregroundColor: currentLineTextColor]

        for line in 1...max(lineCount, 1) {
            let y = CGFloat(line - 1) * (textView.font?.boundingRectForFont.height ?? 16) + 4
            if y > dirtyRect.maxY { break }
            let lineNumber = "\(line)"
            let useAttrs = (line == currentLine) ? currentAttrs : attrs
            (lineNumber as NSString).draw(at: NSPoint(x: 8, y: y), withAttributes: useAttrs)
        }

        _ = layoutManager
        _ = textContainer
    }

    private func currentLineNumber(textView: NSTextView) -> Int {
        let cursorLocation = textView.selectedRange().location
        let text = textView.string
        let prefix = (text as NSString).substring(to: min(cursorLocation, (text as NSString).length))
        return prefix.split(separator: "\n").count + 1
    }
}