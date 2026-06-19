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

    var totalCrewStars: Int = 8  // mock — replace with crew backend query

    var recentGame: OfficialGame? = nil
    var totalGamesWorked: Int = 0
    var gameDates: Set<Date> = []
    var mostRecentWorkout: WorkoutSession? = nil
    var calendarDays: [CalendarDay] = []

    // MARK: - Load

    func load(using healthKit: HealthKitManager, officialName: String = "") async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        loadError = nil

        let cal = Calendar.current
        let today = Date.now
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let startOfToday = cal.startOfDay(for: today)
        let startOfYesterday = cal.startOfDay(for: yesterday)

        // Phase 1: All raw HealthKit fetches run concurrently.
        // try? per-fetch so one failed query doesn't wipe all state.
        async let todayMetrics     = healthKit.fetchDailyMetrics(for: today)
        async let yesterdayMetrics = healthKit.fetchDailyMetrics(for: yesterday)
        async let hrvHistory       = healthKit.fetchHRVHistory(days: 30)
        async let rhrHistory       = healthKit.fetchRHRHistory(days: 30)
        async let rawToday         = healthKit.fetchWorkouts(from: startOfToday)
        async let rawYesterday     = healthKit.fetchWorkouts(from: startOfYesterday, to: startOfToday)
        async let activityHistory  = healthKit.fetchActivityHistory(days: 120)

        let m        = (try? await todayMetrics)     ?? .empty
        let prevM    = (try? await yesterdayMetrics) ?? .empty
        let hrv      = (try? await hrvHistory)       ?? []
        let rhr      = (try? await rhrHistory)       ?? []
        let rawT     = (try? await rawToday)         ?? []
        let rawY     = (try? await rawYesterday)     ?? []
        let activity = (try? await activityHistory)  ?? []

        // Fall back to the last recorded value when today's reading isn't available yet
        // (e.g., early morning before Apple Watch has synced overnight data).
        let effectiveHRV   = m.hrv ?? hrv.last?.1
        let effectiveRHR   = m.restingHeartRate ?? rhr.last?.1
        let effectiveSleep = m.sleep ?? prevM.sleep

        dailyMetrics = DailyMetrics(
            date: m.date,
            hrv: effectiveHRV,
            restingHeartRate: effectiveRHR,
            activeCalories: m.activeCalories,
            steps: m.steps,
            exerciseMinutes: m.exerciseMinutes,
            sleep: effectiveSleep
        )

        // Fitness age from 30-day HRV baseline.
        let hrvAvg = hrv.map(\.1).mean
        fitnessAge = FitnessAgeCalculator.calculate(hrv30DayAvg: hrvAvg)

        // Streak, monthly active-day count, and 16-week calendar grid.
        (currentStreak, activeDaysThisMonth) = computeStreakAndMonth(from: activity)
        calendarDays = buildCalendarDays(from: activity)

        // Phase 2: Enrich workouts with HR zone data.
        // Run today and yesterday enrichment concurrently via task groups.
        async let todaySessions     = enrichWorkouts(rawT, healthKit: healthKit)
        async let yesterdaySessions = enrichWorkouts(rawY, healthKit: healthKit)

        workouts = (try? await todaySessions)     ?? []
        let prevWorkouts = (try? await yesterdaySessions) ?? []
        mostRecentWorkout = workouts.first ?? prevWorkouts.first

        // Phase 3: Calculate scores.
        let prevStrain = StrainCalculator.calculate(input: StrainInput(
            workoutSessions: prevWorkouts,
            activeCalories: prevM.activeCalories,
            steps: prevM.steps,
            maxHeartRate: healthKit.maxHeartRate
        )).score

        recoveryScore = RecoveryCalculator.calculate(input: RecoveryInput(
            todayHRV: effectiveHRV,
            todayRHR: effectiveRHR,
            hrvHistory: hrv.map(\.1),
            rhrHistory: rhr.map(\.1),
            lastNightSleep: effectiveSleep,
            previousDayStrain: prevStrain
        ))

        strainScore = StrainCalculator.calculate(input: StrainInput(
            workoutSessions: workouts,
            activeCalories: m.activeCalories,
            steps: m.steps,
            maxHeartRate: healthKit.maxHeartRate
        ))

        await loadOfficialData(name: officialName)
    }

    // MARK: - Private

    private func loadOfficialData(name: String) async {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let client = BCHLAPIClient()
        async let game  = try? client.fetchRecentGame(for: name)
        async let total = try? client.fetchTotalGamesWorked(for: name)
        async let dates = try? client.fetchGameDates(for: name)
        recentGame       = await game ?? recentGame
        totalGamesWorked = await total ?? totalGamesWorked
        let cal = Calendar.current
        gameDates = Set((await dates ?? []).map { cal.startOfDay(for: $0) })
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

    private func buildCalendarDays(
        from history: [(date: Date, steps: Double, exerciseMinutes: Double)]
    ) -> [CalendarDay] {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: .now)

        let lookup = Dictionary(uniqueKeysWithValues: history.map {
            (cal.startOfDay(for: $0.date), ($0.steps, $0.exerciseMinutes))
        })

        // 14 weeks = 98 days; pad the start back to the nearest Monday.
        let rawStart = cal.date(byAdding: .day, value: -97, to: today)!
        let weekday  = cal.component(.weekday, from: rawStart)
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
            } else {
                level = .missed
            }
            days.append(CalendarDay(date: cursor, level: level))
            cursor = cal.date(byAdding: .day, value: 1, to: cursor)!
        }
        return days
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
