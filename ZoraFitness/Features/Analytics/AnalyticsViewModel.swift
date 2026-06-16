import Foundation
import HealthKit
import Observation

struct DailyDataPoint: Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}

@Observable
@MainActor
final class AnalyticsViewModel {

    // MARK: - State

    var hrvHistory:    [DailyDataPoint] = []
    var strainHistory: [DailyDataPoint] = []
    var sleepHistory:  [SleepSession]   = []
    var isLoading  = false
    var loadError: Error?

    // MARK: - Computed Summaries

    var hrvBaseline: Double  { hrvHistory.map(\.value).mean }

    // 7-day vs prior 7-day percentage change.
    func trend(for data: [DailyDataPoint], higherIsBetter: Bool = true) -> Double {
        guard data.count >= 14 else { return 0 }
        let recent = Array(data.suffix(7)).map(\.value).mean
        let prior  = Array(data.dropLast(7).suffix(7)).map(\.value).mean
        guard prior > 0 else { return 0 }
        return (recent - prior) / prior * 100
    }

    var sleepTrend: Double {
        let hours = sleepHistory.map { $0.totalDuration / 3600 }
        guard hours.count >= 14 else { return 0 }
        let recent = Array(hours.suffix(7)).mean
        let prior  = Array(hours.dropLast(7).suffix(7)).mean
        guard prior > 0 else { return 0 }
        return (recent - prior) / prior * 100
    }

    func statsRow(for data: [DailyDataPoint], format: (Double) -> String) -> [(String, String)] {
        guard !data.isEmpty else { return [] }
        let values = data.map(\.value)
        return [
            ("Min", format(values.min() ?? 0)),
            ("Avg", format(values.mean)),
            ("Max", format(values.max() ?? 0)),
        ]
    }

    func sleepStatsRow() -> [(String, String)] {
        let hours = sleepHistory.map { $0.totalDuration / 3600 }
        guard !hours.isEmpty else { return [] }
        let fmt = { (h: Double) in String(format: "%.1fh", h) }
        return [
            ("Min", fmt(hours.min() ?? 0)),
            ("Avg", fmt(hours.mean)),
            ("Max", fmt(hours.max() ?? 0)),
        ]
    }

    // MARK: - Load

    func load(using healthKit: HealthKitManager) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        loadError = nil

        do {
            async let hrv    = healthKit.fetchHRVHistory(days: 30)
            async let sleep  = healthKit.fetchSleepHistory(days: 30)
            async let strain = buildStrainHistory(days: 30, healthKit: healthKit)

            let (hrvRaw, sleepRaw, strainRaw) = try await (hrv, sleep, strain)

            hrvHistory    = deduplicated(hrvRaw.map { DailyDataPoint(date: $0.0, value: $0.1) })
            sleepHistory  = sleepRaw
            strainHistory = strainRaw
        } catch {
            loadError = error
        }
    }

    // MARK: - Private

    /// Fetches all workouts in the window, enriches them concurrently,
    /// groups by day, and runs StrainCalculator per day.
    private func buildStrainHistory(days: Int, healthKit: HealthKitManager) async throws -> [DailyDataPoint] {
        let start = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        let raw = try await healthKit.fetchWorkouts(from: start)

        let sessions = try await withThrowingTaskGroup(of: WorkoutSession.self) { group in
            for workout in raw {
                group.addTask { try await healthKit.buildWorkoutSession(from: workout) }
            }
            var results: [WorkoutSession] = []
            for try await s in group { results.append(s) }
            return results
        }

        let cal = Calendar.current
        let byDay = Dictionary(grouping: sessions) { cal.startOfDay(for: $0.startDate) }

        return byDay.map { date, daySessions in
            let score = StrainCalculator.calculate(input: StrainInput(
                workoutSessions: daySessions,
                activeCalories: 0,
                steps: 0,
                maxHeartRate: healthKit.maxHeartRate
            )).score
            return DailyDataPoint(date: date, value: score)
        }.sorted { $0.date < $1.date }
    }

    /// Keeps the last reading per calendar day, eliminating bar stacking in Charts.
    private func deduplicated(_ points: [DailyDataPoint]) -> [DailyDataPoint] {
        let cal = Calendar.current
        var byDay: [Date: DailyDataPoint] = [:]
        for point in points {
            byDay[cal.startOfDay(for: point.date)] = point
        }
        return byDay.values.sorted { $0.date < $1.date }
    }
}
