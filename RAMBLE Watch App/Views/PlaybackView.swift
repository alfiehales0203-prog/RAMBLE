import SwiftUI
import SwiftUI
import AVFoundation
import Combine

/// View for playing back a recording
struct PlaybackView: View {
    let recording: Recording
    
    @StateObject private var player = AudioPlayer()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            // Title
            Text(recording.title)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            // Progress
            VStack(spacing: 4) {
                // Time display
                HStack {
                    Text(formatTime(player.currentTime))
                        .font(.system(.caption2, design: .monospaced))
                    Spacer()
                    Text(formatTime(recording.duration))
                        .font(.system(.caption2, design: .monospaced))
                }
                .foregroundColor(.secondary)
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 4)
                        
                        // Progress
                        Capsule()
                            .fill(Color.red)
                            .frame(width: geometry.size.width * progress, height: 4)
                    }
                }
                .frame(height: 4)
            }
            
            // Play/Pause button
            Button {
                player.togglePlayback()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .offset(x: player.isPlaying ? 0 : 2) // Visual balance for play icon
                }
            }
            .buttonStyle(.plain)
            
            // Delete button
            Button(role: .destructive) {
                RecordingManager.shared.deleteRecording(recording)
                dismiss()
            } label: {
                Label("Delete", systemImage: "trash")
                    .font(.caption)
            }
        }
        .padding()
        .onAppear {
            player.load(url: RecordingManager.shared.fileURL(for: recording))
        }
        .onDisappear {
            player.stop()
        }
    }
    
    private var progress: CGFloat {
        guard recording.duration > 0 else { return 0 }
        return CGFloat(player.currentTime / recording.duration)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// Audio player wrapper for SwiftUI
@MainActor
class AudioPlayer: NSObject, ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    
    private var player: AVAudioPlayer?
    private var timer: Timer?
    
    func load(url: URL) {
        do {
            try AudioSessionManager.shared.configureForPlayback()
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
        } catch {
            print("Failed to load audio: \(error)")
        }
    }
    
    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func play() {
        player?.play()
        isPlaying = true
        startTimer()
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
    }
    
    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        currentTime = 0
        stopTimer()
        AudioSessionManager.shared.deactivate()
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.currentTime = self?.player?.currentTime ?? 0
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

extension AudioPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.currentTime = 0
            self.stopTimer()
            self.player?.currentTime = 0
        }
    }
}

#Preview {
    PlaybackView(recording: Recording(duration: 65))
}
