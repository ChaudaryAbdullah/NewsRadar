import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../shared/models/models.dart';
import '../../../shared/models/user.dart';
import '../../../core/theme.dart';
import '../../analysis/screens/analysis_screen.dart';
import '../widgets/chatbot_overlay.dart';

class ArticleDetailScreen extends StatefulWidget {
  final Article article;
  final AnalysisResponse? analysis; // Pre-loaded if coming from AnalysisScreen

  const ArticleDetailScreen({super.key, required this.article, this.analysis});

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  bool _chatOpen = false;

  @override
  Widget build(BuildContext context) {
    final article = widget.article;
    final analysis = widget.analysis;
    final user = AuthService().currentUser;

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ── Header ──────────────────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 200,
                floating: false,
                pinned: true,
                backgroundColor: AppColors.surface,
                surfaceTintColor: Colors.transparent,
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.arrow_back_ios_rounded, size: 16, color: AppColors.textPrimary),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.share_rounded, size: 16, color: AppColors.textPrimary),
                    ),
                    onPressed: () => Clipboard.setData(ClipboardData(text: article.url)),
                  ),
                  if (user != null && user.role.canViewAnalytics)
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.analytics_rounded, size: 16, color: AppColors.accent),
                      ),
                      onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => AnalysisScreen(article: article))),
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(fit: StackFit.expand, children: [
                    if (article.urlToImage != null)
                      Image.network(
                        article.urlToImage!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _PlaceholderHero(article: article),
                      )
                    else
                      _PlaceholderHero(article: article),
                    // Gradient overlay
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black54],
                        ),
                      ),
                    ),
                  ]),
                ),
              ),

              // ── Body ────────────────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(delegate: SliverChildListDelegate([
                  // Metadata row
                  _MetaRow(article: article),
                  const SizedBox(height: 12),

                  // Title
                  Text(
                    article.title,
                    style: GoogleFonts.inter(
                      fontSize: 22, fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary, height: 1.3,
                    ),
                  ).animate().fadeIn(duration: 400.ms),
                  const SizedBox(height: 16),

                  // Verdict + reliability badges
                  if (analysis != null) ...[
                    _VerdictReliabilityRow(
                      verdict: analysis.insights.sentiment,
                      evaluation: analysis.evaluation,
                      articleStatus: article.status,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Read original button (REQUIRED by SRS)
                  _ReadOriginalButton(url: article.url, source: article.source.name),
                  const SizedBox(height: 20),

                  // Divider
                  const Divider(),
                  const SizedBox(height: 12),

                  // AI Summary (if analysis available)
                  if (analysis != null) ...[
                    _AISummaryCard(insight: analysis.insights),
                    const SizedBox(height: 16),
                  ],

                  // Article body / description
                  _ArticleBody(article: article),
                  const SizedBox(height: 16),

                  // NER entities (if analysis available)
                  if (analysis != null && analysis.insights.namedEntities.isNotEmpty) ...[
                    _NERSection(entities: analysis.insights.namedEntities),
                    const SizedBox(height: 16),
                  ],

                  // Key claims (journalists+)
                  if (analysis != null && analysis.insights.keyClaims.isNotEmpty &&
                      user != null && user.role.canViewAnalytics) ...[
                    _KeyClaimsSection(claims: analysis.insights.keyClaims),
                    const SizedBox(height: 16),
                  ],

                  // Credibility signals (editors+)
                  if (analysis != null && analysis.evaluation.flags.isNotEmpty &&
                      user != null && user.role.canOverrideVerdicts) ...[
                    _CredibilityFlags(flags: analysis.evaluation.flags, reasoning: analysis.evaluation.reasoning),
                    const SizedBox(height: 16),
                  ],

                  // Bottom spacer for FAB
                  const SizedBox(height: 80),
                ])),
              ),
            ],
          ),

          // ── Chatbot overlay ─────────────────────────────────────────────────
          if (_chatOpen)
            ChatbotOverlay(
              article: widget.article,
              analysis: widget.analysis,
              onClose: () => setState(() => _chatOpen = false),
            ),
        ],
      ),

      // ── FAB — Ask AI ────────────────────────────────────────────────────────
      floatingActionButton: _chatOpen ? null : FloatingActionButton.extended(
        onPressed: () => setState(() => _chatOpen = true),
        backgroundColor: AppColors.accentDeep,
        elevation: 4,
        icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 18),
        label: Text('Ask AI', style: GoogleFonts.inter(
          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
      ).animate().scale(delay: 600.ms, duration: 400.ms, curve: Curves.easeOutBack),
    );
  }
}

// ─── Hero placeholder ─────────────────────────────────────────────────────────

class _PlaceholderHero extends StatelessWidget {
  final Article article;
  const _PlaceholderHero({required this.article});
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [AppColors.accentDeep, AppColors.accent],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
    ),
    child: Center(child: Icon(Icons.article_rounded, color: Colors.white.withOpacity(0.3), size: 80)),
  );
}

// ─── Metadata row ─────────────────────────────────────────────────────────────

class _MetaRow extends StatelessWidget {
  final Article article;
  const _MetaRow({required this.article});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
      ),
      child: Text(article.source.name, style: GoogleFonts.inter(
        fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accentDeep)),
    ),
    const SizedBox(width: 8),
    if (article.author != null) ...[
      Text(article.author!, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
      const SizedBox(width: 8),
    ],
    const Spacer(),
    Text(_formatDate(article.publishedAt),
      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
  ]);

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return raw.split('T').first;
    }
  }
}

// ─── Read original button ─────────────────────────────────────────────────────

class _ReadOriginalButton extends StatelessWidget {
  final String url, source;
  const _ReadOriginalButton({required this.url, required this.source});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      icon: const Icon(Icons.open_in_new_rounded, size: 16),
      label: Text('Read original article on $source ↗',
        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.accentDeep,
        side: const BorderSide(color: AppColors.accentDeep, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
  );
}

// ─── Verdict row ──────────────────────────────────────────────────────────────

class _VerdictReliabilityRow extends StatelessWidget {
  final String verdict;
  final EvaluationResult evaluation;
  final String articleStatus;
  const _VerdictReliabilityRow({required this.verdict, required this.evaluation, required this.articleStatus});

  Color get _verdictColor {
    switch (articleStatus) {
      case 'VERIFIED':       return AppColors.badgeGreen;
      case 'DISPUTED':       return const Color(0xFF7C3AED);
      case 'MISINFORMATION': return AppColors.badgeRed;
      default:               return AppColors.badgeAmber;
    }
  }

  Color get _relColor => evaluation.sourceReliability >= 0.7
    ? AppColors.badgeGreen : evaluation.sourceReliability >= 0.4
    ? AppColors.badgeAmber : AppColors.badgeRed;

  @override
  Widget build(BuildContext context) => Row(children: [
    _Badge(label: articleStatus, color: _verdictColor),
    const SizedBox(width: 8),
    _Badge(label: evaluation.riskLevel, color: evaluation.riskLevel == 'HIGH' ? AppColors.badgeRed :
      evaluation.riskLevel == 'MEDIUM' ? AppColors.badgeAmber : AppColors.badgeGreen),
    const SizedBox(width: 8),
    Expanded(child: Row(children: [
      Text('Reliability ', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
      Text('${(evaluation.sourceReliability * 100).toInt()}%',
        style: GoogleFonts.jetBrainsMono(fontSize: 11, color: _relColor, fontWeight: FontWeight.w700)),
    ])),
  ]);
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: color.withOpacity(0.4)),
    ),
    child: Text(label, style: GoogleFonts.jetBrainsMono(fontSize: 9, color: color, fontWeight: FontWeight.w700)),
  );
}

// ─── AI Summary card ──────────────────────────────────────────────────────────

class _AISummaryCard extends StatelessWidget {
  final InsightResult insight;
  const _AISummaryCard({required this.insight});

  Color get _sentColor => insight.sentiment == 'POSITIVE' ? AppColors.badgeGreen :
    insight.sentiment == 'NEGATIVE' ? AppColors.badgeRed : AppColors.badgeAmber;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.accentDeep.withOpacity(0.05),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.accentDeep.withOpacity(0.2)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.accentDeep),
        const SizedBox(width: 6),
        Text('AI Summary', style: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accentDeep, letterSpacing: 0.3)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _sentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
          child: Text(insight.sentiment, style: GoogleFonts.inter(fontSize: 10, color: _sentColor, fontWeight: FontWeight.w600)),
        ),
      ]),
      const SizedBox(height: 10),
      Text(insight.summary, style: GoogleFonts.inter(
        fontSize: 14, color: AppColors.textPrimary, height: 1.6)),
      if (insight.topics.isNotEmpty) ...[
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 4,
          children: insight.topics.map((t) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.accentDeep.withOpacity(0.08),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('#$t', style: GoogleFonts.inter(fontSize: 10, color: AppColors.accentDeep)),
          )).toList()),
      ],
    ]),
  ).animate().fadeIn(delay: 200.ms);
}

// ─── Article body ─────────────────────────────────────────────────────────────

class _ArticleBody extends StatelessWidget {
  final Article article;
  const _ArticleBody({required this.article});
  @override
  Widget build(BuildContext context) {
    final text = article.content ?? article.description ?? 'No content available.';
    return Text(text, style: GoogleFonts.inter(
      fontSize: 15, color: AppColors.textSecondary, height: 1.7));
  }
}

// ─── NER Section ──────────────────────────────────────────────────────────────

class _NERSection extends StatelessWidget {
  final List<NamedEntity> entities;
  const _NERSection({required this.entities});

  static const _entityColors = {
    'PERSON':       Color(0xFF7C3AED),
    'ORG':          AppColors.accentDeep,
    'ORGANIZATION': AppColors.accentDeep,
    'LOCATION':     AppColors.badgeGreen,
    'GPE':          AppColors.badgeGreen,
    'DATE':         AppColors.badgeAmber,
    'CONCEPT':      AppColors.textMuted,
    'EVENT':        AppColors.badgeRed,
  };

  @override
  Widget build(BuildContext context) => _SectionCard(
    title: 'Named Entities',
    icon: Icons.label_rounded,
    child: Wrap(
      spacing: 8, runSpacing: 6,
      children: entities.map((e) {
        final color = _entityColors[e.type.toUpperCase()] ?? AppColors.textMuted;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(e.name, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
            const SizedBox(width: 5),
            Text(e.type, style: GoogleFonts.jetBrainsMono(fontSize: 9, color: color.withOpacity(0.7))),
          ]),
        );
      }).toList(),
    ),
  );
}

// ─── Key claims ───────────────────────────────────────────────────────────────

class _KeyClaimsSection extends StatelessWidget {
  final List<String> claims;
  const _KeyClaimsSection({required this.claims});
  @override
  Widget build(BuildContext context) => _SectionCard(
    title: 'Key Claims',
    icon: Icons.fact_check_rounded,
    child: Column(children: claims.asMap().entries.map((e) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 20, height: 20,
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            color: AppColors.accentDeep.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4)),
          child: Center(child: Text('${e.key + 1}', style: GoogleFonts.jetBrainsMono(
            fontSize: 10, color: AppColors.accentDeep, fontWeight: FontWeight.w700))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(e.value, style: GoogleFonts.inter(
          fontSize: 13, color: AppColors.textSecondary, height: 1.5))),
      ]),
    )).toList()),
  );
}

// ─── Credibility flags ────────────────────────────────────────────────────────

class _CredibilityFlags extends StatelessWidget {
  final List<String> flags;
  final String reasoning;
  const _CredibilityFlags({required this.flags, required this.reasoning});
  @override
  Widget build(BuildContext context) => _SectionCard(
    title: 'Credibility Signals',
    icon: Icons.warning_amber_rounded,
    iconColor: AppColors.badgeAmber,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ...flags.map((f) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.circle, size: 6, color: AppColors.badgeAmber),
          const SizedBox(width: 8),
          Expanded(child: Text(f, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary))),
        ]),
      )),
      if (reasoning.isNotEmpty) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.badgeAmber.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8)),
          child: Text(reasoning, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, height: 1.5)),
        ),
      ],
    ]),
  );
}

// ─── Shared section card ──────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? iconColor;
  final Widget child;
  const _SectionCard({required this.title, required this.icon, this.iconColor, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.divider),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 14, color: iconColor ?? AppColors.accentDeep),
        const SizedBox(width: 6),
        Text(title, style: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w700,
          color: iconColor ?? AppColors.accentDeep, letterSpacing: 0.3)),
      ]),
      const SizedBox(height: 12),
      child,
    ]),
  ).animate().fadeIn(delay: 300.ms);
}
