import Foundation

/// Locates and runs the command-line helpers Optics leans on (ffmpeg, cwebp).
/// Looks inside the app bundle first, then the usual Homebrew prefixes.
enum Shell {
    static func find(_ name: String) -> URL? {
        var candidates: [URL] = []
        if let res = Bundle.main.resourceURL {
            candidates.append(res.appendingPathComponent("bin/\(name)"))
        }
        candidates += ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"].map { URL(fileURLWithPath: $0).appendingPathComponent(name) }
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    static var ffmpeg: URL? { find("ffmpeg") }
    static var cwebp: URL? { find("cwebp") }

    @discardableResult
    static func run(_ executable: URL, _ arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            let process = Process()
            process.executableURL = executable
            process.arguments = arguments
            let out = Pipe()
            process.standardOutput = out
            process.standardError = out
            process.standardInput = FileHandle.nullDevice
            let buffer = OutputBuffer()
            out.fileHandleForReading.readabilityHandler = { handle in
                buffer.append(handle.availableData)
            }
            process.terminationHandler = { p in
                out.fileHandleForReading.readabilityHandler = nil
                buffer.append(out.fileHandleForReading.readDataToEndOfFile())
                let text = buffer.text
                if p.terminationStatus == 0 {
                    cont.resume(returning: text)
                } else {
                    let tail = text.split(separator: "\n").suffix(3).joined(separator: " ")
                    cont.resume(throwing: OpticsError("\(executable.lastPathComponent) failed: \(tail)"))
                }
            }
            do { try process.run() } catch { cont.resume(throwing: error) }
        }
    }

    /// Runs ffmpeg with `-y -hide_banner -loglevel error` prepended.
    @discardableResult
    static func ffmpeg(_ arguments: [String]) async throws -> String {
        guard let bin = ffmpeg else {
            throw OpticsError("ffmpeg isn't installed. Run `brew install ffmpeg`, then try again.")
        }
        return try await run(bin, ["-y", "-hide_banner", "-loglevel", "error"] + arguments)
    }
}

/// Thread-safe accumulator for a child process's combined output.
private final class OutputBuffer: @unchecked Sendable {
    private var data = Data()
    private let lock = NSLock()
    func append(_ chunk: Data) { lock.lock(); data.append(chunk); lock.unlock() }
    var text: String { lock.lock(); defer { lock.unlock() }; return String(decoding: data, as: UTF8.self) }
}
