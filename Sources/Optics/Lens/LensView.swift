import SwiftUI

/// Wheel geometry, in points, for a 372 pt panel.
enum LensMetrics {
    static let panel: CGFloat = 372
    static let discRadius: CGFloat = 127
    static let petalOuter: CGFloat = 118
    static let petalInner: CGFloat = 49
    static let holeRadius: CGFloat = 42
    static let gap: CGFloat = 7
    static let corner: CGFloat = 13
    static let pill = CGSize(width: 72, height: 34)
}

enum LensPalette {
    static let disc = Color(white: 19 / 255)
    static let discRim = Color(white: 33 / 255)
    static let petal = Color(white: 55 / 255)
    static let petalTop = Color(white: 61 / 255)
    static let pill = Color(white: 54 / 255)
    /// Hover fill runs from a peach inner edge to burnt orange at the rim.
    static let hotInner = Color(red: 238 / 255, green: 142 / 255, blue: 96 / 255)
    static let hotMid = Color(red: 230 / 255, green: 98 / 255, blue: 32 / 255)
    static let hotOuter = Color(red: 212 / 255, green: 86 / 255, blue: 24 / 255)
    static let accent = Color(red: 1, green: 0.32, blue: 0)
}

/// One petal: an annular sector whose sides are offset so every gap has the same width,
/// with all four corners rounded. Angles are radians, 0 at twelve o'clock, clockwise.
struct PetalShape: Shape {
    var center: Double
    var span: Double
    var inner: CGFloat = LensMetrics.petalInner
    var outer: CGFloat = LensMetrics.petalOuter
    var gap: CGFloat = LensMetrics.gap
    var corner: CGFloat = LensMetrics.corner

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        // Build the sector shrunk by the corner radius, then grow it back with a round stroke.
        let r = corner
        let rIn = inner + r, rOut = outer - r, d = gap / 2 + r
        // Screen space: x right, y down. Direction for clock angle a is (sin a, -cos a).
        func dir(_ a: Double) -> CGVector { CGVector(dx: sin(a), dy: -cos(a)) }
        // Point at radius `rad` on the line parallel to angle `a`, offset `off` toward the sector.
        func point(_ a: Double, _ rad: CGFloat, _ off: CGFloat) -> CGPoint {
            let u = dir(a)
            let n = CGVector(dx: cos(a), dy: sin(a)) // clockwise normal
            let t = sqrt(max(rad * rad - off * off, 0))
            return CGPoint(x: c.x + u.dx * t + n.dx * off, y: c.y + u.dy * t + n.dy * off)
        }
        func angle(_ p: CGPoint) -> CGFloat { atan2(p.y - c.y, p.x - c.x) }
        let a0 = center - span / 2, a1 = center + span / 2
        let p1 = point(a0, rIn, d), p2 = point(a0, rOut, d)
        let p3 = point(a1, rOut, -d), p4 = point(a1, rIn, -d)
        let core = CGMutablePath()
        core.move(to: p1)
        core.addLine(to: p2)
        core.addArc(center: c, radius: rOut, startAngle: angle(p2), endAngle: angle(p3), clockwise: false)
        core.addLine(to: p4)
        core.addArc(center: c, radius: rIn, startAngle: angle(p4), endAngle: angle(p1), clockwise: true)
        core.closeSubpath()
        let grown = core.copy(strokingWithWidth: 2 * r, lineCap: .round, lineJoin: .round, miterLimit: 1)
        return Path(core.union(grown))
    }
}

struct LensView: View {
    @Bindable var model: LensModel

    var body: some View {
        let n = max(model.items.count, 1)
        let span = 2 * Double.pi / Double(n)
        ZStack {
            // Disc with a punched-out center.
            Circle()
                .fill(LensPalette.disc)
                .frame(width: LensMetrics.discRadius * 2, height: LensMetrics.discRadius * 2)
                .overlay(Circle().strokeBorder(LensPalette.discRim, lineWidth: 1))
                .mask(
                    ZStack {
                        Circle().frame(width: LensMetrics.discRadius * 2)
                        Circle().frame(width: LensMetrics.holeRadius * 2).blendMode(.destinationOut)
                    }
                    .compositingGroup()
                )
                .overlay(Circle().strokeBorder(LensPalette.discRim, lineWidth: 1)
                    .frame(width: LensMetrics.holeRadius * 2, height: LensMetrics.holeRadius * 2))
                .shadow(color: .black.opacity(0.45), radius: 14, y: 6)

            ForEach(Array(model.items.enumerated()), id: \.element.id) { i, item in
                PetalView(item: item, center: Double(i) * span, span: span, isHot: model.hovered == i)
            }

            CenterPill(text: model.hovered.flatMap { model.items.indices.contains($0) ? model.items[$0].label : nil },
                       idle: model.summary)
        }
        .frame(width: LensMetrics.panel, height: LensMetrics.panel)
        .opacity(model.revealed ? 1 : 0)
        .animation(.easeOut(duration: 0.2), value: model.revealed)
        .animation(.easeOut(duration: 0.12), value: model.hovered)
    }
}

private struct PetalView: View {
    let item: LensItem
    let center: Double
    let span: Double
    let isHot: Bool

    var body: some View {
        let shape = PetalShape(center: center, span: span)
        let mid = (LensMetrics.petalInner + LensMetrics.petalOuter) / 2
        let u = CGVector(dx: sin(center), dy: -cos(center))
        ZStack {
            shape.fill(LinearGradient(colors: [LensPalette.petalTop, LensPalette.petal],
                                      startPoint: .top, endPoint: .bottom))
            shape.fill(RadialGradient(stops: [.init(color: LensPalette.hotInner, location: 0),
                                              .init(color: LensPalette.hotMid, location: 0.35),
                                              .init(color: LensPalette.hotOuter, location: 1)],
                                      center: .center, startRadius: LensMetrics.petalInner, endRadius: LensMetrics.petalOuter))
                .opacity(isHot ? 1 : 0)
            shape.stroke(Color.white.opacity(isHot ? 0.18 : 0.06), lineWidth: 1)
            PetalLabel(item: item, isHot: isHot)
                .offset(x: u.dx * mid, y: u.dy * mid)
        }
        .frame(width: LensMetrics.panel, height: LensMetrics.panel)
        .compositingGroup()
    }
}

private struct PetalLabel: View {
    let item: LensItem
    let isHot: Bool

    var body: some View {
        Group {
            if let symbol = item.symbol {
                VStack(spacing: 4) {
                    if symbol == AirDropGlyph.name {
                        AirDropGlyph().frame(width: 13, height: 13)
                    } else {
                        Image(systemName: symbol).font(.system(size: 12, weight: .medium))
                    }
                    Text(wrapped(item.label.uppercased()))
                        .font(.system(size: 8, weight: .bold))
                        .tracking(0.4)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize()
                }
            } else {
                Text(item.label.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.3)
            }
        }
        .foregroundStyle(Color.white.opacity(isHot ? 1 : 0.9))
        .frame(width: 70)
    }
}

/// Long two-word captions stack, as "COPY / PATH" does; single words up to 8 letters stay on one line.
private func wrapped(_ s: String) -> String {
    guard s.count > 8, let space = s.firstIndex(of: " ") else { return s }
    return s.replacingCharacters(in: space...space, with: "\n")
}

private struct CenterPill: View {
    let text: String?
    let idle: String

    var body: some View {
        Text(text?.uppercased() ?? idle)
            .font(.system(size: text == nil ? 10.5 : 8.5, weight: .bold))
            .tracking(text == nil ? 0 : 0.4)
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 8)
            .frame(width: LensMetrics.pill.width, height: LensMetrics.pill.height)
            .background {
                Capsule().fill(LensPalette.pill)
                Capsule().fill(RadialGradient(colors: [LensPalette.accent.opacity(0.13), .clear],
                                              center: .leading, startRadius: 0, endRadius: 40))
                    .opacity(text == nil ? 0 : 1)
            }
            .overlay(Capsule().strokeBorder(
                LinearGradient(colors: [.white.opacity(0.22), .white.opacity(0.04)], startPoint: .top, endPoint: .bottom),
                lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
    }
}

/// AirDrop mark drawn in code (no SF Symbol exists): two rings opening at the bottom over a small cone.
struct AirDropGlyph: View {
    static let name = "optics.airdrop"

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height * 0.46)
            let r = min(size.width, size.height) * 0.46
            for (radius, width) in [(r, 1.3), (r * 0.55, 1.2)] {
                var arc = Path()
                arc.addArc(center: c, radius: radius, startAngle: .degrees(120), endAngle: .degrees(60), clockwise: false)
                ctx.stroke(arc, with: .foreground, style: StrokeStyle(lineWidth: width, lineCap: .round))
            }
            var cone = Path()
            cone.move(to: CGPoint(x: c.x, y: c.y + r * 0.15))
            cone.addLine(to: CGPoint(x: c.x - r * 0.42, y: size.height))
            cone.addLine(to: CGPoint(x: c.x + r * 0.42, y: size.height))
            cone.closeSubpath()
            ctx.fill(cone, with: .foreground)
        }
    }
}
