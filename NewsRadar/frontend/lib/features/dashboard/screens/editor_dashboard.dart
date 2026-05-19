import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/common_app_bar.dart';
import '../../feed/screens/feed_screen.dart';

class EditorDashboard extends StatefulWidget {
  const EditorDashboard({super.key});
  @override
  State<EditorDashboard> createState() => _EditorDashboardState();
}

class _EditorDashboardState extends State<EditorDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() { super.initState(); _tab = TabController(length: 4, vsync: this); }
  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: CommonAppBar(
        title: 'Editor Dashboard',
        subtitle: 'Editorial Control',
        icon: Icons.edit_note_rounded,
        iconColor: const Color(0xFF7C3AED),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          indicatorColor: const Color(0xFF7C3AED),
          labelColor: const Color(0xFF7C3AED),
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(icon: Icon(Icons.feed_rounded, size: 16), text: 'Feed'),
            Tab(icon: Icon(Icons.gavel_rounded, size: 16), text: 'Verdicts'),
            Tab(icon: Icon(Icons.bar_chart_rounded, size: 16), text: 'Analytics'),
            Tab(icon: Icon(Icons.notifications_rounded, size: 16), text: 'Alerts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          const FeedBodyContent(),
          const _VerdictOverrideTab(),
          _EditorAnalyticsTab(),
          const _AlertsTab(),
        ],
      ),
    );
  }
}

// ─── Verdict Override Tab ─────────────────────────────────────────────────────

class _VerdictOverrideTab extends StatelessWidget {
  const _VerdictOverrideTab();

  static final _queue = [
    _VerdictItem('AI Companies Urge Regulation Before Election Season',
        'Reuters', 'UNVERIFIED', 'HIGH', '14 min ago'),
    _VerdictItem('Climate Summit Reaches Record Agreement on Emissions',
        'BBC News', 'VERIFIED', 'LOW', '28 min ago'),
    _VerdictItem('Viral Claim: New Vaccine Causes Microchip Implant',
        'Unknown Source', 'MISINFORMATION', 'HIGH', '1 hr ago'),
    _VerdictItem('Stock Market Hits 5-Year High Amid Rate Cut Hopes',
        'Reuters', 'VERIFIED', 'LOW', '2 hrs ago'),
    _VerdictItem('Government Officials Deny Budget Leak Report',
        'AP News', 'DISPUTED', 'MEDIUM', '3 hrs ago'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(12),
        color: const Color(0xFF7C3AED).withOpacity(0.06),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF7C3AED)),
          const SizedBox(width: 8),
          Expanded(child: Text(
            'Override verdicts with a 100-character rationale. All changes are audit-logged.',
            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF7C3AED)),
          )),
        ]),
      ),
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _queue.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _VerdictCard(item: _queue[i]),
        ),
      ),
    ]);
  }
}

class _VerdictItem {
  final String title, source, verdict, risk, time;
  const _VerdictItem(this.title, this.source, this.verdict, this.risk, this.time);
}

class _VerdictCard extends StatefulWidget {
  final _VerdictItem item;
  const _VerdictCard({required this.item});
  @override
  State<_VerdictCard> createState() => _VerdictCardState();
}

class _VerdictCardState extends State<_VerdictCard> {
  String _currentVerdict = '';
  final _ctrl = TextEditingController();
  bool _overriding = false;

  @override
  void initState() { super.initState(); _currentVerdict = widget.item.verdict; }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Color get _vColor {
    switch (_currentVerdict) {
      case 'VERIFIED':       return AppColors.badgeGreen;
      case 'UNVERIFIED':     return AppColors.badgeAmber;
      case 'DISPUTED':       return const Color(0xFF7C3AED);
      case 'MISINFORMATION': return AppColors.badgeRed;
      default:               return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: _vColor.withOpacity(0.12), borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: _vColor.withOpacity(0.4))),
                child: Text(_currentVerdict, style: GoogleFonts.jetBrainsMono(
                  fontSize: 9, color: _vColor, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              _RiskBadge(risk: widget.item.risk),
              const Spacer(),
              Text(widget.item.time, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
            ]),
            const SizedBox(height: 8),
            Text(widget.item.title, style: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary, height: 1.3)),
            const SizedBox(height: 4),
            Text(widget.item.source, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
          ]),
        ),
        if (_overriding) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Override verdict to:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 6, children: ['VERIFIED', 'UNVERIFIED', 'DISPUTED', 'MISINFORMATION'].map((v) =>
                GestureDetector(
                  onTap: () => setState(() => _currentVerdict = v),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _currentVerdict == v ? _vColor.withOpacity(0.15) : AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _currentVerdict == v ? _vColor : AppColors.divider)),
                    child: Text(v, style: GoogleFonts.jetBrainsMono(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: _currentVerdict == v ? _vColor : AppColors.textMuted)),
                  ),
                )
              ).toList()),
              const SizedBox(height: 10),
              TextField(
                controller: _ctrl, maxLength: 100,
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Rationale for override (required)...',
                  hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
                  filled: true, fillColor: AppColors.primary,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.divider)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.divider)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5)),
                ),
              ),
              Row(children: [
                TextButton(onPressed: () => setState(() => _overriding = false), child: const Text('Cancel')),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => setState(() { _overriding = false; }),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
                  child: Text('Apply Override', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ]),
            ]),
          ),
        ] else ...[
          const Divider(height: 1),
          TextButton.icon(
            onPressed: () => setState(() => _overriding = true),
            icon: const Icon(Icons.gavel_rounded, size: 15),
            label: const Text('Override Verdict'),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF7C3AED)),
          ),
        ],
      ]),
    );
  }
}

class _RiskBadge extends StatelessWidget {
  final String risk;
  const _RiskBadge({required this.risk});
  Color get _c => risk == 'HIGH' ? AppColors.badgeRed : risk == 'MEDIUM' ? AppColors.badgeAmber : AppColors.badgeGreen;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: _c.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
    child: Text('$risk RISK', style: GoogleFonts.inter(fontSize: 9, color: _c, fontWeight: FontWeight.w700)),
  );
}

// ─── Alerts Tab ───────────────────────────────────────────────────────────────

class _AlertsTab extends StatelessWidget {
  const _AlertsTab();
  static final _alerts = [
    _AlertItem('Misinformation spike detected', 'Misinformation articles up 140% in last 6h', true),
    _AlertItem('Source reliability drop', 'RT News reliability dropped below threshold (0.31)', true),
    _AlertItem('High-volume topic: AI Regulation', '78 articles ingested in last 2h', false),
    _AlertItem('Fact-check queue full', 'Integrity service queue > 500 articles', true),
  ];

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Active Alert Rules', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add_rounded, size: 15),
          label: const Text('New Rule'),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
        ),
      ]),
      const SizedBox(height: 12),
      ..._alerts.map((a) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: a.urgent ? AppColors.badgeRed.withOpacity(0.05) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: a.urgent ? AppColors.badgeRed.withOpacity(0.3) : AppColors.divider)),
        child: Row(children: [
          Icon(a.urgent ? Icons.warning_amber_rounded : Icons.notifications_rounded,
            color: a.urgent ? AppColors.badgeRed : AppColors.badgeAmber, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            Text(a.desc, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted, height: 1.4)),
          ])),
        ]),
      )),
    ],
  );
}

class _AlertItem {
  final String title, desc;
  final bool urgent;
  const _AlertItem(this.title, this.desc, this.urgent);
}

// ─── Editor analytics (simple version) ───────────────────────────────────────

class _EditorAnalyticsTab extends StatelessWidget {
  static final _verdictBreakdown = [
    ('VERIFIED',      203, AppColors.badgeGreen),
    ('UNVERIFIED',     91, AppColors.badgeAmber),
    ('DISPUTED',       38, AppColors.badgeRed),
    ('MISINFORMATION', 14, Color(0xFF7C3AED)),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          _EditorStatCard(label: 'Pending Review', value: '23', icon: Icons.pending_rounded, color: AppColors.badgeAmber),
          const SizedBox(width: 12),
          _EditorStatCard(label: 'Overridden Today', value: '5', icon: Icons.gavel_rounded, color: const Color(0xFF7C3AED)),
          const SizedBox(width: 12),
          _EditorStatCard(label: 'Active Alerts', value: '4', icon: Icons.notifications_rounded, color: AppColors.badgeRed),
        ]),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Verdict Distribution', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 14),
            ..._verdictBreakdown.map((v) {
              final (label, count, color) = v;
              final total = _verdictBreakdown.fold<int>(0, (s, e) => s + e.$2);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 8),
                  SizedBox(width: 120, child: Text(label, style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppColors.textPrimary))),
                  Expanded(child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: count / total, minHeight: 10,
                      backgroundColor: AppColors.divider,
                      valueColor: AlwaysStoppedAnimation(color.withOpacity(0.7))),
                  )),
                  const SizedBox(width: 8),
                  Text('$count', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppColors.textMuted)),
                ]),
              );
            }),
          ]),
        ),
      ],
    );
  }
}

class _EditorStatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _EditorStatCard({required this.label, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surface, borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.divider)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(height: 6),
      Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
    ]),
  ));
}
