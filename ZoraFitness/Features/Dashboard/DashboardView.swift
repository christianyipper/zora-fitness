import SwiftUI

struct DashboardView: View {
    @Environment(HealthKitManager.self) private var healthKit
    @Environment(SettingsStore.self)    private var settings
    @State private var viewModel = DashboardViewModel()

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
                        if viewModel.currentStreak > 0 {
                            streakBanner
                        }
                        recoveryCard
                        if let game = viewModel.recentGame {
                            recentGameCard(game)
                        }
                        strainCard
                        biometricsRow
                        if !viewModel.workouts.isEmpty {
                            workoutsCard
                        }
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
            VStack(alignment: .trailing, spacing: 6) {
                if let fa = viewModel.fitnessAge {
                    fitnessAgePill(age: fa)
                }
                if viewModel.totalGamesWorked > 0 {
                    gameBadge
                }
            }
        }
        .padding(.top, 4)
    }

    private func fitnessAgePill(age: Int) -> some View {
        let delta = FitnessAgeCalculator.delta(fitnessAge: age, chronologicalAge: settings.age)
        let isYounger = delta < 0
        return VStack(alignment: .trailing, spacing: 3) {
            Text("FITNESS AGE")
                .font(AppTheme.micro)
                .foregroundStyle(AppTheme.secondaryText)
                .tracking(1.2)
            HStack(spacing: 4) {
                Text("\(age)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.strainBlue)
                    .monospacedDigit()
                if delta != 0 {
                    Text(isYounger ? "\(abs(delta))↑" : "\(abs(delta))↓")
                        .font(AppTheme.micro)
                        .foregroundStyle(isYounger ? AppTheme.recoveryGreen : AppTheme.recoveryYellow)
                }
            }
        }
    }

    private var gameBadge: some View {
        Label("\(viewModel.totalGamesWorked) games", systemImage: "flag.checkered.2.crossed")
            .font(AppTheme.caption)
            .foregroundStyle(AppTheme.strainBlue)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(AppTheme.strainBlue.opacity(0.15), in: Capsule())
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

    // MARK: - Streak Banner

    private var streakBanner: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                FlameView()
                    .frame(width: 18, height: 22)
                Text("\(viewModel.currentStreak)-day streak")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.recoveryYellow)
            }
            Spacer()
            Text("\(viewModel.activeDaysThisMonth) active this month")
                .font(AppTheme.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.innerRadius))
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
            if let score = viewModel.recoveryScore {
                VStack(spacing: 10) {
                    componentBar(label: "HRV",   value: score.hrvComponent,   color: score.category.color)
                    componentBar(label: "RHR",   value: score.rhrComponent,   color: score.category.color)
                    componentBar(label: "Sleep", value: score.sleepComponent, color: AppTheme.sleepPurple)
                }
            }
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius))
    }

    private var tripleRingCluster: some View {
        let sleepFraction  = ((viewModel.recoveryScore?.sleepComponent ?? 0) / 100).clamped(to: 0...1)
        let strainFraction = ((viewModel.strainScore?.score ?? 0) / 21).clamped(to: 0...1)
        let recoveryColor  = viewModel.recoveryScore?.category.color ?? Color(white: 0.25)
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

            // ── Center text ───────────────────────────────────
            VStack(spacing: 3) {
                if let score = viewModel.recoveryScore {
                    Text("\(Int(score.overall))")
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundStyle(score.category.color)
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

    private func componentBar(label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(AppTheme.caption)
                .foregroundStyle(AppTheme.secondaryText)
                .frame(width: 36, alignment: .leading)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(white: 0.18))
                    Capsule()
                        .fill(color.opacity(0.85))
                        .frame(width: proxy.size.width * (value / 100).clamped(to: 0...1))
                        .animation(.easeOut(duration: 0.9), value: value)
                }
            }
            .frame(height: 6)

            Text("\(Int(value))%")
                .font(AppTheme.caption)
                .foregroundStyle(AppTheme.primaryText)
                .monospacedDigit()
                .frame(width: 34, alignment: .trailing)
        }
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

    // MARK: - Workouts Card

    private var workoutsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("TODAY'S WORKOUTS")

            ForEach(Array(viewModel.workouts.enumerated()), id: \.element.id) { index, workout in
                if index > 0 {
                    Divider().background(Color(white: 0.18))
                }
                workoutRow(workout)
            }
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius))
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

    // MARK: - Shared

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(AppTheme.label)
            .foregroundStyle(AppTheme.secondaryText)
            .tracking(1.5)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
