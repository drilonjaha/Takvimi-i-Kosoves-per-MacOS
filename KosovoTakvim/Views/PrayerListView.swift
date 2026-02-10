import SwiftUI

struct PrayerListView: View {
    let prayerTimes: DailyPrayerTimes?
    let currentDate: Date
    var isRamadanActive: Bool = false
    var ramadanDay: Int? = nil
    var isFasting: Bool = false
    var iftarCountdown: String? = nil
    var displayNameForPrayer: ((Prayer) -> String)? = nil

    private let timeFormatter = TimeFormatter.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let times = prayerTimes {
                // Date header
                VStack(alignment: .leading, spacing: 2) {
                    Text(timeFormatter.formatDate(currentDate))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)

                    if let hijri = times.hijriDate {
                        Text(hijri)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                // Ramadan header
                if isRamadanActive, let day = ramadanDay {
                    HStack(spacing: 6) {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 12))
                        Text("Ramazani - Dita \(day)")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange)
                }

                // Iftar countdown badge
                if isFasting, let countdown = iftarCountdown {
                    HStack(spacing: 6) {
                        Image(systemName: "sunset.fill")
                            .font(.system(size: 14))
                        Text("Iftari pas")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Text(countdown)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.12))
                }

                Divider()

                // Prayer times list
                VStack(spacing: 0) {
                    ForEach(Prayer.allCases) { prayer in
                        PrayerRowView(
                            prayer: prayer,
                            time: times.time(for: prayer),
                            isNext: isNextPrayer(prayer, times: times),
                            isPassed: isPassed(prayer, times: times),
                            currentDate: currentDate,
                            displayName: displayNameForPrayer?(prayer) ?? prayer.rawValue,
                            isRamadanHighlight: isRamadanActive && (prayer == .imsak || prayer == .maghrib)
                        )
                    }
                }
            } else {
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Duke ngarkuar...")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
    }

    private func isNextPrayer(_ prayer: Prayer, times: DailyPrayerTimes) -> Bool {
        guard let next = times.nextPrayer(after: currentDate) else { return false }
        return next.prayer == prayer
    }

    private func isPassed(_ prayer: Prayer, times: DailyPrayerTimes) -> Bool {
        times.time(for: prayer) <= currentDate
    }
}

struct PrayerRowView: View {
    let prayer: Prayer
    let time: Date
    let isNext: Bool
    let isPassed: Bool
    let currentDate: Date
    var displayName: String = ""
    var isRamadanHighlight: Bool = false

    private let timeFormatter = TimeFormatter.shared

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: prayer.icon)
                .font(.system(size: 14))
                .foregroundColor(iconColor)
                .frame(width: 24, alignment: .center)

            Text(displayName.isEmpty ? prayer.rawValue : displayName)
                .font(.system(size: 13, weight: isNext ? .semibold : .regular))
                .foregroundColor(textColor)

            if isNext {
                Text(timeFormatter.formatCountdown(to: time))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.green)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(4)
            }

            Spacer()

            Text(timeFormatter.formatTime(time))
                .font(.system(size: 13, weight: isNext ? .semibold : .regular, design: .monospaced))
                .foregroundColor(textColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isNext ? Color.accentColor.opacity(0.1) : Color.clear)
    }

    private var iconColor: Color {
        if isRamadanHighlight && !isPassed { return .orange }
        if isNext { return .green }
        if isPassed { return .secondary }
        return .primary
    }

    private var textColor: Color {
        if isPassed { return .secondary }
        return .primary
    }
}

#Preview {
    PrayerListView(prayerTimes: nil, currentDate: Date())
        .frame(width: 280)
}
