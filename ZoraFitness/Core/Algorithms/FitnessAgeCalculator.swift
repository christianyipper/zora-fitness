import Foundation

// Estimates physiological age from a 30-day HRV baseline using a linear fit
// to published SDNN population norms: HRV ≈ 82.5 − 0.85 × age
// (source: Umetani et al. / Task Force normative tables).
// Inverted: fitnessAge ≈ (82.5 − hrv) / 0.85, clamped to [18, 80].
enum FitnessAgeCalculator {

    static func calculate(hrv30DayAvg: Double) -> Int? {
        guard hrv30DayAvg > 0 else { return nil }
        return Int(((82.5 - hrv30DayAvg) / 0.85).clamped(to: 18.0...80.0))
    }

    // Signed delta: negative means younger than chronological age (good).
    static func delta(fitnessAge: Int, chronologicalAge: Int) -> Int {
        fitnessAge - chronologicalAge
    }
}
