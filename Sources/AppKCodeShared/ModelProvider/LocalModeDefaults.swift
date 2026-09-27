import Foundation

public enum LocalModeDefaults {
    public static let endpoint = URL(string: "http://127.0.0.1:8080")!
    public static let mode: ModelProviderMode = .local
    public static let modelName = "local-model"
    public static let maxTokens = 4096
    public static let temperature = 0.7
}