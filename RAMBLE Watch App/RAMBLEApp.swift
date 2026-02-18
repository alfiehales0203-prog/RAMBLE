import SwiftUI

@main
struct RAMBLEWATCHApp: App {
    @StateObject private var recordingManager = RecordingManager.shared
    @StateObject private var permissionsManager = PermissionsManager.shared
    @StateObject private var connectivitySender = WatchConnectivitySender.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(recordingManager)
                .environmentObject(permissionsManager)
                .environmentObject(connectivitySender)
                .onAppear {
                    // Request permissions on first launch
                    Task {
                        _ = await permissionsManager.requestMicrophonePermission()
                    }
                }
        }
    }
}

