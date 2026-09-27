import Foundation
import AppKCodeShared
import AppKCodeInfrastructure
import Combine

@MainActor
public final class GitStateManager: ObservableObject {
    @Published public private(set) var status: GitRepositoryStatus = .notARepository
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var lastError: String? = nil

    private let gitService: GitServiceProtocol
    private var currentRepoURL: URL? = nil

    public init(gitService: GitServiceProtocol) {
        self.gitService = gitService
    }

    public func setRepository(_ url: URL) async {
        currentRepoURL = url
        await refresh()
    }

    public func refresh() async {
        guard let repoURL = currentRepoURL else { return }
        isLoading = true
        lastError = nil

        do {
            let newStatus = try await gitService.getStatus(at: repoURL)
            status = newStatus
        } catch {
            lastError = error.localizedDescription
            status = .notARepository
        }

        isLoading = false
    }

    public func detectAndSet(_ url: URL) async {
        currentRepoURL = url
        isLoading = true
        let detected = await gitService.detectRepository(at: url)
        status = detected
        isLoading = false
    }

    public var currentBranch: String? {
        status.currentBranch
    }

    public var modifiedCount: Int {
        status.files.filter { !$0.staged && $0.status != .untracked }.count
    }

    public var stagedCount: Int {
        status.files.filter { $0.staged }.count
    }

    public var untrackedCount: Int {
        status.files.filter { $0.status == .untracked }.count
    }
}