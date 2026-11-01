import 'package:flutter/material.dart' hide RepeatMode;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:shogunify/controllers/image_utils.dart';
import 'package:shogunify/controllers/provider.dart';
import 'package:shogunify/pages/player.dart';
import 'package:shogunify/pages/playlists.dart';
import 'package:shogunify/services/music_service.dart';

import 'package:shogunify/controllers/states.dart';
import 'package:shogunify/controllers/queue_sheet.dart';

const _playlistPurpleLight = Color(0xFF9384D1);

class PlaylistDetail extends StatefulWidget {
  final int playlistId;
  final String token;

  const PlaylistDetail({
    super.key,
    required this.playlistId,
    required this.token,
  });

  @override
  State<PlaylistDetail> createState() => _PlaylistDetailState();
}

class _PlaylistDetailState extends State<PlaylistDetail> {
  late Future<Playlist> _playlistFuture;
  final ScrollController _playlistScrollController = ScrollController();
  int _visibleSongCount = 12;

  static const _purple = Color(0xFF483D73);
  static const _purpleLight = Color(0xFF9384D1);

  @override
  void initState() {
    super.initState();
    _playlistScrollController.addListener(_loadMoreSongsWhenNeeded);
    _reload();
  }

  @override
  void dispose() {
    _playlistScrollController.removeListener(_loadMoreSongsWhenNeeded);
    _playlistScrollController.dispose();
    super.dispose();
  }

  void _loadMoreSongsWhenNeeded() {
    if (!_playlistScrollController.hasClients ||
        _playlistScrollController.position.extentAfter > 500) {
      return;
    }
    setState(() {
      _visibleSongCount += 12;
    });
  }

  void _reload() {
    _playlistFuture = PlaylistService.fetchPlaylist(
      widget.playlistId,
      widget.token,
    );
  }

  List<Map<String, dynamic>> _playerSongs(List<Map<String, dynamic>> songs) {
    return songs
        .map(
          (song) => {
            'title': song['title'],
            'artist': song['artist'],
            'filename': song['filename'],
            'album_art_url': song['album_art_url'],
            'streamUrl': MusicService.getStreamUrl(song['filename'] ?? ''),
          },
        )
        .toList();
  }

  void _playSong(List<Map<String, dynamic>> songs, int index) {
    final player = context.read<PlayerController>();
    // The queue is replaced with this playlist only. No global library songs
    // are added here, and no repeat mode is changed.
    player.songQueue = _playerSongs(songs);
    player.playFromQueue(index);
  }

  bool _isPlaylistQueue(
    PlayerController player,
    List<Map<String, dynamic>> songs,
  ) {
    final queue = _playerSongs(songs);
    if (queue.length != player.songQueue.length) return false;
    return queue.asMap().entries.every(
      (entry) =>
          entry.value['filename'] == player.songQueue[entry.key]['filename'],
    );
  }

  Future<void> _togglePlaylistPlayback(List<Map<String, dynamic>> songs) async {
    final player = context.read<PlayerController>();
    if (_isPlaylistQueue(player, songs)) {
      if (player.isPlaying) {
        await player.pause();
      } else {
        await player.play();
      }
      return;
    }
    player.songQueue = _playerSongs(songs);
    if (songs.isNotEmpty) await player.playFromQueue(0);
  }

  Future<void> _addSongToPlaylist(Map<String, dynamic> song) async {
    await showAddToPlaylistDialog(
      context: context,
      token: widget.token,
      song: song,
      onSongAdded: () => setState(_reload),
    );
  }

  Future<void> _deletePlaylist() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF211E28),
        title: const Text(
          'Delete playlist?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will permanently delete the playlist and cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await PlaylistService.deletePlaylist(
        playlistId: widget.playlistId,
        token: widget.token,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _removeSong(Map<String, dynamic> song) async {
    final songId = (song['id'] as num?)?.toInt();
    if (songId == null) return;

    try {
      await PlaylistService.removeSong(
        playlistId: widget.playlistId,
        songId: songId,
        token: widget.token,
      );
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Removed from playlist')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  void _showSongMenu(
    Map<String, dynamic> song,
    List<Map<String, dynamic>> songs,
    int index,
  ) {
    final title = '${song['title'] ?? 'Unknown'}';
    final artist = song['artist'];
    final filename = '${song['filename'] ?? ''}';
    final albumArtUrl = song['album_art_url'];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF2D2D2D),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Row(
                  children: [
                    _SongArt(url: albumArtUrl?.toString(), size: 52),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${artist ?? 'Unknown artist'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white60),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _MenuItem(
                icon: Icons.playlist_add,
                label: 'Add to Playlist',
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _addSongToPlaylist(song);
                },
              ),
              _MenuItem(
                icon: Icons.add_circle_outline_outlined,
                label: 'Add to Favorites',
                onTap: () {
                  Navigator.pop(sheetContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Favorites action is not connected yet.'),
                    ),
                  );
                },
              ),
              _MenuItem(
                icon: Icons.queue,
                label: 'Add to Queue',
                onTap: () {
                  final player = context.read<PlayerController>();
                  player.addToQueue({
                    'title': title,
                    'artist': artist,
                    'filename': filename,
                    'album_art_url': albumArtUrl,
                    'streamUrl': MusicService.getStreamUrl(filename),
                  });
                  Navigator.pop(sheetContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Added to queue')),
                  );
                },
              ),
              _MenuItem(
                icon: Icons.queue_music_rounded,
                label: 'Go to Queue',
                onTap: () {
                  Navigator.pop(sheetContext);
                  showQueueSheet(context);
                },
              ),
              _MenuItem(
                icon: Icons.info_outline_rounded,
                label: 'Check Info',
                onTap: () {
                  Navigator.pop(sheetContext);
                  showDialog<void>(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: const Color(0xFF211E28),
                      title: Text(
                        title,
                        style: const TextStyle(color: Colors.white),
                      ),
                      content: Text(
                        'Artist: ${artist ?? 'Unknown artist'}\nFile: $filename',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  );
                },
              ),
              _MenuItem(
                icon: Icons.delete_outline,
                label: 'Remove from Playlist',
                iconColor: Colors.redAccent,
                labelColor: Colors.redAccent,
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _removeSong(song);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Delete playlist',
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: _deletePlaylist,
          ),
        ],
      ),
      body: FutureBuilder<Playlist>(
        future: _playlistFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _purpleLight),
            );
          }
          if (snapshot.hasError) {
            return _ErrorState(
              message: '${snapshot.error}',
              onRetry: () => setState(_reload),
            );
          }

          final playlist = snapshot.data!;
          final songs = playlist.songs;

          return Stack(
            children: [
              RefreshIndicator(
                color: _purpleLight,
                backgroundColor: _purple,
                onRefresh: () async => setState(_reload),
                child: ListView(
                  controller: _playlistScrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 170),
                  children: [
                    _PlaylistHeader(
                      playlist: playlist,
                      songCount: songs.length,
                      onPlayPause: () => _togglePlaylistPlayback(songs),
                    ),
                    const SizedBox(height: 24),
                    if (songs.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            'No songs yet. Add songs from the song menu.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      )
                    else
                      ...() {
                        final visibleSongs = songs
                            .take(_visibleSongCount)
                            .toList();
                        return visibleSongs.asMap().entries.map((entry) {
                          final index = entry.key;
                          final song = entry.value;
                          return _PlaylistSongTile(
                            song: song,
                            onTap: () => _playSong(songs, index),
                            onMenu: () => _showSongMenu(song, songs, index),
                            onRemove: () => _removeSong(song),
                          );
                        });
                      }(),
                  ],
                ),
              ),
              const Positioned(
                left: 12,
                right: 12,
                bottom: 14,
                child: _MiniPlayer(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class AnotherPlayPause extends StatefulWidget {
  const AnotherPlayPause({super.key});

  @override
  State<AnotherPlayPause> createState() => _AnotherPlayPauseState();
}

class _AnotherPlayPauseState extends State<AnotherPlayPause> {
  @override
  Widget build(BuildContext context) {
    final player = Provider.of<PlayerController>(context);
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: 60,
            right: 6,
            child: IconButton(
              iconSize: 60,
              icon: Icon(
                player.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
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
        ],
      ),
    );
  }
}

class _PlaylistHeader extends StatelessWidget {
  final Playlist playlist;
  final int songCount;
  final VoidCallback onPlayPause;

  const _PlaylistHeader({
    required this.playlist,
    required this.songCount,
    required this.onPlayPause,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _PlaylistCoverImage(
              title: playlist.name,
              imageUrl: playlist.coverArtUrl,
              fallbackImageUrl: playlist.songs.isNotEmpty
                  ? playlist.songs.first['album_art_url']?.toString()
                  : null,
              size: 148,
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PLAYLIST',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    playlist.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (playlist.description?.isNotEmpty == true) ...[
                    const SizedBox(height: 6),
                    Text(
                      playlist.description!,
                      style: const TextStyle(color: Colors.white60),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '$songCount ${songCount == 1 ? 'song' : 'songs'}',
                    style: const TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Consumer<PlayerController>(
          builder: (context, player, _) => Row(
            children: [
              _PlayerIconBox(
                icon: Icons.shuffle_rounded,
                active: player.isShuffling,
                onTap: player.toggleShuffle,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: playlist.songs.isEmpty ? null : onPlayPause,
                    style: FilledButton.styleFrom(
                      backgroundColor: _playlistPurpleLight,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: Icon(
                      player.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 30,
                    ),
                    label: Text(
                      player.isPlaying ? 'Pause' : 'Play',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _PlayerIconBox(
                icon: player.repeatMode == RepeatMode.one
                    ? Icons.repeat_one_rounded
                    : Icons.repeat_rounded,
                active: player.repeatMode != RepeatMode.off,
                onTap: player.cycleRepeatMode,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlayerIconBox extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _PlayerIconBox({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: active ? _playlistPurpleLight : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? _playlistPurpleLight : const Color(0xFF3A3A3A),
          ),
        ),
        child: Icon(
          icon,
          color: active ? Colors.black : Colors.white70,
          size: 26,
        ),
      ),
    );
  }
}

class _PlaylistCoverImage extends StatefulWidget {
  final String title;
  final String? imageUrl;
  final String? fallbackImageUrl;
  final double size;

  const _PlaylistCoverImage({
    required this.title,
    required this.imageUrl,
    this.fallbackImageUrl,
    required this.size,
  });

  @override
  State<_PlaylistCoverImage> createState() => _PlaylistCoverImageState();
}

class _PlaylistCoverImageState extends State<_PlaylistCoverImage> {
  @override
  Widget build(BuildContext context) {
    final url =
        ImageUtils.resolveUrl(widget.imageUrl) ??
        ImageUtils.resolveUrl(widget.fallbackImageUrl);
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url != null)
              CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => _fallback(),
                errorWidget: (_, __, ___) => _fallback(),
              )
            else
              _fallback(),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color.fromRGBO(0, 0, 0, .75)],
                  stops: [0.70, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 12,
              child: Text(
                widget.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallback() => Container(
    decoration: const BoxDecoration(
      gradient: RadialGradient(
        center: Alignment(-.65, -.75),
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

class _PlaylistSongTile extends StatelessWidget {
  final Map<String, dynamic> song;
  final VoidCallback onTap;
  final VoidCallback onMenu;
  final VoidCallback onRemove;

  const _PlaylistSongTile({
    required this.song,
    required this.onTap,
    required this.onMenu,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerController>(
      builder: (context, player, _) {
        final filename = song['filename']?.toString();
        final active =
            filename != null &&
            player.currentIndex >= 0 &&
            player.currentIndex < player.songQueue.length &&
            player.songQueue[player.currentIndex]['filename']?.toString() ==
                filename;
        return Dismissible(
          key: ValueKey('playlist-${song['id']}-${song['filename']}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            color: Colors.redAccent,
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          confirmDismiss: (_) async {
            onRemove();
            return false;
          },
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            onTap: onTap,
            leading: Stack(
              alignment: Alignment.center,
              children: [
                _SongArt(url: song['album_art_url']?.toString()),
                if (active && player.isPlaying)
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.volume_up_rounded,
                      color: _playlistPurpleLight,
                      size: 28,
                    ),
                  ),
              ],
            ),
            title: Text(
              '${song['title'] ?? 'Unknown'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active ? _playlistPurpleLight : Colors.white,
                fontWeight: active ? FontWeight.bold : FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '${song['artist'] ?? 'Unknown artist'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54),
            ),
            trailing: IconButton(
              icon: const Icon(
                Icons.more_vert,
                color: Colors.white70,
                size: 30,
              ),
              onPressed: onMenu,
            ),
          ),
        );
      },
    );
  }
}

class _SongArt extends StatelessWidget {
  final String? url;
  final double size;

  const _SongArt({this.url, this.size = 54});

  @override
  Widget build(BuildContext context) {
    final imageUrl = ImageUtils.resolveUrl(url);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: size,
        height: size,
        child: imageUrl == null
            ? ImageUtils.placeholder(iconSize: 28)
            : CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => ImageUtils.placeholder(iconSize: 28),
                errorWidget: (_, __, ___) =>
                    ImageUtils.placeholder(iconSize: 28),
              ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;
  final Color labelColor;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor = Colors.white60,
    this.labelColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -3),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      leading: Icon(icon, color: iconColor),
      title: Text(label, style: TextStyle(color: labelColor, fontSize: 16)),
      onTap: onTap,
    );
  }
}

class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer();

  Widget _buildAlbumArt(
    String? imageUrl, {
    double size = 100,
    double radius = 20,
  }) {
    final fullUrl = ImageUtils.resolveUrl(imageUrl);

    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: fullUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: CachedNetworkImage(
                imageUrl: fullUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => ImageUtils.placeholder(iconSize: 50),
                errorWidget: (_, __, ___) =>
                    ImageUtils.placeholder(iconSize: 50),
              ),
            )
          : const Icon(
              Icons.music_note_sharp,
              color: Color(0xFF9384D1),
              size: 50,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PlayPause()),
      ),
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
                player.songQueue.isNotEmpty &&
                    player.currentIndex >= 0 &&
                    player.currentIndex < player.songQueue.length
                ? player.songQueue[player.currentIndex]
                : null;
            final displayTitle = currentSongMap?['title'] ?? 'No song playing';
            final displayArtist = currentSongMap?['artist'] != null
                ? '- ${currentSongMap!['artist']}'
                : '- ArtistUnknown';
            final displayArtUrl = currentSongMap?['album_art_url']?.toString();

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
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        displayArtist.length > 20
                            ? '${displayArtist.substring(0, 20)}...'
                            : displayArtist,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color.fromARGB(179, 255, 255, 255),
                          fontSize: 14,
                        ),
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
                  onPressed: () =>
                      player.isPlaying ? player.pause() : player.play(),
                ),
                const SizedBox(width: 10),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off, color: Colors.white54, size: 44),
        const SizedBox(height: 12),
        Text(
          message,
          style: const TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}
