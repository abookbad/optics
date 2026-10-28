# Tangerine — reverse-engineering notes

Source: `/Applications/Tangerine.app` (Mac App Store, `com.th.Tangerine`, v2.0.2 build 9,
arm64, built with Xcode 27 / macOS 27 SDK, min macOS 13). Analysed 2026-10-27 with the REA
MCP (Hopper provider) plus `strings`/`otool`/`plutil`. The binary is stripped Swift, so
REA's xrefs from strings landed in Swift metadata, not code; the findings below come from
type names, property names, enum cases and UI strings that ship in the binary. No code,
scripts or assets from Tangerine are copied into Optics.

## What it is

A menu-bar utility (`LSUIElement`) for doing things to files mid-drag. Monetised with
RevenueCat ("Unlock Tangerine", "Unlimited conversions and tools").

## Core interaction

- **Drag-gesture monitor** (`DragGestureMonitor`, `activeDragPasteboardChangeCount`):
  watches global drags and the drag pasteboard's change count to know when files are
  being dragged anywhere in macOS.
- **Three wheels, each on its own modifier mask**: `conversionWheelDragModifierMask`,
  `toolsDragModifierMask`, `actionsWheelDragModifierMask` (`DragModifierCombination`,
  "Tap the chosen modifier combination while dragging files"). A migration flag
  `didMigrateToolsWheelToCommand` shows the tools wheel moved to ⌘.
- **Conversion wheel**: a radial "fan" (`NativeGlassFanModel`, `PetalTintView`,
  `FanCenterLabelView`, `FanHighlightSoundPlayer`, themes in `ConversionFanTheme`:
  citrus, meadow, whisper, orchid, lagoon, sorbet, emerald, sunset, violet, graphite…).
  Petals highlight with a sound/haptic as the drag passes over them.
- **Floats**: floating file shelves (`FloatingFilePanel`, `FloatingFileGroupModel`,
  `FloatingTabGlassMaterialView`, a paper-clip graphic, rubber-band selection,
  QuickLook, "Drag to carry all files", "Add Files to an Existing Float").

## Tool catalogue (enum cases recovered from the binary)

`convert, fileTool, airDrop, copyPath, openTerminal` (top-level), then file tools:
`compress, removeMetadata, editImage, annotateImage, frameImage, cropImage,
normalizeAudio, muteVideo, trimVideo, splitPDF, organizePDF, extractArchive, createPDF,
mergePDF, cropVideo, changeVideoSpeed, joinVideos, videoSnapshots, splitVideo,
audioToVideo, trimAudio, audioChannels, createCollage, readQRCode, redactImage,
redactVideo, redactAudio (bleep)`.

Many tools open an options panel (`FileToolOptionsPanel`) with editors: crop handles,
timeline scrubbing, waveform, bleep ranges, redaction rectangles (blur/solid), annotation
(arrows, numbered callouts, text, highlight, freehand), collage spacing/background,
target-size compression, loudness targets (`normalizationTargetLoudness`, `…TruePeak`).

## Formats

Images (jpg, png, heic, webp, tiff, gif, bmp, avif, svg), video (mp4, mov, mkv, webm,
avi, m4v), audio (mp3, m4a, wav, flac, aiff, ogg, opus, aac), documents (pdf, docx, rtf,
txt, md, html, epub, pages, key, numbers, pptx, xlsx, xls, ppt, ods), archives (zip, rar, 7z).

## Bundled engines

- `ffmpeg` and `cwebp` binaries in `Resources/Tools`, using `h264_videotoolbox` /
  `hevc_videotoolbox` plus palettegen/paletteuse for GIFs.
- ExifTool (Perl) with two custom bridge scripts for metadata reading and fail-closed
  metadata stripping that keeps image samples byte-identical.
- JavaScriptCore-hosted JS bundles: `OfficePreview.js` (JSZip-based Office rendering),
  `PagesWriter.js` (writes native `.pages` from a template).
- A bundled PowerPoint/spreadsheet converter runtime (arm64 + x86_64).
- System frameworks: Vision (QR + subject masks), PDFKit, Quartz filters, AVFoundation,
  QuickLookThumbnailing, ServiceManagement (login item), StoreKit.

## What Optics takes from this

The interaction model: modifier-while-dragging opens a radial picker under the cursor,
plus floating shelves. Optics is a fresh implementation with its own names (Lens, Tray),
design and code, using macOS frameworks and the user's own Homebrew ffmpeg/cwebp.
Not ported (yet): the interactive editors (crop/annotate/redact/trim timelines),
EPUB/Pages/PowerPoint writers, and target-size compression.
