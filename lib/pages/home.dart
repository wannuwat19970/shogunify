import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shogunify/pages/player.dart';
import 'package:shogunify/controllers/states.dart';
import 'package:shogunify/controllers/provider.dart';
import 'package:provider/provider.dart';
import 'package:shogunify/services/music_service.dart';
import 'package:shogunify/pages/playlists.dart';
import 'package:shogunify/pages/playlist_detail.dart';
import 'package:shogunify/controllers/queue_sheet.dart';
import 'package:shogunify/pages/support.dart';
import 'package:shogunify/widgets/shogunify_drawer.dart';

import 'package:shogunify/controllers/auth_controller.dart';
import 'package:shogunify/pages/login.dart';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shogunify/controllers/image_utils.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';

class _HomePlaylistCover extends StatelessWidget {
  final String? imageUrl;
  final List<Map<String, dynamic>> songs;

  const _HomePlaylistCover({required this.imageUrl, required this.songs});

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

    if (mosaicUrls.length == 4) {
      return GridView.count(
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
                placeholder: (_, __) => _fallback(),
                errorWidget: (_, __, ___) => _fallback(),
              ),
            )
            .toList(),
      );
    }

    if (resolvedImageUrl != null) {
      return CachedNetworkImage(
        imageUrl: resolvedImageUrl,
        fit: BoxFit.cover,
        placeholder: (_, __) => _fallback(),
        errorWidget: (_, __, ___) => _fallback(),
      );
    }

    return _fallback();
  }

  Widget _fallback() {
    return Container(
      decoration: const BoxDecoration(color: Color.fromARGB(255, 86, 86, 86)),
      child: const Center(
        child: Icon(Icons.music_note_rounded, color: Colors.white, size: 25),
      ),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<Home> {
  late Future<List<Map<String, dynamic>>> songsFuture;
  final ScrollController _homeScrollController = ScrollController();

  String _accountDisplayName = 'Logged-in user';
  String _selectedFilter = 'All';

  List<Map<String, dynamic>> _allSongs = [];
  int _visibleSongCount = 12;
  final Set<String> _favoriteSongKeys = <String>{};

  Future<List<Playlist>>? _playlistsFuture;
  String? _playlistsFutureToken;

  @override
  void initState() {
    super.initState();
    songsFuture = MusicService.fetchSongs().then(
      (list) => List<Map<String, dynamic>>.from(list)..shuffle(),
    );
    _homeScrollController.addListener(_loadMoreSongsWhenNeeded);
  }

  @override
  void dispose() {
    _homeScrollController
      ..removeListener(_loadMoreSongsWhenNeeded)
      ..dispose();
    super.dispose();
  }

  void _loadMoreSongsWhenNeeded() {
    if (!_homeScrollController.hasClients ||
        _homeScrollController.position.extentAfter > 500 ||
        _visibleSongCount >= _allSongs.length) {
      return;
    }
    setState(() {
      _visibleSongCount = (_visibleSongCount + 12).clamp(0, _allSongs.length);
    });
  }

  String _songKey(Map<String, dynamic> song) =>
      (song['id'] ?? song['song_id'] ?? song['filename'] ?? '').toString();

  bool _playlistContainsSong(Playlist playlist, Map<String, dynamic> song) {
    final key = _songKey(song);
    return playlist.songs.any((item) => _songKey(item) == key);
  }

  Future<void> _addSongToPlaylist(
    String token,
    Playlist playlist,
    Map<String, dynamic> song,
  ) async {
    final songId = song['id'] ?? song['song_id'];
    final body = songId != null
        ? {'song_id': songId}
        : {'filename': song['filename']?.toString() ?? ''};

    final response = await http.post(
      Uri.parse(
        'https://music.wannuwatbot.com/api/playlists/${playlist.id}/songs',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('The song could not be added to ${playlist.name}.');
    }
  }

  Future<void> _showPlaylistSelectionDialog(
    String token,
    Map<String, dynamic> song,
  ) async {
    await showAddToPlaylistDialog(
      context: context,
      token: token,
      song: song,
      onSongAdded: () {
        _playlistsFuture = PlaylistService.fetchPlaylists(token);
        setState(() {});
      },
    );
  }

  Future<void> _addSongToFavorites(
    String token,
    Map<String, dynamic> song,
  ) async {
    final playlists = await PlaylistService.fetchPlaylists(token);
    final favorites = playlists.cast<Playlist?>().firstWhere(
      (playlist) => playlist!.name.trim().toLowerCase() == 'favorites',
      orElse: () => null,
    );

    if (favorites == null) {
      throw Exception('Favorites playlist was not found.');
    }

    await _addSongToPlaylist(token, favorites, song);
    if (mounted) {
      setState(() => _favoriteSongKeys.add(_songKey(song)));
    }
  }

  void _showAccountDialog(BuildContext context) {
    final auth = Provider.of<AuthController>(context, listen: false);
    final displayName = auth.username ?? _accountDisplayName;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 45, 45, 45),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white12, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 30,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Account',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white54,
                      size: 22,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 72, 61, 115),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromARGB(70, 147, 132, 209),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Your Shogunify account',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                displayName,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        Navigator.pushNamed(context, '/settings');
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 72, 61, 115),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Settings'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    await auth.logout();
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const Login()),
                        (route) => false,
                      );
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Log out'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlbumArt(
    String? albumArtUrl, {
    required double size,
    required double radius,
  }) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: albumArtUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: Image.network(
                'https://music.wannuwatbot.com$albumArtUrl',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.music_note, color: Colors.grey, size: 50),
              ),
            )
          : const Icon(
              Icons.music_note,
              color: Color.fromARGB(148, 148, 132, 209),
              size: 50,
            ),
    );
  }

  Widget _buildFilterButton({
    required String label,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: selected
                ? const Color.fromARGB(255, 147, 132, 209)
                : Colors.transparent,
            width: selected ? 2.5 : 0,
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color.fromARGB(80, 147, 132, 209),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: selected
                ? const Color.fromARGB(255, 72, 61, 115)
                : const Color.fromARGB(255, 55, 55, 55),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(23),
            ),
            side: BorderSide.none,
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openPlaylist(Playlist playlist, String token) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaylistDetail(playlistId: playlist.id, token: token),
      ),
    );
  }

  Future<void> _openFavorites(String token) async {
    try {
      final playlists = await PlaylistService.fetchPlaylists(token);
      Playlist? favorites;

      for (final playlist in playlists) {
        if (playlist.name.trim().toLowerCase() == 'favorites') {
          favorites = playlist;
          break;
        }
      }

      if (!mounted) return;

      if (favorites == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Favorites playlist was not found.')),
        );
        return;
      }

      await _openPlaylist(favorites, token);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open Favorites: $error')),
      );
    }
  }

  Widget _buildFavoritesPlaylist(String token) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        await _openFavorites(token);
      },
      child: Container(
        height: 53,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
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
        ),
        child: Row(
          children: [
            Container(
              width: 53,
              height: 53,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: Colors.white,
                size: 25,
              ),
            ),
            const SizedBox(width: 9),
            const Expanded(
              child: Text(
                'Favorites',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }

  Widget _buildRealPlaylist(Playlist playlist, String token) {
    return GestureDetector(
      onTap: () => _openPlaylist(playlist, token),
      child: Container(
        height: 53,
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 48, 48, 48),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Container(
              width: 53,
              height: 53,
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 72, 61, 115),
                borderRadius: BorderRadius.circular(6),
              ),
              clipBehavior: Clip.antiAlias,
              child: _HomePlaylistCover(
                imageUrl: playlist.coverArtUrl,
                songs: playlist.songs,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                playlist.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeHeader({
    required bool showPlaylists,
    required String displayName,
    required String? authToken,
  }) {
    final hasAuthToken = authToken != null && authToken.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => _showAccountDialog(context),
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.fromARGB(255, 205, 126, 77),
                  ),
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterButton(
                        label: 'All',
                        selected: _selectedFilter == 'All',
                        onPressed: () {
                          setState(() {
                            _selectedFilter = 'All';
                          });
                        },
                      ),
                      _buildFilterButton(
                        label: 'Music',
                        selected: _selectedFilter == 'Music',
                        onPressed: () {
                          setState(() {
                            _selectedFilter = 'Music';
                          });
                        },
                      ),
                      _buildFilterButton(
                        label: 'Library',
                        selected: false,
                        onPressed: () {
                          Navigator.pushReplacementNamed(context, '/library');
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (showPlaylists) ...[
            const SizedBox(height: 18),
            const Text(
              'Your playlists',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            if (!hasAuthToken)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 0,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 10,
                  mainAxisExtent: 53,
                ),
                itemBuilder: (context, index) => const SizedBox.shrink(),
              )
            else
              Builder(
                builder: (context) {
                  if (_playlistsFuture == null ||
                      _playlistsFutureToken != authToken) {
                    _playlistsFutureToken = authToken;
                    _playlistsFuture = PlaylistService.fetchPlaylists(
                      authToken!,
                    );
                  }
                  return FutureBuilder<List<Playlist>>(
                    future: _playlistsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Color.fromARGB(255, 147, 132, 209),
                            ),
                          ),
                        );
                      }
                      final playlists = (snapshot.data ?? [])
                          .where(
                            (p) => p.name.trim().toLowerCase() != 'favorites',
                          )
                          .toList();

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: playlists.length + 1,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 10,
                              mainAxisExtent: 53,
                            ),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _buildFavoritesPlaylist(authToken!);
                          }
                          return _buildRealPlaylist(
                            playlists[index - 1],
                            authToken!,
                          );
                        },
                      );
                    },
                  );
                },
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSongRow(
    BuildContext context,
    Map<String, dynamic> song,
    List<Map<String, dynamic>> songs,
    int index,
    String? token,
  ) {
    final title = song['title'] ?? 'Unknown';
    final filename = song['filename'] ?? '';
    final artist = song['artist'];
    final albumArtUrl = song['album_art_url'];

    return GestureDetector(
      onTap: () {
        final playerController = Provider.of<PlayerController>(
          context,
          listen: false,
        );

        playerController.songQueue = songs
            .map(
              (s) => {
                'title': s['title'],
                'artist': s['artist'],
                'filename': s['filename'],
                'album_art_url': s['album_art_url'],
                'streamUrl': MusicService.getStreamUrl(s['filename']),
              },
            )
            .toList();

        playerController.playFromQueue(index);
      },
      child: Container(
        height: 80,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: const BoxDecoration(
          color: Colors.transparent,
          border: Border(
            top: BorderSide(color: Color.fromARGB(255, 81, 81, 81), width: 1),
            bottom: BorderSide(
              color: Color.fromARGB(255, 81, 81, 81),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 15),
            _buildAlbumArt(albumArtUrl, size: 55, radius: 10),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    artist != null ? '- $artist' : '- ArtistUnknown',
                    style: const TextStyle(
                      color: Color.fromARGB(255, 170, 170, 170),
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert,
                color: Color.fromARGB(255, 120, 120, 120),
                size: 40,
              ),
              color: const Color.fromARGB(255, 45, 45, 45),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onSelected: (value) async {
                final songData = {
                  'title': title,
                  'artist': artist,
                  'filename': filename,
                  'album_art_url': albumArtUrl,
                  'streamUrl': MusicService.getStreamUrl(filename),
                };
                final playerController = Provider.of<PlayerController>(
                  context,
                  listen: false,
                );

                if (value == 'add_to_playlist') {
                  if (token == null) return;
                  try {
                    await _showPlaylistSelectionDialog(token, song);
                  } catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('$error')));
                  }
                } else if (value == 'add_to_favorites') {
                  if (token == null) return;
                  try {
                    await _addSongToFavorites(token, song);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Added to Favorites.')),
                    );
                  } catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('$error')));
                  }
                } else if (value == 'add_to_queue') {
                  playerController.addToQueue(songData);
                } else if (value == 'go_to_queue') {
                  showQueueSheet(context);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'add_to_playlist',
                  child: Row(
                    children: [
                      Icon(Icons.playlist_add, color: Colors.white60, size: 30),
                      SizedBox(width: 5),
                      Text(
                        'Add to Playlist',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'add_to_favorites',
                  child: Row(
                    children: [
                      Icon(
                        _favoriteSongKeys.contains(_songKey(song))
                            ? Icons.check_circle_rounded
                            : Icons.add_circle_outline_outlined,
                        color: _favoriteSongKeys.contains(_songKey(song))
                            ? Colors.white
                            : Colors.white60,
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'Add to Favorites',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'add_to_queue',
                  child: Row(
                    children: [
                      Icon(Icons.queue, color: Colors.white60),
                      SizedBox(width: 5),
                      Text(
                        'Add to Queue',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'go_to_queue',
                  child: Row(
                    children: [
                      Icon(Icons.queue_music_rounded, color: Colors.white60),
                      SizedBox(width: 5),
                      Text(
                        'Go to Queue',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'check_info',
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: Colors.white60),
                      SizedBox(width: 5),
                      Text(
                        'Check Info',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniPlayer(BuildContext context) {
    return Align(
      alignment: const Alignment(0, 0.945),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const PlayPause(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    const begin = Offset(0.0, 1.0);
                    const end = Offset.zero;
                    const curve = Curves.easeInOutQuart;

                    final tween = Tween(
                      begin: begin,
                      end: end,
                    ).chain(CurveTween(curve: curve));
                    final offsetAnimation = animation.drive(tween);

                    return SlideTransition(
                      position: offsetAnimation,
                      child: child,
                    );
                  },
              transitionDuration: const Duration(milliseconds: 200),
            ),
          );
        },
        child: Container(
          height: 120,
          width: 400,
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 72, 61, 115),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: const Color.fromARGB(255, 147, 132, 209),
              width: 1.5,
            ),
          ),
          child: Consumer<PlayerController>(
            builder: (context, player, child) {
              final currentSongMap =
                  (player.songQueue.isNotEmpty &&
                      player.currentIndex < player.songQueue.length)
                  ? player.songQueue[player.currentIndex]
                  : null;

              final displayTitle =
                  currentSongMap?['title'] ?? 'No song playing';
              final displayArtist = currentSongMap?['artist'] != null
                  ? '- ${currentSongMap!['artist']}'
                  : '- ArtistUnknown';
              final displayArtUrl = currentSongMap?['album_art_url'];

              return Row(
                children: [
                  const SizedBox(width: 10),
                  _buildAlbumArt(displayArtUrl, size: 100, radius: 20),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayTitle.length > 20
                              ? '${displayTitle.substring(0, 20)}...'
                              : displayTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          displayArtist.length > 20
                              ? '${displayArtist.substring(0, 20)}...'
                              : displayArtist,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      player.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 60,
                    ),
                    onPressed: () {
                      if (player.isPlaying) {
                        player.pause();
                      } else {
                        player.play();
                      }
                    },
                  ),
                  const SizedBox(width: 10),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showPlaylists = _selectedFilter == 'All';
    final authToken = context.watch<AuthController>().token;
    final authUsername =
        context.watch<AuthController>().username ?? _accountDisplayName;

    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: const Color.fromARGB(255, 72, 61, 115),
        title: const Text(
          'Shogunify - Home',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      drawer: const ShogunifyDrawer(),
      backgroundColor: const Color.fromARGB(255, 18, 18, 18),
      body: Stack(
        children: [
          FutureBuilder<List<Map<String, dynamic>>>(
            future: songsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }

              final songs = snapshot.data ?? [];
              if (!identical(_allSongs, songs)) {
                _allSongs = songs;
                _visibleSongCount = _visibleSongCount.clamp(0, songs.length);
              }
              final visibleSongs = songs
                  .take(_visibleSongCount)
                  .toList(growable: false);

              return ListView.builder(
                controller: _homeScrollController,
                padding: const EdgeInsets.only(bottom: 150),
                itemCount: visibleSongs.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildHomeHeader(
                      showPlaylists: showPlaylists,
                      displayName: authUsername,
                      authToken: authToken,
                    );
                  }
                  final songIndex = index - 1;
                  return _buildSongRow(
                    context,
                    visibleSongs[songIndex],
                    songs,
                    songIndex,
                    authToken,
                  );
                },
              );
            },
          ),
          _buildMiniPlayer(context),
        ],
      ),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:flutter/rendering.dart';
// import 'package:shogunify/pages/player.dart';
// import 'package:shogunify/controllers/states.dart';
// import 'package:shogunify/controllers/provider.dart';
// import 'package:provider/provider.dart';
// import 'package:shogunify/services/music_service.dart';

// import 'package:shogunify/controllers/auth_controller.dart';
// import 'package:shogunify/pages/login.dart';

// import 'package:package_info_plus/package_info_plus.dart';
// import 'package:url_launcher/url_launcher.dart';

// import 'package:http/http.dart' as http;
// import 'dart:convert';

// class Home extends StatefulWidget {
//   const Home({super.key});

//   @override
//   State<Home> createState() => _MyWidgetState();
// }

// class _MyWidgetState extends State<Home> {
//   late Future<List<Map<String, dynamic>>> songsFuture;

//   String _accountDisplayName = 'Logged-in user';
//   String _selectedFilter = 'All';

//   final List<Map<String, dynamic>> _placeholderPlaylists = [
//     {
//       'title': 'Liked Songs',
//       'icon': Icons.music_note_rounded,
//       'color': Color.fromARGB(255, 88, 88, 88),
//     },
//     {
//       'title': 'My playlist #1',
//       'icon': Icons.music_note_rounded,
//       'color': Color.fromARGB(255, 88, 88, 88),
//     },
//     {
//       'title': 'My playlist #2',
//       'icon': Icons.music_note_rounded,
//       'color': Color.fromARGB(255, 88, 88, 88),
//     },
//     {
//       'title': 'My playlist #3',
//       'icon': Icons.music_note_rounded,
//       'color': Color.fromARGB(255, 88, 88, 88),
//     },
//     {
//       'title': 'My playlist #4',
//       'icon': Icons.music_note_rounded,
//       'color': Color.fromARGB(255, 88, 88, 88),
//     },
//     {
//       'title': 'My playlist #5',
//       'icon': Icons.music_note_rounded,
//       'color': Color.fromARGB(255, 88, 88, 88),
//     },
//   ];

//   @override
//   void initState() {
//     super.initState();
//     songsFuture = MusicService.fetchSongs();
//     _checkForUpdate();
//   }
//   // @override
//   // void initState() {
//   //   super.initState();
//   //   songsFuture = MusicService.fetchSongs();
//   // }

//   Future<void> _checkForUpdate() async {
//     try {
//       final packageInfo = await PackageInfo.fromPlatform();
//       final currentVersion = packageInfo.version;

//       final response = await http.get(
//         Uri.parse('https://music.wannuwatbot.com/api/version'),
//       );
//       if (response.statusCode != 200) return;

//       final data = jsonDecode(response.body);
//       final latestVersion = data['latest_version'];

//       if (latestVersion != currentVersion && mounted) {
//         showDialog(
//           context: context,
//           barrierDismissible: false,
//           builder: (context) => AlertDialog(
//             backgroundColor: const Color.fromARGB(255, 45, 45, 45),
//             title: const Text(
//               'Update Available',
//               style: TextStyle(color: Colors.white),
//             ),
//             content: Text(
//               'A new version ($latestVersion) is available. You\'re on $currentVersion.',
//               style: const TextStyle(color: Colors.white70),
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(context),
//                 child: const Text('Later'),
//               ),
//               FilledButton(
//                 onPressed: () {
//                   Navigator.pop(context);
//                   launchUrl(
//                     Uri.parse(data['download_url']),
//                     mode: LaunchMode.externalApplication,
//                   );
//                 },
//                 style: FilledButton.styleFrom(
//                   backgroundColor: const Color.fromARGB(255, 72, 61, 115),
//                 ),
//                 child: const Text('Download'),
//               ),
//             ],
//           ),
//         );
//       }
//     } catch (e) {
//       // fail silently — don't block the app if the version check fails
//     }
//   }

//   void _showAccountDialog(BuildContext context) {
//     final auth = Provider.of<AuthController>(context, listen: false);
//     final displayName = auth.username ?? _accountDisplayName;

//     showDialog<void>(
//       context: context,
//       builder: (dialogContext) => Dialog(
//         backgroundColor: Colors.transparent,
//         insetPadding: const EdgeInsets.symmetric(horizontal: 24),
//         child: Container(
//           padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
//           decoration: BoxDecoration(
//             color: const Color.fromARGB(255, 45, 45, 45),
//             borderRadius: BorderRadius.circular(28),
//             border: Border.all(color: Colors.white12, width: 1),
//             boxShadow: const [
//               BoxShadow(
//                 color: Colors.black45,
//                 blurRadius: 30,
//                 offset: Offset(0, 14),
//               ),
//             ],
//           ),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Row(
//                 children: [
//                   const Expanded(
//                     child: Text(
//                       'Account',
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 19,
//                         fontWeight: FontWeight.w800,
//                       ),
//                     ),
//                   ),
//                   IconButton(
//                     tooltip: 'Close',
//                     onPressed: () => Navigator.pop(dialogContext),
//                     icon: const Icon(
//                       Icons.close_rounded,
//                       color: Colors.white54,
//                       size: 22,
//                     ),
//                     visualDensity: VisualDensity.compact,
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 8),
//               Container(
//                 width: 76,
//                 height: 76,
//                 decoration: BoxDecoration(
//                   color: const Color.fromARGB(255, 72, 61, 115),
//                   shape: BoxShape.circle,
//                   border: Border.all(color: Colors.white24, width: 2),
//                   boxShadow: const [
//                     BoxShadow(
//                       color: Color.fromARGB(70, 147, 132, 209),
//                       blurRadius: 18,
//                       spreadRadius: 2,
//                     ),
//                   ],
//                 ),
//                 child: Center(
//                   child: Text(
//                     displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontSize: 30,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 14),
//               const Text(
//                 'Your Shogunify account',
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               const SizedBox(height: 8),
//               Text(
//                 displayName,
//                 style: const TextStyle(
//                   color: Colors.white60,
//                   fontSize: 15,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//               const SizedBox(height: 20),
//               const Divider(color: Colors.white12, height: 1),
//               const SizedBox(height: 14),
//               Row(
//                 children: [
//                   Expanded(
//                     child: TextButton(
//                       onPressed: () => Navigator.pop(dialogContext),
//                       style: TextButton.styleFrom(
//                         foregroundColor: Colors.white70,
//                         padding: const EdgeInsets.symmetric(vertical: 13),
//                       ),
//                       child: const Text('Close'),
//                     ),
//                   ),
//                   Expanded(
//                     child: FilledButton(
//                       onPressed: () {
//                         Navigator.pop(dialogContext);
//                         Navigator.pushNamed(context, '/settings');
//                       },
//                       style: FilledButton.styleFrom(
//                         backgroundColor: const Color.fromARGB(255, 72, 61, 115),
//                         foregroundColor: Colors.white,
//                         padding: const EdgeInsets.symmetric(vertical: 13),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(14),
//                         ),
//                       ),
//                       child: const Text('Settings'),
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 8),
//               SizedBox(
//                 width: double.infinity,
//                 child: TextButton(
//                   onPressed: () async {
//                     Navigator.pop(dialogContext);
//                     await auth.logout();
//                     if (context.mounted) {
//                       Navigator.pushAndRemoveUntil(
//                         context,
//                         MaterialPageRoute(builder: (_) => const Login()),
//                         (route) => false,
//                       );
//                     }
//                   },
//                   style: TextButton.styleFrom(
//                     foregroundColor: Colors.redAccent,
//                     padding: const EdgeInsets.symmetric(vertical: 12),
//                   ),
//                   child: const Text('Log out'),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   void _showQueueSheet(BuildContext context) {
//     showModalBottomSheet(
//       context: context,
//       backgroundColor: const Color.fromARGB(255, 34, 34, 34),
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
//       ),
//       builder: (context) {
//         return Consumer2<PlayerController, States>(
//           builder: (context, player, states, child) {
//             final currentSong =
//                 (player.songQueue.isNotEmpty &&
//                     player.currentIndex < player.songQueue.length &&
//                     player.currentIndex >= 0)
//                 ? player.songQueue[player.currentIndex]
//                 : null;

//             // Everything AFTER the currently playing song
//             final upcoming = player.currentIndex >= 0
//                 ? player.songQueue.sublist(player.currentIndex + 1)
//                 : player.songQueue;

//             return SizedBox(
//               height: MediaQuery.of(context).size.height * 0.75,
//               child: Column(
//                 children: [
//                   const SizedBox(height: 12),
//                   Container(
//                     width: 60,
//                     height: 6,
//                     decoration: BoxDecoration(
//                       color: Colors.white24,
//                       borderRadius: BorderRadius.circular(5),
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                   Padding(
//                     padding: const EdgeInsets.symmetric(horizontal: 20),
//                     child: Row(
//                       crossAxisAlignment: CrossAxisAlignment.end,
//                       children: [
//                         const Text(
//                           'Queue',
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontSize: 26,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   if (currentSong != null)
//                     Padding(
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 20,
//                         vertical: 4,
//                       ),
//                       child: Align(
//                         alignment: Alignment.centerLeft,
//                         child: Text.rich(
//                           TextSpan(
//                             style: const TextStyle(
//                               color: Colors.white54,
//                               fontSize: 14,
//                             ),
//                             children: [
//                               const TextSpan(text: 'Playing '),
//                               TextSpan(
//                                 text: currentSong['title'] ?? 'Unknown',
//                                 style: const TextStyle(color: Colors.white),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ),
//                   const SizedBox(height: 10),

//                   // CURRENTLY PLAYING — highlighted row
//                   if (currentSong != null)
//                     Padding(
//                       padding: const EdgeInsets.symmetric(horizontal: 12),
//                       child: Row(
//                         children: [
//                           const SizedBox(width: 3),
//                           _buildAlbumArt(
//                             currentSong['album_art_url'],
//                             size: 55,
//                             radius: 10,
//                           ),
//                           const SizedBox(width: 15),
//                           Expanded(
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text(
//                                   currentSong['title'] ?? 'Unknown Title',
//                                   style: const TextStyle(
//                                     color: Color.fromARGB(255, 147, 132, 209),
//                                     fontSize: 16,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                   overflow: TextOverflow.ellipsis,
//                                 ),
//                                 Text(
//                                   currentSong['artist'] != null
//                                       ? '- ${currentSong['artist']}'
//                                       : '- ArtistUnknown',
//                                   style: const TextStyle(
//                                     color: Colors.white70,
//                                     fontSize: 12,
//                                   ),
//                                   overflow: TextOverflow.ellipsis,
//                                 ),
//                               ],
//                             ),
//                           ),
//                           IconButton(
//                             icon: Icon(
//                               player.isPlaying
//                                   ? Icons.pause_circle_filled_rounded
//                                   : Icons.play_circle_filled_rounded,
//                               color: Colors.white,
//                               size: 34,
//                             ),
//                             onPressed: () {
//                               if (player.isPlaying) {
//                                 player.pause();
//                               } else {
//                                 player.play();
//                               }
//                             },
//                           ),
//                         ],
//                       ),
//                     ),

//                   const SizedBox(height: 16),
//                   Padding(
//                     padding: const EdgeInsets.symmetric(horizontal: 20),
//                     child: Align(
//                       alignment: Alignment.centerLeft,
//                       child: Row(
//                         children: [
//                           if (states.isShuffling)
//                             const Icon(
//                               Icons.shuffle_rounded,
//                               color: Colors.white54,
//                               size: 18,
//                             ),
//                           if (states.isShuffling) const SizedBox(width: 6),
//                           Text(
//                             states.isShuffling
//                                 ? 'Shuffling from:'
//                                 : 'Next in queue:',
//                             style: const TextStyle(
//                               color: Colors.white54,
//                               fontSize: 14,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 6),

//                   // UPCOMING LIST
//                   Expanded(
//                     child: upcoming.isEmpty
//                         ? const Center(
//                             child: Text(
//                               'Nothing queued next',
//                               style: TextStyle(color: Colors.white54),
//                             ),
//                           )
//                         : ListView.builder(
//                             itemCount: upcoming.length,
//                             itemBuilder: (context, index) {
//                               final song = upcoming[index];
//                               final realIndex = player.currentIndex + 1 + index;

//                               return GestureDetector(
//                                 onTap: () => player.playFromQueue(realIndex),
//                                 child: Container(
//                                   height: 70,
//                                   margin: const EdgeInsets.symmetric(
//                                     horizontal: 12,
//                                     vertical: 4,
//                                   ),
//                                   child: Row(
//                                     children: [
//                                       const SizedBox(width: 3),
//                                       _buildAlbumArt(
//                                         song['album_art_url'],
//                                         size: 45,
//                                         radius: 10,
//                                       ),
//                                       const SizedBox(width: 15),
//                                       Expanded(
//                                         child: Column(
//                                           mainAxisAlignment:
//                                               MainAxisAlignment.center,
//                                           crossAxisAlignment:
//                                               CrossAxisAlignment.start,
//                                           children: [
//                                             Text(
//                                               song['title'] ?? 'Unknown Title',
//                                               style: const TextStyle(
//                                                 color: Colors.white,
//                                                 fontSize: 16,
//                                                 fontWeight: FontWeight.bold,
//                                               ),
//                                               overflow: TextOverflow.ellipsis,
//                                             ),
//                                             Text(
//                                               song['artist'] != null
//                                                   ? '- ${song['artist']}'
//                                                   : '- ArtistUnknown',
//                                               style: const TextStyle(
//                                                 color: Colors.white70,
//                                                 fontSize: 12,
//                                               ),
//                                               overflow: TextOverflow.ellipsis,
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//                                       const Icon(
//                                         Icons.drag_handle_rounded,
//                                         color: Colors.white24,
//                                         size: 22,
//                                       ),
//                                       const SizedBox(width: 8),
//                                     ],
//                                   ),
//                                 ),
//                               );
//                             },
//                           ),
//                   ),

//                   // BOTTOM: Shuffle / Timer buttons
//                   Padding(
//                     padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
//                     child: Row(
//                       children: [
//                         Expanded(
//                           child: GestureDetector(
//                             onTap: () => states.toggleShuffle(),
//                             child: Container(
//                               height: 70,
//                               decoration: BoxDecoration(
//                                 color: const Color.fromARGB(255, 45, 45, 45),
//                                 borderRadius: BorderRadius.circular(16),
//                               ),
//                               child: Column(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   Icon(
//                                     Icons.shuffle_rounded,
//                                     color: states.isShuffling
//                                         ? const Color.fromARGB(
//                                             255,
//                                             147,
//                                             132,
//                                             209,
//                                           )
//                                         : Colors.white,
//                                     size: 26,
//                                   ),
//                                   const SizedBox(height: 4),
//                                   Text(
//                                     'Shuffle',
//                                     style: TextStyle(
//                                       color: states.isShuffling
//                                           ? const Color.fromARGB(
//                                               255,
//                                               147,
//                                               132,
//                                               209,
//                                             )
//                                           : Colors.white,
//                                       fontSize: 13,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 12),
//                         Expanded(
//                           child: Container(
//                             height: 70,
//                             decoration: BoxDecoration(
//                               color: const Color.fromARGB(255, 45, 45, 45),
//                               borderRadius: BorderRadius.circular(16),
//                             ),
//                             child: const Column(
//                               mainAxisAlignment: MainAxisAlignment.center,
//                               children: [
//                                 Icon(
//                                   Icons.timer_outlined,
//                                   color: Colors.white,
//                                   size: 26,
//                                 ),
//                                 SizedBox(height: 4),
//                                 Text(
//                                   'Timer',
//                                   style: TextStyle(
//                                     color: Colors.white,
//                                     fontSize: 13,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             );
//           },
//         );
//       },
//     );
//   }

//   Widget _buildAlbumArt(
//     String? albumArtUrl, {
//     required double size,
//     required double radius,
//   }) {
//     return Container(
//       height: size,
//       width: size,
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(radius),
//       ),
//       child: albumArtUrl != null
//           ? ClipRRect(
//               borderRadius: BorderRadius.circular(radius),
//               child: Image.network(
//                 'https://music.wannuwatbot.com$albumArtUrl',
//                 fit: BoxFit.cover,
//                 errorBuilder: (context, error, stackTrace) =>
//                     const Icon(Icons.music_note, color: Colors.grey),
//               ),
//             )
//           : const Icon(Icons.music_note, color: Colors.grey),
//     );
//   }

//   Widget _buildFilterButton({
//     required String label,
//     required bool selected,
//     required VoidCallback onPressed,
//   }) {
//     return Padding(
//       padding: const EdgeInsets.only(right: 10),
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 180),
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(26),
//           border: Border.all(
//             color: selected
//                 ? const Color.fromARGB(255, 147, 132, 209)
//                 : Colors.transparent,
//             width: selected ? 2.5 : 0,
//           ),
//           boxShadow: selected
//               ? const [
//                   BoxShadow(
//                     color: Color.fromARGB(80, 147, 132, 209),
//                     blurRadius: 8,
//                     spreadRadius: 1,
//                   ),
//                 ]
//               : [],
//         ),
//         child: ElevatedButton(
//           onPressed: onPressed,
//           style: ElevatedButton.styleFrom(
//             elevation: 0,
//             backgroundColor: selected
//                 ? const Color.fromARGB(255, 72, 61, 115)
//                 : const Color.fromARGB(255, 55, 55, 55),
//             foregroundColor: Colors.white,
//             padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(23),
//             ),
//             side: BorderSide.none,
//           ),
//           child: Text(
//             label,
//             style: const TextStyle(
//               fontSize: 15,
//               fontWeight: FontWeight.w600,
//               color: Colors.white,
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildPlaceholderPlaylist(Map<String, dynamic> playlist) {
//     return Container(
//       height: 53,
//       decoration: BoxDecoration(
//         color: const Color.fromARGB(255, 48, 48, 48),
//         borderRadius: BorderRadius.circular(6),
//       ),
//       child: Row(
//         children: [
//           Container(
//             width: 53,
//             height: 53,
//             decoration: BoxDecoration(
//               color: playlist['color'] as Color,
//               borderRadius: BorderRadius.circular(6),
//             ),
//             child: Icon(
//               playlist['icon'] as IconData,
//               color: Colors.white,
//               size: 25,
//             ),
//           ),
//           const SizedBox(width: 9),
//           Expanded(
//             child: Text(
//               playlist['title'] as String,
//               maxLines: 2,
//               overflow: TextOverflow.ellipsis,
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontSize: 12,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ),
//           const SizedBox(width: 6),
//         ],
//       ),
//     );
//   }

//   Widget _buildHomeHeader({
//     required bool showPlaylists,
//     required String displayName,
//   }) {
//     return Padding(
//       padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               GestureDetector(
//                 onTap: () => _showAccountDialog(context),
//                 child: Container(
//                   width: 48,
//                   height: 48,
//                   alignment: Alignment.center,
//                   decoration: const BoxDecoration(
//                     shape: BoxShape.circle,
//                     color: Color.fromARGB(255, 205, 126, 77),
//                   ),
//                   child: Text(
//                     displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontSize: 24,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 14),
//               Expanded(
//                 child: SingleChildScrollView(
//                   scrollDirection: Axis.horizontal,
//                   child: Row(
//                     children: [
//                       _buildFilterButton(
//                         label: 'All',
//                         selected: _selectedFilter == 'All',
//                         onPressed: () {
//                           setState(() {
//                             _selectedFilter = 'All';
//                           });
//                         },
//                       ),
//                       _buildFilterButton(
//                         label: 'Music',
//                         selected: _selectedFilter == 'Music',
//                         onPressed: () {
//                           setState(() {
//                             _selectedFilter = 'Music';
//                           });
//                         },
//                       ),
//                       _buildFilterButton(
//                         label: 'Library',
//                         selected: false,
//                         onPressed: () {
//                           Navigator.pushReplacementNamed(context, '/library');
//                         },
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           if (showPlaylists) ...[
//             const SizedBox(height: 18),
//             const Text(
//               'Your playlists',
//               style: TextStyle(
//                 color: Colors.white,
//                 fontSize: 24,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             const SizedBox(height: 10),
//             GridView.builder(
//               shrinkWrap: true,
//               physics: const NeverScrollableScrollPhysics(),
//               itemCount: _placeholderPlaylists.length,
//               gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                 crossAxisCount: 2,
//                 crossAxisSpacing: 12,
//                 mainAxisSpacing: 10,
//                 mainAxisExtent: 53,
//               ),
//               itemBuilder: (context, index) {
//                 return _buildPlaceholderPlaylist(_placeholderPlaylists[index]);
//               },
//             ),
//           ],
//         ],
//       ),
//     );
//   }

//   Widget _buildSongRow(
//     BuildContext context,
//     Map<String, dynamic> song,
//     List<Map<String, dynamic>> songs,
//     int index,
//   ) {
//     final title = song['title'] ?? 'Unknown';
//     final filename = song['filename'] ?? '';
//     final artist = song['artist'];
//     final albumArtUrl = song['album_art_url'];

//     return GestureDetector(
//       onTap: () {
//         final playerController = Provider.of<PlayerController>(
//           context,
//           listen: false,
//         );

//         playerController.songQueue = songs
//             .map(
//               (s) => {
//                 'title': s['title'],
//                 'artist': s['artist'],
//                 'filename': s['filename'],
//                 'album_art_url': s['album_art_url'],
//                 'streamUrl': MusicService.getStreamUrl(s['filename']),
//               },
//             )
//             .toList();

//         playerController.playFromQueue(index);
//       },
//       child: Container(
//         height: 80,
//         margin: const EdgeInsets.symmetric(horizontal: 12),
//         decoration: const BoxDecoration(
//           color: Colors.transparent,
//           border: Border(
//             top: BorderSide(color: Color.fromARGB(255, 81, 81, 81), width: 1),
//             bottom: BorderSide(
//               color: Color.fromARGB(255, 81, 81, 81),
//               width: 1,
//             ),
//           ),
//         ),
//         child: Row(
//           children: [
//             const SizedBox(width: 15),
//             _buildAlbumArt(albumArtUrl, size: 55, radius: 10),
//             const SizedBox(width: 15),
//             Expanded(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     title,
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontSize: 22,
//                       fontWeight: FontWeight.bold,
//                     ),
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                   Text(
//                     artist != null ? '- $artist' : '- ArtistUnknown',
//                     style: const TextStyle(
//                       color: Color.fromARGB(255, 170, 170, 170),
//                       fontSize: 14,
//                     ),
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                 ],
//               ),
//             ),
//             PopupMenuButton<String>(
//               icon: const Icon(
//                 Icons.more_vert,
//                 color: Color.fromARGB(255, 120, 120, 120),
//                 size: 40,
//               ),
//               color: const Color.fromARGB(255, 45, 45, 45),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(16),
//               ),
//               onSelected: (value) {
//                 final songData = {
//                   'title': title,
//                   'artist': artist,
//                   'filename': filename,
//                   'album_art_url': albumArtUrl,
//                   'streamUrl': MusicService.getStreamUrl(filename),
//                 };
//                 final playerController = Provider.of<PlayerController>(
//                   context,
//                   listen: false,
//                 );

//                 if (value == 'add_to_queue') {
//                   playerController.addToQueue(songData);
//                 } else if (value == 'go_to_queue') {
//                   _showQueueSheet(context);
//                 }
//               },
//               itemBuilder: (context) => [
//                 const PopupMenuItem(
//                   value: 'add_to_playlist',
//                   child: Row(
//                     children: [
//                       Icon(Icons.playlist_add, color: Colors.white60, size: 30),
//                       SizedBox(width: 5),
//                       Text(
//                         'Add to Playlist',
//                         style: TextStyle(color: Colors.white, fontSize: 16),
//                       ),
//                     ],
//                   ),
//                 ),
//                 const PopupMenuItem(
//                   value: 'add_to_favorites',
//                   child: Row(
//                     children: [
//                       Icon(
//                         Icons.add_circle_outline_rounded,
//                         color: Colors.white60,
//                       ),
//                       SizedBox(width: 5),
//                       Text(
//                         'Add to Favorites',
//                         style: TextStyle(color: Colors.white, fontSize: 16),
//                       ),
//                     ],
//                   ),
//                 ),
//                 const PopupMenuItem(
//                   value: 'add_to_queue',
//                   child: Row(
//                     children: [
//                       Icon(Icons.queue, color: Colors.white60),
//                       SizedBox(width: 5),
//                       Text(
//                         'Add to Queue',
//                         style: TextStyle(color: Colors.white, fontSize: 16),
//                       ),
//                     ],
//                   ),
//                 ),
//                 const PopupMenuItem(
//                   value: 'go_to_queue',
//                   child: Row(
//                     children: [
//                       Icon(Icons.queue_music_rounded, color: Colors.white60),
//                       SizedBox(width: 5),
//                       Text(
//                         'Go to Queue',
//                         style: TextStyle(color: Colors.white, fontSize: 16),
//                       ),
//                     ],
//                   ),
//                 ),
//                 const PopupMenuItem(
//                   value: 'check_info',
//                   child: Row(
//                     children: [
//                       Icon(Icons.info_outline_rounded, color: Colors.white60),
//                       SizedBox(width: 5),
//                       Text(
//                         'Check Info',
//                         style: TextStyle(color: Colors.white, fontSize: 16),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(width: 5),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildMiniPlayer(BuildContext context) {
//     return Align(
//       alignment: const Alignment(0, 0.945),
//       child: GestureDetector(
//         onTap: () {
//           Navigator.push(
//             context,
//             PageRouteBuilder(
//               pageBuilder: (context, animation, secondaryAnimation) =>
//                   const PlayPause(),
//               transitionsBuilder:
//                   (context, animation, secondaryAnimation, child) {
//                     const begin = Offset(0.0, 1.0);
//                     const end = Offset.zero;
//                     const curve = Curves.easeInOutQuart;

//                     final tween = Tween(
//                       begin: begin,
//                       end: end,
//                     ).chain(CurveTween(curve: curve));
//                     final offsetAnimation = animation.drive(tween);

//                     return SlideTransition(
//                       position: offsetAnimation,
//                       child: child,
//                     );
//                   },
//               transitionDuration: const Duration(milliseconds: 200),
//             ),
//           );
//         },
//         child: Container(
//           height: 120,
//           width: 400,
//           decoration: BoxDecoration(
//             color: const Color.fromARGB(255, 72, 61, 115),
//             borderRadius: BorderRadius.circular(30),
//             border: Border.all(
//               color: const Color.fromARGB(255, 147, 132, 209),
//               width: 1.5,
//             ),
//           ),
//           child: Consumer<PlayerController>(
//             builder: (context, player, child) {
//               final currentSongMap =
//                   (player.songQueue.isNotEmpty &&
//                       player.currentIndex < player.songQueue.length)
//                   ? player.songQueue[player.currentIndex]
//                   : null;

//               final displayTitle =
//                   currentSongMap?['title'] ?? 'No song playing';
//               final displayArtist = currentSongMap?['artist'] != null
//                   ? '- ${currentSongMap!['artist']}'
//                   : '- ArtistUnknown';
//               final displayArtUrl = currentSongMap?['album_art_url'];

//               return Row(
//                 children: [
//                   const SizedBox(width: 10),
//                   _buildAlbumArt(displayArtUrl, size: 100, radius: 20),
//                   const SizedBox(width: 15),
//                   Expanded(
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           displayTitle.length > 20
//                               ? '${displayTitle.substring(0, 20)}...'
//                               : displayTitle,
//                           style: const TextStyle(
//                             color: Colors.white,
//                             fontSize: 22,
//                             fontWeight: FontWeight.bold,
//                           ),
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                         const SizedBox(height: 4),
//                         Text(
//                           displayArtist.length > 20
//                               ? '${displayArtist.substring(0, 20)}...'
//                               : displayArtist,
//                           style: const TextStyle(
//                             color: Colors.white70,
//                             fontSize: 14,
//                           ),
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                       ],
//                     ),
//                   ),
//                   IconButton(
//                     icon: Icon(
//                       player.isPlaying
//                           ? Icons.pause_rounded
//                           : Icons.play_arrow_rounded,
//                       color: Colors.white,
//                       size: 60,
//                     ),
//                     onPressed: () {
//                       if (player.isPlaying) {
//                         player.pause();
//                       } else {
//                         player.play();
//                       }
//                     },
//                   ),
//                   const SizedBox(width: 10),
//                 ],
//               );
//             },
//           ),
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final showPlaylists = _selectedFilter == 'All';
//     final authUsername =
//         context.watch<AuthController>().username ?? _accountDisplayName;

//     return Scaffold(
//       appBar: AppBar(
//         iconTheme: const IconThemeData(color: Colors.white),
//         backgroundColor: const Color.fromARGB(255, 72, 61, 115),
//         title: const Text(
//           'Shogunify - Home',
//           style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//         ),
//       ),
//       drawer: Drawer(
//         backgroundColor: const Color.fromARGB(255, 25, 25, 25),
//         child: Column(
//           children: [
//             const DrawerHeader(
//               child: Icon(
//                 Icons.music_note_rounded,
//                 size: 40,
//                 color: Colors.white,
//               ),
//             ),
//             ListTile(
//               onTap: () {
//                 Navigator.pop(context);
//                 Navigator.pushReplacementNamed(context, '/home');
//               },
//               leading: const Icon(
//                 Icons.home_rounded,
//                 size: 30,
//                 color: Colors.white,
//               ),
//               title: const Text(
//                 'Home',
//                 style: TextStyle(color: Colors.white, fontSize: 20),
//               ),
//             ),
//             ListTile(
//               onTap: () {
//                 Navigator.pop(context);
//                 Navigator.pushReplacementNamed(context, '/library');
//               },
//               leading: const Icon(
//                 Icons.format_list_bulleted_rounded,
//                 size: 30,
//                 color: Colors.white,
//               ),
//               title: const Text(
//                 'Library',
//                 style: TextStyle(color: Colors.white, fontSize: 20),
//               ),
//             ),
//             ListTile(
//               onTap: () {
//                 Navigator.pop(context);
//                 Navigator.pushReplacementNamed(context, '/settings');
//               },
//               leading: const Icon(
//                 Icons.settings,
//                 size: 30,
//                 color: Colors.white,
//               ),
//               title: const Text(
//                 'Settings',
//                 style: TextStyle(fontSize: 20, color: Colors.white),
//               ),
//             ),
//           ],
//         ),
//       ),
//       backgroundColor: const Color.fromARGB(255, 18, 18, 18),
//       body: Stack(
//         children: [
//           FutureBuilder<List<Map<String, dynamic>>>(
//             future: songsFuture,
//             builder: (context, snapshot) {
//               if (snapshot.connectionState == ConnectionState.waiting) {
//                 return const Center(child: CircularProgressIndicator());
//               }
//               if (snapshot.hasError) {
//                 return Center(
//                   child: Text(
//                     'Error: ${snapshot.error}',
//                     style: const TextStyle(color: Colors.white),
//                   ),
//                 );
//               }

//               final songs = snapshot.data ?? [];

//               // Single unified list: header (item 0) + all songs after it.
//               // This is what fixes the dead space and makes playlists scroll
//               // together with the song list instead of two separate regions.
//               return ListView.builder(
//                 padding: const EdgeInsets.only(bottom: 150),
//                 itemCount: songs.length + 1,
//                 itemBuilder: (context, index) {
//                   if (index == 0) {
//                     return _buildHomeHeader(
//                       showPlaylists: showPlaylists,
//                       displayName: authUsername,
//                     );
//                   }
//                   final songIndex = index - 1;
//                   return _buildSongRow(
//                     context,
//                     songs[songIndex],
//                     songs,
//                     songIndex,
//                   );
//                 },
//               );
//             },
//           ),
//           _buildMiniPlayer(context),
//         ],
//       ),
//     );
//   }
// }
