# Planned Features & Enhancements Roadmap

> **Target Audience**: AI Agents, Flutter Developers, and Backend Engineers.  
> **App**: Shogunify (v1.0.4+3)  
> **Status**: Ready for pre-release implementation  

---

## 1. Executive Summary

This document specifies upcoming features and architectural enhancements for Shogunify prior to release:

1. **Pagination & Infinite Scrolling Optimization**: Limit song lists to an initial 12 items across all pages with automated infinite scrolling as the user reaches the bottom.
2. **"Add to Playlist" Popup UI/UX Overhaul**: Redesign the song options popup to incorporate the shared 4-quadrant mosaic playlist cover and elevate UI polish across screens.
3. **Cross-Page Design Uniformity**: Align typography, modal bottom sheets, dividers, tile heights, and color tokens uniformly across all pages.
4. **Song Tagging System**: Support user-defined hashtags (`#japanese`, `#city-pop`, `#<artist name>`, etc.) with filtering chips and tagging modals.
5. **Artist Auto-Complete & Ghost Text Suggestions**: Intelligent inline completion in the "Add Song" flow that queries registered server artists and displays transparent ghost text completions that can be accepted with one tap.

---

## 2. Feature Specifications

### 2.1 Pagination & Lazy Loading (Max 12 Songs per Page)

#### Objective
Prevent heavy widget trees and unnecessary image loads by capping initial rendering to 12 songs and dynamically loading the next 12 when the user scrolls to the bottom.

#### Implementation Details
- **Affected Views**:
  - `Home` (`lib/pages/home.dart`): Main song feed and filtered results.
  - `Library` (`lib/pages/library.dart`): All songs, liked songs, and playlist songs.
  - `PlaylistDetail` (`lib/pages/playlist_detail.dart`): Playlist song lists.
- **Scroll Detection Pattern**:
  ```dart
  final ScrollController _scrollController = ScrollController();
  int _visibleCount = 12;
  static const int _batchSize = 12;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    // Trigger when user is within 200 pixels of the bottom
    if (_scrollController.position.extentAfter < 200 && _visibleCount < _totalSongs.length) {
      setState(() {
        _visibleCount = (_visibleCount + _batchSize).clamp(0, _totalSongs.length);
      });
    }
  }
  ```
- **UI Indicator**: Display a subtle loading indicator at the list's footer while more items exist.

---

### 2.2 "Add to Playlist" Popup UI Overhaul

#### Objective
Upgrade the "Add to Playlist" modal bottom sheet from a basic list into a rich, branded sheet with dynamic artwork and smooth interactions.

#### Design Requirements
1. **Dynamic Mosaic Artwork**:
   - Replace generic icon fallbacks with the shared 4-quadrant mosaic cover (`_HomePlaylistCover` / `_LibraryPlaylistCover`) using the first 4 tracks in each playlist.
   - For playlists with dedicated covers, render `CachedNetworkImage` with rounded corners (`BorderRadius.circular(10)`).
2. **Visual Consistency**:
   - Background: Dark surface (`Color(0xFF1E1B24)` or `Color(0xFF222222)`).
   - Card shape: Rounded container (`BorderRadius.circular(14)`) with subtle border or highlight.
   - Header: Playlist title, song count badge, and a distinct close button.
   - Active Indicator: If the song is already present in a playlist, show a distinct checkmark icon in accent purple (`Color(0xFF9384D1)`) and prevent duplicate insertion or allow one-tap toggling.
3. **Reusable Shared Component**:
   - Extract the modal into a standalone widget: `lib/widgets/add_to_playlist_sheet.dart` or `lib/controllers/add_to_playlist_dialog.dart` so `Home`, `Library`, and `Player` invoke the identical UI and logic without code duplication.

---

### 2.3 Cross-Page UI & Detail Uniformity

#### Objective
Ensure all micro-interactions, dialogs, drawers, and card layouts adhere to a single unified design system.

#### Consistency Checklist
- **App Drawer & Headers**:
  - Unify header height, logo border radius (`16px`), and subtext (`v1.0.4`) across `Home`, `Settings`, and `Support`.
- **Action Sheets & Context Menus**:
  - Modal bottom sheets must share consistent background (`Color(0xFF1E1B24)`), top handle bar (`width: 48, height: 5, borderRadius: 2.5`), and Kanit typography.
- **Divider Lines & Spacing**:
  - Standardize divider margins and opacity (`Colors.white.withOpacity(0.12)`).
- **Song Item Tile Heights**:
  - Standardize album art size (`48x48` with `BorderRadius.circular(8)`), title/artist padding, and trailing popup button icons.

---

### 2.4 Song Tagging System

#### Objective
Allow users to create, attach, and filter songs by descriptive tags (e.g., `#japanese`, `#city-pop`, `#j-rock`, `#lo-fi`, `#<artist name>`).

#### Data Model
```dart
class SongTag {
  final int id;
  final String name; // e.g. "japanese", "city-pop"

  const SongTag({required this.id, required this.name});

  factory SongTag.fromJson(Map<String, dynamic> json) => SongTag(
    id: json['id'] as int,
    name: json['name'] as String,
  );

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}
```

#### Backend API Requirements
- `GET /api/tags`: Fetch all available tags.
- `GET /api/songs?tag=:tagName`: Fetch songs associated with a tag.
- `POST /api/songs/:songId/tags`: Add one or more tags to a song:
  ```json
  { "tags": ["japanese", "city-pop"] }
  ```
- `DELETE /api/songs/:songId/tags/:tagId`: Remove tag from song.

#### Frontend UI Integration
- **Tag Display**: Render tag chips underneath or next to the song title/artist in both the tracklist and full-screen player (`lib/pages/player.dart`).
- **Tag Editor Modal**: Accessible via the song context menu ("Manage Tags") or directly within the "Add Song" flow (`lib/pages/addsongs.dart`).
- **Home/Library Filter Bar**: Horizontal scrollable chip bar above the song list:
  `[ All ] [ #japanese ] [ #city-pop ] [ #rock ] [ + Add Tag ]`.

---

### 2.5 Artist Auto-Complete & Ghost Text Suggestions

#### Objective
Streamline the "Add Song" experience in `lib/pages/addsongs.dart` by displaying verified artist suggestions with transparent inline ghost text as the user types.

#### Interaction Flow
1. User taps into the **Artist name** text field.
2. User types a prefix (e.g., `bru`).
3. App queries registered artists (either from a pre-fetched set or debounced server endpoint `GET /api/artists/search?q=bru`).
4. If a match is found (`"Bruno Mars"`):
   - The field renders the user's typed text in solid white (`"bru"`).
   - Behind or directly after the typed characters, the remainder of the suggestion (`"no Mars"`) is displayed in semi-transparent ghost text (`color: Colors.white38`).
5. **Acceptance Interaction**:
   - Tapping an inline completion badge/chip or pressing a completion icon (e.g. `Icons.arrow_forward_rounded` or `Icons.done`) instantly replaces the field's text with `"Bruno Mars"`.
   - Alternatively, tapping anywhere on the suggestion accepts the complete string.

#### Backend API Requirement
- `GET /api/artists`: Returns unique artist list registered across the music catalog.
- `POST /api/artists`: Register a new artist name during song import if not already present.

---

### 2.6 Server Album Cover Registration During Song Import

#### Objective
Ensure that when a user selects an existing server album cover in `lib/pages/addsongs.dart` (instead of uploading a local image from their device), the imported song is correctly registered and linked to that chosen album cover on the server.

#### Problem & Requirements
1. **Payload Specification**: When selecting an existing server cover, the client must pass both the full resolved URL (`album_art_url`), the server relative path (`album_art_path`), and aliases (`cover_url`, `existing_album_art`), while setting `use_generated_cover=false`.
2. **Preview & Thumbnail Consistency**: The existing server covers in the 4x3 grid must resolve safely through `ImageUtils.resolveUrl(...)` and render via `CachedNetworkImage` with fallback placeholder handling.
3. **Add to Playlist & Playlist Creation**: Ensure that in both the "Add to Playlist" dialog (`showAddToPlaylistDialog`) and the "Create Playlist" song selection screen (`_SongPage`), album art images are loaded properly with URL resolution and caching.

---

## 3. Implementation Plan & Priority Order

| Step | Feature | Complexity | Core Files Touched |
| :--- | :--- | :--- | :--- |
| **Phase 1** | **Lazy Loading (12 songs/scroll)** | Low | `lib/pages/home.dart`, `lib/pages/library.dart`, `lib/pages/playlist_detail.dart` |
| **Phase 2** | **"Add to Playlist" UI Overhaul & Cover Art** | Medium | `lib/pages/playlists.dart`, `lib/pages/home.dart`, `lib/pages/library.dart` |
| **Phase 3** | **Cross-Page Design Uniformity** | Low-Medium | `lib/pages/settings.dart`, `lib/pages/support.dart`, `lib/pages/player.dart` |
| **Phase 4** | **Artist Auto-Complete / Ghost Text** | Medium | `lib/pages/addsongs.dart`, Backend artist API |
| **Phase 5** | **Song Tagging System** | Medium-High | Backend Tag API, `lib/pages/home.dart`, `lib/pages/addsongs.dart`, `lib/pages/player.dart` |
| **Phase 6** | **Server Album Cover Registration Fix** | Low-Medium | `lib/pages/addsongs.dart`, `lib/pages/playlists.dart` |
