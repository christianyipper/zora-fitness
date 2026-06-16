import Foundation

// MARK: - Input / Output Types

struct StrainInput {
    let workoutSessions: [WorkoutSession]
    let activeCalories: Double   // all-day kcal (used for non-workout activity load)
    let steps: Double
    let maxHeartRate: Double     // used when falling back to avg HR estimation
}

struct StrainScore {
    let score: Double            // 0–21
    let workoutLoad: Double      // raw TRIMP contribution from workouts
    let activityLoad: Double     // raw TRIMP contribution from daily activity
    let dominantZone: Int?       // 1–5, whichever zone accumulated the most time today

    var category: Category {
        switch score {
        case 0..<8:   return .recovery
        case 8..<14:  return .moderate
        case 14..<18: return .strenuous
        default:      return .allOut
        }
    }

    enum Category: String {
        case recovery  = "Recovery"
        case moderate  = "Moderate"
        case strenuous = "Strenuous"
        case allOut    = "All Out"
    }
}

// MARK: - Calculator

enum StrainCalculator {

    // Edwards TRIMP zone multipliers (zones 1–5).
    // Each minute in a higher zone contributes exponentially more load.
    private static let zoneMultipliers: [Double] = [1.0, 2.0, 3.0, 4.5, 6.0]

    // Logarithmic scaling constant.
    // Derived so a hard 45-min run (≈130 raw load) maps to strain ≈ 11.
    // Adjust upward if you train at higher volumes.
    private static let logScale: Double = 2.26

    static func calculate(input: StrainInput) -> StrainScore {
        let workoutLoad = input.workoutSessions.reduce(0.0) { $0 + trimp(for: $1, maxHR: input.maxHeartRate) }
        let activityLoad = backgroundLoad(activeCalories: input.activeCalories, steps: input.steps)

        let totalLoad = workoutLoad + activityLoad
        let score = (log(1 + totalLoad) * logScale).clamped(to: 0...21)

        return StrainScore(
            score: score,
            workoutLoad: workoutLoad,
            activityLoad: activityLoad,
            dominantZone: dominantZone(in: input.workoutSessions)
        )
    }

    // MARK: - TRIMP per Workout

    // Zone-weighted Training Impulse for a single session.
    // Prefers actual heart rate zone data; falls back to average HR estimate.
    private static func trimp(for session: WorkoutSession, maxHR: Double) -> Double {
        let zones = session.heartRateZones

        if zones.total > 60 {  // at least 1 minute of real zone data
            let durations = [zones.zone1, zones.zone2, zones.zone3, zones.zone4, zones.zone5]
            return zip(durations, zoneMultipliers).reduce(0.0) { acc, pair in
                acc + (pair.0 / 60.0) * pair.1  // convert seconds → minutes, then weight
            }
        }

        // Fallback: estimate from average HR if zone data is sparse (e.g., strength sessions)
        if let avgHR = session.averageHeartRate, maxHR > 0 {
            let fraction = (avgHR / maxHR).clamped(to: 0...1)
            let durationMinutes = session.duration / 60.0
            // Simple Banister-style TRIMP: duration * HR fraction * exponential factor
            return durationMinutes * fraction * exp(1.92 * fraction)
        }

        return 0
    }

    // MARK: - Background Activity Load

    // Estimates cardiovascular load from daily non-workout movement.
    // Calibrated so a typical 8k-step active day contributes ~5–8 raw load,
    // which adds ~1–1.5 strain points on top of workout contribution.
    private static func backgroundLoad(activeCalories: Double, steps: Double) -> Double {
        let calContribution  = (activeCalories / 100.0) * 2.5
        let stepContribution = (steps / 2000.0) * 1.5
        return calContribution + stepContribution
    }

    // MARK: - Dominant Zone

    private static func dominantZone(in sessions: [WorkoutSession]) -> Int? {
        guard !sessions.isEmpty else { return nil }

        var totals = [Double](repeating: 0, count: 5)
        for s in sessions {
            totals[0] += s.heartRateZones.zone1
            totals[1] += s.heartRateZones.zone2
            totals[2] += s.heartRateZones.zone3
            totals[3] += s.heartRateZones.zone4
            totals[4] += s.heartRateZones.zone5
        }

        guard let max = totals.max(), max > 60,     // ignore if barely any zone data
              let idx = totals.firstIndex(of: max) else { return nil }
        return idx + 1
    }
}

// MARK: - Strain Description Helpers

extension StrainScore {
    var scoreFormatted: String {
        String(format: "%.1f", score)
    }

    var categoryDescription: String {
        switch category {
        case .recovery:  return "Light effort. Good day to let your body restore."
        case .moderate:  return "Solid aerobic effort. Sustainable with good recovery."
        case .strenuous: return "High exertion. Prioritize sleep and nutrition tonight."
        case .allOut:    return "Maximum effort. Full recovery before training hard again."
        }
    }
}
