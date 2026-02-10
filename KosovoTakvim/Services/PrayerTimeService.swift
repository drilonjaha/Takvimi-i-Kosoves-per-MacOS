import Foundation

enum PrayerTimeError: Error, LocalizedError {
    case networkError(Error)
    case invalidResponse
    case parsingError
    case noCache
    case noDataForDate

    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .parsingError:
            return "Failed to parse prayer times"
        case .noCache:
            return "No cached data available"
        case .noDataForDate:
            return "No prayer times available for this date"
        }
    }
}

actor PrayerTimeService {
    static let shared = PrayerTimeService()

    private var cache: [String: DailyPrayerTimes] = [:]
    private let cacheKey = "cachedPrayerTimes"

    init() {
        loadCacheFromDisk()
    }

    func fetchPrayerTimes(for city: City, date: Date = Date()) async throws -> DailyPrayerTimes {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)

        // Use official BIM Kosovo data for 2026 (always prioritize over cache)
        if year == 2026 {
            if let times = PrayerTimesData2026.getPrayerTimes(for: date, city: city) {
                let cacheId = cacheKey(for: city, date: date)
                cache[cacheId] = times
                saveCacheToDisk()
                return times
            }
        }

        let cacheId = cacheKey(for: city, date: date)

        // Check memory cache for non-2026 dates
        if let cached = cache[cacheId] {
            return cached
        }

        // Fallback to API for other years
        do {
            let times = try await fetchFromAPI(city: city, date: date)
            cache[cacheId] = times
            saveCacheToDisk()
            return times
        } catch {
            // Try to return stale cache for same city
            if let fallback = cache.values.first(where: { $0.city.id == city.id }) {
                return fallback
            }
            throw error
        }
    }

    private func fetchFromAPI(city: City, date: Date) async throws -> DailyPrayerTimes {
        let baseURL = "https://api.aladhan.com/v1/timings"
        let methodSettings = "18,null,17" // BIM Kosovo angles

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM-yyyy"
        let dateString = dateFormatter.string(from: date)

        var components = URLComponents(string: "\(baseURL)/\(dateString)")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(city.latitude)),
            URLQueryItem(name: "longitude", value: String(city.longitude)),
            URLQueryItem(name: "method", value: "99"),
            URLQueryItem(name: "methodSettings", value: methodSettings)
        ]

        guard let url = components.url else {
            throw PrayerTimeError.invalidResponse
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PrayerTimeError.invalidResponse
        }

        let aladhanResponse = try JSONDecoder().decode(AladhanResponse.self, from: data)
        return try parsePrayerTimes(from: aladhanResponse, city: city, date: date)
    }

    private func parsePrayerTimes(from response: AladhanResponse, city: City, date: Date) throws -> DailyPrayerTimes {
        let timings = response.data.timings
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)

        func parseTime(_ timeString: String) -> Date? {
            let parts = timeString.components(separatedBy: " ").first ?? timeString
            let timeParts = parts.components(separatedBy: ":")
            guard timeParts.count == 2,
                  let hour = Int(timeParts[0]),
                  let minute = Int(timeParts[1]) else {
                return nil
            }

            var components = dateComponents
            components.hour = hour
            components.minute = minute
            components.second = 0
            return calendar.date(from: components)
        }

        // Use Imsak from API (Fajr/Sabahu will be calculated as Imsak + 35 min)
        guard let imsak = parseTime(timings.Imsak),
              let sunrise = parseTime(timings.Sunrise),
              let dhuhr = parseTime(timings.Dhuhr),
              let asr = parseTime(timings.Asr),
              let maghrib = parseTime(timings.Maghrib),
              let isha = parseTime(timings.Isha) else {
            throw PrayerTimeError.parsingError
        }

        let hijri = response.data.date.hijri
        let hijriDate = "\(hijri.day) \(hijri.month.en) \(hijri.year)"

        // Fajr/Sabahu is automatically calculated as Imsak + 35 min in the initializer
        return DailyPrayerTimes(
            date: date,
            city: city,
            imsak: imsak,
            sunrise: sunrise,
            dhuhr: dhuhr,
            asr: asr,
            maghrib: maghrib,
            isha: isha,
            hijriDate: hijriDate
        )
    }

    private func cacheKey(for city: City, date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return "\(city.id)_\(dateFormatter.string(from: date))"
    }

    private func loadCacheFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let decoded = try? JSONDecoder().decode([String: DailyPrayerTimes].self, from: data) else {
            return
        }
        cache = decoded
    }

    private func saveCacheToDisk() {
        guard let encoded = try? JSONEncoder().encode(cache) else { return }
        UserDefaults.standard.set(encoded, forKey: cacheKey)
    }

}
