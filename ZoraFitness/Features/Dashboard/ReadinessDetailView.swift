import SwiftUI

struct ReadinessDetailView: View {
    let score: RecoveryScore
    let dailyMetrics: DailyMetrics
    let previousStrain: Double

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppTheme.sectionGap) {
                        scoreHeader
                        formulaCard
                        componentsCard
                        methodologyNote
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Readiness")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Score Header

    private var scoreHeader: some View {
        VStack(spacing: 8) {
            Text("\(Int(score.overall))")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.recoveryGreen)
                .monospacedDigit()

            Text(score.category.label.uppercased())
                .font(AppTheme.label)
                .foregroundStyle(AppTheme.recoveryGreen.opacity(0.85))
                .tracking(2.0)

            Text("Your body's readiness to perform today")
                .font(AppTheme.caption)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.cardPadding)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius))
    }

    // MARK: - Formula Card

    private var formulaCard: some View {
        VStack(spacing: 12) {
            Text("HOW IT'S CALCULATED")
                .font(AppTheme.label)
                .foregroundStyle(AppTheme.secondaryText)
                .tracking(1.4)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 0) {
                formulaPill(label: "HRV", weight: "50%", color: AppTheme.recoveryGreen)
                Text(" · ")
                    .font(AppTheme.caption)
                    .foregroundStyle(AppTheme.tertiaryText)
                formulaPill(label: "RHR", weight: "25%", color: AppTheme.strainBlue)
                Text(" · ")
                    .font(AppTheme.caption)
                    .foregroundStyle(AppTheme.tertiaryText)
                formulaPill(label: "SLEEP", weight: "25%", color: AppTheme.sleepPurple)
            }
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius))
    }

    private func formulaPill(label: String, weight: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(AppTheme.label)
                .foregroundStyle(color)
                .tracking(0.8)
            Text(weight)
                .font(AppTheme.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    // MARK: - Components Card

    private var componentsCard: some View {
        VStack(spacing: 0) {
            Text("BREAKDOWN")
                .font(AppTheme.label)
                .foregroundStyle(AppTheme.secondaryText)
                .tracking(1.4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 16)

            componentRow(
                icon: "waveform.path.ecg",
                label: "HRV",
                detail: dailyMetrics.hrv.map { "\(Int($0)) ms" } ?? "--",
                subtitle: "vs 30-day baseline",
                componentScore: score.hrvComponent,
                color: AppTheme.recoveryGreen
            )

            Divider()
                .background(Color(white: 0.18))
                .padding(.vertical, 14)

            componentRow(
                icon: "heart.fill",
                label: "Resting Heart Rate",
                detail: dailyMetrics.restingHeartRate.map { "\(Int($0)) bpm" } ?? "--",
                subtitle: "vs 30-day baseline",
                componentScore: score.rhrComponent,
                color: AppTheme.strainBlue
            )

            Divider()
                .background(Color(white: 0.18))
                .padding(.vertical, 14)

            componentRow(
                icon: "moon.fill",
                label: "Sleep",
                detail: dailyMetrics.sleep.map { formatDuration($0.totalDuration) } ?? "--",
                subtitle: "need \(RecoveryCalculator.sleepNeedFormatted(forStrain: previousStrain))",
                componentScore: score.sleepComponent,
                color: AppTheme.sleepPurple
            )
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius))
    }

    private func componentRow(
        icon: String,
        label: String,
        detail: String,
        subtitle: String,
        componentScore: Double,
        color: Color
    ) -> some View {
        VStack(spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(AppTheme.caption)
                        .foregroundStyle(AppTheme.primaryText)
                    Text(subtitle)
                        .font(AppTheme.micro)
                        .foregroundStyle(AppTheme.tertiaryText)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(componentScore))")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(barColor(componentScore))
                        .monospacedDigit()
                    Text(detail)
                        .font(AppTheme.micro)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(white: 0.18))
                    Capsule()
                        .fill(barColor(componentScore))
                        .frame(width: proxy.size.width * (componentScore / 100).clamped(to: 0...1))
                }
            }
            .frame(height: 5)
        }
    }

    // MARK: - Methodology Note

    private var methodologyNote: some View {
        Text("Scores compare today's readings to your 30-day personal baseline using a sigmoid curve — the same approach used by professional recovery platforms.")
            .font(AppTheme.micro)
            .foregroundStyle(AppTheme.tertiaryText)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
    }

    // MARK: - Helpers

    private func barColor(_ score: Double) -> Color {
        if score >= 67 { return AppTheme.recoveryGreen }
        if score >= 34 { return AppTheme.recoveryYellow }
        return AppTheme.recoveryRed
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }
}
