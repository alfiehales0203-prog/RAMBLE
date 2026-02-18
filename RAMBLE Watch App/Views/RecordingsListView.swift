import SwiftUI

/// List view showing all saved recordings
struct RecordingsListView: View {
    @ObservedObject var recordingManager = RecordingManager.shared
    @State private var selectedRecording: Recording?
    
    var body: some View {
        Group {
            if recordingManager.recordings.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "waveform")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No Recordings")
                        .font(.headline)
                    Text("Tap Record to start")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                List {
                    ForEach(recordingManager.recordings) { recording in
                        RecordingRow(recording: recording)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedRecording = recording
                            }
                    }
                    .onDelete { offsets in
                        recordingManager.deleteRecordings(at: offsets)
                    }
                }
                .listStyle(.carousel)
            }
        }
        .navigationTitle("Recordings")
        .sheet(item: $selectedRecording) { recording in
            PlaybackView(recording: recording)
        }
    }
}

/// Single row in the recordings list
struct RecordingRow: View {
    let recording: Recording
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "waveform")
                    .foregroundColor(.red)
                    .font(.caption)
                
                Text(recording.formattedDuration)
                    .font(.headline)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(recording.relativeTime)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        RecordingsListView()
    }
}
