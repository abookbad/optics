import SwiftUI

struct GettingStartedView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(nsImage: MenuBarIcon.image).resizable().frame(width: 34, height: 34)
                    .foregroundStyle(LensPalette.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Welcome to Optics").font(.title2.bold())
                    Text("Drag any file, then hold a key. Drop on a petal.").foregroundStyle(.secondary)
                }
            }
            ForEach(LensMode.allCases) { mode in
                HStack(alignment: .top, spacing: 12) {
                    Text(Prefs.modifiers(for: mode).glyphs)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .frame(width: 44, height: 30)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 7))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mode.title).font(.headline)
                        Text(mode.blurb).font(.callout).foregroundStyle(.secondary)
                    }
                }
            }
            Text("Results are saved next to the original. Change keys in Settings.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 420)
    }
}

extension LensMode {
    var blurb: String {
        switch self {
        case .convert: "Turn files into another format: images, video, audio, documents."
        case .tools: "Compress, clean metadata, resize, cut out, merge, trim silence and more."
        case .actions: "AirDrop, pin to a Float, copy, move, copy the path, or open Terminal there."
        }
    }
}
