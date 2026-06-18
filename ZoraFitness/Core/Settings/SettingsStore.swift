import Foundation
import Observation

/// Single source of truth for user-configurable values.
/// Properties persist to UserDefaults via didSet.
/// Injected into the SwiftUI environment alongside HealthKitManager.
@Observable
final class SettingsStore {

    // MARK: - Personal

    /// Used to compute maxHeartRate via 220 − age formula.
    var age: Int = 29 {
        didSet { UserDefaults.standard.set(age, forKey: Keys.age) }
    }

    /// Full name as it appears in the BCHL officials database. Used to match game records.
    var officialName: String = "" {
        didSet { UserDefaults.standard.set(officialName, forKey: Keys.officialName) }
    }

    /// 220 − age. Drives HealthKitManager.maxHeartRate and strain zone calculation.
    var computedMaxHR: Double { Double(220 - age) }

    // MARK: - Training

    /// Nightly sleep target in hours. Shown as a reference line in Analytics.
    var sleepTargetHours: Double = 7.5 {
        didSet { UserDefaults.standard.set(sleepTargetHours, forKey: Keys.sleepTarget) }
    }

    var sleepTargetFormatted: String {
        let h = Int(sleepTargetHours)
        let m = Int((sleepTargetHours - Double(h)) * 60)
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }

    // MARK: - Init

    init() {
        let storedAge = UserDefaults.standard.integer(forKey: Keys.age)
        if storedAge >= 15 && storedAge <= 80 { age = storedAge }

        let storedSleep = UserDefaults.standard.double(forKey: Keys.sleepTarget)
        if storedSleep >= 4 && storedSleep <= 12 { sleepTargetHours = storedSleep }

        officialName = UserDefaults.standard.string(forKey: Keys.officialName) ?? ""
    }

    // MARK: - Keys

    private enum Keys {
        static let age          = "zora.userAge"
        static let sleepTarget  = "zora.sleepTargetHours"
        static let officialName = "zora.officialName"
    }
}
