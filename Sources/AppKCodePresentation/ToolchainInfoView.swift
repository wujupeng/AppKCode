import SwiftUI
import AppKCodeShared
import AppKCodeInfrastructure

struct ToolchainInfoView: View {
    @State private var toolchains: [ToolchainInfo] = []
    @State private var isDetecting: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Toolchains")
                    .font(.headline)
                Spacer()
                Button("Detect") { detect() }
                    .buttonStyle(.borderedProminent)
                    .disabled(isDetecting)
            }
            .padding(8)

            Divider()

            if toolchains.isEmpty {
                Text("Click Detect to scan for toolchains")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(toolchains, id: \.kind) { info in
                            toolchainRow(info)
                        }
                    }
                    .padding(8)
                }
            }
        }
    }

    private func toolchainRow(_ info: ToolchainInfo) -> some View {
        HStack(spacing: 8) {
            Image(systemName: info.isAvailable ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor(info.isAvailable ? .green : .red)
            VStack(alignment: .leading, spacing: 2) {
                Text(info.kind.displayName)
                    .font(.system(size: 13, weight: .medium))
                if info.isAvailable {
                    HStack(spacing: 8) {
                        Text(info.version)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text(info.path)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Not installed")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(6)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(4)
    }

    private func detect() {
        isDetecting = true
        Task {
            let detector = ToolchainDetector()
            let results = await detector.detectAll()
            await MainActor.run {
                toolchains = results
                isDetecting = false
            }
        }
    }
}