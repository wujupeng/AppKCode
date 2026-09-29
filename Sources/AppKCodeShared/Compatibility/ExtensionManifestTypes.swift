import Foundation

// MARK: - Extension ID (TASK-001.1)

public struct ExtensionID: Hashable, Sendable, Codable {
    public let rawValue: String
    public init() { self.rawValue = UUID().uuidString }
    public init(_ value: String) { self.rawValue = value }
}

// MARK: - API Surface (TASK-001.1)

public enum APISurface: Sendable, Codable, Hashable {
    case native
    case vscode
    case jetbrains
    case lsp
    case mcp
    case custom(String)
}

// MARK: - Extension Kind (TASK-001.2)

public enum ExtensionKind: String, Sendable, Codable, Hashable {
    case codeartsAgent
    case vscodeExtension
    case jetbrainsPlugin
    case lspServer
    case mcpServer
    case custom
}

// MARK: - Architecture (TASK-001.4)

public enum Architecture: String, Sendable, Codable, Hashable {
    case x86_64
    case arm64
    case universal
}

// MARK: - Semantic Version (TASK-001.4, TASK-001.5, SemVer 2.0.0)

public struct SemVer: Sendable, Codable, Hashable, Comparable {
    public let major: Int
    public let minor: Int
    public let patch: Int
    public let preRelease: String?
    public let buildMetadata: String?

    public init(
        _ major: Int,
        _ minor: Int,
        _ patch: Int,
        preRelease: String? = nil,
        buildMetadata: String? = nil
    ) {
        self.major = major
        self.minor = minor
        self.patch = patch
        self.preRelease = preRelease
        self.buildMetadata = buildMetadata
    }

    public static func < (lhs: SemVer, rhs: SemVer) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }

        switch (lhs.preRelease, rhs.preRelease) {
        case (nil, nil):
            return false
        case (nil, _?):
            return false
        case (_?, nil):
            return true
        case (let l?, let r?):
            return comparePreRelease(l, r) < 0
        }
    }

    public static func == (lhs: SemVer, rhs: SemVer) -> Bool {
        lhs.major == rhs.major
            && lhs.minor == rhs.minor
            && lhs.patch == rhs.patch
            && lhs.preRelease == rhs.preRelease
    }

    private static func comparePreRelease(_ lhs: String, _ rhs: String) -> Int {
        let lhsParts = lhs.split(separator: ".").map(String.init)
        let rhsParts = rhs.split(separator: ".").map(String.init)
        let count = Swift.min(lhsParts.count, rhsParts.count)
        for i in 0..<count {
            let l = lhsParts[i]
            let r = rhsParts[i]
            let lIsNum = l.allSatisfy { $0.isNumber }
            let rIsNum = r.allSatisfy { $0.isNumber }
            if lIsNum && rIsNum {
                let li = Int(l) ?? 0
                let ri = Int(r) ?? 0
                if li != ri { return li < ri ? -1 : 1 }
            } else if lIsNum && !rIsNum {
                return -1
            } else if !lIsNum && rIsNum {
                return 1
            } else {
                if l != r { return l < r ? -1 : 1 }
            }
        }
        if lhsParts.count != rhsParts.count {
            return lhsParts.count < rhsParts.count ? -1 : 1
        }
        return 0
    }
}

// MARK: - Extension Manifest (TASK-001.3)

public struct ExtensionManifest: Sendable, Codable, Hashable {
    public let id: ExtensionID
    public let name: String
    public let version: SemVer
    public let kind: ExtensionKind
    public let apiSurface: APISurface
    public let architectures: [Architecture]
    public let contractID: CapabilityContractID
    public let entryPoint: String
    public let permissions: [ExtensionPermission]
    public let capabilities: [CapabilityID]
    public let metadata: [String: String]

    public init(
        id: ExtensionID,
        name: String,
        version: SemVer,
        kind: ExtensionKind,
        apiSurface: APISurface,
        architectures: [Architecture],
        contractID: CapabilityContractID,
        entryPoint: String,
        permissions: [ExtensionPermission] = [],
        capabilities: [CapabilityID] = [],
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.kind = kind
        self.apiSurface = apiSurface
        self.architectures = architectures
        self.contractID = contractID
        self.entryPoint = entryPoint
        self.permissions = permissions
        self.capabilities = capabilities
        self.metadata = metadata
    }
}

// MARK: - Extension Load State (TASK-001.6)

public enum ExtensionLoadState: Sendable, Codable, Hashable, Equatable {
    case notLoaded
    case loading
    case loaded
    case enabled
    case disabled
    case failed(reason: String)
    case incompatible(reason: String)
}