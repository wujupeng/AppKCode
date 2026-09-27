import Foundation

public struct JSONRPCNotification: Codable, Sendable {
    public let jsonrpc: String
    public let method: String
    public let params: AnyCodable?

    public init(method: String, params: AnyCodable? = nil) {
        self.jsonrpc = "2.0"
        self.method = method
        self.params = params
    }

    enum CodingKeys: String, CodingKey {
        case jsonrpc, method, params
    }
}