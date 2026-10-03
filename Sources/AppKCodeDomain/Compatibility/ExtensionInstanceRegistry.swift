import Foundation
import AppKCodeShared

// MARK: - Extension Instance ID (TASK-027.2)

public struct ExtensionInstanceID: Hashable, Sendable, Codable {
    public let rawValue: String
    public init() { self.rawValue = UUID().uuidString }
    public init(_ value: String) { self.rawValue = value }
}

// MARK: - Workspace ID (TASK-027.2)

public struct WorkspaceID: Hashable, Sendable, Codable {
    public let rawValue: String
    public init() { self.rawValue = UUID().uuidString }
    public init(_ value: String) { self.rawValue = value }
}

// MARK: - Extension Instance State (TASK-027.3, design §2.1.3.7)

public enum ExtensionInstanceState: String, Sendable, Codable, Hashable, Equatable {
    case notStarted = "not_started"
    case loading
    case loaded
    case incompatible
    case activating
    case active
    case deactivating
    case deactivated
    case crashed
    case restarting
    case failed
    case unstable
}

// MARK: - Extension Instance (TASK-027.2)

public struct ExtensionInstance: Sendable, Codable, Equatable {
    public let id: ExtensionInstanceID
    public let extensionID: ExtensionID
    public let workspaceID: WorkspaceID
    public let hostType: ExtensionHostType
    public let createdAt: ISO8601Timestamp
    public var state: ExtensionInstanceState

    public init(
        id: ExtensionInstanceID = ExtensionInstanceID(),
        extensionID: ExtensionID,
        workspaceID: WorkspaceID,
        hostType: ExtensionHostType,
        createdAt: ISO8601Timestamp = ISO8601Timestamp(),
        state: ExtensionInstanceState = .notStarted
    ) {
        self.id = id
        self.extensionID = extensionID
        self.workspaceID = workspaceID
        self.hostType = hostType
        self.createdAt = createdAt
        self.state = state
    }
}

// MARK: - Extension Instance Registry Protocol (TASK-027.1)

public protocol ExtensionInstanceRegistry: Sendable {
    func register(
        extensionID: ExtensionID,
        workspaceID: WorkspaceID,
        instance: ExtensionInstance
    ) async throws -> ExtensionInstanceID

    func lookup(
        extensionID: ExtensionID,
        workspaceID: WorkspaceID
    ) -> ExtensionInstance?

    func listInstances(workspaceID: WorkspaceID) -> [ExtensionInstance]
    func remove(extensionInstanceID: ExtensionInstanceID) async throws
    func updateState(_ state: ExtensionInstanceState, for instanceID: ExtensionInstanceID) async throws
    func allInstances() -> [ExtensionInstance]
}

// MARK: - Extension Instance Registry Impl (TASK-027.4~027.6, REQ-024)

public final class ExtensionInstanceRegistryImpl: ExtensionInstanceRegistry, @unchecked Sendable {
    private let lock = NSLock()
    private var instancesByID: [ExtensionInstanceID: ExtensionInstance] = [:]
    private var indexByExtensionWorkspace: [ExtensionID: [WorkspaceID: ExtensionInstanceID]] = [:]
    private var indexByWorkspace: [WorkspaceID: [ExtensionInstanceID]] = [:]

    public init() {}

    public func register(
        extensionID: ExtensionID,
        workspaceID: WorkspaceID,
        instance: ExtensionInstance
    ) async throws -> ExtensionInstanceID {
        lock.lock()
        defer { lock.unlock() }

        let instanceID = instance.id
        instancesByID[instanceID] = instance

        if indexByExtensionWorkspace[extensionID] == nil {
            indexByExtensionWorkspace[extensionID] = [:]
        }
        indexByExtensionWorkspace[extensionID]?[workspaceID] = instanceID

        if indexByWorkspace[workspaceID] == nil {
            indexByWorkspace[workspaceID] = []
        }
        indexByWorkspace[workspaceID]?.append(instanceID)

        return instanceID
    }

    public func lookup(
        extensionID: ExtensionID,
        workspaceID: WorkspaceID
    ) -> ExtensionInstance? {
        lock.lock()
        defer { lock.unlock() }

        guard let instanceID = indexByExtensionWorkspace[extensionID]?[workspaceID] else {
            return nil
        }
        return instancesByID[instanceID]
    }

    public func listInstances(workspaceID: WorkspaceID) -> [ExtensionInstance] {
        lock.lock()
        defer { lock.unlock() }

        guard let ids = indexByWorkspace[workspaceID] else { return [] }
        return ids.compactMap { instancesByID[$0] }
    }

    public func remove(extensionInstanceID: ExtensionInstanceID) async throws {
        lock.lock()
        defer { lock.unlock() }

        guard let instance = instancesByID[extensionInstanceID] else {
            return
        }

        instancesByID[extensionInstanceID] = nil
        indexByExtensionWorkspace[instance.extensionID]?.removeValue(forKey: instance.workspaceID)
        if indexByExtensionWorkspace[instance.extensionID]?.isEmpty == true {
            indexByExtensionWorkspace.removeValue(forKey: instance.extensionID)
        }
        indexByWorkspace[instance.workspaceID]?.removeAll { $0 == extensionInstanceID }
        if indexByWorkspace[instance.workspaceID]?.isEmpty == true {
            indexByWorkspace.removeValue(forKey: instance.workspaceID)
        }
    }

    public func updateState(_ state: ExtensionInstanceState, for instanceID: ExtensionInstanceID) async throws {
        lock.lock()
        defer { lock.unlock() }

        guard instancesByID[instanceID] != nil else {
            return
        }
        instancesByID[instanceID]?.state = state
    }

    public func allInstances() -> [ExtensionInstance] {
        lock.lock()
        defer { lock.unlock() }
        return Array(instancesByID.values)
    }
}