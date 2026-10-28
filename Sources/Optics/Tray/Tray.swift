import AppKit
import Observation
import QuickLookThumbnailing
import SwiftUI

/// A Tray is a small floating shelf: park files in it while you move between apps,
/// then drag them (all or one) wherever they need to go. Nothing is copied; a Tray
/// only holds references.
@MainActor
@Observable
final class TrayModel {
    var files: [URL] = []
    var selection: Set<URL> = []

    func add(_ urls: [URL]) {
        for u in urls where !files.contains(u) { files.append(u) }
    }
}

@MainActor
final class TrayController: NSObject, NSWindowDelegate {
    private static var open: [TrayController] = []

    let model = TrayModel()
    private let panel: NSPanel

    static func open(with urls: [URL]) {
        let c = TrayController()
        c.model.add(urls)
        open.append(c)
        c.show()
    }

    static var count: Int { open.count }

    private override init() {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 240, height: 300),
                        styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .utilityWindow, .fullSizeContentView],
                        backing: .buffered, defer: false)
        super.init()
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: TrayView(model: model, close: { [weak self] in self?.panel.close() }))
    }

    private func show() {
        let p = NSEvent.mouseLocation
        let offset = CGFloat(Self.open.count - 1) * 24
        panel.setFrameTopLeftPoint(NSPoint(x: p.x + 24 + offset, y: p.y + 120 - offset))
        panel.orderFrontRegardless()
    }

    func windowWillClose(_ notification: Notification) {
        Self.open.removeAll { $0 === self }
    }
}

struct TrayView: View {
    @Bindable var model: TrayModel
    let close: () -> Void
    @State private var targeted = false

    private var active: [URL] { model.selection.isEmpty ? model.files : model.files.filter(model.selection.contains) }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "tray.full").foregroundStyle(.secondary)
                Text(model.files.count == 1 ? "1 item" : "\(model.files.count) items")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Spacer()
                Menu {
                    menuContents
                } label: { Image(systemName: "ellipsis.circle") }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .disabled(model.files.isEmpty)
            }
            .padding(.top, 26)

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 8)], spacing: 8) {
                    ForEach(model.files, id: \.self) { url in
                        TrayTile(url: url, selected: model.selection.contains(url))
                            .onTapGesture {
                                if model.selection.contains(url) { model.selection.remove(url) } else { model.selection.insert(url) }
                            }
                            .onTapGesture(count: 2) { NSWorkspace.shared.open(url) }
                            .draggable(url)
                            .contextMenu {
                                Button("Open") { NSWorkspace.shared.open(url) }
                                Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                                Divider()
                                Button("Remove from Tray") { model.files.removeAll { $0 == url }; model.selection.remove(url) }
                            }
                    }
                }
                .padding(2)
            }
            .overlay {
                if model.files.isEmpty {
                    Text("Drop files here").font(.callout).foregroundStyle(.secondary)
                }
            }

            if model.files.count > 1 {
                AllItemsHandle(urls: active)
            }
        }
        .padding(.horizontal, 10).padding(.bottom, 10)
        .frame(minWidth: 200, minHeight: 200)
        .background(targeted ? Color.accentColor.opacity(0.12) : .clear)
        .dropDestination(for: URL.self) { urls, _ in
            model.add(urls.filter(\.isFileURL))
            return true
        } isTargeted: { targeted = $0 }
    }

    @ViewBuilder private var menuContents: some View {
        let files = active
        if let kind = FileKind.common(files) {
            Menu("Convert") {
                ForEach(OutputFormat.targets(for: kind)) { f in
                    Button(f.label) { JobCenter.shared.convert(files, to: f) }
                }
            }
            Menu("Tools") {
                ForEach(Tool.tools(for: kind, count: files.count)) { t in
                    Button(t.label) { JobCenter.shared.run(t, on: files) }
                }
            }
        }
        ForEach(FileAction.allCases.filter { $0 != .newTray }) { a in
            Button(a.label) { Actions.perform(a, on: files) }
        }
        Divider()
        Button("Clear Selection") { model.selection.removeAll() }.disabled(model.selection.isEmpty)
        Button("Close Tray", action: close)
    }
}

/// One handle that drags every (selected) item at once.
private struct AllItemsHandle: View {
    let urls: [URL]

    var body: some View {
        Label("Drag \(urls.count) items", systemImage: "square.stack.3d.up")
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(.quaternary, in: Capsule())
            .onDrag {
                // NSItemProvider carries one file; Finder accepts the first, so register all.
                let provider = NSItemProvider()
                for u in urls {
                    provider.registerFileRepresentation(forTypeIdentifier: UTType.fileURL.identifier, fileOptions: [], visibility: .all) { done in
                        done(u, false, nil); return nil
                    }
                }
                return provider
            }
            .help("Drag to carry all files")
    }
}

private struct TrayTile: View {
    let url: URL
    let selected: Bool
    @State private var thumbnail: NSImage?

    var body: some View {
        VStack(spacing: 4) {
            Group {
                if let thumbnail { Image(nsImage: thumbnail).resizable().scaledToFit() }
                else { Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().scaledToFit() }
            }
            .frame(width: 56, height: 56)
            Text(url.lastPathComponent)
                .font(.system(size: 10))
                .lineLimit(2).multilineTextAlignment(.center)
                .truncationMode(.middle)
        }
        .padding(6)
        .frame(width: 84)
        .background(selected ? Color.accentColor.opacity(0.25) : Color.primary.opacity(0.04),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .task(id: url) {
            let req = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: 112, height: 112),
                                                   scale: NSScreen.main?.backingScaleFactor ?? 2, representationTypes: .thumbnail)
            if let rep = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: req) {
                thumbnail = rep.nsImage
            }
        }
    }
}
