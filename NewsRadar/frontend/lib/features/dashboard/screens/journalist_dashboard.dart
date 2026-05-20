
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/common_app_bar.dart';
import '../../feed/screens/feed_screen.dart';
import '../../chat/screens/chat_screen.dart';

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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen())),
        backgroundColor: const Color(0xFF004E9F),
        icon: const Icon(Icons.mic_rounded, color: Colors.white),
        label: Text('AI Chat', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
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
  Widget build(BuildContext context) => const FeedBodyContent();
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
                    valueColor: AlwaysStoppedAnimation(color.withValues(alpha: 0.7)),
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
            _ReliabilityRow('BBC News',   0.91),
            _ReliabilityRow('Reuters',    0.88),
            _ReliabilityRow('AP News',    0.85),
            _ReliabilityRow('CNN',        0.72),
            _ReliabilityRow('TechCrunch', 0.68),
            _ReliabilityRow('RT News',    0.31),
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
        _ToolCard(
          icon: Icons.compare_arrows_rounded,
          color: AppColors.accentDeep,
          title: 'Compare Coverage',
          desc: 'Compare how different sources covered the same event',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _CompareCoverageScreen())),
        ),
        _ToolCard(
          icon: Icons.fact_check_rounded,
          color: AppColors.badgeGreen,
          title: 'Manual Fact Check',
          desc: 'Initiate a fact-check pipeline on any article',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _FactCheckScreen())),
        ),
        _ToolCard(
          icon: Icons.download_rounded,
          color: AppColors.badgeAmber,
          title: 'Export Report',
          desc: 'Export filtered article data as CSV or PDF',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _ExportReportScreen())),
        ),
        _ToolCard(
          icon: Icons.hub_rounded,
          color: const Color(0xFF7C3AED),
          title: 'Narrative Clustering',
          desc: 'Visualize semantic clusters of related stories',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _NarrativeClusteringScreen())),
        ),
        const SizedBox(height: 20),
        _SectionHeader('AI Research Assistant'),
        const SizedBox(height: 12),
        _ToolCard(
          icon: Icons.mic_rounded,
          color: const Color(0xFF004E9F),
          title: 'Ask AI (Voice + Text)',
          desc: 'Ask anything — news, facts, research queries in English or Roman Urdu',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen())),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 1. COMPARE COVERAGE SCREEN
// ═════════════════════════════════════════════════════════════════════════════
class _CompareCoverageScreen extends StatefulWidget {
  const _CompareCoverageScreen();
  @override
  State<_CompareCoverageScreen> createState() => _CompareCoverageScreenState();
}

class _CompareCoverageScreenState extends State<_CompareCoverageScreen> {
  final _queryCtrl = TextEditingController();
  final _api = ApiService();
  bool _loading = false;
  List<Map<String, dynamic>> _results = [];
  String? _error;

  Future<void> _search() async {
    final q = _queryCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() { _loading = true; _error = null; _results = []; });
    try {
      final articles = await _api.getArticles(q: q, pageSize: 10);
      // Group by source
      final Map<String, List<dynamic>> bySource = {};
      for (final a in articles) {
        bySource.putIfAbsent(a.source.name, () => []).add(a);
      }
      setState(() {
        _results = bySource.entries.map((e) => {
          'source': e.key,
          'count': e.value.length,
          'titles': e.value.map((a) => a.title).toList(),
          'verdicts': e.value.map((a) => a.status).toList(),
        }).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text('Compare Coverage', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        elevation: 0,
      ),
      body: Column(children: [
        // Search bar
        Container(
          color: AppColors.primaryLight,
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _queryCtrl,
                decoration: InputDecoration(
                  hintText: 'Enter topic or event (e.g. "Pakistan election")',
                  hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
                  filled: true, fillColor: AppColors.primary,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accentDeep, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onSubmitted: (_) => _search(),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: _search,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentDeep,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              child: Text('Compare', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ]),
        ),
        // Results
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentDeep))
          : _error != null
            ? Center(child: Text(_error!, style: GoogleFonts.inter(color: AppColors.badgeRed)))
            : _results.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.compare_arrows_rounded, size: 64, color: AppColors.textMuted),
                  const SizedBox(height: 16),
                  Text('Search a topic to compare sources', style: GoogleFonts.inter(color: AppColors.textMuted)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _results.length,
                  itemBuilder: (_, i) {
                    final r = _results[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: ExpansionTile(
                        leading: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.accentDeep.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(child: Text('${r['count']}',
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.accentDeep))),
                        ),
                        title: Text(r['source'] as String,
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        subtitle: Text('${r['count']} articles found',
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                        children: (r['titles'] as List).asMap().entries.map((e) =>
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.article_outlined, size: 16, color: AppColors.textMuted),
                            title: Text(e.value.toString(),
                              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                            trailing: _VerdictChip(r['verdicts'][e.key] as String),
                          ),
                        ).toList(),
                      ),
                    ).animate(delay: Duration(milliseconds: i * 60)).fadeIn().slideY(begin: 0.1);
                  },
                ),
        ),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 2. MANUAL FACT CHECK SCREEN
// ═════════════════════════════════════════════════════════════════════════════
class _FactCheckScreen extends StatefulWidget {
  const _FactCheckScreen();
  @override
  State<_FactCheckScreen> createState() => _FactCheckScreenState();
}

class _FactCheckScreenState extends State<_FactCheckScreen> {
  final _claimCtrl = TextEditingController();
  final _api = ApiService();
  final _sessionId = 'factcheck_${DateTime.now().millisecondsSinceEpoch}';
  bool _loading = false;
  Map<String, dynamic>? _result;

  Future<void> _factCheck() async {
    final claim = _claimCtrl.text.trim();
    if (claim.isEmpty) return;
    setState(() { _loading = true; _result = null; });

    try {
      final res = await _api.sendChatMessage(
        message: 'Fact check this claim thoroughly. Verdict: VERIFIED, UNVERIFIED, DISPUTED, or MISINFORMATION. '
            'Explain why with evidence. Claim: "$claim"',
        sessionId: _sessionId,
      );
      final reply = res['reply'] as String? ?? 'Could not analyze.';

      // Detect verdict from reply
      String verdict = 'UNVERIFIED';
      if (reply.toUpperCase().contains('MISINFORMATION')) {
        verdict = 'MISINFORMATION';
      } else if (reply.toUpperCase().contains('DISPUTED')) {
        verdict = 'DISPUTED';
      } else if (reply.toUpperCase().contains('VERIFIED')) {
        verdict = 'VERIFIED';
      }

      if (!mounted) return;
      setState(() {
        _result = {'verdict': verdict, 'analysis': reply, 'claim': claim};
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: AppColors.badgeRed));
    }
  }

  @override
  Widget build(BuildContext context) {
    final verdictColors = {
      'VERIFIED': AppColors.badgeGreen,
      'UNVERIFIED': AppColors.badgeAmber,
      'DISPUTED': AppColors.badgeRed,
      'MISINFORMATION': const Color(0xFF7C3AED),
    };

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text('Manual Fact Check', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Claim input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Enter Claim to Fact-Check',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 10),
              TextField(
                controller: _claimCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'e.g. "Pakistan\'s inflation rate is the highest in the world"',
                  hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
                  filled: true, fillColor: AppColors.primary,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.divider)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.divider)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accentDeep, width: 1.5)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _factCheck,
                  icon: _loading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.fact_check_rounded),
                  label: Text(_loading ? 'Analyzing...' : 'Run Fact Check',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.badgeGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ]),
          ),

          // Result
          if (_result != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: verdictColors[_result!['verdict']]!.withValues(alpha: 0.4), width: 1.5),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: verdictColors[_result!['verdict']]!.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_result!['verdict'] as String,
                      style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700,
                        color: verdictColors[_result!['verdict']])),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.textMuted),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _result!['analysis'] as String));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 1)));
                    },
                  ),
                ]),
                const SizedBox(height: 12),
                Text('Analysis', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                const SizedBox(height: 6),
                Text(_result!['analysis'] as String,
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.6)),
              ]),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),
          ],
        ]),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 3. EXPORT REPORT SCREEN
// ═════════════════════════════════════════════════════════════════════════════
class _ExportReportScreen extends StatefulWidget {
  const _ExportReportScreen();
  @override
  State<_ExportReportScreen> createState() => _ExportReportScreenState();
}

class _ExportReportScreenState extends State<_ExportReportScreen> {
  final _api = ApiService();
  bool _loading = false;
  bool _exported = false;
  String _selectedCategory = 'All';
  String _selectedVerdict = 'All';
  String _exportFormat = 'CSV';
  List<dynamic> _articles = [];

  final _categories = ['All', 'Technology', 'Business', 'Health', 'Science', 'Sports', 'Entertainment'];
  final _verdicts = ['All', 'VERIFIED', 'UNVERIFIED', 'DISPUTED', 'MISINFORMATION'];

  Future<void> _loadAndExport() async {
    setState(() { _loading = true; _exported = false; });
    try {
      final articles = await _api.getArticles(
        category: _selectedCategory == 'All' ? null : _selectedCategory.toLowerCase(),
        pageSize: 50,
      );
      // Filter by verdict
      final filtered = _selectedVerdict == 'All'
          ? articles
          : articles.where((a) => a.status.toUpperCase() == _selectedVerdict).toList();

      // Build export content
      final lines = StringBuffer();
      if (_exportFormat == 'CSV') {
        lines.writeln('Title,Source,Category,Status,PublishedAt,URL');
        for (final a in filtered) {
          lines.writeln('"${a.title.replaceAll('"', '""')}","${a.source.name}","${_selectedCategory}","${a.status}","${a.publishedAt}","${a.url}"');
        }
      } else {
        lines.writeln('NEWSRADAR EXPORT REPORT');
        lines.writeln('Generated: ${DateTime.now()}');
        lines.writeln('Category: $_selectedCategory | Verdict: $_selectedVerdict');
        lines.writeln('='*50);
        for (final a in filtered) {
          lines.writeln('\n[${a.status}] ${a.title}');
          lines.writeln('Source: ${a.source.name} | ${a.publishedAt}');
          lines.writeln('URL: ${a.url}');
        }
      }

      await Clipboard.setData(ClipboardData(text: lines.toString()));
      setState(() { _loading = false; _exported = true; _articles = filtered; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.badgeRed));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text('Export Report', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Export Settings', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              // Category filter
              Text('Category', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: _categories.map((c) =>
                ChoiceChip(
                  label: Text(c, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                  selected: _selectedCategory == c,
                  selectedColor: AppColors.accentDeep.withValues(alpha: 0.15),
                  onSelected: (_) => setState(() => _selectedCategory = c),
                  labelStyle: TextStyle(color: _selectedCategory == c ? AppColors.accentDeep : AppColors.textSecondary),
                  side: BorderSide(color: _selectedCategory == c ? AppColors.accentDeep : AppColors.divider),
                ),
              ).toList()),
              const SizedBox(height: 14),
              // Verdict filter
              Text('Verdict', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: _verdicts.map((v) =>
                ChoiceChip(
                  label: Text(v, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                  selected: _selectedVerdict == v,
                  selectedColor: AppColors.badgeGreen.withValues(alpha: 0.15),
                  onSelected: (_) => setState(() => _selectedVerdict = v),
                  labelStyle: TextStyle(color: _selectedVerdict == v ? AppColors.badgeGreen : AppColors.textSecondary),
                  side: BorderSide(color: _selectedVerdict == v ? AppColors.badgeGreen : AppColors.divider),
                ),
              ).toList()),
              const SizedBox(height: 14),
              // Format
              Text('Format', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
              const SizedBox(height: 8),
              Row(children: ['CSV', 'Plain Text'].map((f) =>
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ChoiceChip(
                    label: Text(f, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                    selected: _exportFormat == f,
                    selectedColor: AppColors.badgeAmber.withValues(alpha: 0.15),
                    onSelected: (_) => setState(() => _exportFormat = f),
                    labelStyle: TextStyle(color: _exportFormat == f ? AppColors.badgeAmber : AppColors.textSecondary),
                    side: BorderSide(color: _exportFormat == f ? AppColors.badgeAmber : AppColors.divider),
                  ),
                ),
              ).toList()),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _loadAndExport,
                  icon: _loading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.download_rounded),
                  label: Text(_loading ? 'Generating...' : 'Generate & Copy to Clipboard',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.badgeAmber,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ]),
          ),

          if (_exported) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.badgeGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.badgeGreen.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.badgeGreen),
                const SizedBox(width: 12),
                Expanded(child: Text(
                  '${_articles.length} articles exported as $_exportFormat — copied to clipboard!',
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.badgeGreen, fontWeight: FontWeight.w600),
                )),
              ]),
            ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95)),
            const SizedBox(height: 16),
            // Preview
            Text('Preview (${_articles.length} articles)',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            ..._articles.take(5).map((a) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a.title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(a.source.name, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                ])),
                const SizedBox(width: 8),
                _VerdictChip(a.status),
              ]),
            )).toList(),
            if (_articles.length > 5)
              Text('... and ${_articles.length - 5} more',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
          ],
        ]),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 4. NARRATIVE CLUSTERING SCREEN
// ═════════════════════════════════════════════════════════════════════════════
class _NarrativeClusteringScreen extends StatefulWidget {
  const _NarrativeClusteringScreen();
  @override
  State<_NarrativeClusteringScreen> createState() => _NarrativeClusteringScreenState();
}

class _NarrativeClusteringScreenState extends State<_NarrativeClusteringScreen> {
  final _api = ApiService();
  bool _loading = false;
  List<Map<String, dynamic>> _clusters = [];
  int? _selectedCluster;

  static const _clusterColors = [
    Color(0xFF0066CC), Color(0xFF10B981), Color(0xFFAE2F34),
    Color(0xFF7C3AED), Color(0xFFF59E0B), Color(0xFF0891B2),
  ];

  Future<void> _cluster() async {
    setState(() { _loading = true; _clusters = []; _selectedCluster = null; });
    try {
      final articles = await _api.getArticles(pageSize: 30);
      // Client-side naive clustering by keyword overlap
      final Map<String, List<dynamic>> grouped = {};
      for (final a in articles) {
        final words = a.title.toLowerCase().split(' ')
            .where((w) => w.length > 4).toList();
        bool placed = false;
        for (final key in grouped.keys) {
          final keyWords = key.split('|');
          final overlap = words.where((w) => keyWords.contains(w)).length;
          if (overlap >= 1) { grouped[key]!.add(a); placed = true; break; }
        }
        if (!placed && words.isNotEmpty) {
          grouped[words.take(2).join('|')]= [a];
        }
      }
      // Build clusters, sort by size
      final sorted = grouped.entries.toList()
        ..sort((a, b) => b.value.length.compareTo(a.value.length));

      setState(() {
        _clusters = sorted.take(6).map((e) {
          final topic = e.key.split('|').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
          return {'topic': topic, 'articles': e.value, 'count': e.value.length};
        }).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.badgeRed));
    }
  }

  @override
  void initState() { super.initState(); _cluster(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text('Narrative Clustering', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.accentDeep),
            onPressed: _cluster,
            tooltip: 'Re-cluster',
          ),
        ],
      ),
      body: _loading
        ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(color: AppColors.accentDeep),
            SizedBox(height: 16),
            Text('Clustering narratives...'),
          ]))
        : _clusters.isEmpty
          ? Center(child: ElevatedButton.icon(onPressed: _cluster,
              icon: const Icon(Icons.hub_rounded), label: const Text('Load Clusters')))
          : Row(children: [
              // Cluster list
              SizedBox(
                width: 180,
                child: Container(
                  color: AppColors.primaryLight,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _clusters.length,
                    itemBuilder: (_, i) {
                      final c = _clusters[i];
                      final selected = _selectedCluster == i;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedCluster = i),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: selected ? _clusterColors[i % _clusterColors.length].withValues(alpha: 0.1) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected ? _clusterColors[i % _clusterColors.length] : AppColors.divider,
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Container(
                              width: 28, height: 28,
                              decoration: BoxDecoration(
                                color: _clusterColors[i % _clusterColors.length].withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(child: Text('${c['count']}',
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800,
                                  color: _clusterColors[i % _clusterColors.length]))),
                            ),
                            const SizedBox(height: 6),
                            Text(c['topic'] as String,
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          ]),
                        ),
                      ).animate(delay: Duration(milliseconds: i * 50)).fadeIn().slideX(begin: -0.1);
                    },
                  ),
                ),
              ),
              // Article list
              Expanded(
                child: _selectedCluster == null
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.hub_rounded, size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      Text('Select a cluster to view stories',
                        style: GoogleFonts.inter(color: AppColors.textMuted)),
                    ]))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: (_clusters[_selectedCluster!]['articles'] as List).length,
                      itemBuilder: (_, i) {
                        final a = (_clusters[_selectedCluster!]['articles'] as List)[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(a.title,
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                              maxLines: 3, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 6),
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.accentDeep.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(a.source.name,
                                  style: GoogleFonts.inter(fontSize: 10, color: AppColors.accentDeep, fontWeight: FontWeight.w600)),
                              ),
                              const Spacer(),
                              _VerdictChip(a.status),
                            ]),
                          ]),
                        ).animate(delay: Duration(milliseconds: i * 40)).fadeIn().slideY(begin: 0.1);
                      },
                    ),
              ),
            ]),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _VerdictChip extends StatelessWidget {
  final String status;
  const _VerdictChip(this.status);

  Color get _color {
    switch (status.toUpperCase()) {
      case 'VERIFIED': return AppColors.badgeGreen;
      case 'DISPUTED': return AppColors.badgeRed;
      case 'MISINFORMATION': return const Color(0xFF7C3AED);
      default: return AppColors.badgeAmber;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: _color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(status.length > 10 ? status.substring(0, 8) : status,
      style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w700, color: _color)),
  );
}

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
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
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
