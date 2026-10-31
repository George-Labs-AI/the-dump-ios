import Foundation
import AVFoundation
import Combine

enum RecordingState {
    case idle
    case recording
    case paused
    case stopped
}

enum RecorderError: LocalizedError {
    case permissionDenied
    case setupFailed
    case recordingFailed
    case fileNotFound
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone access denied. Please enable in Settings."
        case .setupFailed:
            return "Failed to set up audio recording"
        case .recordingFailed:
            return "Recording failed"
        case .fileNotFound:
            return "Recording file not found"
        }
    }
}

@MainActor
class AudioRecorderService: NSObject, ObservableObject {
    @Published var state: RecordingState = .idle
    @Published var duration: TimeInterval = 0
    @Published var currentFileURL: URL?
    @Published var errorMessage: String?
    /// The input level while recording, 0 (silence) to 1, for level meters.
    @Published var level: Float = 0
    
    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    /// Pause, rather than silently stop, when a call or another app takes
    /// the microphone. The voice recorder turns this on; it shows "Paused"
    /// and a Resume button. A paused memo never restarts on its own.
    var pausesOnInterruption = false
    private var interruptionCancellable: AnyCancellable?
    private var startTime: Date?
    
    static let maxDurationWarning: TimeInterval = 600 // 10 minutes
    static let maxDurationHard: TimeInterval = 3600 // 1 hour hard limit
    
    override init() {
        super.init()
        interruptionCancellable = NotificationCenter.default
            .publisher(for: AVAudioSession.interruptionNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                MainActor.assumeIsolated {
                    guard let self, self.pausesOnInterruption, self.state == .recording,
                          let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                          AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
                    self.pauseRecording()
                }
            }
    }
    
    // MARK: - Permissions
    
    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    func hasPermission() -> Bool {
        AVAudioApplication.shared.recordPermission == .granted
    }
    
    // MARK: - Recording
    
    /// Voice notes record at 44.1 kHz. Onboarding passes 16 kHz, which is
    /// plenty for speech and keeps a ten-minute recording small enough to
    /// upload quickly for transcription.
    func startRecording(sampleRate: Double = 44100) throws {
        guard hasPermission() else {
            throw RecorderError.permissionDenied
        }
        
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)
        
        let filename = "recording_\(UUID().uuidString).m4a"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(filename)
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
        audioRecorder?.delegate = self
        audioRecorder?.isMeteringEnabled = true
        
        guard audioRecorder?.record() == true else {
            throw RecorderError.recordingFailed
        }
        
        currentFileURL = fileURL
        state = .recording
        startTime = Date()
        startTimer()
    }
    
    func pauseRecording() {
        audioRecorder?.pause()
        state = .paused
        stopTimer()
    }
    
    func resumeRecording() {
        // An interruption switches the audio session off; switch it back on.
        try? AVAudioSession.sharedInstance().setActive(true)
        guard audioRecorder?.record() == true else {
            errorMessage = "Couldn't resume recording"
            return
        }
        state = .recording
        startTimer()
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        state = .stopped
        stopTimer()
        releaseAudioSession()
    }

    /// Let other apps' audio carry on once recording is done.
    private func releaseAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    func discardRecording() {
        audioRecorder?.stop()
        if let url = currentFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        reset()
    }
    
    func reset() {
        audioRecorder?.stop()
        audioRecorder = nil
        currentFileURL = nil
        state = .idle
        duration = 0
        startTime = nil
        stopTimer()
        errorMessage = nil
        level = 0
        releaseAudioSession()
    }
    
    // MARK: - Timer
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self, let recorder = self.audioRecorder, recorder.isRecording else { return }
                self.duration = recorder.currentTime
                recorder.updateMeters()
                // averagePower is in decibels, about -160 (silence) to 0.
                let power = recorder.averagePower(forChannel: 0)
                self.level = max(0, min(1, (power + 50) / 50))
                
                // Hard limit
                if self.duration >= Self.maxDurationHard {
                    self.stopRecording()
                }
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Utility
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var isOverWarningLimit: Bool {
        duration >= Self.maxDurationWarning
    }
}

extension AudioRecorderService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
                errorMessage = "Recording finished unexpectedly"
            }
        }
    }
    
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            errorMessage = error?.localizedDescription ?? "Encoding error"
        }
    }
}
