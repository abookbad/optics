import AppKit
import CoreImage
import ImageIO
import UniformTypeIdentifiers
import Vision

enum ImageEngine {
    static func load(_ url: URL) throws -> CGImage {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let img = CGImageSourceCreateImageAtIndex(src, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
        else { throw OpticsError("Couldn't read \(url.lastPathComponent) as an image.") }
        return orientedImage(img, source: src)
    }

    /// Applies the EXIF orientation so outputs look the way Finder shows the original.
    private static func orientedImage(_ img: CGImage, source: CGImageSource) -> CGImage {
        let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let raw = (props?[kCGImagePropertyOrientation] as? UInt32) ?? 1
        guard raw != 1, let orientation = CGImagePropertyOrientation(rawValue: raw) else { return img }
        let ci = CIImage(cgImage: img).oriented(orientation)
        return CIContext().createCGImage(ci, from: ci.extent) ?? img
    }

    static func write(_ image: CGImage, to url: URL, type: UTType, quality: Double? = nil, metadata: CFDictionary? = nil) throws {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil) else {
            throw OpticsError("This Mac can't write \(type.preferredFilenameExtension?.uppercased() ?? "that format").")
        }
        var props: [CFString: Any] = [:]
        if let metadata = metadata as? [CFString: Any] { props.merge(metadata) { a, _ in a } }
        if let quality { props[kCGImageDestinationLossyCompressionQuality] = quality }
        CGImageDestinationAddImage(dest, image, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw OpticsError("Couldn't save \(url.lastPathComponent).") }
    }

    static func convert(_ url: URL, to format: OutputFormat) async throws -> [URL] {
        let out = OutputNaming.url(nextTo: url, ext: format.fileExtension)
        switch format {
        case .webp:
            try await writeWebP(from: url, to: out, quality: Settings.imageQuality)
        case .avif:
            try await Shell.ffmpeg(["-i", url.path, "-c:v", "libaom-av1", "-still-picture", "1", "-crf", "30", out.path])
        case .pdf:
            return try PDFEngine.imagesToPDF([url])
        default:
            let type: UTType = switch format {
            case .jpg: .jpeg
            case .png: .png
            case .heic: .heic
            case .tiff: .tiff
            case .bmp: .bmp
            case .gif: .gif
            default: throw OpticsError("Images can't become \(format.label).")
            }
            var image = try load(url)
            if format == .jpg || format == .bmp { image = flattened(image) }
            let lossy: Double? = (format == .jpg || format == .heic) ? max(Settings.imageQuality, 0.85) : nil
            try write(image, to: out, type: type, quality: lossy)
        }
        return [out]
    }

    private static func writeWebP(from url: URL, to out: URL, quality: Double) async throws {
        let q = String(Int(quality * 100))
        if let cwebp = Shell.cwebp {
            // cwebp reads PNG/JPEG/TIFF/WebP directly; route everything else through a temp PNG.
            var input = url
            var temp: URL?
            if !["png", "jpg", "jpeg", "tif", "tiff", "webp"].contains(url.pathExtension.lowercased()) {
                let t = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
                try write(try load(url), to: t, type: .png)
                input = t; temp = t
            }
            defer { if let temp { try? FileManager.default.removeItem(at: temp) } }
            try await Shell.run(cwebp, ["-quiet", "-q", q, "-metadata", "none", input.path, "-o", out.path])
        } else {
            try await Shell.ffmpeg(["-i", url.path, "-c:v", "libwebp", "-quality", q, out.path])
        }
    }

    /// Draws onto white so transparent pixels don't turn black in JPEG.
    static func flattened(_ image: CGImage) -> CGImage {
        guard image.alphaInfo != .none, image.alphaInfo != .noneSkipLast, image.alphaInfo != .noneSkipFirst else { return image }
        let ctx = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.setFillColor(.white)
        ctx.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return ctx.makeImage() ?? image
    }

    static func resized(_ image: CGImage, maxEdge: Int) -> CGImage {
        let longest = max(image.width, image.height)
        guard longest > maxEdge else { return image }
        let scale = Double(maxEdge) / Double(longest)
        let w = Int((Double(image.width) * scale).rounded()), h = Int((Double(image.height) * scale).rounded())
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage() ?? image
    }

    private static func outputType(for url: URL) -> UTType {
        let t = UTType(filenameExtension: url.pathExtension.lowercased()) ?? .png
        let writable = CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []
        return writable.contains(t.identifier) ? t : .png
    }

    // MARK: Tools

    static func compress(_ url: URL) async throws -> URL {
        let ext = url.pathExtension.lowercased()
        let quality = Settings.imageQuality
        if ext == "webp" {
            let out = OutputNaming.url(nextTo: url, suffix: " compressed", ext: "webp")
            try await writeWebP(from: url, to: out, quality: quality)
            return out
        }
        // PNG and other lossless sources become HEIC-quality JPEGs only if that's smaller;
        // keep the original type when it's a lossy format already.
        let keepType: UTType = ["jpg", "jpeg", "heic", "heif"].contains(ext) ? outputType(for: url) : .jpeg
        let out = OutputNaming.url(nextTo: url, suffix: " compressed", ext: keepType.preferredFilenameExtension ?? "jpg")
        var image = try load(url)
        if keepType == .jpeg { image = flattened(image) }
        try write(image, to: out, type: keepType, quality: quality)
        let before = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let after = (try? out.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        if before > 0, after >= before {
            try? FileManager.default.removeItem(at: out)
            throw OpticsError("\(url.lastPathComponent) is already as small as Optics can make it.")
        }
        return out
    }

    static func resize(_ url: URL) throws -> URL {
        let type = outputType(for: url)
        let out = OutputNaming.url(nextTo: url, suffix: " \(Settings.resizeMaxEdge)px", ext: type.preferredFilenameExtension ?? "png")
        try write(resized(try load(url), maxEdge: Settings.resizeMaxEdge), to: out, type: type, quality: 0.9)
        return out
    }

    static func rotate(_ url: URL) throws -> URL {
        let img = try load(url)
        let ctx = CGContext(data: nil, width: img.height, height: img.width, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.translateBy(x: 0, y: CGFloat(img.width))
        ctx.rotate(by: -.pi / 2)
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: img.width, height: img.height))
        let type = outputType(for: url)
        let out = OutputNaming.url(nextTo: url, suffix: " rotated", ext: type.preferredFilenameExtension ?? "png")
        try write(ctx.makeImage()!, to: out, type: type, quality: 0.92)
        return out
    }

    /// Re-encodes pixels only: EXIF, GPS, IPTC, XMP and maker notes are dropped.
    static func stripMetadata(_ url: URL) throws -> URL {
        let type = outputType(for: url)
        let out = OutputNaming.url(nextTo: url, suffix: " clean", ext: type.preferredFilenameExtension ?? "png")
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let dest = CGImageDestinationCreateWithURL(out as CFURL, type.identifier as CFString, 1, nil)
        else { throw OpticsError("Couldn't read \(url.lastPathComponent).") }
        // CopyImageSource with metadata removal keeps encoded samples untouched where ImageIO allows it.
        let opts: [CFString: Any] = [
            kCGImageDestinationMetadata: CGImageMetadataCreateMutable(),
            kCGImageDestinationMergeMetadata: false,
            kCGImageMetadataShouldExcludeGPS: true,
            kCGImageMetadataShouldExcludeXMP: true,
        ]
        var err: Unmanaged<CFError>?
        if !CGImageDestinationCopyImageSource(dest, src, opts as CFDictionary, &err) {
            // Fall back to a full re-encode with no properties at all.
            try write(try load(url), to: out, type: type, quality: 0.95)
        }
        return out
    }

    static func removeBackground(_ url: URL) async throws -> URL {
        let image = try load(url)
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])
        guard let result = request.results?.first else { throw OpticsError("No subject found in \(url.lastPathComponent).") }
        let buffer = try result.generateMaskedImage(ofInstances: result.allInstances, from: handler, croppedToInstancesExtent: false)
        let ci = CIImage(cvPixelBuffer: buffer)
        guard let cg = CIContext().createCGImage(ci, from: ci.extent) else { throw OpticsError("Couldn't render the cut-out.") }
        let out = OutputNaming.url(nextTo: url, suffix: " cutout", ext: "png")
        try write(cg, to: out, type: .png)
        return out
    }

    static func readQRCodes(_ urls: [URL]) throws -> [String] {
        var found: [String] = []
        for url in urls {
            let request = VNDetectBarcodesRequest()
            try VNImageRequestHandler(cgImage: try load(url)).perform([request])
            found += (request.results ?? []).compactMap(\.payloadStringValue)
        }
        return found
    }

    /// Lays images out on a near-square grid; each cell fits its image with padding.
    static func collage(_ urls: [URL]) throws -> URL {
        let images = try urls.map { resized(try load($0), maxEdge: 1600) }
        let cols = Int(ceil(sqrt(Double(images.count))))
        let rows = Int(ceil(Double(images.count) / Double(cols)))
        let cell = 1200, gap = 24
        let w = cols * cell + (cols + 1) * gap, h = rows * cell + (rows + 1) * gap
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(gray: 0.97, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.interpolationQuality = .high
        for (i, img) in images.enumerated() {
            let col = i % cols, row = i / cols
            let originX = gap + col * (cell + gap)
            let originY = h - (gap + (row + 1) * cell + row * gap)
            let scale = min(Double(cell) / Double(img.width), Double(cell) / Double(img.height))
            let dw = Double(img.width) * scale, dh = Double(img.height) * scale
            let rect = CGRect(x: Double(originX) + (Double(cell) - dw) / 2, y: Double(originY) + (Double(cell) - dh) / 2, width: dw, height: dh)
            ctx.draw(img, in: rect)
        }
        let out = OutputNaming.url(nextTo: urls[0], suffix: " collage", ext: "png")
        try write(ctx.makeImage()!, to: out, type: .png)
        return out
    }
}
