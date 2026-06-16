import Foundation
import HealthKit

struct WorkoutSession: Identifiable, Sendable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let activityType: HKWorkoutActivityType
    let duration: TimeInterval         // seconds
    let activeCalories: Double         // kcal
    let distanceMeters: Double?        // meters, nil for non-distance activities
    let averageHeartRate: Double?      // bpm
    let maxHeartRate: Double?          // bpm
    let heartRateZones: HeartRateZones

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let hours = minutes / 60
        return hours > 0 ? "\(hours)h \(minutes % 60)m" : "\(minutes)m"
    }

    var formattedDistance: String? {
        guard let d = distanceMeters, d > 10 else { return nil }
        return d >= 1000
            ? String(format: "%.2f km", d / 1000)
            : String(format: "%.0f m", d)
    }

    var activityName: String {
        activityType.displayName
    }
}

struct HeartRateZones: Sendable {
    let zone1: TimeInterval  // 50–60% max HR (Recovery)
    let zone2: TimeInterval  // 60–70% max HR (Aerobic base)
    let zone3: TimeInterval  // 70–80% max HR (Aerobic)
    let zone4: TimeInterval  // 80–90% max HR (Threshold)
    let zone5: TimeInterval  // 90–100% max HR (Anaerobic)

    var total: TimeInterval { zone1 + zone2 + zone3 + zone4 + zone5 }

    static let empty = HeartRateZones(zone1: 0, zone2: 0, zone3: 0, zone4: 0, zone5: 0)
}

extension HKWorkoutActivityType {
    var systemImage: String {
        switch self {
        case .running:          return "figure.run"
        case .cycling:          return "figure.outdoor.cycle"
        case .walking:          return "figure.walk"
        case .traditionalStrengthTraining: return "dumbbell.fill"
        case .functionalStrengthTraining:  return "figure.strengthtraining.functional"
        case .highIntensityIntervalTraining: return "bolt.heart.fill"
        case .yoga:             return "figure.yoga"
        case .swimming:         return "figure.pool.swim"
        case .rowing:           return "figure.rowing"
        case .elliptical:       return "figure.elliptical"
        case .stairs:           return "figure.stairs"
        case .crossTraining:    return "figure.cross.training"
        default:                return "figure.mixed.cardio"
        }
    }

    var displayName: String {
        switch self {
        case .running:          return "Run"
        case .cycling:          return "Cycle"
        case .walking:          return "Walk"
        case .traditionalStrengthTraining: return "Strength"
        case .functionalStrengthTraining:  return "Functional"
        case .highIntensityIntervalTraining: return "HIIT"
        case .yoga:             return "Yoga"
        case .swimming:         return "Swim"
        case .rowing:           return "Row"
        case .elliptical:       return "Elliptical"
        case .stairs:           return "Stairs"
        case .crossTraining:    return "Cross Training"
        default:                return "Workout"
        }
    }
}
