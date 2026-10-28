import Foundation

/// Archives via the system's own ditto/bsdtar, so no third-party code is needed.
enum ArchiveEngine {
    static func zip(_ urls: [URL]) async throws -> URL {
        let ditto = URL(fileURLWithPath: "/usr/bin/ditto")
        if urls.count == 1 {
            let out = OutputNaming.url(nextTo: urls[0], ext: urls[0].pathExtension.isEmpty ? "zip" : urls[0].pathExtension + ".zip")
            try await Shell.run(ditto, ["-c", "-k", "--norsrc", "--keepParent", urls[0].path, out.path])
            return out
        }
        // Several items: stage them as hard copies in a temp folder so the archive has one root.
        let staging = FileManager.default.temporaryDirectory.appendingPathComponent("Optics-" + UUID().uuidString)
        let root = staging.appendingPathComponent("Archive")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: staging) }
        for u in urls { try FileManager.default.copyItem(at: u, to: root.appendingPathComponent(u.lastPathComponent)) }
        let out = OutputNaming.unique(in: urls[0].deletingLastPathComponent(), base: "Archive", ext: "zip")
        try await Shell.run(ditto, ["-c", "-k", "--norsrc", "--keepParent", root.path, out.path])
        return out
    }

    static func extract(_ url: URL) async throws -> URL {
        let folder = try OutputNaming.folder(nextTo: url, suffix: "")
        let ext = url.pathExtension.lowercased()
        do {
            if ext == "zip" {
                try await Shell.run(URL(fileURLWithPath: "/usr/bin/ditto"), ["-x", "-k", url.path, folder.path])
            } else {
                // bsdtar handles tar/gz/bz2/xz/7z and RAR4/RAR5 (read-only).
                try await Shell.run(URL(fileURLWithPath: "/usr/bin/tar"), ["-xf", url.path, "-C", folder.path])
            }
        } catch {
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
        return folder
    }
}
