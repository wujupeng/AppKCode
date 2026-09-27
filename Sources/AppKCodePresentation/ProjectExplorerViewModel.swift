import Foundation
import AppKCodeShared
import AppKCodeApplication

public final class ProjectExplorerViewModel: ObservableObject {
    @Published public var rootNode: FileTreeEntry?
    @Published public var errorMessage: String?
    @Published public var isLoading: Bool = false

    private let workspaceService: WorkspaceService
    private var watcher: FSEventsWatcher?

    public init(workspaceService: WorkspaceService) {
        self.workspaceService = workspaceService
    }

    public func openFolder(_ url: URL) {
        do {
            let handle = try workspaceService.openFolder(url: url)
            loadFileTree(at: handle.rootURL)
            startFileWatcher(at: handle.rootURL)
            errorMessage = nil
        } catch let AppKError.permissionDenied(path) {
            errorMessage = "无法读取目录，请检查权限: \(path)"
        } catch {
            errorMessage = "打开目录失败: \(error.localizedDescription)"
        }
    }

    public func loadFileTree(at url: URL) {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let entry = Self.buildTree(at: url)
            DispatchQueue.main.async {
                self?.rootNode = entry
                self?.isLoading = false
            }
        }
    }

    private func startFileWatcher(at url: URL) {
        watcher = FSEventsWatcher { [weak self] changedURLs in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let root = self.rootNode {
                    self.refreshNode(root, changedURLs: changedURLs)
                }
            }
        }
        watcher?.startWatching(directory: url)
    }

    private func refreshNode(_ node: FileTreeEntry, changedURLs: Set<URL>) {
        for url in changedURLs {
            if node.url == url || node.url.path == url.path {
                let refreshed = Self.buildTree(at: node.url)
                node.children = refreshed.children
                return
            }
        }
        for child in node.children {
            refreshNode(child, changedURLs: changedURLs)
        }
    }

    public static func buildTree(at url: URL) -> FileTreeEntry {
        let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        let entry = FileTreeEntry(name: url.lastPathComponent, url: url, isDirectory: isDir)

        if isDir {
            let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .nameKey]
            if let contents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: resourceKeys, options: [.skipsHiddenFiles]) {
                entry.children = contents.map { buildTree(at: $0) }.sorted { lhs, rhs in
                    if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
                    return lhs.name < rhs.name
                }
            }
        }
        return entry
    }
}

public final class FileTreeEntry: Identifiable, Equatable {
    public let id = UUID()
    public let name: String
    public let url: URL
    public let isDirectory: Bool
    public var children: [FileTreeEntry] = []

    public init(name: String, url: URL, isDirectory: Bool) {
        self.name = name
        self.url = url
        self.isDirectory = isDirectory
    }

    public static func == (lhs: FileTreeEntry, rhs: FileTreeEntry) -> Bool {
        lhs.url == rhs.url
    }
}