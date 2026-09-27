import Foundation
import AppKCodeShared
import AppKCodeInfrastructure

public protocol TerminalService: AnyObject {
    func createSession(shell: String?, workingDirectory: URL?, environment: [String: String]) -> TerminalSessionID
    func sendInput(_ text: String, to session: TerminalSessionID)
    func resize(cols: Int, rows: Int, session: TerminalSessionID)
    func close(session: TerminalSessionID)
    func subscribeOutput(_ handler: @escaping @Sendable (TerminalSessionID, Data) -> Void) -> TerminalSubscriptionID
    func unsubscribe(_ subscription: TerminalSubscriptionID)
    var activeSessions: [TerminalSessionID] { get }
}

public struct TerminalSubscriptionID: Sendable, Equatable, Hashable {
    public let rawValue: UUID
    public init() { self.rawValue = UUID() }
}

public final class TerminalServiceManager: TerminalService, @unchecked Sendable {
    private var sessions: [TerminalSessionID: TerminalSession] = [:]
    private var subscriptions: [TerminalSubscriptionID: @Sendable (TerminalSessionID, Data) -> Void] = [:]
    private let lock = NSLock()

    public init() {}

    public var activeSessions: [TerminalSessionID] {
        lock.lock()
        defer { lock.unlock() }
        return Array(sessions.keys)
    }

    public func createSession(shell: String?, workingDirectory: URL?, environment: [String: String]) -> TerminalSessionID {
        let session = TerminalSession()
        let shellPath = shell ?? ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/bash"
        let command = Command(executable: shellPath, arguments: [], environment: environment, workingDirectory: workingDirectory)

        session.onOutput = { [weak self] data in
            self?.notifySubscribers(session.id, data)
        }

        do {
            try session.start(command: command)
        } catch {
        }

        lock.lock()
        sessions[session.id] = session
        lock.unlock()
        return session.id
    }

    public func sendInput(_ text: String, to session: TerminalSessionID) {
        lock.lock()
        let session = sessions[session]
        lock.unlock()
        try? session?.sendInput(text)
    }

    public func resize(cols: Int, rows: Int, session: TerminalSessionID) {
        lock.lock()
        let session = sessions[session]
        lock.unlock()
        session?.resize(cols: cols, rows: rows)
    }

    public func close(session: TerminalSessionID) {
        lock.lock()
        let session = sessions.removeValue(forKey: session)
        lock.unlock()
        session?.close()
    }

    public func subscribeOutput(_ handler: @escaping @Sendable (TerminalSessionID, Data) -> Void) -> TerminalSubscriptionID {
        let id = TerminalSubscriptionID()
        lock.lock()
        subscriptions[id] = handler
        lock.unlock()
        return id
    }

    public func unsubscribe(_ subscription: TerminalSubscriptionID) {
        lock.lock()
        subscriptions.removeValue(forKey: subscription)
        lock.unlock()
    }

    private func notifySubscribers(_ sessionID: TerminalSessionID, _ data: Data) {
        lock.lock()
        let subs = subscriptions
        lock.unlock()
        for (_, handler) in subs {
            handler(sessionID, data)
        }
    }
}