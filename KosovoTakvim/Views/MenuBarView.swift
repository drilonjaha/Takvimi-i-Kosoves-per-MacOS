import SwiftUI

struct MenuBarView: View {
    @ObservedObject var viewModel: MenuBarViewModel
    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 0) {
            // City header
            HStack {
                Image(systemName: "location.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(viewModel.selectedCity.name)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))

            // Prayer list
            PrayerListView(
                prayerTimes: viewModel.prayerTimes,
                currentDate: viewModel.currentDate
            )

            Divider()

            // Bottom actions
            HStack(spacing: 16) {
                Button(action: { showingSettings = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "gear")
                            .font(.system(size: 11))
                        Text("Cilësimet")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: { viewModel.refreshPrayerTimes() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                        Text("Rifresko")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Button(action: { NSApplication.shared.terminate(nil) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "power")
                            .font(.system(size: 11))
                        Text("Dil")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(width: 280)
        .popover(isPresented: $showingSettings) {
            SettingsView(
                onCityChange: { city in
                    viewModel.selectCity(city)
                },
                onNotificationToggle: { enabled in
                    viewModel.toggleNotifications(enabled)
                }
            )
        }
    }
}

@MainActor
class MenuBarViewModel: ObservableObject {
    @Published var prayerTimes: DailyPrayerTimes?
    @Published var currentDate = Date()
    @Published var selectedCity: City
    @Published var nextPrayer: (prayer: Prayer, time: Date)?
    @Published var isLoading = false
    @Published var error: String?

    @AppStorage("selectedCityId") private var selectedCityId: String = City.default.id
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true

    var onPrayerDataChanged: (() -> Void)?

    private var midnightTimer: Timer?

    init() {
        self.selectedCity = City.find(by: UserDefaults.standard.string(forKey: "selectedCityId") ?? City.default.id) ?? City.default
        scheduleMidnightRefresh()
        Task {
            await loadPrayerTimes()
        }
    }

    private func scheduleMidnightRefresh() {
        let calendar = Calendar.current
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()),
              let midnight = calendar.date(bySettingHour: 0, minute: 1, second: 0, of: tomorrow) else {
            return
        }

        let interval = midnight.timeIntervalSince(Date())
        midnightTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.loadPrayerTimes()
                self?.scheduleMidnightRefresh()
            }
        }
    }

    func updateCurrentTime() {
        currentDate = Date()
        updateNextPrayer()
    }

    private func updateNextPrayer() {
        nextPrayer = prayerTimes?.nextPrayer(after: currentDate)
    }

    func loadPrayerTimes() async {
        isLoading = true
        error = nil

        do {
            prayerTimes = try await PrayerTimeService.shared.fetchPrayerTimes(for: selectedCity)
            updateNextPrayer()
            onPrayerDataChanged?()

            if notificationsEnabled, let times = prayerTimes {
                await NotificationService.shared.scheduleAllPrayerNotifications(times: times)
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func refreshPrayerTimes() {
        Task {
            await loadPrayerTimes()
        }
    }

    func selectCity(_ city: City) {
        selectedCity = city
        selectedCityId = city.id
        refreshPrayerTimes()
    }

    func toggleNotifications(_ enabled: Bool) {
        if enabled {
            Task {
                let granted = await NotificationService.shared.requestAuthorization()
                if granted, let times = prayerTimes {
                    await NotificationService.shared.scheduleAllPrayerNotifications(times: times)
                }
            }
        } else {
            Task {
                await NotificationService.shared.cancelAllNotifications()
            }
        }
    }

    var menuBarText: String {
        guard let next = nextPrayer else {
            return "..."
        }

        let countdown = TimeFormatter.shared.formatCountdown(to: next.time)
        let showName = UserDefaults.standard.object(forKey: "showPrayerName") as? Bool ?? true

        if showName {
            return "\(next.prayer.rawValue) \(countdown)"
        } else {
            return countdown
        }
    }

    deinit {
        midnightTimer?.invalidate()
    }
}

#Preview {
    MenuBarView(viewModel: MenuBarViewModel())
}
