import Foundation

struct RamadanService {
    // Ramadan 2026 dates — update these constants each year
    static let ramadanStartMonth = 2
    static let ramadanStartDay = 19
    static let ramadanEndMonth = 3
    static let ramadanEndDay = 19
    static let ramadanYear = 2026
    static let totalDays = 29

    static func isRamadan(date: Date = Date()) -> Bool {
        let cal = Calendar.current
        let year = cal.component(.year, from: date)
        guard year == ramadanYear else { return false }

        let month = cal.component(.month, from: date)
        let day = cal.component(.day, from: date)

        if month == ramadanStartMonth && day >= ramadanStartDay { return true }
        if month == ramadanEndMonth && day <= ramadanEndDay { return true }
        return false
    }

    static func ramadanDay(for date: Date = Date()) -> Int? {
        guard isRamadan(date: date) else { return nil }
        let cal = Calendar.current
        var startComps = DateComponents()
        startComps.year = ramadanYear
        startComps.month = ramadanStartMonth
        startComps.day = ramadanStartDay
        guard let start = cal.date(from: startComps) else { return nil }
        let startOfDate = cal.startOfDay(for: date)
        let days = cal.dateComponents([.day], from: start, to: startOfDate).day ?? 0
        return min(days + 1, totalDays)
    }

    static func isFasting(imsak: Date, maghrib: Date, now: Date = Date()) -> Bool {
        now >= imsak && now < maghrib
    }

    static func ramadanDisplayName(for prayer: Prayer) -> String {
        switch prayer {
        case .imsak: return "Syfyri"
        case .maghrib: return "Iftari"
        default: return prayer.rawValue
        }
    }
}
