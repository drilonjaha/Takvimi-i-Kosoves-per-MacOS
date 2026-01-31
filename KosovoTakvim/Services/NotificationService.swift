import Foundation
import UserNotifications

class NotificationService {
    static let shared = NotificationService()

    // How many minutes before prayer to send reminder
    // TODO: Change back to 15 before shipping
    private let reminderMinutesBefore: Int = 27

    // Timers for playing voice reminders
    private var reminderTimers: [Prayer: Timer] = [:]

    private init() {}

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }

    func schedulePrePrayerReminder(for prayer: Prayer, prayerTime: Date, city: String) async {
        guard prayer.isObligatoryPrayer else { return }

        // Calculate reminder time (15 minutes before prayer)
        let reminderTime = prayerTime.addingTimeInterval(-Double(reminderMinutesBefore * 60))

        // Don't schedule if reminder time has already passed
        guard reminderTime > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "🕌 \(prayer.rawValue) për \(reminderMinutesBefore) minuta!"
        content.subtitle = "Koha për t'u përgatitur"
        content.body = "Ndalo punën tani. Merr abdest dhe përgatitu për namaz. Mos e vono!\n\n📍 \(city)"

        // Use critical sound to ensure it's heard
        content.sound = UNNotificationSound.default

        // Set interruption level for iOS 15+ / macOS 12+
        if #available(macOS 12.0, *) {
            content.interruptionLevel = .timeSensitive
        }

        // Add category for actions
        content.categoryIdentifier = "PRAYER_REMINDER"

        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let identifier = "prayer_reminder_\(prayer.rawValue)_\(prayerTime.timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("Scheduled reminder for \(prayer.rawValue) at \(reminderTime)")
        } catch {
            print("Failed to schedule notification: \(error)")
        }
    }

    func schedulePrayerTimeNotification(for prayer: Prayer, at time: Date, city: String) async {
        guard prayer.isObligatoryPrayer else { return }
        guard time > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "🕋 Koha e \(prayer.rawValue) ka hyrë!"
        content.body = "Allahu Ekber - Fale namazin tani.\n\n📍 \(city)"
        content.sound = UNNotificationSound.default

        if #available(macOS 12.0, *) {
            content.interruptionLevel = .timeSensitive
        }

        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let identifier = "prayer_time_\(prayer.rawValue)_\(time.timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Failed to schedule notification: \(error)")
        }
    }

    func scheduleAllPrayerNotifications(times: DailyPrayerTimes) async {
        // Cancel existing notifications first
        await cancelAllNotifications()

        // Setup notification categories
        setupNotificationCategories()

        for prayer in Prayer.allCases where prayer.isObligatoryPrayer {
            let prayerTime = times.time(for: prayer)

            // Schedule 15-minute reminder
            await schedulePrePrayerReminder(for: prayer, prayerTime: prayerTime, city: times.city.name)

            // Schedule voice reminder timer
            scheduleVoiceReminder(for: prayer, prayerTime: prayerTime)

            // Also schedule notification at prayer time
            await schedulePrayerTimeNotification(for: prayer, at: prayerTime, city: times.city.name)
        }
    }

    private func scheduleVoiceReminder(for prayer: Prayer, prayerTime: Date) {
        // Cancel existing timer for this prayer
        reminderTimers[prayer]?.invalidate()

        // Calculate reminder time (15 minutes before prayer)
        let reminderTime = prayerTime.addingTimeInterval(-Double(reminderMinutesBefore * 60))

        // Don't schedule if reminder time has already passed
        guard reminderTime > Date() else { return }

        let interval = reminderTime.timeIntervalSince(Date())

        // Schedule timer on main thread
        DispatchQueue.main.async {
            self.reminderTimers[prayer] = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
                self?.playVoiceReminder(for: prayer)
            }
        }
    }

    private func playVoiceReminder(for prayer: Prayer) {
        // Check if voice reminders are enabled
        let voiceRemindersEnabled = UserDefaults.standard.object(forKey: "voiceRemindersEnabled") as? Bool ?? true
        guard voiceRemindersEnabled else { return }

        // Play the custom voice recording if it exists
        AudioReminderService.shared.playReminderIfExists(for: prayer)
    }

    private func setupNotificationCategories() {
        let prayerCategory = UNNotificationCategory(
            identifier: "PRAYER_REMINDER",
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        UNUserNotificationCenter.current().setNotificationCategories([prayerCategory])
    }

    func cancelAllNotifications() async {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        // Cancel all voice reminder timers
        DispatchQueue.main.async {
            for timer in self.reminderTimers.values {
                timer.invalidate()
            }
            self.reminderTimers.removeAll()
        }
    }
}
