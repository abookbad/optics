import Foundation

/// A target format on the Convert lens.
enum OutputFormat: String, CaseIterable, Identifiable {
    // Images
    case jpg, png, heic, webp, tiff, bmp, gif, avif
    // Video
    case mp4, mov, webm, mkv, animatedGIF
    // Audio
    case m4a, mp3, wav, flac, aiff, ogg, opus
    // Documents
    case pdf, docx, rtf, html, txt, odt, markdown
    // Containers
    case zip

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .animatedGIF: "gif"
        case .markdown: "md"
        default: rawValue
        }
    }

    var label: String {
        switch self {
        case .animatedGIF: "GIF"
        case .markdown: "Markdown"
        case .heic: "HEIC"
        default: rawValue.uppercased()
        }
    }

    /// Formats offered for a given input kind, in the order they appear around the lens.
    static func targets(for kind: FileKind) -> [OutputFormat] {
        switch kind {
        case .image: [.jpg, .png, .heic, .webp, .pdf, .tiff, .gif, .avif, .bmp]
        case .video: [.mp4, .mov, .animatedGIF, .webm, .m4a, .mp3, .mkv, .wav]
        case .audio: [.mp3, .m4a, .wav, .flac, .aiff, .ogg, .opus, .mp4]
        case .pdf: [.png, .jpg, .txt, .docx, .rtf, .html, .markdown]
        case .document: [.pdf, .docx, .rtf, .txt, .html, .odt, .markdown]
        case .folder, .other: [.zip]
        case .archive: []
        }
    }
}
