import AppKit
import Observation
import SwiftUI

struct LensItem: Identifiable {
    let id: String
    let label: String
    let symbol: String
    let perform: ([URL]) -> Void
}

@MainActor
@Observable
final class LensModel {
    var mode: LensMode = .convert
    var title = ""
    var items: [LensItem] = []
    var hovered: Int?
    var emptyMessage: String?
}

/// The radial picker. A transparent, non-activating panel centered on the cursor that
/// accepts the file drop itself; the drop location's angle picks the segment.
@MainActor
final class LensPanel {
    static let shared = LensPanel()
    static let diameter: CGFloat = 380
    static let innerRadius: CGFloat = 58

    let model = LensModel()
    private lazy var panel: NSPanel = makePanel()
    private var droppedRecently = false

    private func makePanel() -> NSPanel {
        let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: Self.diameter, height: Self.diameter),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.level = .popUpMenu
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        p.hidesOnDeactivate = false
        let drop = LensDropView(frame: p.contentRect(forFrameRect: p.frame))
        drop.owner = self
        let host = NSHostingView(rootView: LensView(model: model))
        host.frame = drop.bounds
        host.autoresizingMask = [.width, .height]
        drop.addSubview(host)
        p.contentView = drop
        return p
    }

    func present(mode: LensMode, files: [URL], at point: NSPoint) {
        model.mode = mode
        model.hovered = nil
        configure(mode: mode, files: files)
        let d = Self.diameter
        var origin = NSPoint(x: point.x - d / 2, y: point.y - d / 2)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) {
            let f = screen.visibleFrame
            origin.x = min(max(origin.x, f.minX), f.maxX - d)
            origin.y = min(max(origin.y, f.minY), f.maxY - d)
        }
        panel.setFrameOrigin(origin)
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        Feedback.tick()
    }

    private func configure(mode: LensMode, files: [URL]) {
        let kind = FileKind.common(files)
        model.emptyMessage = nil
        switch mode {
        case .convert:
            model.title = "Convert"
            let formats = kind.map(OutputFormat.targets) ?? [.zip]
            model.items = formats.map { f in
                LensItem(id: f.rawValue, label: f.label, symbol: f.symbol, perform: { JobCenter.shared.convert($0, to: f) })
            }
            if formats.isEmpty { model.emptyMessage = "Nothing to convert to" }
        case .tools:
            model.title = "Tools"
            let tools = kind.map { Tool.tools(for: $0, count: files.count) } ?? [.zipFiles]
            model.items = tools.map { t in
                LensItem(id: t.rawValue, label: t.label, symbol: t.symbol, perform: { JobCenter.shared.run(t, on: $0) })
            }
            if tools.isEmpty { model.emptyMessage = "No tools for these files" }
        case .actions:
            model.title = "Actions"
            model.items = FileAction.allCases.map { a in
                LensItem(id: a.rawValue, label: a.label, symbol: a.symbol, perform: { Actions.perform(a, on: $0) })
            }
        }
    }

    func dismiss() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated { self?.panel.orderOut(nil) }
        })
    }

    func dismissIfIdle() {
        guard panel.isVisible, !droppedRecently else { droppedRecently = false; return }
        dismiss()
    }

    // MARK: Hit testing (view coordinates, origin bottom-left)

    func segment(at point: NSPoint) -> Int? {
        let n = model.items.count
        guard n > 0 else { return nil }
        let c = Self.diameter / 2
        let dx = point.x - c, dy = point.y - c
        let r = hypot(dx, dy)
        guard r > Self.innerRadius, r < c else { return nil }
        // 0 at twelve o'clock, increasing clockwise.
        var angle = atan2(dx, dy)
        if angle < 0 { angle += 2 * .pi }
        let slice = 2 * .pi / CGFloat(n)
        return Int((angle + slice / 2) / slice) % n
    }

    func hover(_ index: Int?) {
        guard index != model.hovered else { return }
        model.hovered = index
        if index != nil { NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now) }
    }

    func drop(_ urls: [URL], at point: NSPoint) -> Bool {
        droppedRecently = true
        defer { dismiss() }
        guard let i = segment(at: point), model.items.indices.contains(i) else { return false }
        model.items[i].perform(urls)
        return true
    }
}

/// AppKit drop target under the SwiftUI drawing.
final class LensDropView: NSView {
    weak var owner: LensPanel?

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }
    required init?(coder: NSCoder) { fatalError() }

    private func local(_ info: NSDraggingInfo) -> NSPoint { convert(info.draggingLocation, from: nil) }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { draggingUpdated(sender) }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        MainActor.assumeIsolated {
            let i = owner?.segment(at: local(sender))
            owner?.hover(i)
            return i == nil ? [] : .copy
        }
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        MainActor.assumeIsolated { owner?.hover(nil) }
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        guard !urls.isEmpty else { return false }
        return MainActor.assumeIsolated { owner?.drop(urls, at: local(sender)) ?? false }
    }
}
