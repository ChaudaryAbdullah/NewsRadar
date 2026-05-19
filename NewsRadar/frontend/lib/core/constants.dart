class AppConstants {
  // ── Backend URL ─────────────────────────────────────────────────────────────
  // static const String baseUrl = 'http://localhost:8000';         // Windows desktop only
  // static const String baseUrl = 'http://10.0.2.2:8000';         // Android emulator only
  // static const String baseUrl = 'http://172.15.75.109:8000';    // Physical phone (same WiFi)
  static const String baseUrl = 'https://newsradar-ftkd.onrender.com'; // ✅ Cloud (works everywhere)

  static const String apiV1 = '$baseUrl/api/v1';

  // Endpoints
  static const String articlesEndpoint   = '$apiV1/articles';
  static const String searchEndpoint     = '$apiV1/articles/search';
  static const String categoriesEndpoint = '$apiV1/articles/categories';
  static const String analyzeEndpoint    = '$apiV1/analysis/analyze';
  static const String simulateEndpoint   = '$apiV1/analysis/simulate';
  static const String tracesEndpoint     = '$apiV1/analysis/traces';
  static const String healthEndpoint     = '$apiV1/health';
  static const String chatAskEndpoint    = '$apiV1/chat/ask';
  static const String chatStreamEndpoint = '$apiV1/chat/stream';

  // Timeouts
  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration analysisTimeout = Duration(seconds: 60);

  // UI
  static const int defaultPageSize = 20;
  static const double cardRadius = 16.0;
  static const double screenPadding = 16.0;
}
