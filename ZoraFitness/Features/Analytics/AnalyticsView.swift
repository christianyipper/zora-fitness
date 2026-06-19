import SwiftUI
import Charts

struct AnalyticsView: View {
    @Environment(HealthKitManager.self) private var healthKit
    @Environment(SettingsStore.self)    private var settings
    @State private var viewModel = AnalyticsViewModel()
    @State private var showProfile = false

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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    AvatarButton(initials: initialsFromName(settings.officialName.isEmpty ? "You" : settings.officialName)) {
                        showProfile = true
                    }
                }
            }
            .sheet(isPresented: $showProfile) { ProfileView() }
        }
        .task { await viewModel.load(using: healthKit) }
    }

    // MARK: - Activity Calendar

    private struct MonthGroup: Identifiable {
        let monthName: String
        let monthKey: String
        let weeks: [[CalendarDay]]
        var id: String { monthKey }
    }

    private var monthGroups: [MonthGroup] {
        let days = viewModel.calendarDays
        guard !days.isEmpty else { return [] }
        let cal = Calendar.current
        let keyFmt = DateFormatter()
        keyFmt.dateFormat = "yyyy-MM"
        let labelFmt = DateFormatter()
        labelFmt.dateFormat = "MMM"

        var weeks: [[CalendarDay]] = []
        var i = 0
        while i < days.count {
            weeks.append(Array(days[i..<min(i + 7, days.count)]))
            i += 7
        }

        var groups: [MonthGroup] = []
        var currentKey: String? = nil
        var currentLabel = ""
        var currentWeeks: [[CalendarDay]] = []

        for week in weeks {
            guard let first = week.first else { continue }
            let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: first.date))!
            let key = keyFmt.string(from: monthStart)
            if key != currentKey {
                if !currentWeeks.isEmpty, let k = currentKey {
                    groups.append(MonthGroup(monthName: currentLabel, monthKey: k, weeks: currentWeeks))
                }
                currentKey = key
                currentLabel = labelFmt.string(from: monthStart).uppercased()
                currentWeeks = [week]
            } else {
                currentWeeks.append(week)
            }
        }
        if !currentWeeks.isEmpty, let k = currentKey {
            groups.append(MonthGroup(monthName: currentLabel, monthKey: k, weeks: currentWeeks))
        }
        return groups
    }

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ACTIVITY · 14 WEEKS")
                    .font(AppTheme.label)
                    .foregroundStyle(AppTheme.secondaryText)
                    .tracking(1.4)
                Spacer()
                HStack(spacing: 8) {
                    legendChip(color: AppTheme.strainBlue,              label: "Goal")
                    legendChip(color: AppTheme.strainBlue.opacity(0.4), label: "Partial")
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .trailing, spacing: 4) {
                        ForEach(["M", "", "W", "", "F", "", "S"], id: \.self) { lbl in
                            Text(lbl)
                                .font(.system(size: 9))
                                .foregroundStyle(AppTheme.tertiaryText)
                                .frame(width: 10, height: 14)
                        }
                        Color.clear.frame(height: 16)
                    }
                    .padding(.trailing, 6)

                    HStack(alignment: .top, spacing: 4) {
                        ForEach(monthGroups) { group in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .top, spacing: 4) {
                                    ForEach(group.weeks.indices, id: \.self) { wi in
                                        VStack(spacing: 4) {
                                            ForEach(group.weeks[wi]) { day in
                                                calendarCell(day)
                                            }
                                        }
                                    }
                                }
                                Text(group.monthName)
                                    .font(AppTheme.micro)
                                    .foregroundStyle(AppTheme.tertiaryText)
                                    .tracking(1.0)
                            }
                        }
                    }
                }
            }
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius))
    }

    private func calendarCell(_ day: CalendarDay) -> some View {
        let color: Color = {
            switch day.level {
            case .achieved:        return AppTheme.strainBlue
            case .partial:         return AppTheme.strainBlue.opacity(0.4)
            case .missed:          return Color(white: 0.15)
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
