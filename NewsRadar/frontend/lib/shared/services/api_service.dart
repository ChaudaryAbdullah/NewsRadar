import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import '../models/user.dart';
import '../../core/constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final _client = http.Client();

  Map<String, String> get _authHeaders {
    final token = AuthService().token;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Articles ────────────────────────────────────────────────────────────────

  Future<List<Article>> getArticles({
    String? category,
    String? q,
    int page = 1,
    int pageSize = 20,
  }) async {
    final uri = Uri.parse(AppConstants.articlesEndpoint).replace(
      queryParameters: {
        if (category != null) 'category': category,
        if (q != null) 'q': q,
        'page': page.toString(),
        'page_size': pageSize.toString(),
      },
    );
    final resp = await _client
        .get(uri, headers: _authHeaders)
        .timeout(AppConstants.requestTimeout);
    _check(resp);
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return (data['articles'] as List)
        .map((a) => Article.fromJson(a))
        .toList();
  }

  Future<List<Article>> searchArticles(String query, {int page = 1}) async {
    final uri = Uri.parse(AppConstants.searchEndpoint).replace(
      queryParameters: {'q': query, 'page': page.toString()},
    );
    final resp = await _client
        .get(uri, headers: _authHeaders)
        .timeout(AppConstants.requestTimeout);
    _check(resp);
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return (data['articles'] as List)
        .map((a) => Article.fromJson(a))
        .toList();
  }

  Future<List<String>> getCategories() async {
    final resp = await _client
        .get(Uri.parse(AppConstants.categoriesEndpoint), headers: _authHeaders)
        .timeout(AppConstants.requestTimeout);
    _check(resp);
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return List<String>.from(data['categories'] ?? []);
  }

  // ── Analysis ────────────────────────────────────────────────────────────────

  Future<AnalysisResponse> analyzeArticle(Article article) async {
    final resp = await _client
        .post(
          Uri.parse(AppConstants.analyzeEndpoint),
          headers: _authHeaders,
          body: jsonEncode(article.toJson()),
        )
        .timeout(AppConstants.analysisTimeout);
    _check(resp);
    return AnalysisResponse.fromJson(
        jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<SimulationResult> simulateAction({
    required Article article,
    required EvaluationResult evaluation,
    required String actionType,
  }) async {
    final body = {
      'article_id': article.id,
      'article_title': article.title,
      'article_url': article.url,
      'source_name': article.source.name,
      'source_id': article.source.id,
      'current_status': article.status,
      'current_reliability': evaluation.sourceReliability,
      'action_type': actionType,
    };
    final resp = await _client
        .post(
          Uri.parse(AppConstants.simulateEndpoint),
          headers: _authHeaders,
          body: jsonEncode(body),
        )
        .timeout(AppConstants.requestTimeout);
    _check(resp);
    return SimulationResult.fromJson(
        jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<SimulationResult> executeAction({
    required Article article,
    required EvaluationResult evaluation,
    required RecommendedAction action,
  }) async {
    final body = {
      'article_id': article.id,
      'article': article.toJson(),
      'action_type': action.type,
      'action_title': action.title,
      'risk_level': evaluation.riskLevel,
    };
    final resp = await _client
        .post(
          Uri.parse(AppConstants.executeActionEndpoint),
          headers: _authHeaders,
          body: jsonEncode(body),
        )
        .timeout(AppConstants.requestTimeout);
    _check(resp);
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    
    return SimulationResult(
      actionType: data['action_type'] ?? action.type,
      beforeState: ArticleState.fromJson(data['before_state'] ?? {}),
      afterState: ArticleState.fromJson(data['after_state'] ?? {}),
      executionLog: ['Initiating action execution...', 'Status: ${data['status']}'],
      impactSummary: data['error'] ?? 'Action successfully executed in production state.',
      durationMs: 0,
    );
  }

  Future<Map<String, dynamic>> getTraces() async {
    final resp = await _client
        .get(Uri.parse(AppConstants.tracesEndpoint), headers: _authHeaders)
        .timeout(AppConstants.requestTimeout);
    _check(resp);
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<bool> checkHealth() async {
    try {
      final resp = await _client
          .get(Uri.parse(AppConstants.healthEndpoint), headers: _authHeaders)
          .timeout(const Duration(seconds: 5));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  void _check(http.Response resp) {
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final body = jsonDecode(resp.body);
      throw Exception(body['detail'] ?? 'Request failed: ${resp.statusCode}');
    }
  }

  // ── Chat ─────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> sendChatMessage({
    required String message,
    required String sessionId,
    Map<String, dynamic>? articleContext,
  }) async {
    final body = {
      'message': message,
      'session_id': sessionId,
      if (articleContext != null) 'article_context': articleContext,
    };
    final resp = await _client
        .post(
          Uri.parse(AppConstants.chatAskEndpoint),
          headers: _authHeaders,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 60));
    _check(resp);
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }
}
