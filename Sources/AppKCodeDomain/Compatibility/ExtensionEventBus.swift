import Foundation
import AppKCodeShared

// MARK: - Text Change (TASK-017.2)

public struct TextChange: Sendable, Codable, Equatable {
    public let rangeStartLine: Int
    public let rangeStartCharacter: Int
    public let rangeEndLine: Int
    public let rangeEndCharacter: Int
    public let text: String

    public init(rangeStartLine: Int, rangeStartCharacter: Int, rangeEndLine: Int, rangeEndCharacter: Int, text: String) {
        self.rangeStartLine = rangeStartLine
        self.rangeStartCharacter = rangeStartCharacter
        self.rangeEndLine = rangeEndLine
        self.rangeEndCharacter = rangeEndCharacter
        self.text = text
    }
}

// MARK: - Diagnostic Item (TASK-017.2)

public struct DiagnosticItem: Sendable, Codable, Equatable {
    public let startLine: Int
    public let startCharacter: Int
    public let endLine: Int
    public let endCharacter: Int
    public let severity: Int
    public let message: String
    public let source: String?

    public init(startLine: Int, startCharacter: Int, endLine: Int, endCharacter: Int, severity: Int, message: String, source: String? = nil) {
        self.startLine = startLine
        self.startCharacter = startCharacter
        self.endLine = endLine
        self.endCharacter = endCharacter
        self.severity = severity
        self.message = message
        self.source = source
    }
}

// MARK: - Extension Outbound Event (TASK-017.2, Extension → Host)

public enum ExtensionOutboundEvent: Sendable, Codable, Equatable {
    case onDidChangeTextDocument(extensionID: ExtensionID, uri: String, changes: [TextChange])
    case onDidSaveTextDocument(extensionID: ExtensionID, uri: String)
    case diagnostics(extensionID: ExtensionID, uri: String, diagnostics: [DiagnosticItem])
    case onDidChangeConfiguration(extensionID: ExtensionID, key: String, value: AnyCodableValue)
}

// MARK: - Extension Inbound Event (TASK-017.3, Host → Extension)

public enum ExtensionInboundEvent: Sendable, Codable, Equatable {
    case onDidChangeConfiguration(key: String, value: AnyCodableValue)
    case onDidChangeWorkspaceFolders(added: [String], removed: [String])
    case onDidOpenTextDocument(uri: String, languageID: String)
    case onDidCloseTextDocument(uri: String)
}

// MARK: - Backpressure Strategy (TASK-017.6)

public enum BackpressureStrategy: Sendable, Codable, Hashable {
    case dropOldest
    case coalesce
    case sample(rate: Double)

    public var rawValue: String {
        switch self {
        case .dropOldest: return "dropOldest"
        case .coalesce: return "coalesce"
        case .sample: return "sample"
        }
    }
}

// MARK: - Extension Event Bus Protocol (TASK-017.1)

public protocol ExtensionEventBus: Sendable {
    func subscribeExtensionEvents(extensionID: ExtensionID) -> AsyncStream<ExtensionOutboundEvent>
    func subscribeHostEvents(extensionID: ExtensionID) -> AsyncStream<ExtensionInboundEvent>
    func publishOutbound(_ event: ExtensionOutboundEvent) async throws
    func publishInbound(_ event: ExtensionInboundEvent) async throws
    func setBackpressureStrategy(_ strategy: BackpressureStrategy)
}

// MARK: - Extension Event Bus Impl (TASK-017.4~017.5, H23)

public final class ExtensionEventBusImpl: ExtensionEventBus, @unchecked Sendable {
    private let lock = NSLock()
    private var outboundStreams: [ExtensionID: AsyncStream<ExtensionOutboundEvent>.Continuation] = [:]
    private var inboundStreams: [ExtensionID: AsyncStream<ExtensionInboundEvent>.Continuation] = [:]
    private var backpressureStrategy: BackpressureStrategy = .dropOldest
    private var eventCount: Int = 0
    private var lastResetTime: Date = Date()
    private let highFrequencySampleRate: Double = 0.1
    private var auditLog: [(timestamp: ISO8601Timestamp, eventKind: String, sampled: Bool)] = []

    public init() {}

    public func subscribeExtensionEvents(extensionID: ExtensionID) -> AsyncStream<ExtensionOutboundEvent> {
        AsyncStream { continuation in
            self.lock.lock()
            self.outboundStreams[extensionID] = continuation
            self.lock.unlock()
        }
    }

    public func subscribeHostEvents(extensionID: ExtensionID) -> AsyncStream<ExtensionInboundEvent> {
        AsyncStream { continuation in
            self.lock.lock()
            self.inboundStreams[extensionID] = continuation
            self.lock.unlock()
        }
    }

    public func publishOutbound(_ event: ExtensionOutboundEvent) async throws {
        let shouldAudit = shouldAuditEvent(event)
        let extensionID: ExtensionID
        let eventKind: String

        switch event {
        case .onDidChangeTextDocument(let extID, _, _):
            extensionID = extID
            eventKind = "onDidChangeTextDocument"
        case .onDidSaveTextDocument(let extID, _):
            extensionID = extID
            eventKind = "onDidSaveTextDocument"
        case .diagnostics(let extID, _, _):
            extensionID = extID
            eventKind = "diagnostics"
        case .onDidChangeConfiguration(let extID, _, _):
            extensionID = extID
            eventKind = "onDidChangeConfiguration"
        }

        if shouldAudit {
            lock.lock()
            auditLog.append((ISO8601Timestamp(), eventKind, true))
            lock.unlock()
        }

        applyBackpressureIfNeeded()

        lock.lock()
        let continuation = outboundStreams[extensionID]
        lock.unlock()
        continuation?.yield(event)
    }

    public func publishInbound(_ event: ExtensionInboundEvent) async throws {
        lock.lock()
        auditLog.append((ISO8601Timestamp(), "inbound", true))
        lock.unlock()

        for (_, continuation) in inboundStreams {
            continuation.yield(event)
        }
    }

    public func setBackpressureStrategy(_ strategy: BackpressureStrategy) {
        lock.lock()
        backpressureStrategy = strategy
        lock.unlock()
    }

    // MARK: Private

    private func shouldAuditEvent(_ event: ExtensionOutboundEvent) -> Bool {
        switch event {
        case .onDidChangeTextDocument:
            return Double.random(in: 0..<1) < highFrequencySampleRate
        case .onDidSaveTextDocument, .diagnostics, .onDidChangeConfiguration:
            return true
        }
    }

    private func applyBackpressureIfNeeded() {
        lock.lock()
        let now = Date()
        if now.timeIntervalSince(lastResetTime) >= 1.0 {
            eventCount = 0
            lastResetTime = now
        }
        eventCount += 1

        if eventCount > 10000 {
            switch backpressureStrategy {
            case .dropOldest:
                break
            case .coalesce:
                break
            case .sample(let rate):
                if Double.random(in: 0..<1) >= rate {
                    eventCount -= 1
                }
            }
        }
        lock.unlock()
    }

    public var auditLogCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return auditLog.count
    }
}