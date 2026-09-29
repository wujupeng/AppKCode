import Foundation
import AppKCodeShared

// MARK: - Extension Lifecycle Event (TASK-029.7)

public enum ExtensionLifecycleEvent: Sendable, Codable, Equatable {
    case loaded(ExtensionID)
    case enabled(ExtensionID)
    case disabled(ExtensionID)
    case unloaded(ExtensionID)
    case reloaded(ExtensionID)
    case loadFailed(ExtensionID, String)
    case incompatible(ExtensionID, IncompatibilityReason)
}

// MARK: - Extension Lifecycle Service Protocol (TASK-029.1)

public protocol ExtensionLifecycleService: Sendable {
    func loadExtension(_ manifest: ExtensionManifest) async throws -> ExtensionID
    func enableExtension(_ id: ExtensionID) async throws -> ExtensionLoadState
    func disableExtension(_ id: ExtensionID) async throws
    func unloadExtension(_ id: ExtensionID) async throws
    func reloadExtension(_ id: ExtensionID) async throws -> ExtensionLoadState
    func lifecycleEvents() -> AsyncStream<ExtensionLifecycleEvent>
}

// MARK: - Extension Lifecycle Service Impl (TASK-029.2~029.6)

public final class ExtensionLifecycleServiceImpl: ExtensionLifecycleService, @unchecked Sendable {
    private let registry: CompatibilityRegistryImpl
    private let validator: ExtensionManifestValidator
    private let versionNegotiation: VersionNegotiationService
    private let contractRegistry: CapabilityContractRegistry
    private let auditIntegration: ExtensionAuditIntegration
    private let lock = NSLock()
    private var manifests: [ExtensionID: ExtensionManifest] = [:]
    private var eventContinuation: AsyncStream<ExtensionLifecycleEvent>.Continuation?

    public init(
        registry: CompatibilityRegistryImpl,
        validator: ExtensionManifestValidator,
        versionNegotiation: VersionNegotiationService,
        contractRegistry: CapabilityContractRegistry,
        auditIntegration: ExtensionAuditIntegration
    ) {
        self.registry = registry
        self.validator = validator
        self.versionNegotiation = versionNegotiation
        self.contractRegistry = contractRegistry
        self.auditIntegration = auditIntegration
    }

    public func lifecycleEvents() -> AsyncStream<ExtensionLifecycleEvent> {
        AsyncStream { continuation in
            self.eventContinuation = continuation
        }
    }

    public func loadExtension(_ manifest: ExtensionManifest) async throws -> ExtensionID {
        let validation = validator.validate(manifest, availableContracts: contractRegistry.listAll().map { $0.id })
        if case .invalid(let reasons) = validation {
            let reason = reasons.joined(separator: "; ")
            eventContinuation?.yield(.loadFailed(manifest.id, reason))
            try await auditIntegration.recordExtensionEvent(M9AuditEvent(
                kind: .extensionFailed, extensionID: manifest.id,
                detail: .string("Validation failed: \(reason)")
            ))
            throw ExtensionLifecycleError.validationFailed(reason)
        }

        let matrix = CompatibilityMatrix(entries: [])
        let negRequest = VersionNegotiationRequest(
            extensionManifest: manifest,
            hostVersion: SemVer(0, 9, 0),
            hostArchitecture: .x86_64,
            matrix: matrix
        )
        let negResult = try await versionNegotiation.negotiate(negRequest)

        switch negResult {
        case .incompatible(let reason):
            registry.updateState(manifest.id, .incompatible(reason: String(describing: reason)))
            eventContinuation?.yield(.incompatible(manifest.id, reason))
            try await auditIntegration.recordExtensionEvent(M9AuditEvent(
                kind: .extensionIncompatible, extensionID: manifest.id,
                detail: .string("Incompatible: \(String(describing: reason))")
            ))
            throw ExtensionLifecycleError.incompatible(reason)
        case .degraded:
            registry.updateState(manifest.id, .loaded)
        case .compatible:
            break
        }

        let id = try await registry.registerExtension(manifest)

        lock.lock()
        manifests[id] = manifest
        lock.unlock()

        try await auditIntegration.recordExtensionEvent(M9AuditEvent(
            kind: .extensionManifestLoaded, extensionID: id,
            detail: .string("Extension loaded: \(manifest.name)")
        ))

        eventContinuation?.yield(.loaded(id))
        return id
    }

    public func enableExtension(_ id: ExtensionID) async throws -> ExtensionLoadState {
        registry.updateState(id, .enabled)
        try await auditIntegration.recordExtensionEvent(M9AuditEvent(
            kind: .extensionEnabled, extensionID: id,
            detail: .string("Extension enabled")
        ))
        eventContinuation?.yield(.enabled(id))
        return .enabled
    }

    public func disableExtension(_ id: ExtensionID) async throws {
        registry.updateState(id, .disabled)
        try await auditIntegration.recordExtensionEvent(M9AuditEvent(
            kind: .extensionDisabled, extensionID: id,
            detail: .string("Extension disabled")
        ))
        eventContinuation?.yield(.disabled(id))
    }

    public func unloadExtension(_ id: ExtensionID) async throws {
        registry.updateState(id, .notLoaded)
        try await registry.unregisterExtension(id)

        lock.lock()
        manifests.removeValue(forKey: id)
        lock.unlock()

        try await auditIntegration.recordExtensionEvent(M9AuditEvent(
            kind: .extensionUnloaded, extensionID: id,
            detail: .string("Extension unloaded")
        ))
        eventContinuation?.yield(.unloaded(id))
    }

    public func reloadExtension(_ id: ExtensionID) async throws -> ExtensionLoadState {
        lock.lock()
        let oldManifest = manifests[id]
        lock.unlock()

        try await unloadExtension(id)

        if let manifest = oldManifest {
            let newId = try await loadExtension(manifest)
            let state = try await enableExtension(newId)
            eventContinuation?.yield(.reloaded(id))
            return state
        }

        return .notLoaded
    }
}

public enum ExtensionLifecycleError: Error, Sendable {
    case validationFailed(String)
    case incompatible(IncompatibilityReason)
    case notFound(ExtensionID)
}