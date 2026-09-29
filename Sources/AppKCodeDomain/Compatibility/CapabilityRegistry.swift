import Foundation
import AppKCodeShared

// MARK: - Capability Registry Protocol (TASK-016.1)

public protocol CapabilityRegistry: Sendable {
    func register(_ descriptor: CapabilityDescriptor) async throws -> CapabilityID
    func unregister(_ id: CapabilityID) async throws
    func resolve(_ id: CapabilityID) -> CapabilityDescriptor?
    func listAll() -> [CapabilityDescriptor]
    func listByCategory(_ category: CapabilityCategory) -> [CapabilityDescriptor]
    func listByExtension(_ id: ExtensionID) -> [CapabilityDescriptor]
    func findDeprecationChain(_ id: CapabilityID) -> [CapabilityID]
}

// MARK: - Capability Registry Impl (TASK-016.2, TASK-016.3)

public final class CapabilityRegistryImpl: CapabilityRegistry, @unchecked Sendable {
    private let lock = NSLock()
    private var registry: [CapabilityID: CapabilityDescriptor] = [:]

    public init() {}

    public func register(_ descriptor: CapabilityDescriptor) async throws -> CapabilityID {
        lock.lock()
        defer { lock.unlock() }

        let id = descriptor.capability.id
        if registry[id] != nil {
            throw CapabilityRegistryError.duplicateRegistration(id)
        }
        registry[id] = descriptor
        return id
    }

    public func unregister(_ id: CapabilityID) async throws {
        lock.lock()
        defer { lock.unlock() }
        registry.removeValue(forKey: id)
    }

    public func resolve(_ id: CapabilityID) -> CapabilityDescriptor? {
        lock.lock()
        defer { lock.unlock() }
        return registry[id]
    }

    public func listAll() -> [CapabilityDescriptor] {
        lock.lock()
        defer { lock.unlock() }
        return Array(registry.values)
    }

    public func listByCategory(_ category: CapabilityCategory) -> [CapabilityDescriptor] {
        lock.lock()
        defer { lock.unlock() }
        return registry.values.filter { $0.capability.category == category }
    }

    public func listByExtension(_ id: ExtensionID) -> [CapabilityDescriptor] {
        lock.lock()
        defer { lock.unlock() }
        return registry.values.filter { $0.providedBy == id }
    }

    public func findDeprecationChain(_ id: CapabilityID) -> [CapabilityID] {
        lock.lock()
        defer { lock.unlock() }

        var chain: [CapabilityID] = [id]
        var current = id
        var visited: Set<CapabilityID> = [id]

        while let descriptor = registry[current],
              let replacement = descriptor.capability.replacement,
              !visited.contains(replacement) {
            chain.append(replacement)
            visited.insert(replacement)
            current = replacement
        }
        return chain
    }
}

public enum CapabilityRegistryError: Error, Sendable {
    case duplicateRegistration(CapabilityID)
    case notFound(CapabilityID)
}