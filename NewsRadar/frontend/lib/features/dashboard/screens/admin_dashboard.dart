import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/models/user.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/common_app_bar.dart';
import '../../../shared/services/admin_api_service.dart';

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

class _UsersTab extends StatefulWidget {
  const _UsersTab();
  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  final _api = AdminApiService();
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _loadUsers(); }

  Future<void> _loadUsers() async {
    setState(() { _loading = true; _error = null; });
    try {
      final token = AuthService().token!;
      final users = await _api.getUsers(token);
      setState(() { _users = users; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _updateStatus(String userId, String status) async {
    try {
      await _api.updateUserStatus(token: AuthService().token!, userId: userId, status: status);
      _loadUsers();
    } catch (e) {}
  }

  Future<void> _deleteUser(String userId) async {
    try {
      await _api.deleteUser(token: AuthService().token!, userId: userId);
      _loadUsers();
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));

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
          itemBuilder: (_, i) => _UserCard(
            userMap: _users[i],
            onStatusChange: (s) => _updateStatus(_users[i]['id'], s),
            onDelete: () => _deleteUser(_users[i]['id']),
          ),
        ),
      ),
    ]);
  }
}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> userMap;
  final Function(String) onStatusChange;
  final VoidCallback onDelete;
  
  const _UserCard({required this.userMap, required this.onStatusChange, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final name = userMap['name'] ?? 'Unknown';
    final email = userMap['email'] ?? '';
    final roleStr = userMap['role'] ?? 'consumer';
    final status = userMap['status'] ?? 'active';
    final role = UserRoleExt.fromString(roleStr);
    final roleColor = Color(role.colorValue);
    
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 20, backgroundColor: roleColor.withOpacity(0.15),
          child: Text(name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase(),
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: roleColor)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          Text(email, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
        ])),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          _RoleBadge(role: role),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: status == 'active'
                ? AppColors.badgeGreen.withOpacity(0.1)
                : AppColors.badgeRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(status.toUpperCase(), style: GoogleFonts.inter(
              fontSize: 10, fontWeight: FontWeight.w600,
              color: status == 'active' ? AppColors.badgeGreen : AppColors.badgeRed)),
          ),
        ]),
        const SizedBox(width: 8),
        if (status == 'pending')
          ElevatedButton.icon(
            onPressed: () => onStatusChange('active'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.badgeGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.check_circle_rounded, size: 16),
            label: Text('Approve', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
          )
        else
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 18, color: AppColors.textMuted),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            color: AppColors.surface,
            itemBuilder: (_) {
              final items = <PopupMenuEntry<String>>[];
              if (status == 'active') {
                items.add(_menuItem('locked', Icons.lock_rounded, 'Lock Account', AppColors.badgeAmber));
              } else if (status == 'locked') {
                items.add(_menuItem('active', Icons.lock_open_rounded, 'Unlock Account', AppColors.badgeGreen));
              }
              items.add(_menuItem('delete', Icons.delete_rounded, 'Delete', AppColors.badgeRed));
              return items;
            },
            onSelected: (val) {
              if (val == 'locked') onStatusChange('locked');
              if (val == 'active') onStatusChange('active');
              if (val == 'delete') onDelete();
            },
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

class _SourcesTab extends StatefulWidget {
  const _SourcesTab();
  @override
  State<_SourcesTab> createState() => _SourcesTabState();
}

class _SourcesTabState extends State<_SourcesTab> {
  final _api = AdminApiService();
  List<Map<String, dynamic>> _sources = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _loadSources(); }

  Future<void> _loadSources() async {
    setState(() { _loading = true; _error = null; });
    try {
      final token = AuthService().token!;
      final sources = await _api.getSources(token);
      setState(() { _sources = sources; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _toggleSource(String id, bool active) async {
    try {
      await _api.toggleSource(token: AuthService().token!, sourceId: id, isActive: active);
      _loadSources();
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));

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
          itemBuilder: (_, i) => _SourceCard(
            sourceMap: _sources[i],
            onToggle: (v) => _toggleSource(_sources[i]['id'], v),
          ),
        ),
      ),
    ]);
  }
}

class _SourceCard extends StatelessWidget {
  final Map<String, dynamic> sourceMap;
  final Function(bool) onToggle;
  
  const _SourceCard({required this.sourceMap, required this.onToggle});

  Color get _relColor {
    final r = (sourceMap['reliability'] ?? 0.0) as double;
    return r >= 0.7 ? AppColors.badgeGreen : r >= 0.4 ? AppColors.badgeAmber : AppColors.badgeRed;
  }

  @override
  Widget build(BuildContext context) {
    final name = sourceMap['name'] ?? 'Unknown';
    final url = sourceMap['url'] ?? '';
    final type = sourceMap['source_type'] ?? 'RSS';
    final reliability = (sourceMap['reliability'] ?? 0.0) as double;
    final isActive = sourceMap['is_active'] ?? false;

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
          Text(name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          Text(url, style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppColors.textMuted)),
        ])),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.accentDeep.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
            child: Text(type, style: GoogleFonts.jetBrainsMono(
              fontSize: 9, color: AppColors.accentDeep, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(
              color: _relColor, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text('${(reliability * 100).toInt()}%',
              style: GoogleFonts.jetBrainsMono(fontSize: 11, color: _relColor, fontWeight: FontWeight.w700)),
          ]),
        ]),
        const SizedBox(width: 8),
        Switch(
          value: isActive,
          activeColor: AppColors.accent,
          onChanged: onToggle,
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
  final _api = AdminApiService();
  String _provider = 'Groq';
  double _temp = 0.3;
  String _sumModel = 'llama-3.3-70b-versatile';
  String _nerModel = 'llama-3.1-8b-instant';
  String _sentModel = 'llama-3.1-8b-instant';
  String _claimModel = 'llama-3.3-70b-versatile';
  String _chatModel = 'llama-3.3-70b-versatile';
  bool _loading = true;

  @override
  void initState() { super.initState(); _loadConfig(); }

  Future<void> _loadConfig() async {
    try {
      final token = AuthService().token!;
      final cfg = await _api.getLlmConfig(token);
      setState(() {
        _provider = cfg['provider'] ?? 'Groq';
        _temp = (cfg['temperature'] ?? 0.3).toDouble();
        _sumModel = cfg['model_summ'] ?? _sumModel;
        _nerModel = cfg['model_ner'] ?? _nerModel;
        _sentModel = cfg['model_sent'] ?? _sentModel;
        _claimModel = cfg['model_claim'] ?? _claimModel;
        _chatModel = cfg['model_chat'] ?? _chatModel;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveConfig() async {
    try {
      await _api.saveLlmConfig(token: AuthService().token!, config: {
        'provider': _provider,
        'model_summ': _sumModel,
        'model_ner': _nerModel,
        'model_sent': _sentModel,
        'model_claim': _claimModel,
        'model_chat': _chatModel,
        'temperature': _temp,
        'max_tokens': 2048,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.accent));
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
          _ModelRow('NER Extraction',      _nerModel),
          _ModelRow('Sentiment Analysis',  _sentModel),
          _ModelRow('Claim Extraction',    _claimModel),
          _ModelRow('Chatbot',             _chatModel),
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
            onPressed: _saveConfig,
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
