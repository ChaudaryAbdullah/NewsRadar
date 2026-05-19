import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../models/user.dart';

/// HTTP client for all admin-panel API calls.
/// All requests attach the logged-in user's Bearer token.
class AdminApiService {
  final _client = http.Client();

  Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  Map<String, dynamic> _parse(http.Response resp) {
    if (resp.statusCode == 204) return {};
    final body = jsonDecode(resp.body);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return body as Map<String, dynamic>;
    }
    final detail = (body as Map<String, dynamic>)['detail'] ?? 'Request failed (${resp.statusCode})';
    throw Exception(detail);
  }

  // ── Users ────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getUsers(String token) async {
    final resp = await _client
        .get(Uri.parse('${AppConstants.baseUrl}/api/v1/admin/users'),
            headers: _headers(token))
        .timeout(AppConstants.requestTimeout);
    final data = _parse(resp);
    return List<Map<String, dynamic>>.from(data['users'] as List);
  }

  Future<Map<String, dynamic>> inviteUser({
    required String token,
    required String name,
    required String email,
    required String role,
    String? password,
  }) async {
    final resp = await _client
        .post(
          Uri.parse('${AppConstants.baseUrl}/api/v1/admin/users/invite'),
          headers: _headers(token),
          body: jsonEncode({
            'name':     name,
            'email':    email,
            'role':     role,
            if (password != null) 'password': password,
          }),
        )
        .timeout(AppConstants.requestTimeout);
    return _parse(resp);
  }

  Future<Map<String, dynamic>> updateUserRole({
    required String token,
    required String userId,
    required String role,
  }) async {
    final resp = await _client
        .patch(
          Uri.parse('${AppConstants.baseUrl}/api/v1/admin/users/$userId/role'),
          headers: _headers(token),
          body: jsonEncode({'role': role}),
        )
        .timeout(AppConstants.requestTimeout);
    return _parse(resp);
  }

  Future<Map<String, dynamic>> updateUserStatus({
    required String token,
    required String userId,
    required String status,  // 'active' | 'locked'
  }) async {
    final resp = await _client
        .patch(
          Uri.parse('${AppConstants.baseUrl}/api/v1/admin/users/$userId/status'),
          headers: _headers(token),
          body: jsonEncode({'status': status}),
        )
        .timeout(AppConstants.requestTimeout);
    return _parse(resp);
  }

  Future<void> deleteUser({required String token, required String userId}) async {
    final resp = await _client
        .delete(
          Uri.parse('${AppConstants.baseUrl}/api/v1/admin/users/$userId'),
          headers: _headers(token),
        )
        .timeout(AppConstants.requestTimeout);
    _parse(resp);
  }

  // ── Sources ──────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getSources(String token) async {
    final resp = await _client
        .get(Uri.parse('${AppConstants.baseUrl}/api/v1/admin/sources'),
            headers: _headers(token))
        .timeout(AppConstants.requestTimeout);
    final data = _parse(resp);
    return List<Map<String, dynamic>>.from(data['sources'] as List);
  }

  Future<Map<String, dynamic>> addSource({
    required String token,
    required String name,
    required String url,
    required String sourceType,
    required double reliability,
  }) async {
    final resp = await _client
        .post(
          Uri.parse('${AppConstants.baseUrl}/api/v1/admin/sources'),
          headers: _headers(token),
          body: jsonEncode({
            'name':        name,
            'url':         url,
            'source_type': sourceType,
            'reliability': reliability,
            'is_active':   true,
          }),
        )
        .timeout(AppConstants.requestTimeout);
    return _parse(resp);
  }

  Future<Map<String, dynamic>> toggleSource({
    required String token,
    required String sourceId,
    required bool isActive,
  }) async {
    final resp = await _client
        .patch(
          Uri.parse('${AppConstants.baseUrl}/api/v1/admin/sources/$sourceId'),
          headers: _headers(token),
          body: jsonEncode({'is_active': isActive}),
        )
        .timeout(AppConstants.requestTimeout);
    return _parse(resp);
  }

  Future<void> deleteSource({required String token, required String sourceId}) async {
    final resp = await _client
        .delete(
          Uri.parse('${AppConstants.baseUrl}/api/v1/admin/sources/$sourceId'),
          headers: _headers(token),
        )
        .timeout(AppConstants.requestTimeout);
    _parse(resp);
  }

  // ── Alert Rules ──────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAlerts(String token) async {
    final resp = await _client
        .get(Uri.parse('${AppConstants.baseUrl}/api/v1/alerts'),
            headers: _headers(token))
        .timeout(AppConstants.requestTimeout);
    final data = _parse(resp);
    return List<Map<String, dynamic>>.from(data['alerts'] as List);
  }

  Future<Map<String, dynamic>> createAlert({
    required String token,
    required String title,
    required String description,
    required String condition,
    required bool isUrgent,
  }) async {
    final resp = await _client
        .post(
          Uri.parse('${AppConstants.baseUrl}/api/v1/alerts'),
          headers: _headers(token),
          body: jsonEncode({
            'title':       title,
            'description': description,
            'condition':   condition,
            'is_urgent':   isUrgent,
          }),
        )
        .timeout(AppConstants.requestTimeout);
    return _parse(resp);
  }

  Future<void> deleteAlert({required String token, required String alertId}) async {
    final resp = await _client
        .delete(
          Uri.parse('${AppConstants.baseUrl}/api/v1/alerts/$alertId'),
          headers: _headers(token),
        )
        .timeout(AppConstants.requestTimeout);
    _parse(resp);
  }

  // ── LLM Config ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getLlmConfig(String token) async {
    final resp = await _client
        .get(Uri.parse('${AppConstants.baseUrl}/api/v1/admin/llm-config'),
            headers: _headers(token))
        .timeout(AppConstants.requestTimeout);
    return _parse(resp);
  }

  Future<Map<String, dynamic>> saveLlmConfig({
    required String token,
    required Map<String, dynamic> config,
  }) async {
    final resp = await _client
        .put(
          Uri.parse('${AppConstants.baseUrl}/api/v1/admin/llm-config'),
          headers: _headers(token),
          body: jsonEncode(config),
        )
        .timeout(AppConstants.requestTimeout);
    return _parse(resp);
  }
}
