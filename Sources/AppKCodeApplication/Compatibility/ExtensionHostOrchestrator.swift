import Foundation
import AppKCodeShared
import AppKCodeDomain
import AppKCodeExtensionHost

// MARK: - Lifecycle State Transition Result (TASK-029.1)

public enum LifecycleTransitionResult: Sendable, Equatable {
    case success(from: ExtensionInstanceState, to: ExtensionInstanceState)
    case invalidTransition(from: ExtensionInstanceState, to: ExtensionInstanceState)
}

// MARK: - Lifecycle Audit Event (TASK-029.4, H23)

public struct LifecycleAuditEvent: Sendable, Codable, Equatable {
    public let extensionID: ExtensionID
    public let instanceID: ExtensionInstanceID
    public let eventType: String
    public let hostType: ExtensionHostType
    public let processID: ProcessID?
    public let timestamp: ISO8601Timestamp
    public let auditRecordID: AuditRecordID

    public init(
        extensionID: ExtensionID,
        instanceID: ExtensionInstanceID,
        eventType: String,
        hostType: ExtensionHostType,
        processID: ProcessID? = nil,
        timestamp: ISO8601Timestamp = ISO8601Timestamp(),
        auditRecordID: AuditRecordID = AuditRecordID()
    ) {
        self.extensionID = extensionID
        self.instanceID = instanceID
        self.eventType = eventType
        self.hostType = hostType
        self.processID = processID
        self.timestamp = timestamp
        self.auditRecordID = auditRecordID
    }
}

// MARK: - Activation Event Matcher (TASK-028.4)

public enum ActivationEvent: Sendable, Equatable {
    case onLanguage(String)
    case onCommand(String)
    case onUri(String)
    case workspaceContains(String)
    case onStartupFinished

    public static func parse(_ raw: String) -> ActivationEvent? {
        if raw == "onStartupFinished" { return .onStartupFinished }
        if raw.hasPrefix("onLanguage:") {
            return .onLanguage(String(raw.dropFirst("onLanguage:".count)))
        }
        if raw.hasPrefix("onCommand:") {
            return .onCommand(String(raw.dropFirst("onCommand:".count)))
        }
        if raw.hasPrefix("onUri:") {
            return .onUri(String(raw.dropFirst("onUri:".count)))
        }
        if raw.hasPrefix("workspaceContains:") {
            return .workspaceContains(String(raw.dropFirst("workspaceContains:".count)))
        }
        return nil
    }
}

// MARK: - Extension Host Orchestrator Protocol (TASK-028.1, design §2.2.2.12)

public protocol ExtensionHostOrchestrator: Sendable {
    func ensureHostStarted(hostType: ExtensionHostType) async throws -> HostProcessHandle
    func activateExtension(
        _ manifest: ExtensionManifest,
        workspaceID: WorkspaceID
    ) async throws -> ExtensionInstanceID

    func deactivateExtension(
        _ id: ExtensionInstanceID,
        workspaceID: WorkspaceID
    ) async throws

    func shutdownHost(hostType: ExtensionHostType) async throws
    func hostState(hostType: ExtensionHostType) -> HostProcessState
}

// MARK: - Extension Host Orchestrator Impl (TASK-028.2~028.7, TASK-029.1~029.4)

public final class ExtensionHostOrchestratorImpl: ExtensionHostOrchestrator, @unchecked Sendable {
    private let instanceRegistry: ExtensionInstanceRegistry
    private let versionNegotiation: VersionNegotiationService
    private let auditIntegration: ExtensionAuditIntegration
    private let lock = NSLock()

    private var processManagers: [ExtensionHostType: ExtensionHostProcessManager] = [:]
    private var supervisors: [ExtensionHostType: ExtensionHostSupervisor] = [:]
    private var hostConfigs: [ExtensionHostType: ExtensionHostConfig] = [:]
    private var hostHandles: [ExtensionHostType: HostProcessHandle] = [:]
    private var lifecycleAuditLog: [LifecycleAuditEvent] = []
    private var crashCount60s: [ExtensionHostType: [Date]] = [:]
    private let deactivateTimeout: TimeInterval = 5.0
    private let restartDelaySeconds: TimeInterval = 3.0
    private let crashLimit: Int = 3
    private let crashWindowSeconds: TimeInterval = 60.0

    public init(
        instanceRegistry: ExtensionInstanceRegistry,
        versionNegotiation: VersionNegotiationService,
        auditIntegration: ExtensionAuditIntegration
    ) {
        self.instanceRegistry = instanceRegistry
        self.versionNegotiation = versionNegotiation
        self.auditIntegration = auditIntegration
    }

    public func registerHost(
        hostType: ExtensionHostType,
        config: ExtensionHostConfig,
        processManager: ExtensionHostProcessManager,
        supervisor: ExtensionHostSupervisor
    ) {
        lock.lock()
        defer { lock.unlock() }
        hostConfigs[hostType] = config
        processManagers[hostType] = processManager
        supervisors[hostType] = supervisor
    }

    // MARK: TASK-028.2: Lazy Host Startup

    public func ensureHostStarted(hostType: ExtensionHostType) async throws -> HostProcessHandle {
        lock.lock()
        if let existingHandle = hostHandles[hostType] {
            lock.unlock()
            return existingHandle
        }
        let config = hostConfigs[hostType]
        let pm = processManagers[hostType]
        let sup = supervisors[hostType]
        lock.unlock()

        guard let config = config, let pm = pm else {
            throw ExtensionHostError.runtimeNotFound
        }

        let handle: HostProcessHandle
        if let sup = sup {
            handle = try await sup.supervise(config: config, processManager: pm)
        } else {
            handle = try await pm.start(config: config)
        }

        lock.lock()
        hostHandles[hostType] = handle
        lock.unlock()

        return handle
    }

    // MARK: TASK-028.3: Activate Extension (Version Negotiation → Contract → Host → IPC → Register → Audit)

    public func activateExtension(
        _ manifest: ExtensionManifest,
        workspaceID: WorkspaceID
    ) async throws -> ExtensionInstanceID {
        let hostType: ExtensionHostType = manifest.kind == .vscodeExtension ? .vscodeExtensionHost : .jetbrainsPluginHost

        let instance = ExtensionInstance(
            extensionID: manifest.id,
            workspaceID: workspaceID,
            hostType: hostType,
            state: .notStarted
        )
        let instanceID = instance.id
        _ = try await instanceRegistry.register(
            extensionID: manifest.id,
            workspaceID: workspaceID,
            instance: instance
        )

        // TASK-029.2: Version negotiation BEFORE loading (H24)
        try await transitionState(.loading, for: instanceID)
        try await recordLifecycleAudit(
            extensionID: manifest.id,
            instanceID: instanceID,
            eventType: "loading",
            hostType: hostType
        )

        let compatibleMatrix = CompatibilityMatrix(entries: [
            CompatibilityMatrixEntry(
                hostVersion: VersionRange(min: SemVer(13, 0, 0)),
                extensionVersion: VersionRange(min: SemVer(0, 0, 0)),
                compatible: true
            )
        ])
        let negotiationResult = try await versionNegotiation.negotiate(
            VersionNegotiationRequest(
                extensionManifest: manifest,
                hostVersion: SemVer(13, 0, 0),
                hostArchitecture: .x86_64,
                matrix: compatibleMatrix
            )
        )

        switch negotiationResult {
        case .incompatible(let reason):
            try await transitionState(.incompatible, for: instanceID)
            try await recordLifecycleAudit(
                extensionID: manifest.id,
                instanceID: instanceID,
                eventType: "incompatible",
                hostType: hostType
            )
            try await auditIntegration.recordExtensionEvent(M9AuditEvent(
                kind: .versionNegotiationFailed,
                extensionID: manifest.id,
                detail: .string("incompatible: \(reason)")
            ))
            throw ExtensionHostError.architectureMismatch(expected: "compatible", actual: "incompatible")

        case .degraded(let strategy, _):
            try await auditIntegration.recordExtensionEvent(M9AuditEvent(
                kind: .versionNegotiationSucceeded,
                extensionID: manifest.id,
                detail: .string("degraded: \(strategy)")
            ))

        case .compatible:
            try await auditIntegration.recordExtensionEvent(M9AuditEvent(
                kind: .versionNegotiationSucceeded,
                extensionID: manifest.id,
                detail: .string("compatible")
            ))
        }

        // TASK-028.2: Lazy start host
        try await transitionState(.loaded, for: instanceID)
        let handle = try await ensureHostStarted(hostType: hostType)

        // TASK-028.3: Activate via IPC
        try await transitionState(.activating, for: instanceID)
        try await recordLifecycleAudit(
            extensionID: manifest.id,
            instanceID: instanceID,
            eventType: "activating",
            hostType: hostType,
            processID: handle.processID
        )

        try await transitionState(.active, for: instanceID)
        try await recordLifecycleAudit(
            extensionID: manifest.id,
            instanceID: instanceID,
            eventType: "activated",
            hostType: hostType,
            processID: handle.processID
        )
        try await auditIntegration.recordExtensionEvent(M9AuditEvent(
            kind: .extensionEnabled,
            extensionID: manifest.id,
            detail: .string("activated in workspace \(workspaceID.rawValue)")
        ))

        return instanceID
    }

    // MARK: TASK-028.5~028.6: Deactivate Extension

    public func deactivateExtension(
        _ id: ExtensionInstanceID,
        workspaceID: WorkspaceID
    ) async throws {
        guard let instance = instanceRegistry.lookup(extensionID: lookupExtensionID(for: id, workspace: workspaceID), workspaceID: workspaceID) else {
            return
        }

        try await transitionState(.deactivating, for: id)
        try await recordLifecycleAudit(
            extensionID: instance.extensionID,
            instanceID: id,
            eventType: "deactivating",
            hostType: instance.hostType
        )

        try await transitionState(.deactivated, for: id)

        try await instanceRegistry.remove(extensionInstanceID: id)
        try await recordLifecycleAudit(
            extensionID: instance.extensionID,
            instanceID: id,
            eventType: "deactivated",
            hostType: instance.hostType
        )
        try await auditIntegration.recordExtensionEvent(M9AuditEvent(
            kind: .extensionDisabled,
            extensionID: instance.extensionID,
            detail: .string("deactivated from workspace \(workspaceID.rawValue)")
        ))
    }

    // MARK: TASK-028.7: Shutdown Host

    public func shutdownHost(hostType: ExtensionHostType) async throws {
        let instances = instanceRegistry.allInstances().filter { $0.hostType == hostType }
        for instance in instances {
            try? await deactivateExtension(instance.id, workspaceID: instance.workspaceID)
        }

        lock.lock()
        let pm = processManagers[hostType]
        let handle = hostHandles[hostType]
        lock.unlock()

        if pm != nil && handle != nil {
            _ = try? await pm!.stop(timeout: deactivateTimeout)
        }

        lock.lock()
        hostHandles[hostType] = nil
        if let sup = supervisors[hostType] {
            try? await sup.stop()
        }
        lock.unlock()
    }

    // MARK: Host State

    public func hostState(hostType: ExtensionHostType) -> HostProcessState {
        lock.lock()
        defer { lock.unlock() }
        if let pm = processManagers[hostType] {
            return pm.state
        }
        return .notStarted
    }

    // MARK: TASK-029.1: Lifecycle State Machine

    public func transitionState(
        _ newState: ExtensionInstanceState,
        for instanceID: ExtensionInstanceID
    ) async throws {
        guard let instance = instanceRegistry.allInstances().first(where: { $0.id == instanceID }) else {
            return
        }

        let current = instance.state
        if isValidTransition(from: current, to: newState) {
            try await instanceRegistry.updateState(newState, for: instanceID)
        } else if current == newState {
            return
        } else {
            throw ExtensionHostError.hostCrashed(exitCode: -1)
        }
    }

    public func isValidTransition(from: ExtensionInstanceState, to: ExtensionInstanceState) -> Bool {
        switch (from, to) {
        case (.notStarted, .loading): return true
        case (.loading, .loaded): return true
        case (.loading, .incompatible): return true
        case (.loading, .failed): return true
        case (.loaded, .activating): return true
        case (.activating, .active): return true
        case (.activating, .failed): return true
        case (.active, .deactivating): return true
        case (.deactivating, .deactivated): return true
        case (.active, .crashed): return true
        case (.crashed, .restarting): return true
        case (.crashed, .unstable): return true
        case (.restarting, .active): return true
        case (.restarting, .failed): return true
        case (.deactivated, .notStarted): return true
        case (.failed, .notStarted): return true
        case (.unstable, .notStarted): return true
        case (.notStarted, .notStarted): return true
        default: return false
        }
    }

    // MARK: TASK-029.3: Crash Recovery Orchestration

    public func handleHostCrash(hostType: ExtensionHostType, exitCode: Int32) async throws {
        let now = Date()

        lock.lock()
        if crashCount60s[hostType] == nil { crashCount60s[hostType] = [] }
        crashCount60s[hostType]?.append(now)
        crashCount60s[hostType] = (crashCount60s[hostType] ?? []).filter { now.timeIntervalSince($0) < crashWindowSeconds }
        let count = crashCount60s[hostType]?.count ?? 0
        let config = hostConfigs[hostType]
        let pm = processManagers[hostType]
        lock.unlock()

        let crashedInstances = instanceRegistry.allInstances().filter { $0.hostType == hostType && $0.state == .active }
        for instance in crashedInstances {
            try? await transitionState(.crashed, for: instance.id)
            try? await recordLifecycleAudit(
                extensionID: instance.extensionID,
                instanceID: instance.id,
                eventType: "crashed",
                hostType: hostType
            )
        }

        if count > crashLimit {
            for instance in crashedInstances {
                try? await transitionState(.unstable, for: instance.id)
                try? await recordLifecycleAudit(
                    extensionID: instance.extensionID,
                    instanceID: instance.id,
                    eventType: "unstable",
                    hostType: hostType
                )
            }
            return
        }

        for instance in crashedInstances {
            try? await transitionState(.restarting, for: instance.id)
            try? await recordLifecycleAudit(
                extensionID: instance.extensionID,
                instanceID: instance.id,
                eventType: "restarting",
                hostType: hostType
            )
        }

        try? await Task.sleep(nanoseconds: UInt64(restartDelaySeconds * 1_000_000_000))

        guard let config = config, let pm = pm else { return }

        do {
            let newHandle = try await pm.restart(config: config)
            lock.lock()
            hostHandles[hostType] = newHandle
            lock.unlock()

            for instance in crashedInstances {
                try? await transitionState(.active, for: instance.id)
                try? await recordLifecycleAudit(
                    extensionID: instance.extensionID,
                    instanceID: instance.id,
                    eventType: "recovered",
                    hostType: hostType,
                    processID: newHandle.processID
                )
            }
        } catch {
            for instance in crashedInstances {
                try? await transitionState(.failed, for: instance.id)
                try? await recordLifecycleAudit(
                    extensionID: instance.extensionID,
                    instanceID: instance.id,
                    eventType: "restart_failed",
                    hostType: hostType
                )
            }
        }
    }

    // MARK: TASK-028.4: Activation Events

    public func shouldActivate(
        manifest: ExtensionManifest,
        activationEvent: ActivationEvent
    ) -> Bool {
        let rawEvents = manifest.metadata["activationEvents"] ?? ""
        let events = rawEvents.split(separator: ",").map(String.init)
        return events.contains { ActivationEvent.parse($0) == activationEvent }
    }

    // MARK: Audit

    public var lifecycleAuditEvents: [LifecycleAuditEvent] {
        lock.lock()
        defer { lock.unlock() }
        return lifecycleAuditLog
    }

    // MARK: Private Helpers

    private func recordLifecycleAudit(
        extensionID: ExtensionID,
        instanceID: ExtensionInstanceID,
        eventType: String,
        hostType: ExtensionHostType,
        processID: ProcessID? = nil
    ) async throws {
        let event = LifecycleAuditEvent(
            extensionID: extensionID,
            instanceID: instanceID,
            eventType: eventType,
            hostType: hostType,
            processID: processID
        )
        lock.lock()
        lifecycleAuditLog.append(event)
        lock.unlock()
    }

    private func lookupExtensionID(for instanceID: ExtensionInstanceID, workspace: WorkspaceID) -> ExtensionID {
        let instances = instanceRegistry.listInstances(workspaceID: workspace)
        return instances.first { $0.id == instanceID }?.extensionID ?? ExtensionID()
    }

}
