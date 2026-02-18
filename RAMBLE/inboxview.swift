import SwiftUI
import AVFoundation

// MARK: - Filter Option

enum FilterOption: Equatable {
    case all
    case category(RecordingCategory)
    
    var displayName: String {
        switch self {
        case .all:
            return "All"
        case .category(let cat):
            return cat.name
        }
    }
    
    var icon: String {
        switch self {
        case .all:
            return "tray.fill"
        case .category(let cat):
            return cat.iconName
        }
    }
    
    var tileColor: Color {
        switch self {
        case .all:
            return Color(red: 0.55, green: 0.55, blue: 0.58)
        case .category(let cat):
            return cat.color
        }
    }
    
    var headerColor: Color {
        switch self {
        case .all:
            return Color(red: 0.88, green: 0.88, blue: 0.87)
        case .category(let cat):
            return cat.deepHeaderColor
        }
    }
    
    var railColor: Color {
        switch self {
        case .all:
            return Color(red: 0.82, green: 0.82, blue: 0.81)
        case .category(let cat):
            return cat.deepHeaderColor.opacity(0.85)
        }
    }
    
    var headerUsesDarkText: Bool {
        switch self {
        case .all:
            return true
        case .category:
            return false
        }
    }
    
    var backgroundTint: Color {
        switch self {
        case .all:
            return Color.clear
        case .category(let cat):
            return cat.color.opacity(0.15)
        }
    }
}

// MARK: - Color Palette

extension Color {
    static let indexOffWhite = Color(red: 0.97, green: 0.96, blue: 0.95)
    static let indexBackground = Color(red: 0.965, green: 0.960, blue: 0.955)
    static let indexCardBackground = Color.white
    static let indexPrimaryText = Color(red: 0.12, green: 0.12, blue: 0.13)
    static let indexSecondaryText = Color(red: 0.45, green: 0.45, blue: 0.47)
    static let indexTertiaryText = Color(red: 0.62, green: 0.62, blue: 0.64)
    static let indexLightText = Color(red: 0.72, green: 0.72, blue: 0.73)
    static let indexAccent = Color(red: 0.20, green: 0.45, blue: 1.0)
    static let indexDestructive = Color(red: 0.90, green: 0.25, blue: 0.20)
}

// MARK: - Header Constants

private struct HeaderConstants {
    static let titleHeight: CGFloat = 50
    static let railHeight: CGFloat = 76
    static let filterButtonHeight: CGFloat = 48
    static let filterButtonHeightSelected: CGFloat = 60
    static let filterButtonWidth: CGFloat = 68
    static let filterButtonWidthSelected: CGFloat = 82
}

// MARK: - Available Colors for New Categories

let categoryColorOptions: [UInt] = [
    0xFF5A4D, 0xFF8C26, 0xF2BF26, 0x40C77E,
    0x33ADD9, 0x5980F2, 0x9966F2, 0xF26699
]

let categoryIconOptions: [String] = [
    "lightbulb.fill", "briefcase.fill", "heart.fill", "checkmark.circle.fill",
    "star.fill", "flag.fill", "bookmark.fill", "tag.fill",
    "folder.fill", "tray.fill", "archivebox.fill", "doc.fill",
    "camera.fill", "photo.fill", "music.note", "mic.fill",
    "phone.fill", "envelope.fill", "message.fill", "bubble.left.fill",
    "cart.fill", "bag.fill", "creditcard.fill", "giftcard.fill",
    "house.fill", "building.fill", "car.fill", "airplane",
    "leaf.fill", "flame.fill", "bolt.fill", "drop.fill",
    "sun.max.fill", "moon.fill", "cloud.fill", "snowflake",
    "graduationcap.fill", "book.fill", "pencil", "paintbrush.fill"
]

// MARK: - Filter Button (Normal Mode)

struct IndexFilterButton: View {
    let filter: FilterOption
    let isSelected: Bool
    let headerUsesDarkText: Bool
    let onTap: () -> Void
    
    var unselectedTextColor: Color {
        headerUsesDarkText ? Color.black.opacity(0.4) : Color.white.opacity(0.55)
    }
    
    var unselectedBgColor: Color {
        headerUsesDarkText ? Color.black.opacity(0.06) : Color.white.opacity(0.12)
    }
    
    var buttonWidth: CGFloat {
        isSelected ? HeaderConstants.filterButtonWidthSelected : HeaderConstants.filterButtonWidth
    }
    
    var buttonHeight: CGFloat {
        isSelected ? HeaderConstants.filterButtonHeightSelected : HeaderConstants.filterButtonHeight
    }
    
    var iconSize: CGFloat {
        isSelected ? 19 : 15
    }
    
    var fontSize: CGFloat {
        isSelected ? 10 : 9
    }
    
    var body: some View {
        VStack(spacing: isSelected ? 4 : 3) {
            Image(systemName: filter.icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundColor(isSelected ? .white.opacity(0.95) : filter.tileColor)
            
            Text(filter.displayName)
                .font(.system(size: fontSize, weight: isSelected ? .bold : .semibold))
                .foregroundColor(isSelected ? .white.opacity(0.95) : unselectedTextColor)
                .lineLimit(1)
        }
        .frame(width: buttonWidth, height: buttonHeight)
        .background(
            RoundedRectangle(cornerRadius: isSelected ? 14 : 10)
                .fill(isSelected ? filter.tileColor : unselectedBgColor)
        )
        .shadow(color: isSelected ? filter.tileColor.opacity(0.35) : .clear, radius: 6, x: 0, y: 3)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Editable Category Button (Edit Mode)

struct EditableCategoryButton: View {
    let category: RecordingCategory
    let isSelected: Bool
    let headerUsesDarkText: Bool
    let isWiggling: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    let onLongPress: () -> Void
    
    @State private var wiggleAmount: Double = 0
    @State private var isPressing: Bool = false
    @State private var longPressTimer: Timer?
    
    var unselectedTextColor: Color {
        headerUsesDarkText ? Color.black.opacity(0.4) : Color.white.opacity(0.55)
    }
    
    var unselectedBgColor: Color {
        headerUsesDarkText ? Color.black.opacity(0.06) : Color.white.opacity(0.12)
    }
    
    var buttonWidth: CGFloat {
        isSelected ? HeaderConstants.filterButtonWidthSelected : HeaderConstants.filterButtonWidth
    }
    
    var buttonHeight: CGFloat {
        isSelected ? HeaderConstants.filterButtonHeightSelected : HeaderConstants.filterButtonHeight
    }
    
    var iconSize: CGFloat {
        isSelected ? 19 : 15
    }
    
    var fontSize: CGFloat {
        isSelected ? 10 : 9
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Main button content
            VStack(spacing: isSelected ? 4 : 3) {
                Image(systemName: category.iconName)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundColor(isSelected ? .white.opacity(0.95) : category.color)
                
                Text(category.name)
                    .font(.system(size: fontSize, weight: isSelected ? .bold : .semibold))
                    .foregroundColor(isSelected ? .white.opacity(0.95) : unselectedTextColor)
                    .lineLimit(1)
            }
            .frame(width: buttonWidth, height: buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: isSelected ? 14 : 10)
                    .fill(isSelected ? category.color : unselectedBgColor)
            )
            .shadow(color: isSelected ? category.color.opacity(0.35) : .clear, radius: 6, x: 0, y: 3)
            .scaleEffect(isPressing ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isPressing)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
            .onLongPressGesture(minimumDuration: 0.4, pressing: { pressing in
                if pressing {
                    isPressing = true
                    longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { _ in
                        onLongPress()
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                    }
                } else {
                    isPressing = false
                    longPressTimer?.invalidate()
                    longPressTimer = nil
                }
            }, perform: {})
            
            // Delete button - larger and more visible
            if isWiggling {
                Button(action: onDelete) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 26, height: 26)
                        
                        Circle()
                            .fill(Color.indexDestructive)
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .offset(x: -8, y: -8)
                .buttonStyle(PlainButtonStyle())
                .zIndex(10)
            }
        }
        .rotationEffect(.degrees(isWiggling ? wiggleAmount : 0))
        .onAppear {
            if isWiggling {
                startWiggle()
            }
        }
        .onChange(of: isWiggling) { newValue in
            if newValue {
                startWiggle()
            } else {
                withAnimation(.easeOut(duration: 0.1)) {
                    wiggleAmount = 0
                }
            }
        }
        .onDisappear {
            longPressTimer?.invalidate()
        }
    }
    
    private func startWiggle() {
        wiggleAmount = -2
        withAnimation(
            .easeInOut(duration: 0.1)
            .repeatForever(autoreverses: true)
        ) {
            wiggleAmount = 2
        }
    }
}

// MARK: - Add Category Button

struct IndexAddCategoryButton: View {
    let headerUsesDarkText: Bool
    let onTap: () -> Void
    
    var iconColor: Color {
        headerUsesDarkText ? Color.black.opacity(0.25) : Color.white.opacity(0.35)
    }
    
    var borderColor: Color {
        headerUsesDarkText ? Color.black.opacity(0.12) : Color.white.opacity(0.18)
    }
    
    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(iconColor)
            
            Text("Add")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(iconColor)
        }
        .frame(width: HeaderConstants.filterButtonWidth, height: HeaderConstants.filterButtonHeight)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(borderColor, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Swipeable Recording Card

struct SwipeableRecordingCard: View {
    let recording: Recording
    let category: RecordingCategory?
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var isSwiping = false
    @State private var hasDecidedDirection = false
    
    private let deleteThreshold: CGFloat = -80
    private let deleteButtonWidth: CGFloat = 80
    private let directionThreshold: CGFloat = 10
    
    private var displayText: String {
        if recording.isTranscribing {
            return "Transcribing..."
        }
        if let text = recording.transcription, !text.isEmpty {
            return text
        }
        return "Tap to transcribe"
    }
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete background - only show when actively swiped
            if offset < 0 {
                HStack(spacing: 0) {
                    Spacer()
                    Button(action: onDelete) {
                        VStack(spacing: 4) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Delete")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .frame(width: deleteButtonWidth)
                        .frame(maxHeight: .infinity)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.indexDestructive)
                )
            }
            
            // Card content
            VStack(alignment: .leading, spacing: 10) {
                Text(displayText)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(recording.transcription == nil && !recording.isTranscribing ? .indexTertiaryText : .indexPrimaryText)
                    .italic(recording.isTranscribing)
                    .lineLimit(2)
                    .lineSpacing(3)
                
                HStack(spacing: 0) {
                    if !recording.isRead {
                        Circle()
                            .fill(Color.indexAccent)
                            .frame(width: 7, height: 7)
                            .padding(.trailing, 8)
                    }
                    
                    Text(recording.relativeTime)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.indexLightText)
                    
                    if recording.duration > 0 {
                        Text("  ·  \(recording.formattedDuration)")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.indexLightText)
                    }
                    
                    if let category = category {
                        Text("  ·  ")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.indexLightText)
                        
                        Image(systemName: category.iconName)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(category.color)
                            .padding(.trailing, 4)
                        
                        Text(category.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(category.color)
                    }
                }
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.indexCardBackground)
            )
            .offset(x: offset)
            .gesture(
                DragGesture(minimumDistance: 20, coordinateSpace: .local)
                    .onChanged { gesture in
                        // Only track if the gesture started clearly horizontal
                        if !hasDecidedDirection {
                            let horizontal = abs(gesture.translation.width)
                            let vertical = abs(gesture.translation.height)
                            
                            hasDecidedDirection = true
                            // Must be more horizontal than vertical and swiping left
                            if horizontal > vertical && gesture.translation.width < 0 {
                                isSwiping = true
                            }
                        }
                        
                        if isSwiping && gesture.translation.width < 0 {
                            offset = gesture.translation.width
                        }
                    }
                    .onEnded { gesture in
                        if isSwiping {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if gesture.translation.width < deleteThreshold {
                                    offset = -deleteButtonWidth
                                } else {
                                    offset = 0
                                }
                            }
                        }
                        isSwiping = false
                        hasDecidedDirection = false
                    }
            )
            .onTapGesture {
                if offset < 0 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        offset = 0
                    }
                } else {
                    onTap()
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Recording Detail Modal

struct IndexRecordingDetailModal: View {
    let recording: Recording
    let categories: [RecordingCategory]
    let onCategorySelected: (RecordingCategory) -> Void
    let onDelete: () -> Void
    let onTranscribe: () -> Void
    let onAddCategory: () -> Void
    
    private var displayText: String {
        if recording.isTranscribing {
            return "Transcribing..."
        }
        return recording.transcription ?? "No transcription yet"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.indexLightText.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, 14)
                .padding(.bottom, 28)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(displayText)
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(recording.transcription == nil ? .indexTertiaryText : .indexPrimaryText)
                        .italic(recording.isTranscribing)
                        .lineSpacing(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                    
                    HStack(spacing: 12) {
                        Text(recording.relativeTime)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.indexLightText)
                        
                        if recording.duration > 0 {
                            Text("·")
                                .foregroundColor(.indexLightText)
                            Text(recording.formattedDuration)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.indexLightText)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    if recording.transcription == nil && !recording.isTranscribing {
                        Button(action: onTranscribe) {
                            HStack {
                                Image(systemName: "waveform")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Transcribe")
                                    .font(.system(size: 17, weight: .medium))
                            }
                            .foregroundColor(.indexAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.indexAccent.opacity(0.1))
                            )
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    Spacer().frame(height: 8)
                    
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Category")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.indexSecondaryText)
                            .textCase(.uppercase)
                            .tracking(0.8)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 16)
                        
                        ForEach(categories) { category in
                            IndexCategoryRow(
                                category: category,
                                isSelected: recording.categoryName == category.name
                            )
                            .onTapGesture {
                                onCategorySelected(category)
                            }
                        }
                        
                        Button(action: onAddCategory) {
                            HStack(spacing: 14) {
                                Image(systemName: "plus")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.indexAccent)
                                    .frame(width: 22)
                                
                                Text("New category")
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundColor(.indexAccent)
                                
                                Spacer()
                            }
                            .padding(.vertical, 16)
                            .padding(.horizontal, 24)
                            .background(Color.indexCardBackground)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    Spacer().frame(height: 32)
                    
                    Button(action: onDelete) {
                        Text("Delete thought")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.indexDestructive)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer(minLength: 40)
                }
            }
        }
        .background(Color.indexBackground)
    }
}

// MARK: - Category Row

struct IndexCategoryRow: View {
    let category: RecordingCategory
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: category.iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(category.color)
                .frame(width: 22)
            
            Text(category.name)
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(.indexPrimaryText)
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.indexAccent)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 24)
        .background(Color.indexCardBackground)
        .contentShape(Rectangle())
    }
}

// MARK: - Add Category Modal

struct IndexAddCategoryModal: View {
    @Binding var name: String
    @Binding var selectedColorIndex: Int
    @Binding var selectedIcon: String
    let onSave: () -> Void
    let onCancel: () -> Void
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)
    
    private func colorFromHex(_ hex: UInt) -> Color {
        Color(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel", action: onCancel)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.indexAccent)
                
                Spacer()
                
                Text("New Category")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.indexPrimaryText)
                
                Spacer()
                
                Button("Save", action: onSave)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(name.isEmpty ? .indexLightText : .indexAccent)
                    .disabled(name.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.indexCardBackground)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack {
                        Spacer()
                        VStack(spacing: 5) {
                            Image(systemName: selectedIcon)
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text(name.isEmpty ? "Name" : name)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(name.isEmpty ? 0.5 : 0.9))
                        }
                        .frame(width: 80, height: 70)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(colorFromHex(categoryColorOptions[selectedColorIndex]))
                        )
                        Spacer()
                    }
                    .padding(.top, 24)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Name")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.indexSecondaryText)
                            .textCase(.uppercase)
                            .tracking(0.8)
                        
                        TextField("Category name", text: $name)
                            .font(.system(size: 17))
                            .foregroundColor(.indexPrimaryText)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.indexCardBackground)
                            )
                    }
                    .padding(.horizontal, 20)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Color")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.indexSecondaryText)
                            .textCase(.uppercase)
                            .tracking(0.8)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 8), spacing: 12) {
                            ForEach(0..<categoryColorOptions.count, id: \.self) { index in
                                Button(action: { selectedColorIndex = index }) {
                                    Circle()
                                        .fill(colorFromHex(categoryColorOptions[index]))
                                        .frame(width: 34, height: 34)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(Color.white, lineWidth: selectedColorIndex == index ? 3 : 0)
                                                .padding(2)
                                        )
                                        .scaleEffect(selectedColorIndex == index ? 1.1 : 1.0)
                                        .animation(.easeOut(duration: 0.15), value: selectedColorIndex)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Icon")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.indexSecondaryText)
                            .textCase(.uppercase)
                            .tracking(0.8)
                        
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(categoryIconOptions, id: \.self) { icon in
                                Button(action: { selectedIcon = icon }) {
                                    Image(systemName: icon)
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(selectedIcon == icon ? .white : .indexSecondaryText)
                                        .frame(width: 44, height: 44)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(selectedIcon == icon ? colorFromHex(categoryColorOptions[selectedColorIndex]) : Color.indexCardBackground)
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 40)
                }
            }
            .background(Color.indexBackground)
        }
        .background(Color.indexBackground)
    }
}

// MARK: - Settings Modal

struct IndexSettingsModal: View {
    @Binding var isDarkMode: Bool
    let onDeleteAll: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.indexLightText.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, 14)
                .padding(.bottom, 24)
            
            Text("Settings")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.indexPrimaryText)
                .padding(.bottom, 32)
            
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Appearance")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.indexSecondaryText)
                        .textCase(.uppercase)
                        .tracking(0.8)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                    
                    HStack {
                        Image(systemName: "moon.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.indexAccent)
                            .frame(width: 26)
                        
                        Text("Dark mode")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(.indexPrimaryText)
                        
                        Spacer()
                        
                        Toggle("", isOn: $isDarkMode)
                            .labelsHidden()
                            .tint(.indexAccent)
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 24)
                    .background(Color.indexCardBackground)
                }
                
                Spacer().frame(height: 40)
                
                VStack(alignment: .leading, spacing: 0) {
                    Text("Danger zone")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.indexSecondaryText)
                        .textCase(.uppercase)
                        .tracking(0.8)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                    
                    Button(action: onDeleteAll) {
                        HStack {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.indexDestructive)
                                .frame(width: 26)
                            
                            Text("Delete all thoughts")
                                .font(.system(size: 17, weight: .regular))
                                .foregroundColor(.indexDestructive)
                            
                            Spacer()
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 24)
                        .background(Color.indexCardBackground)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            Spacer()
        }
        .background(Color.indexBackground)
    }
}

// MARK: - Empty State

struct IndexEmptyState: View {
    let isSyncing: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: isSyncing ? "arrow.triangle.2.circlepath" : "waveform")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.indexTertiaryText)
                .rotationEffect(.degrees(isSyncing ? 360 : 0))
                .animation(isSyncing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isSyncing)
            
            Text(isSyncing ? "Syncing..." : "No thoughts yet")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.indexSecondaryText)
            
            Text(isSyncing ? "Receiving recordings from your watch" : "Record on your Apple Watch to get started")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.indexTertiaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
    }
}

// MARK: - Rounded Corner Shape

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Scroll Offset Preference Key

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Main Index View

struct IndexView: View {
    @EnvironmentObject private var connectivityManager: WatchConnectivityManager
    @StateObject private var categoryStore = CategoryStore()
    
    @State private var selectedRecording: Recording? = nil
    @State private var selectedFilter: FilterOption = .all
    @State private var showSettings: Bool = false
    @State private var showAddCategory: Bool = false
    @State private var isDarkMode: Bool = false
    @State private var isEditingCategories: Bool = false
    
    // New category state
    @State private var newCategoryName: String = ""
    @State private var newCategoryColorIndex: Int = 0
    @State private var newCategoryIcon: String = "star.fill"
    
    var filterOptions: [FilterOption] {
        [.all] + categoryStore.categories.map { .category($0) }
    }
    
    var filteredRecordings: [Recording] {
        let recordings = connectivityManager.recordings
        
        switch selectedFilter {
        case .all:
            return recordings.sorted { $0.createdAt > $1.createdAt }
        case .category(let cat):
            return recordings.filter { $0.categoryName == cat.name }.sorted { $0.createdAt > $1.createdAt }
        }
    }
    
    func categoryFor(_ recording: Recording) -> RecordingCategory? {
        guard let name = recording.categoryName else { return nil }
        return categoryStore.categories.first { $0.name == name }
    }
    
    var collapseProgress: CGFloat {
        // Simplified: no dynamic scrolling effect for now
        return 0
    }
    
    var titleHeight: CGFloat {
        HeaderConstants.titleHeight * (1 - collapseProgress)
    }
    
    var titleOpacity: CGFloat {
        1 - collapseProgress
    }
    
    var titleTextColor: Color {
        selectedFilter.headerUsesDarkText ? .indexPrimaryText : .indexOffWhite
    }
    
    var settingsIconColor: Color {
        selectedFilter.headerUsesDarkText ? Color.black.opacity(0.4) : Color.white.opacity(0.6)
    }
    
    var backgroundWithTint: some View {
        ZStack {
            Color.indexBackground
            selectedFilter.backgroundTint
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.3), value: selectedFilter.displayName)
    }
    
    func deleteCategory(_ category: RecordingCategory) {
        if case .category(let selected) = selectedFilter, selected.id == category.id {
            selectedFilter = .all
        }
        categoryStore.delete(category)
    }
    
    func exitEditMode() {
        withAnimation(.easeOut(duration: 0.2)) {
            isEditingCategories = false
        }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            backgroundWithTint
                .zIndex(0)
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 0) {
                    // Title section
                    HStack(alignment: .center) {
                        Text("Ramble")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(titleTextColor)
                        
                        Spacer()
                        
                        if connectivityManager.receivingFile || connectivityManager.isSyncing {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(selectedFilter.headerUsesDarkText ? .indexSecondaryText : .white.opacity(0.7))
                                .scaleEffect(0.7)
                                .padding(.trailing, 6)
                        }
                        
                        Button(action: { showSettings = true }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(settingsIconColor)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
                    .padding(.bottom, 8)
                    .frame(height: titleHeight)
                    .opacity(titleOpacity)
                    .clipped()
                    
                    // Category Rail
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .center, spacing: 6) {
                            // "All" button - not editable
                            IndexFilterButton(
                                filter: .all,
                                isSelected: selectedFilter == .all,
                                headerUsesDarkText: selectedFilter.headerUsesDarkText,
                                onTap: {
                                    if isEditingCategories {
                                        exitEditMode()
                                    } else {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            selectedFilter = .all
                                        }
                                    }
                                }
                            )
                            
                            // Category buttons - editable
                            ForEach(categoryStore.categories) { category in
                                let filter = FilterOption.category(category)
                                let isSelected = {
                                    if case .category(let sel) = selectedFilter {
                                        return sel.id == category.id
                                    }
                                    return false
                                }()
                                
                                EditableCategoryButton(
                                    category: category,
                                    isSelected: isSelected,
                                    headerUsesDarkText: selectedFilter.headerUsesDarkText,
                                    isWiggling: isEditingCategories,
                                    onTap: {
                                        if isEditingCategories {
                                            exitEditMode()
                                        } else {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                selectedFilter = filter
                                            }
                                        }
                                    },
                                    onDelete: {
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            deleteCategory(category)
                                        }
                                    },
                                    onLongPress: {
                                        withAnimation(.easeOut(duration: 0.15)) {
                                            isEditingCategories = true
                                        }
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                        impactFeedback.impactOccurred()
                                    }
                                )
                            }
                            
                            IndexAddCategoryButton(
                                headerUsesDarkText: selectedFilter.headerUsesDarkText,
                                onTap: {
                                    if isEditingCategories {
                                        exitEditMode()
                                    }
                                    newCategoryName = ""
                                    newCategoryColorIndex = 0
                                    newCategoryIcon = "star.fill"
                                    showAddCategory = true
                                }
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .frame(height: HeaderConstants.railHeight)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(selectedFilter.railColor)
                            .padding(.horizontal, 8)
                    )
                }
                .padding(.bottom, 4)
                .background(
                    selectedFilter.headerColor
                        .clipShape(RoundedCorner(radius: 20, corners: [.bottomLeft, .bottomRight]))
                        .ignoresSafeArea(edges: .top)
                        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
                )
                .animation(.easeInOut(duration: 0.3), value: selectedFilter.displayName)
                .zIndex(1)
                
                // Content
                if filteredRecordings.isEmpty {
                    IndexEmptyState(isSyncing: connectivityManager.receivingFile || connectivityManager.isSyncing)
                        .onTapGesture {
                            if isEditingCategories {
                                exitEditMode()
                            }
                        }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredRecordings) { recording in
                                SwipeableRecordingCard(
                                    recording: recording,
                                    category: categoryFor(recording),
                                    onTap: {
                                        if isEditingCategories {
                                            exitEditMode()
                                        } else {
                                            connectivityManager.markAsRead(recording)
                                            selectedRecording = recording
                                        }
                                    },
                                    onDelete: {
                                        connectivityManager.deleteRecording(recording)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            connectivityManager.loadRecordings()
        }
        .sheet(item: $selectedRecording) { recording in
            IndexRecordingDetailModal(
                recording: recording,
                categories: categoryStore.categories,
                onCategorySelected: { category in
                    connectivityManager.assignCategory(category.name, to: recording)
                    selectedRecording = nil
                },
                onDelete: {
                    connectivityManager.deleteRecording(recording)
                    selectedRecording = nil
                },
                onTranscribe: {
                    Task {
                        await connectivityManager.transcribe(recording)
                    }
                    selectedRecording = nil
                },
                onAddCategory: {
                    selectedRecording = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        newCategoryName = ""
                        newCategoryColorIndex = 0
                        newCategoryIcon = "star.fill"
                        showAddCategory = true
                    }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showSettings) {
            IndexSettingsModal(
                isDarkMode: $isDarkMode,
                onDeleteAll: {
                    // TODO: Implement delete all
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showAddCategory) {
            IndexAddCategoryModal(
                name: $newCategoryName,
                selectedColorIndex: $newCategoryColorIndex,
                selectedIcon: $newCategoryIcon,
                onSave: {
                    let newCategory = RecordingCategory(
                        name: newCategoryName,
                        iconName: newCategoryIcon,
                        colorHex: categoryColorOptions[newCategoryColorIndex]
                    )
                    categoryStore.add(newCategory)
                    showAddCategory = false
                },
                onCancel: {
                    showAddCategory = false
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
    }
}

// MARK: - Preview

#Preview {
    IndexView()
        .environmentObject(WatchConnectivityManager.shared)
}
