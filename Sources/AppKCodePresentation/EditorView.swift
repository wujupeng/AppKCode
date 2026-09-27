import SwiftUI
import AppKit
import AppKCodeShared
import AppKCodeDomain
import AppKCodeInfrastructure

struct EditorView: View {
    @ObservedObject var viewModel: EditorViewModel
    @State private var showFindPanel: Bool = false
    @State private var findQuery: String = ""
    @State private var replaceQuery: String = ""
    @State private var searchResultsCount: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            if showFindPanel {
                findReplacePanel
            }
            if let doc = viewModel.activeDocument {
                EditorCoreHostView(
                    document: doc,
                    editorState: viewModel.editorState(for: doc),
                    highlighterRegistry: viewModel.highlighterRegistry
                )
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
        .onReceive(NotificationCenter.default.publisher(for: .appkCloseRequested)) { _ in
            if let idx = viewModel.activeDocumentIndex {
                handleTabClose(at: idx)
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
                handleTabClose(at: index)
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

    private func handleTabClose(at index: Int) {
        guard index < viewModel.openDocuments.count else { return }
        let doc = viewModel.openDocuments[index]
        if doc.isDirty {
            let alert = NSAlert()
            alert.messageText = "Save changes to \(doc.displayName)?"
            alert.informativeText = "Your changes will be lost if you don't save them."
            alert.addButton(withTitle: "Save")
            alert.addButton(withTitle: "Don't Save")
            alert.addButton(withTitle: "Cancel")
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                viewModel.saveActiveDocument()
                _ = viewModel.closeDocument(at: index, force: true)
            } else if response == .alertSecondButtonReturn {
                _ = viewModel.closeDocument(at: index, force: true)
            }
        } else {
            _ = viewModel.closeDocument(at: index, force: true)
        }
    }

    private var findReplacePanel: some View {
        HStack(spacing: 8) {
            TextField("Find", text: $findQuery)
                .textFieldStyle(.roundedBorder)
                .onSubmit { performFind() }
            TextField("Replace", text: $replaceQuery)
                .textFieldStyle(.roundedBorder)
            Button("Replace All") { performReplaceAll() }
                .buttonStyle(.bordered)
            if searchResultsCount > 0 {
                Text("\(searchResultsCount) matches")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: { showFindPanel = false }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(6)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func performFind() {
        guard let doc = viewModel.activeDocument else { return }
        let state = viewModel.editorState(for: doc)
        let results = state.find(findQuery)
        searchResultsCount = results.count
    }

    private func performReplaceAll() {
        guard let doc = viewModel.activeDocument else { return }
        let state = viewModel.editorState(for: doc)
        let count = state.replaceAll(findQuery, with: replaceQuery)
        searchResultsCount = 0
        doc.updateContent(state.document.content)
        _ = count
    }
}