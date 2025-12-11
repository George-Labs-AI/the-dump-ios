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
    
    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var startTime: Date?
    
    static let maxDurationWarning: TimeInterval = 600 // 10 minutes
    static let maxDurationHard: TimeInterval = 3600 // 1 hour hard limit
    
    override init() {
        super.init()
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
    
    func startRecording() throws {
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
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
        audioRecorder?.delegate = self
        
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
        audioRecorder?.record()
        state = .recording
        startTimer()
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        state = .stopped
        stopTimer()
    }
    
    func discardRecording() {
        audioRecorder?.stop()
        if let url = currentFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        reset()
    }
    
    func reset() {
        audioRecorder = nil
        currentFileURL = nil
        state = .idle
        duration = 0
        startTime = nil
        stopTimer()
        errorMessage = nil
    }
    
    // MARK: - Timer
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self, let recorder = self.audioRecorder, recorder.isRecording else { return }
                self.duration = recorder.currentTime
                
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
