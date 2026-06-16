import SwiftUI

/// A themed card wrapper for a Swift Charts chart. Handles the title, current
/// value, trend badge, and a min/avg/max stats row — the caller supplies the
/// chart content via a @ViewBuilder closure.
struct ChartCard<C: View>: View {
    let title: String
    let unit: String
    let current: String?
    let trend: Double          // % change, last 7d vs prior 7d
    let isHigherBetter: Bool   // controls trend badge color
    let stats: [(String, String)]
    let chart: C

    init(
        title: String,
        unit: String,
        current: String? = nil,
        trend: Double = 0,
        isHigherBetter: Bool = true,
        stats: [(String, String)] = [],
        @ViewBuilder chart: () -> C
    ) {
        self.title = title
        self.unit = unit
        self.current = current
        self.trend = trend
        self.isHigherBetter = isHigherBetter
        self.stats = stats
        self.chart = chart()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerRow
            chart.frame(height: 130)
            if !stats.isEmpty { statsRow }
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius))
    }

    // MARK: - Subviews

    private var headerRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
                    .font(AppTheme.label)
                    .foregroundStyle(AppTheme.secondaryText)
                    .tracking(1.5)
                Text(unit)
                    .font(AppTheme.micro)
                    .foregroundStyle(AppTheme.tertiaryText)
            }
            Spacer()
            if let current {
                VStack(alignment: .trailing, spacing: 3) {
                    Text(current)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.primaryText)
                        .monospacedDigit()
                    trendBadge
                }
            }
        }
    }

    @ViewBuilder
    private var trendBadge: some View {
        if abs(trend) > 0.5 {
            let good  = isHigherBetter ? trend > 0 : trend < 0
            let arrow = trend > 0 ? "↑" : "↓"
            Text("\(arrow) \(String(format: "%.0f", abs(trend)))%")
                .font(AppTheme.micro)
                .foregroundStyle(good ? AppTheme.recoveryGreen : AppTheme.recoveryRed)
                .tracking(0.5)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(stats.enumerated()), id: \.offset) { index, stat in
                VStack(spacing: 3) {
                    Text(stat.0.uppercased())
                        .font(AppTheme.micro)
                        .foregroundStyle(AppTheme.tertiaryText)
                        .tracking(0.8)
                    Text(stat.1)
                        .font(AppTheme.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                        .monospacedDigit()
                }
                if index < stats.count - 1 { Spacer() }
            }
        }
        .padding(.top, 2)
    }
}
