import SwiftUI
import AVFoundation
import Combine

// MARK: - Audio Player Manager

@MainActor
class AudioPlayerManager: NSObject, ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    
    private var player: AVAudioPlayer?
    private var timer: Timer?
    
    func setupAudio(for recording: Recording, connectivityManager: WatchConnectivityManager) {
        stop() // Stop any existing playback
        
        // Get the audio file URL from connectivity manager
        let audioURL = connectivityManager.fileURL(for: recording)
        
        do {
            // Configure audio session for playback
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
            
            // Create and prepare the player
            player = try AVAudioPlayer(contentsOf: audioURL)
            player?.delegate = self
            player?.prepareToPlay()
        } catch {
            print("Failed to setup audio: \(error)")
        }
    }
    
    func play() {
        player?.play()
        isPlaying = true
        startTimer()
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
    }
    
    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        currentTime = 0
        stopTimer()
        
        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false)
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.currentTime = self?.player?.currentTime ?? 0
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

extension AudioPlayerManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.currentTime = 0
            self.stopTimer()
            self.player?.currentTime = 0
        }
    }
}

// MARK: - Category Model

struct RecordingCategory: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var iconName: String      // SF Symbol name
    var colorHex: UInt        // e.g. 0xFF9800
    
    init(id: UUID = UUID(), name: String, iconName: String, colorHex: UInt) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
    }
    
    var color: Color {
        Color(
            red: Double((colorHex >> 16) & 0xFF) / 255.0,
            green: Double((colorHex >> 8) & 0xFF) / 255.0,
            blue: Double(colorHex & 0xFF) / 255.0
        )
    }
    
    // For IndexView compatibility - deeper header color
    var deepHeaderColor: Color {
        Color(
            red: Double((colorHex >> 16) & 0xFF) / 255.0 * 0.78,
            green: Double((colorHex >> 8) & 0xFF) / 255.0 * 0.78,
            blue: Double(colorHex & 0xFF) / 255.0 * 0.78
        )
    }
    
    // Default categories matching the Dart app
    static let defaults: [RecordingCategory] = [
        RecordingCategory(name: "Shopping List", iconName: "cart.fill", colorHex: 0xFF9800),
        RecordingCategory(name: "To Do List", iconName: "checkmark.square.fill", colorHex: 0x2196F3),
        RecordingCategory(name: "Ideas", iconName: "lightbulb.fill", colorHex: 0xFBC02D),
        RecordingCategory(name: "Misc", iconName: "square.grid.2x2.fill", colorHex: 0x9C27B0),
    ]
}

// MARK: - Category Store

class CategoryStore: ObservableObject {
    @Published var categories: [RecordingCategory] = []
    
    private let storageKey = "ramble_categories"
    
    init() {
        loadCategories()
        if categories.isEmpty {
            categories = RecordingCategory.defaults
            saveCategories()
        }
    }
    
    func loadCategories() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([RecordingCategory].self, from: data) else { return }
        categories = decoded
    }
    
    func saveCategories() {
        if let data = try? JSONEncoder().encode(categories) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    func add(_ category: RecordingCategory) {
        categories.append(category)
        saveCategories()
    }
    
    func delete(_ category: RecordingCategory) {
        categories.removeAll { $0.id == category.id }
        saveCategories()
    }
    
    func move(from source: Int, to destination: Int) {
        categories.move(fromOffsets: IndexSet(integer: source),
                        toOffset: destination > source ? destination + 1 : destination)
        saveCategories()
    }
}

// MARK: - Main View

struct RecordingsListView: View {
    @EnvironmentObject private var connectivityManager: WatchConnectivityManager
    @StateObject private var categoryStore = CategoryStore()
    @State private var selectedRecording: Recording?
    @State private var showingCategoryFilter: RecordingCategory?
    @State private var showingAddCategory = false
    @State private var showingManageCategories = false
    
    private var statusMessage: String {
        if connectivityManager.receivingFile {
            return "Syncing..."
        }
        
        let count = connectivityManager.recordings.count
        if count == 0 {
            return "No thoughts yet. Sync your device to get started!"
        }
        return "\(count) thought(s)"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Blue header bar
            headerBar
            
            // Category chips + manage button
            categorySection
            
            // Status message
            statusBar
            
            // Recordings list
            if connectivityManager.recordings.isEmpty {
                emptyState
            } else {
                recordingsList
            }
        }
        .background(Color(.systemGray6))
        .navigationBarHidden(true)
        .sheet(item: $selectedRecording) { recording in
            ThoughtOptionsSheet(
                recording: recording,
                categories: categoryStore.categories,
                connectivityManager: connectivityManager,
                onAssignCategory: { categoryName in
                    connectivityManager.assignCategory(categoryName, to: recording)
                },
                onDelete: {
                    connectivityManager.deleteRecording(recording)
                },
                onTranscribe: {
                    Task { await connectivityManager.transcribe(recording) }
                }
            )
        }
        .sheet(isPresented: $showingAddCategory) {
            AddCategorySheet(categoryStore: categoryStore)
        }
        .sheet(isPresented: $showingManageCategories) {
            ManageCategoriesSheet(
                categoryStore: categoryStore,
                recordings: connectivityManager.recordings
            )
        }
        .sheet(item: $showingCategoryFilter) { category in
            CategoryFilterSheet(
                category: category,
                recordings: connectivityManager.recordings
            )
        }
    }
    
    // MARK: - Header
    
    private var headerBar: some View {
        HStack {
            BackButton()
            
            Spacer()
            
            Text("Ramble")
                .font(.title2.weight(.bold))
                .foregroundColor(.white)
                .tracking(1.2)
            
            Spacer()
            
            Button {
                print("🔄 Manual sync requested")
                print("   - Current recordings count: \(connectivityManager.recordings.count)")
                print("   - Watch connected: \(connectivityManager.isWatchConnected)")
                print("   - Watch reachable: \(connectivityManager.isWatchReachable)")
                connectivityManager.loadRecordings()
                connectivityManager.requestRecordingsFromWatch()
            } label: {
                if connectivityManager.receivingFile {
                    ProgressView()
                        .tint(.white)
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                        .foregroundColor(.white)
                }
            }
            .disabled(connectivityManager.receivingFile)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.blue)
    }
    
    // Helper view for back button
    private struct BackButton: View {
        @Environment(\.dismiss) private var dismiss
        
        var body: some View {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)
            }
        }
    }
    
    // MARK: - Categories
    
    private var categorySection: some View {
        VStack(spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categoryStore.categories) { category in
                        CategoryChip(
                            iconName: category.iconName,
                            label: category.name,
                            color: category.color
                        ) {
                            showingCategoryFilter = category
                        }
                    }
                    
                    Button {
                        showingAddCategory = true
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 12)
            
            Button {
                showingManageCategories = true
            } label: {
                Label("Manage Categories", systemImage: "gearshape")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Status Bar
    
    private var statusBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .font(.subheadline)
                .foregroundColor(.blue)
            
            Text(statusMessage)
                .font(.subheadline)
            
            Spacer()
        }
        .padding(12)
        .background(Color.blue.opacity(0.08))
        .cornerRadius(8)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "mic.slash")
                .font(.system(size: 64))
                .foregroundColor(Color(.systemGray4))
            Text("No thoughts yet")
                .font(.title3)
                .foregroundColor(Color(.systemGray))
            Text("Sync your device to get started")
                .font(.subheadline)
                .foregroundColor(Color(.systemGray2))
            Spacer()
        }
    }
    
    // MARK: - Recordings List
    
    private var recordingsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(connectivityManager.recordings) { recording in
                    RecordingCard(recording: recording)
                        .environmentObject(categoryStore)
                        .onTapGesture {
                            selectedRecording = recording
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }
}

// MARK: - Recording Card

struct RecordingCard: View {
    let recording: Recording
    @EnvironmentObject private var categoryStore: CategoryStore
    
    private var isTranscribing: Bool {
        recording.isTranscribing
    }
    
    private var preview: String {
        if isTranscribing { return "Transcribing..." }
        guard let text = recording.transcription, !text.isEmpty else {
            return recording.filename
        }
        return text.count <= 50 ? text : String(text.prefix(50)) + "..."
    }
    
    // Find the category for this recording
    private var assignedCategory: RecordingCategory? {
        guard let categoryName = recording.categoryName else { return nil }
        return categoryStore.categories.first { $0.name == categoryName }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Leading icon
            Image(systemName: "music.note")
                .foregroundColor(.gray)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(preview)
                    .font(.subheadline.weight(.medium))
                    .italic(isTranscribing)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    Text(recording.relativeTime)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Show category badge if assigned
                    if let category = assignedCategory {
                        HStack(spacing: 4) {
                            Image(systemName: category.iconName)
                                .font(.caption2)
                            Text(category.name)
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(category.color)
                        .cornerRadius(8)
                    }
                }
            }
            
            Spacer()
            
            if isTranscribing {
                ProgressView()
                    .scaleEffect(0.7)
            } else {
                Image(systemName: "ellipsis")
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let iconName: String
    let label: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.title3)
                Text(label)
                    .font(.caption2.weight(.semibold))
            }
            .foregroundColor(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Thought Options Bottom Sheet

struct ThoughtOptionsSheet: View {
    let recording: Recording
    let categories: [RecordingCategory]
    let connectivityManager: WatchConnectivityManager
    let onAssignCategory: (String?) -> Void
    let onDelete: () -> Void
    let onTranscribe: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    @State private var showFullTranscription = false
    @StateObject private var audioPlayer = AudioPlayerManager()
    
    private var preview: String {
        guard let text = recording.transcription, !text.isEmpty else {
            return recording.filename
        }
        return text.count <= 50 ? text : String(text.prefix(50)) + "..."
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Drag handle
                    Capsule()
                        .fill(Color(.systemGray4))
                        .frame(width: 40, height: 4)
                        .padding(.top, 12)
                        .padding(.bottom, 20)
                    
                    // Preview + timestamp
                    VStack(spacing: 8) {
                        Text(preview)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Text(recording.formattedDate)
                                .font(.caption)
                                .foregroundColor(Color(.systemGray))
                        }
                    }
                    .padding(.bottom, 20)
                    
                    Divider()
                    
                    // View full transcription
                    if let text = recording.transcription, text.count > 50 {
                        OptionRow(icon: "text.quote", iconColor: .blue, title: "View Full Transcription") {
                            showFullTranscription = true
                        }
                    }
                    
                    // Play audio
                    OptionRow(
                        icon: audioPlayer.isPlaying ? "pause.fill" : "play.fill",
                        iconColor: .green,
                        title: audioPlayer.isPlaying ? "Pause Audio" : "Play Audio"
                    ) {
                        if audioPlayer.isPlaying {
                            audioPlayer.pause()
                        } else {
                            audioPlayer.setupAudio(for: recording, connectivityManager: connectivityManager)
                            audioPlayer.play()
                        }
                    }
                    
                    // Transcribe (if not already transcribed)
                    if recording.transcription == nil && !recording.isTranscribing {
                        OptionRow(icon: "waveform.and.mic", iconColor: .orange, title: "Transcribe") {
                            onTranscribe()
                            dismiss()
                        }
                    }
                    
                    Divider().padding(.vertical, 8)
                    
                    // Category assignment
                    Text("Assign to Category")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    
                    ForEach(categories) { category in
                        HStack(spacing: 16) {
                            Image(systemName: category.iconName)
                                .foregroundColor(category.color)
                                .frame(width: 24)
                            
                            Text(category.name)
                            
                            Spacer()
                            
                            // Show checkmark if this category is assigned
                            if recording.categoryName == category.name {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                                    .font(.body.weight(.semibold))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // Toggle: if already assigned, remove it; otherwise assign it
                            if recording.categoryName == category.name {
                                onAssignCategory(nil)
                            } else {
                                onAssignCategory(category.name)
                            }
                            dismiss()
                        }
                    }
                    
                    Divider().padding(.vertical, 8)
                    
                    // Delete
                    OptionRow(icon: "trash", iconColor: .red, title: "Delete", titleColor: .red) {
                        showDeleteConfirm = true
                    }
                    
                    Spacer().frame(height: 32)
                }
            }
            .alert("Delete Thought?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
            } message: {
                Text("This action cannot be undone.")
            }
            .sheet(isPresented: $showFullTranscription) {
                FullTranscriptionView(recording: recording)
            }
        }
        .presentationDetents([.medium, .large])
        .onDisappear {
            audioPlayer.stop()
        }
    }
}

// MARK: - Option Row (reusable list row)

struct OptionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var titleColor: Color = .primary
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .frame(width: 24)
                
                Text(title)
                    .foregroundColor(titleColor)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Full Transcription View

struct FullTranscriptionView: View {
    let recording: Recording
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(recording.formattedDate)
                            .font(.caption)
                            .foregroundColor(Color(.systemGray))
                    }
                    
                    Divider()
                    
                    Text(recording.transcription ?? "No transcription available")
                        .font(.body)
                }
                .padding()
            }
            .navigationTitle("Full Transcription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Add Category Sheet

struct AddCategorySheet: View {
    @ObservedObject var categoryStore: CategoryStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var selectedIcon = "square.grid.2x2.fill"
    @State private var selectedColorHex: UInt = 0x2196F3
    
    private let iconOptions = [
        "cart.fill", "checkmark.square.fill", "lightbulb.fill", "square.grid.2x2.fill",
        "briefcase.fill", "house.fill", "star.fill", "heart.fill",
        "book.fill", "music.note", "fork.knife", "cross.case.fill"
    ]
    
    private let colorOptions: [UInt] = [
        0xFF9800, 0x2196F3, 0xFBC02D, 0x9C27B0,
        0x4CAF50, 0xF44336, 0x00BCD4, 0xFF5722
    ]
    
    private func colorFromHex(_ hex: UInt) -> Color {
        Color(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Category Name") {
                    TextField("Name", text: $name)
                }
                
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(iconOptions, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.title3)
                                    .foregroundColor(colorFromHex(selectedColorHex))
                                    .frame(width: 44, height: 44)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(
                                                selectedIcon == icon ? Color.blue : Color(.systemGray4),
                                                lineWidth: selectedIcon == icon ? 2 : 1
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                        ForEach(colorOptions, id: \.self) { hex in
                            Button {
                                selectedColorHex = hex
                            } label: {
                                Circle()
                                    .fill(colorFromHex(hex))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Circle()
                                            .stroke(selectedColorHex == hex ? Color.primary : Color.clear, lineWidth: 2)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Add Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        categoryStore.add(RecordingCategory(
                            name: name,
                            iconName: selectedIcon,
                            colorHex: selectedColorHex
                        ))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Manage Categories Sheet

struct ManageCategoriesSheet: View {
    @ObservedObject var categoryStore: CategoryStore
    let recordings: [Recording]
    @Environment(\.dismiss) private var dismiss
    @State private var categoryToDelete: RecordingCategory?
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(categoryStore.categories) { category in
                    HStack(spacing: 12) {
                        Image(systemName: category.iconName)
                            .foregroundColor(category.color)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading) {
                            Text(category.name)
                                .font(.body)
                            // TODO: count recordings per category when Recording model has category field
                            Text("0 thought(s)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button {
                            categoryToDelete = category
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Manage Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Delete Category?", isPresented: Binding(
                get: { categoryToDelete != nil },
                set: { if !$0 { categoryToDelete = nil } }
            )) {
                Button("Cancel", role: .cancel) { categoryToDelete = nil }
                Button("Delete", role: .destructive) {
                    if let cat = categoryToDelete {
                        categoryStore.delete(cat)
                    }
                    categoryToDelete = nil
                }
            } message: {
                Text("Thoughts in this category will become uncategorized.")
            }
        }
    }
}

// MARK: - Category Filter Sheet

struct CategoryFilterSheet: View {
    let category: RecordingCategory
    let recordings: [Recording]
    @Environment(\.dismiss) private var dismiss
    
    private var filteredRecordings: [Recording] {
        recordings.filter { $0.categoryName == category.name }
    }
    
    private func preview(for recording: Recording) -> String {
        if recording.isTranscribing { return "Transcribing..." }
        guard let text = recording.transcription, !text.isEmpty else {
            return recording.filename
        }
        return text.count <= 50 ? text : String(text.prefix(50)) + "..."
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if filteredRecordings.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Text("No thoughts in this category yet")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    List(filteredRecordings) { recording in
                        HStack(spacing: 12) {
                            Image(systemName: "music.note")
                                .foregroundColor(.gray)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(preview(for: recording))
                                    .font(.subheadline.weight(.medium))
                                    .italic(recording.isTranscribing)
                                    .lineLimit(2)
                                Text(recording.relativeTime)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(category.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 6) {
                        Image(systemName: category.iconName)
                            .foregroundColor(category.color)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    RecordingsListView()
        .environmentObject(WatchConnectivityManager.shared)
}
