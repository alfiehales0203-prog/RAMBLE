# Enable Transcription - Info.plist Setup

## Quick Fix: Add Speech Recognition Permission

Your transcription functionality is already implemented in the code! You just need to add the required privacy permission to your iOS app's `Info.plist`.

---

## Option 1: Using Xcode UI (Recommended)

1. **Open your project in Xcode**

2. **Select the iOS app target** (not the Watch target)
   - Click on your project name in the Project Navigator (left sidebar)
   - Under "TARGETS", select "RAMBLE" (the iOS target)

3. **Go to the Info tab**
   - You should see the Info tab in the top bar of the editor

4. **Add the permission**
   - Hover over any row and click the `+` button (or right-click and choose "Add Row")
   - Start typing: **"Privacy - Speech Recognition Usage Description"**
   - Xcode will autocomplete to: `Privacy - Speech Recognition Usage Description`
   - In the Value column, paste:
     ```
     Ramble needs access to speech recognition to transcribe your voice recordings into text.
     ```

5. **Save** (Cmd+S)

---

## Option 2: Edit Info.plist XML Directly

If you prefer to edit the XML directly:

1. **Find Info.plist**
   - Right-click on `Info.plist` in Project Navigator
   - Choose "Open As" → "Source Code"

2. **Add this XML** (anywhere inside the `<dict>` tag):
   ```xml
   <key>NSSpeechRecognitionUsageDescription</key>
   <string>Ramble needs access to speech recognition to transcribe your voice recordings into text.</string>
   ```

3. **Save** (Cmd+S)

---

## Option 3: Create/Edit Info.plist if Missing

If you don't see an Info.plist file (newer Xcode projects might not have one visible):

1. **Check the Info tab** (Option 1 above still works)
2. **Or create a new Info.plist**:
   - Right-click on your iOS app folder
   - New File → Property List
   - Name it `Info.plist`
   - Add the content:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>Ramble needs access to speech recognition to transcribe your voice recordings into text.</string>
</dict>
</plist>
```

---

## Complete Info.plist Example

Your complete Info.plist might look like this:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleDisplayName</key>
    <string>Ramble</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>UIApplicationSceneManifest</key>
    <dict>
        <key>UIApplicationSupportsMultipleScenes</key>
        <true/>
    </dict>
    <key>UILaunchScreen</key>
    <dict/>
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>Ramble needs access to speech recognition to transcribe your voice recordings into text.</string>
</dict>
</plist>
```

---

## After Adding the Permission

### Test It Out

1. **Clean build** (Cmd+Shift+K)
2. **Build and run** your app
3. **Sync a recording** from your watch
4. **Tap on a recording** to open the detail view or options sheet
5. **Tap "Transcribe Audio"**
6. **Grant permission** when prompted
7. **Wait a few seconds** for transcription to complete

### What You'll See

**First Time:**
- iOS will show a permission dialog
- "Ramble would like to access Speech Recognition"
- Your custom message will appear below
- User taps "OK" to allow

**During Transcription:**
- "Transcribing..." message with spinner
- Recording card shows italic text

**After Transcription:**
- Full text appears in the detail view
- Copy and Share buttons become available
- Text is automatically saved

---

## Permission States

### ✅ Authorized
- Transcription button is enabled and blue
- Tapping it starts transcription immediately

### ⏸️ Not Determined (First Launch)
- Transcription button is enabled
- Tapping it triggers the permission dialog
- After granting, transcription starts

### ❌ Denied
- Transcription button is disabled and gray
- Message: "Transcription not available"
- User must go to Settings to re-enable

### How to Re-enable if Denied

1. Open **Settings** app
2. Scroll to **Ramble**
3. Toggle **Speech Recognition** ON

Or:

1. Open **Settings** app
2. Go to **Privacy & Security**
3. Tap **Speech Recognition**
4. Find **Ramble** and toggle ON

---

## Additional Privacy Keys (Optional)

While you're in Info.plist, consider adding these for better UX:

### Microphone Permission (for Watch recording)
```xml
<key>NSMicrophoneUsageDescription</key>
<string>Ramble needs access to the microphone to record your voice notes on Apple Watch.</string>
```

**Note:** This is only needed if you record on iPhone. If you only record on Watch, you don't need this for the iOS app.

---

## Code That Uses This Permission

The permission is checked in `WatchConnectivityManager.swift`:

```swift
func transcribe(_ recording: Recording) async {
    // Request authorization if needed
    let authStatus = SFSpeechRecognizer.authorizationStatus()
    if authStatus == .notDetermined {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume()
            }
        }
    }
    
    guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
        print("❌ Speech recognition not authorized")
        return
    }
    
    // ... transcription happens here
}
```

### Permission Request Methods

You can also manually request permission:

```swift
// Check availability
if connectivityManager.isTranscriptionAvailable {
    // Transcription is available
}

// Request permission explicitly
let granted = await connectivityManager.requestTranscriptionPermission()
if granted {
    // User granted permission
}
```

---

## Troubleshooting

### "Transcription not available" button
**Problem:** Button is grayed out
**Solutions:**
1. Check Info.plist has the key
2. Clean build (Cmd+Shift+K)
3. Delete app from device
4. Rebuild and reinstall
5. Check device language is supported

### Permission prompt never appears
**Problem:** No dialog shows when tapping transcribe
**Solutions:**
1. Verify Info.plist key exists
2. Check spelling: `NSSpeechRecognitionUsageDescription`
3. Rebuild project completely
4. Check you're testing on the iOS app, not Watch

### Transcription fails silently
**Problem:** No error, but no transcription appears
**Solutions:**
1. Check Console logs for errors
2. Verify audio file exists and isn't corrupt
3. Check audio quality is sufficient
4. Try a shorter, clearer recording first
5. Ensure iPhone has internet for first-time setup (downloads language models)

### "Speech recognizer not available"
**Problem:** Feature works but randomly becomes unavailable
**Solutions:**
1. Ensure device isn't in Low Power Mode
2. Check sufficient storage space (language models need space)
3. Verify iOS version is 13.0+
4. Restart device

---

## Testing Checklist

- [ ] Info.plist contains `NSSpeechRecognitionUsageDescription`
- [ ] Clean build performed
- [ ] App runs without crashes
- [ ] Sync recording from watch successfully
- [ ] Tap on recording to view details
- [ ] "Transcribe Audio" button is visible and enabled
- [ ] Tapping button shows permission dialog (first time)
- [ ] Grant permission
- [ ] Transcription begins (shows "Transcribing...")
- [ ] Transcription completes (shows text)
- [ ] Can copy transcription to clipboard
- [ ] Can share transcription
- [ ] Transcription persists after app restart

---

## Console Logs to Watch For

### Successful Transcription
```
🎤 Starting transcription for: Dec 11, 2024 at 2:30 PM
✅ Transcription complete: This is a test recording...
```

### Permission Issues
```
❌ Speech recognition not authorized
```

### Availability Issues
```
❌ Speech recognizer not available
```

### Already Transcribing
```
⚠️ Already transcribing Recording Name
```

---

## Summary

**You only need to:**
1. ✅ Open Info.plist in Xcode
2. ✅ Add "Privacy - Speech Recognition Usage Description" key
3. ✅ Set value to: "Ramble needs access to speech recognition to transcribe your voice recordings into text."
4. ✅ Clean and rebuild
5. ✅ Test transcription feature

The code is already there and working! Just needs the permission key. 🎉
