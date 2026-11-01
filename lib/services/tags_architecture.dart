// tags_architecture.dart
// -----------------------------------------------------------------------------
// SHOGUNIFY - SONG TAGS ARCHITECTURE & IMPLEMENTATION GUIDE
// -----------------------------------------------------------------------------
//
// This file outlines how the song tagging system is designed to work in future
// updates when full server-side tag persistence is deployed.
//
// 1. TAG SPECIFICATION & VALIDATION RULES:
//    - Every tag MUST strictly start with a '#' prefix.
//    - Tags must consist of a continuous string without spaces.
//    - Permitted characters: letters (multilingual supported), digits,
//      underscores ('_'), and hyphens ('-').
//    - Examples:
//        ✓ VALID:   "#ThaiSong", "#japanese", "#city-pop", "#lo_fi", "#Rock90s"
//        ✗ INVALID: "#thai song" (contains space)
//        ✗ INVALID: "ThaiSong"   (missing leading '#')
//        ✗ INVALID: "#song@pop"  (contains illegal character '@')
//
// 2. WHERE TAGS ARE CREATED:
//    - Users can define tags when importing a song via the Add Song screen
//      (lib/pages/addsongs.dart).
//    - The tag input field is positioned directly beneath the Album Cover section.
//    - The input validates real-time against RegExp(r'^#[A-Za-z0-9_\-]+$').
//
// 3. WHERE TAGS ARE DISPLAYED:
//    - As requested, tags are strictly displayed ONLY on the full-screen Player
//      page (lib/pages/player.dart) directly below the artist name.
//    - Tags are NOT rendered on Home or Library tracklists to maintain
//      a minimal, uncluttered catalog aesthetic.
//
// 4. FUTURE BACKEND INTEGRATION:
//    When the backend at https://music.wannuwatbot.com introduces tag endpoints:
//    - POST /api/songs (include 'tags': ['#ThaiSong', '#city-pop'])
//    - GET /api/songs (each song payload returns 'tags': List<String>)
//    - PUT /api/songs/:id/tags (update tags on an existing song)
// -----------------------------------------------------------------------------

import 'package:flutter/foundation.dart';

class TagValidator {
  static final RegExp tagRegExp = RegExp(r'^#[A-Za-z0-9_\-]+$');

  /// Validates if a single raw tag string complies with the rule.
  static bool isValid(String raw) {
    final trimmed = raw.trim();
    return tagRegExp.hasMatch(trimmed);
  }

  /// Normalizes and cleans a tag string.
  static String? normalize(String raw) {
    var tag = raw.trim();
    if (!tag.startsWith('#')) {
      tag = '#$tag';
    }
    return isValid(tag) ? tag : null;
  }
}

/// Abstract representation of how tags will be managed and cached locally.
class FutureTagModel {
  final int songId;
  final List<String> tags;

  const FutureTagModel({required this.songId, required this.tags});

  Map<String, dynamic> toJson() => {'song_id': songId, 'tags': tags};

  factory FutureTagModel.fromJson(Map<String, dynamic> json) => FutureTagModel(
    songId: json['song_id'] as int,
    tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
  );
}
