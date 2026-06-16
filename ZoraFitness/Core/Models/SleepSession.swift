import Foundation
import HealthKit

struct SleepSession: Sendable {
    let date: Date                 // night of the session (start date)
    let totalDuration: TimeInterval
    let remDuration: TimeInterval
    let deepDuration: TimeInterval
    let coreDuration: TimeInterval
    let awakeDuration: TimeInterval

    var efficiency: Double {
        guard totalDuration > 0 else { return 0 }
        return (totalDuration - awakeDuration) / totalDuration
    }

    var formattedDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    static let empty = SleepSession(
        date: .now,
        totalDuration: 0,
        remDuration: 0,
        deepDuration: 0,
        coreDuration: 0,
        awakeDuration: 0
    )
}

extension HKCategoryValueSleepAnalysis {
    var isAsleep: Bool {
        switch self {
        case .asleepCore, .asleepDeep, .asleepREM, .asleepUnspecified: return true
        default: return false
        }
    }
}
