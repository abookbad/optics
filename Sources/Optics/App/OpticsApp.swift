import AppKit
import SwiftUI


struct OpticsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuView()
        } label: {
            Image(systemName: "circle.circle")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        MainActor.assumeIsolated { DragMonitor.shared.start() }
        previewLensIfRequested()
    }

    /// `--preview-lens <convert|tools|actions> <files…>` opens a lens at screen center, for screenshots and QA.
    private func previewLensIfRequested() {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--preview-lens"), args.count > i + 2, let mode = LensMode(rawValue: args[i + 1]) else { return }
        let files = args[(i + 2)...].map { URL(fileURLWithPath: $0) }
        let center = NSScreen.main.map { NSPoint(x: $0.frame.midX, y: $0.frame.midY) } ?? .zero
        MainActor.assumeIsolated {
            LensPanel.shared.present(mode: mode, files: files, at: center)
            LensPanel.shared.hover(1)
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        MainActor.assumeIsolated { TrayController.open(with: urls.filter(\.isFileURL)) }
    }
}
