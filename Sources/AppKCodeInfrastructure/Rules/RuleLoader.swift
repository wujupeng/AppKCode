import Foundation
import AppKCodeShared

// MARK: - Rule Loader (TASK-011)

public final class RuleLoader: @unchecked Sendable {
    public init() {}

    public func loadFromDirectory(_ dir: URL, scope: RuleScope) async throws -> [Rule] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: dir.path) else {
            return []
        }

        let entries = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        let ruleFiles = entries.filter { $0.pathExtension == "md" }

        var rules: [Rule] = []
        var lastValidRules: [Rule] = []

        for file in ruleFiles {
            do {
                let content = try String(contentsOf: file, encoding: .utf8)
                if let rule = parseRule(content, scope: scope, sourceFile: file) {
                    rules.append(rule)
                    lastValidRules = rules
                }
            } catch {
                continue
            }
        }

        return rules
    }

    func parseRule(_ content: String, scope: RuleScope, sourceFile: URL) -> Rule? {
        let parts = content.components(separatedBy: "---")
        guard parts.count >= 3 else { return nil }

        let frontmatter = parts[1]
        let body = parts[2].trimmingCharacters(in: .whitespacesAndNewlines)

        let yamlLines = frontmatter.components(separatedBy: .newlines).filter { !$0.isEmpty }
        var name = ""
        var priorityValue = 0
        var enforcementStr = "info"
        var targetStr = "all"
        var matcherStr = "always"

        for line in yamlLines {
            let kv = line.components(separatedBy: ":")
            guard kv.count >= 2 else { continue }
            let key = kv[0].trimmingCharacters(in: .whitespaces)
            let value = kv[1].trimmingCharacters(in: .whitespaces)
            switch key {
            case "name": name = value
            case "priority": priorityValue = Int(value) ?? 0
            case "enforcement": enforcementStr = value
            case "target": targetStr = value
            case "matcher": matcherStr = value
            default: break
            }
        }

        let enforcement = RuleEnforcement(rawValue: enforcementStr) ?? .info

        let target: RuleTarget
        if targetStr == "all" {
            target = .all
        } else {
            target = .toolID(ToolID(targetStr))
        }

        let matcher: RuleMatcher
        if matcherStr == "always" {
            matcher = .always
        } else {
            matcher = .equals(matcherStr)
        }

        return Rule(
            name: name,
            scope: scope,
            priority: RulePriority(priorityValue),
            condition: RuleCondition(target: target, matcher: matcher),
            instruction: RuleInstruction(description: body),
            enforcement: enforcement,
            sourceFile: sourceFile
        )
    }
}

// MARK: - Rule Store (TASK-011.3)

public final class RuleStore: @unchecked Sendable {
    private let rulesetURL: URL

    public init(workspaceRoot: URL) {
        self.rulesetURL = workspaceRoot
            .appendingPathComponent(".appkcode")
            .appendingPathComponent("rules")
            .appendingPathComponent("ruleset.json")
    }

    public func save(_ ruleSet: RuleSet) async throws {
        let fm = FileManager.default
        let dir = rulesetURL.deletingLastPathComponent()
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let data = try encoder.encode(ruleSet)
        try data.write(to: rulesetURL)
    }

    public func load() async throws -> RuleSet {
        let fm = FileManager.default
        guard fm.fileExists(atPath: rulesetURL.path) else {
            return RuleSet()
        }

        let data = try Data(contentsOf: rulesetURL)
        return try JSONDecoder().decode(RuleSet.self, from: data)
    }
}

// MARK: - Rule File Watcher (TASK-011.4)

public enum RuleReloadEvent: Sendable, Equatable {
    case rulesChanged
    case error(String)
}

public final class RuleFileWatcher: @unchecked Sendable {
    private let watchPath: URL
    private var source: DispatchSourceFileSystemObject?
    private var eventContinuation: AsyncStream<RuleReloadEvent>.Continuation?

    public init(watchPath: URL) {
        self.watchPath = watchPath
    }

    public var events: AsyncStream<RuleReloadEvent> {
        AsyncStream { continuation in
            self.eventContinuation = continuation
        }
    }

    public func startWatching() {
        let fd = open(watchPath.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename],
            queue: .global()
        )

        source.setEventHandler { [weak self] in
            self?.eventContinuation?.yield(.rulesChanged)
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        self.source = source
    }

    public func stopWatching() {
        source?.cancel()
        source = nil
    }
}