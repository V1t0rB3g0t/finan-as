import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient(this.baseUrl, {FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final String baseUrl;
  final FlutterSecureStorage _storage;

  Future<String?> get token async => _storage.read(key: 'token');

  Future<void> saveToken(String token) async {
    await _storage.write(key: 'token', value: token);
  }

  Future<void> clearToken() async {
    await _storage.delete(key: 'token');
  }

  Future<Map<String, dynamic>> register(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> fetchJobs() async {
    final response = await http.get(
      Uri.parse('$baseUrl/jobs'),
      headers: await _authHeaders(),
    );
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> fetchJob(String id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/jobs/$id'),
      headers: await _authHeaders(),
    );
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> reanalyze(String id) async {
    final response = await http.post(
      Uri.parse('$baseUrl/jobs/$id/reanalyze'),
      headers: await _authHeaders(),
    );
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> uploadFile(File file) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/audio/upload'));
    request.headers.addAll(await _authHeaders());
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> _decodeResponse(http.Response response) async {
    final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    if (response.statusCode >= 400) {
      throw HttpException(body['error'] ?? 'Erro de comunicação');
    }
    return body;
  }

  Future<Map<String, String>> _authHeaders() async {
    final tokenValue = await token;
    if (tokenValue == null) {
      return {};
    }
    return {
      'Authorization': 'Bearer $tokenValue'
    };
  }
}
