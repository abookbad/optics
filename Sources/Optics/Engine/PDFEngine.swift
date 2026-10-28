import AppKit
import PDFKit
import Quartz

enum PDFEngine {
    static func open(_ url: URL) throws -> PDFDocument {
        guard let doc = PDFDocument(url: url), !doc.isLocked else {
            throw OpticsError("\(url.lastPathComponent) can't be read or is password-protected.")
        }
        guard doc.pageCount > 0 else { throw OpticsError("\(url.lastPathComponent) has no pages.") }
        return doc
    }

    static func imagesToPDF(_ urls: [URL]) throws -> [URL] {
        let doc = PDFDocument()
        for url in urls {
            let cg = try ImageEngine.load(url)
            let image = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
            guard let page = PDFPage(image: image) else { throw OpticsError("Couldn't place \(url.lastPathComponent) on a page.") }
            doc.insert(page, at: doc.pageCount)
        }
        let out = OutputNaming.url(nextTo: urls[0], suffix: urls.count > 1 ? " and \(urls.count - 1) more" : "", ext: "pdf")
        guard doc.write(to: out) else { throw OpticsError("Couldn't save the PDF.") }
        return [out]
    }

    static func merge(_ urls: [URL]) throws -> URL {
        let merged = PDFDocument()
        for url in urls {
            let doc = try open(url)
            for i in 0..<doc.pageCount {
                if let page = doc.page(at: i)?.copy() as? PDFPage { merged.insert(page, at: merged.pageCount) }
            }
        }
        let out = OutputNaming.url(nextTo: urls[0], suffix: " merged", ext: "pdf")
        guard merged.write(to: out) else { throw OpticsError("Couldn't save the merged PDF.") }
        return out
    }

    static func split(_ url: URL) throws -> URL {
        let doc = try open(url)
        let folder = try OutputNaming.folder(nextTo: url, suffix: " pages")
        let base = url.deletingPathExtension().lastPathComponent
        for i in 0..<doc.pageCount {
            let single = PDFDocument()
            if let page = doc.page(at: i)?.copy() as? PDFPage { single.insert(page, at: 0) }
            single.write(to: folder.appendingPathComponent(String(format: "%@ p%03d.pdf", base, i + 1)))
        }
        return folder
    }

    /// Uses the system "Reduce File Size" Quartz filter, keeping the result only if it's smaller.
    static func compress(_ url: URL) throws -> URL {
        let doc = try open(url)
        let filterURL = URL(fileURLWithPath: "/System/Library/Filters/Reduce File Size.qfilter")
        guard let filter = QuartzFilter(url: filterURL) else { throw OpticsError("macOS's PDF compression filter is unavailable.") }
        let out = OutputNaming.url(nextTo: url, suffix: " compressed", ext: "pdf")
        guard doc.write(to: out, withOptions: [PDFDocumentWriteOption(rawValue: "QuartzFilter"): filter]) else {
            throw OpticsError("Couldn't write the compressed PDF.")
        }
        let before = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let after = (try? out.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        if after >= before {
            try? FileManager.default.removeItem(at: out)
            throw OpticsError("\(url.lastPathComponent) is already compact.")
        }
        return out
    }

    static func pagesToImages(_ url: URL, type: UTType = .png, scale: CGFloat = 2) throws -> URL {
        let doc = try open(url)
        let folder = try OutputNaming.folder(nextTo: url, suffix: " images")
        let base = url.deletingPathExtension().lastPathComponent
        let ext = type.preferredFilenameExtension ?? "png"
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let w = Int(bounds.width * scale), h = Int(bounds.height * scale)
            let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            ctx.setFillColor(.white)
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            ctx.scaleBy(x: scale, y: scale)
            page.draw(with: .mediaBox, to: ctx)
            let file = folder.appendingPathComponent(String(format: "%@ p%03d.%@", base, i + 1, ext))
            try ImageEngine.write(ctx.makeImage()!, to: file, type: type, quality: 0.9)
        }
        return folder
    }

    static func text(_ url: URL) throws -> String {
        let doc = try open(url)
        guard let text = doc.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OpticsError("\(url.lastPathComponent) has no selectable text.")
        }
        return text
    }

    /// Text-preserving conversion: pulls attributed text from each page.
    static func attributedText(_ url: URL) throws -> NSAttributedString {
        let doc = try open(url)
        let result = NSMutableAttributedString()
        for i in 0..<doc.pageCount {
            if let page = doc.page(at: i)?.attributedString { result.append(page) }
            if i < doc.pageCount - 1 { result.append(NSAttributedString(string: "\n\u{0C}")) }
        }
        guard result.length > 0 else { throw OpticsError("\(url.lastPathComponent) has no selectable text.") }
        return result
    }
}
