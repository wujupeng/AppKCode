import Foundation
import AppKCodeShared

// MARK: - Compatibility Matrix Store (TASK-012, H24)

public final class CompatibilityMatrixStore: @unchecked Sendable {
    private let matrixURL: URL
    private let lock = NSLock()

    public init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dir = home
            .appendingPathComponent(".appkcode")
            .appendingPathComponent("compatibility")
        self.matrixURL = dir.appendingPathComponent("matrix.json")
    }

    public init(customURL: URL) {
        self.matrixURL = customURL
    }

    public func save(_ matrix: CompatibilityMatrix) async throws {
        let fm = FileManager.default
        let dir = matrixURL.deletingLastPathComponent()
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let data = try encoder.encode(matrix)
        try data.write(to: matrixURL)
    }

    public func load() async throws -> CompatibilityMatrix {
        let fm = FileManager.default
        guard fm.fileExists(atPath: matrixURL.path) else {
            return CompatibilityMatrix(entries: [])
        }

        let data = try Data(contentsOf: matrixURL)
        return try JSONDecoder().decode(CompatibilityMatrix.self, from: data)
    }

    public func query(hostVersion: SemVer, extensionVersion: SemVer) async throws -> CompatibilityMatrixEntry? {
        let matrix = try await load()
        for entry in matrix.entries {
            if entry.hostVersion.contains(hostVersion) && entry.extensionVersion.contains(extensionVersion) {
                return entry
            }
        }
        return nil
    }

    public func addEntry(_ entry: CompatibilityMatrixEntry) async throws {
        lock.lock()
        defer { lock.unlock() }

        let matrix = try await load()
        let newMatrix = CompatibilityMatrix(id: matrix.id, entries: matrix.entries + [entry])
        try await save(newMatrix)
    }

    public func updateEntry(_ entry: CompatibilityMatrixEntry) async throws {
        lock.lock()
        defer { lock.unlock() }

        let matrix = try await load()
        var updated = false
        var newEntries: [CompatibilityMatrixEntry] = []
        for existing in matrix.entries {
            if existing.hostVersion.contains(entry.hostVersion.min)
                && existing.extensionVersion.contains(entry.extensionVersion.min) {
                newEntries.append(entry)
                updated = true
            } else {
                newEntries.append(existing)
            }
        }
        if !updated {
            newEntries.append(entry)
        }
        let newMatrix = CompatibilityMatrix(id: matrix.id, entries: newEntries)
        try await save(newMatrix)
    }
}