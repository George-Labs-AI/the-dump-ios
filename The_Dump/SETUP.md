# The Dump iOS App - Setup Guide

## Project Setup

### 1. Create Xcode Project
- Open Xcode → File → New → Project
- Choose "App" under iOS
- Product Name: `TheDump`
- Bundle Identifier: `com.yourcompany.thedump`
- Interface: SwiftUI
- Language: Swift
- Minimum Deployment: iOS 16.0

### 2. Add Files
Copy all `.swift` files into your project maintaining this structure:
```
TheDump/
├── TheDumpApp.swift
├── Theme.swift
├── Models/
│   ├── SessionItem.swift
│   ├── UploadResponse.swift
│   └── APIError.swift
├── State/
│   ├── AppState.swift
│   └── SessionStore.swift
├── Services/
│   ├── AuthService.swift
│   ├── UploadService.swift
│   ├── AudioRecorderService.swift
│   └── AudioPlayerService.swift
└── Views/
    ├── AuthView.swift
    ├── ContentView.swift
    ├── CameraView.swift
    ├── VoiceMemoView.swift
    └── SettingsView.swift
```

### 3. Add Firebase SDK
Using Swift Package Manager:
1. File → Add Package Dependencies
2. Add: `https://github.com/firebase/firebase-ios-sdk`
3. Select these packages:
   - `FirebaseAuth`
   - `FirebaseCore`

### 4. Add GoogleService-Info.plist
1. Download from Firebase Console → Project Settings → iOS App
2. Drag into Xcode project root
3. Ensure "Copy items if needed" is checked
4. Add to target

### 5. Info.plist Configuration

Add these keys to your Info.plist (via Xcode target → Info tab or edit directly):

```xml
<!-- Camera access -->
<key>NSCameraUsageDescription</key>
<string>The Dump needs camera access to capture photos for your notes.</string>

<!-- Photo library access -->
<key>NSPhotoLibraryUsageDescription</key>
<string>The Dump needs photo library access to upload existing photos.</string>

<!-- Microphone access -->
<key>NSMicrophoneUsageDescription</key>
<string>The Dump needs microphone access to record voice memos.</string>
```

### 6. Build Settings
- iOS Deployment Target: 16.0
- Swift Language Version: 5.0

### 7. Capabilities
No special capabilities required for v1.

---

## Firebase Configuration

### Firebase Console Setup
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project (or create one)
3. Add iOS app if not already added
4. Download `GoogleService-Info.plist`

### Authentication Setup
1. Firebase Console → Authentication → Sign-in method
2. Enable Email/Password provider
3. Ensure your test users exist

---

## Testing

### Simulator
- Photo capture will use photo library (camera not available)
- Voice recording works normally
- Use test Firebase credentials

### Device
- Camera capture available
- Full functionality
- Requires provisioning profile

### Test Checklist
- [ ] Login with valid credentials
- [ ] Login with invalid credentials (error shown)
- [ ] Capture photo from camera/library
- [ ] Photo uploads successfully
- [ ] Record voice memo
- [ ] Play back voice memo
- [ ] Upload voice memo
- [ ] Session list shows uploads
- [ ] Logout clears session
- [ ] Network error handling

---

## API Endpoints

### Upload File
```
POST https://thedump.ai/api/mobile/upload_file
Authorization: Bearer <firebase_id_token>
Content-Type: application/json

{
  "filename": "photo_uuid.jpg",
  "contentType": "image/jpeg",
  "isQuickNote": false
}
```

Response:
```json
{
  "uploadUrl": "https://storage.googleapis.com/...",
  "storagePath": "user_email/timestamp_filename.jpg",
  "uuid": "...",
  ...
}
```

Then PUT file data to `uploadUrl`.

---

## Troubleshooting

### "Missing or invalid Authorization header"
- Ensure Firebase is configured correctly
- Check `GoogleService-Info.plist` is in project
- Verify user is logged in

### Camera not working
- On simulator: expected, uses photo library
- On device: check Info.plist permissions

### Recording fails
- Check microphone permission in Settings
- Ensure `NSMicrophoneUsageDescription` is set

### Upload fails
- Check network connectivity
- Verify backend URL is correct
- Check Firebase token is valid (not expired)
