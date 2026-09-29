import Foundation
import AppKCodeShared

// MARK: - Extension Registry Entry (TASK-010.2)

public struct ExtensionRegistryEntry: Sendable, Codable, Equatable {
    public let manifest: ExtensionManifest
    public let state: ExtensionLoadState
    public let installedAt: ISO8601Timestamp
    public let lastStateChange: ISO8601Timestamp

    public init(
        manifest: ExtensionManifest,
        state: ExtensionLoadState = .notLoaded,
        installedAt: ISO8601Timestamp = ISO8601Timestamp(),
        lastStateChange: ISO8601Timestamp = ISO8601Timestamp()
    ) {
        self.manifest = manifest
        self.state = state
        self.installedAt = installedAt
        self.lastStateChange = lastStateChange
    }
}

// MARK: - Extension Store (TASK-010)

public final class ExtensionStore: @unchecked Sendable {
    private let registryURL: URL
    private let lock = NSLock()

    public init(workspaceRoot: URL) {
        self.registryURL = workspaceRoot
            .appendingPathComponent(".appkcode")
            .appendingPathComponent("extensions")
            .appendingPathComponent("registry.json")
    }

    public func save(_ entries: [ExtensionRegistryEntry]) async throws {
        let fm = FileManager.default
        let dir = registryURL.deletingLastPathComponent()
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let data = try encoder.encode(entries)
        try data.write(to: registryURL)
    }

    public func load() async throws -> [ExtensionRegistryEntry] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: registryURL.path) else {
            return []
        }

        let data = try Data(contentsOf: registryURL)
        return try JSONDecoder().decode([ExtensionRegistryEntry].self, from: data)
    }

    public func updateState(_ id: ExtensionID, state: ExtensionLoadState) async throws {
        lock.lock()
        defer { lock.unlock() }

        var entries = try await load()
        let now = ISO8601Timestamp()
        for i in entries.indices {
            if entries[i].manifest.id == id {
                entries[i] = ExtensionRegistryEntry(
                    manifest: entries[i].manifest,
                    state: state,
                    installedAt: entries[i].installedAt,
                    lastStateChange: now
                )
                try await save(entries)
                return
            }
        }
        throw ExtensionStoreError.extensionNotFound(id)
    }
}

public enum ExtensionStoreError: Error, Sendable {
    case extensionNotFound(ExtensionID)
}