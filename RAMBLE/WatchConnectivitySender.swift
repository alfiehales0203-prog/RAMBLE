import Foundation
import WatchConnectivity
import Combine

/// Manages Watch Connectivity on watchOS - sends audio files to iPhone
@MainActor
class WatchConnectivitySender: NSObject, ObservableObject {
    static let shared = WatchConnectivitySender()
    
    // MARK: - Published Properties
    
    @Published var isPhoneReachable: Bool = false
    @Published var isSyncing: Bool = false
    @Published var syncProgress: Double = 0.0
    @Published var lastSyncDate: Date?
    
    // MARK: - Private Properties
    
    private var pendingTransfers: [WCSessionFileTransfer] = []
    private let fileManager = FileManager.default
    
    /// Directory where audio files are stored
    private var recordingsDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsPath = documentsPath.appendingPathComponent("Recordings", isDirectory: true)
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: recordingsPath.path) {
            try? fileManager.createDirectory(at: recordingsPath, withIntermediateDirectories: true)
        }
        
        return recordingsPath
    }
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            
            // Check for any outstanding transfers from previous sessions
            Task { @MainActor in
                let outstanding = session.outstandingFileTransfers
                if !outstanding.isEmpty {
                    print("📋 Found \(outstanding.count) outstanding file transfer(s) from previous session")
                    pendingTransfers = outstanding
                    isSyncing = true
                    updateSyncProgress()
                }
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Get the full file URL for a recording
    private func fileURL(for recording: Recording) -> URL {
        return recordingsDirectory.appendingPathComponent(recording.filename)
    }
    
    /// Send a recording to the iPhone
    func sendRecording(_ recording: Recording) {
        guard WCSession.default.activationState == .activated else {
            print("❌ Cannot send recording: WCSession not activated (state: \(WCSession.default.activationState.rawValue))")
            return
        }
        
        let fileURL = fileURL(for: recording)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("❌ Recording file not found: \(fileURL.path)")
            return
        }
        
        // Verify file has content
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let fileSize = attributes[.size] as? Int, fileSize > 0 else {
            print("❌ Recording file is empty or unreadable: \(fileURL.path)")
            return
        }
        
        // Check if this recording is already being transferred
        let alreadyTransferring = pendingTransfers.contains { transfer in
            guard let metadata = transfer.file.metadata,
                  let transferId = metadata["id"] as? String else {
                return false
            }
            return transferId == recording.id.uuidString
        }
        
        if alreadyTransferring {
            print("⚠️ Recording already being transferred: \(recording.title)")
            return
        }
        
        // Prepare metadata
        let metadata: [String: Any] = [
            "id": recording.id.uuidString,
            "createdAt": recording.createdAt.timeIntervalSinceReferenceDate,
            "duration": recording.duration,
            "filename": recording.filename
        ]
        
        // Transfer file
        print("📤 Starting transfer: \(recording.title)")
        print("   - ID: \(recording.id)")
        print("   - File: \(fileURL.lastPathComponent)")
        print("   - Size: \(fileSize) bytes")
        print("   - Duration: \(String(format: "%.1f", recording.duration))s")
        print("   - Phone reachable: \(WCSession.default.isReachable)")
        print("   - Activation state: \(WCSession.default.activationState.rawValue)")
        
        let transfer = WCSession.default.transferFile(fileURL, metadata: metadata)
        pendingTransfers.append(transfer)
        
        isSyncing = true
        updateSyncProgress()
        
        print("   ✓ Transfer queued (total pending: \(pendingTransfers.count))")
    }
    
    /// Send all recordings to the iPhone
    func sendAllRecordings() {
        let recordings = loadRecordings()
        
        guard !recordings.isEmpty else {
            print("📭 No recordings to send")
            return
        }
        
        print("📤 Sending \(recordings.count) recording(s) to iPhone...")
        isSyncing = true
        
        for recording in recordings {
            sendRecording(recording)
        }
    }
    
    /// Send only recordings that haven't been sent yet (check against outstanding transfers)
    func sendUnsentRecordings() {
        let recordings = loadRecordings()
        
        guard !recordings.isEmpty else {
            print("📭 No recordings to check")
            return
        }
        
        // Get IDs of recordings already being transferred
        let transferringIds = Set(WCSession.default.outstandingFileTransfers.compactMap { transfer in
            transfer.file.metadata?["id"] as? String
        })
        
        // Filter to recordings not currently transferring
        let unsentRecordings = recordings.filter { recording in
            !transferringIds.contains(recording.id.uuidString)
        }
        
        if unsentRecordings.isEmpty {
            print("✅ All recordings are already queued for transfer")
            return
        }
        
        print("📤 Sending \(unsentRecordings.count) unsent recording(s)...")
        isSyncing = true
        
        for recording in unsentRecordings {
            sendRecording(recording)
        }
    }
    
    /// Load recordings metadata from UserDefaults
    private func loadRecordings() -> [Recording] {
        guard let data = UserDefaults.standard.data(forKey: "savedRecordings") else {
            return []
        }
        
        do {
            let recordings = try JSONDecoder().decode([Recording].self, from: data)
            // Filter out recordings whose files no longer exist
            return recordings.filter { fileManager.fileExists(atPath: fileURL(for: $0).path) }
        } catch {
            print("Failed to load recordings: \(error)")
            return []
        }
    }
    
    /// Send only unsent recordings (implement your own logic for tracking)
    func syncNewRecordings() {
        // For now, this sends all recordings
        // You could add a "synced" flag to the Recording model to track which have been sent
        sendAllRecordings()
    }
    
    /// Cancel all pending transfers
    func cancelAllTransfers() {
        for transfer in pendingTransfers {
            transfer.cancel()
        }
        pendingTransfers.removeAll()
        isSyncing = false
        syncProgress = 0.0
    }
    
    /// Notify iPhone that a recording was deleted
    func notifyRecordingDeleted(_ recording: Recording) {
        guard WCSession.default.activationState == .activated else { return }
        
        let message: [String: Any] = [
            "action": "recordingDeleted",
            "id": recording.id.uuidString
        ]
        
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: { error in
                print("Failed to notify deletion: \(error)")
            })
        } else {
            // Use transferUserInfo for offline delivery
            WCSession.default.transferUserInfo(message)
        }
    }
    
    // MARK: - Private Methods
    
    private func updateSyncProgress() {
        // Check current outstanding transfers
        let outstandingTransfers = WCSession.default.outstandingFileTransfers
        pendingTransfers = outstandingTransfers
        
        let count = pendingTransfers.count
        
        if count == 0 {
            isSyncing = false
            syncProgress = 0.0
            lastSyncDate = Date()
            print("✅ All file transfers complete")
        } else {
            isSyncing = true
            // Calculate average progress across all transfers
            let totalProgress = pendingTransfers.reduce(0.0) { $0 + $1.progress.fractionCompleted }
            syncProgress = count > 0 ? totalProgress / Double(count) : 0.0
            print("📊 Transfer progress: \(Int(syncProgress * 100))% (\(count) remaining)")
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivitySender: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            if let error = error {
                print("❌ WCSession activation failed: \(error)")
            } else {
                print("✅ WCSession activated successfully")
                print("   - activationState: \(activationState.rawValue)")
                print("   - isReachable: \(session.isReachable)")
                
                isPhoneReachable = session.isReachable
            }
        }
    }
    
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isPhoneReachable = session.isReachable
            print("Phone reachability changed: \(session.isReachable)")
        }
    }
    
    // MARK: - File Transfer Callbacks
    
    nonisolated func session(
        _ session: WCSession,
        didFinish fileTransfer: WCSessionFileTransfer,
        error: Error?
    ) {
        Task { @MainActor in
            if let error = error {
                print("File transfer failed: \(error)")
            } else {
                print("File transfer completed successfully")
            }
            
            updateSyncProgress()
        }
    }
    
    // MARK: - Message Handling
    
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        print("📩 Received message from iPhone: \(message)")
        
        // Handle requests from iPhone
        if let action = message["action"] as? String {
            switch action {
            case "requestRecordings":
                Task { @MainActor in
                    let recordings = loadRecordings()
                    let count = recordings.count
                    
                    print("📤 iPhone requested recordings. Found \(count) recording(s)")
                    
                    // Reply immediately with the count
                    replyHandler(["status": "syncing", "count": count])
                    
                    // Send unsent recordings (smarter than sending all)
                    if count > 0 {
                        sendUnsentRecordings()
                    } else {
                        print("   No recordings to transfer")
                    }
                }
            default:
                replyHandler(["status": "unknown action"])
            }
        } else {
            replyHandler(["status": "no action specified"])
        }
    }
}
