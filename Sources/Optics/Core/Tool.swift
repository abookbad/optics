import Foundation

/// One-shot operations on the Tools lens. Each works on the dropped files and writes
/// new files next to the originals; nothing is modified in place.
enum Tool: String, CaseIterable, Identifiable {
    // Images
    case compressImage, resizeImage, removeBackground, stripMetadata, readQRCode, makeCollage, imagesToPDF, rotateImage
    // Video
    case compressVideo, muteVideo, extractAudio, speedUpVideo, slowDownVideo, joinVideos, snapshotVideo
    // Audio
    case normalizeAudio, trimSilence, monoAudio, waveformVideo
    // PDF
    case mergePDFs, splitPDF, compressPDF, pdfToImages, extractPDFText
    // Archives & any file
    case extractArchive, zipFiles

    var id: String { rawValue }

    var label: String {
        switch self {
        case .compressImage, .compressVideo, .compressPDF: "Compress"
        case .resizeImage: "Resize"
        case .removeBackground: "Cut Out"
        case .stripMetadata: "Strip Metadata"
        case .readQRCode: "Read QR"
        case .makeCollage: "Collage"
        case .imagesToPDF: "To One PDF"
        case .rotateImage: "Rotate"
        case .muteVideo: "Mute"
        case .extractAudio: "Audio Only"
        case .speedUpVideo: "2× Speed"
        case .slowDownVideo: "½× Speed"
        case .joinVideos: "Join"
        case .snapshotVideo: "Snapshots"
        case .normalizeAudio: "Normalize"
        case .trimSilence: "Trim Silence"
        case .monoAudio: "Mono"
        case .waveformVideo: "Waveform Video"
        case .mergePDFs: "Merge"
        case .splitPDF: "Split Pages"
        case .pdfToImages: "Pages to PNG"
        case .extractPDFText: "Extract Text"
        case .extractArchive: "Extract"
        case .zipFiles: "Zip"
        }
    }

    var symbol: String {
        switch self {
        case .compressImage, .compressVideo, .compressPDF: "arrow.down.right.and.arrow.up.left"
        case .resizeImage: "arrow.up.left.and.down.right.magnifyingglass"
        case .removeBackground: "person.crop.rectangle"
        case .stripMetadata: "eye.slash"
        case .readQRCode: "qrcode.viewfinder"
        case .makeCollage: "square.grid.2x2"
        case .imagesToPDF, .mergePDFs: "doc.on.doc"
        case .rotateImage: "rotate.right"
        case .muteVideo: "speaker.slash"
        case .extractAudio: "music.note"
        case .speedUpVideo: "hare"
        case .slowDownVideo: "tortoise"
        case .joinVideos: "film.stack"
        case .snapshotVideo: "camera"
        case .normalizeAudio: "slider.horizontal.3"
        case .trimSilence: "scissors"
        case .monoAudio: "speaker.wave.1"
        case .waveformVideo: "waveform.path"
        case .splitPDF: "square.split.2x1"
        case .pdfToImages: "photo.on.rectangle"
        case .extractPDFText: "text.quote"
        case .extractArchive: "archivebox"
        case .zipFiles: "doc.zipper"
        }
    }

    /// Tools that need more than one file to make sense.
    var minimumFiles: Int {
        switch self {
        case .joinVideos, .mergePDFs: 2
        default: 1
        }
    }

    static func tools(for kind: FileKind, count: Int) -> [Tool] {
        let all: [Tool]
        switch kind {
        case .image: all = [.compressImage, .resizeImage, .removeBackground, .stripMetadata, .readQRCode, .makeCollage, .imagesToPDF, .rotateImage]
        case .video: all = [.compressVideo, .muteVideo, .extractAudio, .speedUpVideo, .slowDownVideo, .joinVideos, .snapshotVideo, .stripMetadata]
        case .audio: all = [.normalizeAudio, .trimSilence, .monoAudio, .waveformVideo, .stripMetadata]
        case .pdf: all = [.mergePDFs, .splitPDF, .compressPDF, .pdfToImages, .extractPDFText]
        case .archive: all = [.extractArchive]
        case .document, .folder, .other: all = [.zipFiles]
        }
        return all.filter { count >= $0.minimumFiles }
    }
}

/// File actions on the Actions lens: things you do *with* files rather than *to* them.
enum FileAction: String, CaseIterable, Identifiable {
    case newTray, copyPaths, moveTo, copyTo, airDrop, openTerminal, revealInFinder

    var id: String { rawValue }

    var label: String {
        switch self {
        case .newTray: "New Tray"
        case .copyPaths: "Copy Paths"
        case .moveTo: "Move To…"
        case .copyTo: "Copy To…"
        case .airDrop: "AirDrop"
        case .openTerminal: "Terminal"
        case .revealInFinder: "Reveal"
        }
    }

    var symbol: String {
        switch self {
        case .newTray: "tray.and.arrow.down"
        case .copyPaths: "link"
        case .moveTo: "folder.badge.plus"
        case .copyTo: "plus.square.on.square"
        case .airDrop: "airplayaudio"
        case .openTerminal: "terminal"
        case .revealInFinder: "magnifyingglass"
        }
    }
}
