import SwiftUI

struct DashboardView: View {
    @Environment(HealthKitManager.self) private var healthKit
    @Environment(SettingsStore.self)    private var settings
    @State private var viewModel = DashboardViewModel()
    @State private var calendarMonthOffset = 0
    @State private var showProfile = false
    @State private var showReadinessDetail = false
    @State private var selectedWorkout: WorkoutSession? = nil

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            if viewModel.isLoading && viewModel.recoveryScore == nil {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.4)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: AppTheme.sectionGap) {
                        header
                        recoveryCard
                        if let w = viewModel.mostRecentWorkout {
                            lastWorkoutCard(w)
                        }
                        if !viewModel.calendarDays.isEmpty {
                            activityCalendarCard
                        }
                        if let game = viewModel.recentGame {
                            recentGameCard(game)
                        }
                        strainCard
                        biometricsRow
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
                .refreshable { await viewModel.load(using: healthKit, officialName: settings.officialName) }
            }
        }
        .task { await viewModel.load(using: healthKit, officialName: settings.officialName) }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text(greeting)
                    .font(AppTheme.label)
                    .foregroundStyle(AppTheme.secondaryText)
                    .tracking(1.4)
                Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(AppTheme.subheadline)
                    .foregroundStyle(AppTheme.primaryText)
            }
            Spacer()
            AvatarButton(initials: initialsFromName(settings.officialName.isEmpty ? "You" : settings.officialName)) {
                showProfile = true
            }
        }
        .padding(.top, 4)
        .sheet(isPresented: $showProfile) { ProfileView() }
    }

    // MARK: - Stats Badge Row

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

    // MARK: - Recent Game Card

    private func recentGameCard(_ game: OfficialGame) -> some View {
        VStack(spacing: 16) {
            sectionLabel("LAST GAME")

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(game.homeTeam)
                        .font(AppTheme.subheadline)
                        .foregroundStyle(AppTheme.primaryText)
                    Text("HOME")
                        .font(AppTheme.micro)
                        .foregroundStyle(AppTheme.secondaryText)
                        .tracking(1.1)
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(game.formattedDate)
                        .font(AppTheme.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                    if let range = game.timeRange {
                        Text(range)
                            .font(AppTheme.micro)
                            .foregroundStyle(AppTheme.tertiaryText)
                    }
                    Text(game.formattedDuration)
                        .font(AppTheme.label)
                        .foregroundStyle(AppTheme.primaryText)
                        .padding(.top, 2)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(game.awayTeam)
                        .font(AppTheme.subheadline)
                        .foregroundStyle(AppTheme.primaryText)
                    Text("AWAY")
                        .font(AppTheme.micro)
                        .foregroundStyle(AppTheme.secondaryText)
                        .tracking(1.1)
                }
            }

            HStack {
                penaltyPill(minutes: game.homePIM)
                Spacer()
                Text("PENALTY MIN")
                    .font(AppTheme.micro)
                    .foregroundStyle(AppTheme.tertiaryText)
                    .tracking(1.1)
                Spacer()
                penaltyPill(minutes: game.awayPIM)
            }

            Divider()
                .background(Color(white: 0.2))

            if !game.referees.isEmpty {
                officialRow(title: "REFS", names: game.referees)
            }
            if !game.linespersons.isEmpty {
                officialRow(title: "LINES", names: game.linespersons)
            }
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius))
    }

    private func penaltyPill(minutes: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(minutes)")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(minutes > 10 ? AppTheme.recoveryRed : AppTheme.primaryText)
                .monospacedDigit()
            Text("PIM")
                .font(AppTheme.micro)
                .foregroundStyle(AppTheme.secondaryText)
                .tracking(1.1)
        }
    }

    private func officialRow(title: String, names: [String]) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title)
                .font(AppTheme.micro)
                .foregroundStyle(AppTheme.secondaryText)
                .tracking(1.2)
                .frame(width: 40, alignment: .leading)
            Text(names.joined(separator: "  ·  "))
                .font(AppTheme.caption)
                .foregroundStyle(AppTheme.primaryText)
            Spacer()
        }
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 0..<12: return "GOOD MORNING"
        case 12..<17: return "GOOD AFTERNOON"
        default:      return "GOOD EVENING"
        }
    }

    // MARK: - Recovery Card

    private var recoveryCard: some View {
        VStack(spacing: 20) {
            sectionLabel("RECOVERY")
            tripleRingCluster
            statBadgesRow
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius))
    }

    private var tripleRingCluster: some View {
        let sleepFraction  = ((viewModel.recoveryScore?.sleepComponent ?? 0) / 100).clamped(to: 0...1)
        let strainFraction = ((viewModel.strainScore?.score ?? 0) / 21).clamped(to: 0...1)
        let recoveryColor  = AppTheme.recoveryGreen
        let trackColor     = Color(white: 0.14)
        // 40 % of circumference (144°) centered on 9-o'clock (left) and 3-o'clock (right).
        // With rotationEffect(−90°): trim 0.0 = 12-o'clock, 0.25 = 3, 0.5 = 6, 0.75 = 9.
        let span: Double   = 0.30
        let leftLo: Double = 0.75 - span / 2  // 0.55
        let leftHi: Double = 0.75 + span / 2  // 0.95
        let rightLo: Double = 0.25 - span / 2 // 0.05
        let rightHi: Double = 0.25 + span / 2 // 0.45

        return ZStack {
            // ── Left arc: Sleep (track) ───────────────────────
            Circle()
                .trim(from: leftLo, to: leftHi)
                .stroke(trackColor, style: StrokeStyle(lineWidth: 13, lineCap: .round))
                .frame(width: 200, height: 200)
                .rotationEffect(.degrees(-90))

            // ── Left arc: Sleep (fill — grows from bottom of arc) ─
            Circle()
                .trim(from: leftLo, to: min(leftHi, leftLo + span * sleepFraction))
                .stroke(AppTheme.sleepPurple, style: StrokeStyle(lineWidth: 13, lineCap: .round))
                .frame(width: 200, height: 200)
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 1.0), value: sleepFraction)

            // ── Right arc: Strain (track) ─────────────────────
            Circle()
                .trim(from: rightLo, to: rightHi)
                .stroke(trackColor, style: StrokeStyle(lineWidth: 13, lineCap: .round))
                .frame(width: 200, height: 200)
                .rotationEffect(.degrees(-90))

            // ── Right arc: Strain (fill — grows from bottom of arc)
            Circle()
                .trim(from: max(rightLo, rightHi - span * strainFraction), to: rightHi)
                .stroke(AppTheme.strainBlue, style: StrokeStyle(lineWidth: 13, lineCap: .round))
                .frame(width: 200, height: 200)
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 1.0), value: strainFraction)

            // ── Center ring: Recovery (renders on top) ────────
            WaveCircleView(
                progress: ((viewModel.recoveryScore?.overall ?? 0) / 100).clamped(to: 0...1),
                color: recoveryColor
            )
            .frame(width: 160, height: 160)

            // ── Center text (tap to open breakdown) ──────────
            VStack(spacing: 3) {
                if let score = viewModel.recoveryScore {
                    Text("\(Int(score.overall))")
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.recoveryGreen)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .shadow(color: .black.opacity(0.8), radius: 1, x: 0, y: 1)
                    Text("READINESS")
                        .font(AppTheme.label)
                        .foregroundStyle(.black)
                        .tracking(1.4)
                } else {
                    Text("--")
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
            .onTapGesture {
                if viewModel.recoveryScore != nil { showReadinessDetail = true }
            }

            // ── Sheet ─────────────────────────────────────────
            Color.clear
                .sheet(isPresented: $showReadinessDetail) {
                    if let score = viewModel.recoveryScore {
                        ReadinessDetailView(
                            score: score,
                            dailyMetrics: viewModel.dailyMetrics,
                            previousStrain: viewModel.strainScore?.score ?? 0
                        )
                    }
                }

            // ── Left stat: Sleep ──────────────────────────────
            VStack(alignment: .trailing, spacing: 4) {
                Text(viewModel.recoveryScore.map { "\(Int($0.sleepComponent))" } ?? "--")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.sleepPurple)
                    .monospacedDigit()
                Text("SLEEP")
                    .font(AppTheme.micro)
                    .foregroundStyle(AppTheme.secondaryText)
                    .tracking(1.3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 4)

            // ── Right stat: Strain ────────────────────────────
            VStack(alignment: .leading, spacing: 4) {
                Group {
                    if let s = viewModel.strainScore {
                        Text(String(format: "%.1f", s.score))
                            .foregroundStyle(AppTheme.strainBlue)
                    } else {
                        Text("--")
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .monospacedDigit()
                Text("STRAIN")
                    .font(AppTheme.micro)
                    .foregroundStyle(AppTheme.secondaryText)
                    .tracking(1.3)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 4)
        }
        .frame(maxWidth: .infinity, minHeight: 216)
    }

    // MARK: - Strain Card

    private var strainCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                sectionLabel("STRAIN")
                Spacer()
                if let score = viewModel.strainScore {
                    Text(score.category.rawValue.uppercased())
                        .font(AppTheme.label)
                        .foregroundStyle(AppTheme.strainBlue)
                        .tracking(1.4)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(viewModel.strainScore.map { String(format: "%.1f", $0.score) } ?? "--")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.strainBlue)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("/ 21")
                    .font(AppTheme.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .padding(.bottom, 8)
            }

            // Gauge track
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(white: 0.14))
                        .frame(height: 10)

                    Capsule()
                        .fill(LinearGradient(
                            colors: [AppTheme.strainBlue.opacity(0.6), AppTheme.strainBlue],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(
                            width: proxy.size.width * ((viewModel.strainScore?.score ?? 0) / 21).clamped(to: 0...1),
                            height: 10
                        )
                        .animation(.easeOut(duration: 1.1), value: viewModel.strainScore?.score)

                    // Zone boundary ticks at 8, 14, 18
                    ForEach([8.0, 14.0, 18.0], id: \.self) { mark in
                        Rectangle()
                            .fill(AppTheme.background)
                            .frame(width: 2, height: 14)
                            .offset(x: proxy.size.width * (mark / 21) - 1, y: -2)
                    }
                }
            }
            .frame(height: 10)

            // Zone labels
            HStack(spacing: 0) {
                Text("Recovery")
                Spacer()
                Text("Moderate")
                Spacer()
                Text("Strenuous")
                Spacer()
                Text("All Out")
            }
            .font(AppTheme.micro)
            .foregroundStyle(AppTheme.tertiaryText)
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius))
    }

    // MARK: - Biometrics Row

    private var biometricsRow: some View {
        HStack(spacing: AppTheme.sectionGap) {
            let sleep = viewModel.dailyMetrics.sleep

            bioCard(
                label: "HRV",
                value: viewModel.dailyMetrics.hrv.map { "\(Int($0))" } ?? "--",
                unit: "ms"
            )
            bioCard(
                label: "RHR",
                value: viewModel.dailyMetrics.restingHeartRate.map { "\(Int($0))" } ?? "--",
                unit: "bpm"
            )
            bioCard(
                label: "Sleep",
                value: sleep?.formattedDuration ?? "--",
                unit: sleep.map { "\(Int($0.efficiency * 100))% eff" } ?? ""
            )
        }
    }

    private func bioCard(label: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(AppTheme.label)
                .foregroundStyle(AppTheme.secondaryText)
                .tracking(1.3)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.primaryText)
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(unit)
                .font(AppTheme.caption)
                .foregroundStyle(AppTheme.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.innerRadius))
    }

    // MARK: - Workout Card

    private func lastWorkoutCard(_ session: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("LAST WORKOUT")
            workoutRow(session)
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius))
        .contentShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
        .onTapGesture { selectedWorkout = session }
        .sheet(item: $selectedWorkout) { workout in
            WorkoutDetailView(session: workout, maxHeartRate: healthKit.maxHeartRate)
        }
    }

    private func workoutRow(_ session: WorkoutSession) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.strainBlue.opacity(0.14))
                    .frame(width: 46, height: 46)
                Image(systemName: session.activityType.systemImage)
                    .foregroundStyle(AppTheme.strainBlue)
                    .font(.system(size: 18, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(session.activityName)
                    .font(AppTheme.subheadline)
                    .foregroundStyle(AppTheme.primaryText)
                Text(session.formattedDuration)
                    .font(AppTheme.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let hr = session.averageHeartRate {
                    HStack(spacing: 3) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.red)
                        Text("\(Int(hr))")
                            .font(AppTheme.subheadline)
                            .foregroundStyle(AppTheme.primaryText)
                            .monospacedDigit()
                    }
                }
                Text("\(Int(session.activeCalories)) kcal")
                    .font(AppTheme.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Activity Calendar

    private struct MonthDay {
        let number: Int?   // nil = leading padding cell
        let date: Date?
        let level: ActivityLevel?
        let isGame: Bool
    }

    private var monthDays: [MonthDay] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let thisMonth = cal.date(from: cal.dateComponents([.year, .month], from: today))!
        let firstOfMonth = cal.date(byAdding: .month, value: calendarMonthOffset, to: thisMonth)!
        let dayCount = cal.range(of: .day, in: .month, for: firstOfMonth)!.count

        // Sunday-anchored: Sun weekday=1 → 0 pads, Mon=2 → 1, … Sat=7 → 6
        let firstWeekday = cal.component(.weekday, from: firstOfMonth)
        let leadingPadding = firstWeekday - 1

        let lookup = Dictionary(uniqueKeysWithValues: viewModel.calendarDays.map { ($0.date, $0) })

        var result: [MonthDay] = Array(repeating: MonthDay(number: nil, date: nil, level: nil, isGame: false), count: leadingPadding)
        for dayNum in 1...dayCount {
            let date = cal.date(byAdding: .day, value: dayNum - 1, to: firstOfMonth)!
            let sod  = cal.startOfDay(for: date)
            result.append(MonthDay(
                number: dayNum,
                date: sod,
                level: lookup[sod]?.level,
                isGame: viewModel.gameDates.contains(sod)
            ))
        }
        return result
    }

    private var monthYearLabel: String {
        let cal = Calendar.current
        let thisMonth = cal.date(from: cal.dateComponents([.year, .month], from: .now))!
        let target = cal.date(byAdding: .month, value: calendarMonthOffset, to: thisMonth)!
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        return fmt.string(from: target).uppercased()
    }

    private var activityCalendarCard: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) { calendarMonthOffset -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(width: 24, height: 24)
                }

                Text(monthYearLabel)
                    .font(AppTheme.label)
                    .foregroundStyle(AppTheme.secondaryText)
                    .tracking(1.4)
                    .frame(minWidth: 110, alignment: .center)
                    .animation(.none, value: calendarMonthOffset)

                Button {
                    withAnimation(.easeInOut(duration: 0.22)) { calendarMonthOffset = min(calendarMonthOffset + 1, 0) }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(calendarMonthOffset < 0 ? AppTheme.secondaryText : AppTheme.tertiaryText)
                        .frame(width: 24, height: 24)
                }
                .disabled(calendarMonthOffset >= 0)

                Spacer()
                HStack(spacing: 8) {
                    calLegendChip(color: AppTheme.strainBlue,              label: "Goal")
                    calLegendChip(color: AppTheme.strainBlue.opacity(0.4), label: "Partial")
                }
            }

            // Day-of-week header
            LazyVGrid(columns: cols, spacing: 4) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { label in
                    Text(label)
                        .font(AppTheme.micro)
                        .foregroundStyle(AppTheme.tertiaryText)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day cells
            LazyVGrid(columns: cols, spacing: 6) {
                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, day in
                    calendarCell(day)
                }
            }
            .animation(.easeInOut(duration: 0.22), value: calendarMonthOffset)
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius))
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    withAnimation(.easeInOut(duration: 0.22)) {
                        if value.translation.width < 0 {
                            calendarMonthOffset -= 1
                        } else {
                            calendarMonthOffset = min(calendarMonthOffset + 1, 0)
                        }
                    }
                }
        )
    }

    @ViewBuilder
    private func calendarCell(_ day: MonthDay) -> some View {
        if let num = day.number {
            let isToday = day.date == Calendar.current.startOfDay(for: .now)

            ZStack {
                if day.isGame {
                    Circle().fill(AppTheme.strainBlue)
                    Circle().fill(AppTheme.background).padding(2)
                    Circle().fill(AppTheme.strainBlue).padding(4)
                } else {
                    switch day.level {
                    case .achieved:
                        Circle().fill(AppTheme.strainBlue)
                    case .partial:
                        Circle().fill(AppTheme.strainBlue.opacity(0.35))
                    default:
                        if isToday {
                            Circle().fill(Color(white: 0.20))
                        } else {
                            Color.clear
                        }
                    }
                }

                Text("\(num)")
                    .font(.system(
                        size: 13,
                        weight: (day.level == .achieved || day.isGame) ? .bold : .regular
                    ))
                    .foregroundStyle(
                        (day.level == .achieved || day.level == .partial || day.isGame)
                            ? AppTheme.primaryText
                            : (isToday ? AppTheme.primaryText : AppTheme.tertiaryText)
                    )
            }
            .frame(height: 38)
        } else {
            Color.clear.frame(height: 38)
        }
    }

    private func calLegendChip(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(AppTheme.micro)
                .foregroundStyle(AppTheme.tertiaryText)
        }
    }

    // MARK: - Shared

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(AppTheme.label)
            .foregroundStyle(AppTheme.secondaryText)
            .tracking(1.5)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
