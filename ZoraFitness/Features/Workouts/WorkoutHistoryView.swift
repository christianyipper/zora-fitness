import SwiftUI

struct WorkoutHistoryView: View {
    @Environment(HealthKitManager.self) private var healthKit
    @Environment(SettingsStore.self)    private var settings
    @State private var viewModel = WorkoutHistoryViewModel()
    @State private var selectedSession: WorkoutSession?
    @State private var showProfile = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                if viewModel.isLoading && viewModel.sessions.isEmpty {
                    ProgressView().tint(.white).scaleEffect(1.4)
                } else if viewModel.sessions.isEmpty {
                    emptyState
                } else {
                    workoutList
                }
            }
            .navigationTitle("Workouts")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    AvatarButton(initials: initialsFromName(settings.officialName.isEmpty ? "You" : settings.officialName)) {
                        showProfile = true
                    }
                }
            }
            .sheet(item: $selectedSession) { session in
                WorkoutDetailView(session: session, maxHeartRate: viewModel.maxHeartRate)
            }
            .sheet(isPresented: $showProfile) { ProfileView() }
        }
        .task { await viewModel.load(using: healthKit) }
    }

    // MARK: - List

    private var workoutList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                ForEach(viewModel.grouped, id: \.date) { group in
                    Section {
                        VStack(spacing: 1) {
                            ForEach(group.sessions) { session in
                                WorkoutRowCell(session: session, maxHeartRate: viewModel.maxHeartRate)
                                    .contentShape(Rectangle())
                                    .onTapGesture { selectedSession = session }
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)
                    } header: {
                        Text(group.label)
                            .font(AppTheme.label)
                            .foregroundStyle(AppTheme.secondaryText)
                            .tracking(1.4)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 9)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.background)
                    }
                }

                loadMoreButton
                    .padding(.bottom, 40)
            }
            .refreshable { await viewModel.load(using: healthKit) }
        }
    }

    // MARK: - Load More

    private var loadMoreButton: some View {
        Button {
            Task { await viewModel.loadMore(using: healthKit) }
        } label: {
            HStack(spacing: 8) {
                if viewModel.isLoadingMore {
                    ProgressView().tint(AppTheme.secondaryText).scaleEffect(0.8)
                }
                Text(viewModel.isLoadingMore ? "Loading…" : "Load older workouts")
                    .font(AppTheme.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
        }
        .disabled(viewModel.isLoadingMore)
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.run.circle")
                .font(.system(size: 56))
                .foregroundStyle(AppTheme.strainBlue)
            Text("No Workouts Found")
                .font(AppTheme.headline)
                .foregroundStyle(AppTheme.primaryText)
            Text("Workouts from the last 30 days will appear here.")
                .font(AppTheme.body)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - Row Cell

private struct WorkoutRowCell: View {
    let session: WorkoutSession
    let maxHeartRate: Double

    private var strainScore: Double {
        StrainCalculator.calculate(input: StrainInput(
            workoutSessions: [session],
            activeCalories: 0,
            steps: 0,
            maxHeartRate: maxHeartRate
        )).score
    }

    var body: some View {
        HStack(spacing: 14) {
            activityIcon

            VStack(alignment: .leading, spacing: 5) {
                Text(session.activityName)
                    .font(AppTheme.subheadline)
                    .foregroundStyle(AppTheme.primaryText)

                HStack(spacing: 10) {
                    Label(session.formattedDuration, systemImage: "clock")

                    if let dist = session.formattedDistance {
                        Label(dist, systemImage: "map")
                    }

                    if let hr = session.averageHeartRate {
                        Label("\(Int(hr))", systemImage: "heart.fill")
                            .foregroundStyle(AppTheme.recoveryRed.opacity(0.85))
                    }
                }
                .font(AppTheme.caption)
                .foregroundStyle(AppTheme.secondaryText)
                .labelStyle(CompactLabelStyle())
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(String(format: "%.1f", strainScore))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.strainBlue)
                    .monospacedDigit()
                Text("strain")
                    .font(AppTheme.micro)
                    .foregroundStyle(AppTheme.tertiaryText)
                    .tracking(0.8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(AppTheme.cardBackground)
    }

    private var activityIcon: some View {
        ZStack {
            Circle()
                .fill(AppTheme.strainBlue.opacity(0.13))
                .frame(width: 46, height: 46)
            Image(systemName: session.activityType.systemImage)
                .foregroundStyle(AppTheme.strainBlue)
                .font(.system(size: 18, weight: .semibold))
        }
    }
}

// MARK: - Label Style

private struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon
            configuration.title
        }
    }
}
