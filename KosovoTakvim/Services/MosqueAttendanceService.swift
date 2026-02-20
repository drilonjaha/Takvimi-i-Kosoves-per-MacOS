import Foundation

struct MosqueAttendanceRecord: Codable, Equatable {
    var prayersAttended: Set<String>
}

@MainActor
class MosqueAttendanceService: ObservableObject {
    static let shared = MosqueAttendanceService()

    @Published private(set) var records: [String: MosqueAttendanceRecord] = [:]

    private let fileURL: URL

    static let trackablePrayers: [Prayer] = Prayer.allCases.filter { $0.isObligatoryPrayer }
    static let prayersPerDay = trackablePrayers.count

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("KosovoTakvim", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        fileURL = appDir.appendingPathComponent("mosque_attendance.json")
        load()
    }

    // MARK: - Public API

    func isAttended(prayer: Prayer, on date: Date) -> Bool {
        let key = Self.dateFormatter.string(from: date)
        return records[key]?.prayersAttended.contains(prayer.rawValue) ?? false
    }

    func toggleAttendance(prayer: Prayer, on date: Date) {
        let key = Self.dateFormatter.string(from: date)
        var record = records[key] ?? MosqueAttendanceRecord(prayersAttended: [])

        if record.prayersAttended.contains(prayer.rawValue) {
            record.prayersAttended.remove(prayer.rawValue)
        } else {
            record.prayersAttended.insert(prayer.rawValue)
        }

        if record.prayersAttended.isEmpty {
            records.removeValue(forKey: key)
        } else {
            records[key] = record
        }
        save()
    }

    func attendedCount(on date: Date) -> Int {
        let key = Self.dateFormatter.string(from: date)
        return records[key]?.prayersAttended.count ?? 0
    }

    func attendedAll(on date: Date) -> Bool {
        attendedCount(on: date) == Self.prayersPerDay
    }

    /// Current streak: consecutive days (ending today or yesterday) with at least one mosque prayer
    func currentStreak() -> Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        // If today has no entries yet, start from yesterday
        if attendedCount(on: checkDate) == 0 {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = yesterday
        }

        while attendedCount(on: checkDate) > 0 {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }

        return streak
    }

    /// Perfect streak: consecutive days with ALL 5 prayers at the mosque
    func perfectStreak() -> Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        if !attendedAll(on: checkDate) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = yesterday
        }

        while attendedAll(on: checkDate) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }

        return streak
    }

    /// Returns dates for the last N days including today
    func lastDays(_ count: Int) -> [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<count).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }.reversed()
    }

    /// Monthly attendance percentage for a given month
    func monthlyPercentage(for date: Date) -> Double {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: date)!
        let components = calendar.dateComponents([.year, .month], from: date)
        let today = calendar.startOfDay(for: Date())

        var totalPossible = 0
        var totalAttended = 0

        for day in range {
            var dc = components
            dc.day = day
            guard let dayDate = calendar.date(from: dc), dayDate <= today else { continue }
            totalPossible += Self.prayersPerDay
            totalAttended += attendedCount(on: dayDate)
        }

        guard totalPossible > 0 else { return 0 }
        return Double(totalAttended) / Double(totalPossible) * 100
    }

    static func dateKey(for date: Date) -> String {
        dateFormatter.string(from: date)
    }

    // MARK: - Persistence

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            records = try JSONDecoder().decode([String: MosqueAttendanceRecord].self, from: data)
        } catch {
            records = [:]
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(records)
            try data.write(to: fileURL, options: .atomic)
        } catch {}
    }
}
