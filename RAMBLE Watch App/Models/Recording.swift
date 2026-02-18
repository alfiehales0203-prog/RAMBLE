import Foundation

/// Represents a single voice recording
struct Recording: Identifiable, Codable, Equatable {
    let id: UUID
    let createdAt: Date
    var duration: TimeInterval
    let filename: String
    
    /// Display-friendly title based on date
    var title: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
    
    /// Full formatted date for detail view
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
    
    /// Formatted duration string (e.g., "1:23")
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    /// Relative time description (e.g., "2 hours ago")
    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    init(id: UUID = UUID(), createdAt: Date = Date(), duration: TimeInterval = 0, filename: String? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.duration = duration
        self.filename = filename ?? "\(id.uuidString).m4a"
    }
}
