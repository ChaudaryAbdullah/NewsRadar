import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/models/models.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/badges.dart';
import '../../../core/theme.dart';
import '../../actions/screens/action_simulator_screen.dart';

class AnalysisScreen extends StatefulWidget {
  final Article article;
  const AnalysisScreen({super.key, required this.article});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final _api = ApiService();
  AnalysisResponse? _result;
  bool _loading = true;
  String? _error;
  int _currentStep = 0;

  final List<String> _stepLabels = [
    'Ingesting article...',
    'Extracting insights...',
    'Evaluating implications...',
    'Generating actions...',
  ];

  @override
  void initState() {
    super.initState();
    _runAnalysis();
  }

  Future<void> _runAnalysis() async {
    setState(() { _loading = true; _error = null; _currentStep = 0; });
    // Animate through steps while waiting
    _animateSteps();
    try {
      final result = await _api.analyzeArticle(widget.article);
      setState(() { _result = result; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _animateSteps() async {
    for (int i = 0; i < _stepLabels.length; i++) {
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted && _loading) setState(() => _currentStep = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('AI Analysis', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
        actions: [
          if (_result != null)
            TextButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => ActionSimulatorScreen(analysis: _result!),
              )),
              icon: const Icon(Icons.bolt_rounded, color: AppColors.accent, size: 18),
              label: Text('Actions', style: GoogleFonts.inter(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 13)),
            ),
        ],
      ),
      body: _loading ? _buildLoadingState() : _error != null ? _buildError() : _buildResult(),
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Article title
          Text(widget.article.title,
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary, height: 1.4),
          ),
          const SizedBox(height: 32),
          // Pipeline animation
          Text('Running AI Pipeline', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text('Gemini 2.0 Flash is analyzing this article...', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
          const SizedBox(height: 32),
          ...List.generate(_stepLabels.length, (i) => _buildStepRow(i)),
        ],
      ),
    );
  }

  Widget _buildStepRow(int i) {
    final done = i < _currentStep;
    final active = i == _currentStep;
    final color = done ? AppColors.badgeGreen : active ? AppColors.accent : AppColors.textMuted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.5)),
            ),
            child: Center(
              child: done
                ? Icon(Icons.check_rounded, color: color, size: 16)
                : active
                  ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: color))
                  : Text('${i + 1}', style: GoogleFonts.inter(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(_stepLabels[i], style: GoogleFonts.inter(fontSize: 14, color: active ? AppColors.textPrimary : done ? AppColors.textSecondary : AppColors.textMuted, fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
          ),
          if (done) Text('✓', style: GoogleFonts.inter(fontSize: 12, color: AppColors.badgeGreen)),
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: i * 200));
  }

  Widget _buildError() {
    return Center(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline_rounded, color: AppColors.badgeRed, size: 48),
        const SizedBox(height: 16),
        Text('Analysis Failed', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Text(_error ?? '', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        ElevatedButton.icon(onPressed: _runAnalysis, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry Analysis')),
      ]),
    ));
  }

  Widget _buildResult() {
    final r = _result!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header card
        _SectionCard(
          title: r.article.title,
          child: Row(children: [
            ReliabilityBadgeWidget(badge: r.evaluation.reliabilityBadge, large: true),
            const SizedBox(width: 8),
            VerdictBadgeWidget(status: r.article.status),
            const Spacer(),
            SentimentWidget(sentiment: r.insights.sentiment, score: r.insights.sentimentScore),
          ]),
        ),
        const SizedBox(height: 12),
        // Insights section
        _SectionCard(
          label: 'AI SUMMARY',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.insights.summary, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, height: 1.6)),
            const SizedBox(height: 12),
            _TagRow(tags: r.insights.topics, color: AppColors.accent),
          ]),
        ),
        const SizedBox(height: 12),
        // Key claims
        _SectionCard(
          label: 'KEY CLAIMS',
          child: Column(children: r.insights.keyClaims.asMap().entries.map((e) =>
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 20, height: 20, margin: const EdgeInsets.only(top: 2, right: 8),
                  decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.15), shape: BoxShape.circle),
                  child: Center(child: Text('${e.key + 1}', style: GoogleFonts.inter(fontSize: 10, color: AppColors.accent, fontWeight: FontWeight.w700))),
                ),
                Expanded(child: Text(e.value, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.5))),
              ]),
            )
          ).toList()),
        ),
        const SizedBox(height: 12),
        // Entities
        if (r.insights.namedEntities.isNotEmpty)
          _SectionCard(
            label: 'NAMED ENTITIES',
            child: Wrap(spacing: 8, runSpacing: 8, children: r.insights.namedEntities.map((e) =>
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(e.name, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 4),
                  Text(e.type, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                ]),
              )
            ).toList()),
          ),
        const SizedBox(height: 12),
        // Evaluation
        _SectionCard(
          label: 'INTEGRITY EVALUATION',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              RiskLevelWidget(riskLevel: r.evaluation.riskLevel),
              const Spacer(),
              Text('${(r.evaluation.misinformationProbability * 100).toInt()}% misinfo risk',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
            ]),
            const SizedBox(height: 10),
            _ProgressBar(label: 'Source Reliability', value: r.evaluation.sourceReliability, color: _reliabilityColor(r.evaluation.sourceReliability)),
            const SizedBox(height: 8),
            _ProgressBar(label: 'Misinfo Probability', value: r.evaluation.misinformationProbability, color: _riskColor(r.evaluation.misinformationProbability)),
            if (r.evaluation.flags.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...r.evaluation.flags.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  const Icon(Icons.flag_rounded, size: 14, color: AppColors.badgeAmber),
                  const SizedBox(width: 6),
                  Expanded(child: Text(f, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary))),
                ]),
              )),
            ],
            const SizedBox(height: 8),
            Text(r.evaluation.reasoning, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted, fontStyle: FontStyle.italic)),
          ]),
        ),
        const SizedBox(height: 12),
        // Agent trace summary
        _SectionCard(
          label: 'AGENT TRACE',
          child: Column(children: [
            Row(children: [
              const Icon(Icons.timer_outlined, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text('${r.trace.totalDurationMs}ms total', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(width: 12),
              Text(r.trace.traceId, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted).copyWith(fontFamily: 'monospace')),
            ]),
            const SizedBox(height: 10),
            ...r.trace.steps.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(
                  color: s.status == 'SUCCESS' ? AppColors.badgeGreen : AppColors.badgeAmber,
                  shape: BoxShape.circle,
                )),
                const SizedBox(width: 8),
                Text(s.step, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${s.durationMs}ms', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
              ]),
            )),
          ]),
        ),
        const SizedBox(height: 20),
        // CTA
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => ActionSimulatorScreen(analysis: _result!),
            )),
            icon: const Icon(Icons.bolt_rounded),
            label: const Text('View & Execute Actions'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
        ),
        const SizedBox(height: 32),
      ]),
    );
  }

  Color _reliabilityColor(double v) => v >= 0.7 ? AppColors.badgeGreen : v >= 0.4 ? AppColors.badgeAmber : AppColors.badgeRed;
  Color _riskColor(double v) => v >= 0.6 ? AppColors.badgeRed : v >= 0.3 ? AppColors.badgeAmber : AppColors.badgeGreen;
}

class _SectionCard extends StatelessWidget {
  final String? label;
  final String? title;
  final Widget child;

  const _SectionCard({this.label, this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (label != null) ...[
          Text(label!, style: GoogleFonts.inter(fontSize: 10, color: AppColors.accent, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          const SizedBox(height: 10),
        ],
        if (title != null) ...[
          Text(title!, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary, height: 1.4)),
          const SizedBox(height: 12),
        ],
        child,
      ]),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05);
  }
}

class _TagRow extends StatelessWidget {
  final List<String> tags;
  final Color color;
  const _TagRow({required this.tags, required this.color});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 6, children: tags.map((t) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(t, style: GoogleFonts.inter(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    )).toList());
  }
}

class _ProgressBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _ProgressBar({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
        const Spacer(),
        Text('${(value * 100).toInt()}%', style: GoogleFonts.inter(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: value, minHeight: 6,
          backgroundColor: AppColors.divider,
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
    ]);
  }
}
