//providers.dart

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';

enum RepeatMode { off, all, one }

class PlayerController extends BaseAudioHandler with ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  bool isPlaying = false;
  bool isRepeating = false;
  String currentSong = "No song";
  String? currentArtist;
  String? currentAlbumArtUrl;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  // Add alongside the other fields:
  bool isShuffling = false;
  RepeatMode repeatMode = RepeatMode.off;
  List<Map<String, dynamic>>? _unshuffledQueue;

  void toggleShuffle() {
    if (isShuffling) {
      final current = (currentIndex >= 0 && currentIndex < songQueue.length)
          ? songQueue[currentIndex]
          : null;
      if (_unshuffledQueue != null) {
        songQueue = List<Map<String, dynamic>>.from(_unshuffledQueue!);
      }
      _unshuffledQueue = null;
      if (current != null) {
        final restoredIndex = songQueue.indexWhere(
          (s) => s['streamUrl'] == current['streamUrl'],
        );
        currentIndex = restoredIndex >= 0 ? restoredIndex : currentIndex;
      }
      isShuffling = false;
    } else {
      _unshuffledQueue = List<Map<String, dynamic>>.from(songQueue);
      final current = (currentIndex >= 0 && currentIndex < songQueue.length)
          ? songQueue[currentIndex]
          : null;
      final shuffled = List<Map<String, dynamic>>.from(songQueue)..shuffle();
      if (current != null) {
        shuffled.removeWhere((s) => s['streamUrl'] == current['streamUrl']);
        shuffled.insert(0, current);
        currentIndex = 0;
      }
      songQueue = shuffled;
      isShuffling = true;
    }
    notifyListeners();
  }

  void cycleRepeatMode() {
    repeatMode = switch (repeatMode) {
      RepeatMode.off => RepeatMode.all,
      RepeatMode.all => RepeatMode.one,
      RepeatMode.one => RepeatMode.off,
    };
    isRepeating = repeatMode == RepeatMode.one;
    _player.setLoopMode(
      repeatMode == RepeatMode.one ? LoopMode.one : LoopMode.off,
    );
    notifyListeners();
  }

  Future<void> playNext() async {
    if (songQueue.isEmpty) return;
    if (currentIndex + 1 < songQueue.length) {
      await playFromQueue(currentIndex + 1);
    } else if (repeatMode == RepeatMode.all) {
      // Loop back to the first song when at the end of the queue
      await playFromQueue(0);
    }
  }

  List<Map<String, dynamic>> songQueue = [];
  int currentIndex = -1;

  PlayerController() {
    _player.positionStream.listen((pos) {
      position = pos;
      notifyListeners();

      playbackState.add(
        playbackState.value.copyWith(
          updatePosition: pos,
          bufferedPosition: _player.bufferedPosition,
        ),
      );
    });

    _player.durationStream.listen((dur) {
      duration = dur ?? Duration.zero;
      notifyListeners();

      final current = mediaItem.value;
      if (current != null) {
        mediaItem.add(current.copyWith(duration: duration));
      }
    });

    _player.playerStateStream.listen((state) {
      // Update OUR field, not just the OS-facing one — this fixes the in-app button sync bug
      isPlaying = state.playing;
      notifyListeners();

      playbackState.add(
        playbackState.value.copyWith(
          controls: [
            MediaControl.skipToPrevious,
            state.playing ? MediaControl.pause : MediaControl.play,
            MediaControl.skipToNext,
          ],
          systemActions: const {
            MediaAction.seek,
            MediaAction.skipToPrevious,
            MediaAction.skipToNext,
          },
          androidCompactActionIndices: const [0, 1, 2],
          processingState: {
            ProcessingState.idle: AudioProcessingState.idle,
            ProcessingState.loading: AudioProcessingState.loading,
            ProcessingState.buffering: AudioProcessingState.buffering,
            ProcessingState.ready: AudioProcessingState.ready,
            ProcessingState.completed: AudioProcessingState.completed,
          }[state.processingState]!,
          playing: state.playing,
          updatePosition: _player.position,
          bufferedPosition: _player.bufferedPosition,
          speed: _player.speed,
        ),
      );

      // AUTO-ADVANCE: handle song completion based on active repeat mode
      if (state.processingState == ProcessingState.completed) {
        if (repeatMode == RepeatMode.one) {
          _player.seek(Duration.zero);
          _player.play();
        } else {
          playNext();
        }
      }
    });
  }

  Future<void> playSong(String url) async {
    currentSong = url;
    notifyListeners();
    await _player.setUrl(url);
    await _player.play();
    isPlaying = true;
    notifyListeners();
  }

  @override
  Future<void> play() async {
    isPlaying = true;
    notifyListeners();
    await _player.play();
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
    notifyListeners();
    await _player.pause();
  }

  Future<void> stop2() async {
    await _player.stop();
    isPlaying = false;
    notifyListeners();
  }

  @override
  Future<void> seek(Duration newPosition) async {
    await _player.seek(newPosition);
  }

  @override
  Future<void> skipToNext() async {
    await playNext();
  }

  @override
  Future<void> skipToPrevious() async {
    await playPrevious();
  }

  Future<void> toggleRepeat() async {
    isRepeating = !isRepeating;
    if (isRepeating) {
      await _player.setLoopMode(LoopMode.one);
    } else {
      await _player.setLoopMode(LoopMode.off);
    }
    notifyListeners();
  }

  void addToQueue(Map<String, dynamic> song) {
    songQueue.add(song);
    notifyListeners();
  }

  void playNextInQueue(Map<String, dynamic> song) {
    if (currentIndex + 1 <= songQueue.length) {
      songQueue.insert(currentIndex + 1, song);
    } else {
      songQueue.add(song);
    }
    notifyListeners();
  }

  Future<void> playFromQueue(int index) async {
    if (index < 0 || index >= songQueue.length) return;
    currentIndex = index;
    final song = songQueue[index];
    currentArtist = song['artist'];
    currentAlbumArtUrl = song['album_art_url'];

    mediaItem.add(
      MediaItem(
        id: song['streamUrl'],
        title: song['title'] ?? 'Unknown',
        artist: song['artist'] ?? 'Unknown Artist',
        artUri: song['album_art_url'] != null
            ? Uri.parse('https://music.wannuwatbot.com${song['album_art_url']}')
            : null,
      ),
    );

    await playSong(song['streamUrl']);
  }

  Future<void> playPrevious() async {
    if (songQueue.isEmpty) return;
    if (currentIndex - 1 >= 0) {
      await playFromQueue(currentIndex - 1);
    }
  }
}
