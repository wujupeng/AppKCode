import Foundation

// MARK: - Version Range (TASK-004.1)

public struct VersionRange: Sendable, Codable, Hashable {
    public let min: SemVer
    public let max: SemVer?
    public let excludePreReleases: Bool

    public init(min: SemVer, max: SemVer? = nil, excludePreReleases: Bool = true) {
        self.min = min
        self.max = max
        self.excludePreReleases = excludePreReleases
    }

    public func contains(_ version: SemVer) -> Bool {
        if version < min { return false }
        if let max = max, version > max { return false }
        if excludePreReleases, version.preRelease != nil { return false }
        return true
    }
}

// MARK: - Compatibility Matrix Entry (TASK-004.2)

public struct CompatibilityMatrixEntry: Sendable, Codable, Hashable {
    public let hostVersion: VersionRange
    public let extensionVersion: VersionRange
    public let compatible: Bool
    public let degradationStrategy: DegradationStrategy?
    public let notes: String?

    public init(
        hostVersion: VersionRange,
        extensionVersion: VersionRange,
        compatible: Bool,
        degradationStrategy: DegradationStrategy? = nil,
        notes: String? = nil
    ) {
        self.hostVersion = hostVersion
        self.extensionVersion = extensionVersion
        self.compatible = compatible
        self.degradationStrategy = degradationStrategy
        self.notes = notes
    }
}

// MARK: - Matrix ID (TASK-004.3)

public struct MatrixID: Hashable, Sendable, Codable {
    public let rawValue: String
    public init() { self.rawValue = UUID().uuidString }
    public init(_ value: String) { self.rawValue = value }
}

// MARK: - Compatibility Matrix (TASK-004.3)

public struct CompatibilityMatrix: Sendable, Codable, Hashable {
    public let id: MatrixID
    public let entries: [CompatibilityMatrixEntry]

    public init(id: MatrixID = MatrixID(), entries: [CompatibilityMatrixEntry]) {
        self.id = id
        self.entries = entries
    }
}

// MARK: - Incompatibility Reason (TASK-004.4, H24)

public enum IncompatibilityReason: Sendable, Codable, Hashable {
    case hostVersionTooLow(required: SemVer, actual: SemVer)
    case hostVersionTooHigh(max: SemVer, actual: SemVer)
    case extensionVersionNotSupported
    case architectureMismatch(extension: Architecture, host: Architecture)
    case noMatrixEntry
}

// MARK: - Version Negotiation Result (TASK-004.4, H24)

public enum VersionNegotiationResult: Sendable, Codable, Equatable {
    case compatible(extensionVersion: SemVer, hostVersion: SemVer)
    case incompatible(reason: IncompatibilityReason)
    case degraded(strategy: DegradationStrategy, extensionVersion: SemVer)
}

// MARK: - Version Negotiation Request (TASK-004.5)

public struct VersionNegotiationRequest: Sendable, Codable, Hashable {
    public let extensionManifest: ExtensionManifest
    public let hostVersion: SemVer
    public let hostArchitecture: Architecture
    public let matrix: CompatibilityMatrix

    public init(
        extensionManifest: ExtensionManifest,
        hostVersion: SemVer,
        hostArchitecture: Architecture,
        matrix: CompatibilityMatrix
    ) {
        self.extensionManifest = extensionManifest
        self.hostVersion = hostVersion
        self.hostArchitecture = hostArchitecture
        self.matrix = matrix
    }
}