import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String _serverUrlKey = 'server_url';
  static const String _tokenKey = 'auth_token';
  static const String _usernameKey = 'username';
  static const String _roleKey = 'role';

  // ── Server URL ──────────────────────────────────────────────────────────────
  static Future<String> getServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_serverUrlKey) ?? 'http://192.168.1.100:3000';
  }

  static Future<void> setServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    // Remove trailing slash
    await prefs.setString(_serverUrlKey, url.trimRight().replaceAll(RegExp(r'/+$'), ''));
  }

  // ── Token helpers ────────────────────────────────────────────────────────────
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<Map<String, String>> authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Auth ─────────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(
      String username, String password) async {
    final base = await getServerUrl();
    final response = await http
        .post(
          Uri.parse('$base/api/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'username': username, 'password': password}),
        )
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, body['token'] as String);
      await prefs.setString(_usernameKey, body['user']['username'] as String);
      await prefs.setString(_roleKey, body['user']['role'] as String);
      return body;
    }
    throw ApiException(body['error'] ?? 'Login failed');
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_roleKey);
  }

  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }

  // ── Files ────────────────────────────────────────────────────────────────────
  static Future<List<HtmlFile>> listFiles() async {
    final base = await getServerUrl();
    final headers = await authHeaders();
    final response = await http
        .get(Uri.parse('$base/api/files'), headers: headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final files = (body['files'] as List)
          .map((f) => HtmlFile.fromJson(f as Map<String, dynamic>, base))
          .toList();
      return files;
    }
    final err = jsonDecode(response.body);
    throw ApiException(err['error'] ?? 'Failed to list files');
  }

  static Future<HtmlFile> uploadFile(File file) async {
    final base = await getServerUrl();
    final token = await getToken();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$base/api/files/upload'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath(
      'file',
      file.path,
      contentType: MediaType('text', 'html'),
    ));

    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);
    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 201) {
      return HtmlFile.fromJson(
          body['file'] as Map<String, dynamic>, base);
    }
    throw ApiException(body['error'] ?? 'Upload failed');
  }

  static Future<void> deleteFile(String filename) async {
    final base = await getServerUrl();
    final headers = await authHeaders();
    final response = await http
        .delete(Uri.parse('$base/api/files/$filename'), headers: headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw ApiException(err['error'] ?? 'Delete failed');
    }
  }

  static Future<bool> checkHealth() async {
    try {
      final base = await getServerUrl();
      final response = await http
          .get(Uri.parse('$base/api/health'))
          .timeout(const Duration(seconds: 8));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class HtmlFile {
  final String filename;
  final String originalName;
  final int size;
  final DateTime uploadedAt;
  final String relativeUrl;
  final String fullUrl;

  HtmlFile({
    required this.filename,
    required this.originalName,
    required this.size,
    required this.uploadedAt,
    required this.relativeUrl,
    required this.fullUrl,
  });

  factory HtmlFile.fromJson(Map<String, dynamic> json, String baseUrl) {
    final rel = json['url'] as String;
    return HtmlFile(
      filename: json['filename'] as String,
      originalName: json['originalName'] as String,
      size: json['size'] as int,
      uploadedAt: DateTime.parse(json['uploadedAt'] as String),
      relativeUrl: rel,
      fullUrl: '$baseUrl$rel',
    );
  }

  String get formattedSize {
    if (size < 1024) return '${size}B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)}KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}
