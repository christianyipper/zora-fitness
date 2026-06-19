import SwiftUI

// MARK: - ViewModel

@Observable
@MainActor
final class ProfileViewModel {
    var calendarDays: [CalendarDay] = []
    var currentStreak: Int = 0
    var totalGamesWorked: Int = 0
    var totalCrewStars: Int = 8
    var officialNumber: String? = nil
    var isLoading = false

    func load(using healthKit: HealthKitManager, officialName: String) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        if let activity = try? await healthKit.fetchActivityHistory(days: 120) {
            currentStreak = computeStreak(from: activity)
            calendarDays  = buildCalendarDays(from: activity)
        }

        let trimmed = officialName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let client = BCHLAPIClient()
        async let games   = try? client.fetchTotalGamesWorked(for: trimmed)
        async let numbers = try? client.fetchOfficialNumbers(for: trimmed)

        totalGamesWorked = await games ?? 0
        if let (rNum, lNum) = await numbers {
            officialNumber = rNum ?? lNum
        }
    }

    private func computeStreak(
        from history: [(date: Date, steps: Double, exerciseMinutes: Double)]
    ) -> Int {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: .now)
        let isActive = { (s: Double, e: Double) in s >= 8000 || e >= 30 }

        let pastDays = history
            .filter { cal.startOfDay(for: $0.date) < today }
            .sorted { $0.date > $1.date }

        var streak = 0
        var expected = cal.date(byAdding: .day, value: -1, to: today)!
        for day in pastDays {
            let dayStart = cal.startOfDay(for: day.date)
            guard dayStart == expected else { break }
            if isActive(day.steps, day.exerciseMinutes) {
                streak += 1
                expected = cal.date(byAdding: .day, value: -1, to: dayStart)!
            } else { break }
        }
        return streak
    }

    private func buildCalendarDays(
        from history: [(date: Date, steps: Double, exerciseMinutes: Double)]
    ) -> [CalendarDay] {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: .now)
        let lookup = Dictionary(uniqueKeysWithValues: history.map {
            (cal.startOfDay(for: $0.date), ($0.steps, $0.exerciseMinutes))
        })
        let rawStart  = cal.date(byAdding: .day, value: -97, to: today)!
        let weekday   = cal.component(.weekday, from: rawStart)
        let offsetToMonday = (weekday == 1) ? -6 : -(weekday - 2)
        let gridStart = cal.date(byAdding: .day, value: offsetToMonday, to: rawStart)!

        var days: [CalendarDay] = []
        var cursor = gridStart
        while cursor <= today {
            let level: ActivityLevel
            if let (s, e) = lookup[cursor] {
                if s >= 8000 || e >= 30      { level = .achieved }
                else if s >= 4000 || e >= 15 { level = .partial  }
                else                          { level = .missed   }
            } else { level = .missed }
            days.append(CalendarDay(date: cursor, level: level))
            cursor = cal.date(byAdding: .day, value: 1, to: cursor)!
        }
        return days
    }
}

// MARK: - View

struct ProfileView: View {
    @Environment(HealthKitManager.self) private var healthKit
    @Environment(SettingsStore.self)    private var settings
    @State private var viewModel = ProfileViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppTheme.sectionGap) {
                        identityHeader
                        statBadgesRow
                        if !viewModel.calendarDays.isEmpty {
                            calendarCard
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .task { await viewModel.load(using: healthKit, officialName: settings.officialName) }
    }

    // MARK: - Identity Header

    private var identityHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.strainBlue.opacity(0.18))
                    .frame(width: 80, height: 80)
                Text(initialsFromName(settings.officialName.isEmpty ? "You" : settings.officialName))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppTheme.strainBlue)
            }

            VStack(spacing: 6) {
                Text(settings.officialName.isEmpty ? "Your Name" : settings.officialName)
                    .font(AppTheme.headline)
                    .foregroundStyle(AppTheme.primaryText)

                Text("BCHL")
                    .font(AppTheme.micro)
                    .foregroundStyle(AppTheme.strainBlue)
                    .tracking(1.4)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AppTheme.strainBlue.opacity(0.14), in: Capsule())

                if let num = viewModel.officialNumber {
                    Text("#\(num)")
                        .font(AppTheme.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                        .tracking(0.8)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.cardPadding)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius))
    }

    // MARK: - Stat Badges

    private var statBadgesRow: some View {
        HStack(spacing: AppTheme.sectionGap) {
            statBadge(
                icon: "flame.fill",
                label: "STREAK",
                value: viewModel.currentStreak > 0 ? "\(viewModel.currentStreak)" : "--",
                unit: "days",
                color: Color(red: 1.0, green: 0.52, blue: 0.05)
            )
            statBadge(
                icon: "star.fill",
                label: "CREW STARS",
                value: "\(viewModel.totalCrewStars)",
                unit: "total",
                color: AppTheme.recoveryYellow
            )
            statBadge(
                icon: "flag.checkered.2.crossed",
                label: "GAMES",
                value: viewModel.totalGamesWorked > 0 ? "\(viewModel.totalGamesWorked)" : "--",
                unit: "worked",
                color: AppTheme.strainBlue
            )
        }
    }

    private func statBadge(icon: String, label: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.primaryText)
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(AppTheme.micro)
                .foregroundStyle(AppTheme.secondaryText)
                .tracking(1.2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: AppTheme.innerRadius))
    }

    // MARK: - Calendar

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
}
