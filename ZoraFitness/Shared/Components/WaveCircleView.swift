import SwiftUI

struct WaveCircleView: View {
    let progress: Double   // 0–1
    let color: Color

    @State private var fill: Double = 0

    var body: some View {
        TimelineView(.animation) { tl in
            let phase = tl.date.timeIntervalSinceReferenceDate * 1.6
            canvas(phase: phase)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) { fill = progress }
        }
        .onChange(of: progress) { _, new in
            withAnimation(.easeOut(duration: 0.8)) { fill = new }
        }
    }

    private func canvas(phase: Double) -> some View {
        ZStack {
            // ── Liquid fill (two waves for depth) ────────────────
            ZStack {
                WaveShape(progress: fill, phase: phase + 1.7)
                    .fill(color.opacity(0.42))
                WaveShape(progress: fill, phase: phase)
                    .fill(color.opacity(0.82))
            }
            .clipShape(Circle())

            // ── Top-light gloss ───────────────────────────────────
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.10), .clear],
                        startPoint: .top,
                        endPoint: UnitPoint(x: 0.5, y: 0.55)
                    )
                )
        }
    }
}

private struct WaveShape: Shape {
    var progress: Double
    var phase: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { .init(progress, phase) }
        set { progress = newValue.first; phase = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let clamped = min(1, max(0, progress))
        let waveY   = h * (1 - clamped)
        let amp     = h * 0.044   // wave amplitude ≈ 4.4 % of height

        var path = Path()
        path.move(to: CGPoint(x: 0, y: waveY + CGFloat(amp * sin(phase))))

        var x: CGFloat = 2
        while x <= w {
            let relX = Double(x / w)
            let y    = waveY + CGFloat(amp * sin(relX * .pi * 4 + phase))
            path.addLine(to: CGPoint(x: x, y: y))
            x += 2
        }

        path.addLine(to: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: 0, y: h))
        path.closeSubpath()
        return path
    }
}
