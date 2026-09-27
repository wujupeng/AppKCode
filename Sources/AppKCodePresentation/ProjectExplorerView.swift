import SwiftUI
import AppKit
import AppKCodeShared

struct ProjectExplorerView: View {
    @ObservedObject var viewModel: ProjectExplorerViewModel
    @State private var expandedIDs: Set<UUID> = []

    var body: some View {
        VStack(spacing: 0) {
            if let error = viewModel.errorMessage {
                errorBanner(error)
            }
            if viewModel.isLoading {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let root = viewModel.rootNode {
                fileList(root)
            } else {
                emptyState
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .onReceive(NotificationCenter.default.publisher(for: .appkOpenFolderRequested)) { _ in
            showOpenPanel()
        }
    }

    private func fileList(_ root: FileTreeEntry) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(root.children) { entry in
                    fileTreeRow(entry, depth: 0)
                }
            }
        }
    }

    @ViewBuilder
    private func fileTreeRow(_ entry: FileTreeEntry, depth: Int) -> AnyView {
        AnyView(
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                if entry.isDirectory {
                    Button(action: {
                        if expandedIDs.contains(entry.id) {
                            expandedIDs.remove(entry.id)
                        } else {
                            expandedIDs.insert(entry.id)
                        }
                    }) {
                        Image(systemName: expandedIDs.contains(entry.id) ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    Image(systemName: "folder")
                        .foregroundColor(.accentColor)
                } else {
                    Spacer().frame(width: 16)
                    Image(systemName: "doc")
                        .foregroundColor(.secondary)
                }
                Text(entry.name)
                    .font(.system(size: 13))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.leading, CGFloat(depth) * 16 + 4)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
            .onTapGesture {
                if entry.isDirectory {
                    if expandedIDs.contains(entry.id) {
                        expandedIDs.remove(entry.id)
                    } else {
                        expandedIDs.insert(entry.id)
                    }
                } else {
                    NotificationCenter.default.post(name: .appkFileOpenRequested, object: entry.url)
                }
            }
            if entry.isDirectory && expandedIDs.contains(entry.id) {
                ForEach(entry.children) { child in
                    fileTreeRow(child, depth: depth + 1)
                }
            }
        }
        )
    }

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.caption)
                .foregroundColor(.red)
            Spacer()
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("No folder open")
                .font(.headline)
            Button("Open Folder") {
                showOpenPanel()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func showOpenPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.openFolder(url)
        }
    }
}