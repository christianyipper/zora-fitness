import SwiftUI

struct WorkoutDetailView: View {
    let session: WorkoutSession
    let maxHeartRate: Double

    @Environment(\.dismiss) private var dismiss

    private var strainScore: StrainScore {
        StrainCalculator.calculate(input: StrainInput(
            workoutSessions: [session],
            activeCalories: 0,
            steps: 0,
            maxHeartRate: maxHeartRate
        ))
    }

    private var zones: [(label: String, range: String, duration: TimeInterval, color: Color)] {
        let z = session.heartRateZones
        return [
            ("Recovery",  "50–60%", z.zone1, AppTheme.zoneColor(1)),
            ("Aerobic",   "60–70%", z.zone2, AppTheme.zoneColor(2)),
            ("Tempo",     "70–80%", z.zone3, AppTheme.zoneColor(3)),
            ("Threshold", "80–90%", z.zone4, AppTheme.zoneColor(4)),
            ("Anaerobic", "90%+",   z.zone5, AppTheme.zoneColor(5)),
        ]
    }

    private var totalZoneTime: TimeInterval {
        session.heartRateZones.total
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppTheme.sectionGap) {
                        headerCard
                        statsGrid
                        if totalZoneTime > 60 {
                            hrZoneCard
                        }
                        performanceCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppTheme.strainBlue)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.strainBlue.opacity(0.14))
                    .frame(width: 72, height: 72)
                Image(systemName: session.activityType.systemImage)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(AppTheme.strainBlue)
            }

            VStack(spacing: 6) {
                Text(session.activityName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)

                Text(session.startDate.formatted(.dateTime.weekday(.wide).month(.wide).day().hour().minute()))
                    .font(AppTheme.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            // Strain pill
            let score = strainScore
            HStack(spacing: 6) {
                Text(String(format: "%.1f", score.score))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.strainBlue)
                Text("strain · \(score.category.rawValue)")
                    .font(AppTheme.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(AppTheme.strainBlue.opacity(0.12), in: Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.cardPadding)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius))
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        let items: [(String, String, String)] = statItems
        let columns = [GridItem(.flexible()), GridItem(.flexible())]

        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(items, id: \.0) { item in
                statCell(label: item.0, value: item.1, unit: item.2)
            }
        }
    }

    private var statItems: [(String, String, String)] {
        var items: [(String, String, String)] = [
            ("Duration",  session.formattedDuration, ""),
            ("Calories",  "\(Int(session.activeCalories))", "kcal"),
        ]
        if let dist = session.formattedDistance {
            items.append(("Distance", dist, ""))
        }
        if let avg = session.averageHeartRate {
            items.append(("Avg HR", "\(Int(avg))", "bpm"))
        }
        if let max = session.maxHeartRate {
            items.append(("Max HR", "\(Int(max))", "bpm"))
        }
        if let zone = strainScore.dominantZone {
            items.append(("Peak Zone", "Zone \(zone)", ""))
        }
        return items
    }

    private func statCell(label: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(AppTheme.label)
                .foregroundStyle(AppTheme.secondaryText)
                .tracking(1.2)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.primaryText)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                if !unit.isEmpty {
                    Text(unit)
                        .font(AppTheme.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.innerRadius))
    }

    // MARK: - HR Zone Card

    private var hrZoneCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("HEART RATE ZONES")

            VStack(spacing: 10) {
                ForEach(Array(zones.enumerated()), id: \.offset) { index, zone in
                    zoneRow(zone: zone, zoneNumber: index + 1)
                }
            }

            // Stacked zone bar at the bottom
            GeometryReader { proxy in
                HStack(spacing: 2) {
                    ForEach(Array(zones.enumerated()), id: \.offset) { _, zone in
                        let fraction = totalZoneTime > 0 ? zone.duration / totalZoneTime : 0
                        if fraction > 0.01 {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(zone.color)
                                .frame(width: proxy.size.width * fraction)
                        }
                    }
                }
                .frame(height: 8)
                .clipShape(Capsule())
            }
            .frame(height: 8)
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius))
    }

    private func zoneRow(zone: (label: String, range: String, duration: TimeInterval, color: Color), zoneNumber: Int) -> some View {
        let fraction = totalZoneTime > 0 ? zone.duration / totalZoneTime : 0
        let minutes = Int(zone.duration) / 60
        let seconds = Int(zone.duration) % 60

        return HStack(spacing: 10) {
            // Zone number dot
            ZStack {
                Circle().fill(zone.color.opacity(0.2)).frame(width: 26, height: 26)
                Text("\(zoneNumber)")
                    .font(AppTheme.label)
                    .foregroundStyle(zone.color)
            }

            // Label + range
            VStack(alignment: .leading, spacing: 1) {
                Text(zone.label)
                    .font(AppTheme.caption)
                    .foregroundStyle(AppTheme.primaryText)
                Text(zone.range)
                    .font(AppTheme.micro)
                    .foregroundStyle(AppTheme.tertiaryText)
            }
            .frame(width: 74, alignment: .leading)

            // Progress bar
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(white: 0.16))
                    Capsule()
                        .fill(zone.color.opacity(0.85))
                        .frame(width: proxy.size.width * fraction.clamped(to: 0...1))
                }
            }
            .frame(height: 6)

            // Time
            Text(minutes > 0 ? "\(minutes)m \(seconds)s" : "\(seconds)s")
                .font(AppTheme.caption)
                .foregroundStyle(AppTheme.secondaryText)
                .monospacedDigit()
                .frame(width: 52, alignment: .trailing)
        }
    }

    // MARK: - Performance Card

    private var performanceCard: some View {
        let score = strainScore
        return VStack(alignment: .leading, spacing: 10) {
            sectionLabel("PERFORMANCE SUMMARY")
            Text(score.categoryDescription)
                .font(AppTheme.body)
                .foregroundStyle(AppTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.cardPadding)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius))
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(AppTheme.label)
            .foregroundStyle(AppTheme.secondaryText)
            .tracking(1.5)
    }
}
