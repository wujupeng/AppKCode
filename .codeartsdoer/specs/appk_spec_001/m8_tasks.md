# APPK-M8-TASK-001 v0.1 — AppKCode M8 编码任务计划

> **文档编号**：APPK-M8-TASK-001
> **版本**：v0.1
> **状态**：Draft
> **对应需求**：APPK-SPEC-001 v0.1
> **对应设计**：APPK-DESIGN-001 v0.1
> **里程碑**：M8 — MCP / Skills / Rules Runtime
> **PM 授权**：APPK-TASK-008
> **前置基线**：M7 交付完成，545/545 测试通过
> **构建环境**：macOS 13.0, Swift 5.8, x86_64-apple-macos13.0
> **任务编号格式**：APPK-M8-TASK-XXX（主任务），APPK-M8-TASK-XXX.Y（子任务）

---

## M8 范围与约束摘要

### 纳入范围

| 域 | 能力 |
|----|------|
| A. MCP Client — Server Discovery | 发现、注册、配置、启用/禁用 MCP Server（stdio / HTTP transport，SSE 可选） |
| B. MCP Client — Tool Discovery | 从 MCP Server 拉取 tools/list，生成 ToolSchema 注册到 ToolRegistry |
| C. MCP Client — Resource Discovery | 从 MCP Server 拉取 resources/list，暴露资源句柄 |
| D. MCP Client — Tool Invocation | 调用 MCP Server tools/call，结果映射为 ToolOutput |
| E. MCP Client — Result Handling | 成功/失败/超时/取消四态，复用 M7 ActionResultTypes |
| F. MCP Client — Error / Timeout / Cancel | MCP 协议错误映射、调用超时、取消传播 |
| G. Skills — 定义模型 | id, name, description, input schema (JSON Schema), output schema, execution policy |
| H. Skills — Registry | 注册/查询/列举/热重载 Skill 清单 |
| I. Skills — Execution | Skill 作为能力编排单元，内部编排 Tool 调用，经 Authorization |
| J. Rules — 定义模型 | scope (global/project/session), priority, condition, instruction, enforcement (block/warn/info) |
| K. Rules — Engine | 规则评估、优先级排序、作用域解析 |
| L. Rules — Conflict Detection | 冲突检测与解决机制（H17） |
| M. Rules — Enforcement | 将规则约束应用到 Agent Plan 生成与执行流程 |

### 核心架构

```
                     ┌──────────────┐
                     │  Agent Plan  │  (复用 M7 Planner)
                     └──────┬───────┘
                            │
                            ▼
                 ┌──────────────────────┐
                 │   Rule Engine (M8)   │  ← 规则约束前置（H17）
                 │   scope + priority   │
                 └──────────┬───────────┘
                            │ 约束后 Plan
                            ▼
                     ┌──────────────┐
                     │  Tool Registry│  (复用 M7 ToolRegistry)
                     └──────┬───────┘
              ┌─────────────┼─────────────┐
              ▼             ▼             ▼
         Built-in Tools  MCP Tools    Skill Tools
         (复用 M7)      (M8 新增)    (M8 新增)
              │             │             │
              │             ▼             ▼
              │      ┌────────────┐  ┌────────────┐
              │      │ MCP Client │  │ Skill Exec │
              │      │ (M8 新增)  │  │ (M8 新增)  │
              │      └─────┬──────┘  └─────┬──────┘
              │            │               │
              └────────────┼───────────────┘
                           ▼
                  ┌─────────────────┐
                  │ Authorization   │  (复用 M7, H15/H16/H18)
                  │     Gate        │
                  └────────┬────────┘
                           │
                  ┌────────┼────────┐
                  ▼        ▼        ▼
              Execute   Audit    Evidence
              (M7)      (M7)     (M7)
```

### 新增硬约束

| 约束 | 内容 |
|------|------|
| **H15 — MCP Isolation** | MCP Server 不得直接突破 AppKCode Authorization。必须：MCP → Tool Protocol (AgentTool) → AuthorizationGate → ActionExecutor → Execution，而不是 MCP → 直接执行 / MCP → 绕过审批 |
| **H16 — Skill Isolation** | Skill 是能力描述/编排单元，不等于无限执行权限。必须：Skill → Tool (AgentTool) → AuthorizationGate → ActionExecutor → Execution，而不是 Skill → 直接执行 / Skill → 绕过审批 |
| **H17 — Rules Precedence** | Rules 必须具有明确作用域（global/project/session）和优先级（整数排序），不能出现无冲突解决机制的规则冲突。冲突解决策略：session > project > global，同作用域按 priority 数值排序 |
| **H18 — MCP/Skills/Rules Audit** | 所有由 M8 产生的 Tool Action 必须继续进入 M7 的 AuthorizationGate + AuditService，不能绕过 H12/H13/H14。MCP Tool 调用、Skill 内部 Tool 调用、Rule Enforcement 决策均须审计记录 |

### 继承硬约束

H1（x86_64 构建锁定）/ H2（Approval Gate 不可 bypass）/ H3（Local Mode 默认）/ H4（契约前置）/ H5（LSP Process Isolation）/ H6（Search <1s）/ H7（Command Execution Safety）/ H8（Git 操作分层隔离）/ H9（AI Approval Boundary）/ H10（Context Isolation）/ H11（Local Mode Default）/ H12（Agent Authorization）/ H13（Tool Isolation）/ H14（Agent Audit）

### 明确禁止

- ❌ CodeArts Compatibility Layer（留给 M9）
- ❌ CodeArts Agent Plugin Runtime（留给 M9）
- ❌ VS Code Extension Runtime（留给 M9）
- ❌ JetBrains Plugin Runtime（留给 M9）
- ❌ G-AI Runtime 深度接入（留给 M9+）
- ❌ 私有 CodeArts API 逆向兼容（留给 M9）
- ❌ 未授权自动执行（H15/H16/H18 禁止）
- ❌ MCP Server 直接访问文件系统/进程（必须经 Tool Protocol）
- ❌ Skill 绕过 AuthorizationGate 直接执行高危操作
- ❌ 无冲突解决机制的规则集（H17 强制）

> **M8 是 Runtime Foundation，不是 CodeArts Compatibility。** CodeArts Compatibility 留给 M9。

### M7 已交付的可复用接口（M8 必须复用，不得重新发明）

| M7 接口/类型 | 文件路径 | M8 复用方式 |
|-------------|---------|------------|
| `AgentTool` (ToolProtocol) | `Sources/AppKCodeDomain/AgentRuntime/ToolProtocol.swift` | M8 的 MCP Tool 和 Skill Tool 须适配此协议 |
| `ToolRegistry` | `Sources/AppKCodeDomain/AgentRuntime/ToolRegistry.swift` | M8 的 MCP/Skill Tool 须注册到此 Registry |
| `ToolSchema` / `ToolPermission` | `Sources/AppKCodeShared/AgentRuntime/ToolSchemaTypes.swift` | M8 Tool 须声明 Schema 与权限 |
| `AuthorizationGate` | `Sources/AppKCodeDomain/AgentRuntime/AuthorizationGate.swift` | M8 所有 Tool Action 须经过此 Gate（H15/H16/H18） |
| `AuditService` | `Sources/AppKCodeDomain/AgentRuntime/AuditService.swift` | M8 所有 Tool Action 须被审计（H18） |
| `ActionExecutor` | `Sources/AppKCodeDomain/AgentRuntime/ActionExecutor.swift` | M8 须复用执行管道 |
| `AgentRuntimeOrchestrator` | `Sources/AppKCodeApplication/AgentRuntime/AgentRuntimeOrchestrator.swift` | M8 须接入编排流程 |
| `AgentSessionManagerImpl` | `Sources/AppKCodeDomain/AgentRuntime/AgentSessionManagerImpl.swift` | M8 复用会话管理 |
| `Planner` / `AIPlanner` | `Sources/AppKCodeDomain/AgentRuntime/Planner.swift` | M8 Rule Engine 在 Plan 生成前应用约束 |
| `ActionResult` | `Sources/AppKCodeShared/AgentRuntime/ActionResultTypes.swift` | M8 复用四态结果 |
| `AuditRecord` / `AuditTarget` | `Sources/AppKCodeShared/AgentRuntime/AuditTypes.swift` | M8 扩展 AuditTarget 增加 mcp/skill/rule |
| `AgentSessionTypes` | `Sources/AppKCodeShared/AgentRuntime/AgentSessionTypes.swift` | M8 复用会话类型 |
| `ActionPlanTypes` | `Sources/AppKCodeShared/AgentRuntime/ActionPlanTypes.swift` | M8 复用计划类型 |

### 既有可复用基线（M0~M7）

| 里程碑 | 可复用能力 |
|--------|-----------|
| M0 | ApprovalService、DiffEngine、ModelRouter |
| M3 | LanguageService、LSPServerRegistry（MCP transport 复用 JSON-RPC 模式） |
| M4 | BuildTestService、ProcessRunner（MCP 进程管理复用进程托管模式） |
| M5 | GitServiceProtocol |
| M6 | ChatService、ContextProvider、ModelProvider、AIBoundaryValidator、ContextAggregator |
| M7 | AgentTool、ToolRegistry、AuthorizationGate、AuditService、ActionExecutor、AgentRuntimeOrchestrator、Planner |

### M8 新增目录结构

```
Sources/
├── AppKCodeShared/
│   ├── MCP/                          # M8 新增：MCP 共享类型
│   │   ├── MCPTypes.swift
│   │   ├── MCPProtocolTypes.swift
│   │   └── MCPConfigTypes.swift
│   ├── Skills/                       # M8 新增：Skill 共享类型
│   │   └── SkillTypes.swift
│   └── Rules/                        # M8 新增：Rule 共享类型
│       └── RuleTypes.swift
├── AppKCodeInfrastructure/
│   ├── MCP/                          # M8 新增：MCP 基础设施
│   │   ├── MCPStdioTransport.swift
│   │   ├── MCPHttpTransport.swift
│   │   └── MCPServerProcessManager.swift
│   ├── Skills/                       # M8 新增：Skill 基础设施
│   │   ├── SkillLoader.swift
│   │   └── SkillStore.swift
│   └── Rules/                        # M8 新增：Rule 基础设施
│       ├── RuleLoader.swift
│       ├── RuleStore.swift
│       └── RuleFileWatcher.swift
├── AppKCodeDomain/
│   ├── MCP/                          # M8 新增：MCP 领域服务
│   │   ├── MCPHostService.swift
│   │   ├── MCPToolDiscovery.swift
│   │   ├── MCPResourceDiscovery.swift
│   │   ├── MCPToolAdapter.swift
│   │   └── MCPToolInvocation.swift
│   ├── Skills/                       # M8 新增：Skill 领域服务
│   │   ├── SkillRegistry.swift
│   │   └── SkillExecutor.swift
│   └── Rules/                        # M8 新增：Rule 领域服务
│       ├── RuleEngine.swift
│       ├── RuleResolver.swift
│       └── RuleEnforcer.swift
├── AppKCodeApplication/
│   ├── MCP/                          # M8 新增
│   │   └── MCPHostAppService.swift
│   ├── Skills/                       # M8 新增
│   │   └── SkillAppService.swift
│   └── Rules/                        # M8 新增
│       └── RuleAppService.swift
└── AppKCodePresentation/
    ├── MCP/                          # M8 新增
    │   ├── MCPServerManagementView.swift
    │   └── MCPToolBrowserView.swift
    ├── Skills/                       # M8 新增
    │   └── SkillRegistryView.swift
    └── Rules/                        # M8 新增
        ├── RuleEditorView.swift
        └── RuleConflictView.swift

Tests/
├── AppKCodeDomainTests/
│   ├── MCP/                          # M8 新增
│   ├── Skills/                       # M8 新增
│   └── Rules/                        # M8 新增
└── AppKCodeIntegrationTests/
    └── M8SmokeTest.swift             # M8 新增

Resources/
├── Skills/                           # 已有：内置 Skills 清单
└── Rules/                            # 已有：内置 Rules 模板
```

---

# Phase 1: Shared Types（共享类型层）

> 目标：在 `AppKCodeShared` 中定义 M8 全部共享类型（MCP / Skills / Rules），被 Infrastructure / Domain / Application / Presentation 依赖。所有类型 Sendable + Codable 合规，类型层面预先固化 H15/H16/H17/H18 约束。复用 M7 既有 Shared Types（ToolSchemaTypes / AuthorizationTypes / AuditTypes / ActionResultTypes）。

## APPK-M8-TASK-001: MCP 共享类型定义

**输入**：spec §5.6（MCP 集成）、design §1.2.1 模块 G（G4/G5）、H15 约束
**输出**：`Sources/AppKCodeShared/MCP/MCPTypes.swift`
**验收标准**：类型 Sendable + Codable 合规；覆盖 Server/Tool/Resource/Invocation 全模型；transport 枚举含 stdio/http/sse

- [ ] **APPK-M8-TASK-001.1**：定义 `struct MCPServerID: Hashable, Sendable, Codable`（封装 UUID v4）与 `enum MCPTransport: Sendable, Codable { case stdio(command: String, args: [String], env: [String: String]?), http(endpoint: URL), sse(endpoint: URL) }`，覆盖 spec §5.6 全部 transport
- [ ] **APPK-M8-TASK-001.2**：定义 `struct MCPServerConfig: Sendable, Codable { let id: MCPServerID, let name: String, let transport: MCPTransport, let enabled: Bool, let autoDiscoverTools: Bool, let timeoutSeconds: Int }`，MCP Server 配置模型
- [ ] **APPK-M8-TASK-001.3**：定义 `enum MCPConnectionState: Sendable, Codable { case disconnected, connecting, connected, disconnectedUnexpectedly(reason: String), failed(error: String) }`，连接状态枚举
- [ ] **APPK-M8-TASK-001.4**：定义 `struct MCPToolDescriptor: Sendable, Codable { let name: String, let description: String, let inputSchema: JSONSchema, let annotations: MCPToolAnnotations? }` 与 `struct MCPToolAnnotations: Sendable, Codable { let readOnlyHint: Bool?, let destructiveHint: Bool? }`，MCP Server 声明的工具描述
- [ ] **APPK-M8-TASK-001.5**：定义 `struct MCPResourceDescriptor: Sendable, Codable { let uri: String, let name: String, let description: String?, let mimeType: String? }`，MCP Server 声明的资源描述
- [ ] **APPK-M8-TASK-001.6**：定义 `struct MCPToolInvocationRequest: Sendable, Codable { let serverID: MCPServerID, let toolName: String, let arguments: [String: AnyCodableValue] }` 与 `enum MCPToolInvocationResult: Sendable, Codable { case success(content: [MCPContent], isError: Bool), case failure(error: MCPError) }` 与 `enum MCPContent: Sendable, Codable { case text(String), case image(data: Data, mimeType: String), case resource(uri: String) }`
- [ ] **APPK-M8-TASK-001.7**：定义 `struct MCPError: Error, Sendable, Codable { let code: Int, let message: String, let data: AnyCodableValue? }` 与 `enum MCPErrorCode: Sendable, Codable { case parseError, invalidRequest, methodNotFound, invalidParams, internalError }`，MCP 协议错误模型

## APPK-M8-TASK-002: MCP Protocol Message Types 定义

**输入**：MCP 协议规范（JSON-RPC 2.0）、design §1.2.1（G4 MCP Host 进程托管 + MCP 协议）
**输出**：`Sources/AppKCodeShared/MCP/MCPProtocolTypes.swift`
**验收标准**：覆盖 initialize / tools/list / tools/call / resources/list 全部 MCP 协议消息；JSON-RPC 2.0 合规

- [ ] **APPK-M8-TASK-002.1**：定义 `struct MCPInitializeRequest: Sendable, Codable { let protocolVersion: String, let clientInfo: MCPClientInfo, let capabilities: MCPClientCapabilities }` 与 `struct MCPInitializeResponse: Sendable, Codable { let protocolVersion: String, let serverInfo: MCPServerInfo, let capabilities: MCPServerCapabilities }`，MCP 握手消息
- [ ] **APPK-M8-TASK-002.2**：定义 `struct MCPListToolsResponse: Sendable, Codable { let tools: [MCPToolDescriptor] }` 与 `struct MCPListResourcesResponse: Sendable, Codable { let resources: [MCPResourceDescriptor] }`，Discovery 响应
- [ ] **APPK-M8-TASK-002.3**：定义 `struct MCPCallToolRequest: Sendable, Codable { let name: String, let arguments: [String: AnyCodableValue] }` 与 `struct MCPCallToolResponse: Sendable, Codable { let content: [MCPContent], let isError: Bool }`，工具调用请求/响应
- [ ] **APPK-M8-TASK-002.4**：定义 `enum MCPNotification: Sendable, Codable { case toolsListChanged, resourcesListChanged, progress(token: String, progress: Double, total: Double?) }`，MCP 通知消息
- [ ] **APPK-M8-TASK-002.5**：定义 `struct AnyCodableValue: Sendable, Codable`（通用 JSON 值封装，支持 string/number/boolean/null/array/object），用于 MCP 协议中动态 JSON 参数

## APPK-M8-TASK-003: Skill 共享类型定义

**输入**：spec §5.7（Skills / Rules）、design §1.2.1 模块 H（H1 Skills 加载）、H16 约束
**输出**：`Sources/AppKCodeShared/Skills/SkillTypes.swift`
**验收标准**：Skill 有 id/name/description/input schema (JSON Schema)/output schema/execution policy；类型 Sendable + Codable

- [ ] **APPK-M8-TASK-003.1**：定义 `struct SkillID: Hashable, Sendable, Codable`（封装 UUID）与 `struct JSONSchema: Sendable, Codable { let type: String, let properties: [String: JSONSchemaProperty], let required: [String], let description: String? }` 与 `struct JSONSchemaProperty: Sendable, Codable { let type: String, let description: String?, let items: JSONSchemaProperty?, let enumValues: [AnyCodableValue]? }`，JSON Schema 描述模型
- [ ] **APPK-M8-TASK-003.2**：定义 `struct SkillManifest: Sendable, Codable { let id: SkillID, let name: String, let description: String, let version: String, let inputSchema: JSONSchema, let outputSchema: JSONSchema, let executionPolicy: SkillExecutionPolicy, let allowedTools: [ToolID]?, let metadata: [String: String] }`，Skill 完整清单
- [ ] **APPK-M8-TASK-003.3**：定义 `struct SkillExecutionPolicy: Sendable, Codable { let maxSteps: Int, let maxDurationSeconds: Int, let requireApproval: Bool, let allowedCategories: [ToolCategory], let sandboxed: Bool }`，执行策略（H16：requireApproval 控制是否需审批，allowedCategories 限定可用工具类别）
- [ ] **APPK-M8-TASK-003.4**：定义 `enum SkillExecutionResult: Sendable, Codable { case success(output: AnyCodableValue, evidence: [EvidenceRecordID]), case failure(error: SkillError, partialEvidence: [EvidenceRecordID]), case timedOut, case cancelled }` 与 `enum SkillError: Error, Sendable, Codable { case invalidInput(reason: String), case toolNotAllowed(ToolID), case maxStepsExceeded, case executionPolicyViolation(String), case underlyingError(String) }`
- [ ] **APPK-M8-TASK-003.5**：定义 `struct SkillInvocationRequest: Sendable, Codable { let skillID: SkillID, let input: AnyCodableValue, let sessionID: AgentSessionID }`，Skill 调用请求

## APPK-M8-TASK-004: Rule 共享类型定义

**输入**：spec §5.7（Rules 约束）、design §1.2.1 模块 H（H2 Rules 加载）、H17 约束
**输出**：`Sources/AppKCodeShared/Rules/RuleTypes.swift`
**验收标准**：Rule 有 scope/priority/condition/instruction/enforcement；冲突检测类型完备；类型 Sendable + Codable

- [ ] **APPK-M8-TASK-004.1**：定义 `struct RuleID: Hashable, Sendable, Codable`（封装 UUID）与 `enum RuleScope: Sendable, Codable, Comparable { case global, project, session }`，规则作用域（H17：session > project > global）
- [ ] **APPK-M8-TASK-004.2**：定义 `struct RulePriority: Sendable, Codable, Comparable { let value: Int }`（数值越大优先级越高），与 `enum RuleEnforcement: Sendable, Codable { case block, warn, info }`，执行级别
- [ ] **APPK-M8-TASK-004.3**：定义 `struct RuleCondition: Sendable, Codable { let target: RuleTarget, let matcher: RuleMatcher }` 与 `enum RuleTarget: Sendable, Codable { case toolID(ToolID), case toolCategory(ToolCategory), case operationKind(String), case all }` 与 `enum RuleMatcher: Sendable, Codable { case equals(String), case contains(String), case regex(String), case always }`，规则条件模型
- [ ] **APPK-M8-TASK-004.4**：定义 `struct RuleInstruction: Sendable, Codable { let description: String, let requireApproval: Bool, let denyExecution: Bool, let maxRetries: Int? }`，规则指令（denyExecution 用于 block 级别）
- [ ] **APPK-M8-TASK-004.5**：定义 `struct Rule: Sendable, Codable { let id: RuleID, let name: String, let scope: RuleScope, let priority: RulePriority, let condition: RuleCondition, let instruction: RuleInstruction, let enforcement: RuleEnforcement, let sourceFile: URL? }`，完整规则模型
- [ ] **APPK-M8-TASK-004.6**：定义 `struct RuleSet: Sendable, Codable { let rules: [Rule] }` 与 `struct RuleConflict: Sendable, Codable { let rule1: RuleID, let rule2: RuleID, let conflictType: RuleConflictType, let description: String }` 与 `enum RuleConflictType: Sendable, Codable { case contradictoryInstruction, sameTargetDifferentEnforcement, priorityCycle }`
- [ ] **APPK-M8-TASK-004.7**：定义 `enum RuleEvaluationResult: Sendable, Codable { case allow, warn(rule: RuleID, message: String), block(rule: RuleID, message: String), noApplicableRule }`，规则评估结果

## APPK-M8-TASK-005: M8 Audit 扩展类型定义（H18）

**输入**：H18 约束、M7 既有 AuditTypes（AuditTarget / AuditRecord）
**输出**：修改 `Sources/AppKCodeShared/AgentRuntime/AuditTypes.swift`（扩展 AuditTarget）
**验收标准**：AuditTarget 增加 mcp/skill/rule 相关枚举值；不破坏 M7 既有 AuditRecord 结构

- [ ] **APPK-M8-TASK-005.1**：扩展 `enum AuditTarget` 增加 `case mcpServer(MCPServerID, tool: String)`、`case skillInvocation(SkillID)`、`case ruleEvaluation(RuleID)`，覆盖 M8 全部审计目标（H18）
- [ ] **APPK-M8-TASK-005.2**：定义 `struct M8AuditEvent: Sendable, Codable { let kind: M8AuditEventKind, let sessionID: AgentSessionID, let timestamp: ISO8601Timestamp, let detail: AnyCodableValue }` 与 `enum M8AuditEventKind: Sendable, Codable { case mcpServerConnected, mcpServerDisconnected, mcpToolInvoked, mcpToolDiscoveryCompleted, skillRegistered, skillInvoked, skillCompleted, ruleLoaded, ruleEvaluated, ruleConflictDetected, ruleEnforced }`，M8 审计事件类型
- [ ] **APPK-M8-TASK-005.3**：确保扩展不破坏 M7 既有 `AuditRecord` 的 Codable 兼容性（新增枚举 case 向后兼容）

## APPK-M8-TASK-006: M8 Configuration Types 定义

**输入**：spec §5.6/§5.7、APPK-DFX-M03（热重载）
**输出**：`Sources/AppKCodeShared/MCP/MCPConfigTypes.swift`（含 Skills/Rules 配置）
**验收标准**：配置类型 Codable；支持热重载标记；默认值安全

- [ ] **APPK-M8-TASK-006.1**：定义 `struct MCPRuntimeConfig: Sendable, Codable { let servers: [MCPServerConfig], let defaultTimeoutSeconds: Int, let maxConcurrentInvocations: Int, let hotReload: Bool }`，MCP 运行时配置
- [ ] **APPK-M8-TASK-006.2**：定义 `struct SkillsRuntimeConfig: Sendable, Codable { let builtinSkillsPath: URL, let customSkillsPath: URL?, let hotReload: Bool, let defaultExecutionPolicy: SkillExecutionPolicy }`，Skills 运行时配置
- [ ] **APPK-M8-TASK-006.3**：定义 `struct RulesRuntimeConfig: Sendable, Codable { let globalRulesPath: URL, let projectRulesPath: URL?, let hotReload: Bool, let strictConflictDetection: Bool }`，Rules 运行时配置（strictConflictDetection 为 true 时冲突导致加载失败，H17）

---

# Phase 2: Infrastructure（基础设施层）

> 目标：在 `AppKCodeInfrastructure` 中实现 MCP Transport（stdio/HTTP）、MCP Server 进程管理、Skill 加载与存储、Rule 加载与存储及热重载。复用 M4 ProcessRunner 的进程托管模式与 M3 JSON-RPC 通信模式。不引入 shell 字符串拼接（H7）。

## APPK-M8-TASK-007: MCP stdio Transport 实现

**输入**：APPK-M8-TASK-002（Protocol Types）、M4 既有 ProcessRunner（进程托管模式）、design §1.2.1（G4）
**输出**：`Sources/AppKCodeInfrastructure/MCP/MCPStdioTransport.swift`
**验收标准**：通过子进程 stdin/stdout JSON-RPC 2.0 通信；支持请求/响应/通知；不直接拼接 shell 命令（H7）

- [ ] **APPK-M8-TASK-007.1**：实现 `final class MCPStdioTransport: MCPTransportProtocol`，构造接收 `MCPServerConfig`（stdio 类型），启动子进程并通过 `Pipe` 连接 stdin/stdout，使用 `Process`（复用 M4 ProcessRunner 模式，不直接拼接 shell 字符串）
- [ ] **APPK-M8-TASK-007.2**：实现 `func send(_ request: JSONRPCRequest) async throws -> JSONRPCResponse`，按 JSON-RPC 2.0 格式序列化并写入 stdin，从 stdout 读取响应并反序列化；支持请求 ID 关联
- [ ] **APPK-M8-TASK-007.3**：实现 `func sendNotification(_ notification: JSONRPCNotification) async throws`，单向通知写入 stdin 不等待响应
- [ ] **APPK-M8-TASK-007.4**：实现进程生命周期：`func start() async throws` 启动进程 + initialize 握手，`func stop() async throws` 优雅终止，进程意外退出时通过回调通知上层

## APPK-M8-TASK-008: MCP HTTP Transport 实现

**输入**：APPK-M8-TASK-002（Protocol Types）、design §1.2.1（G4 MCP 协议 over stdio 或 SSE）
**输出**：`Sources/AppKCodeInfrastructure/MCP/MCPHttpTransport.swift`
**验收标准**：通过 HTTP POST 发送请求、SSE 接收响应/通知；支持长连接；超时可控

- [ ] **APPK-M8-TASK-008.1**：实现 `final class MCPHttpTransport: MCPTransportProtocol`，构造接收 `MCPServerConfig`（http 类型），使用 `URLSession` 发送 JSON-RPC 请求到 HTTP endpoint
- [ ] **APPK-M8-TASK-008.2**：实现 `func send(_ request: JSONRPCRequest) async throws -> JSONRPCResponse`，HTTP POST 请求体为 JSON-RPC 消息，响应体为 JSON-RPC 响应
- [ ] **APPK-M8-TASK-008.3**：实现 SSE（Server-Sent Events）监听：对 `sse` transport 类型，建立 SSE 长连接接收服务器推送的通知与响应，支持自动重连

## APPK-M8-TASK-009: MCP Server Process Manager 实现

**输入**：APPK-M8-TASK-007（StdioTransport）、APPK-M8-TASK-008（HttpTransport）、M4 既有进程管理模式
**输出**：`Sources/AppKCodeInfrastructure/MCP/MCPServerProcessManager.swift`
**验收标准**：管理多个 MCP Server 进程生命周期；进程崩溃检测与状态通知；资源清理

- [ ] **APPK-M8-TASK-009.1**：实现 `final class MCPServerProcessManager: Sendable`，内部 `[MCPServerID: MCPManagedServer]` 注册表，`func startServer(_ config: MCPServerConfig) async throws -> MCPConnectionState` 根据 transport 类型创建对应 Transport 并启动
- [ ] **APPK-M8-TASK-009.2**：实现 `func stopServer(_ id: MCPServerID) async throws` 优雅停止，`func stopAll() async throws` 停止全部 Server，`func connectionState(_ id: MCPServerID) -> MCPConnectionState` 查询状态
- [ ] **APPK-M8-TASK-009.3**：实现进程监控：stdio transport 的子进程意外退出时更新状态为 `.disconnectedUnexpectedly`，通过 `AsyncStream<MCPServerEvent>` 通知上层（复用 M3 LSP 自愈模式参考但不自动重启 MCP Server，由用户决定）
- [ ] **APPK-M8-TASK-009.4**：实现资源清理：`stopServer` 时关闭 transport 连接、回收子进程资源、清理待处理请求队列

## APPK-M8-TASK-010: Skill Loader & Store 实现

**输入**：APPK-M8-TASK-003（Skill Types）、design §1.2.1（H1 Skills 加载：清单解析 + 热重载）、APPK-DFX-M03
**输出**：`Sources/AppKCodeInfrastructure/Skills/SkillLoader.swift`、`Sources/AppKCodeInfrastructure/Skills/SkillStore.swift`
**验收标准**：从 JSON/YAML 文件解析 SkillManifest；支持内置与自定义 Skills 目录；热重载

- [ ] **APPK-M8-TASK-010.1**：实现 `final class SkillLoader`，`func loadFromDirectory(_ dir: URL) async throws -> [SkillManifest]`，扫描目录下 `*.skill.json` 文件，逐个解析为 `SkillManifest`，解析失败时跳过并记录错误（不中断其他 Skill 加载）
- [ ] **APPK-M8-TASK-010.2**：实现 `func loadBuiltinSkills() async throws -> [SkillManifest]`，从 `Resources/Skills/` 加载内置 Skills（Go/C++/Python/Swift/ProjectManagement 等）
- [ ] **APPK-M8-TASK-010.3**：实现 `final class SkillStore`，持久化 Skill 注册状态到 `<workspace>/.appkcode/skills/registry.json`，`func save(_ manifests: [SkillManifest]) async throws` 与 `func load() async throws -> [SkillManifest]`
- [ ] **APPK-M8-TASK-010.4**：实现 JSON Schema 校验：加载 SkillManifest 时校验 `inputSchema` 与 `outputSchema` 为合法 JSON Schema 结构（type/properties/required 字段完整性）

## APPK-M8-TASK-011: Rule Loader & Store & File Watcher 实现

**输入**：APPK-M8-TASK-004（Rule Types）、design §1.2.1（H2 Rules 加载：Markdown 解析 + 热重载）、APPK-DFX-M03
**输出**：`Sources/AppKCodeInfrastructure/Rules/RuleLoader.swift`、`Sources/AppKCodeInfrastructure/Rules/RuleStore.swift`、`Sources/AppKCodeInfrastructure/Rules/RuleFileWatcher.swift`
**验收标准**：从 Markdown 文件解析 Rules；支持 global/project 作用域；FSEvents 热重载；解析失败保留上一份有效规则

- [ ] **APPK-M8-TASK-011.1**：实现 `final class RuleLoader`，`func loadFromDirectory(_ dir: URL, scope: RuleScope) async throws -> [Rule]`，扫描目录下 `*.md` 文件，解析 frontmatter（YAML）+ Markdown body 为 `Rule`，解析失败时保留上一份有效规则并提示（spec §5.7.3 异常场景）
- [ ] **APPK-M8-TASK-011.2**：实现 Markdown 规则解析格式：frontmatter 含 `name/scope/priority/enforcement/target/matcher`，body 为 `instruction.description`；支持 coding.md / testing.md / security.md / PM-Gate.md 等规则文件
- [ ] **APPK-M8-TASK-011.3**：实现 `final class RuleStore`，持久化 RuleSet 到 `<workspace>/.appkcode/rules/ruleset.json`，`func save(_ ruleSet: RuleSet) async throws` 与 `func load() async throws -> RuleSet`
- [ ] **APPK-M8-TASK-011.4**：实现 `final class RuleFileWatcher`，使用 `DispatchSource`（FSEvents）监听规则文件目录变更，变更时触发 `AsyncStream<RuleReloadEvent>` 通知上层热重载（APPK-DFX-M03）
- [ ] **APPK-M8-TASK-011.5**：实现热重载安全：解析失败时保留上一份有效 RuleSet 不替换，通过事件通知错误详情，不中断 Agent 运行

---

# Phase 3: Domain（领域服务层）

> 目标：在 `AppKCodeDomain` 中实现 MCP Host Service（Discovery/Invocation）、MCP Tool Adapter（适配 AgentTool，H15）、Skill Registry/Executor（H16）、Rule Engine/Resolver/Enforcer（H17）。所有 M8 产生的 Tool Action 须经 M7 AuthorizationGate + AuditService（H18）。复用 M7 ToolProtocol / ToolRegistry / AuthorizationGate / AuditService / ActionExecutor，不重新发明。

## APPK-M8-TASK-012: MCP Host Service — Server Discovery 实现

**输入**：APPK-M8-TASK-001（MCP Types）、APPK-M8-TASK-009（ProcessManager）、design §1.2.1（G4）
**输出**：`Sources/AppKCodeDomain/MCP/MCPHostService.swift`
**验收标准**：支持注册/启用/禁用/查询 MCP Server；连接状态管理；不直接执行工具

- [ ] **APPK-M8-TASK-012.1**：定义 `protocol MCPHostService: Sendable { func registerServer(_ config: MCPServerConfig) async throws; func enableServer(_ id: MCPServerID) async throws -> MCPConnectionState; func disableServer(_ id: MCPServerID) async throws; func listServers() -> [MCPServerConfig]; func serverState(_ id: MCPServerID) -> MCPConnectionState; var serverEvents: AsyncStream<MCPServerEvent> { get } }`
- [ ] **APPK-M8-TASK-012.2**：实现 `final class MCPHostServiceImpl: MCPHostService`，构造接收 `MCPServerProcessManager`，`enableServer` 调用 ProcessManager 启动 Server + initialize 握手，`disableServer` 调用 ProcessManager 停止
- [ ] **APPK-M8-TASK-012.3**：实现 `serverEvents` 事件流：转发 ProcessManager 的进程事件（connected/disconnected/failed），供 Application 层订阅并更新 UI

## APPK-M8-TASK-013: MCP Tool Discovery 实现

**输入**：APPK-M8-TASK-002（Protocol Types）、APPK-M8-TASK-012（MCPHostService）、M7 既有 ToolSchemaTypes
**输出**：`Sources/AppKCodeDomain/MCP/MCPToolDiscovery.swift`
**验收标准**：从 MCP Server 拉取 tools/list 并生成 ToolSchema；映射 MCP 权限提示到 ToolPermission

- [ ] **APPK-M8-TASK-013.1**：实现 `final class MCPToolDiscovery`，`func discoverTools(serverID: MCPServerID) async throws -> [MCPToolDescriptor]`，通过 transport 发送 `tools/list` 请求，解析响应为 `[MCPToolDescriptor]`
- [ ] **APPK-M8-TASK-013.2**：实现 `func convertToToolSchema(_ descriptor: MCPToolDescriptor, serverID: MCPServerID) -> ToolSchema`，将 MCPToolDescriptor 转换为 M7 `ToolSchema`：`id` = `ToolID("mcp.<serverName>.<toolName>")`，`category` = `.mcp`（扩展 ToolCategory），`permission` 根据 `annotations.readOnlyHint` 映射（readOnly=true → .readOnly，否则 → .high，H15：MCP 工具默认高危需审批）
- [ ] **APPK-M8-TASK-013.3**：实现 `func discoverAndRegister(serverID: MCPServerID, registry: ToolRegistry) async throws -> [ToolID]`，发现工具后生成 ToolSchema 并通过 MCPToolAdapter 注册到 M7 ToolRegistry

## APPK-M8-TASK-014: MCP Resource Discovery 实现

**输入**：APPK-M8-TASK-002（Protocol Types）、APPK-M8-TASK-012（MCPHostService）
**输出**：`Sources/AppKCodeDomain/MCP/MCPResourceDiscovery.swift`
**验收标准**：从 MCP Server 拉取 resources/list；暴露资源句柄供 Agent 读取

- [ ] **APPK-M8-TASK-014.1**：实现 `final class MCPResourceDiscovery`，`func discoverResources(serverID: MCPServerID) async throws -> [MCPResourceDescriptor]`，通过 transport 发送 `resources/list` 请求
- [ ] **APPK-M8-TASK-014.2**：实现 `func readResource(serverID: MCPServerID, uri: String) async throws -> MCPContent`，通过 transport 发送 `resources/read` 请求读取资源内容（只读操作，不须经审批但须审计）

## APPK-M8-TASK-015: MCP Tool Adapter 实现（H15）

**输入**：APPK-M8-TASK-013（ToolDiscovery）、M7 既有 AgentTool 协议、M7 既有 ToolRegistry、H15 约束
**输出**：`Sources/AppKCodeDomain/MCP/MCPToolAdapter.swift`
**验收标准**：MCP Tool 适配为 AgentTool 协议（H13 隔离延续）；注册到 ToolRegistry；H15：所有调用经 AuthorizationGate

- [ ] **APPK-M8-TASK-015.1**：实现 `final class MCPToolAdapter: AgentTool`，构造接收 `MCPServerID` + `MCPToolDescriptor` + `MCPToolInvocation`，`var schema: ToolSchema` 返回由 ToolDiscovery 转换的 ToolSchema
- [ ] **APPK-M8-TASK-015.2**：实现 `func validate(arguments: ToolArguments) -> ValidationResult`，根据 `descriptor.inputSchema` 校验参数（必填字段、类型匹配）
- [ ] **APPK-M8-TASK-015.3**：实现 `func execute(arguments: ToolArguments, session: AgentSessionID) async throws -> ToolOutput`，内部调用 `MCPToolInvocation.invoke`（不直接访问 transport/进程，H13 隔离），将 `MCPToolInvocationResult` 映射为 `ToolOutput`
- [ ] **APPK-M8-TASK-015.4**：固化 H15：`MCPToolAdapter.schema.permission` 对非 readOnly 工具设为 `.high`，确保经 AuthorizationGate 强制审批；源码中不存在绕过 AuthorizationGate 的直接执行路径
- [ ] **APPK-M8-TASK-015.5**：实现 `func registerAll(serverID: MCPServerID, descriptors: [MCPToolDescriptor], registry: ToolRegistry) throws -> [ToolID]`，批量适配并注册到 M7 ToolRegistry，返回注册的 ToolID 列表

## APPK-M8-TASK-016: MCP Tool Invocation & Result Handling 实现

**输入**：APPK-M8-TASK-001（MCP Types）、APPK-M8-TASK-009（ProcessManager）、M7 既有 ActionResultTypes
**输出**：`Sources/AppKCodeDomain/MCP/MCPToolInvocation.swift`
**验收标准**：调用 MCP Server tools/call；结果映射为 ToolOutput；错误/超时/取消处理

- [ ] **APPK-M8-TASK-016.1**：实现 `final class MCPToolInvocation: Sendable`，构造接收 `MCPServerProcessManager`，`func invoke(_ request: MCPToolInvocationRequest) async throws -> MCPToolInvocationResult`，通过 transport 发送 `tools/call` 请求
- [ ] **APPK-M8-TASK-016.2**：实现结果映射：`MCPToolInvocationResult.success` 映射为 `ToolOutput`（text content → `text` 字段，structured data → `structured` 字段），`isError == true` 时映射为 `MCPError` 并抛出
- [ ] **APPK-M8-TASK-016.3**：实现错误处理：MCP 协议错误（parseError/invalidRequest/methodNotFound/invalidParams/internalError）映射为可读错误消息；transport 连接断开时返回 `MCPError(code: -1, message: "Server disconnected")`
- [ ] **APPK-M8-TASK-016.4**：实现超时与取消：调用超时由 `MCPServerConfig.timeoutSeconds` 控制，超时抛出错误供 ActionExecutor 映射为 `ActionResult.timedOut`；`Task.cancel()` 中断待处理请求并返回 `ActionResult.cancelled`

## APPK-M8-TASK-017: Skill Registry 实现

**输入**：APPK-M8-TASK-003（Skill Types）、APPK-M8-TASK-010（SkillLoader/SkillStore）
**输出**：`Sources/AppKCodeDomain/Skills/SkillRegistry.swift`
**验收标准**：注册/查询/列举 Skills；支持热重载；不重复注册

- [ ] **APPK-M8-TASK-017.1**：实现 `final class SkillRegistry: Sendable`，内部 `[SkillID: SkillManifest]` 注册表，`func register(_ manifest: SkillManifest) throws` 注册（重复 ID 抛出错误），`func unregister(_ id: SkillID) throws`
- [ ] **APPK-M8-TASK-017.2**：实现 `func resolve(_ id: SkillID) -> SkillManifest?` 查询，`func listAll() -> [SkillManifest]` 列举全部，`func listByCategory(_ category: String) -> [SkillManifest]` 按元数据 category 过滤
- [ ] **APPK-M8-TASK-017.3**：实现 `func loadFromDirectory(_ dir: URL) async throws -> [SkillID]`，调用 SkillLoader 加载并批量注册，返回注册的 SkillID 列表
- [ ] **APPK-M8-TASK-017.4**：实现热重载：`func reload(_ dir: URL) async throws -> ReloadResult`，重新加载目录下 Skills，新增的注册、移除的注销、变更的替换，返回变更摘要

## APPK-M8-TASK-018: Skill Executor 实现（H16）

**输入**：APPK-M8-TASK-003（Skill Types）、APPK-M8-TASK-017（SkillRegistry）、M7 既有 ActionExecutor/AuthorizationGate/ToolRegistry、H16 约束
**输出**：`Sources/AppKCodeDomain/Skills/SkillExecutor.swift`
**验收标准**：Skill 内部编排 Tool 调用；所有 Tool 调用经 AuthorizationGate（H16）；执行策略约束生效

- [ ] **APPK-M8-TASK-018.1**：定义 `protocol SkillExecutor: Sendable { func execute(_ request: SkillInvocationRequest) async throws -> SkillExecutionResult }`，Skill 执行器协议
- [ ] **APPK-M8-TASK-018.2**：实现 `final class SkillExecutorImpl: SkillExecutor`，构造接收 `SkillRegistry` + M7 `ActionExecutor` + M7 `ToolRegistry` + M7 `AuthorizationGate`，`execute` 流程：① 从 Registry 查询 SkillManifest → ② 校验 input 符合 inputSchema → ③ 按 executionPolicy 编排 Tool 调用 → ④ 每步通过 M7 ActionExecutor 执行（内部含 Authorization + Audit）→ ⑤ 聚合结果
- [ ] **APPK-M8-TASK-018.3**：固化 H16：Skill 内部 Tool 调用通过 M7 `ActionExecutor.execute`，不直接调用 `AgentTool.execute` 或底层 Service；`executionPolicy.requireApproval == true` 时确保每步经 AuthorizationGate；`allowedTools` / `allowedCategories` 限制可调用工具范围
- [ ] **APPK-M8-TASK-018.4**：实现执行策略约束：`maxSteps` 超出时返回 `.failure(.maxStepsExceeded)`，`maxDurationSeconds` 超出时返回 `.timedOut`，调用不在 `allowedCategories` 的工具时返回 `.failure(.toolNotAllowed)`
- [ ] **APPK-M8-TASK-018.5**：实现 Skill 编排逻辑：Skill 的执行步骤由其 manifest 描述（预定义的工具调用序列或基于 input 的动态编排），每步生成 `ActionStep` 提交 M7 ActionExecutor，收集全部 `ActionResult` 聚合为 `SkillExecutionResult`

## APPK-M8-TASK-019: Rule Engine 实现（H17）

**输入**：APPK-M8-TASK-004（Rule Types）、APPK-M8-TASK-011（RuleLoader/RuleStore）、H17 约束
**输出**：`Sources/AppKCodeDomain/Rules/RuleEngine.swift`
**验收标准**：规则评估正确；优先级排序；作用域解析；冲突检测

- [ ] **APPK-M8-TASK-019.1**：实现 `final class RuleEngine: Sendable`，构造接收 `RuleSet`，`func evaluate(target: RuleTarget, scope: RuleScope) -> RuleEvaluationResult`，按条件匹配 + 优先级排序 + 作用域解析返回评估结果
- [ ] **APPK-M8-TASK-019.2**：实现条件匹配：`RuleCondition.matcher` 对目标值执行 `equals/contains/regex/always` 匹配，`RuleCondition.target` 匹配 toolID/toolCategory/operationKind/all
- [ ] **APPK-M8-TASK-019.3**：实现优先级排序（H17）：对同一目标匹配的多条规则，按 `scope` 优先级（session > project > global）再按 `priority.value` 降序排序，取最高优先级规则的 enforcement 为最终结果
- [ ] **APPK-M8-TASK-019.4**：实现 `func detectConflicts(ruleSet: RuleSet) -> [RuleConflict]`，检测矛盾指令（同一目标 block vs allow）、同目标不同 enforcement 且同优先级、优先级环，返回冲突列表
- [ ] **APPK-M8-TASK-019.5**：实现 `func updateRuleSet(_ ruleSet: RuleSet) throws`，更新时先检测冲突，若存在冲突且 `strictConflictDetection == true` 则抛出错误拒绝更新（H17 强制冲突解决）

## APPK-M8-TASK-020: Rule Resolver 实现（H17）

**输入**：APPK-M8-TASK-019（RuleEngine）、H17 约束
**输出**：`Sources/AppKCodeDomain/Rules/RuleResolver.swift`
**验收标准**：冲突解决机制明确；无歧义；可追溯

- [ ] **APPK-M8-TASK-020.1**：实现 `final class RuleResolver`，`func resolve(_ conflicts: [RuleConflict], ruleSet: RuleSet) -> [RuleResolution]`，对每条冲突生成解决决策
- [ ] **APPK-M8-TASK-020.2**：定义 `struct RuleResolution: Sendable, Codable { let conflict: RuleConflict, let strategy: RuleResolutionStrategy, let resolvedRuleID: RuleID?, let description: String }` 与 `enum RuleResolutionStrategy: Sendable, Codable { case higherPriorityWins, higherScopeWins, denyByDefault, manualOverride }`
- [ ] **APPK-M8-TASK-020.3**：实现冲突解决策略：`contradictoryInstruction` → denyByDefault（安全优先，block 级别胜出）；`sameTargetDifferentEnforcement` → higherPriorityWins 或 higherScopeWins；`priorityCycle` → 抛出不可自动解决错误，需人工干预
- [ ] **APPK-M8-TASK-020.4**：固化 H17：所有冲突必须有明确解决策略，不存在"未解决冲突即应用规则"的路径；冲突解决记录写入审计（H18）

## APPK-M8-TASK-021: Rule Enforcer 实现

**输入**：APPK-M8-TASK-019（RuleEngine）、APPK-M8-TASK-020（RuleResolver）、M7 既有 ActionStep/ActionPlan
**输出**：`Sources/AppKCodeDomain/Rules/RuleEnforcer.swift`
**验收标准**：规则约束应用到 Agent Plan；block 级别阻止执行；warn 级别提示；info 级别记录

- [ ] **APPK-M8-TASK-021.1**：实现 `final class RuleEnforcer: Sendable`，构造接收 `RuleEngine` + `RuleResolver`，`func enforcePlan(_ plan: ActionPlan, scope: RuleScope) -> EnforcedPlan`，对 Plan 中每步评估规则
- [ ] **APPK-M8-TASK-021.2**：定义 `struct EnforcedPlan: Sendable { let originalPlan: ActionPlan, let steps: [EnforcedStep] }` 与 `struct EnforcedStep: Sendable { let step: ActionStep, let evaluation: RuleEvaluationResult, let allowed: Bool }`
- [ ] **APPK-M8-TASK-021.3**：实现 enforcement 执行：`block` → `allowed = false`，该步从 Plan 中移除并记录原因；`warn` → `allowed = true` 但附加警告消息供 UI 展示；`info` → `allowed = true` 仅记录；`allow` / `noApplicableRule` → `allowed = true`
- [ ] **APPK-M8-TASK-021.4**：实现 `func enforceStep(_ step: ActionStep, scope: RuleScope) -> RuleEvaluationResult`，单步规则评估，供 Orchestrator 在执行前调用

## APPK-M8-TASK-022: MCP/Skills/Rules Audit Integration 实现（H18）

**输入**：M7 既有 AuditService、APPK-M8-TASK-005（Audit 扩展类型）、H18 约束
**输出**：修改 `Sources/AppKCodeDomain/MCP/MCPHostService.swift`、`Sources/AppKCodeDomain/Skills/SkillExecutor.swift`、`Sources/AppKCodeDomain/Rules/RuleEnforcer.swift`（集成审计调用）
**验收标准**：所有 M8 产生的 Tool Action 进入 M7 AuditService；不存在绕过审计的路径

- [ ] **APPK-M8-TASK-022.1**：在 MCPHostService 中集成审计：Server enable/disable、Tool Discovery 完成、Tool Invocation 均调用 M7 `AuditService.record`，AuditTarget 使用 `.mcpServer(serverID, tool:)`
- [ ] **APPK-M8-TASK-022.2**：在 SkillExecutor 中集成审计：Skill 注册、调用、完成均调用 M7 `AuditService.record`，AuditTarget 使用 `.skillInvocation(skillID)`；Skill 内部 Tool 调用的审计由 M7 ActionExecutor 自动完成（H18 复用）
- [ ] **APPK-M8-TASK-022.3**：在 RuleEngine/RuleEnforcer 中集成审计：规则加载、评估、冲突检测、enforcement 决策均调用 M7 `AuditService.record`，AuditTarget 使用 `.ruleEvaluation(ruleID)`
- [ ] **APPK-M8-TASK-022.4**：固化 H18：源码扫描确认所有 M8 执行路径均调用 `AuditService.record`，不存在"MCP/Skill/Rule 操作不记录审计"的路径

## APPK-M8-TASK-023: MCP/Skills/Rules Authorization Integration 实现（H15/H16/H18）

**输入**：M7 既有 AuthorizationGate、APPK-M8-TASK-015（MCPToolAdapter）、APPK-M8-TASK-018（SkillExecutor）、H15/H16/H18 约束
**输出**：修改 MCPToolAdapter / SkillExecutor / RuleEnforcer（集成授权调用）
**验收标准**：所有 M8 Tool Action 经 M7 AuthorizationGate；不存在绕过路径；readOnly 自动放行

- [ ] **APPK-M8-TASK-023.1**：确认 MCPToolAdapter 的所有 Tool 调用通过 M7 ActionExecutor（内部含 AuthorizationGate.authorize），MCP readOnly 工具自动放行，high 工具强制审批（H15）
- [ ] **APPK-M8-TASK-023.2**：确认 SkillExecutor 的所有 Tool 调用通过 M7 ActionExecutor（内部含 AuthorizationGate.authorize），Skill executionPolicy.requireApproval 控制审批（H16）
- [ ] **APPK-M8-TASK-023.3**：实现 H15/H16/H18 不可 bypass：源码扫描 `MCPToolAdapter.swift` / `SkillExecutorImpl.swift` / `MCPToolInvocation.swift` 不含 "bypass" / "autoApprove" / "skipAuth" / "skipApproval" / "directExecute" 关键字
- [ ] **APPK-M8-TASK-023.4**：确认 RuleEnforcer 的 block 级别在 AuthorizationGate 之前生效（规则阻止的操作不进入审批流程），warn/info 级别不阻止审批流程

---

# Phase 4: Application（应用编排层）

> 目标：在 `AppKCodeApplication` 中编排 MCP/Skills/Rules 应用服务，接入 M7 AgentRuntimeOrchestrator。编排层不直接执行高危操作，不绕过 Authorization Gate。Rule Engine 在 Plan 生成前应用约束，Skill 可作为 Plan 执行单元。

## APPK-M8-TASK-024: MCP Host Application Service 实现

**输入**：APPK-M8-TASK-012（MCPHostService）、APPK-M8-TASK-013（ToolDiscovery）、APPK-M8-TASK-015（ToolAdapter）、M7 既有 ToolRegistry
**输出**：`Sources/AppKCodeApplication/MCP/MCPHostAppService.swift`
**验收标准**：封装 MCPHostService 供 Presentation 层调用；不暴露底层 ProcessManager/Transport

- [ ] **APPK-M8-TASK-024.1**：实现 `final class MCPHostAppService`，封装 `MCPHostService` + `MCPToolDiscovery` + `MCPToolAdapter` + M7 `ToolRegistry`，提供 `func registerAndEnable(_ config: MCPServerConfig) async throws -> [ToolID]`（注册 Server + 启动 + 发现工具 + 注册到 Registry）
- [ ] **APPK-M8-TASK-024.2**：实现 `func listServers() -> [MCPServerConfig]`、`func serverState(_ id: MCPServerID) -> MCPConnectionState`、`func disableServer(_ id: MCPServerID) async throws`（禁用 Server 并从 Registry 注销其工具）
- [ ] **APPK-M8-TASK-024.3**：实现 `func discoverTools(_ id: MCPServerID) async throws -> [ToolSchema]`，供 UI 展示 MCP Server 提供的工具列表；Presentation 层通过此 Service 获取信息，不直接调用 Domain MCPHostService（H8 分层隔离延续）

## APPK-M8-TASK-025: Skill Application Service 实现

**输入**：APPK-M8-TASK-017（SkillRegistry）、APPK-M8-TASK-018（SkillExecutor）
**输出**：`Sources/AppKCodeApplication/Skills/SkillAppService.swift`
**验收标准**：封装 SkillRegistry + SkillExecutor 供 Presentation 层调用；不暴露底层 ActionExecutor

- [ ] **APPK-M8-TASK-025.1**：实现 `final class SkillAppService`，封装 `SkillRegistry` + `SkillExecutor`，提供 `func listSkills() -> [SkillManifest]`、`func skillDetail(_ id: SkillID) -> SkillManifest?`
- [ ] **APPK-M8-TASK-025.2**：实现 `func invokeSkill(_ request: SkillInvocationRequest) async throws -> SkillExecutionResult`，调用 SkillExecutor 执行 Skill（内部经 Authorization + Audit，H16/H18）
- [ ] **APPK-M8-TASK-025.3**：实现 `func reloadSkills() async throws -> ReloadResult`，热重载 Skills（APPK-DFX-M03），Presentation 层通过此 Service 触发重载

## APPK-M8-TASK-026: Rule Application Service 实现

**输入**：APPK-M8-TASK-019（RuleEngine）、APPK-M8-TASK-020（RuleResolver）、APPK-M8-TASK-021（RuleEnforcer）
**输出**：`Sources/AppKCodeApplication/Rules/RuleAppService.swift`
**验收标准**：封装 RuleEngine + RuleResolver + RuleEnforcer 供 Presentation 层调用；冲突信息可查

- [ ] **APPK-M8-TASK-026.1**：实现 `final class RuleAppService`，封装 `RuleEngine` + `RuleResolver` + `RuleEnforcer`，提供 `func listRules() -> [Rule]`、`func ruleConflicts() -> [RuleConflict]`、`func resolveConflicts() -> [RuleResolution]`
- [ ] **APPK-M8-TASK-026.2**：实现 `func enforcePlan(_ plan: ActionPlan, scope: RuleScope) -> EnforcedPlan`，供 Orchestrator 在 Plan 生成后执行前调用
- [ ] **APPK-M8-TASK-026.3**：实现 `func reloadRules() async throws -> ReloadResult`，热重载 Rules（APPK-DFX-M03），解析失败时保留上一份有效规则并返回错误信息

## APPK-M8-TASK-027: M8 Orchestrator Integration 实现

**输入**：APPK-M8-TASK-026（RuleAppService）、APPK-M8-TASK-024（MCPHostAppService）、APPK-M8-TASK-025（SkillAppService）、M7 既有 AgentRuntimeOrchestrator/Planner
**输出**：修改 `Sources/AppKCodeApplication/AgentRuntime/AgentRuntimeOrchestrator.swift`（接入 M8）
**验收标准**：$：Rule Engine 在 Plan 生成前/后应用约束；MCP/Skill Tool 已通过 Registry 可被 Plan 引用；H12/H15/H16/H17/H18 流程完整

- [ ] **APPK-M8-TASK-027.1**：在 `AgentRuntimeOrchestrator.runRequest` 流程中接入 RuleEnforcer：① `Planner.generatePlan` 生成原始 Plan → ② `RuleEnforcer.enforcePlan` 应用规则约束 → ③ 过滤 block 步骤、附加 warn 信息 → ④ 将 EnforcedPlan 传递给后续执行流程
- [ ] **APPK-M8-TASK-027.2**：确认 MCP Tool 和 Skill Tool 已通过 M8 注册流程加入 M7 ToolRegistry，Planner 生成 Plan 时可引用这些 Tool（toolID 格式 `mcp.<server>.<tool>` / `skill.<skillID>`），无需修改 Planner 核心逻辑
- [ ] **APPK-M8-TASK-027.3**：实现 Rule Enforcement 事件流：在 `runRequestStreaming` 中新增 `ruleEnforced(stepID:evaluation:)` 事件，供 UI 展示规则约束应用情况
- [ ] **APPK-M8-TASK-027.4**：固化 H17/H18：Orchestrator 中不存在"跳过 RuleEnforcer 直接执行"路径；所有 M8 Tool Action 的审计由 M7 ActionExecutor 自动完成（H18 复用）

---

# Phase 5: Presentation（表现层）

> 目标：在 `AppKCodePresentation` 中实现 MCP/Skills/Rules UI。SwiftUI View 不直接调用 MCPHostService / SkillExecutor / RuleEngine / ProcessManager（H8 分层隔离延续）。审批面板复用 M7 AuthorizationPanelView。

## APPK-M8-TASK-028: MCP Server Management View 实现

**输入**：APPK-M8-TASK-024（MCPHostAppService）、APPK-M8-TASK-001（MCP Types）
**输出**：`Sources/AppKCodePresentation/MCP/MCPServerManagementView.swift`
**验收标准**：展示 MCP Server 列表与状态；支持添加/启用/禁用/删除；状态实时更新

- [ ] **APPK-M8-TASK-028.1**：实现 `struct MCPServerManagementView: View`，展示已配置 MCP Server 列表（名称 + transport 类型 + 连接状态图标 + 工具数量），依赖 `MCPServerManagementViewModel`（ObservableObject）
- [ ] **APPK-M8-TASK-028.2**：实现 `@MainActor final class MCPServerManagementViewModel: ObservableObject`，`@Published var servers: [MCPServerConfig]`、`@Published var serverStates: [MCPServerID: MCPConnectionState]`，订阅 `MCPHostAppService` 事件实时更新
- [ ] **APPK-M8-TASK-028.3**：实现 Server 操作：添加 Server（配置名称/transport/超时）、启用 Server（调用 `registerAndEnable`）、禁用 Server（调用 `disableServer`）、删除 Server 配置；操作按钮按状态启用/禁用
- [ ] **APPK-M8-TASK-028.4**：实现连接异常展示：Server 意外断开时显示警告横幅，提供"重新连接"按钮

## APPK-M8-TASK-029: MCP Tool & Resource Browser View 实现

**输入**：APPK-M8-TASK-024（MCPHostAppService）、APPK-M8-TASK-014（ResourceDiscovery）
**输出**：`Sources/AppKCodePresentation/MCP/MCPToolBrowserView.swift`
**验收标准**：浏览 MCP Server 提供的工具与资源；展示 Tool Schema 与权限标注

- [ ] **APPK-M8-TASK-029.1**：实现 `struct MCPToolBrowserView: View`，按 Server 分组展示已发现工具（工具名 + 描述 + 权限标注 + 参数 Schema），依赖 `MCPToolBrowserViewModel`
- [ ] **APPK-M8-TASK-029.2**：实现权限标注：readOnly（绿色"自动允许"）/ high（红色"需审批"），复用 M7 ToolRegistrySettingsView 的标注风格（H15 权限可视化）
- [ ] **APPK-M8-TASK-029.3**：实现资源浏览：展示 MCP Server 提供的资源列表（URI + 名称 + MIME 类型），点击可查看资源内容（只读）

## APPK-M8-TASK-030: Skill Registry View 实现

**输入**：APPK-M8-TASK-025（SkillAppService）、APPK-M8-TASK-003（Skill Types）
**输出**：`Sources/AppKCodePresentation/Skills/SkillRegistryView.swift`
**验收标准**：展示已注册 Skills 列表；查看 Skill Manifest 详情（input/output Schema、执行策略）

- [ ] **APPK-M8-TASK-030.1**：实现 `struct SkillRegistryView: View`，展示已注册 Skills 列表（名称 + 版本 + 描述 + 工具类别），依赖 `SkillRegistryViewModel`
- [ ] **APPK-M8-TASK-030.2**：实现 Skill 详情展开：展示 `inputSchema`（JSON Schema 可视化）、`outputSchema`、`executionPolicy`（maxSteps/maxDuration/requireApproval/allowedCategories）、`allowedTools`
- [ ] **APPK-M8-TASK-030.3**：实现 Skill 调用入口：提供"调用 Skill"按钮，弹出输入表单（根据 inputSchema 生成），提交后调用 `SkillAppService.invokeSkill`，展示执行结果

## APPK-M8-TASK-031: Rule Editor & Conflict View 实现

**输入**：APPK-M8-TASK-026（RuleAppService）、APPK-M8-TASK-004（Rule Types）
**输出**：`Sources/AppKCodePresentation/Rules/RuleEditorView.swift`、`Sources/AppKCodePresentation/Rules/RuleConflictView.swift`
**验收标准**：展示规则列表与作用域/优先级；编辑规则；冲突可视化与解决

- [ ] **APPK-M8-TASK-031.1**：实现 `struct RuleEditorView: View`，按作用域（global/project/session）分组展示规则列表（名称 + 作用域 + 优先级 + enforcement 标签 + 条件摘要），依赖 `RuleEditorViewModel`
- [ ] **APPK-M8-TASK-031.2**：实现 enforcement 标签：block（红色"阻止"）/ warn（橙色"警告"）/ info（蓝色"提示"），H17 enforcement 可视化
- [ ] **APPK-M8-TASK-031.3**：实现规则详情与编辑：展示 condition（target/matcher）、instruction（description/requireApproval/denyExecution），支持编辑优先级与 enforcement 级别
- [ ] **APPK-M8-TASK-031.4**：实现 `struct RuleConflictView: View`，展示 `RuleConflict` 列表（冲突类型 + 涉及规则 + 描述 + 解决策略），冲突未解决时显示警告横幅；H17 冲突可视化

## APPK-M8-TASK-032: M8 IDE Shell 集成

**输入**：APPK-M8-TASK-028~031（M8 Views）
**输出**：修改 `Sources/AppKCodePresentation/` 既有 Shell 视图
**验收标准**：M8 面板出现在设置/侧栏；M0~M7 既有测试不破坏

- [ ] **APPK-M8-TASK-032.1**：将 `MCPServerManagementView` + `MCPToolBrowserView` 集成到设置窗口（新增 "MCP Servers" 标签页）
- [ ] **APPK-M8-TASK-032.2**：将 `SkillRegistryView` 集成到设置窗口（新增 "Skills" 标签页），将 `RuleEditorView` + `RuleConflictView` 集成到底部面板（新增 "Rules" 标签）
- [ ] **APPK-M8-TASK-032.3**：M0~M7 既有测试断言不破坏（回归保护），既有视图不删除仅扩展

---

# Phase 6: Tests（测试）

> 目标：覆盖 M8 全部能力与硬约束（H15/H16/H17/H18）。新增测试 + M0~M7 回归。所有测试在 x86_64-apple-macos13.0 通过。

## APPK-M8-TASK-033: MCP Client Tests

**输入**：APPK-M8-TASK-007~009（Transport/ProcessManager）、APPK-M8-TASK-012~014（HostService/Discovery）
**输出**：`Tests/AppKCodeInfrastructureTests/MCP/MCPStdioTransportTests.swift`、`Tests/AppKCodeInfrastructureTests/MCP/MCPHttpTransportTests.swift`、`Tests/AppKCodeDomainTests/MCP/MCPHostServiceTests.swift`
**验收标准**：Transport 通信正确；Server Discovery / Tool Discovery / Resource Discovery 覆盖；连接状态流转

- [ ] **APPK-M8-TASK-033.1**：测试 MCPStdioTransport：mock 子进程（echo JSON-RPC 响应），验证 send/sendNotification/start/stop，请求 ID 关联正确
- [ ] **APPK-M8-TASK-033.2**：测试 MCPHttpTransport：mock HTTP Server（URLProtocol mock），验证 POST 请求/响应、SSE 连接、超时
- [ ] **APPK-M8-TASK-033.3**：测试 MCPServerProcessManager：多 Server 并发管理、进程崩溃检测、状态流转（disconnected→connecting→connected→disconnectedUnexpectedly）
- [ ] **APPK-M8-TASK-033.4**：测试 MCPHostService：registerServer/enableServer/disableServer/listServers，serverEvents 事件流正确
- [ ] **APPK-M8-TASK-033.5**：测试 MCPToolDiscovery：discoverTools 解析 tools/list 响应为 [MCPToolDescriptor]，convertToToolSchema 权限映射正确（readOnlyHint → .readOnly，否则 → .high）
- [ ] **APPK-M8-TASK-033.6**：测试 MCPResourceDiscovery：discoverResources/readResource 正确

## APPK-M8-TASK-034: MCP Tool Invocation Tests

**输入**：APPK-M8-TASK-016（ToolInvocation）、APPK-M8-TASK-015（ToolAdapter）
**输出**：`Tests/AppKCodeDomainTests/MCP/MCPToolInvocationTests.swift`、`Tests/AppKCodeDomainTests/MCP/MCPToolAdapterTests.swift`
**验收标准**：Tool Invocation / Result Handling / Error / Timeout / Cancel 覆盖

- [ ] **APPK-M8-TASK-034.1**：测试 MCPToolInvocation.invoke：成功调用返回 MCPToolInvocationResult.success，结果映射为 ToolOutput 正确（text/image/resource content）
- [ ] **APPK-M8-TASK-034.2**：测试错误处理：MCP 协议错误（parseError/invalidRequest/methodNotFound/invalidParams/internalError）映射为可读错误，isError=true 响应映射为 MCPError
- [ ] **APPK-M8-TASK-034.3**：测试超时：超过 timeoutSeconds 返回超时错误，取消传播返回 cancelled
- [ ] **APPK-M8-TASK-034.4**：测试 MCPToolAdapter：schema/validate/execute 正确，注册到 ToolRegistry 后可通过 ToolRegistry.resolve 查询

## APPK-M8-TASK-035: MCP Isolation Tests（H15）

**输入**：APPK-M8-TASK-015（ToolAdapter）、APPK-M8-TASK-023（Auth Integration）、H15 约束
**输出**：`Tests/AppKCodeDomainTests/MCP/MCPIsolationTests.swift`
**验收标准**：MCP Tool 经 AuthorizationGate；不存在绕过路径；readOnly 自动放行

- [ ] **APPK-M8-TASK-035.1**：测试 H15 强制审批：MCP Tool `permission == .high` 时经 AuthorizationGate.authorize，用户 Allow → 执行，用户 Reject → 不执行
- [ ] **APPK-M8-TASK-035.2**：测试 H15 readOnly 放行：MCP Tool `annotations.readOnlyHint == true` → `permission == .readOnly` → 自动放行
- [ ] **APPK-M8-TASK-035.3**：测试 H15 不可 bypass：源码扫描 `MCPToolAdapter.swift` / `MCPToolInvocation.swift` / `MCPHostServiceImpl.swift` 不含 "bypass" / "autoApprove" / "skipAuth" / "directExecute" 关键字
- [ ] **APPK-M8-TASK-035.4**：测试 H15 隔离：MCPToolAdapter.execute 不直接访问 Process/Transport/ProcessManager（H13 延续），仅通过 MCPToolInvocation 协议

## APPK-M8-TASK-036: Skill Registry & Schema Tests

**输入**：APPK-M8-TASK-017（SkillRegistry）、APPK-M8-TASK-010（SkillLoader）
**输出**：`Tests/AppKCodeDomainTests/Skills/SkillRegistryTests.swift`、`Tests/AppKCodeInfrastructureTests/Skills/SkillLoaderTests.swift`
**验收标准**：注册/查询/列举/热重载正确；JSON Schema 校验；重复注册拒绝

- [ ] **APPK-M8-TASK-036.1**：测试 SkillRegistry：register/resolve/listAll/listByCategory，重复注册抛出错误，unregister 后查询返回 nil
- [ ] **APPK-M8-TASK-036.2**：测试 SkillLoader：从目录加载 `*.skill.json` 文件解析为 SkillManifest，内置 Skills 加载正确，解析失败跳过并记录错误
- [ ] **APPK-M8-TASK-036.3**：测试 JSON Schema 校验：inputSchema/outputSchema 结构合法性校验，非法 Schema 拒绝加载
- [ ] **APPK-M8-TASK-036.4**：测试热重载：reload 新增/移除/变更 Skill 正确处理

## APPK-M8-TASK-037: Skill Executor & Isolation Tests（H16）

**输入**：APPK-M8-TASK-018（SkillExecutor）、H16 约束
**输出**：`Tests/AppKCodeDomainTests/Skills/SkillExecutorTests.swift`
**验收标准**：Skill 执行正确；所有 Tool 调用经 AuthorizationGate（H16）；执行策略约束生效

- [ ] **APPK-M8-TASK-037.1**：测试 SkillExecutor.execute：mock ActionExecutor + ToolRegistry，验证 Skill 内部逐步骤调用 ActionExecutor.execute，结果聚合为 SkillExecutionResult.success
- [ ] **APPK-M8-TASK-037.2**：测试 H16 隔离：Skill 内部 Tool 调用通过 M7 ActionExecutor（含 Authorization + Audit），不直接调用 AgentTool.execute 或底层 Service
- [ ] **APPK-M8-TASK-037.3**：测试执行策略：maxSteps 超出 → .failure(.maxStepsExceeded)，maxDuration 超出 → .timedOut，调用不允许的工具类别 → .failure(.toolNotAllowed)
- [ ] **APPK-M8-TASK-037.4**：测试 H16 不可 bypass：源码扫描 `SkillExecutorImpl.swift` 不含 "bypass" / "autoApprove" / "skipAuth" / "directExecute" 关键字
- [ ] **APPK-M8-TASK-037.5**：测试 input 校验：input 不符合 inputSchema 时返回 .failure(.invalidInput)

## APPK-M8-TASK-038: Rule Engine & Precedence Tests（H17）

**输入**：APPK-M8-TASK-019（RuleEngine）、APPK-M8-TASK-020（RuleResolver）、APPK-M8-TASK-021（RuleEnforcer）、H17 约束
**输出**：`Tests/AppKCodeDomainTests/Rules/RuleEngineTests.swift`、`Tests/AppKCodeDomainTests/Rules/RuleResolverTests.swift`、`Tests/AppKCodeDomainTests/Rules/RuleEnforcerTests.swift`
**验收标准**：规则评估/优先级排序/作用域解析/冲突检测/冲突解决/enforcement 全覆盖

- [ ] **APPK-M8-TASK-038.1**：测试 RuleEngine.evaluate：条件匹配（equals/contains/regex/always）正确，target 匹配（toolID/toolCategory/operationKind/all）正确
- [ ] **APPK-M8-TASK-038.2**：测试 H17 优先级排序：同一目标多条规则，按 scope（session > project > global）再按 priority.value 降序，取最高优先级 enforcement
- [ ] **APPK-M8-TASK-038.3**：测试 H17 冲突检测：contradictoryInstruction（block vs allow）、sameTargetDifferentEnforcement 同优先级、priorityCycle 均被检测到
- [ ] **APPK-M8-TASK-038.4**：测试 RuleResolver：higherPriorityWins / higherScopeWins / denyByDefault 策略正确，priorityCycle 抛出需人工干预错误
- [ ] **APPK-M8-TASK-038.5**：测试 RuleEnforcer.enforcePlan：block 步骤移除、warn 步骤附加警告、info 步骤记录、allow 步骤放行
- [ ] **APPK-M8-TASK-038.6**：测试 H17 strictConflictDetection：存在冲突时 updateRuleSet 抛出错误拒绝更新
- [ ] **APPK-M8-TASK-038.7**：测试热重载安全：解析失败时保留上一份有效 RuleSet，不中断 Agent 运行

## APPK-M8-TASK-039: Authorization & Audit Integration Tests（H18）

**输入**：APPK-M8-TASK-022（Audit Integration）、APPK-M8-TASK-023（Auth Integration）、H18 约束、M7 既有 AuditService/AuthorizationGate
**输出**：`Tests/AppKCodeIntegrationTests/M8AuthorizationAuditIntegrationTests.swift`
**验收标准**：所有 M8 Tool Action 进入 Authorization + Audit；不存在绕过路径

- [ ] **APPK-M8-TASK-039.1**：测试 H18 MCP 审计：MCP Tool Invocation 后 AuditService.record 被调用，AuditRecord.target == .mcpServer(serverID, tool:)，含 H14 全部 8 字段
- [ ] **APPK-M8-TASK-039.2**：测试 H18 Skill 审计：Skill Invocation 后 AuditService.record 被调用，AuditRecord.target == .skillInvocation(skillID)，Skill 内部 Tool 调用审计由 ActionExecutor 完成
- [ ] **APPK-M8-TASK-039.3**：测试 H18 Rule 审计：Rule 评估/enforcement 后 AuditService.record 被调用，AuditRecord.target == .ruleEvaluation(ruleID)
- [ ] **APPK-M8-TASK-039.4**：测试 H18 不可绕过：构造完整 M8 流程（MCP Tool 调用 / Skill 执行 / Rule enforcement），验证每条路径均产生审计记录，不存在"无审计记录的 M8 操作"
- [ ] **APPK-M8-TASK-039.5**：测试 H18 复用 M7：M8 审计记录复用 M7 AuditRecord 结构与 AuditLogStore 持久化，SHA-256 校验通过

## APPK-M8-TASK-040: H15-H18 硬约束综合测试

**输入**：H15/H16/H17/H18 约束、M8 全部实现
**输出**：`Tests/AppKCodeIntegrationTests/M8HardConstraintTests.swift`
**验收标准**：H15-H18 端到端验证；源码扫描 bypass 关键字；流程完整性

- [ ] **APPK-M8-TASK-040.1**：测试 H15 端到端：配置 MCP Server → 发现工具 → Agent Plan 引用 MCP Tool → AuthorizationGate 审批 → ActionExecutor 执行 → AuditService 记录，全链路验证
- [ ] **APPK-M8-TASK-040.2**：测试 H16 端到端：注册 Skill → Agent 调用 Skill → Skill 内部 Tool 调用经 AuthorizationGate → 执行策略约束 → AuditService 记录
- [ ] **APPK-M8-TASK-040.3**：测试 H17 端到端：加载规则集 → 冲突检测 → 冲突解决 → Plan 生成后 enforcePlan → block 步骤移除 → 审计记录
- [ ] **APPK-M8-TASK-040.4**：测试 H15-H18 源码扫描：扫描全部 M8 新增 `.swift` 文件，确认不含 "bypass" / "autoApprove" / "skipAuth" / "skipApproval" / "directExecute" / "noAudit" 关键字
- [ ] **APPK-M8-TASK-040.5**：测试 H18 完整性：M8 产生的全部 Tool Action 均有对应 AuditRecord，AuditLogStore.verifyIntegrity 返回 true

## APPK-M8-TASK-041: M0~M7 回归测试

**输入**：M0~M7 既有测试套件（545 tests）
**输出**：确认既有测试全部通过
**验收标准**：545/545 既有测试不修改断言、全部绿色

- [ ] **APPK-M8-TASK-041.1**：M0 回归：AppKCodeSharedTests + AppKCodeDomainTests（M0 部分）+ M0SmokeTest 全部通过
- [ ] **APPK-M8-TASK-041.2**：M1 回归：Workspace 持久化 + M1SmokeTest 全部通过
- [ ] **APPK-M8-TASK-041.3**：M2 回归：EditorCore + TextBuffer + Undo + Performance 全部通过
- [ ] **APPK-M8-TASK-041.4**：M3 回归：LSP + LanguageService + JSONRPC + SearchPerformance + M3SmokeTest 全部通过
- [ ] **APPK-M8-TASK-041.5**：M4 回归：Terminal + Build + Test + Process + Problems + M4SmokeTest 全部通过
- [ ] **APPK-M8-TASK-041.6**：M5 回归：Git G1-G9 + H8 合规 + M5SmokeTest 全部通过
- [ ] **APPK-M8-TASK-041.7**：M6 回归：AI Chat + Context Provider + Model Provider + H9/H10/H11 + M6SmokeTest 全部通过
- [ ] **APPK-M8-TASK-041.8**：M7 回归：Agent Session + Tool Registry + Planner + AuthorizationGate + AuditService + ActionExecutor + Orchestrator + H12/H13/H14 + M7SmokeTest 全部通过

## APPK-M8-TASK-042: M8 Smoke Test

**输入**：M8 全部新增类型与协议
**输出**：`Tests/AppKCodeIntegrationTests/M8SmokeTest.swift`
**验收标准**：类型存在性、协议存在性、H8 合规、H15-H18 合规

- [ ] **APPK-M8-TASK-042.1**：测试 M8 类型存在性：MCPServerID / MCPServerConfig / MCPToolDescriptor / SkillManifest / SkillExecutionPolicy / Rule / RuleSet / RuleConflict 等可实例化
- [ ] **APPK-M8-TASK-042.2**：测试 M8 协议存在性：MCPHostService / MCPToolDiscovery / SkillRegistry / SkillExecutor / RuleEngine / RuleResolver / RuleEnforcer 协议可被 mock 实现
- [ ] **APPK-M8-TASK-042.3**：测试 H8 合规：MCPServerManagementView / MCPToolBrowserView / SkillRegistryView / RuleEditorView 等 Presentation 层 View 不直接调用 MCPServerProcessManager / MCPStdioTransport / SkillLoader / RuleLoader，仅通过 ViewModel + AppService 协议
- [ ] **APPK-M8-TASK-042.4**：测试 H15-H18 端到端：构造完整 M8 流程（MCP Server 启动 → Tool Discovery → Rule 加载 → Skill 注册 → Plan 生成 → Rule Enforcement → Authorization → Execute → Audit），验证全链路合规

---

# Phase 7: Build & Exit Report（构建与出口报告）

## APPK-M8-TASK-043: 构建验证

**输入**：M8 全部实现
**输出**：构建产物 + 架构校验
**验收标准**：Debug/Release 构建 0 errors；x86_64 架构锁定（H1）；Working Tree 干净

- [ ] **APPK-M8-TASK-043.1**：执行 `swift build`（Debug），确认 0 errors、0 warnings（或仅既有 warnings），构建产物为 x86_64
- [ ] **APPK-M8-TASK-043.2**：执行 `swift build -c release`（Release），确认 0 errors，构建产物为 x86_64
- [ ] **APPK-M8-TASK-043.3**：执行 `CI/arch-check.sh` 架构?验，确认 `file .build/release/AppKCode` 输出含 `x86_64` 且不含 `arm64e`（H1）
- [ ] **APPK-M8-TASK-043.4**：执行 `swift test`，确认全量测试通过（545 既有 + N 新增 = 总计），0 failures
- [ ] **APPK-M8-TASK-043.5**：验证 Working Tree：`git status` 确认无未提交变更（或仅预期变更），`git diff` 确认变更范围仅限 M8 新增文件与预期修改文件

## APPK-M8-TASK-044: M8 Exit Report

**输入**：M8 全部交付物
**输出**：`.codeartsdoer/specs/appk_spec_001/m8_exit_report.md`
**验收标准**：含验收摘要、能力清单、硬约束合规、测试统计、提交 SHA、M0~M7 回归、Evidence

- [ ] **APPK-M8-TASK-044.1**：生成 `m8_exit_report.md`，包含：验收摘要表（Debug/Release/全量测试/架构/H15/H16/H17/H18）、M8 能力交付清单（MCP Client / Skills / Rules）、硬约束合规表（H1-H18）、新增文件清单、测试统计、提交链
- [ ] **APPK-M8-TASK-044.2**：记录 Implementation SHA（M8 最终提交 hash），附 `git log` 证据链
- [ ] **APPK-M8-TASK-044.3**：记录 Evidence：构建命令输出、`swift test` 输出、`arch-check.sh` 输出、测试计数（545 既有 + N 新增 = 总计）、H15-H18 合规扫描结果
- [ ] **APPK-M8-TASK-044.4**：记录 M8 出口标准 24 项逐项验收矩阵（PASS/FAIL 裁决 + 证据引用）

---

# 任务依赖关系

```
Phase 1 (Shared Types)
  ├─ TASK-001 (MCP Types) ──┐
  ├─ TASK-002 (MCP Protocol Types) ← TASK-001 ──┤
  ├─ TASK-003 (Skill Types) ──┤
  ├─ TASK-004 (Rule Types) ──┤
  ├─ TASK-005 (Audit Extension, H18) ← TASK-001, TASK-003, TASK-004 ──┤
  └─ TASK-006 (Config Types) ← TASK-001, TASK-003, TASK-004 ──┤
                                       │
Phase 2 (Infrastructure)               │
  ├─ TASK-007 (MCP stdio Transport) ← TASK-002 ──┤
  ├─ TASK-008 (MCP HTTP Transport) ← TASK-002 ──┤
  ├─ TASK-009 (MCP Process Manager) ← TASK-007, TASK-008 ──┤
  ├─ TASK-010 (Skill Loader/Store) ← TASK-003 ──┤
  └─ TASK-011 (Rule Loader/Store/Watcher) ← TASK-004 ──┤
                                       │
Phase 3 (Domain)                       │
  ├─ TASK-012 (MCP Host Service) ← TASK-009 ──┤
  ├─ TASK-013 (MCP Tool Discovery) ← TASK-012, M7 ToolSchemaTypes ──┤
  ├─ TASK-014 (MCP Resource Discovery) ← TASK-012 ──┤
  ├─ TASK-015 (MCP Tool Adapter, H15) ← TASK-013, M7 AgentTool/ToolRegistry ──┤
  ├─ TASK-016 (MCP Tool Invocation) ← TASK-009, M7 ActionResultTypes ──┤
  ├─ TASK-017 (Skill Registry) ← TASK-010 ──┤
  ├─ TASK-018 (Skill Executor, H16) ← TASK-017, M7 ActionExecutor/AuthorizationGate ──┤
  ├─ TASK-019 (Rule Engine, H17) ← TASK-011 ──┤
  ├─ TASK-020 (Rule Resolver, H17) ← TASK-019 ──┤
  ├─ TASK-021 (Rule Enforcer) ← TASK-019, TASK-020, M7 ActionPlan ──┤
  ├─ TASK-022 (Audit Integration, H18) ← TASK-012, TASK-018, TASK-021, M7 AuditService ──┤
  └─ TASK-023 (Auth Integration, H15/H16/H18) ← TASK-015, TASK-018, M7 AuthorizationGate ──┤
                                       │
Phase 4 (Application)                  │
  ├─ TASK-024 (MCP Host App Service) ← TASK-012, TASK-013, TASK-015 ──┤
  ├─ TASK-025 (Skill App Service) ← TASK-017, TASK-018 ──┤
  ├─ TASK-026 (Rule App Service) ← TASK-019, TASK-020, TASK-021 ──┤
  └─ TASK-027 (Orchestrator Integration) ← TASK-026, M7 AgentRuntimeOrchestrator ──┤
                                       │
Phase 5 (Presentation)                 │
  ├─ TASK-028 (MCP Server Mgmt View) ← TASK-024 ──┤
  ├─ TASK-029 (MCP Tool Browser View) ← TASK-024, TASK-014 ──┤
  ├─ TASK-030 (Skill Registry View) ← TASK-025 ──┤
  ├─ TASK-031 (Rule Editor & Conflict View) ← TASK-026 ──┤
  └─ TASK-032 (IDE Shell 集成) ← TASK-028, TASK-029, TASK-030, TASK-031 ──┤
                                       │
Phase 6 (Tests)                        │
  ├─ TASK-033 (MCP Client Tests) ← TASK-007, TASK-008, TASK-009, TASK-012, TASK-013 ──┤
  ├─ TASK-034 (MCP Tool Invocation Tests) ← TASK-015, TASK-016 ──┤
  ├─ TASK-035 (MCP Isolation Tests, H15) ← TASK-015, TASK-023 ──┤
  ├─ TASK-036 (Skill Registry & Schema Tests) ← TASK-010, TASK-017 ──┤
  ├─ TASK-037 (Skill Executor & Isolation Tests, H16) ← TASK-018 ──┤
  ├─ TASK-038 (Rule Engine & Precedence Tests, H17) ← TASK-019, TASK-020, TASK-021 ──┤
  ├─ TASK-039 (Auth & Audit Integration Tests, H18) ← TASK-022, TASK-023 ──┤
  ├─ TASK-040 (H15-H>H18 综合测试) ← 全部 M8 ──┤
  ├─ TASK-041 (M0~M7 回归) ← 全部既有 ──┤
  └─ TASK-042 (M8 Smoke) ← 全部 M8 ──┤
                                       │
Phase 7 (Build & Exit)                 │
  ├─ TASK-043 (Build) ← 全部 M8 ──┤
  └─ TASK-044 (Exit Report) ← TASK-043 ──┘
```

---

# 硬约束覆盖矩阵

| 约束 | 覆盖任务 | 验证任务 |
|------|---------|---------|
| **H15 — MCP Isolation** | TASK-001（类型）、TASK-015（MCPToolAdapter 适配 AgentTool）、TASK-023（Auth Integration）、TASK-027（Orchestrator 接入） | TASK-035（H15 测试）、TASK-040（综合测试）、TASK-042（Smoke） |
| **H16 — Skill Isolation** | TASK-003（类型，executionPolicy）、TASK-018（SkillExecutor 经 ActionExecutor）、TASK-023（Auth Integration） | TASK-037（H16 测试）、TASK-040（综合测试）、TASK-042（Smoke） |
| **H17 — Rules Precedence** | TASK-004（类型，scope/priority）、TASK-019（RuleEngine 优先级+冲突检测）、TASK-020（RuleResolver 冲突解决）、TASK-021（RuleEnforcer） | TASK-038（H17 测试）、TASK-040（综合测试）、TASK-042（Smoke） |
| **H18 — M8 Audit** | TASK-005（Audit 扩展类型）、TASK-=022（Audit Integration）、TASK-023（Auth Integration） | TASK-039（H18 测试）、TASK-040（综合测试）、TASK-042（Smoke） |
| H1 — x86_64 构建锁定 | TASK-043（构建验证） | TASK-043.3（arch-check） |
| H12 — Agent Authorization | M7 既有 AuthorizationGate 不修改 + TASK-023 复用 | TASK-039（H18 复用 H12）、TASK-041.8（M7 回归） |
| H13 — Tool Isolation | M7 既有 AgentTool 协议 + TASK-015 MCPToolAdapter 适配 | TASK-035.4（H15 隔离测试）、TASK-041.8（M7 回归） |
| H14 — Agent Audit | M7 既有 AuditService 不修改 + TASK-022 复用 | TASK-039（H18 复用 H14）、TASK-041.8（M7 回归） |
| H2 — Approval Gate 不可 bypass | M7 既有 + TASK-023 源码扫描 | TASK-040.4（bypass 扫描） |
| H7 — Command Execution Safety | M4 既有 + TASK-007 复用进程托管模式 | TASK-041.5（M4 回归） |
| H8 — Git 操作分层隔离 | M7 既有 + M8 Presentation 层不直接调用 Infra | TASK-042.3（H8 合规） |
| H9 — AI Approval Boundary | M6 既有不修改 | TASK-041.7（M6 回归） |
| H10 — Context Isolation | M6 既有不修改 | TASK-041.7（M6 回归） |
| H11 — Local Mode Default | M6 既有不修改 | TASK-041.7（M6 回归） |

---

# 任务统计

| 维度 | 数量 |
|------|------|
| 主任务总数 | 44 |
| 子任务总数 | 155 |
| Phase 1: Shared Types | 6 主 / 24 子 |
| Phase 2: Infrastructure | 5 主 / 18 子 |
| Phase 3: Domain | 12 主 / 48 子 |
| Phase 4: Application | 4 主 / 13 子 |
| Phase 5: Presentation | 5 主 / 14 子 |
| Phase 6: Tests | 10 主 / 33 子 |
| Phase 7: Build & Exit | 2 主 / 9 子 |
| H15 相关任务 | 4 实现 + 3 测试 |
| H16 相关任务 | 3 实现 + 2 测试 |
| H17 相关任务 | 4 实现 + 2 测试 |
| H18 相关任务 | 3 实现 + 3 测试 |

---

# M8 出口标准对照（24 项）

| 出口要求 | 对应任务 |
|---------|---------|
| 1. Debug Build | TASK-043.1 |
| 2. Release Build | TASK-043.2 |
| 3. 全量测试 | TASK-043.4 |
| 4. M0~M7 Regression | TASK-041 |
| 5. MCP Client Tests | TASK-033 |
| 6. MCP Discovery Tests | TASK-033.5, TASK-033.6 |
| 7. MCP Tool Invocation Tests | TASK-034 |
| 8. MCP Timeout-Cancel Tests | TASK-034.3 |
| 9. Skill Registry Tests | TASK-036 |
| 10. Skill Schema Tests | TASK-036.3 |
| 11. Rule Engine Tests | TASK-038 |
| 12. Rule Precedence Tests | TASK-038.2, TASK-038.3 |
| 13. Authorization Integration | TASK-039 |
| 14. Audit Integration | TASK-039 |
| 15. H15 — MCP Isolation | TASK-035, TASK-040.1 |
| 16. H16 — Skill Isolation | TASK-037, TASK-040.2 |
| 17. H17 — Rules Precedence | TASK-038, TASK-040.3 |
| 18. H18 — M8 Audit | TASK-039, TASK-040.5 |
| 19. H1 — x86_64 Architecture | TASK-043.3 |
| 20. Local Mode | TASK-041.7（M6 回归） |
| 21. M8 Exit Report | TASK-044.1 |
| 22. Implementation SHA | TASK-044.2 |
| 23. Evidence | TASK-044.3 |
| 24. Working Tree Verification | TASK-043.5 |

---

# M8 能力交付清单对照

| M8 范围 | 对应任务 | 验证任务 |
|---------|---------|---------|
| MCP Client — Server Discovery | TASK-001, TASK-007, TASK-008, TASK-009, TASK-012 | TASK-033 |
| MCP Client — Tool Discovery | TASK-002, TASK-013 | TASK-033.5 |
| MCP Client — Resource Discovery | TASK-014 | TASK-033.6 |
| MCP Client — Tool Invocation | TASK-016 | TASK-034 |
| MCP Client — Result Handling | TASK-016, TASK-015 | TASK-034.1 |
| MCP Client — Error/Timeout/Cancel | TASK-016 | TASK-034.2, TASK-034.3 |
| Skills — 定义模型 | TASK-003 | TASK-036 |
| Skills — Registry | TASK-010, TASK-017 | TASK-036 |
| Skills — Execution | TASK-018 | TASK-037 |
| Rules — 定义模型 | TASK-004 | TASK-038 |
| Rules — Engine | TASK-019 | TASK-038 |
| Rules — Conflict Detection | TASK-019, TASK-020 | TASK-038.3, TASK-038.4 |
| Rules — Enforcement | TASK-021 | TASK-038.5 |
| H15 — MCP Isolation | TASK-015, TASK-023 | TASK-035, TASK-040 |
| H16 — Skill Isolation | TASK-018, TASK-023 | TASK-037, TASK-040 |
| H17 — Rules Precedence | TASK-019, TASK-020 | TASK-038, TASK-040 |
| H18 — M8 Audit | TASK-005, TASK-022, TASK-023 | TASK-039, TASK-040 |

---

# M7 接口复用清单

| M7 接口 | M8 复用任务 | 复用方式 |
|---------|-----------|---------|
| `AgentTool` (ToolProtocol) | TASK-015 | MCPToolAdapter 适配此协议 |
| `ToolRegistry` | TASK-013, TASK-015, TASK-024 | MCP Tool 注册到此 Registry |
| `ToolSchema` / `ToolPermission` | TASK-013 | MCP Tool 生成 ToolSchema |
| `AuthorizationGate` | TASK-018, TASK-023 | M8 Tool Action 经此 Gate |
| `AuditService` | TASK-022, TASK-023 | M8 操作记录审计 |
| `ActionExecutor` | TASK-018, TASK-027 | Skill 内部 Tool 调用经此执行 |
| `)AgentRuntimeOrchestrator` | TASK-027 | M8 接入编排流程 |
| `Planner` / `AIPlanner` | TASK-027 | Rule Engine 在 Plan 生成后应用约束 |
| `ActionResult` | TASK-016 | MCP 调用结果映射为 ActionResult |
| `AuditRecord` / `AuditTarget` | TASK-005, TASK-022 | 扩展 AuditTarget 增加 mcp/skill/rule |
| `ActionPlan` / `ActionStep` | TASK-021, TASK-027 | RuleEnforcer 对 Plan 应用约束 |
| `AgentSessionID` | TASK-018 | Skill 调用关联会话 |

---

> **文档结束**。本任务计划覆盖 M8 全部范围（MCP / Skills / Rules Runtime），不越界进入 M9+（CodeArts Compatibility Layer / Plugin Runtime / G-AI Runtime 深度集成）。所有 H15/H16/H17/H18 硬约束在类型层、领域层、编排层、测试层四重保障。复用 M7 既有基线（AgentTool / ToolRegistry / AuthorizationGate / AuditService / ActionExecutor / AgentRuntimeOrchestrator / Planner），不重新实现 Agent Runtime �E能力。M8 是 Runtime Foundation，不是 CodeArts Compatibility。