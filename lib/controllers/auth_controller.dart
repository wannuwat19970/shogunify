import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';
import 'dart:convert';

class AuthController extends ChangeNotifier {
  static const String baseUrl = 'https://music.wannuwatbot.com';

  // The shared invite code baked into the app. Log In sends this silently
  // (an existing account still needs a valid code server-side); Sign Up asks
  // the user to type it themselves as the "you were actually invited" step.
  static const String defaultInviteCode = 'WelCoMeTo_ShoGuNiFy';

  final _storage = const FlutterSecureStorage();

  String? token;
  String? username;
  int? userId;
  bool isLoading = true;

  Future<void> checkLoginStatus() async {
    token = await _storage.read(key: 'auth_token');

    if (token != null) {
      final valid = await _verifyToken();
      if (!valid) {
        token = null;
        await _storage.delete(key: 'auth_token');
      }
    }

    isLoading = false;
    notifyListeners();
  }

  Future<bool> _verifyToken() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/auth/verify'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        username = data['username'];
        userId = data['user_id'];
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Extracts a human-readable message from the server's error shape:
  /// {"error": {"code": "...", "message": "..."}}
  String _extractErrorMessage(dynamic data, int statusCode) {
    final error = data is Map ? data['error'] : null;
    if (error is Map) {
      final code = error['code'];
      final message = error['message'];
      switch (code) {
        case 'INVALID_INVITE_CODE':
          return 'That invite code is incorrect.';
        case 'USERNAME_REQUIRED':
          return 'Please enter a username.';
      }
      if (message is String && message.trim().isNotEmpty) return message;
    } else if (error is String && error.trim().isNotEmpty) {
      return error;
    }
    return 'Something went wrong (error $statusCode). Please try again.';
  }

  Future<String?> login(String name, String inviteCode) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': name, 'invite_code': inviteCode}),
          )
          .timeout(const Duration(seconds: 10));

      final dynamic data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        token = data['token'];
        username = data['username'];
        userId = data['user_id'];
        await _storage.write(key: 'auth_token', value: token);
        notifyListeners();
        return null; // null = success, no error
      } else {
        return _extractErrorMessage(data, response.statusCode);
      }
    } on TimeoutException {
      return 'The server took too long to respond. Check your connection and try again.';
    } on http.ClientException {
      return 'Could not reach the server. Check your connection and try again.';
    } on FormatException {
      return 'The server sent back something unexpected. Please try again.';
    } catch (e) {
      return 'Could not reach the server. Check your connection and try again.';
    }
  }

  Future<void> logout() async {
    token = null;
    username = null;
    userId = null;
    await _storage.delete(key: 'auth_token');
    notifyListeners();
  }
}

// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// import 'dart:convert';

// class AuthController extends ChangeNotifier {
//   static const String baseUrl = 'https://music.wannuwatbot.com';
//   final _storage = const FlutterSecureStorage();

//   String? token;
//   String? username;
//   int? userId;
//   bool isLoading = true;

//   Future<void> checkLoginStatus() async {
//     token = await _storage.read(key: 'auth_token');

//     if (token != null) {
//       final valid = await _verifyToken();
//       if (!valid) {
//         token = null;
//         await _storage.delete(key: 'auth_token');
//       }
//     }

//     isLoading = false;
//     notifyListeners();
//   }

//   Future<bool> _verifyToken() async {
//     try {
//       final response = await http.get(
//         Uri.parse('$baseUrl/api/auth/verify'),
//         headers: {'Authorization': 'Bearer $token'},
//       );
//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         username = data['username'];
//         userId = data['user_id'];
//         return true;
//       }
//       return false;
//     } catch (e) {
//       return false;
//     }
//   }

//   Future<String?> login(String name, String inviteCode) async {
//     try {
//       final response = await http.post(
//         Uri.parse('$baseUrl/api/auth/login'),
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode({'username': name, 'invite_code': inviteCode}),
//       );
//       print('DEBUG STATUS: ${response.statusCode}');
//       print('DEBUG BODY: ${response.body}');

//       final data = jsonDecode(response.body);

//       if (response.statusCode == 200) {
//         token = data['token'];
//         username = data['username'];
//         userId = data['user_id'];
//         await _storage.write(key: 'auth_token', value: token);
//         notifyListeners();
//         return null; // null = success, no error
//       } else {
//         return data['error'] ?? 'Login failed';
//       }
//     } catch (e) {
//       print('DEBUG LOGIN ERROR: $e');
//       return 'Could not reach server';
//     }
//   }

//   Future<void> logout() async {
//     token = null;
//     username = null;
//     userId = null;
//     await _storage.delete(key: 'auth_token');
//     notifyListeners();
//   }
// }
