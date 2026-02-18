import AVFoundation
import WatchKit
import Combine
import SwiftUI

/// Error types for recording operations
enum RecordingError: LocalizedError {
    case permissionDenied
    case audioSessionFailed
    case recorderInitFailed
    case storageFull
    case noActiveRecording
    case fileNotFound
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone access denied"
        case .audioSessionFailed:
            return "Failed to configure audio"
        case .recorderInitFailed:
            return "Failed to start recording"
        case .storageFull:
            return "Not enough storage space"
        case .noActiveRecording:
            return "No active recording"
        case .fileNotFound:
            return "Recording file not found"
        }
    }
}

/// Main manager for recording operations
@MainActor
class RecordingManager: NSObject, ObservableObject {
    static let shared = RecordingManager()
    
    // MARK: - Published Properties
    
    @Published var isRecording: Bool = false
    @Published var currentRecording: Recording?
    @Published var recordings: [Recording] = []
    @Published var recordingDuration: TimeInterval = 0
    @Published var error: RecordingError?
    @Published var showError: Bool = false
    
    // MARK: - Private Properties
    
    private var audioRecorder: AVAudioRecorder?
    private var durationTimer: Timer?
    private var extendedSession: WKExtendedRuntimeSession?
    private let storageManager = StorageManager.shared
    private let audioSessionManager = AudioSessionManager.shared
    private let connectivitySender = WatchConnectivitySender.shared
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        loadRecordings()
    }
    
    // MARK: - Public Methods
    
    /// Start a new recording
    func startRecording() async {
        // Check permissions first
        let permissionsManager = PermissionsManager.shared
        let hasPermission = await permissionsManager.requestMicrophonePermission()
        
        guard hasPermission else {
            setError(.permissionDenied)
            return
        }
        
        // Check storage space
        guard storageManager.hasEnoughSpace() else {
            setError(.storageFull)
            return
        }
        
        // Configure audio session
        do {
            try audioSessionManager.configureForRecording()
        } catch {
            print("Audio session error: \(error)")
            setError(.audioSessionFailed)
            return
        }
        
        // Create new recording
        let recording = Recording()
        currentRecording = recording
        
        // Setup recorder
        let url = storageManager.fileURL(for: recording)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            isRecording = true
            recordingDuration = 0
            
            // Start timer to track duration
            startDurationTimer()
            
            // Start extended runtime session to keep recording when screen sleeps
            startExtendedSession()
            
        } catch {
            print("Recorder init error: \(error)")
            setError(.recorderInitFailed)
            currentRecording = nil
        }
    }
    
    /// Stop the current recording
    func stopRecording() {
        guard isRecording, var recording = currentRecording else {
            return
        }
        
        // Stop recording
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        
        // Stop timer
        stopDurationTimer()
        
        // End extended session
        endExtendedSession()
        
        // Update recording duration
        recording.duration = recordingDuration
        
        // Add to recordings list
        recordings.insert(recording, at: 0)
        storageManager.saveRecordings(recordings)
        
        // Send recording to iPhone
        connectivitySender.sendRecording(recording)
        
        // Reset state
        currentRecording = nil
        recordingDuration = 0
        
        // Deactivate audio session
        audioSessionManager.deactivate()
        
        // Haptic feedback
        WKInterfaceDevice.current().play(.success)
    }
    
    /// Toggle recording state
    func toggleRecording() async {
        if isRecording {
            stopRecording()
        } else {
            await startRecording()
        }
    }
    
    /// Delete a recording
    func deleteRecording(_ recording: Recording) {
        // Notify iPhone about deletion
        connectivitySender.notifyRecordingDeleted(recording)
        
        // Remove file
        do {
            try storageManager.deleteFile(for: recording)
        } catch {
            print("Failed to delete file: \(error)")
        }
        
        // Remove from list
        recordings.removeAll { $0.id == recording.id }
        storageManager.saveRecordings(recordings)
    }
    
    /// Delete multiple recordings
    func deleteRecordings(at offsets: IndexSet) {
        for index in offsets {
            let recording = recordings[index]
            try? storageManager.deleteFile(for: recording)
        }
        recordings.remove(atOffsets: offsets)
        storageManager.saveRecordings(recordings)
    }
    
    /// Load saved recordings
    func loadRecordings() {
        recordings = storageManager.loadRecordings()
    }
    
    /// Get file URL for a recording
    func fileURL(for recording: Recording) -> URL {
        return storageManager.fileURL(for: recording)
    }
    
    // MARK: - Private Methods
    
    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordingDuration += 0.1
            }
        }
    }
    
    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }
    
    private func startExtendedSession() {
        extendedSession = WKExtendedRuntimeSession()
        extendedSession?.delegate = self
        extendedSession?.start()
    }
    
    private func endExtendedSession() {
        extendedSession?.invalidate()
        extendedSession = nil
    }
    
    private func setError(_ error: RecordingError) {
        self.error = error
        self.showError = true
        WKInterfaceDevice.current().play(.failure)
    }
}

// MARK: - AVAudioRecorderDelegate

extension RecordingManager: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag && isRecording {
                // Recording was interrupted unexpectedly
                stopRecording()
            }
        }
    }
    
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            print("Encode error: \(error?.localizedDescription ?? "unknown")")
            stopRecording()
        }
    }
}

// MARK: - WKExtendedRuntimeSessionDelegate

extension RecordingManager: WKExtendedRuntimeSessionDelegate {
    nonisolated func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession, didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: Error?) {
        // Session ended - recording may stop if this happens unexpectedly
        if let error = error {
            print("Extended session invalidated: \(error)")
        }
    }
    
    nonisolated func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        // Session started successfully
    }
    
    nonisolated func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        // Session about to expire - stop recording gracefully
        Task { @MainActor in
            if isRecording {
                stopRecording()
            }
        }
    }
}
