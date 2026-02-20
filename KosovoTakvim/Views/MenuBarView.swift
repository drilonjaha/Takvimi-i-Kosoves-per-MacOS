import SwiftUI

struct MenuBarView: View {
    @ObservedObject var viewModel: MenuBarViewModel
    @State private var showingSettings = false
    @State private var showingAttendance = false

    var body: some View {
        if showingAttendance {
            MosqueAttendanceView(onDismiss: { showingAttendance = false })
        } else {
            mainView
        }
    }

    private var mainView: some View {
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

            // Update banner
            if viewModel.updateAvailable, let version = viewModel.updateVersion {
                Button(action: { viewModel.openUpdate() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 12))
                        Text("Përditëso në v\(version)")
                            .font(.system(size: 11, weight: .medium))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.green)
                }
                .buttonStyle(.plain)
            }

            // Prayer list
            PrayerListView(
                prayerTimes: viewModel.prayerTimes,
                currentDate: viewModel.currentDate,
                isRamadanActive: viewModel.isRamadanActive,
                ramadanDay: viewModel.ramadanDay,
                isFasting: viewModel.isFasting,
                iftarCountdown: viewModel.iftarCountdown,
                displayNameForPrayer: { viewModel.displayName(for: $0) }
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

                Button(action: { showingAttendance = true }) {
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 11))
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
                },
                updateAvailable: viewModel.updateAvailable,
                updateVersion: viewModel.updateVersion,
                onUpdate: { viewModel.openUpdate() }
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
    @Published var updateAvailable = false
    @Published var updateVersion: String?
    @Published var updateURL: URL?

    @AppStorage("selectedCityId") private var selectedCityId: String = City.default.id
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @AppStorage("ramadanModeEnabled") var ramadanModeEnabled: Bool = true

    var onPrayerDataChanged: (() -> Void)?

    private var midnightTimer: Timer?
    private var popoverTimer: Timer?

    init() {
        self.selectedCity = City.find(by: UserDefaults.standard.string(forKey: "selectedCityId") ?? City.default.id) ?? City.default
        scheduleMidnightRefresh()
        Task {
            await loadPrayerTimes()
        }
        Task {
            await checkForUpdate()
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

    func startPopoverUpdates() {
        popoverTimer?.invalidate()
        popoverTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateCurrentTime()
            }
        }
    }

    func stopPopoverUpdates() {
        popoverTimer?.invalidate()
        popoverTimer = nil
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

    func checkForUpdate() async {
        let info = await UpdateService.checkForUpdate()
        updateAvailable = info.available
        updateVersion = info.version
        updateURL = info.downloadURL
    }

    func openUpdate() {
        guard let url = updateURL else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Ramadan

    var isRamadanActive: Bool {
        ramadanModeEnabled && RamadanService.isRamadan(date: currentDate)
    }

    var ramadanDay: Int? {
        guard isRamadanActive else { return nil }
        return RamadanService.ramadanDay(for: currentDate)
    }

    var isFasting: Bool {
        guard isRamadanActive, let times = prayerTimes else { return false }
        return RamadanService.isFasting(imsak: times.imsak, maghrib: times.maghrib, now: currentDate)
    }

    var iftarCountdown: String? {
        guard isFasting, let times = prayerTimes else { return nil }
        return TimeFormatter.shared.formatCountdown(to: times.maghrib, from: currentDate)
    }

    func displayName(for prayer: Prayer) -> String {
        guard isRamadanActive else { return prayer.rawValue }
        return RamadanService.ramadanDisplayName(for: prayer)
    }

    var menuBarText: String {
        guard let next = nextPrayer else {
            return "..."
        }

        let showName = UserDefaults.standard.object(forKey: "showPrayerName") as? Bool ?? true
        let countdown = TimeFormatter.shared.formatCountdown(to: next.time)
        let name = displayName(for: next.prayer)

        if showName {
            return "\(name) \(countdown)"
        } else {
            return countdown
        }
    }

    deinit {
        midnightTimer?.invalidate()
        popoverTimer?.invalidate()
    }
}

#Preview {
    MenuBarView(viewModel: MenuBarViewModel())
}
