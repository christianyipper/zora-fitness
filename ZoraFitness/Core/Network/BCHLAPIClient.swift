import Foundation

struct BCHLAPIClient {

    // MARK: - Neon connection (personal-use app, not distributed)
    private let connectionString = "postgresql://neondb_owner:npg_xqByCwA8s7Gh@ep-raspy-hill-ah7tiq9y-pooler.c-3.us-east-1.aws.neon.tech/neondb?sslmode=require"
    private let sqlEndpoint = URL(string: "https://ep-raspy-hill-ah7tiq9y.c-3.us-east-1.aws.neon.tech/sql")!

    // MARK: - Public API

    func fetchRecentGame(for name: String) async throws -> OfficialGame? {
        let sql = """
        SELECT
          g.id,
          g.date,
          g.duration,
          g."startTime",
          g."endTime",
          ht.name AS "homeTeam",
          at.name AS "awayTeam",
          (SELECT COALESCE(SUM(p.minutes), 0) FROM "Penalty" p WHERE p."gameId" = g.id AND p.side = 'home') AS "homePIM",
          (SELECT COALESCE(SUM(p.minutes), 0) FROM "Penalty" p WHERE p."gameId" = g.id AND p.side = 'away') AS "awayPIM",
          (SELECT array_agg(o2.name ORDER BY o2.name) FROM "GameOfficial" go2 JOIN "Official" o2 ON o2.id = go2."officialId" WHERE go2."gameId" = g.id AND go2.role = 'referee') AS referees,
          (SELECT array_agg(o2.name ORDER BY o2.name) FROM "GameOfficial" go2 JOIN "Official" o2 ON o2.id = go2."officialId" WHERE go2."gameId" = g.id AND go2.role = 'linesperson') AS linespersons
        FROM "Game" g
        JOIN "Team" ht ON ht.id = g."homeTeamId"
        JOIN "Team" at ON at.id = g."awayTeamId"
        JOIN "GameOfficial" go ON go."gameId" = g.id
        JOIN "Official" o ON o.id = go."officialId"
        WHERE o.name ILIKE $1
        ORDER BY g.date DESC
        LIMIT 1
        """
        let rows = try await query(sql: sql, params: [name], as: GameRow.self)
        return rows.first.map(OfficialGame.init(row:))
    }

    func fetchGameDates(for name: String) async throws -> [Date] {
        let sql = """
        SELECT DISTINCT g.date
        FROM "Game" g
        JOIN "GameOfficial" go ON go."gameId" = g.id
        JOIN "Official" o ON o.id = go."officialId"
        WHERE o.name ILIKE $1
        ORDER BY g.date DESC
        """
        let rows = try await query(sql: sql, params: [name], as: DateRow.self)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return rows.compactMap { formatter.date(from: $0.date) }
    }

    func fetchOfficialNumbers(for name: String) async throws -> (rNum: String?, lNum: String?) {
        let sql = """
        SELECT r_num, l_num FROM "Official" WHERE name ILIKE $1 LIMIT 1
        """
        let rows = try await query(sql: sql, params: [name], as: OfficialNumbersRow.self)
        guard let row = rows.first else { return (nil, nil) }
        return (row.r_num, row.l_num)
    }

    func fetchTotalGamesWorked(for name: String) async throws -> Int {
        let sql = """
        SELECT COUNT(DISTINCT g.id) AS total
        FROM "Game" g
        JOIN "GameOfficial" go ON go."gameId" = g.id
        JOIN "Official" o ON o.id = go."officialId"
        WHERE o.name ILIKE $1
        """
        let rows = try await query(sql: sql, params: [name], as: TotalRow.self)
        return Int(rows.first?.total ?? "0") ?? 0
    }

    // MARK: - Private helpers

    private func query<T: Decodable>(sql: String, params: [String], as type: T.Type) async throws -> [T] {
        var request = URLRequest(url: sqlEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(connectionString, forHTTPHeaderField: "Neon-Connection-String")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["query": sql, "params": params])

        let (data, _) = try await URLSession.shared.data(for: request)
        let wrapper = try JSONDecoder().decode(NeonResponse<T>.self, from: data)
        return wrapper.rows
    }

    private struct NeonResponse<T: Decodable>: Decodable {
        let rows: [T]
    }

    private struct OfficialNumbersRow: Decodable {
        let r_num: String?
        let l_num: String?
    }

    private struct TotalRow: Decodable {
        let total: String
    }

    private struct DateRow: Decodable {
        let date: String
    }

    // fileprivate so OfficialGame extension below can reference it
    fileprivate struct GameRow: Decodable {
        let id: String
        let date: String
        let duration: Int?
        let startTime: String?
        let endTime: String?
        let homeTeam: String
        let awayTeam: String
        let homePIM: String
        let awayPIM: String
        let referees: [String]?
        let linespersons: [String]?
    }
}

// MARK: - GameRow → OfficialGame

private extension OfficialGame {
    init(row: BCHLAPIClient.GameRow) {
        id = row.id
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        date = formatter.date(from: row.date) ?? Date()
        durationMinutes = row.duration ?? 0
        startTime = row.startTime
        endTime = row.endTime
        homeTeam = row.homeTeam
        awayTeam = row.awayTeam
        homePIM = Int(row.homePIM) ?? 0
        awayPIM = Int(row.awayPIM) ?? 0
        referees = row.referees ?? []
        linespersons = row.linespersons ?? []
    }
}
