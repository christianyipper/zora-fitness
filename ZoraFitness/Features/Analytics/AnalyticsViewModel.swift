import Foundation
import HealthKit
import Observation

struct DailyDataPoint: Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}

enum ActivityLevel {
    case achieved, partial, missed, noData, future
}

struct CalendarDay: Identifiable {
    let date: Date
    let level: ActivityLevel
    var id: Date { date }
}

@Observable
@MainActor
final class AnalyticsViewModel {

    // MARK: - State

    var hrvHistory:    [DailyDataPoint] = []
    var strainHistory: [DailyDataPoint] = []
    var sleepHistory:  [SleepSession]   = []
    var calendarDays:  [CalendarDay]    = []
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
            async let hrv      = healthKit.fetchHRVHistory(days: 30)
            async let sleep    = healthKit.fetchSleepHistory(days: 30)
            async let strain   = buildStrainHistory(days: 30, healthKit: healthKit)
            async let activity = healthKit.fetchActivityHistory(days: 91)

            let (hrvRaw, sleepRaw, strainRaw, activityRaw) = try await (hrv, sleep, strain, activity)

            hrvHistory    = deduplicated(hrvRaw.map { DailyDataPoint(date: $0.0, value: $0.1) })
            sleepHistory  = sleepRaw
            strainHistory = strainRaw
            calendarDays  = buildCalendarDays(from: activityRaw)
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

    /// Builds a 91-day grid of CalendarDay values padded to start on Monday.
    private func buildCalendarDays(
        from history: [(date: Date, steps: Double, exerciseMinutes: Double)]
    ) -> [CalendarDay] {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: .now)

        // Build a lookup by startOfDay.
        let lookup = Dictionary(uniqueKeysWithValues: history.map {
            (cal.startOfDay(for: $0.date), ($0.steps, $0.exerciseMinutes))
        })

        // Find the Monday on or before 91 days ago so the grid aligns week columns.
        let rawStart = cal.date(byAdding: .day, value: -90, to: today)!
        let weekday  = cal.component(.weekday, from: rawStart)  // 1=Sun … 7=Sat
        let offsetToMonday = (weekday == 1) ? -6 : -(weekday - 2)
        let gridStart = cal.date(byAdding: .day, value: offsetToMonday, to: rawStart)!

        var days: [CalendarDay] = []
        var cursor = gridStart
        while cursor <= today {
            let level: ActivityLevel
            if cursor > today {
                level = .future
            } else if let (s, e) = lookup[cursor] {
                if s >= 8000 || e >= 30      { level = .achieved }
                else if s >= 4000 || e >= 15 { level = .partial  }
                else                          { level = .missed   }
            } else {
                level = cursor <= today ? .missed : .noData
            }
            days.append(CalendarDay(date: cursor, level: level))
            cursor = cal.date(byAdding: .day, value: 1, to: cursor)!
        }
        return days
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
