import Foundation

enum Prayer: String, CaseIterable, Identifiable {
    case imsak = "Imsaku"
    case fajr = "Sabahu"
    case sunrise = "Lindja e Diellit"
    case dhuhr = "Dreka"
    case asr = "Ikindia"
    case maghrib = "Akshami"
    case isha = "Jacia"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .imsak: return "moon.fill"
        case .fajr: return "sunrise"
        case .sunrise: return "sun.horizon"
        case .dhuhr: return "sun.max"
        case .asr: return "sun.min"
        case .maghrib: return "sunset"
        case .isha: return "moon.stars"
        }
    }

    // Prayers that require notification (excluding sunrise and imsak)
    var isObligatoryPrayer: Bool {
        self != .sunrise && self != .imsak
    }


}

struct DailyPrayerTimes: Codable {
    let date: Date
    let city: City
    let imsak: Date
    let fajr: Date      // Sabahu = Imsak + 35 minutes
    let sunrise: Date
    let dhuhr: Date
    let asr: Date
    let maghrib: Date
    let isha: Date
    let hijriDate: String?

    // Create with automatic Fajr calculation (Imsak + 35 min)
    init(date: Date, city: City, imsak: Date, sunrise: Date, dhuhr: Date, asr: Date, maghrib: Date, isha: Date, hijriDate: String?) {
        self.date = date
        self.city = city
        self.imsak = imsak
        self.fajr = imsak.addingTimeInterval(35 * 60) // Sabahu is always Imsak + 35 min
        self.sunrise = sunrise
        self.dhuhr = dhuhr
        self.asr = asr
        self.maghrib = maghrib
        self.isha = isha
        self.hijriDate = hijriDate
    }

    func time(for prayer: Prayer) -> Date {
        switch prayer {
        case .imsak: return imsak
        case .fajr: return fajr
        case .sunrise: return sunrise
        case .dhuhr: return dhuhr
        case .asr: return asr
        case .maghrib: return maghrib
        case .isha: return isha
        }
    }

    func nextPrayer(after date: Date = Date()) -> (prayer: Prayer, time: Date)? {
        let prayers: [(Prayer, Date)] = [
            (.imsak, imsak),
            (.fajr, fajr),
            (.sunrise, sunrise),
            (.dhuhr, dhuhr),
            (.asr, asr),
            (.maghrib, maghrib),
            (.isha, isha)
        ]

        for (prayer, time) in prayers {
            if time > date {
                return (prayer, time)
            }
        }

        // All prayers passed for today - return tomorrow's Imsak
        // Calculate tomorrow's imsak time (same time, next day)
        let calendar = Calendar.current
        if let tomorrowImsak = calendar.date(byAdding: .day, value: 1, to: imsak) {
            return (.imsak, tomorrowImsak)
        }

        return nil
    }

}
