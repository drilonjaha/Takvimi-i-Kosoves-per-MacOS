import Foundation

struct TimeFormatter {
    static let shared = TimeFormatter()

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM yyyy"
        formatter.locale = Locale(identifier: "sq_XK")
        return formatter
    }()

    func formatTime(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    func formatDate(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    func formatCountdown(to date: Date, from now: Date = Date()) -> String {
        let interval = date.timeIntervalSince(now)

        if interval <= 0 {
            return "Tani"
        }

        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

}
