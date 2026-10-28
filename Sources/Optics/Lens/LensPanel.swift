import AppKit
import Observation
import SwiftUI

struct LensItem: Identifiable {
    let id: String
    let label: String
    /// nil for the Convert wheel, which shows text only.
    let symbol: String?
    let perform: ([URL]) -> Void
}

@MainActor
@Observable
final class LensModel {
    var mode: LensMode = .convert
    var items: [LensItem] = []
    var hovered: Int?
    /// Shown in the center pill when nothing is hovered: total size of the dragged files.
    var summary = ""
    var revealed = false
}

/// The radial picker. A transparent, non-activating panel centered on the cursor that
/// accepts the file drop itself; the drop location's angle picks the petal.
@MainActor
final class LensPanel {
    static let shared = LensPanel()

    let model = LensModel()
    private lazy var panel: NSPanel = makePanel()
    private var droppedRecently = false
    private var hideWork: DispatchWorkItem?

    var isVisible: Bool { panel.isVisible }

    private func makePanel() -> NSPanel {
        let size = LensMetrics.panel
        let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: size, height: size),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.level = .popUpMenu
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        p.hidesOnDeactivate = false
        let drop = LensDropView(frame: NSRect(x: 0, y: 0, width: size, height: size))
        drop.owner = self
        let host = NSHostingView(rootView: LensView(model: model))
        host.frame = drop.bounds
        host.autoresizingMask = [.width, .height]
        drop.addSubview(host)
        p.contentView = drop
        return p
    }

    func present(mode: LensMode, files: [URL], at point: NSPoint) {
        hideWork?.cancel()
        let wasVisible = panel.isVisible && model.revealed
        model.mode = mode
        model.hovered = nil
        model.items = Self.items(for: mode, files: files)
        model.summary = Self.totalSize(files)
        let d = LensMetrics.panel
        var origin = NSPoint(x: point.x - d / 2, y: point.y - d / 2)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) {
            let f = screen.frame
            origin.x = min(max(origin.x, f.minX), f.maxX - d)
            origin.y = min(max(origin.y, f.minY), f.maxY - d)
        }
        if !wasVisible { panel.setFrameOrigin(origin) }
        panel.orderFrontRegardless()
        if !wasVisible {
            model.revealed = false
            DispatchQueue.main.async { self.model.revealed = true }
        }
    }

    func dismiss() {
        model.revealed = false
        model.hovered = nil
        let work = DispatchWorkItem { [weak self] in self?.panel.orderOut(nil) }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
    }

    func dismissIfIdle() {
        guard panel.isVisible, !droppedRecently else { droppedRecently = false; return }
        dismiss()
    }

    // MARK: Items

    static func items(for mode: LensMode, files: [URL]) -> [LensItem] {
        let kind = FileKind.common(files)
        switch mode {
        case .convert:
            let sourceExts = Set(files.map { $0.pathExtension.lowercased() })
            let formats = (kind.map(OutputFormat.targets) ?? [.zip]).filter { f in
                !sourceExts.contains(f.fileExtension) && !(f == .jpg && sourceExts.contains("jpeg"))
            }
            return formats.prefix(8).map { f in
                LensItem(id: f.rawValue, label: f.label, symbol: nil, perform: { JobCenter.shared.convert($0, to: f) })
            }
        case .tools:
            let tools = kind.map { Tool.tools(for: $0, count: files.count) } ?? [.zipFiles]
            return tools.prefix(8).map { t in
                LensItem(id: t.rawValue, label: t.label, symbol: t.symbol, perform: { JobCenter.shared.run(t, on: $0) })
            }
        case .actions:
            return FileAction.wheel.map { a in
                LensItem(id: a.rawValue, label: a.label, symbol: a.symbol, perform: { Actions.perform(a, on: $0) })
            }
        }
    }

    static func totalSize(_ files: [URL]) -> String {
        var total: Int64 = 0
        for url in files {
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .totalFileAllocatedSizeKey, .fileSizeKey])
            if values?.isDirectory == true {
                let e = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey])
                while let f = e?.nextObject() as? URL {
                    total += Int64((try? f.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
                }
            } else {
                total += Int64(values?.fileSize ?? 0)
            }
        }
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowedUnits = [.useKB, .useMB, .useGB]
        return f.string(fromByteCount: total)
    }

    // MARK: Hit testing (view coordinates, origin bottom-left)

    func segment(at point: NSPoint) -> Int? {
        let n = model.items.count
        guard n > 0 else { return nil }
        let c = LensMetrics.panel / 2
        let dx = point.x - c, dy = point.y - c
        let r = hypot(dx, dy)
        // The hole cancels; anywhere on the disc outside it counts, gaps included.
        guard r > LensMetrics.holeRadius, r <= LensMetrics.discRadius + 6 else { return nil }
        var angle = atan2(dx, dy) // 0 at twelve o'clock, clockwise
        if angle < 0 { angle += 2 * .pi }
        let slice = 2 * .pi / CGFloat(n)
        return Int((angle + slice / 2) / slice) % n
    }

    func hover(_ index: Int?) {
        guard index != model.hovered else { return }
        model.hovered = index
        if index != nil { Feedback.highlight() }
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
