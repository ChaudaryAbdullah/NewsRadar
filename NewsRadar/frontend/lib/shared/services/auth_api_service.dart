import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../models/user.dart';

/// Low-level HTTP calls for Auth endpoints.
/// Used exclusively by AuthService.
class AuthApiService {
  final _client = http.Client();

  Future<Map<String, dynamic>> login(String email, String password) async {
    final resp = await _client
        .post(
          Uri.parse('${AppConstants.baseUrl}/api/v1/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 20));
    return _parse(resp);
  }

  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
    required String role,
  }) async {
    final resp = await _client
        .post(
          Uri.parse('${AppConstants.baseUrl}/api/v1/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'full_name': fullName,
            'email':     email,
            'password':  password,
            'role':      role,
          }),
        )
        .timeout(const Duration(seconds: 20));
    return _parse(resp);
  }

  Future<AppUser> fetchMe(String token) async {
    final resp = await _client
        .get(
          Uri.parse('${AppConstants.baseUrl}/api/v1/auth/me'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 10));
    final data = _parse(resp);
    return AppUser.fromJson(data);
  }

  Map<String, dynamic> _parse(http.Response resp) {
    final body = jsonDecode(resp.body);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return body as Map<String, dynamic>;
    }
    final detail = (body as Map<String, dynamic>)['detail'] ?? 'Request failed (${resp.statusCode})';
    throw Exception(detail);
  }
}
