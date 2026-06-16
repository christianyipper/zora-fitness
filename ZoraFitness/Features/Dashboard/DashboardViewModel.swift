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

    // MARK: - Load

    func load(using healthKit: HealthKitManager) async {
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

            let m     = try await todayMetrics
            let prevM = try await yesterdayMetrics
            let hrv   = try await hrvHistory
            let rhr   = try await rhrHistory
            let rawT  = try await rawToday
            let rawY  = try await rawYesterday

            dailyMetrics = m

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
    }

    // MARK: - Private

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
