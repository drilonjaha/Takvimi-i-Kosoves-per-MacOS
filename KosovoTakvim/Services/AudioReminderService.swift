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

        if discoverySession.devices.isEmpty {
            DispatchQueue.main.async {
                self.permissionDenied = true
            }
            return
        }

        let audioURL = getAudioURL(for: prayer)

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

            if success {
                DispatchQueue.main.async {
                    self.isRecording = true
                    self.recordingPrayer = prayer
                }
            } else {
            }
        } catch {
            }
    }

    func stopRecording() {
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
            guard let player = audioPlayer, player.duration > 0.1 else { return }

            if audioPlayer?.play() == true {
                DispatchQueue.main.async {
                    self.isPlaying = true
                    self.playingPrayer = prayer
                }
            }
        } catch {
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
