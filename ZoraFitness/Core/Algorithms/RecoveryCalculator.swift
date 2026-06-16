import Foundation

// MARK: - Input / Output Types

struct RecoveryInput {
    let todayHRV: Double?              // ms, or nil if unavailable
    let todayRHR: Double?              // bpm, or nil if unavailable
    let hrvHistory: [Double]           // last N days of HRV samples (ms)
    let rhrHistory: [Double]           // last N days of RHR samples (bpm)
    let lastNightSleep: SleepSession?
    let previousDayStrain: Double      // 0–21, used to compute sleep need
}

struct RecoveryScore {
    let overall: Double         // 0–100
    let hrvComponent: Double    // 0–100
    let rhrComponent: Double    // 0–100
    let sleepComponent: Double  // 0–100

    var category: Category {
        switch overall {
        case 0..<34:  return .red
        case 34..<67: return .yellow
        default:      return .green
        }
    }

    enum Category {
        case red, yellow, green

        var label: String {
            switch self {
            case .red:    return "Poor"
            case .yellow: return "Moderate"
            case .green:  return "Optimal"
            }
        }
    }
}

// MARK: - Calculator

enum RecoveryCalculator {

    // Component weights (must sum to 1.0)
    private static let wHRV   = 0.50
    private static let wRHR   = 0.25
    private static let wSleep = 0.25

    // Sigmoid steepness: controls how aggressively deviations from baseline are penalized.
    // 0.8 means ±1 SD → ~68–32% score band, which feels accurate vs Whoop's sensitivity.
    private static let sigmoidSteepness = 0.8

    static func calculate(input: RecoveryInput) -> RecoveryScore {
        let hrv   = hrvScore(today: input.todayHRV, history: input.hrvHistory)
        let rhr   = rhrScore(today: input.todayRHR, history: input.rhrHistory)
        let sleep = sleepScore(session: input.lastNightSleep, previousStrain: input.previousDayStrain)

        let overall = (wHRV * hrv + wRHR * rhr + wSleep * sleep).clamped(to: 0...100)

        return RecoveryScore(
            overall: overall,
            hrvComponent: hrv,
            rhrComponent: rhr,
            sleepComponent: sleep
        )
    }

    // MARK: - HRV Component

    // Higher HRV relative to personal baseline = better recovery.
    // Maps the z-score through a sigmoid so the score stays bounded even with outlier days.
    private static func hrvScore(today: Double?, history: [Double]) -> Double {
        guard let today, !history.isEmpty else { return 50 }

        let std = history.standardDeviation
        guard std > 0 else {
            return today >= history.mean ? 70 : 40
        }

        let z = (today - history.mean) / std
        return (sigmoid(z, steepness: sigmoidSteepness) * 100).clamped(to: 0...100)
    }

    // MARK: - RHR Component

    // Lower RHR relative to baseline = better recovery (inverted z-score).
    private static func rhrScore(today: Double?, history: [Double]) -> Double {
        guard let today, !history.isEmpty else { return 50 }

        let std = history.standardDeviation
        guard std > 0 else {
            return today <= history.mean ? 70 : 40
        }

        let z = (today - history.mean) / std
        return (sigmoid(-z, steepness: sigmoidSteepness) * 100).clamped(to: 0...100)
    }

    // MARK: - Sleep Component

    // Combines sleep efficiency (quality) with duration vs. dynamic sleep need.
    // Sleep need is 7h baseline + up to 2h extra scaled by prior day's strain.
    private static func sleepScore(session: SleepSession?, previousStrain: Double) -> Double {
        guard let session, session.totalDuration > 0 else { return 25 }

        let need = sleepNeedSeconds(forStrain: previousStrain)
        let durationRatio = (session.totalDuration / need).clamped(to: 0...1.15)  // cap bonus at 115%
        let normalizedDuration = durationRatio / 1.15

        // 60% weight to quality (efficiency), 40% to duration vs need
        let raw = 0.60 * session.efficiency + 0.40 * normalizedDuration
        return (raw * 100).clamped(to: 0...100)
    }

    // MARK: - Sleep Need

    /// Returns sleep need in seconds. Exposed so views can display the target.
    static func sleepNeedSeconds(forStrain strain: Double) -> TimeInterval {
        let base = 7.0 * 3600          // 7 hours
        let bonus = (strain / 21.0) * 2.0 * 3600  // up to 2 extra hours at max strain
        return base + bonus
    }

    static func sleepNeedFormatted(forStrain strain: Double) -> String {
        let seconds = sleepNeedSeconds(forStrain: strain)
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
    }
}
