import SwiftUI
import AppKCodeShared
import AppKCodeInfrastructure

struct GlobalSearchView: View {
    @State private var query: String = ""
    @State private var results: [SearchHit] = []
    @State private var isSearching: Bool = false
    @State private var searchMode: SearchMode = .content
    @State private var errorMessage: String?

    let searchDirectory: URL?
    private let ripgrepClient = RipgrepClient()

    enum SearchMode: Int, CaseIterable {
        case content = 0
        case filename = 1
        var label: String { self == .content ? "Content" : "File Name" }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            if let error = errorMessage {
                Text(error).foregroundColor(.red).font(.caption).padding(4)
            }
            resultsList
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Picker("", selection: $searchMode) {
                ForEach(SearchMode.allCases, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 160)

            TextField("Search…", text: $query)
                .textFieldStyle(.roundedBorder)
                .onSubmit { performSearch() }

            if isSearching {
                ProgressView().scaleEffect(0.7)
            }
        }
        .padding(8)
    }

    private var resultsList: some View {
        List(results, id: \.self) { hit in
            VStack(alignment: .leading, spacing: 2) {
                Text(hit.filePath)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                if hit.lineNumber > 0 {
                    Text("Line \(hit.lineNumber): \(hit.matchedLine)")
                        .font(.system(size: 12, design: .monospaced))
                        .lineLimit(2)
                } else {
                    Text(hit.matchedLine)
                        .font(.system(size: 12, design: .monospaced))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                let url = URL(fileURLWithPath: hit.filePath)
                NotificationCenter.default.post(name: .appkFileOpenRequested, object: url)
                if hit.lineNumber > 0 {
                    NotificationCenter.default.post(name: .appkCursorJumpRequested, object: hit.lineNumber)
                }
            }
        }
    }

    private func performSearch() {
        guard !query.isEmpty, let dir = searchDirectory else { return }
        isSearching = true
        errorMessage = nil
        Task {
            do {
                let hits: [SearchHit]
                if searchMode == .content {
                    hits = try await ripgrepClient.search(query: query, in: dir)
                } else {
                    hits = try await ripgrepClient.searchFileNames(query: query, in: dir)
                }
                await MainActor.run {
                    self.results = hits
                    self.isSearching = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isSearching = false
                }
            }
        }
    }
}

extension SearchHit: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(filePath)
        hasher.combine(lineNumber)
    }
}