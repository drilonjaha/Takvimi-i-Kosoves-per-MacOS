import Foundation
import AVFoundation
import AppKit

class AudioReminderService: NSObject, ObservableObject {
    static let shared = AudioReminderService()

    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var recordingPrayer: Prayer?
    @Published var playingPrayer: Prayer?
    @Published var permissionDenied = false

    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?

    private let fileManager = FileManager.default

    private override init() {
        super.init()
    }

    func checkMicrophonePermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    self.permissionDenied = !granted
                    completion(granted)
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.permissionDenied = true
                completion(false)
            }
        @unknown default:
            completion(false)
        }
    }

    func openSystemPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - File Management

    private func getDocumentsDirectory() -> URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    func getAudioURL(for prayer: Prayer) -> URL {
        getDocumentsDirectory().appendingPathComponent("reminder_\(prayer.rawValue).m4a")
    }

    func hasRecording(for prayer: Prayer) -> Bool {
        let url = getAudioURL(for: prayer)
        guard fileManager.fileExists(atPath: url.path) else { return false }

        // Check file size is not empty
        if let attrs = try? fileManager.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64 {
            return size > 100 // Must be more than just a header
        }
        return false
    }

    func deleteRecording(for prayer: Prayer) {
        let url = getAudioURL(for: prayer)
        try? fileManager.removeItem(at: url)
    }

    // MARK: - Recording

    func startRecording(for prayer: Prayer) {
        checkMicrophonePermission { [weak self] granted in
            guard let self = self else { return }

            if !granted {
                print("Microphone permission not granted")
                DispatchQueue.main.async {
                    self.permissionDenied = true
                }
                return
            }

            self.performRecording(for: prayer)
        }
    }

    private func performRecording(for prayer: Prayer) {
        // Stop any existing recording first
        if isRecording {
            stopRecording()
        }

        // Check available audio devices
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInMicrophone, .externalUnknown],
            mediaType: .audio,
            position: .unspecified
        )
        print("Available audio devices: \(discoverySession.devices.map { $0.localizedName })")

        if discoverySession.devices.isEmpty {
            print("ERROR: No audio input devices found!")
            DispatchQueue.main.async {
                self.permissionDenied = true
            }
            return
        }

        let audioURL = getAudioURL(for: prayer)
        print("Starting recording at: \(audioURL.path)")

        // Use simpler settings that are more compatible
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatAppleLossless),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()

            let success = audioRecorder?.record() ?? false
            print("Recording started: \(success)")

            if success {
                DispatchQueue.main.async {
                    self.isRecording = true
                    self.recordingPrayer = prayer
                }
            } else {
                print("Failed to start recording - record() returned false")
                print("Recorder device settings: \(audioRecorder?.settings ?? [:])")
            }
        } catch {
            print("Failed to create recorder: \(error)")
        }
    }

    func stopRecording() {
        let duration = audioRecorder?.currentTime ?? 0
        print("Stopping recording, duration: \(duration)s")

        audioRecorder?.stop()
        audioRecorder = nil

        DispatchQueue.main.async {
            self.isRecording = false
            self.recordingPrayer = nil
        }
    }

    // MARK: - Playback

    func playRecording(for prayer: Prayer) {
        let url = getAudioURL(for: prayer)

        guard fileManager.fileExists(atPath: url.path) else {
            print("No recording found for \(prayer.rawValue)")
            return
        }

        // Stop any current playback first
        stopPlayback()

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.volume = 1.0
            audioPlayer?.prepareToPlay()

            // Check if recording has content
            guard let duration = audioPlayer?.duration, duration > 0.1 else {
                print("Recording for \(prayer.rawValue) is empty or too short")
                return
            }

            let success = audioPlayer?.play() ?? false
            print("Playing recording for \(prayer.rawValue): \(success), duration: \(duration)s")

            if success {
                DispatchQueue.main.async {
                    self.isPlaying = true
                    self.playingPrayer = prayer
                }
            }
        } catch {
            print("Failed to play recording: \(error)")
        }
    }

    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil

        DispatchQueue.main.async {
            self.isPlaying = false
            self.playingPrayer = nil
        }
    }

    // MARK: - Reminder Playback

    func playReminderIfExists(for prayer: Prayer) {
        guard hasRecording(for: prayer) else { return }

        // Bring audio to foreground
        DispatchQueue.main.async {
            self.playRecording(for: prayer)
        }
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioReminderService: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isRecording = false
            self.recordingPrayer = nil
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioReminderService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.playingPrayer = nil
        }
    }
}
