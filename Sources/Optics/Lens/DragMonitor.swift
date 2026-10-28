import AppKit

/// Watches system-wide mouse drags. When a file drag is under way and the user holds one
/// of the wheel modifiers, the matching wheel opens under the cursor.
///
/// A "file drag" is detected from the shared drag pasteboard: every drag session bumps its
/// changeCount, so a changeCount that moved since mouse-down, carrying file URLs, means
/// files are being dragged right now. While that's true, modifier state is polled as well
/// as observed, because flag changes aren't always delivered to global monitors mid-drag.
@MainActor
final class DragMonitor {
    static let shared = DragMonitor()

    private var monitors: [Any] = []
    private var changeCountAtMouseDown = NSPasteboard(name: .drag).changeCount
    private var draggingFiles: [URL]?
    private var shownMode: LensMode?
    private var poll: Timer?

    func start() {
        guard monitors.isEmpty else { return }
        let handlers: [(NSEvent.EventTypeMask, (NSEvent) -> Void)] = [
            (.leftMouseDown, { [weak self] _ in self?.mouseDown() }),
            (.leftMouseDragged, { [weak self] _ in self?.dragged() }),
            (.flagsChanged, { [weak self] _ in self?.evaluate() }),
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
        reset()
    }

    private func dragged() {
        if draggingFiles == nil {
            let pb = NSPasteboard(name: .drag)
            guard pb.changeCount != changeCountAtMouseDown else { return }
            let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
            guard !urls.isEmpty else { return }
            draggingFiles = urls
            startPolling()
        }
        evaluate()
    }

    private func startPolling() {
        poll?.invalidate()
        poll = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { _ in
            MainActor.assumeIsolated {
                let monitor = DragMonitor.shared
                // Mouse released somewhere we didn't hear about (e.g. dropped onto our own panel).
                if NSEvent.pressedMouseButtons & 1 == 0 { monitor.mouseUp(); return }
                monitor.evaluate()
            }
        }
    }

    private func evaluate() {
        guard let files = draggingFiles else { return }
        let pressed = NSEvent.modifierFlags.intersection(Prefs.relevantModifiers)
        guard !pressed.isEmpty else { return }
        // Exact match so ⌃⇧ doesn't also open the ⇧ wheel. Releasing the key keeps the wheel open.
        guard let mode = LensMode.allCases.first(where: { Prefs.modifiers(for: $0) == pressed }), mode != shownMode else { return }
        shownMode = mode
        LensPanel.shared.present(mode: mode, files: files, at: NSEvent.mouseLocation)
    }

    private func mouseUp() {
        let wasShowing = shownMode != nil
        reset()
        // Give the panel a beat to receive the drop before it disappears.
        if wasShowing { DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { LensPanel.shared.dismissIfIdle() } }
    }

    private func reset() {
        poll?.invalidate()
        poll = nil
        draggingFiles = nil
        shownMode = nil
    }
}
