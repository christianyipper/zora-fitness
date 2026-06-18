import SwiftUI
import Charts

struct AnalyticsView: View {
    @Environment(HealthKitManager.self) private var healthKit
    @Environment(SettingsStore.self)    private var settings
    @State private var viewModel = AnalyticsViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                if viewModel.isLoading {
                    VStack(spacing: 14) {
                        ProgressView().tint(.white).scaleEffect(1.4)
                        Text("Analyzing 30 days…")
                            .font(AppTheme.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: AppTheme.sectionGap) {
                            periodLabel
                            if !viewModel.calendarDays.isEmpty {
                                calendarCard
                            }
                            hrvCard
                            strainCard
                            sleepCard
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                    }
                    .refreshable { await viewModel.load(using: healthKit) }
                }
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .task { await viewModel.load(using: healthKit) }
    }

    // MARK: - Activity Calendar

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ACTIVITY CALENDAR · 13 WEEKS")
                    .font(AppTheme.label)
                    .foregroundStyle(AppTheme.secondaryText)
                    .tracking(1.4)
                Spacer()
                // Legend
                HStack(spacing: 8) {
                    legendChip(color: AppTheme.strainBlue,              label: "Goal")
                    legendChip(color: AppTheme.strainBlue.opacity(0.4), label: "Partial")
                    legendChip(color: Color(white: 0.18),               label: "Rest")
                }
            }

            calendarGrid
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius))
    }

    private var calendarGrid: some View {
        // Days are ordered Mon→Sun per column (week).
        // Slice into 7-row columns.
        let days = viewModel.calendarDays
        let numCols = (days.count + 6) / 7   // ceil(days / 7)
        let columns = Array(repeating: GridItem(.fixed(14), spacing: 4), count: numCols)

        return HStack(alignment: .top, spacing: 6) {
            // Day-of-week labels
            VStack(alignment: .trailing, spacing: 4) {
                ForEach(["M", "", "W", "", "F", "", "S"], id: \.self) { label in
                    Text(label)
                        .font(.system(size: 9))
                        .foregroundStyle(AppTheme.tertiaryText)
                        .frame(width: 10, height: 14)
                }
            }

            // Grid: column = week, row = day of week (Mon=0…Sun=6)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(days) { day in
                        calendarCell(day)
                    }
                }
            }
        }
    }

    private func calendarCell(_ day: CalendarDay) -> some View {
        let color: Color = {
            switch day.level {
            case .achieved: return AppTheme.strainBlue
            case .partial:  return AppTheme.strainBlue.opacity(0.4)
            case .missed:   return Color(white: 0.15)
            case .noData, .future: return Color(white: 0.08)
            }
        }()
        return RoundedRectangle(cornerRadius: 3)
            .fill(color)
            .frame(width: 14, height: 14)
    }

    private func legendChip(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(AppTheme.micro)
                .foregroundStyle(AppTheme.tertiaryText)
        }
    }

    // MARK: - Period Label

    private var periodLabel: some View {
        let end   = Date.now
        let start = Calendar.current.date(byAdding: .day, value: -30, to: end)!
        return HStack {
            Text("30-DAY OVERVIEW")
                .font(AppTheme.label)
                .foregroundStyle(AppTheme.secondaryText)
                .tracking(1.4)
            Spacer()
            Text("\(start.formatted(.dateTime.month(.abbreviated).day())) – \(end.formatted(.dateTime.month(.abbreviated).day()))")
                .font(AppTheme.micro)
                .foregroundStyle(AppTheme.tertiaryText)
        }
    }

    // MARK: - HRV Card

    private var hrvCard: some View {
        ChartCard(
            title: "HRV",
            unit: "Heart Rate Variability · ms",
            current: viewModel.hrvHistory.last.map { "\(Int($0.value)) ms" },
            trend: viewModel.trend(for: viewModel.hrvHistory),
            isHigherBetter: true,
            stats: viewModel.statsRow(for: viewModel.hrvHistory) { "\(Int($0)) ms" }
        ) {
            let baseline = viewModel.hrvBaseline
            Chart {
                ForEach(viewModel.hrvHistory) { point in
                    BarMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("HRV", point.value)
                    )
                    .foregroundStyle(point.value >= baseline
                        ? AppTheme.recoveryGreen.opacity(0.85)
                        : AppTheme.recoveryRed.opacity(0.75))
                    .cornerRadius(3)
                }
                if baseline > 0 {
                    RuleMark(y: .value("Baseline", baseline))
                        .foregroundStyle(Color.white.opacity(0.30))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("avg \(Int(baseline)) ms")
                                .font(AppTheme.micro)
                                .foregroundStyle(AppTheme.tertiaryText)
                        }
                }
            }
            .chartXAxis { dateAxis }
            .chartYAxis { valueAxis }
            .chartPlotStyle { $0.background(Color.clear) }
        }
    }

    // MARK: - Strain Card

    private var strainCard: some View {
        let weeklyAvg = viewModel.strainHistory.suffix(7).map(\.value).mean

        return ChartCard(
            title: "Daily Strain",
            unit: "Workout cardiovascular load · 0–21",
            current: weeklyAvg > 0 ? String(format: "%.1f wk avg", weeklyAvg) : nil,
            trend: 0,   // strain trend is neutral — not directionally good or bad
            stats: viewModel.statsRow(for: viewModel.strainHistory) { String(format: "%.1f", $0) }
        ) {
            Chart {
                ForEach(viewModel.strainHistory) { point in
                    BarMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Strain", point.value)
                    )
                    .foregroundStyle(strainColor(point.value))
                    .cornerRadius(3)
                }
            }
            .chartYScale(domain: 0...21)
            .chartXAxis { dateAxis }
            .chartYAxis { valueAxis }
            .chartPlotStyle { $0.background(Color.clear) }
        }
    }

    // MARK: - Sleep Card

    private var sleepCard: some View {
        let lastDuration = viewModel.sleepHistory.last?.formattedDuration

        return ChartCard(
            title: "Sleep",
            unit: "Nightly total duration · hours",
            current: lastDuration,
            trend: viewModel.sleepTrend,
            isHigherBetter: true,
            stats: viewModel.sleepStatsRow()
        ) {
            Chart {
                ForEach(viewModel.sleepHistory, id: \.date) { session in
                    BarMark(
                        x: .value("Date", session.date, unit: .day),
                        y: .value("Hours", session.totalDuration / 3600)
                    )
                    .foregroundStyle(session.totalDuration >= settings.sleepTargetHours * 3600
                        ? AppTheme.sleepPurple.opacity(0.85)
                        : AppTheme.recoveryYellow.opacity(0.80))
                    .cornerRadius(3)
                }
                // User-configured sleep target line
                let target = settings.sleepTargetHours
                RuleMark(y: .value("Target", target))
                    .foregroundStyle(Color.white.opacity(0.28))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("\(settings.sleepTargetFormatted) target")
                            .font(AppTheme.micro)
                            .foregroundStyle(AppTheme.tertiaryText)
                    }
            }
            .chartYScale(domain: 0...11)
            .chartXAxis { dateAxis }
            .chartYAxis { valueAxis }
            .chartPlotStyle { $0.background(Color.clear) }
        }
    }

    // MARK: - Shared Axis Configs

    @AxisContentBuilder
    private var dateAxis: some AxisContent {
        AxisMarks(values: .stride(by: .day, count: 7)) { value in
            if let date = value.as(Date.self) {
                AxisValueLabel {
                    Text(date, format: .dateTime.month(.abbreviated).day())
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.tertiaryText)
                }
            }
            AxisGridLine().foregroundStyle(Color(white: 0.15))
        }
    }

    @AxisContentBuilder
    private var valueAxis: some AxisContent {
        AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
            AxisValueLabel()
                .foregroundStyle(AppTheme.tertiaryText)
            AxisGridLine().foregroundStyle(Color(white: 0.12))
        }
    }

    // MARK: - Helpers

    private func strainColor(_ value: Double) -> Color {
        switch value {
        case 0..<8:  return AppTheme.strainBlue.opacity(0.55)
        case 8..<14: return AppTheme.strainBlue
        case 14..<18: return AppTheme.recoveryYellow
        default:     return AppTheme.recoveryRed
        }
    }
}
