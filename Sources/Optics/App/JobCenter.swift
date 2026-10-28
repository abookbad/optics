import AppKit
import Observation

struct JobRecord: Identifiable {
    enum State { case running, done, failed(String) }
    let id = UUID()
    let title: String
    let started = Date()
    var state: State = .running
    var outputs: [URL] = []
}

/// Runs jobs off the main thread and keeps a short history for the menu.
@MainActor
@Observable
final class JobCenter {
    static let shared = JobCenter()
    private(set) var records: [JobRecord] = []

    var isBusy: Bool { records.contains { if case .running = $0.state { true } else { false } } }

    func convert(_ urls: [URL], to format: OutputFormat) {
        let name = urls.count == 1 ? urls[0].lastPathComponent : "\(urls.count) files"
        start("\(name) → \(format.label)") { try await Engine.convert(urls, to: format) }
    }

    func run(_ tool: Tool, on urls: [URL]) {
        let name = urls.count == 1 ? urls[0].lastPathComponent : "\(urls.count) files"
        start("\(tool.label) · \(name)") { try await Engine.run(tool, on: urls) }
    }

    private func start(_ title: String, _ work: @escaping @Sendable () async throws -> JobOutput) {
        let record = JobRecord(title: title)
        records.insert(record, at: 0)
        if records.count > 30 { records.removeLast(records.count - 30) }
        Task.detached(priority: .userInitiated) {
            do {
                let output = try await work()
                await self.finish(record.id, output: output)
            } catch {
                await self.fail(record.id, message: error.localizedDescription)
            }
        }
    }

    private func finish(_ id: UUID, output: JobOutput) {
        guard let i = records.firstIndex(where: { $0.id == id }) else { return }
        records[i].state = .done
        switch output {
        case .files(let urls):
            records[i].outputs = urls
            if Prefs.revealOutput, !urls.isEmpty { NSWorkspace.shared.activateFileViewerSelecting(urls) }
            Feedback.success()
            Toast.show("Done", detail: urls.count == 1 ? urls[0].lastPathComponent : "\(urls.count) files created")
        case .text(let text, let title):
            Feedback.success()
            TextResultWindow.show(title: title, text: text)
        }
    }

    private func fail(_ id: UUID, message: String) {
        guard let i = records.firstIndex(where: { $0.id == id }) else { return }
        records[i].state = .failed(message)
        Feedback.failure()
        Toast.show("Couldn't finish", detail: message, isError: true)
    }

    func clear() { records.removeAll { if case .running = $0.state { false } else { true } } }
}

enum Feedback {
    static func success() {
        guard Prefs.playSounds else { return }
        NSSound(named: "Glass")?.play()
    }
    static func failure() {
        guard Prefs.playSounds else { return }
        NSSound(named: "Basso")?.play()
    }
    /// Soft tick + haptic as the drag crosses onto a new petal.
    static func highlight() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        guard Prefs.playSounds, let sound = highlightSound else { return }
        sound.stop()
        sound.play()
    }

    private static let highlightSound: NSSound? = {
        let s = NSSound(named: "Tink")?.copy() as? NSSound
        s?.volume = 0.25
        return s
    }()
}
