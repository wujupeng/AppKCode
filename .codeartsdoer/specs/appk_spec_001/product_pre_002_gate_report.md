# PRODUCT-PRE-002 Gate Report — 本地 macOS GUI 真实环境验证

| Field | Value |
|-------|-------|
| **任务编号** | PRODUCT-PRE-002 |
| **任务名称** | 本地 macOS GUI 真实环境验证 |
| **日期** | 2026-10-09 |
| **状态** | 🔶 VERIFICATION COMPLETE / AWAITING PM GATE REVIEW |
| **基线** | M0-M11 全部 PASS / CLOSED / FROZEN (commit `69cbba1`) |
| **验证环境** | macOS 13.7.8 Intel x86_64, Xcode 14.3.1, Swift 5.8, SSH remote + `open` |
| **前置任务** | PRODUCT-PRE-001 (PARTIAL PASS / HOLD) |
| **授权范围** | 在真实图形登录会话中验证启动/渲染/激活/AX，不修改冻结代码 |

---

## 1. 执行摘要

本报告是 PRODUCT-PRE-002 的 Gate 报告。PM 裁定 PRODUCT-PRE-001 为 PARTIAL PASS / HOLD，要求在本地 GUI session 中验证。本任务通过 `open` 命令（经 LaunchServices → launchd → Aqua session）启动 app，并与最小 SwiftUI app 进行对照实验。

**核心结论**：

1. **`open` 命令将 app 启动到 Aqua GUI session (gui/501)** — 进程确认在 gui/501 中，由 loginwindow 创建
2. **窗口仍不可见** — 即使在 Aqua session 中，`screencapture` 仍只显示桌面背景，`CGWindowListCreateImage` 返回 NIL
3. **对照实验证明问题不是 AppKCode 特有的** — 最小 SwiftUI app (Text + Button) 通过 `open` 启动后表现完全一致
4. **SSH 无法建立 display compositor 连接** — 即使 `open` 将进程放入 Aqua session，从 SSH 发起的启动仍无法将窗口合成到物理显示器

**与 PRODUCT-PRE-001 的关键区别**：
- PRE-001: 直接执行二进制 → 进程在 SSH session → 窗口不合成
- PRE-002: 使用 `open` → 进程在 Aqua session (gui/501) → 窗口仍不合成
- PRE-002 对照: 最小 SwiftUI app 也失败 → 证明非 AppKCode 特有

**Gate 总判定**：G1/G6/G7 PASS · G2/G4 PARTIAL · G3 CANNOT VERIFY · G5 PARTIAL（对照实验排除了 AppKCode 代码缺陷，但无法确认 SSH 是否为唯一根因）

---

## 2. 验证环境

| 项目 | 值 |
|------|-----|
| macOS | 13.7.8 (Ventura) |
| 硬件 | Intel x86_64 |
| Xcode | 14.3.1 |
| Swift | 5.8 |
| GUI Session | gui/501, type=login, session=Aqua, active |
| Console User | hunt (UID 501) |
| SSH User | hunt (UID 501, 同一用户) |
| WindowServer | PID 151, running since Sep 25 |
| Display | 1920×1080 (1080p FHD) |
| SSH tty | not a tty |
| Screen Sharing | 服务存在 (com.apple.screensharing.agent)，无法确认是否启用 |
| 启动方式 | `open /tmp/AppKCode.app` (LaunchServices → launchd → Aqua) |

---

## 3. Gate 验收项结果

| Gate | 要求 | 结果 | 说明 |
|------|------|------|------|
| **G1** | 标准构建 | ✅ **PASS** | `swift build -c release` 成功 |
| **G2** | 启动与激活 | ⚠️ **PARTIAL** | 进程在 Aqua session 启动，但无法激活 (frontmost=false) |
| **G3** | UI 可见性 | ❌ **CANNOT VERIFY** | screencapture 只显示桌面背景，但对照实验证明非 AppKCode 特有 |
| **G4** | Accessibility | ⚠️ **PARTIAL** | AX 0 窗口，菜单栏 7 项正确，0 内容视图 |
| **G5** | 渲染根因 | ⚠️ **PARTIAL** | 对照实验排除 AppKCode 代码缺陷；SSH 是合理根因但无法确认为唯一根因 |
| **G6** | 回归测试 | ✅ **PASS** | 1271/1271 PASS, 0 failures, 36.34s |
| **G7** | 基线完整性 | ✅ **PASS** | Working tree clean, commit 69cbba1 未修改 |

---

## 4. 各 Gate 详细证据

### 4.1 G1 — 标准构建 ✅ PASS

```
swift build -c release → Build complete! (2.54s)
file: Mach-O 64-bit executable x86_64
```

### 4.2 G2 — 启动与激活 ⚠️ PARTIAL

**启动**: `open /tmp/AppKCode.app` → 进程启动 (PID 34532)

**Aqua session 确认**:
```
launchctl print gui/501:
  34532  -  application.com.appkcode.ide.14811333.14811336
```
进程在 gui/501 (Aqua session) 中，由 loginwindow 创建。

**激活尝试**:
```
osascript -e 'tell application "AppKCode" to activate'
→ frontmost = false (WeChat 仍为 frontmost)
```

**判定**: 进程在 Aqua session 中启动（优于 PRE-001 的直接执行），但无法激活。

### 4.3 G3 — UI 可见性 ❌ CANNOT VERIFY

**CG 窗口信息**:
```
WID=2600, Owner=AppKCode
Bounds: X=460, Y=146, Width=1000, Height=728
Onscreen=true, Alpha=1.0, Layer=0
```

**截图采集**:

| 方法 | 结果 |
|------|------|
| `screencapture -l 2600` | "could not create image from window" |
| `screencapture -R 460,146,1000,728` | 872KB — AI 分析：仅桌面背景 |
| `screencapture -x` (全屏) | 2.4MB — AI 分析：桌面 + WeChat 菜单栏 |
| `CGWindowListCreateImage` | NIL |

**AI 分析结论**:
- 全屏截图：仅桌面壁纸 + WeChat 菜单栏，无 AppKCode 窗口
- 区域截图：仅橙色/琥珀色桌面壁纸，无 UI 内容

**判定**: 无法从 SSH 验证 UI 可见性。窗口在 CG 中存在但不合成到显示器。

### 4.4 G4 — Accessibility ⚠️ PARTIAL

**AX 树**:
```
AXApplication (AppKCode)
├── AXApplication (role=AXApplication, desc=application)
└── AXMenuBar (7 items: Apple, AppKCode, File, Edit, View, Window, Help)

Windows: 0
Content views: 0
Frontmost: false
```

**CG/AX 不一致**: CG 报告 1 窗口 (WID=2600)，AX 报告 0 窗口。

**判定**: 菜单栏正确，但无窗口和内容视图。CG/AX 不一致持续存在。

### 4.5 G5 — 渲染根因 ⚠️ PARTIAL

**对照实验设计**: 创建最小 SwiftUI app (Text + Button)，用相同方式 (`open`) 启动，对比行为。

**最小 SwiftUI app**:
```swift
@main struct MinimalTestApp: App {
    var body: some Scene {
        WindowGroup {
            VStack {
                Text("Hello Minimal Test").font(.title)
                Button("Test Button") { }
            }
        }
    }
}
```

**对照结果**:

| 检查项 | AppKCode | MinimalTestApp | 一致? |
|--------|----------|----------------|-------|
| 进程启动 | ✅ PID 34532 | ✅ PID 34783 | ✅ |
| Aqua session | ✅ gui/501 | ✅ gui/501 | ✅ |
| CG 窗口存在 | ✅ WID=2600 | ✅ WID=2602 | ✅ |
| CG Onscreen | true | true | ✅ |
| CG Alpha | 1.0 | 1.0 | ✅ |
| CGWindowListCreateImage | NIL | NIL | ✅ |
| AX Windows | 0 | 0 | ✅ |
| AX 菜单栏 | 7 items | 7 items | ✅ |
| Frontmost | false | false | ✅ |
| 可激活 | false | false | ✅ |
| screencapture -l | 失败 | 失败 | ✅ |

**结论**: 两个 app 行为**完全一致**。最小 SwiftUI app 也出现幽灵窗口。

**根因分析**:

| 假设 | 验证方法 | 结果 |
|------|----------|------|
| H1: AppKCode 代码缺陷 | 最小 app 也失败 | ❌ 排除 |
| H2: SwiftUI 视图复杂度 | Text+Button 也不渲染 | ❌ 排除 |
| H3: 启动方式 (直接执行) | `open` 也不工作 | ❌ 排除 |
| H4: SSH 环境限制 | `open` 进入 Aqua session 但仍不渲染 | ⚠️ 强烈支持但未完全确认 |
| H5: display compositor 连接缺失 | 进程在 Aqua session 但窗口不合成 | ⚠️ 强烈支持 |

**判定**: PARTIAL。对照实验排除了 AppKCode 代码缺陷 (H1/H2/H3)，强烈支持 SSH/display compositor 限制 (H4/H5)，但无法从 SSH 确认这是唯一根因——需在真实本地 GUI session (物理访问/VNC) 中验证。

### 4.6 G6 — 回归测试 ✅ PASS

```
swift test → 1271 tests, 0 failures, 36.34s
```

### 4.7 G7 — 基线完整性 ✅ PASS

```
git log: 69cbba1 (M11-P8)
git status: clean
git diff: empty
```

M0-M11 冻结源码未修改。实验中未修改任何项目文件。

---

## 5. 关键发现汇总

### 5.1 `open` vs 直接执行

| 方面 | PRODUCT-PRE-001 (直接执行) | PRODUCT-PRE-002 (`open`) |
|------|--------------------------|--------------------------|
| 进程 session | SSH session | Aqua session (gui/501) ✅ |
| CG 窗口存在 | ✅ | ✅ |
| 窗口合成到显示器 | ❌ | ❌ |
| AX 窗口数 | 0 | 0 |
| 可激活 | false | false |
| CGWindowListCreateImage | NIL | NIL |

`open` 将进程放入 Aqua session，但窗口仍不合成。这表明问题不仅是 "进程不在 GUI session"，而是更底层的 display compositor 连接问题。

### 5.2 对照实验意义

最小 SwiftUI app (Text + Button) 与 AppKCode 行为完全一致，证明：
- **问题不是 AppKCode 代码缺陷**
- **问题不是 SwiftUI 视图复杂度**
- **问题与环境/启动方式相关**

### 5.3 CG/AX 不一致

CG 报告 1 窗口 (Onscreen=true, Alpha=1.0)，AX 报告 0 窗口。这种不一致表明：
- 窗口在 WindowServer 数据库中注册
- 但未在 AppKit/AX 层正确创建
- 可能与 SwiftUI WindowGroup 生命周期有关，或在 SSH 环境中窗口创建不完整

### 5.4 Screen Sharing 服务

Mac 上存在 Screen Sharing 相关服务：
- `com.apple.screensharing.agent`
- `com.apple.RemoteManagementAgent`
- `com.apple.RemoteDesktop.agent`

但无法从 SSH 确认是否启用入站连接。若启用，可通过 VNC/Screen Sharing 进行真正的本地 GUI 验证。

---

## 6. 无法完成的事项

| 事项 | 原因 | 解决方案 |
|------|------|----------|
| G3 UI 可见性 | SSH 环境中窗口不合成到显示器 | 需物理访问 Mac 或 VNC |
| G5 确认 SSH 为唯一根因 | 无法从 SSH 验证本地 GUI 是否正常 | 需在本地 GUI session 中启动 app |
| App 激活 | `osascript activate` 无效 | 需在本地 GUI session 中操作 |

---

## 7. PM 决策点

| 选项 | 描述 | 前提 |
|------|------|------|
| **A** | 接受对照实验结论：问题非 AppKCode 特有，维持 HOLD 等待本地 GUI 验证 | PM 认可对照实验证据 |
| **B** | 安排物理访问 Mac，在 Finder/Terminal.app 中启动 app | PM 可安排 Mac 本地访问 |
| **C** | 启用 Screen Sharing/VNC，通过 VNC 客户端启动 app | Mac Screen Sharing 可启用 |
| **D** | 尝试 launchd plist 在 GUI session 中启动 app | PM 授权 launchd 方案 |
| **E** | 不接受结论，要求进一步调查 | PM 指定新方向 |

### 7.1 建议

**推荐选项 B 或 C**：
1. 对照实验已证明问题非 AppKCode 特有（最小 SwiftUI app 也失败）
2. 需在**真正的本地 GUI session**（非 SSH 发起的 `open`）中验证
3. 物理访问或 VNC 可排除 SSH/display compositor 连接问题
4. 若本地 GUI 验证通过 → 问题确认为 SSH 环境限制，AppKCode GUI 正常
5. 若本地 GUI 验证仍失败 → 需深入调查 SwiftUI/SPM 在 macOS 13.7 上的渲染问题

---

## 8. 基线完整性声明

| 项目 | 状态 |
|------|------|
| M0-M11 源码 | ✅ FROZEN (未修改) |
| 测试文件 | ✅ 未修改 |
| Package.swift | ✅ 未修改 |
| Git commit | `69cbba1` (未新增提交) |
| Working tree | ✅ Clean |

---

## 9. 执行记录

| 步骤 | 描述 | 状态 |
|------|------|------|
| Step 1 | 确认执行环境 | ✅ macOS 13.7.8, Aqua session active |
| Step 2 | 构建 + `open` 启动 | ✅ 进程在 gui/501 |
| Step 3 | 验证窗口内容 | ✅ screencapture + AI 分析完成 |
| Step 4 | 验证 Accessibility | ✅ AX 树完整检查 |
| Step 5 | 对照最小复现 | ✅ 最小 SwiftUI app 行为一致 |
| Step 6 | Gate 报告 | ✅ 本文档 |

---

## 10. 附录: 证据文件

| 文件 | 描述 |
|------|------|
| `appkcode_pre002_full.png` | 全屏截图 — 桌面 + WeChat 菜单栏 |
| `appkcode_pre002_region.png` | 区域截图 — 仅桌面背景 |
| `product_pre_001_gate_report.md` | PRODUCT-PRE-001 Gate 报告 (前置) |

---

**报告生成时间**: 2026-10-09  
**验证执行者**: CodeArts Agent (PRODUCT-PRE-002)  
**下一步**: 等待 PM Gate Review 并决策后续路径