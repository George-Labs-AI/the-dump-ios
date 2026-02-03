# The Dump (iOS)

#### Video Demo: <PASTE YOUR VIDEO URL HERE>

#### Description:
The Dump is an iOS companion app for `thedump.ai`. The goal is to remove friction from capturing “raw” thoughts (handwritten notes, sketches, quick voice ideas) and turn them into organized, searchable notes on the server. On the phone, the experience is intentionally simple: capture a photo or record a voice memo, upload it, and then browse the resulting organized notes by category, date group, or file type.

This project is split into a SwiftUI front end and an existing backend service. The iOS app does **not** attempt to do transcription or AI organization locally; instead it uploads the raw media and then fetches the server’s organized results. In practice, that means this app focuses on the mobile concerns: authentication, media capture, reliable uploads, and a clean browsing UI with pagination.

At a high level, the app has two main modes (tabs): **Dump** and **Browse**. The Dump tab is optimized for fast capture. It can open the camera (for photos) or a voice memo recorder (for audio). After you capture something, the app uploads it and shows “Uploads This Session” so you can confirm what you successfully sent. The Browse tab is optimized for consuming results that the backend has already processed. It loads folder counts, navigates into a filtered list of notes, and then fetches the full content for a selected note.

---

## Core user flows

### 1) Sign in (Firebase Authentication)
The app uses Firebase Authentication (email/password). When a user signs in successfully, Firebase maintains the session and the app listens to auth state changes. API requests to the backend include a **fresh Firebase ID token** in an `Authorization: Bearer <token>` header.

### 2) Capture → upload (photo or voice)
- **Photo**: The Dump tab opens the system camera UI, compresses the image to JPEG, requests a signed upload URL from the backend, then uploads the bytes directly to Google Cloud Storage.
- **Voice**: The voice memo screen requests microphone permission, records to a local `.m4a` file, optionally plays back the recording, then uploads it using the same signed‑URL approach. The app enforces a **100MB** max file size for audio before uploading.

A key security/performance decision here is the signed URL design: the iOS app never holds long‑lived cloud credentials. It asks the backend for a short‑lived URL, then uploads directly to storage. This reduces backend load and keeps credentials out of the mobile client.

### 3) Browse → list → detail (organized notes)
The Browse tab starts by calling an endpoint that returns **counts** for categories/date groups/mime types. Tapping a row navigates into a notes list filtered by that folder type. The list supports:
- pull‑to‑refresh
- infinite scroll pagination using `next_cursor_time` and `next_cursor_id`

Selecting a note navigates to a detail screen that fetches the full note text and title from the backend and displays the content in a scroll view.

---

## Project structure (what each file does)

### Entry point / global setup
- `TheDumpApp.swift`: App entry point; configures Firebase and chooses between `AuthView` and `MainTabView` based on auth state.
- `Theme.swift`: Centralized colors, spacing, and reusable button styles to keep the UI consistent.

### Models (shared data types)
- `Models/APIError.swift`: Central place for mapping HTTP/decoding/network failures into user‑readable errors.
- `Models/NoteModels.swift`: Codable structs for the backend note APIs (counts, previews with titles, full note details with titles).
- `Models/SessionItem.swift`: Data model for “Uploads This Session” items (kind, status, thumbnail/local file URL).
- `Models/UploadResponse.swift`: Codable struct for the backend response that returns the signed upload URL and storage path.

### Services (networking + device capabilities)
- `Services/AuthService.swift`: Wraps Firebase Auth sign‑in/out and exposes a method to fetch a fresh ID token for API calls.
- `Services/NotesService.swift`: Calls the backend note endpoints:
  - `GET /api/note_counts`
  - `GET /api/pull_notes` (filtered + paginated)
  - `POST /api/pull_full_notes`
  Also includes debug logging in DEBUG builds to make API troubleshooting easier.
- `Services/UploadService.swift`: Upload pipeline:
  1) `POST /api/mobile/upload_file` to request a signed URL
  2) `PUT` bytes directly to Google Cloud Storage
- `Services/AudioRecorderService.swift`: Microphone permission + record/pause/resume/stop to a local `.m4a` file.
- `Services/AudioPlayerService.swift`: Playback for recorded audio.

### State (view models / business logic)
- `State/AppState.swift`: Observes Firebase auth changes and publishes `isAuthenticated`, `userEmail`, and `currentUser` for the UI.
- `State/SessionStore.swift`: Stores uploads this session and publishes “last upload status” for the banner UI.
- `State/BrowseViewModel.swift`: Loads folder counts and converts them into UI rows (categories, date groups, file types).
- `State/NotesListViewModel.swift`: Owns the notes list for a specific filter; handles refresh + pagination cursor state.
- `State/NoteDetailViewModel.swift`: Fetches one note’s full content and manages loading/error state.

### Views (SwiftUI screens)
- `Views/AuthView.swift`: Email/password sign‑in screen with basic validation and error handling.
- `Views/MainTabView.swift`: Two tabs: Dump and Browse.
- `Views/ContentView.swift`: Dump screen; launches camera/voice memo/settings and shows session upload history.
- `Views/VoiceMemoView.swift`: Record + playback + upload voice memos; includes permission handling.
- `Views/BrowseView.swift`: Folder list (categories/date groups/file types) with pull‑to‑refresh.
- `Views/NotesListView.swift`: Paginated list of note previews with API titles; navigates to note detail.
- `Views/NoteDetailView.swift`: Displays the full note text and uses the API title in the navigation bar.
- `Views/SettingsView.swift`: Shows account info, session upload count, clear session history, sign out, and a debug link.
- `Views/DebugNotesView.swift`: Developer-only screen to manually test the notes APIs and inspect raw results.

---

## Setup / running the app
1. Open the Xcode project (`The_Dump.xcodeproj`) and select a simulator or device.
2. Ensure Firebase is configured:
   - `GoogleService-Info.plist` must be present in the app target.
3. Backend configuration:
   - The backend base URL is currently hardcoded (e.g., `https://thedump.ai`) in `NotesService.swift` and `UploadService.swift`.
4. Build and run. The app starts on the login screen. After signing in, you can capture uploads in the Dump tab and browse organized notes in the Browse tab.

---

## Design decisions (and why)
- **Firebase Auth + ID tokens**: I wanted a production-like auth flow where the server can verify a standard token and the client doesn’t manage passwords beyond sign-in.
- **Signed URL uploads**: Keeps cloud credentials off-device, reduces backend bandwidth, and scales better than proxying media through the server.
- **Session upload history**: Mobile uploads can fail for many reasons (permissions, connectivity, large files). Showing “Uploads This Session” provides immediate feedback and a lightweight form of reliability.
- **MVVM-ish separation**: View models handle loading/error/pagination state; views focus on rendering. This made the SwiftUI screens easier to reason about even as the app grew.

---

## Known limitations / future improvements
- No offline queueing/retry policy beyond showing failures in session history.
- Hardcoded backend base URLs (would be better as build configs).
- Limited note rendering (plain text only; no rich formatting).
- No on-device caching of note lists/details.
- No ability to upload files already stored on the phone or write a note using the device's keyboard (that functionality does currently exist in thedump.ai which is the flask web app I developed separately, the one that contains the note fetching APIs).
- No forgot/reset password in AuthView
- No ability to edit the notes in the NoteDetailView (which can be done in thedump.ai flask web app). 

---

## Note on AI assistance
I used AI tools as a development assistant (syntax help, SwiftUI patterns, debugging suggestions), but I designed and can explain the **architecture and data flow**: Firebase auth state → ID token → authenticated API requests; signed URL request → direct GCS upload; counts → filtered/paginated lists → full note fetch. I also reviewed and integrated the code, tested the main flows, and treated AI output like any other untrusted snippet: something that must compile, run, and match my intended design.

If asked in a demo, I can walk through the main flows and point to the specific files where each step happens.