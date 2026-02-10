import SwiftUI

struct PrayerListView: View {
    let prayerTimes: DailyPrayerTimes?
    let currentDate: Date

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

                Divider()

                // Prayer times list
                VStack(spacing: 0) {
                    ForEach(Prayer.allCases) { prayer in
                        PrayerRowView(
                            prayer: prayer,
                            time: times.time(for: prayer),
                            isNext: isNextPrayer(prayer, times: times),
                            isPassed: isPassed(prayer, times: times),
                            currentDate: currentDate
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

    private let timeFormatter = TimeFormatter.shared

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: prayer.icon)
                .font(.system(size: 14))
                .foregroundColor(iconColor)
                .frame(width: 24, alignment: .center)

            Text(prayer.rawValue)
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
