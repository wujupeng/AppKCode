import Foundation
import AppKCodeShared
import AppKCodeInfrastructure

// MARK: - Version Negotiation Service Protocol (TASK-018.1, H24)

public protocol VersionNegotiationService: Sendable {
    func negotiate(_ request: VersionNegotiationRequest) async throws -> VersionNegotiationResult
}

// MARK: - Version Negotiation Service Impl (TASK-018.2~018.5, H24)

public final class VersionNegotiationServiceImpl: VersionNegotiationService, @unchecked Sendable {
    private let matrixStore: CompatibilityMatrixStore
    private let hostVersion: SemVer
    private let hostArchitecture: Architecture

    public init(matrixStore: CompatibilityMatrixStore, hostVersion: SemVer, hostArchitecture: Architecture) {
        self.matrixStore = matrixStore
        self.hostVersion = hostVersion
        self.hostArchitecture = hostArchitecture
    }

    public func negotiate(_ request: VersionNegotiationRequest) async throws -> VersionNegotiationResult {
        let manifest = request.extensionManifest

        if !manifest.architectures.contains(hostArchitecture) && !manifest.architectures.contains(.universal) {
            return .incompatible(reason: .architectureMismatch(
                extension: manifest.architectures.first ?? .arm64,
                host: hostArchitecture
            ))
        }

        if let entry = try await matrixStore.query(hostVersion: hostVersion, extensionVersion: manifest.version) {
            if entry.compatible {
                return .compatible(extensionVersion: manifest.version, hostVersion: hostVersion)
            }
            if let strategy = entry.degradationStrategy {
                return .degraded(strategy: strategy, extensionVersion: manifest.version)
            }
            return .incompatible(reason: .extensionVersionNotSupported)
        }

        return .incompatible(reason: .noMatrixEntry)
    }
}