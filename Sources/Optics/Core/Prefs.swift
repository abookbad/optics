import AppKit

/// Which lens a modifier combination opens while dragging files.
enum LensMode: String, CaseIterable, Identifiable {
    case convert, tools, actions
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

/// Persisted preferences. Backed by UserDefaults so @AppStorage views and the engine agree.
enum Prefs {
    private static let defaults = UserDefaults.standard

    static func modifiers(for mode: LensMode) -> NSEvent.ModifierFlags {
        let key = "modifiers.\(mode.rawValue)"
        if defaults.object(forKey: key) == nil { return defaultModifiers(mode) }
        return NSEvent.ModifierFlags(rawValue: UInt(defaults.integer(forKey: key)))
    }

    static func setModifiers(_ flags: NSEvent.ModifierFlags, for mode: LensMode) {
        defaults.set(Int(flags.intersection(relevantModifiers).rawValue), forKey: "modifiers.\(mode.rawValue)")
    }

    static func defaultModifiers(_ mode: LensMode) -> NSEvent.ModifierFlags {
        switch mode {
        case .convert: .option
        case .tools: .control
        case .actions: [.control, .option]
        }
    }

    static let relevantModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

    /// Image quality 0...1 used by Compress and lossy conversions.
    static var imageQuality: Double {
        get { defaults.object(forKey: "imageQuality") as? Double ?? 0.72 }
        set { defaults.set(newValue, forKey: "imageQuality") }
    }

    /// Longest edge, in pixels, for Resize.
    static var resizeMaxEdge: Int {
        get { defaults.object(forKey: "resizeMaxEdge") as? Int ?? 1920 }
        set { defaults.set(newValue, forKey: "resizeMaxEdge") }
    }

    /// Constant rate factor for video compression; higher is smaller.
    static var videoCRF: Int {
        get { defaults.object(forKey: "videoCRF") as? Int ?? 28 }
        set { defaults.set(newValue, forKey: "videoCRF") }
    }

    static var gifFPS: Int {
        get { defaults.object(forKey: "gifFPS") as? Int ?? 15 }
        set { defaults.set(newValue, forKey: "gifFPS") }
    }

    static var gifWidth: Int {
        get { defaults.object(forKey: "gifWidth") as? Int ?? 640 }
        set { defaults.set(newValue, forKey: "gifWidth") }
    }

    static var playSounds: Bool {
        get { defaults.object(forKey: "playSounds") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "playSounds") }
    }

    static var revealOutput: Bool {
        get { defaults.object(forKey: "revealOutput") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "revealOutput") }
    }
}

extension NSEvent.ModifierFlags {
    var glyphs: String {
        var s = ""
        if contains(.control) { s += "⌃" }
        if contains(.option) { s += "⌥" }
        if contains(.shift) { s += "⇧" }
        if contains(.command) { s += "⌘" }
        return s.isEmpty ? "—" : s
    }
}
