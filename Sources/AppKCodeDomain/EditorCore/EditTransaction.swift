import Foundation

public final class EditTransaction: @unchecked Sendable {
    public let id = UUID()
    public private(set) var operations: [EditOperation] = []
    public let timestamp: Date

    public init(operations: [EditOperation] = []) {
        self.operations = operations
        self.timestamp = Date()
    }

    public func add(_ op: EditOperation) {
        operations.append(op)
    }

    public func apply(to document: EditorCoreDocument) {
        for op in operations {
            switch op.type {
            case .insert:
                document.replace(range: op.range, with: op.text)
            case .delete:
                document.replace(range: op.range, with: "")
            case .replace:
                document.replace(range: op.range, with: op.text)
            }
        }
    }

    public var inverse: EditTransaction {
        let reversedOps = operations.reversed().map { $0.inverse }
        return EditTransaction(operations: reversedOps)
    }
}

public final class EditorUndoManager: @unchecked Sendable {
    private var undoStack: [EditTransaction] = []
    private var redoStack: [EditTransaction] = []
    private let lock = NSLock()
    public var limit: Int = 100

    public init() {}

    public var canUndo: Bool {
        lock.lock(); defer { lock.unlock() }
        return !undoStack.isEmpty
    }

    public var canRedo: Bool {
        lock.lock(); defer { lock.unlock() }
        return !redoStack.isEmpty
    }

    public func record(_ transaction: EditTransaction) {
        lock.lock()
        undoStack.append(transaction)
        redoStack.removeAll()
        if undoStack.count > limit {
            undoStack.removeFirst(undoStack.count - limit)
        }
        lock.unlock()
    }

    public func undo(document: EditorCoreDocument) -> EditTransaction? {
        lock.lock()
        guard let transaction = undoStack.popLast() else { lock.unlock(); return nil }
        redoStack.append(transaction)
        lock.unlock()
        let inverse = transaction.inverse
        inverse.apply(to: document)
        return inverse
    }

    public func redo(document: EditorCoreDocument) -> EditTransaction? {
        lock.lock()
        guard let transaction = redoStack.popLast() else { lock.unlock(); return nil }
        undoStack.append(transaction)
        lock.unlock()
        transaction.apply(to: document)
        return transaction
    }

    public func clear() {
        lock.lock()
        undoStack.removeAll()
        redoStack.removeAll()
        lock.unlock()
    }
}