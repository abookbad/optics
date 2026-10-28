import AppKit
import CoreText

/// Rich-text documents go through NSAttributedString, which reads and writes
/// DOCX, RTF, ODT, HTML and plain text natively. PDF output is laid out with Core Text.
enum DocumentEngine {
    static func load(_ url: URL) throws -> NSAttributedString {
        let ext = url.pathExtension.lowercased()
        if ext == "pdf" { return try PDFEngine.attributedText(url) }
        if ext == "md" || ext == "markdown" {
            let source = try String(contentsOf: url, encoding: .utf8)
            let parsed = try AttributedString(markdown: source, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))
            return styled(NSAttributedString(parsed))
        }
        var docType: NSAttributedString.DocumentType?
        switch ext {
        case "docx": docType = .officeOpenXML
        case "doc": docType = .docFormat
        case "odt": docType = .openDocument
        case "rtf": docType = .rtf
        case "rtfd": docType = .rtfd
        case "html", "htm": docType = .html
        case "txt": docType = .plain
        case "webarchive": docType = .webArchive
        default: break
        }
        var opts: [NSAttributedString.DocumentReadingOptionKey: Any] = [:]
        if let docType { opts[.documentType] = docType }
        if docType == .plain { opts[.characterEncoding] = String.Encoding.utf8.rawValue }
        let string = try NSAttributedString(url: url, options: opts, documentAttributes: nil)
        return docType == .plain ? styled(string) : string
    }

    /// Plain text has no fonts; give it a readable default.
    private static func styled(_ s: NSAttributedString) -> NSAttributedString {
        let m = NSMutableAttributedString(attributedString: s)
        m.enumerateAttribute(.font, in: NSRange(location: 0, length: m.length)) { value, range, _ in
            if value == nil { m.addAttribute(.font, value: NSFont.systemFont(ofSize: 12), range: range) }
        }
        return m
    }

    static func convert(_ url: URL, to format: OutputFormat) throws -> URL {
        let text = try load(url)
        let out = OutputNaming.url(nextTo: url, ext: format.fileExtension)
        let range = NSRange(location: 0, length: text.length)
        switch format {
        case .pdf:
            try renderPDF(text, to: out)
        case .txt:
            try text.string.write(to: out, atomically: true, encoding: .utf8)
        case .markdown:
            try markdown(from: text).write(to: out, atomically: true, encoding: .utf8)
        default:
            let type: NSAttributedString.DocumentType = switch format {
            case .docx: .officeOpenXML
            case .rtf: .rtf
            case .html: .html
            case .odt: .openDocument
            default: throw OpticsError("Documents can't become \(format.label).")
            }
            let data = try text.data(from: range, documentAttributes: [.documentType: type])
            try data.write(to: out)
        }
        return out
    }

    /// US Letter pages with one-inch margins.
    static func renderPDF(_ text: NSAttributedString, to url: URL) throws {
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let ctx = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else { throw OpticsError("Couldn't create the PDF.") }
        let framesetter = CTFramesetterCreateWithAttributedString(text as CFAttributedString)
        let frameRect = mediaBox.insetBy(dx: 72, dy: 72)
        var start = 0
        repeat {
            ctx.beginPDFPage(nil)
            let path = CGPath(rect: frameRect, transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: start, length: 0), path, nil)
            CTFrameDraw(frame, ctx)
            let visible = CTFrameGetVisibleStringRange(frame)
            ctx.endPDFPage()
            if visible.length == 0 { break }
            start += visible.length
        } while start < text.length
        ctx.closePDF()
    }

    /// Lightweight Markdown export: bold/italic runs and large-font lines become headings.
    static func markdown(from text: NSAttributedString) -> String {
        var lines: [String] = []
        let ns = text.string as NSString
        ns.enumerateSubstrings(in: NSRange(location: 0, length: ns.length), options: .byParagraphs) { _, range, _, _ in
            guard range.length > 0 else { lines.append(""); return }
            var line = ""
            var maxSize: CGFloat = 0
            text.enumerateAttributes(in: range) { attrs, r, _ in
                let run = ns.substring(with: r)
                guard let font = attrs[.font] as? NSFont else { line += run; return }
                maxSize = max(maxSize, font.pointSize)
                let traits = font.fontDescriptor.symbolicTraits
                let trimmed = run.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { line += run }
                else if traits.contains(.bold) && traits.contains(.italic) { line += "***\(trimmed)***" }
                else if traits.contains(.bold) { line += "**\(trimmed)**" }
                else if traits.contains(.italic) { line += "*\(trimmed)*" }
                else { line += run }
            }
            if maxSize >= 22 { line = "# " + line.replacingOccurrences(of: "**", with: "") }
            else if maxSize >= 17 { line = "## " + line.replacingOccurrences(of: "**", with: "") }
            lines.append(line)
        }
        return lines.joined(separator: "\n\n")
    }
}
