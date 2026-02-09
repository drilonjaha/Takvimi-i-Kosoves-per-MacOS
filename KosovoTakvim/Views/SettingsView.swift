import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("selectedCityId") private var selectedCityId: String = City.default.id
    @AppStorage("showPrayerName") private var showPrayerName: Bool = true
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("voiceRemindersEnabled") private var voiceRemindersEnabled: Bool = true
    @AppStorage("coloredCountdown") private var coloredCountdown: Bool = true

    @Environment(\.dismiss) private var dismiss
    @State private var showVoiceRecorder = false

    var onCityChange: ((City) -> Void)?
    var onNotificationToggle: ((Bool) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Cilesimet")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // City Selection with Country Grouping
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Qyteti")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.top, 12)

                        Picker("Qyteti", selection: $selectedCityId) {
                            ForEach(City.citiesByCountry, id: \.country.id) { group in
                                Section(header: Text("\(group.country.flag) \(group.country.name)")) {
                                    ForEach(group.cities) { city in
                                        Text(city.name).tag(city.id)
                                    }
                                }
                            }
                        }
                        .labelsHidden()
                        .onChange(of: selectedCityId) { newValue in
                            if let city = City.find(by: newValue) {
                                onCityChange?(city)
                            }
                        }

                        // Show data source indicator
                        if let city = City.find(by: selectedCityId) {
                            HStack(spacing: 4) {
                                Image(systemName: city.hasOfficialData ? "checkmark.seal.fill" : "globe")
                                    .font(.system(size: 10))
                                Text(city.hasOfficialData ? "Te dhenat zyrtare te BIK" : "Te dhenat nga Aladhan API")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(city.hasOfficialData ? .green : .secondary)
                        }
                    }

                    Divider()

                    // Display Options
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Shfaqja")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)

                        Toggle("Shfaq emrin e namazit", isOn: $showPrayerName)
                            .toggleStyle(.checkbox)
                            .font(.system(size: 13))

                        Toggle("Ngjyrat e kohes (portokalli < 1h, kuq < 30m)", isOn: $coloredCountdown)
                            .toggleStyle(.checkbox)
                            .font(.system(size: 13))
                    }

                    Divider()

                    // Notifications
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Njoftimet")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)

                        Toggle("Aktivizo njoftimet", isOn: $notificationsEnabled)
                            .toggleStyle(.checkbox)
                            .font(.system(size: 13))
                            .onChange(of: notificationsEnabled) { newValue in
                                onNotificationToggle?(newValue)
                            }

                        Toggle("Luaj zerin tim para namazit", isOn: $voiceRemindersEnabled)
                            .toggleStyle(.checkbox)
                            .font(.system(size: 13))
                            .disabled(!notificationsEnabled)

                        Button(action: { showVoiceRecorder = true }) {
                            HStack {
                                Image(systemName: "mic.fill")
                                Text("Regjistro zerin")
                            }
                            .font(.system(size: 12))
                        }
                        .buttonStyle(.bordered)
                        .disabled(!notificationsEnabled || !voiceRemindersEnabled)
                    }

                    Divider()

                    // Launch at Login
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Sistemi")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)

                        Toggle("Hap me ndezjen e kompjuterit", isOn: $launchAtLogin)
                            .toggleStyle(.checkbox)
                            .font(.system(size: 13))
                            .onChange(of: launchAtLogin) { newValue in
                                updateLaunchAtLogin(newValue)
                            }
                    }

                    Spacer(minLength: 16)
                }
            }

            Divider()

            // Footer
            HStack {
                Spacer()
                Text("Takvimi v1.2")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.top, 12)
        }
        .padding(16)
        .frame(width: 300, height: 480)
        .sheet(isPresented: $showVoiceRecorder) {
            VoiceRecorderView()
        }
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update launch at login: \(error)")
        }
    }
}

// MARK: - Voice Recorder View

struct VoiceRecorderView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var audioService = AudioReminderService.shared

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Regjistro Zerin")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Text("Regjistro nje mesazh per secilin namaz qe do te luhet 15 minuta para kohes.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)

            // Permission denied warning
            if audioService.permissionDenied {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "mic.slash.fill")
                            .foregroundColor(.red)
                        Text("Mikrofoni nuk eshte i lejuar")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red)
                    }

                    Button("Hap Cilesimet e Sistemit") {
                        audioService.openSystemPreferences()
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.bordered)
                }
                .padding(10)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }

            Divider()

            // Prayer list with recording controls
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Prayer.allCases.filter { $0.isObligatoryPrayer }) { prayer in
                        VoiceRecordingRow(prayer: prayer, audioService: audioService)
                    }
                }
            }

            Spacer()

            Button("Mbyll") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .frame(width: 320, height: 420)
        .onAppear {
            // Check permission status on appear
            audioService.checkMicrophonePermission { _ in }
        }
    }
}

struct VoiceRecordingRow: View {
    let prayer: Prayer
    @ObservedObject var audioService: AudioReminderService

    @State private var hasRecording: Bool = false

    var body: some View {
        HStack {
            Image(systemName: prayer.icon)
                .frame(width: 24)
                .foregroundColor(.accentColor)

            Text(prayer.rawValue)
                .font(.system(size: 13, weight: .medium))

            Spacer()

            if audioService.isRecording && audioService.recordingPrayer == prayer {
                // Recording in progress
                Button(action: { audioService.stopRecording() }) {
                    Image(systemName: "stop.circle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 20))
                }
                .buttonStyle(.plain)

                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .opacity(0.8)
            } else {
                // Record button
                Button(action: { audioService.startRecording(for: prayer) }) {
                    Image(systemName: "mic.circle")
                        .font(.system(size: 20))
                }
                .buttonStyle(.plain)
                .disabled(audioService.isRecording || audioService.isPlaying)

                // Play button (if recording exists)
                if hasRecording {
                    let isThisPrayerPlaying = audioService.isPlaying && audioService.playingPrayer == prayer

                    Button(action: {
                        if isThisPrayerPlaying {
                            audioService.stopPlayback()
                        } else {
                            audioService.playRecording(for: prayer)
                        }
                    }) {
                        Image(systemName: isThisPrayerPlaying ? "stop.fill" : "play.fill")
                            .font(.system(size: 16))
                            .foregroundColor(isThisPrayerPlaying ? .orange : .primary)
                    }
                    .buttonStyle(.plain)
                    .disabled(audioService.isRecording)

                    // Delete button
                    Button(action: {
                        audioService.deleteRecording(for: prayer)
                        updateHasRecording()
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .disabled(audioService.isRecording || audioService.isPlaying)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .onAppear {
            updateHasRecording()
        }
        .onChange(of: audioService.isRecording) { _ in
            updateHasRecording()
        }
    }

    private func updateHasRecording() {
        hasRecording = audioService.hasRecording(for: prayer)
    }
}

#Preview {
    SettingsView()
}
