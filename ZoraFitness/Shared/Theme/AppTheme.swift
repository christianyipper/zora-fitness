import SwiftUI

enum AppTheme {
    // MARK: - Backgrounds
    static let background     = Color(red: 0.05, green: 0.05, blue: 0.07)
    static let cardBackground = Color(red: 0.10, green: 0.10, blue: 0.13)

    // MARK: - Text
    static let primaryText   = Color.white
    static let secondaryText = Color(white: 0.55)
    static let tertiaryText  = Color(white: 0.32)

    // MARK: - Recovery
    static let recoveryGreen  = Color(red: 0.18, green: 0.90, blue: 0.55)
    static let recoveryYellow = Color(red: 1.00, green: 0.78, blue: 0.20)
    static let recoveryRed    = Color(red: 1.00, green: 0.30, blue: 0.30)

    // MARK: - Strain
    static let strainBlue = Color(red: 0.35, green: 0.78, blue: 1.00)

    // MARK: - Sleep
    static let sleepPurple = Color(red: 0.55, green: 0.40, blue: 0.95)

    // MARK: - Heart Rate Zones (cool → hot)
    static let zoneColors: [Color] = [
        Color(red: 0.42, green: 0.62, blue: 0.95),  // Z1 Recovery   — periwinkle
        Color(red: 0.18, green: 0.80, blue: 0.70),  // Z2 Aerobic    — teal
        Color(red: 0.40, green: 0.85, blue: 0.35),  // Z3 Tempo      — green
        Color(red: 1.00, green: 0.75, blue: 0.20),  // Z4 Threshold  — amber
        Color(red: 1.00, green: 0.30, blue: 0.30),  // Z5 Anaerobic  — red
    ]

    static func zoneColor(_ zone: Int) -> Color {
        zoneColors[max(0, min(zone - 1, zoneColors.count - 1))]
    }

    // MARK: - Typography (scaled, no dynamic type — dashboard is data-dense)
    static let micro       = Font.system(size: 10, weight: .medium)
    static let caption     = Font.system(size: 11, weight: .medium)
    static let label       = Font.system(size: 11, weight: .semibold)
    static let body        = Font.system(size: 14, weight: .regular)
    static let subheadline = Font.system(size: 15, weight: .semibold)
    static let headline    = Font.system(size: 18, weight: .bold)

    // MARK: - Spacing
    static let cardPadding: CGFloat  = 20
    static let cardRadius: CGFloat   = 20
    static let innerRadius: CGFloat  = 16
    static let sectionGap: CGFloat   = 14
}

// MARK: - Category → color

extension RecoveryScore.Category {
    var color: Color {
        switch self {
        case .green:  return AppTheme.recoveryGreen
        case .yellow: return AppTheme.recoveryYellow
        case .red:    return AppTheme.recoveryRed
        }
    }
}
