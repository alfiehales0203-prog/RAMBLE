import AVFoundation
import WatchKit

/// Manages AVAudioSession configuration for recording and playback
class AudioSessionManager {
    static let shared = AudioSessionManager()
    
    private let audioSession = AVAudioSession.sharedInstance()
    
    private init() {}
    
    /// Configure audio session for recording
    /// Keeps recording active even when watch screen turns off
    func configureForRecording() throws {
        try audioSession.setCategory(.playAndRecord, mode: .default)
        try audioSession.setActive(true)
    }
    
    /// Configure audio session for playback
    func configureForPlayback() throws {
        try audioSession.setCategory(.playback, mode: .default)
        try audioSession.setActive(true)
    }
    
    /// Deactivate audio session
    func deactivate() {
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }
}
