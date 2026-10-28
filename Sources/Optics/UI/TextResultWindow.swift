import AppKit
import SwiftUI

/// Shows text a tool produced (QR payloads, PDF text) with copy and save buttons.
@MainActor
enum TextResultWindow {
    private static var windows: [NSWindow] = []

    static func show(title: String, text: String) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 380),
                              styleMask: [.titled, .closable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = title
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: TextResultView(text: text, close: { window.close() }))
        window.center()
        windows.append(window)
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { _ in
            MainActor.assumeIsolated { windows.removeAll { $0 === window } }
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

private struct TextResultView: View {
    let text: String
    let close: () -> Void
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                Text(text)
                    .font(.system(size: 13, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            Divider()
            HStack {
                if let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)), url.scheme?.hasPrefix("http") == true {
                    Button("Open Link") { NSWorkspace.shared.open(url) }
                }
                Spacer()
                Button("Save…") { save() }
                Button(copied ? "Copied" : "Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    copied = true
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                Button("Done", action: close).keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .frame(minWidth: 380, minHeight: 240)
    }

    private func save() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Optics Text.txt"
        panel.allowedContentTypes = [.plainText]
        if panel.runModal() == .OK, let url = panel.url { try? text.write(to: url, atomically: true, encoding: .utf8) }
    }
}
