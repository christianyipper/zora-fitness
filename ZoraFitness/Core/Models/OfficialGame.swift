import Foundation

struct OfficialGame: Identifiable {
    let id: String
    let date: Date
    let durationMinutes: Int
    let startTime: String?
    let endTime: String?
    let homeTeam: String
    let awayTeam: String
    let homePIM: Int
    let awayPIM: Int
    let referees: [String]
    let linespersons: [String]

    var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }

    var formattedDuration: String {
        let h = durationMinutes / 60
        let m = durationMinutes % 60
        return h > 0 ? "\(h)h \(String(format: "%02d", m))m" : "\(m)m"
    }

    var timeRange: String? {
        guard let s = startTime, let e = endTime else { return nil }
        return "\(s) – \(e)"
    }
}
