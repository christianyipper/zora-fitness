import SwiftUI

struct FlameView: View {
    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            // Incommensurable frequencies → natural, non-repeating visual
            let sway    = sin(t * 4.0) * 3.2          // ±3.2° rotation
            let flicker = 1.0 + sin(t * 7.3) * 0.035  // ±3.5 % height scale
            let drift   = sin(t * 5.7) * 0.03          // inner flame lateral drift
            let innerH  = 0.68 + sin(t * 6.1) * 0.05  // inner flame height fraction

            Canvas { ctx, size in
                let w = size.width
                let h = size.height * flicker

                // ── Outer flame: orange-red ───────────────────────
                let outer = flamePath(w: w, h: h, lean: sway * 0.015)
                ctx.fill(outer, with: .linearGradient(
                    Gradient(stops: [
                        .init(color: Color(red: 1.00, green: 0.33, blue: 0.08), location: 0.0),
                        .init(color: Color(red: 1.00, green: 0.50, blue: 0.09), location: 0.45),
                        .init(color: Color(red: 1.00, green: 0.78, blue: 0.30), location: 1.0),
                    ]),
                    startPoint: CGPoint(x: w / 2, y: h),
                    endPoint: CGPoint(x: w / 2, y: 0)
                ))

                // ── Mid flame: orange-yellow ──────────────────────
                let mw = w * 0.62
                let mh = h * innerH
                let mx = (w - mw) / 2 + w * drift
                let my = h - mh
                let mid = flamePath(w: mw, h: mh, lean: -sway * 0.008, xOff: mx, yOff: my)
                ctx.fill(mid, with: .linearGradient(
                    Gradient(stops: [
                        .init(color: Color(red: 1.00, green: 0.62, blue: 0.10), location: 0.0),
                        .init(color: Color(red: 1.00, green: 0.88, blue: 0.44), location: 0.55),
                        .init(color: Color.white.opacity(0.90),               location: 1.0),
                    ]),
                    startPoint: CGPoint(x: w / 2, y: h),
                    endPoint: CGPoint(x: w / 2, y: 0)
                ))

                // ── White tip highlight ───────────────────────────
                let tw = mw * 0.38
                let th = mh * 0.30
                let tx = mx + (mw - tw) / 2
                let ty = my
                let tip = flamePath(w: tw, h: th, lean: 0, xOff: tx, yOff: ty)
                ctx.fill(tip, with: .color(.white.opacity(0.75)))
            }
            .rotationEffect(.degrees(sway))
        }
    }

    // Generic teardrop-flame bezier, leaning by `lean` fraction of width.
    private func flamePath(
        w: CGFloat, h: CGFloat, lean: Double,
        xOff: CGFloat = 0, yOff: CGFloat = 0
    ) -> Path {
        let leanX = CGFloat(lean) * w
        var p = Path()
        p.move(to: CGPoint(x: xOff + w * 0.50,        y: yOff + h))
        // left side
        p.addCurve(
            to:        CGPoint(x: xOff + w * 0.10,        y: yOff + h * 0.52),
            control1:  CGPoint(x: xOff + w * 0.18,        y: yOff + h * 0.98),
            control2:  CGPoint(x: xOff - w * 0.02,        y: yOff + h * 0.74)
        )
        // upper-left to tip
        p.addCurve(
            to:        CGPoint(x: xOff + w * 0.50 + leanX, y: yOff),
            control1:  CGPoint(x: xOff + w * 0.09,        y: yOff + h * 0.30),
            control2:  CGPoint(x: xOff + w * 0.34 + leanX, y: yOff + h * 0.06)
        )
        // upper-right from tip
        p.addCurve(
            to:        CGPoint(x: xOff + w * 0.90,        y: yOff + h * 0.48),
            control1:  CGPoint(x: xOff + w * 0.66 + leanX, y: yOff + h * 0.06),
            control2:  CGPoint(x: xOff + w * 0.95,        y: yOff + h * 0.28)
        )
        // right side down
        p.addCurve(
            to:        CGPoint(x: xOff + w * 0.50,        y: yOff + h),
            control1:  CGPoint(x: xOff + w * 0.88,        y: yOff + h * 0.70),
            control2:  CGPoint(x: xOff + w * 0.82,        y: yOff + h * 0.98)
        )
        p.closeSubpath()
        return p
    }
}
