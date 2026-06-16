import Foundation

struct DailyMetrics: Sendable {
    let date: Date
    let hrv: Double?              // SDNN in milliseconds
    let restingHeartRate: Double? // beats per minute
    let activeCalories: Double    // kcal
    let steps: Double
    let exerciseMinutes: Double
    let sleep: SleepSession?      // full session including stage breakdown

    var formattedDate: String {
        date.formatted(.dateTime.weekday(.wide).month().day())
    }
}

extension DailyMetrics {
    static let empty = DailyMetrics(
        date: .now,
        hrv: nil,
        restingHeartRate: nil,
        activeCalories: 0,
        steps: 0,
        exerciseMinutes: 0,
        sleep: nil
    )
}
