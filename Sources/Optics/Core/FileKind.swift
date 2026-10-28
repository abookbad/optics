import Foundation
import UniformTypeIdentifiers

/// Broad family a dropped file belongs to. Everything Optics offers is keyed off this.
enum FileKind: String, CaseIterable {
    case image, video, audio, pdf, document, archive, folder, other

    static func of(_ url: URL) -> FileKind {
        if url.hasDirectoryPath { return .folder }
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            // Packages such as .pages/.key/.numbers are directories on disk but documents to the user.
            if ["pages", "key", "numbers", "rtfd"].contains(url.pathExtension.lowercased()) { return .document }
            return .folder
        }
        let ext = url.pathExtension.lowercased()
        if ["zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "xz"].contains(ext) { return .archive }
        guard let type = UTType(filenameExtension: ext) else { return .other }
        if type.conforms(to: .pdf) { return .pdf }
        if type.conforms(to: .image) { return .image }
        if type.conforms(to: .movie) || type.conforms(to: .video) { return .video }
        if type.conforms(to: .audio) { return .audio }
        if ["docx", "doc", "rtf", "rtfd", "odt", "txt", "md", "markdown", "html", "htm", "webarchive"].contains(ext)
            || type.conforms(to: .text) {
            return .document
        }
        return .other
    }

    /// The single kind shared by every URL, or nil when the selection is mixed.
    static func common(_ urls: [URL]) -> FileKind? {
        let kinds = Set(urls.map(FileKind.of))
        return kinds.count == 1 ? kinds.first : nil
    }

    var symbol: String {
        switch self {
        case .image: "photo"
        case .video: "film"
        case .audio: "waveform"
        case .pdf: "doc.richtext"
        case .document: "doc.text"
        case .archive: "archivebox"
        case .folder: "folder"
        case .other: "doc"
        }
    }
}
