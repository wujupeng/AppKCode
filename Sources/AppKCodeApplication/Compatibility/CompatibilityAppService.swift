import Foundation
import AppKCodeShared
import AppKCodeDomain
import AppKCodeInfrastructure

// MARK: - Compatibility App Service Protocol (TASK-030.1)

public protocol CompatibilityAppService: Sendable {
    func listExtensions() async -> [ExtensionRegistryEntry]
    func getCompatibilityMatrix() async throws -> CompatibilityMatrix
    func checkCompatibility(hostVersion: SemVer, extensionVersion: SemVer) async -> CompatibilityMatrixEntry?
}

// MARK: - Compatibility App Service Impl (TASK-030.2)

public final class CompatibilityAppServiceImpl: CompatibilityAppService, @unchecked Sendable {
    private let registry: CompatibilityRegistry
    private let matrixService: CompatibilityMatrixService

    public init(registry: CompatibilityRegistry, matrixService: CompatibilityMatrixService) {
        self.registry = registry
        self.matrixService = matrixService
    }

    public func listExtensions() async -> [ExtensionRegistryEntry] {
        registry.listExtensions()
    }

    public func getCompatibilityMatrix() async throws -> CompatibilityMatrix {
        try await matrixService.getMatrix()
    }

    public func checkCompatibility(hostVersion: SemVer, extensionVersion: SemVer) async -> CompatibilityMatrixEntry? {
        try? await matrixService.query(hostVersion: hostVersion, extensionVersion: extensionVersion)
    }
}