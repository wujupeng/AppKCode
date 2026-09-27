import SwiftUI
import AppKit
import AppKCodePresentation
import AppKCodeApplication
import AppKCodeShared

@main
struct AppKCodeApp: App {
    @NSApplicationDelegateAdaptor(AppKCodeAppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup("AppKCode") {
            AppKCodeRootView()
                .frame(minWidth: 1000, minHeight: 700)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            AppKCodeCommands()
        }
    }
}

final class AppKCodeAppDelegate: NSObject, NSApplicationDelegate {
    let serviceContainer = ServiceContainer()

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [
            "appkcode.modelRouter.defaultEndpoint": "http://127.0.0.1:8080"
        ])
        if let workspaceURL = serviceContainer.workspaceService.loadPersistedWorkspace() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NotificationCenter.default.post(name: .appkRestoreWorkspace, object: workspaceURL)
            }
        }
    }
}

struct AppKCodeRootView: View {
    var body: some View {
        IDEShellRootView()
    }
}

struct AppKCodeCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Open Folder…") {
                NotificationCenter.default.post(name: .appkOpenFolderRequested, object: nil)
            }
            .keyboardShortcut("o", modifiers: .command)
        }
        CommandGroup(after: .newItem) {
            Button("Save") {
                NotificationCenter.default.post(name: .appkSaveRequested, object: nil)
            }
            .keyboardShortcut("s", modifiers: .command)

            Button("Save As…") {
                NotificationCenter.default.post(name: .appkSaveAsRequested, object: nil)
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])

            Button("Close") {
                NotificationCenter.default.post(name: .appkCloseRequested, object: nil)
            }
            .keyboardShortcut("w", modifiers: .command)
        }
        CommandGroup(after: .toolbar) {
            Button("Toggle Sidebar") {}
                .keyboardShortcut("s", modifiers: [.command, .control])
            Button("Toggle Bottom Panel") {}
                .keyboardShortcut("b", modifiers: [.command, .control])
        }
        CommandGroup(replacing: .help) {
            Button("AppKCode Help") {}
        }
    }
}
