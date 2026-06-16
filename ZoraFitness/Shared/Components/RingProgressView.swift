import SwiftUI

/// Circular progress ring. The caller is responsible for animating `progress`.
struct RingProgressView: View {
    let progress: Double    // 0.0–1.0
    let color: Color
    let trackColor: Color
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress.clamped(to: 0...1))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}
