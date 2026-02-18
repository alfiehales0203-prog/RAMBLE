import AVFoundation
import WatchKit
import Combine

/// Manages microphone permissions for recording
@MainActor
class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()
    
    @Published var microphonePermissionGranted: Bool = false
    
    private init() {
        checkCurrentStatus()
    }
    
    /// Check current microphone permission status
    func checkCurrentStatus() {
        let status = AVAudioSession.sharedInstance().recordPermission
        microphonePermissionGranted = (status == .granted)
    }
    
    /// Request microphone permission
    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                Task { @MainActor in
                    self.microphonePermissionGranted = granted
                    continuation.resume(returning: granted)
                }
            }
        }
    }
}
