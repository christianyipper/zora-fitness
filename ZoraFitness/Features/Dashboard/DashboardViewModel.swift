import Foundation
import HealthKit
import Observation

@Observable
@MainActor
final class DashboardViewModel {

    // MARK: - State

    var recoveryScore: RecoveryScore?
    var strainScore: StrainScore?
    var dailyMetrics: DailyMetrics = .empty
    var workouts: [WorkoutSession] = []
    var isLoading = false
    var loadError: Error?

    var fitnessAge: Int? = nil
    var currentStreak: Int = 0
    var activeDaysThisMonth: Int = 0

    var recentGame: OfficialGame? = nil
    var totalGamesWorked: Int = 0

    // MARK: - Load

    func load(using healthKit: HealthKitManager, officialName: String = "") async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        loadError = nil

        do {
            let cal = Calendar.current
            let today = Date.now
            let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
            let startOfToday = cal.startOfDay(for: today)
            let startOfYesterday = cal.startOfDay(for: yesterday)

            // Phase 1: All raw HealthKit fetches run concurrently.
            async let todayMetrics     = healthKit.fetchDailyMetrics(for: today)
            async let yesterdayMetrics = healthKit.fetchDailyMetrics(for: yesterday)
            async let hrvHistory       = healthKit.fetchHRVHistory(days: 30)
            async let rhrHistory       = healthKit.fetchRHRHistory(days: 30)
            async let rawToday         = healthKit.fetchWorkouts(from: startOfToday)
            async let rawYesterday     = healthKit.fetchWorkouts(from: startOfYesterday, to: startOfToday)
            async let activityHistory  = healthKit.fetchActivityHistory(days: 90)

            let m        = try await todayMetrics
            let prevM    = try await yesterdayMetrics
            let hrv      = try await hrvHistory
            let rhr      = try await rhrHistory
            let rawT     = try await rawToday
            let rawY     = try await rawYesterday
            let activity = try await activityHistory

            dailyMetrics = m

            // Fitness age from 30-day HRV baseline.
            let hrvAvg = hrv.map(\.1).mean
            fitnessAge = FitnessAgeCalculator.calculate(hrv30DayAvg: hrvAvg)

            // Streak and monthly active-day count.
            (currentStreak, activeDaysThisMonth) = computeStreakAndMonth(from: activity)

            // Phase 2: Enrich workouts with HR zone data.
            // Run today and yesterday enrichment concurrently via task groups.
            async let todaySessions     = enrichWorkouts(rawT, healthKit: healthKit)
            async let yesterdaySessions = enrichWorkouts(rawY, healthKit: healthKit)

            workouts = try await todaySessions
            let prevWorkouts = try await yesterdaySessions

            // Phase 3: Calculate scores.
            let prevStrain = StrainCalculator.calculate(input: StrainInput(
                workoutSessions: prevWorkouts,
                activeCalories: prevM.activeCalories,
                steps: prevM.steps,
                maxHeartRate: healthKit.maxHeartRate
            )).score

            recoveryScore = RecoveryCalculator.calculate(input: RecoveryInput(
                todayHRV: m.hrv,
                todayRHR: m.restingHeartRate,
                hrvHistory: hrv.map(\.1),
                rhrHistory: rhr.map(\.1),
                lastNightSleep: m.sleep,
                previousDayStrain: prevStrain
            ))

            strainScore = StrainCalculator.calculate(input: StrainInput(
                workoutSessions: workouts,
                activeCalories: m.activeCalories,
                steps: m.steps,
                maxHeartRate: healthKit.maxHeartRate
            ))

        } catch {
            loadError = error
        }

        await loadOfficialData(name: officialName)
    }

    // MARK: - Private

    private func loadOfficialData(name: String) async {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let client = BCHLAPIClient()
        async let game  = try? client.fetchRecentGame(for: name)
        async let total = try? client.fetchTotalGamesWorked(for: name)
        recentGame       = await game ?? recentGame
        totalGamesWorked = await total ?? totalGamesWorked
    }

    private func computeStreakAndMonth(
        from history: [(date: Date, steps: Double, exerciseMinutes: Double)]
    ) -> (streak: Int, activeDaysThisMonth: Int) {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: .now)

        let isActive = { (s: Double, e: Double) in s >= 8000 || e >= 30 }

        // Streak: walk backwards from yesterday.
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
            } else {
                break
            }
        }

        // Active days in the current calendar month (including today's in-progress data).
        let monthDays = history.filter {
            cal.isDate($0.date, equalTo: today, toGranularity: .month)
        }
        let activeDaysThisMonth = monthDays.filter { isActive($0.steps, $0.exerciseMinutes) }.count

        return (streak, activeDaysThisMonth)
    }

    private func enrichWorkouts(_ raw: [HKWorkout], healthKit: HealthKitManager) async throws -> [WorkoutSession] {
        try await withThrowingTaskGroup(of: WorkoutSession.self) { group in
            for workout in raw {
                group.addTask { try await healthKit.buildWorkoutSession(from: workout) }
            }
            var sessions: [WorkoutSession] = []
            for try await session in group {
                sessions.append(session)
            }
            return sessions.sorted { $0.startDate > $1.startDate }
        }
    }
}
