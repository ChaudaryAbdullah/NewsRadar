// ─── Article Source ───────────────────────────────────────────────────────────

class ArticleSource {
  final String? id;
  final String name;

  ArticleSource({this.id, required this.name});

  factory ArticleSource.fromJson(Map<String, dynamic> j) =>
      ArticleSource(id: j['id'], name: j['name'] ?? 'Unknown');

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

// ─── Article ─────────────────────────────────────────────────────────────────

class Article {
  final String id;
  final String title;
  final String? description;
  final String? content;
  final String url;
  final String? urlToImage;
  final String publishedAt;
  final ArticleSource source;
  final String? author;
  final String status;

  Article({
    required this.id,
    required this.title,
    this.description,
    this.content,
    required this.url,
    this.urlToImage,
    required this.publishedAt,
    required this.source,
    this.author,
    this.status = 'UNVERIFIED',
  });

  factory Article.fromJson(Map<String, dynamic> j) => Article(
        id: j['id'] ?? '',
        title: j['title'] ?? '',
        description: j['description'],
        content: j['content'],
        url: j['url'] ?? '',
        urlToImage: j['urlToImage'],
        publishedAt: j['publishedAt'] ?? '',
        source: ArticleSource.fromJson(j['source'] ?? {}),
        author: j['author'],
        status: j['status'] ?? 'UNVERIFIED',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'content': content,
        'url': url,
        'urlToImage': urlToImage,
        'publishedAt': publishedAt,
        'source': source.toJson(),
        'author': author,
        'status': status,
      };
}

// ─── Named Entity ─────────────────────────────────────────────────────────────

class NamedEntity {
  final String name;
  final String type;

  NamedEntity({required this.name, required this.type});

  factory NamedEntity.fromJson(Map<String, dynamic> j) =>
      NamedEntity(name: j['name'] ?? '', type: j['type'] ?? 'CONCEPT');
}

// ─── Insight Result ───────────────────────────────────────────────────────────

class InsightResult {
  final String summary;
  final List<String> keyClaims;
  final List<NamedEntity> namedEntities;
  final List<String> topics;
  final String sentiment;
  final double sentimentScore;
  final List<String> credibilitySignals;
  final String language;

  InsightResult({
    required this.summary,
    required this.keyClaims,
    required this.namedEntities,
    required this.topics,
    required this.sentiment,
    required this.sentimentScore,
    required this.credibilitySignals,
    this.language = 'en',
  });

  factory InsightResult.fromJson(Map<String, dynamic> j) => InsightResult(
        summary: j['summary'] ?? '',
        keyClaims: List<String>.from(j['key_claims'] ?? []),
        namedEntities: (j['named_entities'] as List? ?? [])
            .map((e) => NamedEntity.fromJson(e))
            .toList(),
        topics: List<String>.from(j['topics'] ?? []),
        sentiment: j['sentiment'] ?? 'NEUTRAL',
        sentimentScore: (j['sentiment_score'] ?? 0.0).toDouble(),
        credibilitySignals: List<String>.from(j['credibility_signals'] ?? []),
        language: j['language'] ?? 'en',
      );
}

// ─── Evaluation Result ────────────────────────────────────────────────────────

class EvaluationResult {
  final String riskLevel;
  final double misinformationProbability;
  final double sourceReliability;
  final String reliabilityBadge;
  final List<String> flags;
  final String reasoning;

  EvaluationResult({
    required this.riskLevel,
    required this.misinformationProbability,
    required this.sourceReliability,
    required this.reliabilityBadge,
    required this.flags,
    required this.reasoning,
  });

  factory EvaluationResult.fromJson(Map<String, dynamic> j) => EvaluationResult(
        riskLevel: j['risk_level'] ?? 'MEDIUM',
        misinformationProbability:
            (j['misinformation_probability'] ?? 0.0).toDouble(),
        sourceReliability: (j['source_reliability'] ?? 0.5).toDouble(),
        reliabilityBadge: j['reliability_badge'] ?? 'AMBER',
        flags: List<String>.from(j['flags'] ?? []),
        reasoning: j['reasoning'] ?? '',
      );
}

// ─── Recommended Action ───────────────────────────────────────────────────────

class RecommendedAction {
  final String id;
  final String type;
  final String title;
  final String description;
  final String rationale;
  final int priority;
  final String estimatedImpact;
  final String simulatedOutcome;

  RecommendedAction({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.rationale,
    required this.priority,
    required this.estimatedImpact,
    required this.simulatedOutcome,
  });

  factory RecommendedAction.fromJson(Map<String, dynamic> j) => RecommendedAction(
        id: j['id'] ?? '',
        type: j['type'] ?? 'FACT_CHECK',
        title: j['title'] ?? '',
        description: j['description'] ?? '',
        rationale: j['rationale'] ?? '',
        priority: j['priority'] ?? 1,
        estimatedImpact: j['estimated_impact'] ?? '',
        simulatedOutcome: j['simulated_outcome'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'description': description,
        'rationale': rationale,
        'priority': priority,
        'estimated_impact': estimatedImpact,
        'simulated_outcome': simulatedOutcome,
      };
}

// ─── Trace Step ───────────────────────────────────────────────────────────────

class TraceStep {
  final String step;
  final int durationMs;
  final int? tokensUsed;
  final String status;
  final String outputSummary;

  TraceStep({
    required this.step,
    required this.durationMs,
    this.tokensUsed,
    required this.status,
    required this.outputSummary,
  });

  factory TraceStep.fromJson(Map<String, dynamic> j) => TraceStep(
        step: j['step'] ?? '',
        durationMs: j['duration_ms'] ?? 0,
        tokensUsed: j['tokens_used'],
        status: j['status'] ?? 'SUCCESS',
        outputSummary: j['output_summary'] ?? '',
      );
}

// ─── Agent Trace ──────────────────────────────────────────────────────────────

class AgentTrace {
  final String traceId;
  final String articleId;
  final String articleTitle;
  final String timestamp;
  final int totalDurationMs;
  final List<TraceStep> steps;

  AgentTrace({
    required this.traceId,
    required this.articleId,
    required this.articleTitle,
    required this.timestamp,
    required this.totalDurationMs,
    required this.steps,
  });

  factory AgentTrace.fromJson(Map<String, dynamic> j) => AgentTrace(
        traceId: j['trace_id'] ?? '',
        articleId: j['article_id'] ?? '',
        articleTitle: j['article_title'] ?? '',
        timestamp: j['timestamp'] ?? '',
        totalDurationMs: j['total_duration_ms'] ?? 0,
        steps: (j['steps'] as List? ?? [])
            .map((s) => TraceStep.fromJson(s))
            .toList(),
      );
}

// ─── Full Analysis Response ───────────────────────────────────────────────────

class AnalysisResponse {
  final Article article;
  final InsightResult insights;
  final EvaluationResult evaluation;
  final List<RecommendedAction> recommendedActions;
  final AgentTrace trace;

  AnalysisResponse({
    required this.article,
    required this.insights,
    required this.evaluation,
    required this.recommendedActions,
    required this.trace,
  });

  factory AnalysisResponse.fromJson(Map<String, dynamic> j) => AnalysisResponse(
        article: Article.fromJson(j['article'] ?? {}),
        insights: InsightResult.fromJson(j['insights'] ?? {}),
        evaluation: EvaluationResult.fromJson(j['evaluation'] ?? {}),
        recommendedActions: (j['recommended_actions'] as List? ?? [])
            .map((a) => RecommendedAction.fromJson(a))
            .toList(),
        trace: AgentTrace.fromJson(j['trace'] ?? {}),
      );
}

// ─── Article State ────────────────────────────────────────────────────────────

class ArticleState {
  final String status;
  final String reliabilityBadge;
  final List<String> flags;
  final String? lastAction;
  final String? processedAt;

  ArticleState({
    required this.status,
    required this.reliabilityBadge,
    required this.flags,
    this.lastAction,
    this.processedAt,
  });

  factory ArticleState.fromJson(Map<String, dynamic> j) => ArticleState(
        status: j['status'] ?? 'UNVERIFIED',
        reliabilityBadge: j['reliability_badge'] ?? 'AMBER',
        flags: List<String>.from(j['flags'] ?? []),
        lastAction: j['last_action'],
        processedAt: j['processed_at'],
      );
}

// ─── Simulation Result ────────────────────────────────────────────────────────

class SimulationResult {
  final String actionType;
  final ArticleState beforeState;
  final List<String> executionLog;
  final ArticleState afterState;
  final String impactSummary;
  final int durationMs;

  SimulationResult({
    required this.actionType,
    required this.beforeState,
    required this.executionLog,
    required this.afterState,
    required this.impactSummary,
    required this.durationMs,
  });

  factory SimulationResult.fromJson(Map<String, dynamic> j) => SimulationResult(
        actionType: j['action_type'] ?? '',
        beforeState: ArticleState.fromJson(j['before_state'] ?? {}),
        executionLog: List<String>.from(j['execution_log'] ?? []),
        afterState: ArticleState.fromJson(j['after_state'] ?? {}),
        impactSummary: j['impact_summary'] ?? '',
        durationMs: j['duration_ms'] ?? 0,
      );
}
