import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/models/user.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/common_app_bar.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: CommonAppBar(
        title: 'Admin Panel',
        subtitle: 'Platform Management',
        icon: Icons.admin_panel_settings_rounded,
        iconColor: AppColors.badgeRed,
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          indicatorColor: AppColors.badgeRed,
          labelColor: AppColors.badgeRed,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(icon: Icon(Icons.people_rounded, size: 16), text: 'Users'),
            Tab(icon: Icon(Icons.rss_feed_rounded, size: 16), text: 'Sources'),
            Tab(icon: Icon(Icons.monitor_heart_rounded, size: 16), text: 'Health'),
            Tab(icon: Icon(Icons.psychology_rounded, size: 16), text: 'LLM Config'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _UsersTab(),
          _SourcesTab(),
          _SystemHealthTab(),
          _LLMConfigTab(),
        ],
      ),
    );
  }
}

// ─── Users Tab ────────────────────────────────────────────────────────────────

class _UsersTab extends StatelessWidget {
  const _UsersTab();

  static final _users = [
    _UserRow('Admin User',     'admin@newsradar.com',      UserRole.admin,      'Active', true),
    _UserRow('Editor Jane',    'editor@newsradar.com',     UserRole.editor,     'Active', true),
    _UserRow('John Reporter',  'journalist@newsradar.com', UserRole.journalist, 'Active', false),
    _UserRow('Regular User',   'user@newsradar.com',       UserRole.consumer,   'Active', false),
    _UserRow('Audit Smith',    'auditor@newsradar.com',    UserRole.auditor,    'Active', true),
    _UserRow('Alice Chen',     'alice@media.com',          UserRole.journalist, 'Active', false),
    _UserRow('Bob Nguyen',     'bob@press.com',            UserRole.consumer,   'Locked', false),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _SectionBar(
        label: '${_users.length} registered users',
        action: TextButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.person_add_rounded, size: 16),
          label: const Text('Invite User'),
        ),
      ),
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _users.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _UserCard(user: _users[i]),
        ),
      ),
    ]);
  }
}

class _UserRow {
  final String name, email, status;
  final UserRole role;
  final bool mfaEnabled;
  const _UserRow(this.name, this.email, this.role, this.status, this.mfaEnabled);
}

class _UserCard extends StatelessWidget {
  final _UserRow user;
  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final roleColor = Color(user.role.colorValue);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 20, backgroundColor: roleColor.withOpacity(0.15),
          child: Text(user.name.split(' ').map((w) => w[0]).take(2).join(),
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: roleColor)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(user.name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          Text(user.email, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
        ])),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          _RoleBadge(role: user.role),
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (user.mfaEnabled) ...[
              const Icon(Icons.shield_rounded, size: 11, color: AppColors.badgeGreen),
              const SizedBox(width: 3),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: user.status == 'Active'
                  ? AppColors.badgeGreen.withOpacity(0.1)
                  : AppColors.badgeRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(user.status, style: GoogleFonts.inter(
                fontSize: 10, fontWeight: FontWeight.w600,
                color: user.status == 'Active' ? AppColors.badgeGreen : AppColors.badgeRed)),
            ),
          ]),
        ]),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, size: 18, color: AppColors.textMuted),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          color: AppColors.surface,
          itemBuilder: (_) => [
            _menuItem('edit', Icons.edit_rounded, 'Edit Role', AppColors.textPrimary),
            _menuItem('lock', Icons.lock_rounded, 'Lock Account', AppColors.badgeAmber),
            _menuItem('delete', Icons.delete_rounded, 'Delete', AppColors.badgeRed),
          ],
          onSelected: (_) {},
        ),
      ]),
    ).animate(delay: Duration(milliseconds: 50)).fadeIn().slideX(begin: 0.05);
  }

  PopupMenuItem<String> _menuItem(String v, IconData icon, String label, Color c) =>
    PopupMenuItem(value: v, child: Row(children: [
      Icon(icon, size: 15, color: c), const SizedBox(width: 10),
      Text(label, style: GoogleFonts.inter(fontSize: 13, color: c)),
    ]));
}

// ─── Sources Tab ──────────────────────────────────────────────────────────────

class _SourcesTab extends StatelessWidget {
  const _SourcesTab();

  static final _sources = [
    _SourceRow('BBC News',       'https://bbc.com',       'RSS',     0.91, true),
    _SourceRow('Reuters',        'https://reuters.com',   'RSS',     0.88, true),
    _SourceRow('AP News',        'https://apnews.com',    'SCRAPER', 0.85, true),
    _SourceRow('CNN',            'https://cnn.com',       'RSS',     0.72, true),
    _SourceRow('The Guardian',   'https://guardian.com',  'RSS',     0.80, true),
    _SourceRow('TechCrunch',     'https://techcrunch.com','SCRAPER', 0.68, true),
    _SourceRow('RT News',        'https://rt.com',        'RSS',     0.31, false),
    _SourceRow('NewsWire Daily', 'https://nwd.example',   'API',     0.55, true),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _SectionBar(
        label: '${_sources.length} registered sources',
        action: ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('Add Source'),
        ),
      ),
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _sources.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _SourceCard(source: _sources[i]),
        ),
      ),
    ]);
  }
}

class _SourceRow {
  final String name, url, type;
  final double reliability;
  final bool isActive;
  const _SourceRow(this.name, this.url, this.type, this.reliability, this.isActive);
}

class _SourceCard extends StatelessWidget {
  final _SourceRow source;
  const _SourceCard({required this.source});

  Color get _relColor => source.reliability >= 0.7
    ? AppColors.badgeGreen
    : source.reliability >= 0.4 ? AppColors.badgeAmber : AppColors.badgeRed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40, decoration: BoxDecoration(
            color: AppColors.primary, borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.divider)),
          child: const Icon(Icons.language_rounded, color: AppColors.textMuted, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(source.name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          Text(source.url, style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppColors.textMuted)),
        ])),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.accentDeep.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
            child: Text(source.type, style: GoogleFonts.jetBrainsMono(
              fontSize: 9, color: AppColors.accentDeep, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(
              color: _relColor, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text('${(source.reliability * 100).toInt()}%',
              style: GoogleFonts.jetBrainsMono(fontSize: 11, color: _relColor, fontWeight: FontWeight.w700)),
          ]),
        ]),
        const SizedBox(width: 8),
        Switch(
          value: source.isActive,
          activeColor: AppColors.accent,
          onChanged: (_) {},
        ),
      ]),
    ).animate(delay: Duration(milliseconds: 50)).fadeIn().slideX(begin: 0.05);
  }
}

// ─── System Health Tab ────────────────────────────────────────────────────────

class _SystemHealthTab extends StatelessWidget {
  const _SystemHealthTab();

  static final _services = [
    _ServiceRow('ingestion-service', 'HEALTHY',  '99.8%', '2s ago'),
    _ServiceRow('nlp-service',       'HEALTHY',  '99.5%', '1s ago'),
    _ServiceRow('integrity-service', 'HEALTHY',  '99.7%', '3s ago'),
    _ServiceRow('api-gateway',       'HEALTHY',  '99.9%', '1s ago'),
    _ServiceRow('chatbot-service',   'DEGRADED', '97.2%', '8s ago'),
    _ServiceRow('audit-service',     'HEALTHY',  '100%',  '2s ago'),
    _ServiceRow('notification-svc',  'HEALTHY',  '99.1%', '4s ago'),
  ];

  static final _kafka = [
    _KafkaRow('article.ingested',  'nlp-consumer',      120),
    _KafkaRow('article.enriched',  'integrity-consumer', 45),
    _KafkaRow('article.verified',  'notification',        8),
    _KafkaRow('audit.events',      'audit-consumer',      2),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader('Services'),
        const SizedBox(height: 10),
        ...(_services.map((s) => _ServiceCard(s))),
        const SizedBox(height: 20),
        _SectionHeader('Kafka Consumer Lag'),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider)),
          child: Column(children: _kafka.asMap().entries.map((e) => _KafkaRow2(e.value, e.key == _kafka.length - 1)).toList()),
        ),
        const SizedBox(height: 20),
        _SectionHeader('LLM API Quota'),
        const SizedBox(height: 10),
        _QuotaCard(provider: 'Groq', used: 45230, budget: 100000, costToday: 0.82, costMonth: 14.50),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _ServiceRow {
  final String name, status, uptime, lastBeat;
  const _ServiceRow(this.name, this.status, this.uptime, this.lastBeat);
}

class _ServiceCard extends StatelessWidget {
  final _ServiceRow s;
  const _ServiceCard(this.s);
  Color get _c => s.status == 'HEALTHY' ? AppColors.badgeGreen : s.status == 'DEGRADED' ? AppColors.badgeAmber : AppColors.badgeRed;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.surface, borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.divider)),
    child: Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: _c, shape: BoxShape.circle)),
      const SizedBox(width: 10),
      Expanded(child: Text(s.name, style: GoogleFonts.jetBrainsMono(fontSize: 13, color: AppColors.textPrimary))),
      Text(s.uptime, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
      const SizedBox(width: 12),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: _c.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
        child: Text(s.status, style: GoogleFonts.inter(fontSize: 10, color: _c, fontWeight: FontWeight.w700)),
      ),
    ]),
  ).animate(delay: Duration(milliseconds: 40)).fadeIn();
}

class _KafkaRow {
  final String topic, group;
  final int lag;
  const _KafkaRow(this.topic, this.group, this.lag);
}

class _KafkaRow2 extends StatelessWidget {
  final _KafkaRow r;
  final bool last;
  const _KafkaRow2(this.r, this.last);
  Color get _c => r.lag > 1000 ? AppColors.badgeRed : r.lag > 100 ? AppColors.badgeAmber : AppColors.badgeGreen;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: AppColors.divider))),
    child: Row(children: [
      Expanded(child: Text(r.topic, style: GoogleFonts.jetBrainsMono(fontSize: 12, color: AppColors.textPrimary))),
      Text('lag: ', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
      Text('${r.lag}', style: GoogleFonts.jetBrainsMono(fontSize: 12, color: _c, fontWeight: FontWeight.w700)),
    ]),
  );
}

class _QuotaCard extends StatelessWidget {
  final String provider;
  final int used, budget;
  final double costToday, costMonth;
  const _QuotaCard({required this.provider, required this.used, required this.budget,
    required this.costToday, required this.costMonth});
  @override
  Widget build(BuildContext context) {
    final pct = used / budget;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(provider, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const Spacer(),
          Text('\$${costToday.toStringAsFixed(2)} today  ·  \$${costMonth.toStringAsFixed(2)} /mo',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct, minHeight: 8,
            backgroundColor: AppColors.divider,
            valueColor: AlwaysStoppedAnimation(pct > 0.8 ? AppColors.badgeRed : AppColors.accent),
          ),
        ),
        const SizedBox(height: 6),
        Text('${(used / 1000).toStringAsFixed(1)}k / ${(budget / 1000).toStringAsFixed(0)}k tokens  (${(pct * 100).toInt()}%)',
          style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppColors.textMuted)),
      ]),
    );
  }
}

// ─── LLM Config Tab ───────────────────────────────────────────────────────────

class _LLMConfigTab extends StatefulWidget {
  const _LLMConfigTab();
  @override
  State<_LLMConfigTab> createState() => _LLMConfigTabState();
}

class _LLMConfigTabState extends State<_LLMConfigTab> {
  String _provider = 'Groq';
  double _temp = 0.3;
  String _sumModel = 'llama-3.3-70b-versatile';

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader('LLM Provider'),
        const SizedBox(height: 10),
        _ConfigCard(child: Column(children: ['Groq', 'OpenAI', 'Anthropic'].map((p) =>
          RadioListTile<String>(
            value: p, groupValue: _provider,
            onChanged: (v) => setState(() => _provider = v!),
            title: Text(p, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            activeColor: AppColors.accent,
            dense: true,
          )
        ).toList())),
        const SizedBox(height: 16),
        _SectionHeader('Task Models'),
        const SizedBox(height: 10),
        _ConfigCard(child: Column(children: [
          _ModelRow('Summarization',       _sumModel),
          _ModelRow('NER Extraction',      'llama-3.1-8b-instant'),
          _ModelRow('Sentiment Analysis',  'llama-3.1-8b-instant'),
          _ModelRow('Claim Extraction',    'llama-3.3-70b-versatile'),
          _ModelRow('Chatbot',             'llama-3.3-70b-versatile'),
        ])),
        const SizedBox(height: 16),
        _SectionHeader('Generation Parameters'),
        const SizedBox(height: 10),
        _ConfigCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Temperature: ${_temp.toStringAsFixed(1)}',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          Slider(value: _temp, min: 0.0, max: 1.0, divisions: 10,
            activeColor: AppColors.accent,
            onChanged: (v) => setState(() => _temp = v)),
        ])),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 44,
          child: ElevatedButton(
            onPressed: () {},
            child: Text('Save Configuration',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
          )),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _ModelRow extends StatelessWidget {
  final String task, model;
  const _ModelRow(this.task, this.model);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Expanded(child: Text(task, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary))),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary, borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.divider)),
        child: Text(model, style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppColors.accentDeep)),
      ),
    ]),
  );
}

class _ConfigCard extends StatelessWidget {
  final Widget child;
  const _ConfigCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.divider)),
    child: child,
  );
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

class _SectionBar extends StatelessWidget {
  final String label;
  final Widget? action;
  const _SectionBar({required this.label, this.action});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
    decoration: BoxDecoration(
      color: AppColors.surfaceVariant,
      border: Border(bottom: BorderSide(color: AppColors.divider))),
    child: Row(children: [
      Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
      const Spacer(),
      if (action != null) action!,
    ]),
  );
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700,
      color: AppColors.accentDeep, letterSpacing: 0.5));
}

class _RoleBadge extends StatelessWidget {
  final UserRole role;
  const _RoleBadge({required this.role});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: Color(role.colorValue).withOpacity(0.12),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: Color(role.colorValue).withOpacity(0.3))),
    child: Text(role.label, style: GoogleFonts.jetBrainsMono(
      fontSize: 9, color: Color(role.colorValue), fontWeight: FontWeight.w700)),
  );
}
