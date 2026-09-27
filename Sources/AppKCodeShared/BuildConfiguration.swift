import Foundation

public struct BuildConfiguration: Sendable, Equatable {
    public let name: String
    public let isDebug: Bool
    public let xcodeScheme: String
    public let extraArguments: [String]

    public init(name: String = "Debug", isDebug: Bool = true, xcodeScheme: String = "", extraArguments: [String] = []) {
        self.name = name
        self.isDebug = isDebug
        self.xcodeScheme = xcodeScheme
        self.extraArguments = extraArguments
    }

    public var swiftConfigName: String {
        isDebug ? "debug" : "release"
    }

    public static let debug = BuildConfiguration(name: "Debug", isDebug: true)
    public static let release = BuildConfiguration(name: "Release", isDebug: false)
}