import AppKit

/// File actions from the Actions lens and Tray menus.
@MainActor
enum Actions {
    static func perform(_ action: FileAction, on urls: [URL]) {
        switch action {
        case .newTray:
            TrayController.open(with: urls)
        case .copyPaths:
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(urls.map(\.path).joined(separator: "\n"), forType: .string)
            Toast.show("Copied", detail: urls.count == 1 ? urls[0].path : "\(urls.count) paths")
        case .moveTo, .copyTo:
            transfer(urls, move: action == .moveTo)
        case .airDrop:
            NSSharingService(named: .sendViaAirDrop)?.perform(withItems: urls)
        case .openTerminal:
            openTerminal(at: urls[0])
        case .revealInFinder:
            NSWorkspace.shared.activateFileViewerSelecting(urls)
        }
    }

    private static func transfer(_ urls: [URL], move: Bool) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = move ? "Move Here" : "Copy Here"
        panel.message = "\(move ? "Move" : "Copy") \(urls.count == 1 ? urls[0].lastPathComponent : "\(urls.count) items") to…"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let dir = panel.url else { return }
        var done: [URL] = []
        var failures = 0
        for u in urls {
            let target = OutputNaming.unique(in: dir, base: u.deletingPathExtension().lastPathComponent, ext: u.pathExtension)
            do {
                if move { try FileManager.default.moveItem(at: u, to: target) } else { try FileManager.default.copyItem(at: u, to: target) }
                done.append(target)
            } catch { failures += 1 }
        }
        if failures > 0 { Toast.show("Some items weren't \(move ? "moved" : "copied")", detail: "\(failures) failed", isError: true) }
        else { Toast.show(move ? "Moved" : "Copied", detail: "\(done.count) to \(dir.lastPathComponent)") }
    }

    /// Prefers iTerm when installed, otherwise Terminal.
    private static func openTerminal(at url: URL) {
        let folder = url.hasDirectoryPath || (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            ? url : url.deletingLastPathComponent()
        let ws = NSWorkspace.shared
        let app = ws.urlForApplication(withBundleIdentifier: "com.googlecode.iterm2")
            ?? ws.urlForApplication(withBundleIdentifier: "com.apple.Terminal")
        guard let app else { return }
        ws.open([folder], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
    }
}
