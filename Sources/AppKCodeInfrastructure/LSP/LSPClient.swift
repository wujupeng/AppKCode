import Foundation

public final class LSPClient: ObservableObject, @unchecked Sendable {
    private let transport: LSPTransport
    private let processManager: LSPProcessManager
    private var nextRequestId: Int64 = 0
    private var pendingRequests: [Int64: CheckedContinuation<AnyCodable, Error>] = [:]
    private var notificationHandlers: [String: (AnyCodable?) -> Void] = [:]
    private let lock = NSLock()
    private var receiveTask: Task<Void, Never>?
    private let timeout: TimeInterval = 30.0

    @Published public private(set) var isInitialized = false
    @Published public private(set) var serverCapabilities: AnyCodable?

    public init(transport: LSPTransport, processManager: LSPProcessManager) {
        self.transport = transport
        self.processManager = processManager
    }

    public func startReceiveLoop() {
        receiveTask?.cancel()
        receiveTask = Task.detached { [weak self] in
            await self?.receiveLoop()
        }
    }

    public func stopReceiveLoop() {
        receiveTask?.cancel()
        receiveTask = nil
    }

    private func receiveLoop() async {
        while !Task.isCancelled {
            do {
                let messages = try await transport.receive()
                for message in messages {
                    handleMessage(message)
                }
                if messages.isEmpty {
                    try? await Task.sleep(nanoseconds: 10_000_000)
                }
            } catch {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }

    private func handleMessage(_ message: JSONRPCMessage) {
        switch message {
        case .response(let response):
            handleResponse(response)
        case .notification(let notification):
            handleNotification(notification)
        case .request:
            break
        }
    }

    private func handleResponse(_ response: JSONRPCResponse) {
        lock.lock()
        let continuation = pendingRequests.removeValue(forKey: response.id)
        lock.unlock()

        if let continuation = continuation {
            if let error = response.error {
                continuation.resume(throwing: LSPClientError.serverError(error))
            } else {
                continuation.resume(returning: response.result ?? AnyCodable(null: ()))
            }
        }
    }

    private func handleNotification(_ notification: JSONRPCNotification) {
        lock.lock()
        let handler = notificationHandlers[notification.method]
        lock.unlock()
        handler?(notification.params)
    }

    public func sendRequest(_ method: String, params: AnyCodable? = nil) async throws -> AnyCodable {
        lock.lock()
        nextRequestId += 1
        let id = nextRequestId
        lock.unlock()

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AnyCodable, Error>) in
            lock.lock()
            self.pendingRequests[id] = continuation
            lock.unlock()

            do {
                try self.transport.sendRequest(id: id, method: method, params: params)
            } catch {
                lock.lock()
                self.pendingRequests.removeValue(forKey: id)
                lock.unlock()
                continuation.resume(throwing: error)
                return
            }

            Task.detached {
                try? await Task.sleep(nanoseconds: UInt64(self.timeout * 1_000_000_000))
                self.lock.lock()
                let pending = self.pendingRequests.removeValue(forKey: id)
                self.lock.unlock()
                if let pending = pending {
                    pending.resume(throwing: LSPClientError.timeout)
                }
            }
        }
    }

    public func sendNotification(_ method: String, params: AnyCodable? = nil) throws {
        try transport.sendNotification(method: method, params: params)
    }

    public func registerNotificationHandler(_ method: String, handler: @escaping (AnyCodable?) -> Void) {
        lock.lock()
        notificationHandlers[method] = handler
        lock.unlock()
    }

    public func initialize(workspaceRoot: URL) async throws -> AnyCodable {
        let rootUri = workspaceRoot.path
        let params: [String: Any] = [
            "processId": ProcessInfo.processInfo.processIdentifier,
            "rootUri": "file://\(rootUri)",
            "capabilities": [
                "textDocument": [
                    "completion": ["completionItem": ["snippetSupport": true]],
                    "synchronization": ["didSave": true, "willSave": true, "dynamicRegistration": false]
                ] as [String: Any],
                "workspace": [:] as [String: Any]
            ] as [String: Any]
        ]

        let result = try await sendRequest("initialize", params: AnyCodable(params))
        serverCapabilities = result
        isInitialized = true

        try sendNotification("initialized", params: AnyCodable([String: Any]()))

        return result
    }

    public func shutdown() async throws {
        if isInitialized {
            _ = try? await sendRequest("shutdown")
            try? sendNotification("exit")
            isInitialized = false
        }
        stopReceiveLoop()
        processManager.stop()
    }

    public func textDocumentDidOpen(uri: String, languageId: String, version: Int, text: String) throws {
        let params: [String: Any] = [
            "textDocument": [
                "uri": uri,
                "languageId": languageId,
                "version": version,
                "text": text
            ] as [String: Any]
        ]
        try sendNotification("textDocument/didOpen", params: AnyCodable(params))
    }

    public func textDocumentDidChange(uri: String, version: Int, text: String) throws {
        let params: [String: Any] = [
            "textDocument": ["uri": uri, "version": version] as [String: Any],
            "contentChanges": [["text": text]] as [Any]
        ]
        try sendNotification("textDocument/didChange", params: AnyCodable(params))
    }

    public func textDocumentDidClose(uri: String) throws {
        let params: [String: Any] = [
            "textDocument": ["uri": uri] as [String: Any]
        ]
        try sendNotification("textDocument/didClose", params: AnyCodable(params))
    }

    public func textDocumentCompletion(uri: String, line: Int, character: Int) async throws -> AnyCodable {
        let params: [String: Any] = [
            "textDocument": ["uri": uri] as [String: Any],
            "position": ["line": line, "character": character] as [String: Any]
        ]
        return try await sendRequest("textDocument/completion", params: AnyCodable(params))
    }

    public func textDocumentHover(uri: String, line: Int, character: Int) async throws -> AnyCodable {
        let params: [String: Any] = [
            "textDocument": ["uri": uri] as [String: Any],
            "position": ["line": line, "character": character] as [String: Any]
        ]
        return try await sendRequest("textDocument/hover", params: AnyCodable(params))
    }

    public func textDocumentDefinition(uri: String, line: Int, character: Int) async throws -> AnyCodable {
        let params: [String: Any] = [
            "textDocument": ["uri": uri] as [String: Any],
            "position": ["line": line, "character": character] as [String: Any]
        ]
        return try await sendRequest("textDocument/definition", params: AnyCodable(params))
    }

    public func textDocumentDeclaration(uri: String, line: Int, character: Int) async throws -> AnyCodable {
        let params: [String: Any] = [
            "textDocument": ["uri": uri] as [String: Any],
            "position": ["line": line, "character": character] as [String: Any]
        ]
        return try await sendRequest("textDocument/declaration", params: AnyCodable(params))
    }

    public func textDocumentReferences(uri: String, line: Int, character: Int) async throws -> AnyCodable {
        let params: [String: Any] = [
            "textDocument": ["uri": uri] as [String: Any],
            "position": ["line": line, "character": character] as [String: Any],
            "context": ["includeDeclaration": false] as [String: Any]
        ]
        return try await sendRequest("textDocument/references", params: AnyCodable(params))
    }

    public func textDocumentDocumentSymbol(uri: String) async throws -> AnyCodable {
        let params: [String: Any] = [
            "textDocument": ["uri": uri] as [String: Any]
        ]
        return try await sendRequest("textDocument/documentSymbol", params: AnyCodable(params))
    }

    public func workspaceSymbol(query: String) async throws -> AnyCodable {
        let params: [String: Any] = ["query": query]
        return try await sendRequest("workspace/symbol", params: AnyCodable(params))
    }

    public func textDocumentSignatureHelp(uri: String, line: Int, character: Int) async throws -> AnyCodable {
        let params: [String: Any] = [
            "textDocument": ["uri": uri] as [String: Any],
            "position": ["line": line, "character": character] as [String: Any]
        ]
        return try await sendRequest("textDocument/signatureHelp", params: AnyCodable(params))
    }

    public func textDocumentRename(uri: String, line: Int, character: Int, newName: String) async throws -> AnyCodable {
        let params: [String: Any] = [
            "textDocument": ["uri": uri] as [String: Any],
            "position": ["line": line, "character": character] as [String: Any],
            "newName": newName
        ]
        return try await sendRequest("textDocument/rename", params: AnyCodable(params))
    }
}

public enum LSPClientError: Error, Sendable, Equatable {
    case timeout
    case serverError(JSONRPCError)
    case notInitialized
    case parseError(String)
}