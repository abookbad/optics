# Optics

A macOS menu-bar app for doing things to files *while you drag them*.

Hold a modifier mid-drag and a **Lens** opens under the cursor. Drop on a slice:

| Lens | Default | What's on it |
|---|---|---|
| Convert | ⇧ | Formats for what you're dragging: images ⇄ JPG/PNG/HEIC/WebP/AVIF/TIFF/GIF/BMP/PDF, video → MP4/MOV/WebM/MKV/GIF/audio, audio ⇄ MP3/M4A/WAV/FLAC/AIFF/OGG/Opus, documents ⇄ PDF/DOCX/RTF/ODT/HTML/TXT/Markdown, anything → ZIP |
| Tools | ⌘ | Compress, resize, rotate, cut out subject, clean metadata, read QR, collage, images → one PDF · compress/mute/speed/join/snapshot video · normalize, trim silence, mono, waveform video · merge/split/compress PDFs, pages → PNG, extract text · zip/extract |
| Actions | ⌃ | Float, copy path, move/copy to…, AirDrop, open Terminal/iTerm here, reveal |

**Floats** are floating shelves: park files, switch apps, drag them back out (one or all).
The wheel UI (geometry, palette, fade timing) is matched to captures of Tangerine's; see docs/TANGERINE_ANALYSIS.md.

Results are always new files next to the originals (`photo compressed.jpg`, `clip 2x.mp4`, …);
originals are never modified.

## Build & run

```sh
scripts/build-app.sh          # → build/Optics.app (ad-hoc signed)
open build/Optics.app
```

Requires macOS 14+. Video/audio need `ffmpeg` (`brew install ffmpeg`); `cwebp` is optional.
Everything else uses system frameworks (ImageIO, Vision, PDFKit, Core Text, AVFoundation).

## Headless use

The same engine runs from the command line, which is also how it's tested:

```sh
build/Optics.app/Contents/MacOS/Optics --convert webp photo.png
build/Optics.app/Contents/MacOS/Optics --tool joinVideos a.mp4 b.mp4
build/Optics.app/Contents/MacOS/Optics --preview-lens tools clip.mp4   # show a lens for QA
```

## Layout

- `Core/` file kinds, formats, tools, prefs, output naming
- `Engine/` image, media (ffmpeg), PDF, document, archive engines + dispatcher
- `Lens/` global drag monitor and the radial panel
- `Tray/` floating shelves
- `UI/` menu-bar window, settings, toasts, text results

See `docs/TANGERINE_ANALYSIS.md` for the reverse-engineering notes this was designed from.
