# Quick Setup: Enable Transcription

## TL;DR

Add this ONE line to your iOS app's Info.plist and transcription will work:

```
Privacy - Speech Recognition Usage Description
```

Value:
```
Ramble needs access to speech recognition to transcribe your voice recordings into text.
```

---

## Step-by-Step (2 minutes)

### Using Xcode UI

1. **Open your project in Xcode**

2. **Select your iOS app target**
   - Click project name in left sidebar
   - Under TARGETS, select "RAMBLE" (iOS, not Watch)

3. **Click the "Info" tab** at the top

4. **Add a new row**
   - Hover and click the `+` button
   - Type: "Privacy - Speech"
   - Select: **"Privacy - Speech Recognition Usage Description"**
   - Value: `Ramble needs access to speech recognition to transcribe your voice recordings into text.`

5. **Save** (Cmd+S)

6. **Clean Build** (Cmd+Shift+K)

7. **Run** and test!

---

## Or Edit XML Directly

Right-click Info.plist → Open As → Source Code

Add this inside the `<dict>` tag:

```xml
<key>NSSpeechRecognitionUsageDescription</key>
<string>Ramble needs access to speech recognition to transcribe your voice recordings into text.</string>
```

---

## Testing

1. ✅ Build and run app
2. ✅ Sync a recording from watch
3. ✅ Tap on recording
4. ✅ Tap "Transcribe Audio"
5. ✅ Grant permission when prompted
6. ✅ Wait a few seconds
7. ✅ See transcribed text!

---

## Already Set Up for Watch

Your Watch app already has microphone permission configured (via `PermissionsManager.swift`). You only need to add the **Speech Recognition** permission for the **iOS app**.

---

## Two Different Permissions

| Permission | Where | What For | Status |
|------------|-------|----------|--------|
| **Microphone** | Watch | Record audio | ✅ Already configured |
| **Speech Recognition** | iPhone | Transcribe audio | ❌ **Add to Info.plist** |

---

## What Happens After Adding

**First Transcription Attempt:**
- iOS shows permission dialog
- Your custom message explains why
- User taps "OK"

**Every Transcription After:**
- No dialog
- Immediate transcription
- Takes 2-10 seconds depending on length

**If User Denies:**
- Button becomes gray/disabled
- They can re-enable in Settings > Ramble

---

## That's It! 

The code is already implemented. Just add the permission key and you're done! 🎉

For full details, troubleshooting, and advanced info, see: `ENABLE_TRANSCRIPTION.md`
