import ServiceManagement
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralTab().tabItem { Label("General", systemImage: "gearshape") }
            OutputTab().tabItem { Label("Output", systemImage: "slider.horizontal.3") }
            HelpersTab().tabItem { Label("Helpers", systemImage: "wrench.and.screwdriver") }
        }
        .frame(width: 460, height: 340)
    }
}

private struct GeneralTab: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @AppStorage("playSounds") private var playSounds = true
    @AppStorage("revealOutput") private var revealOutput = false

    var body: some View {
        Form {
            Section("Lens shortcuts — hold while dragging files") {
                ForEach(LensMode.allCases) { ModifierRow(mode: $0) }
            }
            Section {
                Toggle("Open at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in
                        do { on ? try SMAppService.mainApp.register() : try SMAppService.mainApp.unregister() }
                        catch { launchAtLogin = SMAppService.mainApp.status == .enabled }
                    }
                Toggle("Sounds and haptics", isOn: $playSounds)
                Toggle("Reveal results in Finder", isOn: $revealOutput)
            }
        }
        .formStyle(.grouped)
    }
}

private struct ModifierRow: View {
    let mode: LensMode
    @State private var flags: NSEvent.ModifierFlags

    init(mode: LensMode) {
        self.mode = mode
        _flags = State(initialValue: Prefs.modifiers(for: mode))
    }

    private static let choices: [NSEvent.ModifierFlags] = [
        .option, .control, .command, .shift, [.control, .option], [.option, .command], [.control, .command], [.option, .shift],
    ]

    var body: some View {
        Picker(mode.title, selection: Binding(get: { flags.rawValue }, set: {
            flags = NSEvent.ModifierFlags(rawValue: $0)
            Prefs.setModifiers(flags, for: mode)
        })) {
            ForEach(Self.choices, id: \.rawValue) { Text($0.glyphs).tag($0.rawValue) }
        }
    }
}

private struct OutputTab: View {
    @AppStorage("imageQuality") private var imageQuality = 0.72
    @AppStorage("resizeMaxEdge") private var resizeMaxEdge = 1920
    @AppStorage("videoCRF") private var videoCRF = 28
    @AppStorage("gifFPS") private var gifFPS = 15
    @AppStorage("gifWidth") private var gifWidth = 640

    var body: some View {
        Form {
            Section("Images") {
                LabeledContent("Compression quality") {
                    Slider(value: $imageQuality, in: 0.3...0.95) { Text("\(Int(imageQuality * 100))%") }
                }
                Picker("Resize longest edge", selection: $resizeMaxEdge) {
                    ForEach([640, 1080, 1280, 1920, 2560, 3840], id: \.self) { Text("\($0) px").tag($0) }
                }
            }
            Section("Video") {
                Picker("Compression", selection: $videoCRF) {
                    Text("Light").tag(23); Text("Balanced").tag(28); Text("Strong").tag(32)
                }
                Stepper("GIF frame rate: \(gifFPS) fps", value: $gifFPS, in: 5...30)
                Picker("GIF width", selection: $gifWidth) {
                    ForEach([320, 480, 640, 800, 1080], id: \.self) { Text("\($0) px").tag($0) }
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct HelpersTab: View {
    var body: some View {
        Form {
            Section {
                helper("ffmpeg", Shell.ffmpeg, note: "Video, audio, GIF and AVIF. Install with `brew install ffmpeg`.")
                helper("cwebp", Shell.cwebp, note: "Sharper WebP output. Optional; ffmpeg is used as a fallback.")
            } footer: {
                Text("Images, PDFs, documents, QR codes, background removal and archives use built-in macOS frameworks.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func helper(_ name: String, _ url: URL?, note: String) -> some View {
        HStack(alignment: .top) {
            Image(systemName: url == nil ? "xmark.circle" : "checkmark.circle.fill")
                .foregroundStyle(url == nil ? Color.orange : Color.green)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(.body, design: .monospaced))
                Text(url?.path ?? "Not found").font(.caption).foregroundStyle(.secondary)
                Text(.init(note)).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
