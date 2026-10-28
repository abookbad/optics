import AppKit
import ServiceManagement
import SwiftUI

struct OpticsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var jobs = JobCenter.shared

    var body: some Scene {
        MenuBarExtra {
            StatusMenu(jobs: jobs)
        } label: {
            Image(nsImage: MenuBarIcon.image)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
        }

        Window("Getting Started", id: "getting-started") {
            GettingStartedView()
        }
        .windowResizability(.contentSize)
    }
}

/// Native menu, same shape as the status menu Optics replaces: status lines, then commands.
private struct StatusMenu: View {
    let jobs: JobCenter
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(jobs.isBusy ? "Optics is working" : "Optics is ready")
        Text(LensMode.allCases.map { "\(Prefs.modifiers(for: $0).glyphs): \($0.title)" }.joined(separator: " · "))
        if let failure = jobs.records.first, case .failed(let message) = failure.state {
            Text("Last error: \(message)")
        }
        Divider()
        Button("Settings…") { NSApp.activate(ignoringOtherApps: true); openSettings() }
            .keyboardShortcut(",")
        Button("Getting Started…") { NSApp.activate(ignoringOtherApps: true); openWindow(id: "getting-started") }
        Button("About Optics") { NSApp.activate(ignoringOtherApps: true); NSApp.orderFrontStandardAboutPanel(nil) }
        Divider()
        Button("Quit Optics") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

/// Template glyph for the menu bar: the wheel itself, six petals around a hole.
enum MenuBarIcon {
    static let image: NSImage = {
        let size = NSSize(width: 18, height: 18)
        let img = NSImage(size: size, flipped: true) { rect in
            let n = 6
            let span = 2 * Double.pi / Double(n)
            for i in 0..<n {
                let shape = PetalShape(center: Double(i) * span, span: span, inner: 3.6, outer: 8.4, gap: 1.6, corner: 1.1)
                NSColor.black.setFill()
                NSBezierPath(cgPath: shape.path(in: rect).cgPath).fill()
            }
            return true
        }
        img.isTemplate = true
        return img
    }()
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        MainActor.assumeIsolated { DragMonitor.shared.start() }
        registerLoginItemOnFirstLaunch()
        previewLensIfRequested()
    }

    /// Ready whenever the Mac starts: opt in once on first launch; the Settings toggle owns it after that.
    private func registerLoginItemOnFirstLaunch() {
        let key = "didOfferLoginItem"
        guard !UserDefaults.standard.bool(forKey: key), !CommandLine.arguments.contains("--preview-lens") else { return }
        UserDefaults.standard.set(true, forKey: key)
        try? SMAppService.mainApp.register()
    }

    /// `--preview-lens <convert|tools|actions> <files…> [--hover N]` opens a wheel at screen center, for screenshots and QA.
    private func previewLensIfRequested() {
        var args = CommandLine.arguments
        var hover: Int?
        if let h = args.firstIndex(of: "--hover"), args.count > h + 1 {
            hover = Int(args[h + 1])
            args.removeSubrange(h...(h + 1))
        }
        guard let i = args.firstIndex(of: "--preview-lens"), args.count > i + 2, let mode = LensMode(rawValue: args[i + 1]) else { return }
        let files = args[(i + 2)...].map { URL(fileURLWithPath: $0) }
        let center = NSScreen.main.map { NSPoint(x: $0.frame.midX, y: $0.frame.midY) } ?? .zero
        MainActor.assumeIsolated {
            LensPanel.shared.present(mode: mode, files: files, at: center)
            if let hover { LensPanel.shared.hover(hover) }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        MainActor.assumeIsolated { TrayController.open(with: urls.filter(\.isFileURL)) }
    }
}
