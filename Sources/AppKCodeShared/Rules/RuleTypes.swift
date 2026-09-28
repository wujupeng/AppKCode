import Foundation

// MARK: - Rule ID (TASK-004.1)

public struct RuleID: Hashable, Sendable, Codable {
    public let rawValue: String
    public init() { self.rawValue = UUID().uuidString }
    public init(_ value: String) { self.rawValue = value }
}

// MARK: - Rule Scope (TASK-004.1, H17)
// session > project > global

public enum RuleScope: String, Sendable, Codable, Comparable, Equatable {
    case global
    case project
    case session

    public static func < (lhs: RuleScope, rhs: RuleScope) -> Bool {
        let order: [RuleScope] = [.global, .project, .session]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}

// MARK: - Rule Priority (TASK-004.2)
// Higher value = higher priority

public struct RulePriority: Sendable, Codable, Comparable, Equatable {
    public let value: Int

    public init(_ value: Int) {
        self.value = value
    }

    public static func < (lhs: RulePriority, rhs: RulePriority) -> Bool {
        lhs.value < rhs.value
    }
}

// MARK: - Rule Enforcement (TASK-004.2)

public enum RuleEnforcement: String, Sendable, Codable, Equatable {
    case block
    case warn
    case info
}

// MARK: - Rule Target (TASK-004.3)

public enum RuleTarget: Sendable, Codable, Equatable {
    case toolID(ToolID)
    case toolCategory(ToolCategory)
    case operationKind(String)
    case all
}

// MARK: - Rule Matcher (TASK-004.3)

public enum RuleMatcher: Sendable, Codable, Equatable {
    case equals(String)
    case contains(String)
    case regex(String)
    case always
}

// MARK: - Rule Condition (TASK-004.3)

public struct RuleCondition: Sendable, Codable, Equatable {
    public let target: RuleTarget
    public let matcher: RuleMatcher

    public init(target: RuleTarget, matcher: RuleMatcher) {
        self.target = target
        self.matcher = matcher
    }
}

// MARK: - Rule Instruction (TASK-004.4)

public struct RuleInstruction: Sendable, Codable, Equatable {
    public let description: String
    public let requireApproval: Bool
    public let denyExecution: Bool
    public let maxRetries: Int?

    public init(
        description: String,
        requireApproval: Bool = false,
        denyExecution: Bool = false,
        maxRetries: Int? = nil
    ) {
        self.description = description
        self.requireApproval = requireApproval
        self.denyExecution = denyExecution
        self.maxRetries = maxRetries
    }
}

// MARK: - Rule (TASK-004.5)

public struct Rule: Sendable, Codable, Equatable {
    public let id: RuleID
    public let name: String
    public let scope: RuleScope
    public let priority: RulePriority
    public let condition: RuleCondition
    public let instruction: RuleInstruction
    public let enforcement: RuleEnforcement
    public let sourceFile: URL?

    public init(
        id: RuleID = RuleID(),
        name: String,
        scope: RuleScope,
        priority: RulePriority,
        condition: RuleCondition,
        instruction: RuleInstruction,
        enforcement: RuleEnforcement,
        sourceFile: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.scope = scope
        self.priority = priority
        self.condition = condition
        self.instruction = instruction
        self.enforcement = enforcement
        self.sourceFile = sourceFile
    }
}

// MARK: - Rule Set (TASK-004.6)

public struct RuleSet: Sendable, Codable, Equatable {
    public let rules: [Rule]

    public init(rules: [Rule] = []) {
        self.rules = rules
    }
}

// MARK: - Rule Conflict (TASK-004.6)

public enum RuleConflictType: String, Sendable, Codable, Equatable {
    case contradictoryInstruction
    case sameTargetDifferentEnforcement
    case priorityCycle
}

public struct RuleConflict: Sendable, Codable, Equatable {
    public let rule1: RuleID
    public let rule2: RuleID
    public let conflictType: RuleConflictType
    public let description: String

    public init(rule1: RuleID, rule2: RuleID, conflictType: RuleConflictType, description: String) {
        self.rule1 = rule1
        self.rule2 = rule2
        self.conflictType = conflictType
        self.description = description
    }
}

// MARK: - Rule Evaluation Result (TASK-004.7)

public enum RuleEvaluationResult: Sendable, Codable, Equatable {
    case allow
    case warn(rule: RuleID, message: String)
    case block(rule: RuleID, message: String)
    case noApplicableRule
}

// MARK: - Rule Resolution (TASK-020.2, referenced by RuleResolver)

public enum RuleResolutionStrategy: String, Sendable, Codable, Equatable {
    case higherPriorityWins
    case higherScopeWins
    case denyByDefault
    case manualOverride
}

public struct RuleResolution: Sendable, Codable, Equatable {
    public let conflict: RuleConflict
    public let strategy: RuleResolutionStrategy
    public let resolvedRuleID: RuleID?
    public let description: String

    public init(conflict: RuleConflict, strategy: RuleResolutionStrategy, resolvedRuleID: RuleID? = nil, description: String) {
        self.conflict = conflict
        self.strategy = strategy
        self.resolvedRuleID = resolvedRuleID
        self.description = description
    }
}

// MARK: - Reload Result (used by Skill/Rule hot reload)

public struct ReloadResult: Sendable, Codable, Equatable {
    public let added: Int
    public let removed: Int
    public let updated: Int
    public let errors: [String]

    public init(added: Int = 0, removed: Int = 0, updated: Int = 0, errors: [String] = []) {
        self.added = added
        self.removed = removed
        self.updated = updated
        self.errors = errors
    }
}