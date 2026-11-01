# Project Overview: Shogunify

> **Target Audience**: AI Agents, Systems Engineers, and Flutter Developers.  
> **Last Updated**: October 2026  
> **App Version**: 1.0.4+3  

---

## 1. Executive Summary

**Shogunify** is a specialized cross-platform music streaming and personal library application built using Flutter. It connects to a custom backend service (`https://music.wannuwatbot.com`) to deliver on-demand music streaming, custom playlist curation, background audio playback with OS media controls, and seamless YouTube audio importing with in-app 15-second audio previewing and custom album art selection.

The application uses an invite-code gated authentication system and implements dark-themed UI components styled with Google's Kanit typography and custom purple/charcoal accents.

---

## 2. Technical Stack & Core Dependencies

| Category | Package / Tool | Version / Spec | Purpose |
| :--- | :--- | :--- | :--- |
| **Framework** | Flutter / Dart SDK | `sdk: ^3.12.2` | Core cross-platform mobile/desktop framework |
| **Audio Core** | `just_audio` | `^0.9.46` | Underlying audio player instance & streams |
| **Background Audio**| `audio_service` | `^0.18.19` | Integrates with Android/iOS media sessions, lockscreen controls, and system notifications |
| **State Management**| `provider` | `^6.1.2` | State propagation across widget tree (`PlayerController`, `AuthController`, `States`) |
| **Secure Storage** | `flutter_secure_storage`| `^11.0.0` | Persisting JWT authentication tokens across app restarts |
| **Networking** | `http`, `http_parser` | `^1.2.0`, `^4.1.2` | REST API communication, multipart file upload |
| **Media & Caching** | `cached_network_image` | `^3.4.1` | Efficient image caching and fallback rendering |
| **Media Picking** | `image_picker` | `^1.1.2` | Selecting custom album art from device storage |
| **Typography** | `google_fonts` | `^8.2.1` | `Kanit` typography throughout the UI |
| **Launcher / Info** | `package_info_plus`, `url_launcher` | `^10.2.1`, `^6.3.2` | App version retrieval & external links |

---

## 3. Directory Structure & File Map

```
shogunify/
├── android/                   # Android native platform code
├── assets/images/             # Static app assets (Icon6.jpg, support.jpeg)
├── ios/                       # iOS native platform code
├── lib/
│   ├── main.dart              # Entry point: AudioService init, MultiProvider, AuthGate, MaterialApp
│   ├── controllers/
│   │   ├── auth_controller.dart  # Auth state, login/register, token verification & secure storage
│   │   ├── provider.dart         # PlayerController (BaseAudioHandler + ChangeNotifier)
│   │   ├── states.dart           # UI toggle states (e.g. secondary shuffle flag)
│   │   ├── image_utils.dart      # URL normalization for relative/protocol-relative cover art URLs
│   │   └── queue_sheet.dart      # Bottom sheet modal UI for active & upcoming playback queue
│   ├── pages/
│   │   ├── login.dart            # Login & Sign-up interface (invite-code validation)
│   │   ├── home.dart             # Main dashboard (search, filters, song grid/list, mini player)
│   │   ├── player.dart           # Full-screen modal player (`PlayPause` widget)
│   │   ├── library.dart          # User library (playlists, liked tracks, custom creations)
│   │   ├── playlists.dart        # Playlist models & PlaylistService API helpers
│   │   ├── playlist_detail.dart  # Detailed playlist view (tracklist, reordering, mosaic cover)
│   │   ├── addsongs.dart         # YouTube importer with 15s preview player & custom art picker
│   │   ├── settings.dart         # App settings, account status, logout trigger
│   │   └── support.dart          # Developer support page with donation QR / instructions
│   └── services/
│       └── music_service.dart    # Song catalog retrieval & stream URL generator
├── markdowns/
│   ├── future_features/       # Roadmap documents & planned feature specifications
│   └── updates/               # Architecture overviews, changelogs, and agent references
└── pubspec.yaml               # Flutter package configuration & asset bindings
```

---

## 4. Architectural Highlights & Key Subsystems

### 4.1 Authentication & Gating (`AuthController` & `AuthGate`)
- **Backend Base URL**: `https://music.wannuwatbot.com`
- **Invite Code**: Built-in default code `WelCoMeTo_ShoGuNiFy`.
  - For **Sign Up**, users must supply a valid invite code to register.
  - For **Log In**, the invite code is provided transparently or required by the server.
- **Session Persistence**: JWT token stored via `FlutterSecureStorage` under key `'auth_token'`.
- **Initialization Lifecycle**: `AuthGate` intercepts app startup:
  1. Checks if token exists in storage.
  2. Verifies token against `GET /api/auth/verify`.
  3. Transitions user to `Home` if valid, or `Login` if expired/missing.

### 4.2 Audio Pipeline & Background Service (`PlayerController`)
- **Dual Architecture**: `PlayerController` extends `BaseAudioHandler` while mixing in `ChangeNotifier`.
- **System Media Integration**:
  - Initialized in `main()` with `AudioService.init()`.
  - Registers Android notification channel: `com.shogunify.audio` ("Shogunify Playback").
  - Publishes `MediaItem` updates (title, artist, album art URI, duration) and `PlaybackState` updates (playing status, buffered position, speed, compact actions).
- **Queue & Playback Capabilities**:
  - Full queue handling (`songQueue`, `currentIndex`, `addToQueue`, `playNextInQueue`, `playFromQueue`).
  - Auto-advance on track completion (`ProcessingState.completed`).
  - Three-state repeat mode: `RepeatMode.off`, `RepeatMode.all` (loops queue), `RepeatMode.one` (loops single song).
  - Shuffle toggle with non-destructive queue recovery (`_unshuffledQueue` maintains original ordering).

### 4.3 YouTube Audio Import Pipeline (`Addsongs`)
- **Supported Link Formats**: Standard `youtube.com/watch?v=...`, `youtu.be/...`, shorts (`/shorts/...`), embeds (`/embed/...`), and live streams.
- **Workflow**:
  1. User pastes a YouTube URL; the client validates and extracts the 11-character video ID.
  2. Pre-import request sent to `POST /api/youtube/preview` which extracts remote video title and a 15-second audio preview stream URL.
  3. In-app preview player (`AudioPlayer`) plays back the 15-second snippet with shake animation feedback on errors.
  4. Cover Art Selection: User can either select an existing cover from the platform library or upload a custom image via `ImagePicker`.
  5. The song is committed to the backend via `POST /api/youtube/import` or `POST /api/songs`.

### 4.4 Dynamic Playlist Cover Mosaics (`_HomePlaylistCover`, `_LibraryPlaylistCover`)
- When a playlist lacks a dedicated single cover image, Shogunify automatically builds a **2x2 4-quadrant mosaic cover** using the album art of the first 4 distinct songs in that playlist.
- If fewer than 4 songs exist, it gracefully falls back to the first available song cover or a generic branded placeholder.

---

## 5. API Reference Summary

All requests targeting authenticated endpoints must include the `Authorization: Bearer <token>` header.

### Authentication
- `POST /api/auth/login`: `{ "username": "...", "invite_code": "..." }`  
  *Returns*: `{ "token": "...", "username": "...", "user_id": ... }`
- `POST /api/auth/register`: `{ "username": "...", "invite_code": "..." }`  
  *Returns*: `{ "token": "...", "username": "...", "user_id": ... }`
- `GET /api/auth/verify`: Verifies active session token.

### Music & Streaming
- `GET /api/songs`: Returns list of all available song records (id, title, artist, filename, album_art_url, duration, etc.).
- `GET /stream/:filename`: Streams raw audio stream for playback.
- `POST /api/youtube/preview`: Validates YouTube URL and provides preview stream.
- `POST /api/youtube/import`: Imports YouTube audio track to user catalog.

### Playlists
- `GET /api/playlists`: Retrieves all playlists belonging to or accessible by user.
- `GET /api/playlists/:id`: Detailed playlist view including the song list.
- `POST /api/playlists`: Creates a new playlist (`{ "name": "...", "description": "..." }`).
- `PUT /api/playlists/:id`: Updates playlist name / metadata.
- `DELETE /api/playlists/:id`: Removes a playlist.
- `POST /api/playlists/:id/songs`: Adds a song to playlist (`{ "song_id": ... }`).
- `DELETE /api/playlists/:id/songs/:songId`: Removes song from playlist.
- `PUT /api/playlists/:id/reorder`: Persists reordered song sequence.

---

## 6. Design System & Styling Conventions

- **Dark Theme Palette**:
  - Backgrounds: `Color.fromARGB(255, 18, 18, 18)`, `Color.fromARGB(255, 25, 25, 25)`, `Color.fromARGB(255, 34, 34, 34)`
  - Primary Purple: `Color.fromARGB(255, 72, 61, 115)` (`0xFF483D73`)
  - Accent / Bright Purple: `Color.fromARGB(255, 147, 132, 209)` (`0xFF9384D1`)
  - Card & Surface: Deep gray rounded cards (`BorderRadius.circular(12)` to `24`)
- **Typography**: `GoogleFonts.kanitTextTheme()` applied across `MaterialApp`.
- **Media Controls**: Mini player widget fixed at bottom above navigation, swipe-down dismissible full-screen player with drag indicators.

---

## 7. Instructions for Future AI Agents

1. **Safety & Rules**:
   - Always run `pwd` and `ls` before build or dependency operations.
   - Do not delete or mutate `.git/`, `.env*`, or root configuration files without explicit user approval.
   - Use lowercase naming with `-` or `_` for new files and directories.
2. **Audio Architecture**:
   - When modifying playback logic, always update both `PlayerController`'s internal state AND the `AudioService` `playbackState` / `mediaItem` broadcasts to ensure Android/iOS system lockscreens remain in sync.
3. **URL Handling**:
   - Always route album art paths through `ImageUtils.resolveUrl(...)` to handle relative, scheme-less, and absolute URLs reliably.
