import SwiftUI

/// Settings view for managing sync with Apple Watch (iOS version)
struct SyncSettingsView: View {
    @EnvironmentObject private var connectivityManager: WatchConnectivityManager
    
    var body: some View {
        List {
            // Connection Status
            Section {
                HStack {
                    Image(systemName: connectivityManager.isWatchConnected ? "applewatch" : "applewatch.slash")
                        .foregroundColor(connectivityManager.isWatchConnected ? .green : .gray)
                    
                    Text("Apple Watch")
                    
                    Spacer()
                    
                    Text(connectivityManager.isWatchConnected ? "Connected" : "Not Connected")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                
                if connectivityManager.isWatchAppInstalled {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        
                        Text("Watch App Installed")
                            .font(.caption)
                    }
                } else {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                        
                        Text("Watch App Not Installed")
                            .font(.caption)
                    }
                }
            } header: {
                Text("Connection")
            }
            
            // Receiving Status
            if connectivityManager.receivingFile {
                Section {
                    HStack {
                        ProgressView()
                        Text("Receiving Recording...")
                            .padding(.leading, 8)
                    }
                }
            }
            
            // Actions
            Section {
                Button {
                    connectivityManager.requestRecordingsFromWatch()
                } label: {
                    Label("Request Recordings from Watch", systemImage: "arrow.down.circle")
                }
                .disabled(!connectivityManager.isWatchConnected || connectivityManager.receivingFile)
            } header: {
                Text("Actions")
            } footer: {
                Text("Recordings automatically sync from your Apple Watch when you finish recording.")
                    .font(.caption2)
            }
            
            // Statistics
            Section {
                HStack {
                    Image(systemName: "waveform")
                        .foregroundColor(.orange)
                    
                    Text("Synced Recordings")
                    
                    Spacer()
                    
                    Text("\(connectivityManager.recordings.count)")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Statistics")
            } footer: {
                Text("These recordings were received from your Apple Watch.")
                    .font(.caption2)
            }
        }
        .navigationTitle("Sync")
    }
}

#Preview {
    NavigationStack {
        SyncSettingsView()
            .environmentObject(WatchConnectivityManager.shared)
    }
}
