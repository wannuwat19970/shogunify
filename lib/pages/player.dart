import 'package:flutter/material.dart';
import 'package:shogunify/controllers/provider.dart';
import 'package:provider/provider.dart';
import 'package:shogunify/controllers/states.dart';
import 'package:shogunify/controllers/auth_controller.dart';
import 'package:shogunify/services/music_service.dart';
import 'package:shogunify/pages/playlists.dart';
import 'package:shogunify/controllers/queue_sheet.dart';

//import 'package:google_fonts/google_fonts.dart';

class PlayPause extends StatefulWidget {
  const PlayPause({super.key});

  @override
  State<PlayPause> createState() => _PlayPauseState();
}

class _PlayPauseState extends State<PlayPause> {
  final Set<String> _favoriteSongKeys = <String>{};

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString();
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<PlayerController>(context);

    // Pull current song map from player queue
    final currentSongMap =
        (player.songQueue.isNotEmpty &&
            player.currentIndex < player.songQueue.length)
        ? player.songQueue[player.currentIndex]
        : null;

    final songTitle = currentSongMap?['title'] ?? "No song playing";
    final songArtist = currentSongMap?['artist'] != null
        ? "- ${currentSongMap!['artist']}"
        : "- ArtistUnknown";
    final albumArtUrl = currentSongMap?['album_art_url'];

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 18, 18, 18),
      body: Stack(
        children: [
          // Album Art Box
          Align(
            alignment: const Alignment(0, -0.5),
            child: Container(
              height: 350,
              width: 350,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
              ),
              child: albumArtUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Image.network(
                        'https://music.wannuwatbot.com$albumArtUrl',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.music_note_sharp,
                              color: Color.fromARGB(255, 211, 211, 211),
                              size: 150,
                            ),
                      ),
                    )
                  : const Icon(
                      Icons.music_note_sharp,
                      color: Color.fromARGB(255, 211, 211, 211),
                      size: 150,
                    ),
            ),
          ),
          // Drag handle visual indicator
          Align(
            alignment: const Alignment(0, -0.89),
            child: Container(
              width: 70,
              height: 8,
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 81, 81, 81),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
          // Swipe down dismiss handle
          Align(
            alignment: const Alignment(0, -0.925),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragEnd: (details) {
                if (details.primaryVelocity != null &&
                    details.primaryVelocity! > 0) {
                  Navigator.pop(context);
                }
              },
              child: Container(
                width: 100,
                height: 50,
                color: Colors.transparent,
              ),
            ),
          ),
          // PLAY / PAUSE
          Align(
            alignment: const Alignment(0, 0.3),
            child: IconButton(
              icon: Icon(
                player.isPlaying
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_filled_rounded,
                color: Colors.white,
                size: 100,
              ),
              onPressed: () {
                if (player.isPlaying) {
                  player.pause();
                } else {
                  player.play();
                }
              },
            ),
          ),
          // NEXT
          Align(
            alignment: const Alignment(0.525, 0.285),
            child: GestureDetector(
              onTap: () => player.playNext(),
              child: const Icon(
                Icons.skip_next_rounded,
                color: Colors.white,
                size: 55,
              ),
            ),
          ),
          // PREVIOUS
          Align(
            alignment: const Alignment(-0.525, 0.285),
            child: GestureDetector(
              onTap: () => player.playPrevious(),
              child: const Icon(
                Icons.skip_previous_rounded,
                color: Colors.white,
                size: 55,
              ),
            ),
          ),
          // SHUFFLE
          Align(
            alignment: const Alignment(-0.85, 0.282),
            child: GestureDetector(
              onTap: () => player.toggleShuffle(),
              child: Icon(
                Icons.shuffle_rounded,
                color: player.isShuffling
                    ? const Color.fromARGB(255, 155, 140, 213)
                    : Colors.white,
                size: 30,
              ),
            ),
          ),
          const Align(
            alignment: Alignment(0.85, 0.282),
            child: Icon(Icons.timer_sharp, color: Colors.white, size: 30),
          ),
          Align(
            alignment: const Alignment(0.97, -0.9),
            child: GestureDetector(
              onTap: currentSongMap == null
                  ? null
                  : () => _showSongMenu(currentSongMap),
              child: const Icon(
                Icons.more_vert,
                color: Color.fromARGB(255, 120, 120, 120),
                size: 42,
              ),
            ),
          ),
          // SEEK BAR
          Align(
            alignment: const Alignment(0, 0.5),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 14,
                      ),
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      value: player.position.inSeconds.toDouble().clamp(
                        0,
                        player.duration.inSeconds.toDouble() == 0
                            ? 1
                            : player.duration.inSeconds.toDouble(),
                      ),
                      min: 0,
                      max: player.duration.inSeconds.toDouble() == 0
                          ? 1
                          : player.duration.inSeconds.toDouble(),
                      onChanged: (double value) {
                        player.seek(Duration(seconds: value.toInt()));
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(player.position),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _formatDuration(player.duration),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // SONG TITLE
          Positioned(
            bottom: 160,
            left: 20,
            child: Text(
              songTitle.length > 20
                  ? '${songTitle.substring(0, 20)}...'
                  : songTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Align(
          //   alignment: const Alignment(-0.8, 0.62),
          //   child: Text(
          //     songTitle,
          //     style: const TextStyle(
          //       color: Colors.white,
          //       fontSize: 30,
          //       fontWeight: FontWeight.bold,
          //     ),
          //     overflow: TextOverflow.ellipsis,
          //   ),
          // ),
          // ARTIST
          Positioned(
            bottom: 140,
            left: 20,
            child: Text(
              songArtist.length > 20
                  ? '${songArtist.substring(0, 20)}...'
                  : songArtist,
              style: const TextStyle(
                color: Color.fromARGB(179, 255, 255, 255),
                fontSize: 16,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // TAGS PLACEHOLDER (Only shown on player page)
          Positioned(
            bottom: 108,
            left: 20,
            right: 20,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...((currentSongMap?['tags'] as List?)?.map(
                            (t) => t.toString(),
                          ) ??
                          [
                            '#${(currentSongMap?['artist']?.toString() ?? 'Music').replaceAll(RegExp(r'\s+'), '')}',
                            '#Shogunify',
                          ])
                      .map(
                        (tag) => Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF483D73).withOpacity(0.4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF9384D1).withOpacity(0.4),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            tag.startsWith('#') ? tag : '#$tag',
                            style: const TextStyle(
                              color: Color(0xFFD4C7FF),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
          // Align(
          //   alignment: const Alignment(-0.83, 0.68),
          //   child: Text(
          //     songArtist.length > 20
          //         ? '${songArtist.substring(0, 40)}...'
          //         : songArtist,
          //     style: const TextStyle(
          //       color: Color.fromARGB(179, 255, 255, 255),
          //       fontSize: 18,
          //     ),
          //     overflow: TextOverflow.ellipsis,
          //   ),
          // ),
          Positioned(
            bottom: 160,
            right: 30,
            child: GestureDetector(
              onTap: currentSongMap == null
                  ? null
                  : () => _addToFavorites(currentSongMap),
              child: Icon(
                currentSongMap != null &&
                        _favoriteSongKeys.contains(_songKey(currentSongMap))
                    ? Icons.check_circle_outline_rounded
                    : Icons.add_circle_outline_rounded,
                color: Colors.white,
                size: 35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _songKey(Map<String, dynamic> song) =>
      (song['id'] ?? song['song_id'] ?? song['filename'] ?? '').toString();

  Future<int?> _resolveSongId(Map<String, dynamic> song) async {
    final direct =
        (song['id'] as num?)?.toInt() ?? (song['song_id'] as num?)?.toInt();
    if (direct != null) return direct;
    final filename = song['filename']?.toString();
    if (filename == null || filename.isEmpty) return null;
    final allSongs = await MusicService.fetchSongs();
    final match = allSongs.firstWhere(
      (s) => s['filename']?.toString() == filename,
      orElse: () => const {},
    );
    return (match['id'] as num?)?.toInt();
  }

  Future<void> _addToFavorites(Map<String, dynamic> song) async {
    final token = Provider.of<AuthController>(context, listen: false).token;
    if (token == null) return;
    try {
      final songId = await _resolveSongId(song);
      if (songId == null) throw Exception('Song ID not found.');

      final playlists = await PlaylistService.fetchPlaylists(token);
      final favorites = playlists.cast<Playlist?>().firstWhere(
        (p) => p!.name.trim().toLowerCase() == 'favorites',
        orElse: () => null,
      );
      if (favorites == null) {
        throw Exception('Favorites playlist was not found.');
      }

      await PlaylistService.addSong(
        playlistId: favorites.id,
        songId: songId,
        token: token,
      );
      if (!mounted) return;
      setState(() => _favoriteSongKeys.add(_songKey(song)));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Added to Favorites.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  void _showSongMenu(Map<String, dynamic> song) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF2D2D2D),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 6),

                ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(vertical: -2),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  minLeadingWidth: 32,
                  horizontalTitleGap: 8,
                  leading: const Icon(
                    Icons.playlist_add,
                    color: Colors.white60,
                    size: 24,
                  ),
                  title: const Text(
                    'Add to Playlist',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showPlaylistSelectionDialog(song);
                  },
                ),

                ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(vertical: -2),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  minLeadingWidth: 32,
                  horizontalTitleGap: 8,
                  leading: Icon(
                    _favoriteSongKeys.contains(_songKey(song))
                        ? Icons.check_circle_rounded
                        : Icons.add_circle_outline_rounded,
                    color: Colors.white60,
                    size: 24,
                  ),
                  title: const Text(
                    'Add to Favorites',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _addToFavorites(song);
                  },
                ),

                ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(vertical: -2),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  minLeadingWidth: 32,
                  horizontalTitleGap: 8,
                  leading: const Icon(
                    Icons.queue,
                    color: Colors.white60,
                    size: 24,
                  ),
                  title: const Text(
                    'Add to Queue',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  onTap: () {
                    Provider.of<PlayerController>(
                      context,
                      listen: false,
                    ).addToQueue(song);

                    Navigator.pop(sheetContext);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Added to queue')),
                    );
                  },
                ),

                ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(vertical: -2),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  minLeadingWidth: 32,
                  horizontalTitleGap: 8,
                  leading: const Icon(
                    Icons.queue_music_rounded,
                    color: Colors.white60,
                    size: 24,
                  ),
                  title: const Text(
                    'Go to Queue',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    showQueueSheet(context);
                  },
                ),

                ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(vertical: -2),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  minLeadingWidth: 32,
                  horizontalTitleGap: 8,
                  leading: const Icon(
                    Icons.info_outline_rounded,
                    color: Colors.white60,
                    size: 24,
                  ),
                  title: const Text(
                    'Check Info',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);

                    showDialog<void>(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: const Color(0xFF211E28),
                        title: Text(
                          '${song['title'] ?? 'Unknown'}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        content: Text(
                          'Artist: ${song['artist'] ?? 'Unknown artist'}\n'
                          'File: ${song['filename'] ?? ''}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addSongToPlaylist(
    String token,
    Playlist playlist,
    Map<String, dynamic> song,
  ) async {
    final songId = await _resolveSongId(song);
    if (songId == null) {
      throw Exception('Song ID not found.');
    }

    await PlaylistService.addSong(
      playlistId: playlist.id,
      songId: songId,
      token: token,
    );
  }

  Future<void> _showPlaylistSelectionDialog(Map<String, dynamic> song) async {
    final auth = Provider.of<AuthController>(context, listen: false);

    final token = auth.token;
    if (token == null) return;

    await showAddToPlaylistDialog(context: context, token: token, song: song);
    /*
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                                  color: const Color(
                                                    0xFF302C38,
                                                  ),
                                                  child: Icon(
                                                    isFavorites
                                                        ? Icons.favorite
                                                        : Icons.queue_music,
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                          )
                                        : Container(
                                            color: const Color(0xFF302C38),
                                            child: Icon(
                                              isFavorites
                                                  ? Icons.favorite
                                                  : Icons.queue_music,
                                              color: Colors.white70,
                                            ),
                                          ),
                                  ),
                                ),

                                title: Text(
                                  playlist.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: alreadyAdded
                                        ? Colors.white54
                                        : Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),

                                subtitle: Text(
                                  alreadyAdded
                                      ? 'Already added'
                                      : '$songCount '
                                            '${songCount == 1 ? 'song' : 'songs'}',
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12,
                                  ),
                                ),

                                trailing: Icon(
                                  alreadyAdded
                                      ? Icons.check_circle_rounded
                                      : isFavorites
                                      ? Icons.favorite_border_rounded
                                      : Icons.add_circle_outline_rounded,
                                  color: alreadyAdded
                                      ? const Color.fromARGB(255, 147, 132, 209)
                                      : Colors.white,
                                ),

                                onTap: alreadyAdded
                                    ? null
                                    : () async {
                                        try {
                                          await _addSongToPlaylist(
                                            token,
                                            playlist,
                                            song,
                                          );

                                          if (!dialogContext.mounted) return;

                                          Navigator.of(dialogContext).pop();

                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Added to ${playlist.name}',
                                              ),
                                            ),
                                          );
                                        } catch (error) {
                                          if (!dialogContext.mounted) return;

                                          ScaffoldMessenger.of(
                                            dialogContext,
                                          ).showSnackBar(
                                            SnackBar(content: Text('$error')),
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
    */
  }
}
