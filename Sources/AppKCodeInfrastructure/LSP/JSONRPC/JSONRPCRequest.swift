import Foundation

public struct JSONRPCRequest: Codable, Sendable {
    public let jsonrpc: String
    public let id: Int64
    public let method: String
    public let params: AnyCodable?

    public init(id: Int64, method: String, params: AnyCodable? = nil) {
        self.jsonrpc = "2.0"
        self.id = id
        self.method = method
        self.params = params
    }

    enum CodingKeys: String, CodingKey {
        case jsonrpc, id, method, params
    }
}