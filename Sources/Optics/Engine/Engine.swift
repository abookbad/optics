import AppKit

/// What a finished job produced.
enum JobOutput {
    case files([URL])
    case text(String, title: String)
}

/// Routes a lens choice to the engine that does the work.
enum Engine {
    static func convert(_ urls: [URL], to format: OutputFormat) async throws -> JobOutput {
        if format == .zip { return .files([try await ArchiveEngine.zip(urls)]) }
        var outputs: [URL] = []
        for url in urls {
            switch FileKind.of(url) {
            case .image:
                outputs += try await ImageEngine.convert(url, to: format)
            case .video, .audio:
                outputs.append(try await MediaEngine.convert(url, to: format))
            case .pdf where format == .png || format == .jpg:
                outputs.append(try PDFEngine.pagesToImages(url, type: format == .png ? .png : .jpeg))
            case .pdf, .document:
                outputs.append(try DocumentEngine.convert(url, to: format))
            default:
                throw OpticsError("\(url.lastPathComponent) can't be converted to \(format.label).")
            }
        }
        return .files(outputs)
    }

    static func run(_ tool: Tool, on urls: [URL]) async throws -> JobOutput {
        func each(_ op: (URL) async throws -> URL) async throws -> JobOutput {
            var out: [URL] = []
            for u in urls { out.append(try await op(u)) }
            return .files(out)
        }
        switch tool {
        case .compressImage: return try await each(ImageEngine.compress)
        case .resizeImage: return try await each(ImageEngine.resize)
        case .rotateImage: return try await each(ImageEngine.rotate)
        case .removeBackground: return try await each(ImageEngine.removeBackground)
        case .stripMetadata:
            return try await each { url in
                FileKind.of(url) == .image ? try ImageEngine.stripMetadata(url) : try await MediaEngine.stripMetadata(url)
            }
        case .readQRCode:
            let codes = try ImageEngine.readQRCodes(urls)
            guard !codes.isEmpty else { throw OpticsError("No QR codes found.") }
            return .text(codes.joined(separator: "\n"), title: codes.count == 1 ? "QR Code" : "\(codes.count) QR Codes")
        case .makeCollage: return .files([try ImageEngine.collage(urls)])
        case .imagesToPDF: return .files(try PDFEngine.imagesToPDF(urls))
        case .compressVideo: return try await each(MediaEngine.compressVideo)
        case .muteVideo: return try await each(MediaEngine.mute)
        case .extractAudio: return try await each(MediaEngine.extractAudio)
        case .speedUpVideo: return try await each { try await MediaEngine.changeSpeed($0, factor: 2) }
        case .slowDownVideo: return try await each { try await MediaEngine.changeSpeed($0, factor: 0.5) }
        case .joinVideos: return .files([try await MediaEngine.join(urls)])
        case .snapshotVideo: return try await each { try await MediaEngine.snapshots($0) }
        case .normalizeAudio: return try await each(MediaEngine.normalize)
        case .trimSilence: return try await each(MediaEngine.trimSilence)
        case .monoAudio: return try await each(MediaEngine.mono)
        case .waveformVideo: return try await each { try await MediaEngine.waveformVideo($0) }
        case .mergePDFs: return .files([try PDFEngine.merge(urls)])
        case .splitPDF: return try await each(PDFEngine.split)
        case .compressPDF: return try await each(PDFEngine.compress)
        case .pdfToImages: return try await each { try PDFEngine.pagesToImages($0) }
        case .extractPDFText:
            let text = try urls.map(PDFEngine.text).joined(separator: "\n\n")
            return .text(text, title: "Text from \(urls.count == 1 ? urls[0].lastPathComponent : "\(urls.count) PDFs")")
        case .extractArchive: return try await each(ArchiveEngine.extract)
        case .zipFiles: return .files([try await ArchiveEngine.zip(urls)])
        }
    }
}
