import Foundation
import AppKCodeShared

// MARK: - Host Crash Event (TASK-018.7)

public struct HostCrashEvent: Sendable, Codable, Equatable {
    public let hostType: ExtensionHostType
    public let processID: ProcessID
    public let exitCode: Int32
    public let timestamp: ISO8601Timestamp
    public let crashCount60s: Int
    public let auditRecordID: AuditRecordID

    public init(
        hostType: ExtensionHostType,
        processID: ProcessID,
        exitCode: Int32,
        timestamp: ISO8601Timestamp = ISO8601Timestamp(),
        crashCount60s: Int,
        auditRecordID: AuditRecordID = AuditRecordID()
    ) {
        self.hostType = hostType
        self.processID = processID
        self.exitCode = exitCode
        self.timestamp = timestamp
        self.crashCount60s = crashCount60s
        self.auditRecordID = auditRecordID
    }
}

// MARK: - Host Restart Event (TASK-018.7)

public struct HostRestartEvent: Sendable, Codable, Equatable {
    public let hostType: ExtensionHostType
    public let newProcessID: ProcessID
    public let timestamp: ISO8601Timestamp
    public let restartReason: RestartReason
    public let auditRecordID: AuditRecordID

    public init(
        hostType: ExtensionHostType,
        newProcessID: ProcessID,
        timestamp: ISO8601Timestamp = ISO8601Timestamp(),
        restartReason: RestartReason,
        auditRecordID: AuditRecordID = AuditRecordID()
    ) {
        self.hostType = hostType
        self.newProcessID = newProcessID
        self.timestamp = timestamp
        self.restartReason = restartReason
        self.auditRecordID = auditRecordID
    }
}

// MARK: - Restart Reason (TASK-018.7)

public enum RestartReason: String, Sendable, Codable, Hashable {
    case crash
    case resourceLimitExceeded
    case manual
}

// MARK: - Extension Host Supervisor Protocol (TASK-018.1)

public protocol ExtensionHostSupervisor: Sendable {
    func supervise(config: ExtensionHostConfig, processManager: ExtensionHostProcessManager) async throws -> HostProcessHandle
    func stop() async throws
    var crashCount: Int { get }
    var isStable: Bool { get }
    func crashEvents() -> AsyncStream<HostCrashEvent>
    func restartEvents() -> AsyncStream<HostRestartEvent>
    func forceRestart(config: ExtensionHostConfig, processManager: ExtensionHostProcessManager) async throws -> HostProcessHandle
}

// MARK: - Extension Host Supervisor Impl (TASK-018.2~018.6, 复用 M3 LSP 自愈模式, H25, H27, H23)

public final class ExtensionHostSupervisorImpl: ExtensionHostSupervisor, @unchecked Sendable {
    private let lock = NSLock()
    private var _crashCount: Int = 0
    private var crashTimestamps: [Date] = []
    private var currentHandle: HostProcessHandle?
    private let restartTimeoutMS: Int
    private let crashLimit: Int
    private var crashContinuation: AsyncStream<HostCrashEvent>.Continuation?
    private var restartContinuation: AsyncStream<HostRestartEvent>.Continuation?
    private var crashAuditRecords: [AuditRecordID] = []
    private var restartAuditRecords: [AuditRecordID] = []
    private var currentHostType: ExtensionHostType = .vscodeExtensionHost
    private var currentConfig: ExtensionHostConfig?
    private var currentProcessManager: ExtensionHostProcessManager?

    public var crashCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _crashCount
    }

    public var isStable: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _crashCount < crashLimit
    }

    public init(restartTimeoutMS: Int = 3000, crashLimit: Int = 3) {
        self.restartTimeoutMS = restartTimeoutMS
        self.crashLimit = crashLimit
    }

    public func supervise(
        config: ExtensionHostConfig,
        processManager: ExtensionHostProcessManager
    ) async throws -> HostProcessHandle {
        lock.lock()
        currentHostType = config.hostType
        currentConfig = config
        currentProcessManager = processManager
        lock.unlock()

        let handle = try await processManager.start(config: config)

        lock.lock()
        currentHandle = handle
        lock.unlock()

        Task {
            for await state in processManager.monitorState() {
                if case .crashed(let exitCode, _) = state {
                    await self.handleCrash(exitCode: exitCode)
                }
            }
        }

        return handle
    }

    public func stop() async throws {
        lock.lock()
        currentHandle = nil
        currentConfig = nil
        currentProcessManager = nil
        lock.unlock()
    }

    public func crashEvents() -> AsyncStream<HostCrashEvent> {
        AsyncStream { continuation in
            self.lock.lock()
            self.crashContinuation = continuation
            self.lock.unlock()
        }
    }

    public func restartEvents() -> AsyncStream<HostRestartEvent> {
        AsyncStream { continuation in
            self.lock.lock()
            self.restartContinuation = continuation
            self.lock.unlock()
        }
    }

    public func forceRestart(config: ExtensionHostConfig, processManager: ExtensionHostProcessManager) async throws -> HostProcessHandle {
        let auditID = AuditRecordID()
        let newHandle = try await processManager.restart(config: config)

        lock.lock()
        currentHandle = newHandle
        let event = HostRestartEvent(
            hostType: config.hostType,
            newProcessID: newHandle.processID,
            restartReason: .manual,
            auditRecordID: auditID
        )
        restartAuditRecords.append(auditID)
        lock.unlock()

        restartContinuation?.yield(event)

        return newHandle
    }

    // MARK: Private

    private func handleCrash(exitCode: Int32) async {
        let now = Date()
        let auditID = AuditRecordID()

        lock.lock()
        crashTimestamps.append(now)
        crashTimestamps = crashTimestamps.filter { now.timeIntervalSince($0) < 60.0 }
        _crashCount = crashTimestamps.count
        crashAuditRecords.append(auditID)

        let hostType = currentHostType
        let pid = currentHandle?.processID ?? ProcessID(0)
        let count60s = _crashCount

        let crashEvent = HostCrashEvent(
            hostType: hostType,
            processID: pid,
            exitCode: exitCode,
            crashCount60s: count60s,
            auditRecordID: auditID
        )
        lock.unlock()

        crashContinuation?.yield(crashEvent)

        lock.lock()
        if _crashCount >= crashLimit {
            currentHandle = nil
            lock.unlock()
            return
        }
        lock.unlock()

        let timeout = TimeInterval(restartTimeoutMS) / 1000.0
        try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))

        lock.lock()
        let config = currentConfig
        let pm = currentProcessManager
        lock.unlock()

        guard let config = config, let pm = pm else { return }

        do {
            let newHandle = try await pm.restart(config: config)
            let restartAuditID = AuditRecordID()

            lock.lock()
            currentHandle = newHandle
            let restartEvent = HostRestartEvent(
                hostType: hostType,
                newProcessID: newHandle.processID,
                restartReason: .crash,
                auditRecordID: restartAuditID
            )
            restartAuditRecords.append(restartAuditID)
            lock.unlock()

            restartContinuation?.yield(restartEvent)
        } catch {
            lock.lock()
            currentHandle = nil
            lock.unlock()
        }
    }

    public var crashAuditRecordCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return crashAuditRecords.count
    }

    public var restartAuditRecordCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return restartAuditRecords.count
    }
}
