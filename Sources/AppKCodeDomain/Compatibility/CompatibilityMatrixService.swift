import Foundation
import AppKCodeShared
import AppKCodeInfrastructure

// MARK: - Compatibility Matrix Service Protocol (TASK-019.1)

public protocol CompatibilityMatrixService: Sendable {
    func getMatrix() async throws -> CompatibilityMatrix
    func query(hostVersion: SemVer, extensionVersion: SemVer) async throws -> CompatibilityMatrixEntry?
    func queryCompatibleExtensions(hostVersion: SemVer) async throws -> [CompatibilityMatrixEntry]
    func addEntry(_ entry: CompatibilityMatrixEntry) async throws
    func validateMatrix() async throws -> ExtensionValidationResult
}

// MARK: - Compatibility Matrix Service Impl (TASK-019.2~019.3)

public final class CompatibilityMatrixServiceImpl: CompatibilityMatrixService, @unchecked Sendable {
    private let store: CompatibilityMatrixStore

    public init(store: CompatibilityMatrixStore) {
        self.store = store
    }

    public func getMatrix() async throws -> CompatibilityMatrix {
        try await store.load()
    }

    public func query(hostVersion: SemVer, extensionVersion: SemVer) async throws -> CompatibilityMatrixEntry? {
        try await store.query(hostVersion: hostVersion, extensionVersion: extensionVersion)
    }

    public func queryCompatibleExtensions(hostVersion: SemVer) async throws -> [CompatibilityMatrixEntry] {
        let matrix = try await store.load()
        return matrix.entries.filter { $0.hostVersion.contains(hostVersion) && $0.compatible }
    }

    public func addEntry(_ entry: CompatibilityMatrixEntry) async throws {
        try await store.addEntry(entry)
    }

    public func validateMatrix() async throws -> ExtensionValidationResult {
        let matrix = try await store.load()
        var seen: [String: Bool] = [:]
        var contradictions: [String] = []

        for entry in matrix.entries {
            let key = "\(entry.hostVersion.min.major).\(entry.hostVersion.min.minor)|\(entry.extensionVersion.min.major).\(entry.extensionVersion.min.minor)"
            if let existing = seen[key], existing != entry.compatible {
                contradictions.append("Contradictory entry for \(key)")
            }
            seen[key] = entry.compatible
        }

        if contradictions.isEmpty {
            return .valid
        }
        return .invalid(reasons: contradictions)
    }
}