import Foundation

public struct ModelProviderID: Hashable, Sendable, Codable {
    public let rawValue: String
    public init(_ value: String) { self.rawValue = value }
    public init() { self.rawValue = UUID().uuidString }
}

public enum ModelProviderKind: String, Sendable, Equatable, Codable {
    case openAICompatible
    case localModel
    case cloudModel
}

public enum ModelProviderMode: String, Sendable, Equatable, Codable {
    case local
    case cloud
}