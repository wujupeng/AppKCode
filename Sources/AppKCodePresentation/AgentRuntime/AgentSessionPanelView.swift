import SwiftUI
import AppKCodeShared
import AppKCodeApplication

// MARK: - Agent Session Panel View (TASK-026)

public struct AgentSessionPanelView: View {
    @StateObject private var viewModel: AgentSessionViewModel

    public init(viewModel: AgentSessionViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Agent Sessions")
                    .font(.headline)
                Spacer()
                Button(action: { viewModel.createNewSession() }) {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.borderless)
            }
            .padding(8)

            Divider()

            List(viewModel.sessions, id: \.id) { session in
                AgentSessionRowView(session: session, viewModel: viewModel)
            }
            .listStyle(.sidebar)

            if let active = viewModel.activeSession {
                Divider()
                HStack {
                    Button("Resume") { viewModel.resumeSession(active) }
                        .disabled(sessionStatus(for: active) != .paused)
                    Button("Pause") { viewModel.pauseSession(active) }
                        .disabled(sessionStatus(for: active) != .active)
                    Button("Abort") { viewModel.abortSession(active) }
                        .foregroundColor(.red)
                        .disabled(sessionStatus(for: active) == .aborted)
                }
                .padding(8)
            }
        }
    }

    private func sessionStatus(for id: AgentSessionID) -> AgentSessionStatus {
        viewModel.sessions.first { $0.id == id }?.status ?? .aborted
    }
}

struct AgentSessionRowView: View {
    let session: AgentSessionSnapshot
    let viewModel: AgentSessionViewModel

    var body: some View {
        HStack(spacing: 8) {
            statusIcon
            VStack(alignment: .leading, spacing: 2) {
                Text(session.projectRoot.lastPathComponent)
                    .font(.system(.body, design: .monospaced))
                Text(session.createdAt.rawValue.prefix(19))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture { viewModel.selectSession(session.id) }
    }

    @ViewBuilder var statusIcon: some View {
        switch session.status {
        case .active: Circle().fill(.green).frame(width: 8, height: 8)
        case .paused: Circle().fill(.orange).frame(width: 8, height: 8)
        case .completed: Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
        case .aborted: Image(systemName: "xmark.circle.fill").foregroundColor(.red)
        }
    }
}

// MARK: - Agent Session ViewModel

@MainActor
public final class AgentSessionViewModel: ObservableObject {
    @Published public var sessions: [AgentSessionSnapshot] = []
    @Published public var activeSession: AgentSessionID?
    @Published public var runtimeEvents: [AgentRuntimeEvent] = []

    public init() {}

    public func createNewSession() {
        // Delegates to AgentSessionManaging.createSession
    }

    public func selectSession(_ id: AgentSessionID) {
        activeSession = id
    }

    public func resumeSession(_ id: AgentSessionID) {
        // Delegates to AgentSessionManaging.resumeSession
    }

    public func pauseSession(_ id: AgentSessionID) {
        // Delegates to AgentSessionManaging.pauseSession
    }

    public func abortSession(_ id: AgentSessionID) {
        // Delegates to AgentSessionManaging.abortSession
    }
}