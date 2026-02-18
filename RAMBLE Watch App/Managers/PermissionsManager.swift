import AVFoundation
import SwiftUI
import Combine

/// Manages microphone permission requests and status
@MainActor
class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()
    
    @Published var microphonePermissionGranted: Bool = false
    @Published var permissionDenied: Bool = false
    
    private init() {
        checkCurrentStatus()
    }
    
    /// Check current microphone permission status
    func checkCurrentStatus() {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            microphonePermissionGranted = true
            permissionDenied = false
        case .denied:
            microphonePermissionGranted = false
            permissionDenied = true
        case .undetermined:
            microphonePermissionGranted = false
            permissionDenied = false
        @unknown default:
            microphonePermissionGranted = false
            permissionDenied = false
        }
    }
    
    /// Request microphone permission
    func requestMicrophonePermission() async -> Bool {
        let status = AVAudioSession.sharedInstance().recordPermission
        
        switch status {
        case .granted:
            microphonePermissionGranted = true
            return true
            
        case .denied:
            permissionDenied = true
            return false
            
        case .undetermined:
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    Task { @MainActor in
                        self.microphonePermissionGranted = granted
                        self.permissionDenied = !granted
                        continuation.resume(returning: granted)
                    }
                }
            }
            
        @unknown default:
            return false
        }
    }
}
