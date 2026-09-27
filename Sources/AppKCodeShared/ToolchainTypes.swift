import Foundation

public struct ToolchainInfo: Sendable, Equatable {
    public let kind: ToolchainKind
    public let path: String
    public let version: String
    public let isAvailable: Bool

    public init(kind: ToolchainKind, path: String, version: String, isAvailable: Bool) {
        self.kind = kind
        self.path = path
        self.version = version
        self.isAvailable = isAvailable
    }
}

public enum ToolchainKind: String, Sendable, Equatable, CaseIterable {
    case swift, clang, go, python, node, make, cmake

    public var executableName: String {
        switch self {
        case .swift: return "swift"
        case .clang: return "clang"
        case .go: return "go"
        case .python: return "python3"
        case .node: return "node"
        case .make: return "make"
        case .cmake: return "cmake"
        }
    }

    public var versionArguments: [String] {
        switch self {
        case .swift: return ["--version"]
        case .clang: return ["--version"]
        case .go: return ["version"]
        case .python: return ["--version"]
        case .node: return ["--version"]
        case .make: return ["--version"]
        case .cmake: return ["--version"]
        }
    }

    public var displayName: String {
        switch self {
        case .swift: return "Swift"
        case .clang: return "Clang"
        case .go: return "Go"
        case .python: return "Python"
        case .node: return "Node.js"
        case .make: return "Make"
        case .cmake: return "CMake"
        }
    }
}