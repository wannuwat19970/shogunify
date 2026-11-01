import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shogunify/controllers/image_utils.dart';

class Addsongs extends StatefulWidget {
  const Addsongs({super.key});

  @override
  State<Addsongs> createState() => _AddsongsState();
}

class _AddsongsState extends State<Addsongs>
    with SingleTickerProviderStateMixin {
  static const String _baseUrl = 'https://music.wannuwatbot.com';
  static const Duration _previewLength = Duration(seconds: 15);

  final _urlController = TextEditingController();
  final _titleController = TextEditingController();
  final _artistController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _previewPlayer = AudioPlayer();

  late final AnimationController _shakeController;
  StreamSubscription<PlayerState>? _playerSubscription;

  bool _isImporting = false;
  bool _isSaving = false;
  bool _isPlaying = false;
  bool _isPreviewReady = false;
  bool _isClosing = false;
  bool _showAllCovers = false; // Controls grid expansion

  String? _previewToken;
  String? _sourceTitle;
  String? _previewUrl;
  String? _urlError;
  String? _titleError;
  String? _artistError;
  String? _generalError;
  File? _pickedCover;
  String? _selectedExistingCover;
  List<String> _existingCovers = [];
  List<String> _registeredArtists = [];

  final _tagInputController = TextEditingController();
  final List<String> _tags = [];
  String? _tagError;

  static final RegExp _validTagRegex = RegExp(r'^#[A-Za-z0-9_\-]+$');

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _playerSubscription = _previewPlayer.playerStateStream.listen((state) {
      if (!mounted) return;
      if (state.processingState == ProcessingState.completed) {
        setState(() => _isPlaying = false);
        _previewPlayer.seek(Duration.zero);
      } else if (state.playing != _isPlaying) {
        setState(() => _isPlaying = state.playing);
      }
    });
    _artistController.addListener(_onArtistChanged);
    _loadExistingCovers();
  }

  void _onArtistChanged() {
    if (mounted) setState(() {});
  }

  String? get _artistSuggestion {
    final query = _artistController.text;
    if (query.trim().isEmpty) return null;
    final lower = query.toLowerCase();
    for (final artist in _registeredArtists) {
      if (artist.toLowerCase().startsWith(lower) &&
          artist.length > query.length) {
        return artist;
      }
    }
    return null;
  }

  void _addTag(String raw) {
    var tag = raw.trim();
    if (tag.isEmpty) return;

    if (!tag.startsWith('#')) {
      tag = '#$tag';
    }

    if (tag.contains(' ')) {
      setState(() {
        _tagError =
            'Tags cannot contain spaces (e.g. #ThaiSong, not #thai song)';
      });
      return;
    }

    if (!_validTagRegex.hasMatch(tag)) {
      setState(() {
        _tagError =
            'Only letters, numbers, _ and - are allowed (e.g. #ThaiSong)';
      });
      return;
    }

    if (!_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagError = null;
        _tagInputController.clear();
      });
    } else {
      _tagInputController.clear();
    }
  }

  @override
  void dispose() {
    _playerSubscription?.cancel();
    _previewPlayer.dispose();
    _shakeController.dispose();
    _urlController.dispose();
    _titleController.dispose();
    _artistController.removeListener(_onArtistChanged);
    _artistController.dispose();
    _tagInputController.dispose();
    super.dispose();
  }

  String _absoluteUrl(String path) {
    final value = path.trim();
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return Uri.parse('$_baseUrl/').resolve(value).toString();
  }

  Future<void> _loadExistingCovers() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/songs'));
      if (response.statusCode != 200) return;
      final decoded = jsonDecode(response.body);
      if (decoded is! List) return;
      final covers = <String>{};
      final artists = <String>{};
      for (final item in decoded) {
        if (item is Map) {
          if (item['album_art_url'] is String) {
            covers.add(_absoluteUrl(item['album_art_url'] as String));
          }
          if (item['artist'] is String &&
              (item['artist'] as String).trim().isNotEmpty) {
            artists.add((item['artist'] as String).trim());
          }
        }
      }
      if (mounted) {
        setState(() {
          _existingCovers = covers.toList();
          _registeredArtists = artists.toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        });
      }
    } catch (error) {
      debugPrint('Could not load existing covers: $error');
    }
  }

  /// Returns the YouTube video ID for the common URL formats, or null when
  /// the input is not a YouTube video URL.
  String? _extractYoutubeId(String value) {
    var input = value.trim();
    if (input.isEmpty) return null;

    // Uri.host is empty when users paste `youtube.com/watch?v=...` without
    // the scheme, so add one before parsing.
    if (!input.contains('://')) input = 'https://$input';
    final uri = Uri.tryParse(input);
    if (uri == null) return null;

    final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    String? id;
    if (host == 'youtu.be') {
      id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    } else if (host == 'youtube.com' ||
        host == 'm.youtube.com' ||
        host == 'music.youtube.com' ||
        host == 'youtube-nocookie.com') {
      if (uri.path == '/watch') {
        id = uri.queryParameters['v'];
      } else if (uri.pathSegments.length >= 2 &&
          (uri.pathSegments.first == 'shorts' ||
              uri.pathSegments.first == 'embed' ||
              uri.pathSegments.first == 'live')) {
        id = uri.pathSegments[1];
      }
    }

    if (id == null) return null;
    // Remove accidental whitespace but do not accept arbitrary text.
    id = id.trim();
    return RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id) ? id : null;
  }

  String _youtubeCanonicalUrl(String value) {
    final id = _extractYoutubeId(value);
    return id == null ? value.trim() : 'https://www.youtube.com/watch?v=$id';
  }

  String _serverErrorMessage(http.Response response) {
    final body = _jsonBody(response);
    final error = body?['error'];
    if (error is Map && error['message'] is String) {
      return error['message'] as String;
    }
    if (error is String && error.isNotEmpty) return error;
    if (body?['message'] is String) return body!['message'] as String;
    return 'YouTube import failed (${response.statusCode}).';
  }

  void _shake() => _shakeController.forward(from: 0);

  void _clearErrors() {
    if (!mounted) return;
    setState(() {
      _urlError = null;
      _titleError = null;
      _artistError = null;
      _generalError = null;
    });
  }

  void _setFieldError({
    String? url,
    String? title,
    String? artist,
    String? general,
  }) {
    if (!mounted) return;
    setState(() {
      _urlError = url;
      _titleError = title;
      _artistError = artist;
      _generalError = general;
    });
    _shake();
  }

  Future<void> _importYoutube() async {
    final input = _urlController.text.trim();
    final videoId = _extractYoutubeId(input);
    if (videoId == null) {
      _setFieldError(url: '*** Please enter a valid YouTube URL. ***');
      return;
    }

    await _stopPreview();
    await _deletePreviewOnly();
    if (!mounted) return;
    setState(() {
      _isImporting = true;
      _isPreviewReady = false;
      _sourceTitle = null;
      _previewUrl = null;
      _previewToken = null;
      _titleController.clear();
      _artistController.clear();
    });
    _clearErrors();

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/import/youtube/preview'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'url': _youtubeCanonicalUrl(input)}),
          )
          .timeout(const Duration(seconds: 45));
      final body = _jsonBody(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(_serverErrorMessage(response));
      }
      if (body == null) {
        throw Exception('The server returned invalid JSON.');
      }
      final token = body?['preview_token'] as String?;
      final sourceTitle = body?['source_title'] as String?;
      final previewPath = body?['preview_url'] as String?;
      if (token == null || previewPath == null) {
        throw Exception('The server returned an incomplete preview.');
      }
      final resolvedPreviewUrl = _absoluteUrl(previewPath);
      await _previewPlayer.setUrl(resolvedPreviewUrl);

      if (!mounted) return;
      setState(() {
        _previewToken = token;
        _sourceTitle = sourceTitle;
        _previewUrl = resolvedPreviewUrl;
        _isPreviewReady = true;
      });
      if (sourceTitle != null && sourceTitle.isNotEmpty) {
        _showNotification(sourceTitle);
      }
    } on TimeoutException {
      _setFieldError(
        url: 'YouTube preview request timed out. Please try again.',
      );
    } catch (error) {
      debugPrint('YouTube preview error: $error');
      _setFieldError(url: 'Could not fetch YouTube preview: $error');
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Map<String, dynamic>? _jsonBody(http.Response response) {
    try {
      final value = jsonDecode(response.body);
      return value is Map<String, dynamic> ? value : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _togglePreview() async {
    if (!_isPreviewReady || _isSaving) return;
    try {
      if (_previewPlayer.playing) {
        await _previewPlayer.pause();
      } else {
        if (_previewPlayer.position >= _previewLength) {
          await _previewPlayer.seek(Duration.zero);
        }
        await _previewPlayer.play();
      }
    } catch (error) {
      debugPrint('Preview playback error: $error');
      _setFieldError(general: 'The preview could not be played.');
    }
  }

  Future<void> _stopPreview() async {
    await _previewPlayer.stop();
    if (mounted) setState(() => _isPlaying = false);
  }

  Future<void> _deletePreviewOnly() async {
    final token = _previewToken;
    _previewToken = null;
    _previewUrl = null;
    _isPreviewReady = false;
    if (token == null) return;
    try {
      await http.delete(Uri.parse('$_baseUrl/api/import/preview/$token'));
    } catch (error) {
      debugPrint('Preview cleanup failed: $error');
    }
  }

  Future<void> _cancelAndClose() async {
    if (_isClosing) return;
    _isClosing = true;
    await _stopPreview();
    await _deletePreviewOnly();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickCover(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (picked != null && mounted) {
        setState(() {
          _pickedCover = File(picked.path);
          _selectedExistingCover = null;
        });
      }
    } catch (error) {
      _setFieldError(general: 'Could not select that image.');
    }
  }

  Future<void> _showCoverPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF242424),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white),
              title: const Text(
                'Take a picture',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickCover(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: const Text(
                'Choose from gallery',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickCover(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSong() async {
    final title = _titleController.text.trim();
    final artist = _artistController.text.trim();
    String? titleError;
    String? artistError;
    if (!_isPreviewReady || _previewToken == null) {
      _setFieldError(general: 'Fetch a YouTube preview before saving.');
      return;
    }
    if (title.isEmpty) titleError = 'Enter a song title.';
    if (artist.isEmpty) artistError = 'Enter an artist name.';
    if (titleError != null || artistError != null) {
      _setFieldError(title: titleError, artist: artistError);
      return;
    }

    setState(() => _isSaving = true);
    _clearErrors();
    await _stopPreview();
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/songs'),
      );
      request.fields['preview_token'] = _previewToken!;
      request.fields['title'] = title;
      request.fields['artist'] = artist;
      
      final bool hasPickedCover = _pickedCover != null;
      final bool hasSelectedExisting = _selectedExistingCover != null;
      request.fields['use_generated_cover'] =
          (!hasPickedCover && !hasSelectedExisting).toString();
      
      if (hasSelectedExisting) {
        final fullUrl = _selectedExistingCover!;
        final uri = Uri.tryParse(fullUrl);
        final relativePath = (uri != null && uri.path.isNotEmpty) ? uri.path : fullUrl;
        final filename = (uri != null && uri.pathSegments.isNotEmpty) ? uri.pathSegments.last : fullUrl;

        request.fields['album_art_url'] = fullUrl;
        request.fields['cover_url'] = fullUrl;
        request.fields['cover_art_url'] = fullUrl;
        request.fields['existing_cover'] = fullUrl;
        request.fields['album_art_path'] = relativePath;
        request.fields['relative_cover_url'] = relativePath;
        request.fields['cover_filename'] = filename;
        request.fields['existing_album_art'] = relativePath;
      }
      if (hasPickedCover) {
        request.files.add(
          await http.MultipartFile.fromPath('album_art', _pickedCover!.path),
        );
      }
      if (_tags.isNotEmpty) {
        request.fields['tags'] = jsonEncode(_tags);
      }
      final response = await request.send();
      final body = jsonDecode(await response.stream.bytesToString());
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          body['error']?['message'] ?? 'Song could not be saved.',
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(body);
    } catch (error) {
      debugPrint('Save song error: $error');
      _setFieldError(general: 'Song could not be saved. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showNotification(String title) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        top: 60,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Align(
            alignment: Alignment.topLeft,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 320),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF2D2D2D),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF555555)),
              ),
              child: Text(
                'Fetched: $title',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (entry.mounted) entry.remove();
    });
  }

  Widget _animatedContent({required Widget child}) {
    return AnimatedBuilder(
      animation: _shakeController,
      builder: (_, child) {
        final offset =
            8 *
            (1 - _shakeController.value) *
            (0.5 - ((_shakeController.value * 5) % 1).abs());
        return Transform.translate(offset: Offset(offset, 0), child: child);
      },
      child: child,
    );
  }

  // Wrapper providing a thin outline border for all input fields
  Widget _borderedInputBox({
    required Widget child,
    bool isError = false,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: isError
                ? const Color.fromARGB(255, 60, 20, 20)
                : const Color.fromARGB(255, 34, 34, 34),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isError
                  ? Colors.redAccent
                  : const Color.fromARGB(255, 81, 81, 81),
              width: isError ? 1.5 : 1.0, // Thin outline
            ),
          ),
          child: child,
        ),
        if (errorText != null && errorText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 4),
            child: Text(
              errorText,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _coverTile(String? url, {required bool addTile}) {
    if (addTile) {
      return InkWell(
        onTap: _showCoverPicker,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF333333),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF555555), width: 1),
          ),
          child: const Icon(Icons.add, color: Colors.white70, size: 30),
        ),
      );
    }
    final selected = url == _selectedExistingCover;
    return InkWell(
      onTap: () => setState(() {
        _selectedExistingCover = url;
        _pickedCover = null;
      }),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.white : Colors.transparent,
            width: selected ? 3 : 1,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: selected ? const Color(0xFF222222) : Colors.transparent,
              width: selected ? 3 : 0,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Builder(
            builder: (_) {
              final resolvedUrl = ImageUtils.resolveUrl(url);
              if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
                return CachedNetworkImage(
                  imageUrl: resolvedUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _fallbackCover(),
                  errorWidget: (_, __, ___) => _fallbackCover(),
                );
              }
              return _fallbackCover();
            },
          ),
        ),
      ),
    );
  }

  Widget _fallbackCover() {
    return Container(
      color: Colors.grey[800],
      alignment: Alignment.center,
      child: const Icon(Icons.music_note, color: Colors.white54),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine maximum items to display in grid (1 add button + up to 11 covers = 12 total grid slots)
    final totalAvailable = _existingCovers.length + 1;
    final int displayCount = _showAllCovers
        ? totalAvailable
        : (totalAvailable > 12 ? 12 : totalAvailable);

    return WillPopScope(
      onWillPop: () async {
        await _cancelAndClose();
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF222222),
        body: SafeArea(
          child: _animatedContent(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Add song',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _cancelAndClose,
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // URL Input Field Box (Turns Red on error)
                  _borderedInputBox(
                    isError: _urlError != null,
                    errorText: _urlError,
                    child: TextField(
                      controller: _urlController,
                      enabled: !_isImporting && !_isSaving,
                      onChanged: (_) {
                        if (_urlError != null) setState(() => _urlError = null);
                      },
                      onSubmitted: (_) => _importYoutube(),
                      keyboardType: TextInputType.url,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Paste YouTube URL...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        border: InputBorder.none,
                        isDense: true,
                        suffixIcon: _isImporting
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : IconButton(
                                onPressed: _importYoutube,
                                icon: const Icon(
                                  Icons.download,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),

                  if (_sourceTitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Source: $_sourceTitle',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),

                  // Song Title Field (Supports Thai & Multilingual Text)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _borderedInputBox(
                          isError: _titleError != null,
                          errorText: _titleError,
                          child: TextField(
                            controller: _titleController,
                            enabled: !_isSaving,
                            keyboardType: TextInputType.multiline,
                            maxLines: null,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Song title',
                              hintStyle: TextStyle(color: Colors.white54),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                      ),
                      if (_isPreviewReady) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _isSaving ? null : _togglePreview,
                          icon: Icon(
                            _isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_filled,
                            color: Colors.white,
                            size: 42,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Artist Name Field with Intelligent Auto-Complete & Suggestion
                  _borderedInputBox(
                    isError: _artistError != null,
                    errorText: _artistError,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: _artistController,
                          enabled: !_isSaving,
                          keyboardType: TextInputType.text,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          decoration: InputDecoration(
                            hintText: 'Artist name',
                            hintStyle: const TextStyle(color: Colors.white54),
                            border: InputBorder.none,
                            isDense: true,
                            suffixIcon: _artistSuggestion != null
                                ? IconButton(
                                    tooltip: 'Accept "$_artistSuggestion"',
                                    icon: const Icon(
                                      Icons.check_circle_outline_rounded,
                                      color: Color(0xFF9384D1),
                                      size: 22,
                                    ),
                                    onPressed: () {
                                      _artistController.text = _artistSuggestion!;
                                      _artistController.selection =
                                          TextSelection.fromPosition(
                                        TextPosition(
                                            offset: _artistSuggestion!.length),
                                      );
                                    },
                                  )
                                : null,
                          ),
                        ),
                        if (_artistSuggestion != null) ...[
                          const SizedBox(height: 2),
                          InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () {
                              _artistController.text = _artistSuggestion!;
                              _artistController.selection =
                                  TextSelection.fromPosition(
                                TextPosition(
                                    offset: _artistSuggestion!.length),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.auto_awesome,
                                    size: 13,
                                    color: Color(0xFF9384D1),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Suggestion: ',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    _artistSuggestion!,
                                    style: const TextStyle(
                                      color: Color(0xFFD4C7FF),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 13,
                                    color: Color(0xFF9384D1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  const Text(
                    'Album cover (optional)',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 10),

                  // Picked cover or 4x3 Grid (Max 12 Pictures display)
                  if (_pickedCover != null)
                    InkWell(
                      onTap: _showCoverPicker,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _pickedCover!,
                          height: 180,
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4, // 4 in X axis
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                          itemCount: displayCount,
                          itemBuilder: (_, index) => index == 0
                              ? _coverTile(null, addTile: true)
                              : _coverTile(
                                  _existingCovers[index - 1],
                                  addTile: false,
                                ),
                        ),
                        if (!_showAllCovers && totalAvailable > 12) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _showAllCovers = true;
                              });
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white70,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('More'),
                                Icon(Icons.keyboard_arrow_down, size: 18),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),

                  const SizedBox(height: 18),
                  const Text(
                    'Song tags (optional)',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),

                  // Tag input field
                  _borderedInputBox(
                    isError: _tagError != null,
                    errorText: _tagError,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _tagInputController,
                            enabled: !_isSaving,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            onSubmitted: _addTag,
                            decoration: const InputDecoration(
                              hintText: 'Add hashtag (e.g. #japanese, #city-pop)',
                              hintStyle: TextStyle(color: Colors.white54, fontSize: 13),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Add tag',
                          icon: const Icon(
                            Icons.add_circle,
                            color: Color(0xFF9384D1),
                            size: 24,
                          ),
                          onPressed: () => _addTag(_tagInputController.text),
                        ),
                      ],
                    ),
                  ),

                  // Existing tags display as chips
                  if (_tags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _tags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF483D73).withOpacity(0.4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFF9384D1).withOpacity(0.5),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                tag,
                                style: const TextStyle(
                                  color: Color(0xFFD4C7FF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => setState(() => _tags.remove(tag)),
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 14,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  if (_generalError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _generalError!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  const SizedBox(height: 26),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSaving ? null : _cancelAndClose,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Discard'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _isSaving ? null : _saveSong,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : const Text('Save Song'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
