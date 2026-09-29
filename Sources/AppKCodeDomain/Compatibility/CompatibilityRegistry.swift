import Foundation
import AppKCodeShared
import AppKCodeInfrastructure

// MARK: - Extension Registry Event (TASK-014.3)

public enum ExtensionRegistryEvent: Sendable, Codable, Equatable {
    case extensionRegistered(ExtensionID)
    case extensionUnregistered(ExtensionID)
    case capabilityRegistered(CapabilityID)
    case stateChanged(ExtensionID, ExtensionLoadState)
}

// MARK: - Compatibility Registry Protocol (TASK-014.1)

public protocol CompatibilityRegistry: Sendable {
    func registerExtension(_ manifest: ExtensionManifest) async throws -> ExtensionID
    func unregisterExtension(_ id: ExtensionID) async throws
    func listExtensions() -> [ExtensionRegistryEntry]
    func extensionState(_ id: ExtensionID) -> ExtensionLoadState
    func registerCapability(_ descriptor: CapabilityDescriptor) async throws -> CapabilityID
    func listCapabilities() -> [CapabilityDescriptor]
    func capabilities(forExtension id: ExtensionID) -> [CapabilityDescriptor]
    var extensionEvents: AsyncStream<ExtensionRegistryEvent> { get }
}

// MARK: - Compatibility Registry Impl (TASK-014.2, TASK-014.4)

public final class CompatibilityRegistryImpl: CompatibilityRegistry, @unchecked Sendable {
    private let store: ExtensionStore
    private let lock = NSLock()
    private var extensions: [ExtensionID: ExtensionRegistryEntry] = [:]
    private var capabilities: [CapabilityID: CapabilityDescriptor] = [:]
    private var eventContinuation: AsyncStream<ExtensionRegistryEvent>.Continuation?

    public init(store: ExtensionStore) {
        self.store = store
    }

    public var extensionEvents: AsyncStream<ExtensionRegistryEvent> {
        AsyncStream { continuation in
            self.eventContinuation = continuation
        }
    }

    public func registerExtension(_ manifest: ExtensionManifest) async throws -> ExtensionID {
        lock.lock()
        defer { lock.unlock() }

        let entry = ExtensionRegistryEntry(manifest: manifest, state: .loaded)
        extensions[manifest.id] = entry
        eventContinuation?.yield(.extensionRegistered(manifest.id))
        return manifest.id
    }

    public func unregisterExtension(_ id: ExtensionID) async throws {
        lock.lock()
        defer { lock.unlock() }

        extensions.removeValue(forKey: id)
        capabilities = capabilities.filter { $0.value.providedBy != id }
        eventContinuation?.yield(.extensionUnregistered(id))
    }

    public func listExtensions() -> [ExtensionRegistryEntry] {
        lock.lock()
        defer { lock.unlock() }
        return Array(extensions.values)
    }

    public func extensionState(_ id: ExtensionID) -> ExtensionLoadState {
        lock.lock()
        defer { lock.unlock() }
        return extensions[id]?.state ?? .notLoaded
    }

    public func registerCapability(_ descriptor: CapabilityDescriptor) async throws -> CapabilityID {
        lock.lock()
        defer { lock.unlock() }

        capabilities[descriptor.capability.id] = descriptor
        eventContinuation?.yield(.capabilityRegistered(descriptor.capability.id))
        return descriptor.capability.id
    }

    public func listCapabilities() -> [CapabilityDescriptor] {
        lock.lock()
        defer { lock.unlock() }
        return Array(capabilities.values)
    }

    public func capabilities(forExtension id: ExtensionID) -> [CapabilityDescriptor] {
        lock.lock()
        defer { lock.unlock() }
        return capabilities.values.filter { $0.providedBy == id }
    }

    public func updateState(_ id: ExtensionID, _ state: ExtensionLoadState) {
        lock.lock()
        defer { lock.unlock() }

        if let entry = extensions[id] {
            extensions[id] = ExtensionRegistryEntry(
                manifest: entry.manifest,
                state: state,
                installedAt: entry.installedAt,
                lastStateChange: ISO8601Timestamp()
            )
            eventContinuation?.yield(.stateChanged(id, state))
        }
    }
}