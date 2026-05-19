import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/common_app_bar.dart';
import '../../feed/screens/feed_screen.dart';

class JournalistDashboard extends StatefulWidget {
  const JournalistDashboard({super.key});
  @override
  State<JournalistDashboard> createState() => _JournalistDashboardState();
}

class _JournalistDashboardState extends State<JournalistDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() { super.initState(); _tab = TabController(length: 3, vsync: this); }
  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: CommonAppBar(
        title: 'Journalist Hub',
        subtitle: 'Research & Analytics',
        icon: Icons.article_rounded,
        iconColor: AppColors.accentDeep,
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.accentDeep,
          labelColor: AppColors.accentDeep,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(icon: Icon(Icons.feed_rounded, size: 16), text: 'News Feed'),
            Tab(icon: Icon(Icons.bar_chart_rounded, size: 16), text: 'Analytics'),
            Tab(icon: Icon(Icons.search_rounded, size: 16), text: 'Research'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _FeedTab(),
          _AnalyticsTab(),
          _ResearchTab(),
        ],
      ),
    );
  }
}

// ─── Feed Tab ─────────────────────────────────────────────────────────────────

class _FeedTab extends StatelessWidget {
  const _FeedTab();
  @override
  Widget build(BuildContext context) {
    // Reuse existing FeedScreen body
    return const FeedBodyContent();
  }
}

// ─── Analytics Tab ────────────────────────────────────────────────────────────

class _AnalyticsTab extends StatelessWidget {
  const _AnalyticsTab();

  static final _topicStats = [
    ('Technology',  142, 0.82, AppColors.accentDeep),
    ('Politics',     98, 0.51, AppColors.badgeAmber),
    ('Business',     87, 0.74, AppColors.badgeGreen),
    ('Health',       64, 0.88, AppColors.badgeGreen),
    ('Science',      51, 0.91, AppColors.badgeGreen),
    ('Entertainment', 38, 0.62, AppColors.badgeAmber),
    ('Sports',       29, 0.77, AppColors.badgeGreen),
  ];

  static final _verdictBreakdown = [
    ('VERIFIED',      203, AppColors.badgeGreen),
    ('UNVERIFIED',     91, AppColors.badgeAmber),
    ('DISPUTED',       38, AppColors.badgeRed),
    ('MISINFORMATION', 14, const Color(0xFF7C3AED)),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Stats row
        Row(children: [
          _StatCard(label: 'Articles Today', value: '346', icon: Icons.article_rounded, color: AppColors.accentDeep),
          const SizedBox(width: 12),
          _StatCard(label: 'Avg Reliability', value: '74%', icon: Icons.verified_rounded, color: AppColors.badgeGreen),
          const SizedBox(width: 12),
          _StatCard(label: 'Misinformation', value: '4%', icon: Icons.warning_rounded, color: AppColors.badgeRed),
        ]),
        const SizedBox(height: 20),
        _ChartCard(
          title: 'Articles by Topic (Last 7 Days)',
          child: Column(children: _topicStats.map((s) {
            final (label, count, pct, color) = s;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                SizedBox(width: 110, child: Text(label,
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary))),
                Expanded(child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: count / 150, minHeight: 10,
                    backgroundColor: AppColors.divider,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                )),
                const SizedBox(width: 8),
                SizedBox(width: 30, child: Text('$count',
                  style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppColors.textMuted),
                  textAlign: TextAlign.right)),
              ]),
            );
          }).toList()),
        ),
        const SizedBox(height: 16),
        _ChartCard(
          title: 'Verdict Distribution',
          child: Column(children: _verdictBreakdown.map((v) {
            final (label, count, color) = v;
            final total = _verdictBreakdown.fold<int>(0, (s, e) => s + e.$2);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                SizedBox(width: 120, child: Text(label,
                  style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppColors.textPrimary))),
                Expanded(child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: count / total, minHeight: 10,
                    backgroundColor: AppColors.divider,
                    valueColor: AlwaysStoppedAnimation(color.withOpacity(0.7)),
                  ),
                )),
                const SizedBox(width: 8),
                Text('$count', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppColors.textMuted)),
              ]),
            );
          }).toList()),
        ),
        const SizedBox(height: 16),
        _ChartCard(
          title: 'Source Reliability Overview',
          child: Column(children: [
            _ReliabilityRow('BBC News',     0.91),
            _ReliabilityRow('Reuters',      0.88),
            _ReliabilityRow('AP News',      0.85),
            _ReliabilityRow('CNN',          0.72),
            _ReliabilityRow('TechCrunch',   0.68),
            _ReliabilityRow('RT News',      0.31),
          ]),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _ReliabilityRow extends StatelessWidget {
  final String source;
  final double score;
  const _ReliabilityRow(this.source, this.score);
  Color get _c => score >= 0.7 ? AppColors.badgeGreen : score >= 0.4 ? AppColors.badgeAmber : AppColors.badgeRed;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      SizedBox(width: 100, child: Text(source, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary))),
      Expanded(child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(value: score, minHeight: 10,
          backgroundColor: AppColors.divider,
          valueColor: AlwaysStoppedAnimation(_c)),
      )),
      const SizedBox(width: 8),
      SizedBox(width: 36, child: Text('${(score * 100).toInt()}%',
        style: GoogleFonts.jetBrainsMono(fontSize: 11, color: _c), textAlign: TextAlign.right)),
    ]),
  );
}

// ─── Research Tab ─────────────────────────────────────────────────────────────

class _ResearchTab extends StatelessWidget {
  const _ResearchTab();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader('Cross-Reference Tools'),
        const SizedBox(height: 12),
        _ToolCard(icon: Icons.compare_arrows_rounded, color: AppColors.accentDeep,
          title: 'Compare Coverage',
          desc: 'Compare how different sources covered the same event',
          onTap: () {}),
        _ToolCard(icon: Icons.fact_check_rounded, color: AppColors.badgeGreen,
          title: 'Manual Fact Check',
          desc: 'Initiate a fact-check pipeline on any article',
          onTap: () {}),
        _ToolCard(icon: Icons.download_rounded, color: AppColors.badgeAmber,
          title: 'Export Report',
          desc: 'Export filtered article data as CSV or PDF',
          onTap: () {}),
        _ToolCard(icon: Icons.hub_rounded, color: const Color(0xFF7C3AED),
          title: 'Narrative Clustering',
          desc: 'Visualize semantic clusters of related stories',
          onTap: () {}),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.divider)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(height: 8),
      Text(value, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
    ]),
  ));
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ChartCard({required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.divider)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      const SizedBox(height: 14),
      child,
    ]),
  );
}

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, desc;
  final VoidCallback onTap;
  const _ToolCard({required this.icon, required this.color, required this.title, required this.desc, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider)),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          Text(desc, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted, height: 1.4)),
        ])),
        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
      ]),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: GoogleFonts.inter(
    fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accentDeep, letterSpacing: 0.5));
}
