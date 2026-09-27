import Foundation
import AppKCodeShared
import AppKit

public final class EditorViewModel: ObservableObject {
    @Published public var openDocuments: [EditorDocument] = []
    @Published public var activeDocumentIndex: Int? = nil
    @Published public var pendingCloseIndex: Int? = nil

    public init() {}

    public var activeDocument: EditorDocument? {
        guard let idx = activeDocumentIndex, idx < openDocuments.count else { return nil }
        return openDocuments[idx]
    }

    public func openFile(_ url: URL) {
        if let existingIdx = openDocuments.firstIndex(where: { $0.url == url }) {
            activeDocumentIndex = existingIdx
            return
        }
        do {
            let doc = try EditorDocument.load(from: url)
            openDocuments.append(doc)
            activeDocumentIndex = openDocuments.count - 1
        } catch {
            NotificationCenter.default.post(name: .appkEditorError, object: error.localizedDescription)
        }
    }

    public func closeDocument(at index: Int, force: Bool = false) -> Bool {
        guard index < openDocuments.count else { return true }
        let doc = openDocuments[index]
        if doc.isDirty && !force {
            pendingCloseIndex = index
            return false
        }
        openDocuments.remove(at: index)
        if activeDocumentIndex == index {
            activeDocumentIndex = openDocuments.isEmpty ? nil : min(index, openDocuments.count - 1)
        } else if let active = activeDocumentIndex, active > index {
            activeDocumentIndex = active - 1
        }
        return true
    }

    public func saveActiveDocument() {
        guard let doc = activeDocument else { return }
        do {
            try doc.save()
        } catch {
            NotificationCenter.default.post(name: .appkEditorError, object: error.localizedDescription)
        }
    }

    public func saveActiveDocumentAs(to url: URL) {
        guard let doc = activeDocument else { return }
        do {
            try doc.saveAs(to: url)
        } catch {
            NotificationCenter.default.post(name: .appkEditorError, object: error.localizedDescription)
        }
    }

    public func jumpToLine(_ line: Int) {
        NotificationCenter.default.post(name: .appkEditorJumpToLine, object: line)
    }
}

