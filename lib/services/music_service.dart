import 'package:http/http.dart' as http;
import 'dart:convert';

class MusicService {
  static const String baseUrl = 'https://music.wannuwatbot.com';

  static Future<List<Map<String, dynamic>>> fetchSongs() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/songs'));

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        throw Exception('Failed to fetch songs');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static String getStreamUrl(String filename) {
    return '$baseUrl/stream/$filename';
  }
}
