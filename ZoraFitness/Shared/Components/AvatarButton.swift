import SwiftUI

func initialsFromName(_ name: String) -> String {
    let parts = name.split(separator: " ")
    guard let first = parts.first?.first else { return "?" }
    if parts.count >= 2, let second = parts[1].first {
        return "\(first)\(second)".uppercased()
    }
    return String(first).uppercased()
}

struct AvatarButton: View {
    let initials: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(AppTheme.strainBlue.opacity(0.18))
                    .frame(width: 32, height: 32)
                Text(initials.isEmpty ? "?" : initials)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.strainBlue)
            }
        }
        .buttonStyle(.plain)
    }
}
