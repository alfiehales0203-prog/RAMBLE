# Fix Target Membership Issues

## Problem
Your project has files being compiled in the wrong targets (iOS vs watchOS), causing duplicate declarations and missing imports.

## ✅ Code Fixes Already Applied

I've added the missing `Combine` imports to these files:

1. **PermissionsManager.swift** - Added `import Combine`
2. **PermissionsManager-Watch.swift** - Added `import Combine`
3. **PlaybackView.swift** - Added `import SwiftUI` and `import Combine`
4. **ContentView.swift** - Added `import SwiftUI`

## 🎯 Target Membership Configuration Needed

You need to configure which files belong to which targets in Xcode. Here's how:

### Step 1: Open Target Membership Panel
1. In Xcode, select a file in the Project Navigator
2. Open the File Inspector (⌥⌘1 or View > Inspectors > File)
3. Look for "Target Membership" section

### Step 2: Configure iOS Target Files

**These files should ONLY be checked for your iOS app target:**

- `ContentView.swift` (iOS version)
- `PermissionsManager.swift` (has `permissionDenied` property)
- `WatchConnectivityManager.swift` (iOS receiver)
- `IOSStorageManager.swift`
- Any iOS-specific UI files

### Step 3: Configure watchOS Target Files

**These files should ONLY be checked for your watchOS app target:**

- `ContentView-Watch.swift` (rename to just `ContentView.swift` after removing from iOS target)
- `PermissionsManager-Watch.swift` (rename to just `PermissionsManager.swift` after removing from iOS target)
- `WatchConnectivitySender.swift` (watchOS sender)
- `RecordingManager.swift`
- `RecordingView.swift`
- `RecordingsListView.swift`
- `SyncSettingsView-Watch.swift`
- `PlaybackView.swift`
- `RAMBLEApp.swift` (watchOS app file)
- `ComplicationController.swift`

### Step 4: Configure Shared Files

**These files can be in BOTH targets:**

- `Recording.swift` (shared model)
- `RecordingModel.swift` (if different from Recording.swift)
- `StorageManager.swift` (appears to be shared storage logic)

## 🔧 Quick Fix in Xcode

### Option A: Manual Fix
For each file with errors:
1. Select the file in Project Navigator
2. Open File Inspector (⌥⌘1)
3. Under "Target Membership", uncheck the wrong target
4. Keep only the correct target checked

### Option B: Rename Platform-Specific Files
After fixing target membership:
1. Remove iOS `PermissionsManager.swift` from watchOS target
2. Rename `PermissionsManager-Watch.swift` to `PermissionsManager.swift`
3. Remove iOS `ContentView.swift` from watchOS target  
4. Rename `ContentView-Watch.swift` to `ContentView.swift`
5. Do the same for other `-Watch` suffixed files

## 📋 Expected Result

After fixing target membership, you should have:

### iOS App Structure:
```
iOS Target/
├── ContentView.swift (iOS version)
├── PermissionsManager.swift (iOS version)
├── WatchConnectivityManager.swift
└── Shared Models/
    ├── Recording.swift
    └── StorageManager.swift
```

### watchOS App Structure:
```
watchOS Target/
├── RAMBLEApp.swift
├── ContentView.swift (watchOS version)
├── PermissionsManager.swift (watchOS version)
├── RecordingManager.swift
├── WatchConnectivitySender.swift
├── RecordingView.swift
├── RecordingsListView.swift
├── PlaybackView.swift
├── SyncSettingsView.swift
└── Shared Models/
    ├── Recording.swift
    └── StorageManager.swift
```

## ⚠️ Common Errors and Their Causes

| Error | Cause | Fix |
|-------|-------|-----|
| `Invalid redeclaration of 'ContentView'` | Both ContentView files in same target | Remove one from target |
| `Invalid redeclaration of 'PermissionsManager'` | Both PermissionsManager files in same target | Remove one from target |
| `Cannot find 'WatchConnectivitySender'` | WatchConnectivitySender not in watchOS target | Add to watchOS target only |
| `init(wrappedValue:)' not available due to missing Combine` | Missing `import Combine` | Already fixed! |
| `ObservableObject` conformance error | Missing `import Combine` | Already fixed! |
| `Ambiguous use of 'shared'` | Multiple classes with same name in same target | Fix target membership |

## ✨ Verification

After fixing target membership, build both targets:
1. Select your iOS scheme and build (⌘B)
2. Select your watchOS scheme and build (⌘B)
3. Both should compile without errors

If you still see errors after fixing target membership, let me know which specific errors remain!
