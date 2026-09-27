import Foundation
import AppKCodeShared

public final class WorkspaceService: @unchecked Sendable {
    private var currentWorkspace: WorkspaceHandle?
    private let lock = NSLock()

    public init() {}

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
        return handle
    }

    public func closeWorkspace() {
        lock.lock()
        currentWorkspace = nil
        lock.unlock()
    }

    public func listFiles(in directory: URL? = nil) throws -> [FileTreeNode] {
        let targetDir = directory ?? currentWorkspace?.rootURL
        guard let dir = targetDir else {
            throw AppKError.invalidConfiguration(key: "workspace not opened")
        }
        return try buildFileTree(at: dir)
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