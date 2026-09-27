import Foundation

public struct SignatureInformation: Codable, Equatable, Sendable {
    public let label: String
    public let documentation: String?
    public let parameters: [ParameterInformation]

    public init(label: String, documentation: String? = nil, parameters: [ParameterInformation] = []) {
        self.label = label
        self.documentation = documentation
        self.parameters = parameters
    }
}

public struct ParameterInformation: Codable, Equatable, Sendable {
    public let label: String
    public let documentation: String?

    public init(label: String, documentation: String? = nil) {
        self.label = label
        self.documentation = documentation
    }
}

public struct SignatureHelp: Codable, Equatable, Sendable {
    public let signatures: [SignatureInformation]
    public let activeSignature: Int?
    public let activeParameter: Int?

    public init(signatures: [SignatureInformation], activeSignature: Int? = nil, activeParameter: Int? = nil) {
        self.signatures = signatures
        self.activeSignature = activeSignature
        self.activeParameter = activeParameter
    }
}