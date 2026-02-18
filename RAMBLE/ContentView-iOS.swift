import SwiftUI
import AVFoundation

struct ContentView_iOS: View {
    @ObservedObject private var connectivityManager = WatchConnectivityManager.shared
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Spacer()
                
                // App Title
                VStack(spacing: 8) {
                    Text("Ramble")
                        .font(.system(size: 48, weight: .bold))
                    
                    Text("Voice notes from your Apple Watch")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Watch Connection Status
                connectionStatusCard
                
                // Sync Button
                VStack(spacing: 12) {
                    Button {
                        print("🔄 Refreshing recordings list")
                        connectivityManager.loadRecordings()
                        connectivityManager.requestRecordingsFromWatch()
                    } label: {
                        HStack(spacing: 12) {
                            if connectivityManager.receivingFile {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                                Text("Syncing...")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.title2)
                                Text("Sync")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(connectivityManager.receivingFile)
                }
                .padding(.horizontal)
                
                // Recordings Navigation
                NavigationLink {
                    IndexView()
                        .environmentObject(connectivityManager)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Recordings")
                                .font(.headline)
                            Text("\(connectivityManager.recordings.count) recording\(connectivityManager.recordings.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .onAppear {
                print("📱 iOS ContentView appeared")
                print("   - Recordings count: \(connectivityManager.recordings.count)")
                print("   - isWatchConnected: \(connectivityManager.isWatchConnected)")
                print("   - isWatchAppInstalled: \(connectivityManager.isWatchAppInstalled)")
                
                // Load recordings from storage
                connectivityManager.loadRecordings()
            }
        }
    }
    
    // MARK: - Connection Status Card
    
    private var connectionStatusCard: some View {
        HStack(spacing: 16) {
            // Watch icon with status
            ZStack {
                Circle()
                    .fill(connectivityManager.isWatchConnected ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "applewatch")
                    .font(.system(size: 30))
                    .foregroundColor(connectivityManager.isWatchConnected ? .green : .gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(connectivityManager.isWatchConnected ? "Watch Connected" : "Watch Not Connected")
                    .font(.headline)
                
                if connectivityManager.isWatchAppInstalled {
                    if connectivityManager.receivingFile {
                        Text("Receiving file...")
                            .font(.caption)
                            .foregroundColor(.blue)
                    } else {
                        Text("Ready to sync recordings")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Install Ramble on your Apple Watch")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

#Preview {
    ContentView_iOS()
}
