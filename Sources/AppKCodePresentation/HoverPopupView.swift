import SwiftUI
import AppKCodeDomain

public struct HoverPopupView: View {
    let hoverInfo: HoverInfo
    let onDismiss: () -> Void

    public init(hoverInfo: HoverInfo, onDismiss: @escaping () -> Void) {
        self.hoverInfo = hoverInfo
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(hoverInfo.contents)
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: 400, alignment: .leading)
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(4)
        .shadow(radius: 4)
        .onExitCommand {
            onDismiss()
        }
    }
}