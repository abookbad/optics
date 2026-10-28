import SwiftUI

/// The menu bar window: a drop well (for when you'd rather not use modifier-drag),
/// the job history, and shortcuts to Settings.
struct MenuView: View {
    @State private var jobs = JobCenter.shared
    @State private var staged: [URL] = []
    @State private var targeted = false
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if staged.isEmpty { dropWell } else { StagedActions(files: staged, clear: { staged = [] }) }
            if !jobs.records.isEmpty { history }
            footer
        }
        .padding(14)
        .frame(width: 340)
    }

    private var header: some View {
        HStack(spacing: 8) {
            OpticsMark().frame(width: 22, height: 22)
            Text("Optics").font(.system(size: 15, weight: .bold, design: .rounded))
            Spacer()
            if jobs.isBusy { ProgressView().controlSize(.small) }
        }
    }

    private var dropWell: some View {
        VStack(spacing: 6) {
            Image(systemName: "arrow.down.circle").font(.system(size: 26, weight: .light))
            Text("Drop files here").font(.system(size: 13, weight: .semibold))
            Text("or hold \(Prefs.modifiers(for: .convert).glyphs) while dragging files anywhere")
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 110)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            .foregroundStyle(targeted ? Color.accentColor : Color.secondary.opacity(0.4)))
        .background(targeted ? Color.accentColor.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 12))
        .dropDestination(for: URL.self) { urls, _ in
            staged = urls.filter(\.isFileURL)
            return !staged.isEmpty
        } isTargeted: { targeted = $0 }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Recent").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                Button("Clear") { jobs.clear() }.buttonStyle(.link).font(.system(size: 11))
            }
            ForEach(jobs.records.prefix(6)) { r in
                HStack(spacing: 8) {
                    switch r.state {
                    case .running: ProgressView().controlSize(.mini)
                    case .done: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    case .failed: Image(systemName: "xmark.octagon.fill").foregroundStyle(.orange)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(r.title).font(.system(size: 12)).lineLimit(1).truncationMode(.middle)
                        if case .failed(let msg) = r.state {
                            Text(msg).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(2)
                        }
                    }
                    Spacer()
                    if !r.outputs.isEmpty {
                        Button { NSWorkspace.shared.activateFileViewerSelecting(r.outputs) } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        .buttonStyle(.borderless).help("Show in Finder")
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("New Tray") { TrayController.open(with: []) }
            Spacer()
            Button("Settings…") { NSApp.activate(ignoringOtherApps: true); openSettings() }
            Button("Quit") { NSApp.terminate(nil) }
        }
        .buttonStyle(.borderless)
        .font(.system(size: 12))
    }
}

/// After a drop on the menu well: pick a conversion, tool or action.
private struct StagedActions: View {
    let files: [URL]
    let clear: () -> Void
    @State private var mode: LensMode = .convert

    private var kind: FileKind? { FileKind.common(files) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: kind?.symbol ?? "doc.on.doc")
                Text(files.count == 1 ? files[0].lastPathComponent : "\(files.count) files")
                    .font(.system(size: 12, weight: .semibold)).lineLimit(1).truncationMode(.middle)
                Spacer()
                Button(action: clear) { Image(systemName: "xmark.circle.fill") }.buttonStyle(.borderless)
            }
            Picker("", selection: $mode) {
                ForEach(LensMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden()

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                switch mode {
                case .convert:
                    ForEach(kind.map(OutputFormat.targets) ?? [.zip]) { f in
                        chip(f.label, f.symbol) { JobCenter.shared.convert(files, to: f) }
                    }
                case .tools:
                    ForEach(kind.map { Tool.tools(for: $0, count: files.count) } ?? [.zipFiles]) { t in
                        chip(t.label, t.symbol) { JobCenter.shared.run(t, on: files) }
                    }
                case .actions:
                    ForEach(FileAction.allCases) { a in
                        chip(a.label, a.symbol) { Actions.perform(a, on: files) }
                    }
                }
            }
        }
    }

    private func chip(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            clear()
        } label: {
            VStack(spacing: 3) {
                Image(systemName: symbol).font(.system(size: 14))
                Text(title).font(.system(size: 11, weight: .medium)).lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// The Optics mark: two offset rings, a lens catching light.
struct OpticsMark: View {
    var body: some View {
        ZStack {
            Circle().strokeBorder(LinearGradient(colors: [Color(red: 0.36, green: 0.42, blue: 1), Color(red: 0.18, green: 0.77, blue: 1)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 3)
            Circle().fill(LinearGradient(colors: [Color(red: 0.55, green: 0.33, blue: 1), Color(red: 0.93, green: 0.36, blue: 0.86)],
                                         startPoint: .top, endPoint: .bottom))
                .scaleEffect(0.42).offset(x: 3, y: -3)
        }
    }
}
