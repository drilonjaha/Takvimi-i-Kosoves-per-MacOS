import SwiftUI

struct MosqueAttendanceView: View {
    @ObservedObject var attendanceService = MosqueAttendanceService.shared
    var onDismiss: (() -> Void)? = nil
    @State private var selectedTab: AttendanceTab = .today
    @State private var monthOffset: Int = 0
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var previousTab: AttendanceTab? = nil

    enum AttendanceTab {
        case today, weekly, monthly
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            tabBar
            Divider()

            ScrollView {
                VStack(spacing: 12) {
                    switch selectedTab {
                    case .today:
                        todayChecklist
                    case .weekly:
                        weeklyView
                    case .monthly:
                        monthlyView
                    }
                }
                .padding(12)
            }

            Divider()
            streakFooter
        }
        .frame(width: 320, height: 460)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.accentColor)
                Text("Xhamia")
                    .font(.headline)
            }
            Spacer()
            Button(action: { onDismiss?() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton("Sot", tab: .today)
            tabButton("Java", tab: .weekly)
            tabButton("Muaji", tab: .monthly)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func tabButton(_ title: String, tab: AttendanceTab) -> some View {
        Button(action: {
            if tab == .today {
                selectedDate = Calendar.current.startOfDay(for: Date())
                previousTab = nil
            }
            selectedTab = tab
        }) {
            Text(title)
                .font(.system(size: 11, weight: selectedTab == tab ? .semibold : .regular))
                .foregroundColor(selectedTab == tab ? .white : .secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(selectedTab == tab ? Color.accentColor : Color.clear)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Day Checklist

    private var isViewingAnotherDay: Bool {
        !Calendar.current.isDateInToday(selectedDate)
    }

    private func navigateToDay(_ date: Date) {
        let today = Calendar.current.startOfDay(for: Date())
        guard date <= today else { return }
        previousTab = selectedTab
        selectedDate = Calendar.current.startOfDay(for: date)
        selectedTab = .today
    }

    private func navigateBack() {
        selectedDate = Calendar.current.startOfDay(for: Date())
        if let tab = previousTab {
            selectedTab = tab
            previousTab = nil
        }
    }

    private var todayChecklist: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if isViewingAnotherDay {
                    Button(action: { navigateBack() }) {
                        HStack(spacing: 3) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Kthehu")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                }

                Text(TimeFormatter.shared.formatDate(selectedDate))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
                let count = attendanceService.attendedCount(on: selectedDate)
                Text("\(count)/\(MosqueAttendanceService.prayersPerDay)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(count == MosqueAttendanceService.prayersPerDay ? .green : .secondary)
            }

            ForEach(MosqueAttendanceService.trackablePrayers) { prayer in
                dayPrayerRow(prayer, date: selectedDate)
            }
        }
    }

    private func dayPrayerRow(_ prayer: Prayer, date: Date) -> some View {
        let attended = attendanceService.isAttended(prayer: prayer, on: date)

        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                attendanceService.toggleAttendance(prayer: prayer, on: date)
            }
        }) {
            HStack(spacing: 10) {
                Image(systemName: attended ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(attended ? .green : .secondary.opacity(0.5))

                Image(systemName: prayer.icon)
                    .font(.system(size: 13))
                    .foregroundColor(attended ? .accentColor : .secondary)
                    .frame(width: 20, alignment: .center)

                Text(prayer.rawValue)
                    .font(.system(size: 13, weight: attended ? .medium : .regular))
                    .foregroundColor(attended ? .primary : .secondary)

                Spacer()

                if attended {
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green.opacity(0.7))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(attended ? Color.green.opacity(0.08) : Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Weekly View

    private var weeklyView: some View {
        let days = attendanceService.lastDays(7)

        return VStack(alignment: .leading, spacing: 10) {
            // Column headers
            HStack(spacing: 0) {
                Text("")
                    .frame(width: 70, alignment: .leading)
                ForEach(days, id: \.self) { date in
                    let isFuture = date > Calendar.current.startOfDay(for: Date())
                    Button(action: { navigateToDay(date) }) {
                        Text(dayAbbreviation(date))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Calendar.current.isDateInToday(date) ? .accentColor : .secondary)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .disabled(isFuture)
                }
            }

            ForEach(MosqueAttendanceService.trackablePrayers) { prayer in
                HStack(spacing: 0) {
                    HStack(spacing: 4) {
                        Image(systemName: prayer.icon)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text(shortPrayerName(prayer))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 70, alignment: .leading)

                    ForEach(days, id: \.self) { date in
                        let attended = attendanceService.isAttended(prayer: prayer, on: date)
                        let isToday = Calendar.current.isDateInToday(date)
                        let isFuture = date > Calendar.current.startOfDay(for: Date())

                        ZStack {
                            if isFuture {
                                Circle()
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                    .frame(width: 16, height: 16)
                            } else if attended {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 16, height: 16)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white)
                            } else {
                                Circle()
                                    .fill(isToday ? Color.orange.opacity(0.3) : Color.secondary.opacity(0.15))
                                    .frame(width: 16, height: 16)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }

            Divider()
                .padding(.vertical, 4)

            // Daily totals row
            HStack(spacing: 0) {
                Text("Gjithsej")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 70, alignment: .leading)

                ForEach(days, id: \.self) { date in
                    let count = attendanceService.attendedCount(on: date)
                    let isFuture = date > Calendar.current.startOfDay(for: Date())

                    Button(action: { navigateToDay(date) }) {
                        Text(isFuture ? "-" : "\(count)")
                            .font(.system(size: 10, weight: count == MosqueAttendanceService.prayersPerDay ? .bold : .regular, design: .monospaced))
                            .foregroundColor(count == MosqueAttendanceService.prayersPerDay ? .green : .secondary)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .disabled(isFuture)
                }
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Monthly View

    private var monthlyView: some View {
        let monthDate = selectedMonthDate
        let percentage = attendanceService.monthlyPercentage(for: monthDate)
        let monthName = monthDisplayName(for: monthDate)

        return VStack(alignment: .leading, spacing: 10) {
            monthlyHeader(monthName: monthName, percentage: percentage)
            monthlyWeekdayHeaders
            MonthlyCalendarGrid(monthDate: monthDate, attendanceService: attendanceService, onDayTapped: navigateToDay)
            monthlyLegend
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    private func monthlyHeader(monthName: String, percentage: Double) -> some View {
        HStack(spacing: 8) {
            Button(action: { monthOffset -= 1 }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)

            Text(monthName)
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity)

            Button(action: { monthOffset += 1 }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(monthOffset < 0 ? .accentColor : .secondary.opacity(0.3))
            }
            .buttonStyle(.plain)
            .disabled(monthOffset >= 0)

            Text(String(format: "%.0f%%", percentage))
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(percentageColor(percentage))
        }
    }

    private var monthlyWeekdayHeaders: some View {
        HStack(spacing: 2) {
            ForEach(["H", "Ma", "Me", "Ej", "Pr", "Sh", "Di"], id: \.self) { day in
                Text(day)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthlyLegend: some View {
        HStack(spacing: 12) {
            legendItem(color: .green, label: "5/5")
            legendItem(color: .green.opacity(0.5), label: "3-4")
            legendItem(color: .orange.opacity(0.5), label: "1-2")
            legendItem(color: .secondary.opacity(0.15), label: "0")
        }
        .font(.system(size: 9))
        .padding(.top, 4)
    }

    private var selectedMonthDate: Date {
        Calendar.current.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date()
    }

    private func monthDisplayName(for date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "sq_XK")
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date).capitalized
    }

    private func percentageColor(_ pct: Double) -> Color {
        if pct >= 80 { return .green }
        if pct >= 50 { return .orange }
        return .red
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Streak Footer

    private var streakFooter: some View {
        HStack(spacing: 16) {
            streakBadge(
                value: attendanceService.currentStreak(),
                label: "Dite rresht",
                icon: "flame.fill",
                color: .orange
            )
            Divider()
                .frame(height: 24)
            streakBadge(
                value: attendanceService.perfectStreak(),
                label: "5/5 rresht",
                icon: "star.fill",
                color: .yellow
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func streakBadge(value: Int, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(value > 0 ? color : .secondary.opacity(0.4))

            VStack(alignment: .leading, spacing: 1) {
                Text("\(value)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(value > 0 ? .primary : .secondary)
                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func dayAbbreviation(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "sq_XK")
        f.dateFormat = "EEE"
        let result = f.string(from: date)
        return String(result.prefix(2))
    }

    private func shortPrayerName(_ prayer: Prayer) -> String {
        switch prayer {
        case .fajr: return "Sab"
        case .dhuhr: return "Dre"
        case .asr: return "Iki"
        case .maghrib: return "Aks"
        case .isha: return "Jac"
        default: return String(prayer.rawValue.prefix(3))
        }
    }
}

// MARK: - Monthly Calendar Grid (extracted for type-checker)

private struct MonthlyCalendarGrid: View {
    let monthDate: Date
    @ObservedObject var attendanceService: MosqueAttendanceService
    var onDayTapped: (Date) -> Void

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let components = calendar.dateComponents([.year, .month], from: monthDate)
        let range = calendar.range(of: .day, in: .month, for: monthDate)!
        let firstDay = calendar.date(from: components)!
        let weekdayOffset = (calendar.component(.weekday, from: firstDay) + 5) % 7
        let totalCells = weekdayOffset + range.count
        let rows = (totalCells + 6) / 7

        VStack(spacing: 3) {
            ForEach(Array(0..<rows), id: \.self) { row in
                MonthlyCalendarRow(
                    row: row,
                    weekdayOffset: weekdayOffset,
                    daysInMonth: range.count,
                    components: components,
                    today: today,
                    attendanceService: attendanceService,
                    onDayTapped: onDayTapped
                )
            }
        }
    }
}

private struct MonthlyCalendarRow: View {
    let row: Int
    let weekdayOffset: Int
    let daysInMonth: Int
    let components: DateComponents
    let today: Date
    @ObservedObject var attendanceService: MosqueAttendanceService
    var onDayTapped: (Date) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(0..<7), id: \.self) { col in
                cellForColumn(col)
            }
        }
    }

    @ViewBuilder
    private func cellForColumn(_ col: Int) -> some View {
        let dayNumber = row * 7 + col - weekdayOffset + 1
        if dayNumber >= 1 && dayNumber <= daysInMonth {
            dayCellView(dayNumber: dayNumber)
        } else {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 28)
        }
    }

    private func dayCellView(dayNumber: Int) -> some View {
        let calendar = Calendar.current
        var dc = components
        dc.day = dayNumber
        let dayDate = calendar.date(from: dc)!
        let isFuture = dayDate > today
        let count = attendanceService.attendedCount(on: dayDate)
        let isToday = calendar.isDateInToday(dayDate)

        return MonthDayCell(day: dayNumber, count: count, isToday: isToday, isFuture: isFuture) {
            onDayTapped(dayDate)
        }
    }
}

private struct MonthDayCell: View {
    let day: Int
    let count: Int
    let isToday: Bool
    let isFuture: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(isFuture ? Color.secondary.opacity(0.05) : cellColor)

                if isToday {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.accentColor, lineWidth: 1.5)
                }

                VStack(spacing: 1) {
                    Text("\(day)")
                        .font(.system(size: 10, weight: isToday ? .bold : .regular))
                        .foregroundColor(isFuture ? .secondary.opacity(0.4) : .primary)

                    if !isFuture && count > 0 {
                        Text("\(count)")
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 28)
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
    }

    private var cellColor: Color {
        switch count {
        case 5: return .green
        case 3...4: return .green.opacity(0.5)
        case 1...2: return .orange.opacity(0.5)
        default: return .secondary.opacity(0.15)
        }
    }
}

#Preview {
    MosqueAttendanceView()
}
