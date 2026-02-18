import Foundation
import WatchConnectivity
import Combine
import Speech

/// Manages Watch Connectivity for iPhone - receives audio files from watch
@MainActor
class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    // MARK: - Published Properties
    
    @Published var recordings: [Recording] = []
    @Published var isWatchPaired: Bool = false
    @Published var isWatchAppInstalled: Bool = false
    @Published var isWatchReachable: Bool = false
    @Published var receivingFile: Bool = false
    @Published var isSyncing: Bool = false
    @Published var pendingTransfers: Int = 0
    
    // MARK: - Private Properties
    
    private let fileManager = FileManager.default
    private let speechRecognizer = SFSpeechRecognizer()
    private var activeTranscriptionTasks: [UUID: Task<Void, Never>] = [:]
    private let recordingsKey = "iosRecordings"
    
    // MARK: - Computed Properties
    
    /// Watch is connected enough for background file transfers (does NOT require reachability)
    var isWatchConnected: Bool {
        isWatchPaired && isWatchAppInstalled
    }
    
    var recordingsDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsPath = documentsPath.appendingPathComponent("Recordings", isDirectory: true)
        
        if !fileManager.fileExists(atPath: recordingsPath.path) {
            try? fileManager.createDirectory(at: recordingsPath, withIntermediateDirectories: true)
        }
        
        return recordingsPath
    }
    
    // MARK: - Initialization
    
    nonisolated private override init() {
        super.init()
        
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
        
        Task { @MainActor in
            loadRecordings()
            reconcileFilesWithMetadata()
            updatePendingTransfers()
        }
    }
    
    // MARK: - Public Methods
    
    /// Request recordings from watch (manual fallback — primary sync is passive via transferFile)
    func requestRecordingsFromWatch() {
        guard WCSession.default.activationState == .activated else {
            print("⚠️ WCSession not activated")
            return
        }
        
        // sendMessage requires reachability (watch app in foreground)
        guard WCSession.default.isReachable else {
            print("⚠️ Watch not reachable — open the Ramble app on your watch, or just wait for background transfer")
            return
        }
        
        print("🔄 Requesting recordings from watch...")
        isSyncing = true
        
        WCSession.default.sendMessage(
            ["action": "requestRecordings"],
            replyHandler: { response in
                Task { @MainActor in
                    print("✅ Watch responded: \(response)")
                    self.isSyncing = false
                }
            },
            errorHandler: { error in
                Task { @MainActor in
                    print("⚠️ Request failed: \(error.localizedDescription)")
                    self.isSyncing = false
                }
            }
        )
        
        // Update pending transfers count
        updatePendingTransfers()
    }
    
    /// Update the count of pending file transfers
    private func updatePendingTransfers() {
        // WCSession tracks outstanding file transfers
        pendingTransfers = WCSession.default.outstandingFileTransfers.count
    }
    
    /// Delete a recording
    func deleteRecording(_ recording: Recording) {
        let url = recordingsDirectory.appendingPathComponent(recording.filename)
        try? fileManager.removeItem(at: url)
        
        recordings.removeAll { $0.id == recording.id }
        saveRecordings()
    }
    
    /// Assign a category to a recording
    func assignCategory(_ categoryName: String?, to recording: Recording) {
        guard let index = recordings.firstIndex(where: { $0.id == recording.id }) else { return }
        recordings[index].categoryName = categoryName
        saveRecordings()
    }
    
    
    
    /// Mark a recording as read
    func markAsRead(_ recording: Recording) {
        guard let index = recordings.firstIndex(where: { $0.id == recording.id }) else { return }
        recordings[index].isRead = true
        saveRecordings()
    }
    
    /// Get file URL for a recording
    func fileURL(for recording: Recording) -> URL {
        return recordingsDirectory.appendingPathComponent(recording.filename)
    }
    
    // MARK: - Transcription
    
    func transcribe(_ recording: Recording) async {
        guard !recording.isTranscribing else { return }
        
        // Request authorization if needed
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        if authStatus == .notDetermined {
            await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { _ in
                    continuation.resume()
                }
            }
        }
        
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            print("❌ Speech recognition not authorized")
            return
        }
        
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            print("❌ Speech recognizer not available")
            return
        }
        
        // Mark as transcribing
        guard let index = recordings.firstIndex(where: { $0.id == recording.id }) else { return }
        recordings[index].isTranscribing = true
        
        let audioURL = fileURL(for: recording)
        
        guard fileManager.fileExists(atPath: audioURL.path),
              let attributes = try? fileManager.attributesOfItem(atPath: audioURL.path),
              let fileSize = attributes[.size] as? Int, fileSize > 0 else {
            print("❌ Audio file not found or empty")
            recordings[index].isTranscribing = false
            return
        }
        
        print("🎤 Transcribing: \(recording.title) (\(fileSize) bytes)")
        
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        request.requiresOnDeviceRecognition = false
        
        if #available(iOS 16.0, *) {
            request.addsPunctuation = true
        }
        
        let task = Task {
            var partialTranscription: String?
            var recognitionTask: SFSpeechRecognitionTask?
            
            do {
                let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<SFSpeechRecognitionResult, Error>) in
                    var hasResumed = false
                    
                    recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                        if let error = error {
                            let nsError = error as NSError
                            // 1110 = no speech detected — use partial if available
                            if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1110,
                               let result = result, !result.bestTranscription.formattedString.isEmpty {
                                if !hasResumed {
                                    hasResumed = true
                                    continuation.resume(returning: result)
                                }
                                return
                            }
                            if !hasResumed {
                                hasResumed = true
                                continuation.resume(throwing: error)
                            }
                        } else if let result = result {
                            if !result.bestTranscription.formattedString.isEmpty {
                                partialTranscription = result.bestTranscription.formattedString
                            }
                            if result.isFinal && !hasResumed {
                                hasResumed = true
                                continuation.resume(returning: result)
                            }
                        }
                    }
                }
                
                let transcription = result.bestTranscription.formattedString
                print("✅ Transcription: \(transcription.prefix(50))...")
                
                if let idx = recordings.firstIndex(where: { $0.id == recording.id }) {
                    recordings[idx].transcription = transcription
                    recordings[idx].isTranscribing = false
                    saveRecordings()
                }
                
            } catch {
                print("❌ Transcription failed: \(error)")
                if let idx = recordings.firstIndex(where: { $0.id == recording.id }) {
                    if let partial = partialTranscription, !partial.isEmpty {
                        recordings[idx].transcription = partial
                    }
                    recordings[idx].isTranscribing = false
                    saveRecordings()
                }
            }
            
            recognitionTask?.cancel()
            activeTranscriptionTasks.removeValue(forKey: recording.id)
        }
        
        activeTranscriptionTasks[recording.id] = task
    }
    
    func cancelTranscription(for recording: Recording) {
        activeTranscriptionTasks[recording.id]?.cancel()
        activeTranscriptionTasks.removeValue(forKey: recording.id)
        
        if let index = recordings.firstIndex(where: { $0.id == recording.id }) {
            recordings[index].isTranscribing = false
        }
    }
    
    var isTranscriptionAvailable: Bool {
        speechRecognizer?.isAvailable ?? false
    }
    
    func requestTranscriptionPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    // MARK: - Persistence
    
    private func saveRecordings() {
        do {
            let data = try JSONEncoder().encode(recordings)
            UserDefaults.standard.set(data, forKey: recordingsKey)
        } catch {
            print("❌ Failed to save recordings: \(error)")
        }
    }
    
    func loadRecordings() {
        guard let data = UserDefaults.standard.data(forKey: recordingsKey) else {
            print("📱 No saved recordings found")
            return
        }
        
        do {
            let loaded = try JSONDecoder().decode([Recording].self, from: data)
            recordings = loaded.filter { recording in
                let exists = fileManager.fileExists(atPath: fileURL(for: recording).path)
                if !exists {
                    print("⚠️ Removing recording with missing file: \(recording.filename)")
                }
                return exists
            }
            print("📱 Loaded \(recordings.count) recordings")
        } catch {
            print("❌ Failed to decode recordings: \(error)")
        }
    }
    
    // MARK: - Disk Reconciliation
    
    /// Check for audio files on disk that aren't in the recordings list (crash recovery)
    private func reconcileFilesWithMetadata() {
        guard let files = try? fileManager.contentsOfDirectory(
            at: recordingsDirectory,
            includingPropertiesForKeys: [.fileSizeKey, .creationDateKey]
        ) else { return }
        
        let knownFilenames = Set(recordings.map(\.filename))
        
        for fileURL in files {
            let filename = fileURL.lastPathComponent
            guard filename.hasSuffix(".m4a"), !knownFilenames.contains(filename) else { continue }
            
            // Found an orphaned audio file — create a Recording entry for it
            let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path)
            let fileSize = attributes?[.size] as? Int ?? 0
            guard fileSize > 0 else { continue } // Skip empty files
            
            let createdAt = (attributes?[.creationDate] as? Date) ?? Date()
            
            // Try to extract UUID from filename (format: UUID.m4a)
            let stem = filename.replacingOccurrences(of: ".m4a", with: "")
            let id = UUID(uuidString: stem) ?? UUID()
            
            let recording = Recording(id: id, createdAt: createdAt, duration: 0, filename: filename)
            recordings.insert(recording, at: 0)
            
            print("🔧 Recovered orphaned file: \(filename) (\(fileSize) bytes)")
        }
        
        // Sort by date and save
        recordings.sort { $0.createdAt > $1.createdAt }
        saveRecordings()
    }
    
    // MARK: - Handle Received File Metadata
    
    private func handleReceivedFileMetadata(_ recording: Recording) {
        receivingFile = true
        isSyncing = true
        
        print("📝 Processing metadata for: \(recording.title)")
        
        // Add or update in recordings list
        if let existingIndex = recordings.firstIndex(where: { $0.id == recording.id }) {
            // Preserve transcription and category from existing entry
            var updated = recording
            updated.transcription = recordings[existingIndex].transcription
            updated.categoryName = recordings[existingIndex].categoryName
            recordings[existingIndex] = updated
            print("   Updated existing recording entry")
        } else {
            recordings.insert(recording, at: 0)
            recordings.sort { $0.createdAt > $1.createdAt }
            print("   Added new recording entry")
        }
        
        saveRecordings()
        
        receivingFile = false
        isSyncing = false
        updatePendingTransfers()
        
        print("✅ Recording ready: \(recording.title)")
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            if let error = error {
                print("❌ WCSession activation failed: \(error)")
                return
            }
            
            print("✅ WCSession activated")
            print("   isPaired: \(session.isPaired)")
            print("   isWatchAppInstalled: \(session.isWatchAppInstalled)")
            print("   isReachable: \(session.isReachable)")
            
            self.isWatchPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isWatchReachable = session.isReachable
        }
    }
    
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        print("WCSession became inactive")
    }
    
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        print("WCSession deactivated — reactivating")
        session.activate()
    }
    
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isWatchReachable = session.isReachable
            print("📡 Watch reachability: \(session.isReachable)")
        }
    }
    
    // MARK: - File Reception (this is the passive sync entry point)
    
    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        // CRITICAL: Must copy file IMMEDIATELY and SYNCHRONOUSLY
        // The temp file at file.fileURL will be deleted as soon as this method returns
        
        print("📥 Received file: \(file.fileURL.lastPathComponent)")
        print("   Source: \(file.fileURL.path)")
        print("   Metadata: \(file.metadata ?? [:])")
        
        // Extract metadata
        guard let metadata = file.metadata,
              let idString = metadata["id"] as? String,
              let id = UUID(uuidString: idString),
              let timestamp = metadata["createdAt"] as? TimeInterval,
              let duration = metadata["duration"] as? TimeInterval,
              let filename = metadata["filename"] as? String else {
            print("❌ Invalid or missing file metadata")
            return
        }
        
        // Verify source file exists and has content RIGHT NOW (before it gets cleaned up)
        guard FileManager.default.fileExists(atPath: file.fileURL.path),
              let sourceAttrs = try? FileManager.default.attributesOfItem(atPath: file.fileURL.path),
              let sourceSize = sourceAttrs[.size] as? Int, sourceSize > 0 else {
            print("❌ Source file doesn't exist or is empty: \(file.fileURL.path)")
            return
        }
        
        print("   ✓ Source file verified: \(sourceSize) bytes")
        
        // Get destination URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsPath = documentsPath.appendingPathComponent("Recordings", isDirectory: true)
        
        // Create directory if needed (synchronously)
        if !FileManager.default.fileExists(atPath: recordingsPath.path) {
            try? FileManager.default.createDirectory(at: recordingsPath, withIntermediateDirectories: true)
        }
        
        let destinationURL = recordingsPath.appendingPathComponent(filename)
        
        // SYNCHRONOUSLY move/copy the file BEFORE returning from this delegate method
        do {
            // Remove existing file if present
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
                print("   Removed existing file at destination")
            }
            
            // MOVE (not copy) - this is faster and more reliable
            // Note: We use move because the source is temporary and will be deleted anyway
            try FileManager.default.moveItem(at: file.fileURL, to: destinationURL)
            
            // Verify the moved file
            guard let destAttrs = try? FileManager.default.attributesOfItem(atPath: destinationURL.path),
                  let destSize = destAttrs[.size] as? Int, destSize > 0 else {
                print("❌ Moved file is empty or unreadable")
                try? FileManager.default.removeItem(at: destinationURL)
                return
            }
            
            print("✅ File moved successfully: \(destSize) bytes")
            print("   Destination: \(destinationURL.path)")
            
            // Now update the recordings list on MainActor
            let createdAt = Date(timeIntervalSinceReferenceDate: timestamp)
            let recording = Recording(id: id, createdAt: createdAt, duration: duration, filename: filename)
            
            Task { @MainActor in
                self.handleReceivedFileMetadata(recording)
            }
            
        } catch {
            print("❌ Failed to move file: \(error)")
            print("   Source: \(file.fileURL.path)")
            print("   Destination: \(destinationURL.path)")
        }
    }
    
    // MARK: - Message Handling
    
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        print("📩 Message from watch: \(message)")
        
        if let action = message["action"] as? String {
            switch action {
            case "recordingDeleted":
                if let idString = message["id"] as? String,
                   let id = UUID(uuidString: idString) {
                    Task { @MainActor in
                        if let recording = self.recordings.first(where: { $0.id == id }) {
                            self.deleteRecording(recording)
                            print("🗑️ Deleted recording via watch message: \(recording.title)")
                        }
                    }
                }
                replyHandler(["status": "deleted"])
                
            default:
                replyHandler(["status": "unknown action"])
            }
        } else {
            replyHandler(["status": "ok"])
        }
    }
    
    // Also handle messages without reply handler (from transferUserInfo fallback)
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        print("📩 UserInfo from watch: \(userInfo)")
        
        if let action = userInfo["action"] as? String, action == "recordingDeleted",
           let idString = userInfo["id"] as? String,
           let id = UUID(uuidString: idString) {
            Task { @MainActor in
                if let recording = self.recordings.first(where: { $0.id == id }) {
                    self.deleteRecording(recording)
                }
            }
        }
    }
}
