import SwiftUI

/// Annular slice from `start` to `end` (radians, 0 = twelve o'clock, clockwise).
struct RingSlice: Shape {
    var start: Double
    var end: Double
    var inner: CGFloat
    var gap: CGFloat = 0.012

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        // SwiftUI angles run clockwise from three o'clock in a flipped space.
        func a(_ v: Double) -> Angle { .radians(v - .pi / 2) }
        var p = Path()
        p.addArc(center: c, radius: outer, startAngle: a(start + gap), endAngle: a(end - gap), clockwise: false)
        p.addArc(center: c, radius: inner, startAngle: a(end - gap * 2.2), endAngle: a(start + gap * 2.2), clockwise: true)
        p.closeSubpath()
        return p
    }
}

struct LensView: View {
    @Bindable var model: LensModel

    private var accent: [Color] {
        switch model.mode {
        case .convert: [Color(red: 0.36, green: 0.42, blue: 1.0), Color(red: 0.18, green: 0.77, blue: 1.0)]
        case .tools: [Color(red: 0.55, green: 0.33, blue: 1.0), Color(red: 0.93, green: 0.36, blue: 0.86)]
        case .actions: [Color(red: 0.10, green: 0.72, blue: 0.62), Color(red: 0.42, green: 0.86, blue: 0.40)]
        }
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let ringOuter = size / 2 - 8
            let inner = LensPanel.innerRadius
            let n = max(model.items.count, 1)
            let slice = 2 * Double.pi / Double(n)
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1))
                    .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
                    .padding(8)

                ForEach(Array(model.items.enumerated()), id: \.element.id) { i, item in
                    let mid = Double(i) * slice
                    let isHot = model.hovered == i
                    RingSlice(start: mid - slice / 2, end: mid + slice / 2, inner: inner + 4)
                        .fill(isHot
                              ? AnyShapeStyle(LinearGradient(colors: accent, startPoint: .topLeading, endPoint: .bottomTrailing))
                              : AnyShapeStyle(Color.primary.opacity(0.06)))
                        .padding(14)
                        .scaleEffect(isHot ? 1.03 : 1)
                    let r = (ringOuter + inner) / 2 + 2
                    VStack(spacing: 4) {
                        Image(systemName: item.symbol).font(.system(size: 17, weight: .semibold))
                        Text(item.label).font(.system(size: 11, weight: .semibold, design: .rounded)).lineLimit(1)
                    }
                    .foregroundStyle(isHot ? Color.white : Color.primary.opacity(0.85))
                    .frame(width: 78)
                    .offset(x: r * sin(mid), y: -r * cos(mid))
                }

                VStack(spacing: 2) {
                    Text(model.title.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1.2)
                        .foregroundStyle(LinearGradient(colors: accent, startPoint: .leading, endPoint: .trailing))
                    Text(model.hovered.flatMap { model.items.indices.contains($0) ? model.items[$0].label : nil }
                         ?? model.emptyMessage ?? "Drop on a slice")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .frame(width: inner * 1.7, height: inner * 1.7)
                .background(Circle().fill(.regularMaterial))
            }
            .frame(width: size, height: size)
            .animation(.spring(response: 0.22, dampingFraction: 0.75), value: model.hovered)
        }
    }
}
