import Foundation
import AppKCodeShared

public final class BuildConfigurationManager: @unchecked Sendable {
    private var currentConfiguration: BuildConfiguration = .debug
    private let configURL: URL
    private let lock = NSLock()

    public init(projectRoot: URL) {
        self.configURL = projectRoot.appendingPathComponent(".appkcode").appendingPathComponent("build_config.json")
    }

    public var configuration: BuildConfiguration {
        lock.lock()
        defer { lock.unlock() }
        return currentConfiguration
    }

    public func setConfiguration(_ config: BuildConfiguration) {
        lock.lock()
        currentConfiguration = config
        lock.unlock()
        save()
    }

    public func load() {
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? Data(contentsOf: configURL) else { return }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        guard let name = json["name"] as? String else { return }
        let isDebug = json["isDebug"] as? Bool ?? true
        let xcodeScheme = json["xcodeScheme"] as? String ?? ""
        let extraArgs = json["extraArguments"] as? [String] ?? []
        currentConfiguration = BuildConfiguration(name: name, isDebug: isDebug, xcodeScheme: xcodeScheme, extraArguments: extraArgs)
    }

    public func save() {
        lock.lock()
        let config = currentConfiguration
        lock.unlock()

        let dir = configURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let json: [String: Any] = [
            "name": config.name,
            "isDebug": config.isDebug,
            "xcodeScheme": config.xcodeScheme,
            "extraArguments": config.extraArguments
        ]
        if let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
            try? data.write(to: configURL)
        }
    }

    public var availableConfigurations: [BuildConfiguration] {
        [.debug, .release]
    }
}