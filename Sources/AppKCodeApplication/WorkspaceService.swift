import Foundation
import AppKCodeShared

public final class WorkspaceService: @unchecked Sendable {
    private var currentWorkspace: WorkspaceHandle?
    private let lock = NSLock()
    private let workspaceConfigURL: URL

    public init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.workspaceConfigURL = home.appendingPathComponent(".appk/workspace.json")
    }

    public var currentHandle: WorkspaceHandle? {
        lock.lock()
        defer { lock.unlock() }
        return currentWorkspace
    }

    public func openFolder(url: URL) throws -> WorkspaceHandle {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw AppKError.permissionDenied(path: url.path)
        }
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            throw AppKError.permissionDenied(path: url.path)
        }
        let handle = WorkspaceHandle(rootURL: url)
        lock.lock()
        currentWorkspace = handle
        lock.unlock()
        try? saveWorkspace()
        return handle
    }

    public func closeWorkspace() {
        lock.lock()
        currentWorkspace = nil
        lock.unlock()
        try? clearPersistedWorkspace()
    }

    public func listFiles(in directory: URL? = nil) throws -> [FileTreeNode] {
        let targetDir = directory ?? currentWorkspace?.rootURL
        guard let dir = targetDir else {
            throw AppKError.invalidConfiguration(key: "workspace not opened")
        }
        return try buildFileTree(at: dir)
    }

    public func saveWorkspace() throws {
        lock.lock()
        let rootPath = currentWorkspace?.rootURL.path
        lock.unlock()
        guard let path = rootPath else { return }
        let configDir = workspaceConfigURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        let json: [String: String] = ["rootPath": path]
        let data = try JSONSerialization.data(withJSONObject: json)
        try data.write(to: workspaceConfigURL)
    }

    public func loadPersistedWorkspace() -> URL? {
        guard FileManager.default.fileExists(atPath: workspaceConfigURL.path) else { return nil }
        guard let data = try? Data(contentsOf: workspaceConfigURL),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let rootPath = dict["rootPath"] else { return nil }
        let url = URL(fileURLWithPath: rootPath)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue,
              FileManager.default.isReadableFile(atPath: url.path) else { return nil }
        return url
    }

    public func clearPersistedWorkspace() throws {
        if FileManager.default.fileExists(atPath: workspaceConfigURL.path) {
            try FileManager.default.removeItem(at: workspaceConfigURL)
        }
    }

    private func buildFileTree(at url: URL) throws -> [FileTreeNode] {
        let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .nameKey]
        let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: resourceKeys, options: [.skipsHiddenFiles])
        return contents.map { itemURL in
            let isDir = (try? itemURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            return FileTreeNode(name: itemURL.lastPathComponent, url: itemURL, isDirectory: isDir)
        }.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
            return lhs.name < rhs.name
        }
    }
}