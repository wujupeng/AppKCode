import Foundation
import AppKCodeShared
import AppKCodeDomain
import AppKCodeInfrastructure

// MARK: - Extension Management App Service Protocol (TASK-031.1)

public protocol ExtensionManagementAppService: Sendable {
    func loadExtension(from url: URL) async throws -> ExtensionID
    func enableExtension(_ id: ExtensionID) async throws -> ExtensionLoadState
    func disableExtension(_ id: ExtensionID) async throws
    func unloadExtension(_ id: ExtensionID) async throws
    func requestPermission(_ request: PermissionRequest) async throws -> PermissionDecision
    func revokePermission(_ extensionID: ExtensionID, scope: PermissionScope, reason: String) async throws
    func extensionEvents() -> AsyncStream<ExtensionLifecycleEvent>
}

// MARK: - Extension Management App Service Impl (TASK-031.2)

public final class ExtensionManagementAppServiceImpl: ExtensionManagementAppService, @unchecked Sendable {
    private let lifecycleService: ExtensionLifecycleService
    private let permissionService: ExtensionPermissionService
    private let manifestLoader: ExtensionManifestLoader

    public init(
        lifecycleService: ExtensionLifecycleService,
        permissionService: ExtensionPermissionService,
        manifestLoader: ExtensionManifestLoader
    ) {
        self.lifecycleService = lifecycleService
        self.permissionService = permissionService
        self.manifestLoader = manifestLoader
    }

    public func loadExtension(from url: URL) async throws -> ExtensionID {
        let manifest = try await manifestLoader.loadSingle(url)
        return try await lifecycleService.loadExtension(manifest)
    }

    public func enableExtension(_ id: ExtensionID) async throws -> ExtensionLoadState {
        try await lifecycleService.enableExtension(id)
    }

    public func disableExtension(_ id: ExtensionID) async throws {
        try await lifecycleService.disableExtension(id)
    }

    public func unloadExtension(_ id: ExtensionID) async throws {
        try await lifecycleService.unloadExtension(id)
    }

    public func requestPermission(_ request: PermissionRequest) async throws -> PermissionDecision {
        try await permissionService.requestPermission(request)
    }

    public func revokePermission(_ extensionID: ExtensionID, scope: PermissionScope, reason: String) async throws {
        try await permissionService.revoke(extensionID, scope: scope, reason: reason)
    }

    public func extensionEvents() -> AsyncStream<ExtensionLifecycleEvent> {
        lifecycleService.lifecycleEvents()
    }
}