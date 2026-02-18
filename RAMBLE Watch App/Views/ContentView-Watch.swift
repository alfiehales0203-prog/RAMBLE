import SwiftUI

/// Main content view for the watch app with tab navigation
struct ContentView: View {
    @EnvironmentObject private var recordingManager: RecordingManager
    @EnvironmentObject private var permissionsManager: PermissionsManager
    
    var body: some View {
        TabView {
            // Recording Tab
            RecordingView()
                .tag(0)
            
            // Recordings List Tab
            NavigationStack {
                RecordingsListView()
            }
            .tag(1)
            
            // Sync Settings Tab
            NavigationStack {
                SyncSettingsView()
            }
            .tag(2)
        }
        .tabViewStyle(.page)
    }
}

#Preview {
    ContentView()
        .environmentObject(RecordingManager.shared)
        .environmentObject(PermissionsManager.shared)
}
