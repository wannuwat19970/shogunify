import 'package:flutter/material.dart';

/// Shared URL normalization for artwork returned by the music API.

class ImageUtils {
  ImageUtils._();

  static const String baseUrl = 'https://music.wannuwatbot.com';

  static String? resolveUrl(String? path) {
    final value = path?.trim();

    if (value == null || value.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(value);

    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      return value;
    }

    if (value.startsWith('//')) {
      return 'https:$value';
    }

    return '$baseUrl/${value.replaceFirst(RegExp(r'^/+'), '')}';
  }

  static Widget placeholder({double iconSize = 30}) {
    return Container(
      color: const Color(0xFF211A31),
      alignment: Alignment.center,
      child: Icon(
        Icons.music_note_rounded,
        color: const Color.fromARGB(255, 93, 93, 93),
        size: iconSize,
      ),
    );
  }
}
