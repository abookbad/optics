import AVFoundation
import Foundation

/// Video and audio work, done with ffmpeg so every format on the lens is reachable.
/// Hardware H.264/HEVC encoders are used where they make sense.
enum MediaEngine {
    static func convert(_ url: URL, to format: OutputFormat) async throws -> URL {
        let out = OutputNaming.url(nextTo: url, ext: format.fileExtension)
        let i = ["-i", url.path]
        let args: [String]
        switch format {
        case .mp4: args = i + ["-c:v", "h264_videotoolbox", "-b:v", "6M", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", "-pix_fmt", "yuv420p"]
        case .mov: args = i + ["-c:v", "hevc_videotoolbox", "-b:v", "6M", "-tag:v", "hvc1", "-c:a", "aac", "-b:a", "192k"]
        case .webm: args = i + ["-c:v", "libvpx-vp9", "-crf", "32", "-b:v", "0", "-c:a", "libopus"]
        case .mkv: args = i + ["-c", "copy"]
        case .animatedGIF:
            let w = Prefs.gifWidth, fps = Prefs.gifFPS
            args = i + ["-vf", "fps=\(fps),scale='min(\(w),iw)':-2:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=sierra2_4a", "-loop", "0"]
        case .m4a: args = i + ["-vn", "-c:a", "aac", "-b:a", "256k"]
        case .mp3: args = i + ["-vn", "-c:a", "libmp3lame", "-q:a", "2"]
        case .wav: args = i + ["-vn", "-c:a", "pcm_s16le"]
        case .flac: args = i + ["-vn", "-c:a", "flac"]
        case .aiff: args = i + ["-vn", "-c:a", "pcm_s16be"]
        case .ogg: args = i + ["-vn", "-c:a", "vorbis", "-strict", "experimental", "-ac", "2", "-q:a", "6"]
        case .opus: args = i + ["-vn", "-c:a", "libopus", "-b:a", "160k"]
        default: throw OpticsError("Media can't become \(format.label).")
        }
        if format == .mp4, FileKind.of(url) == .audio {
            // Audio → MP4 means a shareable video: render the waveform over a dark canvas.
            return try await waveformVideo(url, output: out)
        }
        try await Shell.ffmpeg(args + [out.path])
        return out
    }

    static func compressVideo(_ url: URL) async throws -> URL {
        let out = OutputNaming.url(nextTo: url, suffix: " compressed", ext: "mp4")
        try await Shell.ffmpeg(["-i", url.path, "-c:v", "libx264", "-preset", "medium", "-crf", String(Prefs.videoCRF),
                                "-vf", "scale='min(1920,iw)':-2", "-c:a", "aac", "-b:a", "128k", "-movflags", "+faststart",
                                "-pix_fmt", "yuv420p", out.path])
        return out
    }

    static func mute(_ url: URL) async throws -> URL {
        let out = OutputNaming.url(nextTo: url, suffix: " muted", ext: url.pathExtension)
        try await Shell.ffmpeg(["-i", url.path, "-c:v", "copy", "-an", out.path])
        return out
    }

    static func extractAudio(_ url: URL) async throws -> URL {
        let out = OutputNaming.url(nextTo: url, ext: "m4a")
        try await Shell.ffmpeg(["-i", url.path, "-vn", "-c:a", "aac", "-b:a", "256k", out.path])
        return out
    }

    /// `factor` > 1 speeds up. atempo only takes 0.5...2, which covers both presets.
    static func changeSpeed(_ url: URL, factor: Double) async throws -> URL {
        let label = factor > 1 ? " \(Int(factor))x" : " half speed"
        let out = OutputNaming.url(nextTo: url, suffix: label, ext: "mp4")
        var args = ["-i", url.path, "-filter:v", "setpts=\(1 / factor)*PTS"]
        args += try await hasAudio(url) ? ["-filter:a", "atempo=\(factor)"] : ["-an"]
        try await Shell.ffmpeg(args + ["-c:v", "h264_videotoolbox", "-b:v", "6M", "-pix_fmt", "yuv420p", out.path])
        return out
    }

    /// Joins clips in drop order, normalising each to the first clip's size so mixed sources work.
    static func join(_ urls: [URL]) async throws -> URL {
        let first = AVURLAsset(url: urls[0])
        guard let track = try await first.loadTracks(withMediaType: .video).first else {
            throw OpticsError("\(urls[0].lastPathComponent) has no video.")
        }
        let size = try await track.load(.naturalSize).applying(try await track.load(.preferredTransform))
        let w = Int(abs(size.width)) / 2 * 2, h = Int(abs(size.height)) / 2 * 2
        var inputs: [String] = [], filters: [String] = [], concat = ""
        var allHaveAudio = true
        for u in urls where try await !hasAudio(u) { allHaveAudio = false }
        for (n, u) in urls.enumerated() {
            inputs += ["-i", u.path]
            filters.append("[\(n):v]scale=\(w):\(h):force_original_aspect_ratio=decrease,pad=\(w):\(h):(ow-iw)/2:(oh-ih)/2,setsar=1,fps=30[v\(n)]")
            concat += allHaveAudio ? "[v\(n)][\(n):a]" : "[v\(n)]"
        }
        let graph = filters.joined(separator: ";") + ";" + concat + "concat=n=\(urls.count):v=1:a=\(allHaveAudio ? 1 : 0)[v]" + (allHaveAudio ? "[a]" : "")
        let out = OutputNaming.url(nextTo: urls[0], suffix: " joined", ext: "mp4")
        var args = inputs + ["-filter_complex", graph, "-map", "[v]"]
        if allHaveAudio { args += ["-map", "[a]", "-c:a", "aac"] }
        try await Shell.ffmpeg(args + ["-c:v", "h264_videotoolbox", "-b:v", "8M", "-pix_fmt", "yuv420p", out.path])
        return out
    }

    /// Six evenly spaced PNG frames into a folder.
    static func snapshots(_ url: URL, count: Int = 6) async throws -> URL {
        let duration = try await AVURLAsset(url: url).load(.duration).seconds
        guard duration.isFinite, duration > 0 else { throw OpticsError("\(url.lastPathComponent) has no playable duration.") }
        let folder = try OutputNaming.folder(nextTo: url, suffix: " snapshots")
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        for n in 0..<count {
            let t = CMTime(seconds: duration * (Double(n) + 0.5) / Double(count), preferredTimescale: 600)
            let (image, _) = try await generator.image(at: t)
            let file = folder.appendingPathComponent(String(format: "%@ %02d.png", url.deletingPathExtension().lastPathComponent, n + 1))
            try ImageEngine.write(image, to: file, type: .png)
        }
        return folder
    }

    static func stripMetadata(_ url: URL) async throws -> URL {
        let out = OutputNaming.url(nextTo: url, suffix: " clean", ext: url.pathExtension)
        try await Shell.ffmpeg(["-i", url.path, "-map", "0", "-map_metadata", "-1", "-map_chapters", "-1", "-c", "copy", out.path])
        return out
    }

    // MARK: Audio

    /// EBU R128 loudness normalisation to −14 LUFS, the common streaming target.
    static func normalize(_ url: URL) async throws -> URL {
        let out = OutputNaming.url(nextTo: url, suffix: " normalized", ext: audioExt(url))
        try await Shell.ffmpeg(["-i", url.path, "-af", "loudnorm=I=-14:TP=-1.0:LRA=11"] + audioCodec(url) + [out.path])
        return out
    }

    static func trimSilence(_ url: URL) async throws -> URL {
        let out = OutputNaming.url(nextTo: url, suffix: " trimmed", ext: audioExt(url))
        let edge = "silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.1"
        try await Shell.ffmpeg(["-i", url.path, "-af", "\(edge),areverse,\(edge),areverse"] + audioCodec(url) + [out.path])
        return out
    }

    static func mono(_ url: URL) async throws -> URL {
        let out = OutputNaming.url(nextTo: url, suffix: " mono", ext: audioExt(url))
        try await Shell.ffmpeg(["-i", url.path, "-ac", "1"] + audioCodec(url) + [out.path])
        return out
    }

    static func waveformVideo(_ url: URL, output: URL? = nil) async throws -> URL {
        let out = output ?? OutputNaming.url(nextTo: url, suffix: " waveform", ext: "mp4")
        let graph = "[0:a]showwaves=s=1280x720:mode=cline:rate=30:colors=0x7C5CFF|0x2EC5FF:scale=sqrt,format=yuv420p[w];color=c=0x0E0F14:s=1280x720:r=30[bg];[bg][w]overlay=shortest=1[v]"
        try await Shell.ffmpeg(["-i", url.path, "-filter_complex", graph, "-map", "[v]", "-map", "0:a",
                                "-c:v", "h264_videotoolbox", "-b:v", "4M", "-c:a", "aac", "-b:a", "192k", "-shortest", out.path])
        return out
    }

    private static func audioExt(_ url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        return ["mp3", "m4a", "wav", "flac", "aiff", "ogg", "opus"].contains(ext) ? ext : "m4a"
    }

    private static func audioCodec(_ url: URL) -> [String] {
        switch audioExt(url) {
        case "mp3": ["-c:a", "libmp3lame", "-q:a", "2"]
        case "wav": ["-c:a", "pcm_s16le"]
        case "aiff": ["-c:a", "pcm_s16be"]
        case "flac": ["-c:a", "flac"]
        case "ogg": ["-c:a", "vorbis", "-strict", "experimental", "-ac", "2", "-q:a", "6"]
        case "opus": ["-c:a", "libopus", "-b:a", "160k"]
        default: ["-c:a", "aac", "-b:a", "256k"]
        }
    }

    private static func hasAudio(_ url: URL) async throws -> Bool {
        !(try await AVURLAsset(url: url).loadTracks(withMediaType: .audio)).isEmpty
    }
}
