import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shogunify/controllers/image_utils.dart';

class PlaylistMosaicCover extends StatelessWidget {
  final String? imageUrl;
  final List<Map<String, dynamic>> songs;
  final double size;

  const PlaylistMosaicCover({
    super.key,
    required this.imageUrl,
    required this.songs,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final mosaicUrls = songs
        .map((song) => song['album_art_url']?.toString().trim())
        .whereType<String>()
        .where((url) => url.isNotEmpty)
        .map(ImageUtils.resolveUrl)
        .whereType<String>()
        .toSet()
        .take(4)
        .toList();
    final resolvedImageUrl = ImageUtils.resolveUrl(imageUrl);

    Widget content;
    if (mosaicUrls.length == 4) {
      content = GridView.count(
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 0,
        mainAxisSpacing: 0,
        children: mosaicUrls
            .map(
              (url) => CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, _) => _fallback(),
                errorWidget: (_, _, _) => _fallback(),
              ),
            )
            .toList(),
      );
    } else if (resolvedImageUrl != null) {
      content = CachedNetworkImage(
        imageUrl: resolvedImageUrl,
        fit: BoxFit.cover,
        placeholder: (_, _) => _fallback(),
        errorWidget: (_, _, _) => _fallback(),
      );
    } else if (mosaicUrls.isNotEmpty) {
      content = CachedNetworkImage(
        imageUrl: mosaicUrls.first,
        fit: BoxFit.cover,
        placeholder: (_, _) => _fallback(),
        errorWidget: (_, _, _) => _fallback(),
      );
    } else {
      content = _fallback();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(width: size, height: size, child: content),
    );
  }

  Widget _fallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF382F52), Color(0xFF211A31)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.music_note_rounded, color: Colors.white70, size: 22),
      ),
    );
  }
}

Future<void> showAddToPlaylistDialog({
  required BuildContext context,
  required String token,
  required Map<String, dynamic> song,
  VoidCallback? onSongAdded,
}) async {
  final playlists = await PlaylistService.fetchPlaylists(token);
  if (!context.mounted) return;

  final songTitle = song['title']?.toString() ?? 'Selected song';
  final songArtist = song['artist']?.toString();

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: const Color(0xFF211E28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add to Playlist',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white54,
                    ),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Builder(
                      builder: (_) {
                        final songArtRaw = song['album_art_url']?.toString() ??
                            song['cover_art_url']?.toString();
                        final songArtUrl = ImageUtils.resolveUrl(songArtRaw);
                        if (songArtUrl != null && songArtUrl.isNotEmpty) {
                          return CachedNetworkImage(
                            imageUrl: songArtUrl,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              width: 44,
                              height: 44,
                              color: const Color(0xFF2D2A37),
                              child: const Icon(Icons.music_note, color: Colors.white54, size: 20),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              width: 44,
                              height: 44,
                              color: const Color(0xFF2D2A37),
                              child: const Icon(Icons.music_note, color: Colors.white54, size: 20),
                            ),
                          );
                        }
                        return Container(
                          width: 44,
                          height: 44,
                          color: const Color(0xFF2D2A37),
                          child: const Icon(Icons.music_note, color: Colors.white54, size: 20),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          songTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (songArtist != null)
                          Text(
                            songArtist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF9384D1),
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SizedBox(
                width: double.maxFinite,
                child: playlists.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'No playlists found.',
                            style: TextStyle(color: Colors.white60),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: playlists.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, index) {
                          final playlist = playlists[index];
                          final songId =
                              (song['id'] ?? song['song_id']) as num?;
                          final songFilename = song['filename']?.toString();
                          final alreadyAdded = playlist.songs.any((item) {
                            final iId = (item['id'] ?? item['song_id']) as num?;
                            final iFilename = item['filename']?.toString();
                            return (songId != null &&
                                    iId != null &&
                                    songId == iId) ||
                                (songFilename != null &&
                                    iFilename != null &&
                                    songFilename == iFilename);
                          });
                          final isFavorites =
                              playlist.name.trim().toLowerCase() == 'favorites';
                          final count = playlist.songs.length;

                          return Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF2D2A37),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.06),
                              ),
                            ),
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              leading: PlaylistMosaicCover(
                                imageUrl: playlist.coverArtUrl,
                                songs: playlist.songs,
                                size: 46,
                              ),
                              title: Text(
                                playlist.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Row(
                                children: [
                                  if (isFavorites) ...[
                                    const Icon(
                                      Icons.favorite,
                                      size: 13,
                                      color: Color(0xFFE57373),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    '$count ${count == 1 ? 'song' : 'songs'}',
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: alreadyAdded
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF9384D1,
                                        ).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.check_rounded,
                                            size: 15,
                                            color: Color(0xFF9384D1),
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Added',
                                            style: TextStyle(
                                              color: Color(0xFF9384D1),
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : const Icon(
                                      Icons.add_circle_outline_rounded,
                                      color: Color(0xFF9384D1),
                                      size: 26,
                                    ),
                              onTap: () async {
                                if (alreadyAdded) {
                                  Navigator.of(dialogContext).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Already in ${playlist.name}',
                                      ),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                  return;
                                }

                                final sId = songId?.toInt();
                                if (sId == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Song ID not found'),
                                    ),
                                  );
                                  return;
                                }

                                try {
                                  await PlaylistService.addSong(
                                    playlistId: playlist.id,
                                    songId: sId,
                                    token: token,
                                  );
                                  if (!context.mounted) return;
                                  Navigator.of(dialogContext).pop();
                                  onSongAdded?.call();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Added to ${playlist.name}!',
                                      ),
                                      backgroundColor: const Color(0xFF483D73),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              },
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class Playlist {
  final int id;
  final String name;
  final String? description;
  final String? coverArtUrl;
  final int songCount;
  final List<Map<String, dynamic>> songs;

  const Playlist({
    required this.id,
    required this.name,
    this.description,
    this.coverArtUrl,
    this.songCount = 0,
    this.songs = const [],
  });

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
    id: (json['id'] as num).toInt(),
    name: (json['name'] ?? 'Untitled playlist').toString(),
    description: json['description']?.toString(),
    coverArtUrl: json['cover_art_url']?.toString(),
    songCount:
        (json['song_count'] as num?)?.toInt() ??
        ((json['songs'] as List?)?.length ?? 0),
    songs:
        (json['songs'] as List?)
            ?.whereType<Map>()
            .map((song) => Map<String, dynamic>.from(song))
            .toList() ??
        const [],
  );
}

class PlaylistService {
  static const String baseUrl = 'https://music.wannuwatbot.com';

  static Map<String, String> _headers(String token) => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  static Future<List<Playlist>> fetchPlaylists(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/playlists'),
      headers: _headers(token),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch playlists (${response.statusCode})');
    }
    final data = jsonDecode(response.body) as List;
    return data
        .whereType<Map>()
        .map((item) => Playlist.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  static Future<Playlist> fetchPlaylist(int id, String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/playlists/$id'),
      headers: _headers(token),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch playlist (${response.statusCode})');
    }
    return Playlist.fromJson(jsonDecode(response.body));
  }

  static Future<Playlist> createPlaylist({
    required String name,
    required String token,
    String? description,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/playlists'),
      headers: _headers(token),
      body: jsonEncode({
        'name': name,
        if (description?.trim().isNotEmpty == true)
          'description': description!.trim(),
      }),
    );
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception('Failed to create playlist (${response.statusCode})');
    }
    return Playlist.fromJson(jsonDecode(response.body));
  }

  static Future<void> addSong({
    required int playlistId,
    required int songId,
    required String token,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/playlists/$playlistId/songs'),
      headers: _headers(token),
      body: jsonEncode({'song_id': songId}),
    );
    if (response.statusCode != 201 &&
        response.statusCode != 200 &&
        response.statusCode != 409) {
      throw Exception('Failed to add song (${response.statusCode})');
    }
  }

  static Future<void> removeSong({
    required int playlistId,
    required int songId,
    required String token,
  }) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/playlists/$playlistId/songs/$songId'),
      headers: _headers(token),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to remove song (${response.statusCode})');
    }
  }

  static Future<void> deletePlaylist({
    required int playlistId,
    required String token,
  }) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/playlists/$playlistId'),
      headers: _headers(token),
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete playlist (${response.statusCode})');
    }
  }
}

class PlaylistCover extends StatelessWidget {
  final String title;
  final double size;
  final bool compact;
  final String? imageUrl;
  final File? imageFile;

  const PlaylistCover({
    super.key,
    required this.title,
    this.size = 168,
    this.compact = false,
    this.imageUrl,
    this.imageFile,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = ImageUtils.resolveUrl(imageUrl);
    final image = imageFile != null
        ? Image.file(imageFile!, fit: BoxFit.cover)
        : (resolvedUrl != null && resolvedUrl.isNotEmpty)
            ? CachedNetworkImage(
                imageUrl: resolvedUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              )
            : null;

    return Container(
      width: size,
      height: size,
      padding: image == null
          ? EdgeInsets.all(compact ? 14 : 18)
          : EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 16 : 24),
        gradient: const RadialGradient(
          center: Alignment(-0.65, -0.75),
          radius: 1.35,
          colors: [
            Color(0xFFB99CFF),
            Color(0xFF7C4DFF),
            Color(0xFF35136B),
            Color(0xFF120B20),
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x663D1A78),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child:
          image ??
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.favorite, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Shogunify',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 22 : 30,
                  fontWeight: FontWeight.bold,
                  height: .95,
                ),
              ),
              const Text(
                'Mix',
                style: TextStyle(color: Colors.white, fontSize: 25, height: 1),
              ),
            ],
          ),
    );
  }
}

Future<Playlist?> showCreatePlaylistDialog(BuildContext context, String token) {
  return showModalBottomSheet<Playlist>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CreatePlaylistSheet(token: token),
  );
}

class _CreatePlaylistSheet extends StatefulWidget {
  final String token;
  const _CreatePlaylistSheet({required this.token});

  @override
  State<_CreatePlaylistSheet> createState() => _CreatePlaylistSheetState();
}

class _CreatePlaylistSheetState extends State<_CreatePlaylistSheet> {
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  final Set<int> _selected = <int>{};
  late final Future<List<Map<String, dynamic>>> _songsFuture;
  List<Map<String, dynamic>> _loadedSongs = [];
  String _search = '';
  bool _creating = false;

  static const _purple = Color(0xFF9B6DFF);
  static const _black = Color(0xFF0B0A0F);
  static const _card = Color(0xFF211B2B);

  @override
  void initState() {
    super.initState();
    _songsFuture = _loadSongsSafely(widget.token);
    _songsFuture.then((songs) {
      if (mounted) setState(() => _loadedSongs = songs);
    });
    _searchController.addListener(
      () =>
          setState(() => _search = _searchController.text.trim().toLowerCase()),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String? _selectedPreviewArtUrl() {
    for (final id in _selected) {
      final match = _loadedSongs.firstWhere(
        (song) => (song['id'] as num?)?.toInt() == id,
        orElse: () => const {},
      );
      final art =
          match['cover_art_url']?.toString() ??
          match['album_art_url']?.toString();
      if (art != null && art.isNotEmpty) return art;
    }
    return null;
  }

  Future<void> _createPlaylist() async {
    if (_creating) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a playlist name')));
      return;
    }

    setState(() => _creating = true);
    try {
      final playlist = await PlaylistService.createPlaylist(
        name: name,
        token: widget.token,
      );
      for (final songId in _selected) {
        await PlaylistService.addSong(
          playlistId: playlist.id,
          songId: songId,
          token: widget.token,
        );
      }
      if (mounted) Navigator.of(context).pop(playlist);
    } catch (error) {
      if (!mounted) return;
      setState(() => _creating = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  InputDecoration _inputDecoration(String hint, {Widget? prefixIcon}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        prefixIcon: prefixIcon,
        filled: true,
        fillColor: const Color(0xFF17131D),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF362A4D)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _purple, width: 1.4),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * .92,
        padding: EdgeInsets.only(bottom: bottom),
        decoration: const BoxDecoration(
          color: _black,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _creating ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                  const Expanded(
                    child: Text(
                      'Add to this playlist',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: _purple,
                    decoration: _inputDecoration('Playlist name'),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      PlaylistCover(
                        title: _nameController.text.isEmpty
                            ? 'New'
                            : _nameController.text,
                        size: 88,
                        compact: true,
                        imageUrl: _selectedPreviewArtUrl(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selected.isEmpty
                              ? 'Cover art is taken from the songs you add.'
                              : 'Cover preview from your selected songs.',
                          style: const TextStyle(color: Colors.white60),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: _purple,
                    decoration: _inputDecoration(
                      'Search every song',
                      prefixIcon: const Icon(Icons.search, color: _purple),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _songsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(30),
                          child: CircularProgressIndicator(color: _purple),
                        ),
                      );
                    final songs = (snapshot.data ?? []).where((song) {
                      if (_search.isEmpty) return true;
                      final text =
                          '${song['title'] ?? ''} ${song['artist'] ?? ''}'
                              .toLowerCase();
                      return text.contains(_search);
                    }).toList();
                    if (songs.isEmpty)
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No songs found.',
                          style: TextStyle(color: Colors.white60),
                        ),
                      );
                    return _SongPage(
                      songs: songs,
                      selected: _selected,
                      disabled: _creating,
                      onToggle: (id) => setState(
                        () => _selected.contains(id)
                            ? _selected.remove(id)
                            : _selected.add(id),
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
              child: Row(
                children: [
                  Text(
                    '${_selected.length} selected',
                    style: const TextStyle(color: Colors.white60),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _creating ? null : () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _creating ? null : _createPlaylist,
                    style: FilledButton.styleFrom(
                      backgroundColor: _purple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _creating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Create'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SongPage extends StatelessWidget {
  final List<Map<String, dynamic>> songs;
  final Set<int> selected;
  final bool disabled;
  final ValueChanged<int> onToggle;
  const _SongPage({
    required this.songs,
    required this.selected,
    required this.disabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF211B2B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF3A2B50)),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 10),
        itemCount: songs.length + 1,
        itemBuilder: (_, index) {
          if (index == 0)
            return const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Text(
                'Every song',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            );
          final song = songs[index - 1];
          final id = (song['id'] as num?)?.toInt();
          if (id == null) return const SizedBox.shrink();
          final isSelected = selected.contains(id);
          final art =
              song['cover_art_url']?.toString() ??
              song['album_art_url']?.toString();
          final resolvedArt = ImageUtils.resolveUrl(art);
          return ListTile(
            onTap: disabled ? null : () => onToggle(id),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 2,
            ),
            leading: Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: (resolvedArt != null && resolvedArt.isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: resolvedArt,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _artPlaceholder(),
                          errorWidget: (_, __, ___) => _artPlaceholder(),
                        )
                      : _artPlaceholder(),
                ),
                const Icon(Icons.play_arrow, color: Colors.white, size: 20),
              ],
            ),
            title: Text(
              '${song['title'] ?? 'Unknown song'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '${song['artist'] ?? 'Unknown artist'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white60),
            ),
            trailing: IconButton(
              onPressed: disabled ? null : () => onToggle(id),
              icon: Icon(
                isSelected ? Icons.check_circle : Icons.add_circle_outline,
                color: isSelected ? const Color(0xFFC4A7FF) : Colors.white70,
                size: 28,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _artPlaceholder() => Container(
    width: 52,
    height: 52,
    color: const Color(0xFF37284B),
    child: const Icon(Icons.music_note, color: Color(0xFFC4A7FF)),
  );
}

Future<List<Map<String, dynamic>>> _loadSongsSafely(String token) async {
  try {
    final response = await http.get(
      Uri.parse('${PlaylistService.baseUrl}/api/songs'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) return [];
    final decoded = jsonDecode(response.body);
    final list = decoded is Map ? decoded['songs'] : decoded;
    return (list as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  } catch (_) {
    return [];
  }
}

// import 'dart:convert';
// import 'dart:io';

// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:image_picker/image_picker.dart';

// class Playlist {
//   final int id;
//   final String name;
//   final String? description;
//   final String? coverArtUrl;
//   final int songCount;
//   final List<Map<String, dynamic>> songs;

//   const Playlist({
//     required this.id,
//     required this.name,
//     this.description,
//     this.coverArtUrl,
//     this.songCount = 0,
//     this.songs = const [],
//   });

//   factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
//     id: (json['id'] as num).toInt(),
//     name: (json['name'] ?? 'Untitled playlist').toString(),
//     description: json['description']?.toString(),
//     coverArtUrl: json['cover_art_url']?.toString(),
//     songCount:
//         (json['song_count'] as num?)?.toInt() ??
//         ((json['songs'] as List?)?.length ?? 0),
//     songs:
//         (json['songs'] as List?)
//             ?.whereType<Map>()
//             .map((song) => Map<String, dynamic>.from(song))
//             .toList() ??
//         const [],
//   );
// }

// class PlaylistService {
//   static const String baseUrl = 'https://music.wannuwatbot.com';

//   static Map<String, String> _headers(String token) => {
//     'Authorization': 'Bearer $token',
//     'Content-Type': 'application/json',
//   };

//   static Future<List<Playlist>> fetchPlaylists(String token) async {
//     final response = await http.get(
//       Uri.parse('$baseUrl/api/playlists'),
//       headers: _headers(token),
//     );
//     if (response.statusCode != 200) {
//       throw Exception('Failed to fetch playlists (${response.statusCode})');
//     }
//     final data = jsonDecode(response.body) as List;
//     return data
//         .whereType<Map>()
//         .map((item) => Playlist.fromJson(Map<String, dynamic>.from(item)))
//         .toList();
//   }

//   static Future<Playlist> fetchPlaylist(int id, String token) async {
//     final response = await http.get(
//       Uri.parse('$baseUrl/api/playlists/$id'),
//       headers: _headers(token),
//     );
//     if (response.statusCode != 200) {
//       throw Exception('Failed to fetch playlist (${response.statusCode})');
//     }
//     return Playlist.fromJson(jsonDecode(response.body));
//   }

//   static Future<Playlist> createPlaylist({
//     required String name,
//     required String token,
//     String? description,
//     File? coverImage,
//   }) async {
//     // A multipart request is used when a cover image is selected. This keeps
//     // the text fields and the local image in one request.
//     if (coverImage != null) {
//       final request =
//           http.MultipartRequest('POST', Uri.parse('$baseUrl/api/playlists'))
//             ..headers['Authorization'] = 'Bearer $token'
//             ..fields['name'] = name;

//       if (description?.trim().isNotEmpty == true) {
//         request.fields['description'] = description!.trim();
//       }
//       request.files.add(
//         await http.MultipartFile.fromPath('cover_art', coverImage.path),
//       );

//       final streamed = await request.send();
//       final responseBody = await streamed.stream.bytesToString();
//       if (streamed.statusCode != 201 && streamed.statusCode != 200) {
//         throw Exception(
//           'Failed to create playlist (${streamed.statusCode}): $responseBody',
//         );
//       }
//       return Playlist.fromJson(jsonDecode(responseBody));
//     }

//     final response = await http.post(
//       Uri.parse('$baseUrl/api/playlists'),
//       headers: _headers(token),
//       body: jsonEncode({
//         'name': name,
//         if (description?.trim().isNotEmpty == true)
//           'description': description!.trim(),
//       }),
//     );
//     if (response.statusCode != 201 && response.statusCode != 200) {
//       throw Exception('Failed to create playlist (${response.statusCode})');
//     }
//     return Playlist.fromJson(jsonDecode(response.body));
//   }

//   static Future<void> addSong({
//     required int playlistId,
//     required int songId,
//     required String token,
//   }) async {
//     final response = await http.post(
//       Uri.parse('$baseUrl/api/playlists/$playlistId/songs'),
//       headers: _headers(token),
//       body: jsonEncode({'song_id': songId}),
//     );
//     if (response.statusCode != 201 &&
//         response.statusCode != 200 &&
//         response.statusCode != 409) {
//       throw Exception('Failed to add song (${response.statusCode})');
//     }
//   }

//   static Future<void> removeSong({
//     required int playlistId,
//     required int songId,
//     required String token,
//   }) async {
//     final response = await http.delete(
//       Uri.parse('$baseUrl/api/playlists/$playlistId/songs/$songId'),
//       headers: _headers(token),
//     );
//     if (response.statusCode != 200) {
//       throw Exception('Failed to remove song (${response.statusCode})');
//     }
//   }

//   static Future<void> deletePlaylist({
//     required int playlistId,
//     required String token,
//   }) async {
//     final response = await http.delete(
//       Uri.parse('$baseUrl/api/playlists/$playlistId'),
//       headers: _headers(token),
//     );
//     if (response.statusCode != 200 && response.statusCode != 204) {
//       throw Exception('Failed to delete playlist (${response.statusCode})');
//     }
//   }
// }

// class PlaylistCover extends StatelessWidget {
//   final String title;
//   final double size;
//   final bool compact;
//   final String? imageUrl;
//   final File? imageFile;

//   const PlaylistCover({
//     super.key,
//     required this.title,
//     this.size = 168,
//     this.compact = false,
//     this.imageUrl,
//     this.imageFile,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final image = imageFile != null
//         ? Image.file(imageFile!, fit: BoxFit.cover)
//         : imageUrl?.isNotEmpty == true
//         ? Image.network(imageUrl!, fit: BoxFit.cover)
//         : null;

//     return Container(
//       width: size,
//       height: size,
//       padding: image == null
//           ? EdgeInsets.all(compact ? 14 : 18)
//           : EdgeInsets.zero,
//       clipBehavior: Clip.antiAlias,
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(compact ? 16 : 24),
//         gradient: const RadialGradient(
//           center: Alignment(-0.65, -0.75),
//           radius: 1.35,
//           colors: [
//             Color(0xFFB99CFF),
//             Color(0xFF7C4DFF),
//             Color(0xFF35136B),
//             Color(0xFF120B20),
//           ],
//         ),
//         boxShadow: const [
//           BoxShadow(
//             color: Color(0x663D1A78),
//             blurRadius: 14,
//             offset: Offset(0, 8),
//           ),
//         ],
//       ),
//       child:
//           image ??
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Row(
//                 children: [
//                   Icon(Icons.favorite, color: Colors.white),
//                   SizedBox(width: 6),
//                   Text(
//                     'Shogunify',
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ],
//               ),
//               const Spacer(),
//               Text(
//                 title,
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: compact ? 22 : 30,
//                   fontWeight: FontWeight.bold,
//                   height: .95,
//                 ),
//               ),
//               const Text(
//                 'Mix',
//                 style: TextStyle(color: Colors.white, fontSize: 25, height: 1),
//               ),
//             ],
//           ),
//     );
//   }
// }

// class _CreatePlaylistSheet extends StatefulWidget {
//   final String token;
//   const _CreatePlaylistSheet({required this.token});

//   @override
//   State<_CreatePlaylistSheet> createState() => _CreatePlaylistSheetState();
// }

// class _CreatePlaylistSheetState extends State<_CreatePlaylistSheet> {
//   final _nameController = TextEditingController();
//   final _descriptionController = TextEditingController();
//   final _searchController = TextEditingController();
//   final _imagePicker = ImagePicker();
//   final Set<int> _selected = <int>{};
//   late final Future<List<Map<String, dynamic>>> _songsFuture;
//   final _pageController = PageController();
//   File? _pickedCover;
//   String _search = '';
//   int _page = 0;
//   bool _creating = false;

//   static const _purple = Color(0xFF9B6DFF);
//   static const _purpleBright = Color(0xFFC4A7FF);
//   static const _black = Color(0xFF0B0A0F);
//   static const _card = Color(0xFF211B2B);

//   @override
//   void initState() {
//     super.initState();
//     _songsFuture = _loadSongsSafely(widget.token);
//     _searchController.addListener(
//       () =>
//           setState(() => _search = _searchController.text.trim().toLowerCase()),
//     );
//   }

//   @override
//   void dispose() {
//     _nameController.dispose();
//     _descriptionController.dispose();
//     _searchController.dispose();
//     _pageController.dispose();
//     super.dispose();
//   }

//   Future<void> _pickCover(ImageSource source) async {
//     final picked = await _imagePicker.pickImage(
//       source: source,
//       imageQuality: 90,
//       maxWidth: 1600,
//       maxHeight: 1600,
//     );
//     if (picked != null && mounted)
//       setState(() => _pickedCover = File(picked.path));
//   }

//   Future<void> _createPlaylist() async {
//     if (_creating) return;
//     final name = _nameController.text.trim();
//     if (name.isEmpty) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text('Enter a playlist name')));
//       return;
//     }

//     setState(() => _creating = true);
//     try {
//       final playlist = await PlaylistService.createPlaylist(
//         name: name,
//         description: _descriptionController.text.trim(),
//         token: widget.token,
//         coverImage: _pickedCover,
//       );
//       for (final songId in _selected) {
//         await PlaylistService.addSong(
//           playlistId: playlist.id,
//           songId: songId,
//           token: widget.token,
//         );
//       }
//       if (mounted) Navigator.of(context).pop(playlist);
//     } catch (error) {
//       if (!mounted) return;
//       setState(() => _creating = false);
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text('$error')));
//     }
//   }

//   InputDecoration _inputDecoration(String hint, {Widget? prefixIcon}) =>
//       InputDecoration(
//         hintText: hint,
//         hintStyle: const TextStyle(color: Colors.white54),
//         prefixIcon: prefixIcon,
//         filled: true,
//         fillColor: const Color(0xFF17131D),
//         contentPadding: const EdgeInsets.symmetric(
//           horizontal: 16,
//           vertical: 14,
//         ),
//         enabledBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(14),
//           borderSide: const BorderSide(color: Color(0xFF362A4D)),
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(14),
//           borderSide: const BorderSide(color: _purple, width: 1.4),
//         ),
//       );

//   List<List<Map<String, dynamic>>> _pages(List<Map<String, dynamic>> songs) {
//     const pageSize = 8;
//     return [
//       for (var i = 0; i < songs.length; i += pageSize)
//         songs.sublist(
//           i,
//           i + pageSize < songs.length ? i + pageSize : songs.length,
//         ),
//     ];
//   }

//   @override
//   Widget build(BuildContext context) {
//     final bottom = MediaQuery.of(context).viewInsets.bottom;
//     return SafeArea(
//       child: Container(
//         height: MediaQuery.of(context).size.height * .92,
//         padding: EdgeInsets.only(bottom: bottom),
//         decoration: const BoxDecoration(
//           color: _black,
//           borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
//         ),
//         child: Column(
//           children: [
//             Padding(
//               padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
//               child: Row(
//                 children: [
//                   IconButton(
//                     onPressed: _creating ? null : () => Navigator.pop(context),
//                     icon: const Icon(Icons.close, color: Colors.white70),
//                   ),
//                   const Expanded(
//                     child: Text(
//                       'Add to this playlist',
//                       textAlign: TextAlign.center,
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 18,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                   const SizedBox(width: 48),
//                 ],
//               ),
//             ),
//             Padding(
//               padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   TextField(
//                     controller: _nameController,
//                     style: const TextStyle(color: Colors.white),
//                     cursorColor: _purple,
//                     decoration: _inputDecoration('Playlist name'),
//                   ),
//                   const SizedBox(height: 10),
//                   TextField(
//                     controller: _descriptionController,
//                     style: const TextStyle(color: Colors.white),
//                     cursorColor: _purple,
//                     decoration: _inputDecoration('Description (optional)'),
//                   ),
//                   const SizedBox(height: 14),
//                   Row(
//                     children: [
//                       PlaylistCover(
//                         title: _nameController.text.isEmpty
//                             ? 'New'
//                             : _nameController.text,
//                         size: 88,
//                         compact: true,
//                         imageFile: _pickedCover,
//                       ),
//                       const SizedBox(width: 12),
//                       Expanded(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             const Text(
//                               'Playlist image',
//                               style: TextStyle(
//                                 color: Colors.white,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                             const SizedBox(height: 8),
//                             Wrap(
//                               spacing: 8,
//                               children: [
//                                 OutlinedButton.icon(
//                                   onPressed: _creating
//                                       ? null
//                                       : () => _pickCover(ImageSource.gallery),
//                                   icon: const Icon(
//                                     Icons.photo_library_outlined,
//                                   ),
//                                   label: const Text('Gallery'),
//                                   style: OutlinedButton.styleFrom(
//                                     foregroundColor: _purpleBright,
//                                     side: const BorderSide(color: _purple),
//                                   ),
//                                 ),
//                                 OutlinedButton.icon(
//                                   onPressed: _creating
//                                       ? null
//                                       : () => _pickCover(ImageSource.camera),
//                                   icon: const Icon(Icons.camera_alt_outlined),
//                                   label: const Text('Camera'),
//                                   style: OutlinedButton.styleFrom(
//                                     foregroundColor: _purpleBright,
//                                     side: const BorderSide(color: _purple),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 20),
//                   TextField(
//                     controller: _searchController,
//                     style: const TextStyle(color: Colors.white),
//                     cursorColor: _purple,
//                     decoration: _inputDecoration(
//                       'Search every song',
//                       prefixIcon: const Icon(Icons.search, color: _purple),
//                     ),
//                   ),
//                   const SizedBox(height: 10),
//                 ],
//               ),
//             ),
//             Expanded(
//               child: Padding(
//                 padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
//                 child: FutureBuilder<List<Map<String, dynamic>>>(
//                   future: _songsFuture,
//                   builder: (context, snapshot) {
//                     if (snapshot.connectionState == ConnectionState.waiting)
//                       return const Center(
//                         child: Padding(
//                           padding: EdgeInsets.all(30),
//                           child: CircularProgressIndicator(color: _purple),
//                         ),
//                       );
//                     final songs = (snapshot.data ?? []).where((song) {
//                       if (_search.isEmpty) return true;
//                       final text =
//                           '${song['title'] ?? ''} ${song['artist'] ?? ''}'
//                               .toLowerCase();
//                       return text.contains(_search);
//                     }).toList();
//                     final pages = _pages(songs);
//                     if (pages.isEmpty)
//                       return const Padding(
//                         padding: EdgeInsets.all(24),
//                         child: Text(
//                           'No songs found.',
//                           style: TextStyle(color: Colors.white60),
//                         ),
//                       );
//                     return Column(
//                       children: [
//                         Expanded(
//                           child: PageView.builder(
//                             controller: _pageController,
//                             onPageChanged: (value) =>
//                                 setState(() => _page = value),
//                             itemCount: pages.length,
//                             itemBuilder: (_, index) => _SongPage(
//                               songs: pages[index],
//                               selected: _selected,
//                               disabled: _creating,
//                               onToggle: (id) => setState(
//                                 () => _selected.contains(id)
//                                     ? _selected.remove(id)
//                                     : _selected.add(id),
//                               ),
//                             ),
//                           ),
//                         ),
//                         const SizedBox(height: 8),
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             for (var i = 0; i < pages.length; i++)
//                               AnimatedContainer(
//                                 duration: const Duration(milliseconds: 200),
//                                 margin: const EdgeInsets.symmetric(
//                                   horizontal: 3,
//                                 ),
//                                 width: i == _page ? 22 : 7,
//                                 height: 7,
//                                 decoration: BoxDecoration(
//                                   color: i == _page
//                                       ? _purpleBright
//                                       : Colors.white24,
//                                   borderRadius: BorderRadius.circular(8),
//                                 ),
//                               ),
//                           ],
//                         ),
//                       ],
//                     );
//                   },
//                 ),
//               ),
//             ),
//             Padding(
//               padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
//               child: Row(
//                 children: [
//                   Text(
//                     '${_selected.length} selected',
//                     style: const TextStyle(color: Colors.white60),
//                   ),
//                   const Spacer(),
//                   TextButton(
//                     onPressed: _creating ? null : () => Navigator.pop(context),
//                     child: const Text(
//                       'Cancel',
//                       style: TextStyle(color: Colors.white70),
//                     ),
//                   ),
//                   const SizedBox(width: 8),
//                   FilledButton(
//                     onPressed: _creating ? null : _createPlaylist,
//                     style: FilledButton.styleFrom(
//                       backgroundColor: _purple,
//                       foregroundColor: Colors.white,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                     ),
//                     child: _creating
//                         ? const SizedBox(
//                             width: 18,
//                             height: 18,
//                             child: CircularProgressIndicator(
//                               strokeWidth: 2,
//                               color: Colors.white,
//                             ),
//                           )
//                         : const Text('Create'),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _SongPage extends StatelessWidget {
//   final List<Map<String, dynamic>> songs;
//   final Set<int> selected;
//   final bool disabled;
//   final ValueChanged<int> onToggle;
//   const _SongPage({
//     required this.songs,
//     required this.selected,
//     required this.disabled,
//     required this.onToggle,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: BoxDecoration(
//         color: const Color(0xFF211B2B),
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(color: const Color(0xFF3A2B50)),
//       ),
//       child: ListView.builder(
//         padding: const EdgeInsets.symmetric(vertical: 10),
//         itemCount: songs.length + 1,
//         itemBuilder: (_, index) {
//           if (index == 0)
//             return const Padding(
//               padding: EdgeInsets.fromLTRB(16, 8, 16, 6),
//               child: Text(
//                 'Every song',
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontWeight: FontWeight.bold,
//                   fontSize: 16,
//                 ),
//               ),
//             );
//           final song = songs[index - 1];
//           final id = (song['id'] as num?)?.toInt();
//           if (id == null) return const SizedBox.shrink();
//           final isSelected = selected.contains(id);
//           final art =
//               song['cover_art_url']?.toString() ??
//               song['album_art_url']?.toString();
//           return ListTile(
//             onTap: disabled ? null : () => onToggle(id),
//             contentPadding: const EdgeInsets.symmetric(
//               horizontal: 14,
//               vertical: 2,
//             ),
//             leading: Stack(
//               alignment: Alignment.center,
//               children: [
//                 ClipRRect(
//                   borderRadius: BorderRadius.circular(8),
//                   child: art?.isNotEmpty == true
//                       ? Image.network(
//                           art!,
//                           width: 52,
//                           height: 52,
//                           fit: BoxFit.cover,
//                           errorBuilder: (_, __, ___) => _artPlaceholder(),
//                         )
//                       : _artPlaceholder(),
//                 ),
//                 const Icon(Icons.play_arrow, color: Colors.white, size: 20),
//               ],
//             ),
//             title: Text(
//               '${song['title'] ?? 'Unknown song'}',
//               maxLines: 1,
//               overflow: TextOverflow.ellipsis,
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//             subtitle: Text(
//               '${song['artist'] ?? 'Unknown artist'}',
//               maxLines: 1,
//               overflow: TextOverflow.ellipsis,
//               style: const TextStyle(color: Colors.white60),
//             ),
//             trailing: IconButton(
//               onPressed: disabled ? null : () => onToggle(id),
//               icon: Icon(
//                 isSelected ? Icons.check_circle : Icons.add_circle_outline,
//                 color: isSelected ? const Color(0xFFC4A7FF) : Colors.white70,
//                 size: 28,
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }

//   Widget _artPlaceholder() => Container(
//     width: 52,
//     height: 52,
//     color: const Color(0xFF37284B),
//     child: const Icon(Icons.music_note, color: Color(0xFFC4A7FF)),
//   );
// }

// Future<List<Map<String, dynamic>>> _loadSongsSafely(String token) async {
//   try {
//     final response = await http.get(
//       Uri.parse('${PlaylistService.baseUrl}/api/songs'),
//       headers: {'Authorization': 'Bearer $token'},
//     );
//     if (response.statusCode != 200) return [];
//     final decoded = jsonDecode(response.body);
//     final list = decoded is Map ? decoded['songs'] : decoded;
//     return (list as List)
//         .whereType<Map>()
//         .map((item) => Map<String, dynamic>.from(item))
//         .toList();
//   } catch (_) {
//     return [];
//   }
// }
