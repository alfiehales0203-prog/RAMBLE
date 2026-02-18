import SwiftUI
import WatchKit

/// Main recording view with large record button
struct RecordingView: View {
    @ObservedObject var recordingManager = RecordingManager.shared
    @ObservedObject var permissionsManager = PermissionsManager.shared
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 8) {
                // Duration display
                if recordingManager.isRecording {
                    Text(formatDuration(recordingManager.recordingDuration))
                        .font(.system(.title2, design: .monospaced))
                        .foregroundColor(.red)
                        .animation(.easeInOut, value: recordingManager.recordingDuration)
                } else {
                    Text("Tap to Record")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                
                // Large record button - takes most of the screen
                Button {
                    Task {
                        await recordingManager.toggleRecording()
                    }
                } label: {
                    ZStack {
                        // Outer ring
                        Circle()
                            .stroke(
                                recordingManager.isRecording ? Color.red : Color.white.opacity(0.3),
                                lineWidth: 4
                            )
                        
                        // Inner circle/square
                        if recordingManager.isRecording {
                            // Stop button (rounded square)
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.red)
                                .frame(width: geometry.size.width * 0.25, height: geometry.size.width * 0.25)
                        } else {
                            // Record button (circle)
                            Circle()
                                .fill(Color.red)
                                .padding(12)
                        }
                    }
                    .frame(width: geometry.size.width * 0.6, height: geometry.size.width * 0.6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(recordingManager.isRecording ? "Stop Recording" : "Start Recording")
                
                // Recording count
                if !recordingManager.isRecording && !recordingManager.recordings.isEmpty {
                    Text("\(recordingManager.recordings.count) recording\(recordingManager.recordings.count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .alert("Error", isPresented: $recordingManager.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(recordingManager.error?.localizedDescription ?? "Unknown error")
        }
        .onAppear {
            permissionsManager.checkCurrentStatus()
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let tenths = Int((duration.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }
}

#Preview {
    RecordingView()
}
