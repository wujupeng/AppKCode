import SwiftUI
import AppKit
import AppKCodeShared

struct EditorView: View {
    @ObservedObject var viewModel: EditorViewModel

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            if let doc = viewModel.activeDocument {
                CodeEditorView(document: doc)
            } else {
                emptyState
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .appkFileOpenRequested)) { notification in
            if let url = notification.object as? URL {
                viewModel.openFile(url)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .appkSaveRequested)) { _ in
            viewModel.saveActiveDocument()
        }
        .onReceive(NotificationCenter.default.publisher(for: .appkSaveAsRequested)) { _ in
            showSaveAsPanel()
        }
        .onReceive(NotificationCenter.default.publisher(for: .appkCursorJumpRequested)) { notification in
            if let line = notification.object as? Int {
                viewModel.jumpToLine(line)
            }
        }
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(viewModel.openDocuments.enumerated()), id: \.element.id) { index, doc in
                    tabItem(doc: doc, index: index)
                }
            }
        }
        .frame(height: 28)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func tabItem(doc: EditorDocument, index: Int) -> some View {
        HStack(spacing: 4) {
            Text(doc.displayName)
                .font(.system(size: 12))
                .padding(.horizontal, 8)
            Button(action: {
                _ = viewModel.closeDocument(at: index)
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 5)
        .background(viewModel.activeDocumentIndex == index ? Color(NSColor.textBackgroundColor) : Color.clear)
        .onTapGesture {
            viewModel.activeDocumentIndex = index
        }
        .overlay(
            Rectangle()
                .fill(Color.accentColor)
                .frame(height: 2)
                .opacity(viewModel.activeDocumentIndex == index ? 1 : 0),
            alignment: .bottom
        )
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("No file open")
                .font(.headline)
            Text("Open a file from the Project Explorer")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor))
    }

    private func showSaveAsPanel() {
        guard let doc = viewModel.activeDocument else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = doc.url.lastPathComponent
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.saveActiveDocumentAs(to: url)
        }
    }
}

struct CodeEditorView: NSViewRepresentable {
    @ObservedObject var document: EditorDocument

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true

        let textView = NSTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = NSColor.textColor
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.delegate = context.coordinator

        if let textStorage = textView.textStorage {
            textStorage.replaceCharacters(in: NSRange(location: 0, length: 0), with: document.content)
        }

        scrollView.documentView = textView
        context.coordinator.textView = textView
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
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(document: document)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        weak var textView: NSTextView?
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
        }
    }
}