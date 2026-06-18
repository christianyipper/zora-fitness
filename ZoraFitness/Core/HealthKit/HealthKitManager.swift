import HealthKit
import Foundation
import Observation

@Observable
@MainActor
final class HealthKitManager {

    // MARK: - Published State

    var authorizationStatus: AuthorizationStatus = .notDetermined
    var lastError: Error?

    enum AuthorizationStatus {
        case notDetermined, authorized, denied, unavailable
    }

    // MARK: - Private

    private let store = HKHealthStore()

    // Age-based max heart rate (220 - age). Defaults to 190 for a 30-year-old.
    // Update in Settings or derive from HealthKit DOB if available.
    var maxHeartRate: Double = 190

    // MARK: - Read Types

    private static let readTypes: Set<HKObjectType> = {
        let quantityIDs: [HKQuantityTypeIdentifier] = [
            .heartRateVariabilitySDNN,
            .restingHeartRate,
            .heartRate,
            .activeEnergyBurned,
            .stepCount,
            .appleExerciseTime,
        ]
        var types: Set<HKObjectType> = Set(quantityIDs.map { HKQuantityType($0) })
        types.insert(HKObjectType.workoutType())
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        return types
    }()

    // MARK: - Authorization

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationStatus = .unavailable
            return
        }
        do {
            try await store.requestAuthorization(toShare: [], read: Self.readTypes)
            authorizationStatus = .authorized
        } catch {
            lastError = error
            authorizationStatus = .denied
        }
    }

    var isAuthorized: Bool { authorizationStatus == .authorized }

    // MARK: - HRV

    /// Returns the most recent HRV (SDNN) sample for the given day, in milliseconds.
    func fetchLatestHRV(for date: Date = .now) async throws -> Double? {
        let type = HKQuantityType(.heartRateVariabilitySDNN)
        let samples = try await fetchMostRecentSamples(of: type, on: date, limit: 1)
        return (samples.first as? HKQuantitySample)?
            .quantity.doubleValue(for: .secondUnit(with: .milli))
    }

    /// Returns a 30-day rolling array of (date, hrv) for baseline calculation.
    func fetchHRVHistory(days: Int = 30) async throws -> [(Date, Double)] {
        let type = HKQuantityType(.heartRateVariabilitySDNN)
        let start = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        let samples = try await fetchSamples(of: type, from: start, to: .now)
        return (samples as? [HKQuantitySample])?.map {
            ($0.startDate, $0.quantity.doubleValue(for: .secondUnit(with: .milli)))
        } ?? []
    }

    // MARK: - Resting Heart Rate

    /// Returns the most recent RHR sample for the given day, in bpm.
    func fetchRestingHeartRate(for date: Date = .now) async throws -> Double? {
        let type = HKQuantityType(.restingHeartRate)
        let samples = try await fetchMostRecentSamples(of: type, on: date, limit: 1)
        return (samples.first as? HKQuantitySample)?
            .quantity.doubleValue(for: .count().unitDivided(by: .minute()))
    }

    func fetchRHRHistory(days: Int = 30) async throws -> [(Date, Double)] {
        let type = HKQuantityType(.restingHeartRate)
        let start = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        let samples = try await fetchSamples(of: type, from: start, to: .now)
        return (samples as? [HKQuantitySample])?.map {
            ($0.startDate, $0.quantity.doubleValue(for: .count().unitDivided(by: .minute())))
        } ?? []
    }

    // MARK: - Workouts

    func fetchWorkouts(from startDate: Date, to endDate: Date = .now) async throws -> [HKWorkout] {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
        let samples = try await querySamples(type: .workoutType(), predicate: predicate, sort: sort, limit: HKObjectQueryNoLimit)
        return samples as? [HKWorkout] ?? []
    }

    /// Enriches a raw HKWorkout with heart rate zone breakdown and summary stats.
    func buildWorkoutSession(from workout: HKWorkout) async throws -> WorkoutSession {
        let hrSamples = try await fetchHeartRateSamples(during: workout)
        let bpms = hrSamples.map { $0.quantity.doubleValue(for: .count().unitDivided(by: .minute())) }

        let avgHR = bpms.isEmpty ? nil : bpms.reduce(0, +) / Double(bpms.count)
        let maxHR = bpms.max()
        let zones = computeHeartRateZones(samples: hrSamples, workout: workout)

        let calories = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
            .sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
        let distance = workout.totalDistance?.doubleValue(for: .meter())

        return WorkoutSession(
            id: workout.uuid,
            startDate: workout.startDate,
            endDate: workout.endDate,
            activityType: workout.workoutActivityType,
            duration: workout.duration,
            activeCalories: calories,
            distanceMeters: distance,
            averageHeartRate: avgHR,
            maxHeartRate: maxHR,
            heartRateZones: zones
        )
    }

    // MARK: - Heart Rate during Workout

    func fetchHeartRateSamples(during workout: HKWorkout) async throws -> [HKQuantitySample] {
        let type = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate, options: .strictStartDate)
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        let samples = try await querySamples(type: type, predicate: predicate, sort: sort, limit: HKObjectQueryNoLimit)
        return samples as? [HKQuantitySample] ?? []
    }

    // MARK: - Sleep

    func fetchSleepSession(for date: Date = .now) async throws -> SleepSession? {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }

        // Sleep windows typically start the previous evening
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: date)
        let windowStart = cal.date(byAdding: .hour, value: -20, to: dayStart)!   // 4 AM prior day

        let predicate = HKQuery.predicateForSamples(withStart: windowStart, end: dayStart, options: .strictStartDate)
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        let samples = try await querySamples(type: type, predicate: predicate, sort: sort, limit: HKObjectQueryNoLimit)
        let categorySamples = samples as? [HKCategorySample] ?? []

        guard !categorySamples.isEmpty else { return nil }
        return aggregateSleepSamples(categorySamples, for: date)
    }

    /// Fetches and groups sleep samples for the last N mornings in one batch query.
    func fetchSleepHistory(days: Int) async throws -> [SleepSession] {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return [] }

        let cal = Calendar.current
        // Extend the window start by 20h to capture the first night's pre-midnight samples.
        let firstMorning = cal.date(byAdding: .day, value: -(days - 1), to: cal.startOfDay(for: .now))!
        let windowStart  = cal.date(byAdding: .hour, value: -20, to: firstMorning)!
        let windowEnd    = cal.startOfDay(for: .now)

        let predicate = HKQuery.predicateForSamples(withStart: windowStart, end: windowEnd, options: .strictStartDate)
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        let samples = try await querySamples(type: type, predicate: predicate, sort: sort, limit: HKObjectQueryNoLimit)
        let categorySamples = samples as? [HKCategorySample] ?? []

        guard !categorySamples.isEmpty else { return [] }

        // Assign each sample to the calendar day it ended in (= wake-up morning).
        var byDay: [Date: [HKCategorySample]] = [:]
        for sample in categorySamples {
            let day = cal.startOfDay(for: sample.endDate)
            byDay[day, default: []].append(sample)
        }

        return byDay.compactMap { date, daySamples in
            aggregateSleepSamples(daySamples, for: date)
        }.sorted { $0.date < $1.date }
    }

    // MARK: - Daily Activity

    func fetchActiveCalories(for date: Date = .now) async throws -> Double {
        try await fetchDailySum(for: .activeEnergyBurned, unit: .kilocalorie(), on: date)
    }

    func fetchStepCount(for date: Date = .now) async throws -> Double {
        try await fetchDailySum(for: .stepCount, unit: .count(), on: date)
    }

    func fetchExerciseMinutes(for date: Date = .now) async throws -> Double {
        try await fetchDailySum(for: .appleExerciseTime, unit: .minute(), on: date)
    }

    /// Fetches all daily metrics for a given date in one concurrent call.
    func fetchDailyMetrics(for date: Date = .now) async throws -> DailyMetrics {
        async let hrv = fetchLatestHRV(for: date)
        async let rhr = fetchRestingHeartRate(for: date)
        async let cals = fetchActiveCalories(for: date)
        async let steps = fetchStepCount(for: date)
        async let exMin = fetchExerciseMinutes(for: date)
        async let sleep = fetchSleepSession(for: date)

        return DailyMetrics(
            date: date,
            hrv: try await hrv,
            restingHeartRate: try await rhr,
            activeCalories: try await cals,
            steps: try await steps,
            exerciseMinutes: try await exMin,
            sleep: try await sleep
        )
    }

    // MARK: - Activity History (batch, for streaks + calendar)

    /// Returns per-day steps and exercise minutes for the last N days using
    /// HKStatisticsCollectionQuery (one query per metric, not one per day).
    func fetchActivityHistory(days: Int) async throws -> [(date: Date, steps: Double, exerciseMinutes: Double)] {
        let cal = Calendar.current
        let end   = cal.startOfDay(for: .now)
        let start = cal.date(byAdding: .day, value: -days, to: end)!

        async let stepsMap    = batchDailyStats(for: .stepCount,        unit: .count(),  from: start, to: end)
        async let exerciseMap = batchDailyStats(for: .appleExerciseTime, unit: .minute(), from: start, to: end)

        let (s, e) = try await (stepsMap, exerciseMap)
        let allDates = Set(s.keys).union(Set(e.keys)).sorted()
        return allDates.map { date in
            (date: date, steps: s[date] ?? 0, exerciseMinutes: e[date] ?? 0)
        }
    }

    private func batchDailyStats(for id: HKQuantityTypeIdentifier, unit: HKUnit, from start: Date, to end: Date) async throws -> [Date: Double] {
        let type      = HKQuantityType(id)
        let interval  = DateComponents(day: 1)
        let anchor    = Calendar.current.startOfDay(for: end)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: anchor,
                intervalComponents: interval
            )
            query.initialResultsHandler = { _, collection, error in
                if let error { continuation.resume(throwing: error); return }
                var result: [Date: Double] = [:]
                collection?.enumerateStatistics(from: start, to: end) { stats, _ in
                    if let sum = stats.sumQuantity() {
                        result[stats.startDate] = sum.doubleValue(for: unit)
                    }
                }
                continuation.resume(returning: result)
            }
            self.store.execute(query)
        }
    }

    // MARK: - Private Helpers

    private func fetchDailySum(for id: HKQuantityTypeIdentifier, unit: HKUnit, on date: Date) async throws -> Double {
        let type = HKQuantityType(id)
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            self.store.execute(query)
        }
    }

    private func fetchMostRecentSamples(of type: HKSampleType, on date: Date, limit: Int) async throws -> [HKSample] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
        return try await querySamples(type: type, predicate: predicate, sort: sort, limit: limit)
    }

    private func fetchSamples(of type: HKSampleType, from start: Date, to end: Date) async throws -> [HKSample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)]
        return try await querySamples(type: type, predicate: predicate, sort: sort, limit: HKObjectQueryNoLimit)
    }

    private func querySamples(type: HKSampleType, predicate: NSPredicate?, sort: [NSSortDescriptor], limit: Int) async throws -> [HKSample] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: limit, sortDescriptors: sort) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: samples ?? [])
            }
            self.store.execute(query)
        }
    }

    // MARK: - Heart Rate Zone Computation

    /// Buckets HR samples into 5 zones based on % of maxHeartRate.
    private func computeHeartRateZones(samples: [HKQuantitySample], workout: HKWorkout) -> HeartRateZones {
        guard samples.count > 1 else { return .empty }

        var z1: TimeInterval = 0
        var z2: TimeInterval = 0
        var z3: TimeInterval = 0
        var z4: TimeInterval = 0
        var z5: TimeInterval = 0

        for i in 0..<samples.count - 1 {
            let bpm = samples[i].quantity.doubleValue(for: .count().unitDivided(by: .minute()))
            let interval = samples[i + 1].startDate.timeIntervalSince(samples[i].startDate)
            guard interval > 0 else { continue }

            let pct = bpm / maxHeartRate
            switch pct {
            case ..<0.60: z1 += interval
            case 0.60..<0.70: z2 += interval
            case 0.70..<0.80: z3 += interval
            case 0.80..<0.90: z4 += interval
            default: z5 += interval
            }
        }
        return HeartRateZones(zone1: z1, zone2: z2, zone3: z3, zone4: z4, zone5: z5)
    }

    // MARK: - Sleep Aggregation

    private func aggregateSleepSamples(_ samples: [HKCategorySample], for date: Date) -> SleepSession {
        var rem: TimeInterval = 0
        var deep: TimeInterval = 0
        var core: TimeInterval = 0
        var awake: TimeInterval = 0

        for sample in samples {
            let duration = sample.endDate.timeIntervalSince(sample.startDate)
            guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { continue }
            switch value {
            case .asleepREM:          rem += duration
            case .asleepDeep:         deep += duration
            case .asleepCore, .asleepUnspecified: core += duration
            case .awake, .inBed:      awake += duration
            default:                  break
            }
        }

        let total = rem + deep + core + awake
        return SleepSession(
            date: date,
            totalDuration: total,
            remDuration: rem,
            deepDuration: deep,
            coreDuration: core,
            awakeDuration: awake
        )
    }
}

// MARK: - Errors

enum HealthKitError: LocalizedError {
    case notAvailable
    case unauthorized
    case dataNotFound

    var errorDescription: String? {
        switch self {
        case .notAvailable:  return "HealthKit is not available on this device."
        case .unauthorized:  return "HealthKit authorization was denied. Please enable access in Settings > Privacy > Health."
        case .dataNotFound:  return "No data found for the requested period."
        }
    }
}
