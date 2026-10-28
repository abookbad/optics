import AppKit

/// Watches system-wide mouse drags. When a file drag is under way and the user
/// presses one of the lens modifier combinations, the matching lens opens under the cursor.
///
/// How a "file drag" is detected: every drag session writes to the shared drag
/// pasteboard, bumping its changeCount. A changeCount that moved since the mouse went
/// down, and that carries file URLs, means the user is dragging files right now.
@MainActor
final class DragMonitor {
    static let shared = DragMonitor()

    private var monitors: [Any] = []
    private var changeCountAtMouseDown = NSPasteboard(name: .drag).changeCount
    private var draggingFiles: [URL]?
    private var shownMode: LensMode?

    func start() {
        guard monitors.isEmpty else { return }
        let handlers: [(NSEvent.EventTypeMask, (NSEvent) -> Void)] = [
            (.leftMouseDown, { [weak self] _ in self?.mouseDown() }),
            (.leftMouseDragged, { [weak self] e in self?.dragged(e) }),
            (.flagsChanged, { [weak self] e in self?.flagsChanged(e) }),
            (.leftMouseUp, { [weak self] _ in self?.mouseUp() }),
        ]
        for (mask, handler) in handlers {
            if let m = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { e in MainActor.assumeIsolated { handler(e) } }) {
                monitors.append(m)
            }
        }
        NSLog("[Optics] drag monitor started")
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
    }

    private func mouseDown() {
        changeCountAtMouseDown = NSPasteboard(name: .drag).changeCount
        draggingFiles = nil
        shownMode = nil
    }

    private func dragged(_ event: NSEvent) {
        if draggingFiles == nil {
            let pb = NSPasteboard(name: .drag)
            guard pb.changeCount != changeCountAtMouseDown else { return }
            let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
            guard !urls.isEmpty else { return }
            draggingFiles = urls
        }
        evaluate(event.modifierFlags)
    }

    private func flagsChanged(_ event: NSEvent) {
        guard draggingFiles != nil else { return }
        evaluate(event.modifierFlags)
    }

    private func evaluate(_ flags: NSEvent.ModifierFlags) {
        guard let files = draggingFiles else { return }
        let pressed = flags.intersection(Prefs.relevantModifiers)
        // Exact match so ⌃⌥ doesn't also trigger the ⌥ lens.
        let mode = LensMode.allCases.first { Prefs.modifiers(for: $0) == pressed && !pressed.isEmpty }
        guard let mode, mode != shownMode else { return }
        shownMode = mode
        LensPanel.shared.present(mode: mode, files: files, at: NSEvent.mouseLocation)
    }

    private func mouseUp() {
        draggingFiles = nil
        shownMode = nil
        // Give the panel a beat to receive the drop before it disappears.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { LensPanel.shared.dismissIfIdle() }
    }
}
