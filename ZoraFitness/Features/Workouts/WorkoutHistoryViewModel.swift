import Foundation
import HealthKit
import Observation

@Observable
@MainActor
final class WorkoutHistoryViewModel {

    // MARK: - State

    var sessions: [WorkoutSession] = []
    var isLoading = false
    var isLoadingMore = false
    var loadError: Error?
    var maxHeartRate: Double = 190

    // Grouped by calendar day, newest first.
    var grouped: [(label: String, date: Date, sessions: [WorkoutSession])] {
        let byDay = Dictionary(grouping: sessions) {
            Calendar.current.startOfDay(for: $0.startDate)
        }
        return byDay
            .sorted { $0.key > $1.key }
            .map { (date, list) in
                (label: Self.sectionLabel(for: date), date: date, sessions: list.sorted { $0.startDate > $1.startDate })
            }
    }

    // MARK: - Private

    private var windowDays = 30

    // MARK: - Load

    func load(using healthKit: HealthKitManager) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        loadError = nil
        maxHeartRate = healthKit.maxHeartRate

        await fetchWindow(days: windowDays, healthKit: healthKit)
    }

    func loadMore(using healthKit: HealthKitManager) async {
        guard !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        windowDays += 30
        await fetchWindow(days: windowDays, healthKit: healthKit)
    }

    // MARK: - Private

    private func fetchWindow(days: Int, healthKit: HealthKitManager) async {
        do {
            let start = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
            let raw = try await healthKit.fetchWorkouts(from: start)
            sessions = try await enrich(raw, healthKit: healthKit)
        } catch {
            loadError = error
        }
    }

    private func enrich(_ raw: [HKWorkout], healthKit: HealthKitManager) async throws -> [WorkoutSession] {
        try await withThrowingTaskGroup(of: WorkoutSession.self) { group in
            for workout in raw {
                group.addTask { try await healthKit.buildWorkoutSession(from: workout) }
            }
            var results: [WorkoutSession] = []
            for try await session in group { results.append(session) }
            return results.sorted { $0.startDate > $1.startDate }
        }
    }

    // MARK: - Helpers

    private static func sectionLabel(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date)     { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        // Within the last week: show day name
        if let daysAgo = cal.dateComponents([.day], from: date, to: .now).day, daysAgo < 7 {
            return date.formatted(.dateTime.weekday(.wide))
        }
        return date.formatted(.dateTime.month(.wide).day().year())
    }
}
