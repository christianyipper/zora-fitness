import SwiftUI

struct DashboardView: View {
    @Environment(HealthKitManager.self) private var healthKit
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
                        recoveryCard
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
                .refreshable { await viewModel.load(using: healthKit) }
            }
        }
        .task { await viewModel.load(using: healthKit) }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .bottom) {
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
        }
        .padding(.top, 4)
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

            ZStack {
                RingProgressView(
                    progress: (viewModel.recoveryScore?.overall ?? 0) / 100,
                    color: viewModel.recoveryScore?.category.color ?? Color(white: 0.25),
                    trackColor: Color(white: 0.14),
                    lineWidth: 18
                )
                .frame(width: 210, height: 210)
                .animation(.easeOut(duration: 1.1), value: viewModel.recoveryScore?.overall)

                VStack(spacing: 3) {
                    if let score = viewModel.recoveryScore {
                        Text("\(Int(score.overall))")
                            .font(.system(size: 58, weight: .bold, design: .rounded))
                            .foregroundStyle(score.category.color)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text(score.category.label.uppercased())
                            .font(AppTheme.label)
                            .foregroundStyle(AppTheme.secondaryText)
                            .tracking(1.6)
                    } else {
                        Text("--")
                            .font(.system(size: 58, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
            }

            if let score = viewModel.recoveryScore {
                VStack(spacing: 10) {
                    componentBar(label: "HRV",   value: score.hrvComponent,   color: score.category.color)
                    componentBar(label: "RHR",   value: score.rhrComponent,   color: score.category.color)
                    componentBar(label: "Sleep", value: score.sleepComponent, color: score.category.color)
                }
            }
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius))
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
