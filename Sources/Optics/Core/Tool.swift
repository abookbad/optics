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
        case .stripMetadata: "Metadata"
        case .readQRCode: "QR Code"
        case .makeCollage: "Collage"
        case .imagesToPDF: "PDF"
        case .rotateImage: "Rotate"
        case .muteVideo: "Mute"
        case .extractAudio: "Audio"
        case .speedUpVideo: "2× Speed"
        case .slowDownVideo: "½× Speed"
        case .joinVideos: "Join"
        case .snapshotVideo: "Snapshots"
        case .normalizeAudio: "Normalize"
        case .trimSilence: "Trim Silence"
        case .monoAudio: "Mono"
        case .waveformVideo: "Waveform"
        case .mergePDFs: "Merge"
        case .splitPDF: "Split"
        case .pdfToImages: "Images"
        case .extractPDFText: "Text"
        case .extractArchive: "Extract"
        case .zipFiles: "Zip"
        }
    }

    var symbol: String {
        switch self {
        case .compressImage, .compressVideo, .compressPDF: "arrow.down.forward.and.arrow.up.backward"
        case .resizeImage: "arrow.up.left.and.arrow.down.right"
        case .removeBackground: "person.crop.rectangle"
        case .stripMetadata: "tag"
        case .readQRCode: "qrcode.viewfinder"
        case .makeCollage: "square.grid.2x2"
        case .imagesToPDF: "doc.richtext"
        case .mergePDFs: "doc.on.doc"
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
        case .joinVideos, .mergePDFs, .makeCollage: 2
        default: 1
        }
    }

    static func tools(for kind: FileKind, count: Int) -> [Tool] {
        let all: [Tool]
        switch kind {
        case .image: all = [.compressImage, .stripMetadata, .resizeImage, .rotateImage, .removeBackground, .readQRCode, .imagesToPDF, .makeCollage]
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

    /// Clockwise from twelve o'clock on the Actions wheel.
    static let wheel: [FileAction] = [.airDrop, .newTray, .copyTo, .moveTo, .copyPaths, .openTerminal]

    var label: String {
        switch self {
        case .newTray: "Float"
        case .copyPaths: "Copy Path"
        case .moveTo: "Move"
        case .copyTo: "Copy"
        case .airDrop: "AirDrop"
        case .openTerminal: "Terminal"
        case .revealInFinder: "Reveal"
        }
    }

    var symbol: String {
        switch self {
        case .newTray: "pin.fill"
        case .copyPaths: "doc.text"
        case .moveTo: "folder"
        case .copyTo: "doc.on.doc"
        case .airDrop: AirDropGlyph.name
        case .openTerminal: "apple.terminal"
        case .revealInFinder: "magnifyingglass"
        }
    }
}
