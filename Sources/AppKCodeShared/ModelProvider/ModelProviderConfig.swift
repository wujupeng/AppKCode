import Foundation

public struct ModelProviderConfig: Sendable, Equatable, Codable {
    public let id: ModelProviderID
    public let kind: ModelProviderKind
    public let mode: ModelProviderMode
    public let endpoint: URL
    public let apiKey: String?
    public let modelName: String
    public let maxTokens: Int
    public let temperature: Double

    public init(
        id: ModelProviderID = ModelProviderID(),
        kind: ModelProviderKind = .localModel,
        mode: ModelProviderMode = .local,
        endpoint: URL = LocalModeDefaults.endpoint,
        apiKey: String? = nil,
        modelName: String = LocalModeDefaults.modelName,
        maxTokens: Int = LocalModeDefaults.maxTokens,
        temperature: Double = LocalModeDefaults.temperature
    ) {
        self.id = id
        self.kind = kind
        self.mode = mode
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.modelName = modelName
        self.maxTokens = maxTokens
        self.temperature = temperature
    }
}