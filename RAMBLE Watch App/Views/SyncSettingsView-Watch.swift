import SwiftUI

/// Settings view for managing sync with iPhone (watchOS version)
struct SyncSettingsView: View {
    @EnvironmentObject private var connectivitySender: WatchConnectivitySender
    @EnvironmentObject private var recordingManager: RecordingManager
    
    var body: some View {
        List {
            // Connection Status
            Section {
                HStack {
                    Image(systemName: connectivitySender.isPhoneReachable ? "iphone" : "iphone.slash")
                        .foregroundColor(connectivitySender.isPhoneReachable ? .green : .gray)
                    
                    Text("iPhone")
                    
                    Spacer()
                    
                    Text(connectivitySender.isPhoneReachable ? "Connected" : "Not Connected")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            } header: {
                Text("Connection")
            }
            
            // Last Sync
            if let lastSync = connectivitySender.lastSyncDate {
                Section {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.blue)
                        
                        Text("Last Sync")
                        
                        Spacer()
                        
                        Text(lastSync, style: .relative)
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
            
            // Sync Status
            if connectivitySender.isSyncing {
                Section {
                    HStack {
                        ProgressView()
                        Text("Syncing...")
                            .padding(.leading, 8)
                    }
                }
            }
            
            // Actions
            Section {
                Button {
                    connectivitySender.sendAllRecordings()
                } label: {
                    Label("Sync All Recordings", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(recordingManager.recordings.isEmpty || connectivitySender.isSyncing)
                
                if connectivitySender.isSyncing {
                    Button(role: .destructive) {
                        connectivitySender.cancelAllTransfers()
                    } label: {
                        Label("Cancel Sync", systemImage: "xmark.circle")
                    }
                }
            } header: {
                Text("Actions")
            } footer: {
                Text("Recordings automatically sync to your iPhone when you finish recording.")
                    .font(.caption2)
            }
            
            // Statistics
            Section {
                HStack {
                    Image(systemName: "waveform")
                        .foregroundColor(.orange)
                    
                    Text("Total Recordings")
                    
                    Spacer()
                    
                    Text("\(recordingManager.recordings.count)")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Statistics")
            }
        }
        .navigationTitle("Sync")
    }
}

#Preview {
    NavigationStack {
        SyncSettingsView()
            .environmentObject(WatchConnectivitySender.shared)
            .environmentObject(RecordingManager.shared)
    }
}
