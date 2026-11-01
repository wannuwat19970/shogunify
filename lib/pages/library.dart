import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'package:shogunify/controllers/image_utils.dart';
import 'package:shogunify/controllers/provider.dart';
import 'package:shogunify/controllers/auth_controller.dart';
import 'package:shogunify/controllers/states.dart';
import 'package:shogunify/controllers/queue_sheet.dart';
import 'package:shogunify/services/music_service.dart';
import 'package:shogunify/pages/addsongs.dart';
import 'package:shogunify/pages/player.dart';
import 'package:shogunify/pages/playlists.dart';
import 'package:shogunify/pages/playlist_detail.dart';
import 'package:shogunify/widgets/shogunify_drawer.dart';

class Library extends StatefulWidget {
  const Library({super.key});

  @override
  State<Library> createState() => _LibraryState();
}

class _LibraryPlaylistCover extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final List<String> fallbackArtUrls;

  const _LibraryPlaylistCover({
    required this.title,
    this.imageUrl,
    this.fallbackArtUrls = const [],
  });

  @override
  Widget build(BuildContext context) {
    final resolvedImageUrl = ImageUtils.resolveUrl(imageUrl);
    final mosaicUrls = fallbackArtUrls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .map((url) => ImageUtils.resolveUrl(url))
        .whereType<String>()
        .toSet()
        .take(4)
        .toList();

    Widget content;

    if (mosaicUrls.length == 4) {
      content = GridView.count(
        crossAxisCount: 2,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        children: mosaicUrls
            .map(
              (url) => CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(color: const Color(0xFF37284B)),
                errorWidget: (_, __, ___) =>
                    Container(color: const Color(0xFF37284B)),
              ),
            )
            .toList(),
      );
    } else if (resolvedImageUrl != null) {
      content = CachedNetworkImage(
        imageUrl: resolvedImageUrl,
        fit: BoxFit.cover,
        placeholder: (_, __) => _fallbackCover(),
        errorWidget: (_, __, ___) => _fallbackCover(),
      );
    } else if (mosaicUrls.isNotEmpty) {
      content = CachedNetworkImage(
        imageUrl: mosaicUrls.first,
        fit: BoxFit.cover,
        placeholder: (_, __) => _fallbackCover(),
        errorWidget: (_, __, ___) => _fallbackCover(),
      );
    } else {
      content = _fallbackCover();
    }

    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        fit: StackFit.expand,
        children: [
          content,
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color.fromRGBO(0, 0, 0, 0.75)],
                stops: [0.1, 1.4],
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 18,
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                height: 1.1,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: Colors.black54,
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackCover() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
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
    );
  }
}

class _LibraryState extends State<Library> {
  late Future<List<Map<String, dynamic>>> songsFuture;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _libraryScrollController = ScrollController();

  List<Map<String, dynamic>> _allSongs = [];
  int _visibleSongCount = 12;
  final Set<String> _favoriteSongKeys = <String>{};

  @override
  void initState() {
    super.initState();
    songsFuture = MusicService.fetchSongs().then(
      (list) => List<Map<String, dynamic>>.from(list)..shuffle(),
    );
    _libraryScrollController.addListener(_loadMoreSongsWhenNeeded);
  }

  @override
  void dispose() {
    _textController.dispose();
    _libraryScrollController
      ..removeListener(_loadMoreSongsWhenNeeded)
      ..dispose();
    super.dispose();
  }

  void _loadMoreSongsWhenNeeded() {
    if (!_libraryScrollController.hasClients ||
        _libraryScrollController.position.extentAfter > 500 ||
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

  // Future<void> _showPlaylistSelectionDialog(
  //   String token,
  //   Map<String, dynamic> song,
  // ) async {
  //   final playlists = await PlaylistService.fetchPlaylists(token);
  //   if (!mounted) return;

  //   await showDialog<void>(
  //     context: context,
  //     builder: (dialogContext) => AlertDialog(
  //       backgroundColor: const Color(0xFF2D2D2D),
  //       title: const Text(
  //         'Select playlist to add this song to',
  //         style: TextStyle(color: Colors.white, fontSize: 19),
  //       ),
  //       content: SizedBox(
  //         width: double.maxFinite,
  //         child: playlists.isEmpty
  //             ? const Text(
  //                 'No playlists found.',
  //                 style: TextStyle(color: Colors.white70),
  //               )
  //             : ListView.builder(
  //                 shrinkWrap: true,
  //                 itemCount: playlists.length,
  //                 itemBuilder: (_, index) {
  //                   final playlist = playlists[index];
  //                   final alreadyAdded = _playlistContainsSong(playlist, song);
  //                   return ListTile(
  //                     title: Text(
  //                       playlist.name,
  //                       style: const TextStyle(color: Colors.white),
  //                     ),
  //                     trailing: alreadyAdded
  //                         ? const Icon(
  //                             Icons.playlist_add_check,
  //                             color: Colors.white,
  //                           )
  //                         : const Icon(
  //                             Icons.playlist_add,
  //                             color: Colors.white60,
  //                           ),
  //                     onTap: () async {
  //                       try {
  //                         await _addSongToPlaylist(token, playlist, song);
  //                         if (!dialogContext.mounted) return;
  //                         Navigator.of(dialogContext).pop();
  //                         ScaffoldMessenger.of(context).showSnackBar(
  //                           SnackBar(
  //                             content: Text('Added to ${playlist.name}.'),
  //                           ),
  //                         );
  //                       } catch (error) {
  //                         if (!dialogContext.mounted) return;
  //                         ScaffoldMessenger.of(
  //                           dialogContext,
  //                         ).showSnackBar(SnackBar(content: Text('$error')));
  //                       }
  //                     },
  //                   );
  //                 },
  //               ),
  //       ),
  //     ),
  //   );
  // }
  Future<void> _showPlaylistSelectionDialog(
    String token,
    Map<String, dynamic> song,
  ) async {
    await showAddToPlaylistDialog(
      context: context,
      token: token,
      song: song,
      onSongAdded: () {
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

    if (favorites == null) throw Exception('Favorites playlist was not found.');

    await _addSongToPlaylist(token, favorites, song);
    if (mounted) {
      setState(() => _favoriteSongKeys.add(_songKey(song)));
    }
  }

  Widget _playlistCard({
    required String title,
    required VoidCallback onTap,
    bool add = false,
    bool favorites = false,
    String? coverArtUrl,
    List<Map<String, dynamic>> songs = const [],
  }) {
    const cardBorder = Color.fromARGB(255, 81, 81, 81);
    final fallbackArtUrls = songs
        .map((song) => song['album_art_url']?.toString())
        .whereType<String>()
        .toList();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 174,
        height: 174,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 27, 27, 27),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cardBorder),
        ),
        child: add
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 55,
                    width: 55,
                    child: Center(
                      child: Icon(
                        Icons.add_rounded,
                        color: Color.fromARGB(255, 100, 100, 100),
                        size: 55,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Add playlist',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              )
            : favorites
            ? PlaylistCover(title: title, size: 174, compact: false)
            : _LibraryPlaylistCover(
                title: title,
                imageUrl: coverArtUrl,
                fallbackArtUrls: fallbackArtUrls,
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
    if (mounted) setState(() {});
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: const Color.fromARGB(255, 72, 61, 115),
        title: const Text(
          "Shogunify - Library",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      drawer: const ShogunifyDrawer(),
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 140,
            child: SingleChildScrollView(
              controller: _libraryScrollController,
              child: Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'Playlists',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Consumer<AuthController>(
                      builder: (context, auth, _) {
                        final token = auth.token;
                        if (token == null) return const SizedBox.shrink();
                        return FutureBuilder<List<Playlist>>(
                          future: PlaylistService.fetchPlaylists(token),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const SizedBox(
                                height: 196,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: Color.fromARGB(255, 147, 132, 209),
                                  ),
                                ),
                              );
                            }
                            final playlists = snapshot.data ?? [];
                            return SizedBox(
                              height: 174,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                children: [
                                  _playlistCard(
                                    title: 'Add playlist',
                                    add: true,
                                    onTap: () async {
                                      final created =
                                          await showCreatePlaylistDialog(
                                            context,
                                            token,
                                          );
                                      if (!mounted || created == null) return;
                                      setState(() {});
                                    },
                                  ),
                                  _playlistCard(
                                    title: 'Favorites',
                                    favorites: true,
                                    onTap: () => _openFavorites(token),
                                  ),
                                  ...playlists
                                      .where(
                                        (playlist) =>
                                            playlist.name
                                                .trim()
                                                .toLowerCase() !=
                                            'favorites',
                                      )
                                      .map(
                                        (playlist) => _playlistCard(
                                          title: playlist.name,
                                          coverArtUrl: playlist.coverArtUrl,
                                          songs: playlist.songs,
                                          onTap: () =>
                                              _openPlaylist(playlist, token),
                                        ),
                                      ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 30),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'Discover new songs',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 30,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    const Addsongs(),
                            transitionsBuilder:
                                (
                                  context,
                                  animation,
                                  secondaryAnimation,
                                  child,
                                ) {
                                  const begin = Offset(0.0, 1.0);
                                  const end = Offset.zero;
                                  const curve = Curves.easeInOutQuart;
                                  final tween = Tween(
                                    begin: begin,
                                    end: end,
                                  ).chain(CurveTween(curve: curve));
                                  return SlideTransition(
                                    position: animation.drive(tween),
                                    child: child,
                                  );
                                },
                            transitionDuration: const Duration(
                              milliseconds: 200,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        height: 80,
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: const BoxDecoration(
                          color: Color.fromARGB(0, 34, 34, 34),
                          border: Border(
                            top: BorderSide(
                              color: Color.fromARGB(255, 81, 81, 81),
                            ),
                            bottom: BorderSide(
                              color: Color.fromARGB(255, 81, 81, 81),
                            ),
                          ),
                        ),
                        child: Row(
                          children: const [
                            SizedBox(width: 15),
                            SizedBox(
                              height: 55,
                              width: 55,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Color.fromARGB(255, 27, 27, 27),
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(10),
                                  ),
                                  border: Border.fromBorderSide(
                                    BorderSide(
                                      color: Color.fromARGB(255, 52, 52, 52),
                                    ),
                                  ),
                                ),
                                child: Icon(
                                  Icons.add_rounded,
                                  color: Color.fromARGB(255, 100, 100, 100),
                                  size: 36,
                                ),
                              ),
                            ),
                            SizedBox(width: 15),
                            Text(
                              'Add songs',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: songsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
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
                          _visibleSongCount = _visibleSongCount.clamp(
                            0,
                            songs.length,
                          );
                        }
                        final visibleSongs = songs
                            .take(_visibleSongCount)
                            .toList(growable: false);

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: visibleSongs.length,
                          itemBuilder: (context, index) {
                            final song = visibleSongs[index];
                            final title = song['title'] ?? 'Unknown';
                            final filename = song['filename'] ?? '';
                            final artist = song['artist'];
                            final albumArtUrl = song['album_art_url'];
                            final resolvedAlbumArtUrl = ImageUtils.resolveUrl(
                              albumArtUrl?.toString(),
                            );

                            return GestureDetector(
                              onTap: () {
                                final playerController =
                                    Provider.of<PlayerController>(
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
                                        'streamUrl': MusicService.getStreamUrl(
                                          s['filename'],
                                        ),
                                      },
                                    )
                                    .toList();
                                playerController.playFromQueue(index);
                              },
                              child: Container(
                                height: 80,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: const BoxDecoration(
                                  color: Color.fromARGB(0, 34, 34, 34),
                                  border: Border(
                                    top: BorderSide(
                                      color: Color.fromARGB(255, 81, 81, 81),
                                      width: 1,
                                    ),
                                    bottom: BorderSide(
                                      color: Color.fromARGB(255, 81, 81, 81),
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const SizedBox(width: 15),
                                    Container(
                                      height: 55,
                                      width: 55,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: resolvedAlbumArtUrl != null
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: CachedNetworkImage(
                                                imageUrl: resolvedAlbumArtUrl,
                                                fit: BoxFit.cover,
                                                placeholder: (_, __) =>
                                                    ImageUtils.placeholder(
                                                      iconSize: 28,
                                                    ),
                                                errorWidget: (_, __, ___) =>
                                                    ImageUtils.placeholder(
                                                      iconSize: 28,
                                                    ),
                                              ),
                                            )
                                          : const Icon(
                                              Icons.music_note,
                                              color: Colors.grey,
                                            ),
                                    ),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: Stack(
                                        children: [
                                          Align(
                                            alignment: const Alignment(
                                              -1,
                                              -0.85,
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                top: 15,
                                              ),
                                              child: Text(
                                                title,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                          Align(
                                            alignment: const Alignment(
                                              -0.99,
                                              1.2,
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 15,
                                              ),
                                              child: Text(
                                                artist != null
                                                    ? '- $artist'
                                                    : '- ArtistUnknown',
                                                style: const TextStyle(
                                                  color: Color.fromARGB(
                                                    255,
                                                    170,
                                                    170,
                                                    170,
                                                  ),
                                                  fontSize: 14,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      icon: const Icon(
                                        Icons.more_vert,
                                        color: Color.fromARGB(
                                          255,
                                          120,
                                          120,
                                          120,
                                        ),
                                        size: 40,
                                      ),
                                      color: const Color.fromARGB(
                                        255,
                                        45,
                                        45,
                                        45,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      onSelected: (value) async {
                                        final streamUrl =
                                            MusicService.getStreamUrl(filename);
                                        final songData = {
                                          'title': title,
                                          'artist': artist,
                                          'filename': filename,
                                          'album_art_url': albumArtUrl,
                                          'streamUrl': streamUrl,
                                        };
                                        final playerController =
                                            Provider.of<PlayerController>(
                                              context,
                                              listen: false,
                                            );
                                        final auth =
                                            Provider.of<AuthController>(
                                              context,
                                              listen: false,
                                            );

                                        if (value == 'add_to_playlist') {
                                          if (auth.token == null) return;
                                          try {
                                            await _showPlaylistSelectionDialog(
                                              auth.token!,
                                              song,
                                            );
                                          } catch (error) {
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(content: Text('$error')),
                                            );
                                          }
                                        } else if (value ==
                                            'add_to_favorites') {
                                          if (auth.token == null) return;
                                          try {
                                            await _addSongToFavorites(
                                              auth.token!,
                                              song,
                                            );
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Added to Favorites.',
                                                ),
                                              ),
                                            );
                                          } catch (error) {
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(content: Text('$error')),
                                            );
                                          }
                                        } else if (value == 'add_to_queue') {
                                          playerController.addToQueue(songData);
                                        } else if (value == 'go_to_queue') {
                                          showQueueSheet(context);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        PopupMenuItem(
                                          value: 'add_to_playlist',
                                          child: Row(
                                            children: const [
                                              Icon(
                                                Icons.playlist_add,
                                                color: Colors.white60,
                                                size: 30,
                                              ),
                                              SizedBox(width: 5),
                                              Text(
                                                'Add to Playlist',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'add_to_favorites',
                                          child: Row(
                                            children: [
                                              Icon(
                                                _favoriteSongKeys.contains(
                                                      _songKey(song),
                                                    )
                                                    ? Icons.check_circle_rounded
                                                    : Icons
                                                          .add_circle_outline_outlined,
                                                color:
                                                    _favoriteSongKeys.contains(
                                                      _songKey(song),
                                                    )
                                                    ? Colors.white
                                                    : Colors.white60,
                                              ),
                                              const SizedBox(width: 5),
                                              const Text(
                                                'Add to Favorites',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'add_to_queue',
                                          child: Row(
                                            children: const [
                                              Icon(
                                                Icons.queue,
                                                color: Colors.white60,
                                              ),
                                              SizedBox(width: 5),
                                              Text(
                                                'Add to Queue',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'go_to_queue',
                                          child: Row(
                                            children: const [
                                              Icon(
                                                Icons.queue_music_rounded,
                                                color: Colors.white60,
                                              ),
                                              SizedBox(width: 5),
                                              Text(
                                                'Go to Queue',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'check_info',
                                          child: Row(
                                            children: const [
                                              Icon(
                                                Icons.info_outline_rounded,
                                                color: Colors.white60,
                                              ),
                                              SizedBox(width: 5),
                                              Text(
                                                'Check Info',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 5),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          Align(
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
                          var tween = Tween(
                            begin: begin,
                            end: end,
                          ).chain(CurveTween(curve: curve));
                          return SlideTransition(
                            position: animation.drive(tween),
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
                    final resolvedDisplayArtUrl = ImageUtils.resolveUrl(
                      displayArtUrl?.toString(),
                    );

                    return Row(
                      children: [
                        const SizedBox(width: 10),
                        Container(
                          height: 100,
                          width: 100,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: resolvedDisplayArtUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: CachedNetworkImage(
                                    imageUrl: resolvedDisplayArtUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) =>
                                        ImageUtils.placeholder(iconSize: 50),
                                    errorWidget: (_, __, ___) =>
                                        ImageUtils.placeholder(iconSize: 50),
                                  ),
                                )
                              : const Icon(
                                  Icons.music_note_sharp,
                                  color: Color.fromARGB(148, 148, 132, 209),
                                  size: 50,
                                ),
                        ),
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
                                  color: Color.fromARGB(179, 255, 255, 255),
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
          ),
        ],
      ),
    );
  }
}
