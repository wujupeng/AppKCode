import Foundation
import AppKCodeShared

// MARK: - VS Code Package Parser Protocol (TASK-009.1)

public protocol VSCodePackageParser: Sendable {
    func parse(packageJSONPath: String) async throws -> VSCodeExtensionManifest
    func validateArchitecture(_ manifest: VSCodeExtensionManifest) -> ArchitectureValidation
}

// MARK: - VS Code Package Parser Impl (TASK-009.2, REQ-042)

public final class VSCodePackageParserImpl: VSCodePackageParser, @unchecked Sendable {
    public init() {}

    public func parse(packageJSONPath: String) async throws -> VSCodeExtensionManifest {
        let url = URL(fileURLWithPath: packageJSONPath)
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

        guard let name = json["name"] as? String else {
            throw NSError(domain: "VSCodePackageParser", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing 'name' field"])
        }

        let versionStr = json["version"] as? String ?? "0.0.0"
        let version = parseSemVer(versionStr) ?? SemVer(0, 0, 0)

        let engines = json["engines"] as? [String: Any] ?? [:]
        let enginesVSCode = engines["vscode"] as? String ?? "*"

        let activationEvents = json["activationEvents"] as? [String] ?? []
        let mainEntry = json["main"] as? String ?? "extension.js"

        let contributesDict = json["contributes"] as? [String: Any] ?? [:]
        let contributes = VSCodeContributes(
            commands: (contributesDict["commands"] as? [[String: Any]])?.compactMap { $0["command"] as? String } ?? [],
            configuration: (contributesDict["configuration"] as? [[String: Any]])?.compactMap { $0["title"] as? String } ?? [],
            languages: (contributesDict["languages"] as? [[String: Any]])?.compactMap { $0["id"] as? String } ?? [],
            snippets: (contributesDict["snippets"] as? [[String: Any]])?.compactMap { $0["language"] as? String } ?? []
        )

        let architectures: [Architecture] = [.x86_64]

        return VSCodeExtensionManifest(
            extensionID: name,
            version: version,
            enginesVSCode: enginesVSCode,
            activationEvents: activationEvents,
            mainEntry: mainEntry,
            contributes: contributes,
            architectures: architectures
        )
    }

    public func validateArchitecture(_ manifest: VSCodeExtensionManifest) -> ArchitectureValidation {
        if manifest.architectures.contains(.x86_64) || manifest.architectures.contains(.universal) {
            return .valid
        }
        if manifest.architectures.contains(.arm64) {
            return .arm64Only(module: manifest.extensionID)
        }
        return .missing
    }

    private func parseSemVer(_ str: String) -> SemVer? {
        let parts = str.split(separator: ".")
        guard parts.count >= 3 else { return nil }
        guard let major = Int(parts[0]), let minor = Int(parts[1]) else { return nil }
        let patchStr = parts[2].split(separator: "-").first.map(String.init) ?? String(parts[2])
        guard let patch = Int(patchStr) else { return nil }
        return SemVer(major, minor, patch)
    }
}

// MARK: - JetBrains Plugin Parser Protocol (TASK-009.3)

public protocol JetBrainsPluginParser: Sendable {
    func parse(pluginXMLPath: String) async throws -> JetBrainsPluginManifest
    func validateArchitecture(_ manifest: JetBrainsPluginManifest) -> ArchitectureValidation
    func scanInternalAPIReferences(jarPath: String) -> [String]
}

// MARK: - JetBrains Plugin Parser Impl (TASK-009.4~009.7, REQ-043~045)

public final class JetBrainsPluginParserImpl: JetBrainsPluginParser, @unchecked Sendable {
    public init() {}

    public func parse(pluginXMLPath: String) async throws -> JetBrainsPluginManifest {
        let url = URL(fileURLWithPath: pluginXMLPath)
        let data = try Data(contentsOf: url)
        let doc = try XMLDocument(data: data, options: [])

        let root = doc.rootElement()
        let id = (root?.elements(forName: "id").first?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let name = (root?.elements(forName: "name").first?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let versionStr = (root?.elements(forName: "version").first?.stringValue ?? "0.0.0").trimmingCharacters(in: .whitespacesAndNewlines)
        let version = parseSemVer(versionStr) ?? SemVer(0, 0, 0)

        let sinceBuild = (root?.elements(forName: "idea-version").first?.attribute(forName: "since-build")?.stringValue ?? "")
        let untilBuild = root?.elements(forName: "idea-version").first?.attribute(forName: "until-build")?.stringValue

        var extensionPoints: [JetBrainsExtensionPoint] = []
        var actions: [JetBrainsActionDecl] = []

        if let extensionsElements = root?.elements(forName: "extensions") {
            for extElem in extensionsElements {
                if let children = extElem.children {
                    for child in children {
                        if let elem = child as? XMLElement {
                            let epName = elem.name ?? ""
                            let implClass = elem.attribute(forName: "implementation")?.stringValue ?? ""
                            let ifaceClass = elem.attribute(forName: "interface")?.stringValue ?? ""
                            extensionPoints.append(JetBrainsExtensionPoint(
                                name: epName,
                                interfaceClass: ifaceClass,
                                implementationClass: implClass
                            ))
                        }
                    }
                }
            }
        }

        if let actionsElements = root?.elements(forName: "actions") {
            for actionsElem in actionsElements {
                if let children = actionsElem.children {
                    for child in children {
                        if let elem = child as? XMLElement, elem.name == "action" {
                            let actionID = elem.attribute(forName: "id")?.stringValue ?? ""
                            let className = elem.attribute(forName: "class")?.stringValue ?? ""
                            let textAttr = elem.attribute(forName: "text")
                            let text = textAttr?.stringValue
                            actions.append(JetBrainsActionDecl(id: actionID, className: className, text: text))
                        }
                    }
                }
            }
        }

        let mainJAR = "lib/\(name).jar"

        return JetBrainsPluginManifest(
            pluginID: id.isEmpty ? name : id,
            version: version,
            sinceBuild: sinceBuild,
            untilBuild: untilBuild,
            extensionPoints: extensionPoints,
            actions: actions,
            mainJAR: mainJAR,
            architectures: [.x86_64]
        )
    }

    public func validateArchitecture(_ manifest: JetBrainsPluginManifest) -> ArchitectureValidation {
        if manifest.architectures.contains(.x86_64) || manifest.architectures.contains(.universal) {
            return .valid
        }
        if manifest.architectures.contains(.arm64) {
            return .arm64Only(module: manifest.pluginID)
        }
        return .missing
    }

    public func scanInternalAPIReferences(jarPath: String) -> [String] {
        let internalPatterns = [
            "com.intellij.psi.impl.",
            "com.intellij.openapi.application.impl.",
            "com.intellij.util.messages.impl."
        ]

        var references: [String] = []

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/strings")
        process.arguments = [jarPath]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            for line in output.split(separator: "\n") {
                let str = String(line)
                for pattern in internalPatterns {
                    if str.contains(pattern) {
                        references.append(str)
                        break
                    }
                }
            }
        } catch {
        }

        return references
    }

    private func parseSemVer(_ str: String) -> SemVer? {
        let parts = str.split(separator: ".")
        guard parts.count >= 3 else { return nil }
        guard let major = Int(parts[0]), let minor = Int(parts[1]) else { return nil }
        let patchStr = parts[2].split(separator: "-").first.map(String.init) ?? String(parts[2])
        guard let patch = Int(patchStr) else { return nil }
        return SemVer(major, minor, patch)
    }
}