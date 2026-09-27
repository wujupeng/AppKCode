import Foundation

public struct AnyCodable: Sendable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(null: Void) {
        self.value = NSNull()
    }
}

extension AnyCodable: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let v as Bool:
            try container.encode(v)
        case let v as Int:
            try container.encode(v)
        case let v as Int64:
            try container.encode(v)
        case let v as Double:
            try container.encode(v)
        case let v as String:
            try container.encode(v)
        case let v as [AnyCodable]:
            try container.encode(v)
        case let v as [String: AnyCodable]:
            try container.encode(v)
        case let v as [Any]:
            try container.encode(v.map { AnyCodable($0) })
        case let v as [String: Any]:
            try container.encode(v.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

extension AnyCodable: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self.init(null: ())
        } else if let v = try? container.decode(Bool.self) {
            self.init(v)
        } else if let v = try? container.decode(Int64.self) {
            self.init(v)
        } else if let v = try? container.decode(Double.self) {
            self.init(v)
        } else if let v = try? container.decode(String.self) {
            self.init(v)
        } else if let v = try? container.decode([AnyCodable].self) {
            self.init(v)
        } else if let v = try? container.decode([String: AnyCodable].self) {
            self.init(v)
        } else {
            self.init(null: ())
        }
    }
}

extension AnyCodable: Equatable {
    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case (is NSNull, is NSNull): return true
        case let (a as Bool, b as Bool): return a == b
        case let (a as Int64, b as Int64): return a == b
        case let (a as Int, b as Int): return a == b
        case let (a as Double, b as Double): return a == b
        case let (a as String, b as String): return a == b
        case let (a as [AnyCodable], b as [AnyCodable]): return a == b
        case let (a as [String: AnyCodable], b as [String: AnyCodable]): return a == b
        default: return false
        }
    }
}