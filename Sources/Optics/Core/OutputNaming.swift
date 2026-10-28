import Foundation

enum OutputNaming {
    /// `<dir>/<base><suffix>.<ext>`, bumping to "<base><suffix> 2.<ext>" etc. if taken.
    static func url(nextTo source: URL, suffix: String = "", ext: String) -> URL {
        let dir = source.deletingLastPathComponent()
        let base = source.deletingPathExtension().lastPathComponent + suffix
        return unique(in: dir, base: base, ext: ext)
    }

    static func unique(in dir: URL, base: String, ext: String) -> URL {
        let fm = FileManager.default
        func make(_ n: Int) -> URL {
            let name = n == 1 ? base : "\(base) \(n)"
            return ext.isEmpty ? dir.appendingPathComponent(name) : dir.appendingPathComponent(name).appendingPathExtension(ext)
        }
        var n = 1
        while fm.fileExists(atPath: make(n).path) { n += 1 }
        return make(n)
    }

    /// A fresh folder next to `source`, for tools that emit many files.
    static func folder(nextTo source: URL, suffix: String) throws -> URL {
        let url = unique(in: source.deletingLastPathComponent(),
                         base: source.deletingPathExtension().lastPathComponent + suffix, ext: "")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

struct OpticsError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
