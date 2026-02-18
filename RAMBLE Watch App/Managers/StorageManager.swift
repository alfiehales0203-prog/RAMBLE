import Foundation

/// Manages local storage of recordings and metadata
class StorageManager {
    static let shared = StorageManager()
    
    private let fileManager = FileManager.default
    private let recordingsKey = "savedRecordings"
    
    /// Directory where audio files are stored
    var recordingsDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsPath = documentsPath.appendingPathComponent("Recordings", isDirectory: true)
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: recordingsPath.path) {
            try? fileManager.createDirectory(at: recordingsPath, withIntermediateDirectories: true)
        }
        
        return recordingsPath
    }
    
    private init() {}
    
    // MARK: - File Operations
    
    /// Get the full file URL for a recording
    func fileURL(for recording: Recording) -> URL {
        return recordingsDirectory.appendingPathComponent(recording.filename)
    }
    
    /// Check if a recording file exists
    func fileExists(for recording: Recording) -> Bool {
        return fileManager.fileExists(atPath: fileURL(for: recording).path)
    }
    
    /// Delete a recording file
    func deleteFile(for recording: Recording) throws {
        let url = fileURL(for: recording)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
    
    /// Get available storage space in bytes
    func availableStorageSpace() -> Int64? {
        do {
            let attributes = try fileManager.attributesOfFileSystem(forPath: recordingsDirectory.path)
            return attributes[.systemFreeSize] as? Int64
        } catch {
            print("Failed to get storage space: \(error)")
            return nil
        }
    }
    
    /// Check if there's enough space for a new recording (minimum 10MB)
    func hasEnoughSpace() -> Bool {
        guard let available = availableStorageSpace() else { return true }
        return available > 10 * 1024 * 1024 // 10MB minimum
    }
    
    // MARK: - Metadata Persistence
    
    /// Save recordings metadata to UserDefaults
    func saveRecordings(_ recordings: [Recording]) {
        do {
            let data = try JSONEncoder().encode(recordings)
            UserDefaults.standard.set(data, forKey: recordingsKey)
        } catch {
            print("Failed to save recordings: \(error)")
        }
    }
    
    /// Load recordings metadata from UserDefaults
    func loadRecordings() -> [Recording] {
        guard let data = UserDefaults.standard.data(forKey: recordingsKey) else {
            return []
        }
        
        do {
            let recordings = try JSONDecoder().decode([Recording].self, from: data)
            // Filter out recordings whose files no longer exist
            return recordings.filter { fileExists(for: $0) }
        } catch {
            print("Failed to load recordings: \(error)")
            return []
        }
    }
    
    /// Get total size of all recordings in bytes
    func totalRecordingsSize() -> Int64 {
        var totalSize: Int64 = 0
        let recordings = loadRecordings()
        
        for recording in recordings {
            let url = fileURL(for: recording)
            if let attributes = try? fileManager.attributesOfItem(atPath: url.path),
               let size = attributes[.size] as? Int64 {
                totalSize += size
            }
        }
        
        return totalSize
    }
    
    /// Format bytes as human-readable string
    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
